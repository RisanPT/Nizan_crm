// Models for Team N Website (the public-site CMS). Hand-written fromJson —
// no code generation. Field definitions come from the backend registry
// (GET /api/website/admin/schema), so editors are built from data, not code.

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Deep copy of JSON-like data (maps / lists / scalars), so an editor can
/// change its working copy without touching the loaded original.
dynamic deepCopyJson(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), deepCopyJson(val)));
  }
  if (v is List) return v.map(deepCopyJson).toList();
  return v;
}

/// Upload limits for one image field, straight from the backend's rule.
class UploadRule {
  final String key;
  final String label;
  final List<String> mimeTypes;
  final List<String> extensions; // with dot: ['.jpg', '.jpeg']
  final int maxBytes;
  final int minWidth;
  final int minHeight;
  final List<double>? ratio; // [min, max] of width / height
  final String shape;
  final String hint;

  const UploadRule({
    required this.key,
    required this.label,
    required this.mimeTypes,
    required this.extensions,
    required this.maxBytes,
    required this.minWidth,
    required this.minHeight,
    required this.ratio,
    required this.shape,
    required this.hint,
  });

  factory UploadRule.fromJson(Map<String, dynamic> j) => UploadRule(
    key: j['key']?.toString() ?? '',
    label: j['label']?.toString() ?? '',
    mimeTypes: (j['mimeTypes'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    extensions: (j['extensions'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    maxBytes: (j['maxBytes'] as num?)?.toInt() ?? 0,
    minWidth: (j['minWidth'] as num?)?.toInt() ?? 0,
    minHeight: (j['minHeight'] as num?)?.toInt() ?? 0,
    ratio: j['ratio'] is List
        ? (j['ratio'] as List).map((e) => (e as num).toDouble()).toList()
        : null,
    shape: j['shape']?.toString() ?? '',
    hint: j['hint']?.toString() ?? '',
  );

  /// Extensions without the dot, for the file picker.
  List<String> get pickerExtensions =>
      extensions.map((e) => e.startsWith('.') ? e.substring(1) : e).toList();
}

/// One editable field. `type` is one of: text, textarea, url, email, phone,
/// number, boolean, image, list, textList, keyedText.
class FieldDef {
  final String name;
  final String type;
  final String label;
  final bool required;
  final int? maxLength;
  final num? min;
  final num? max;
  final int? maxItems;
  final UploadRule? upload;
  final Map<String, FieldDef> fields; // for type 'list'

  const FieldDef({
    required this.name,
    required this.type,
    required this.label,
    this.required = false,
    this.maxLength,
    this.min,
    this.max,
    this.maxItems,
    this.upload,
    this.fields = const {},
  });

  factory FieldDef.fromJson(String name, Map<String, dynamic> j) => FieldDef(
    name: name,
    type: j['type']?.toString() ?? 'text',
    label: j['label']?.toString() ?? name,
    required: j['required'] == true,
    maxLength: (j['maxLength'] as num?)?.toInt(),
    min: j['min'] as num?,
    max: j['max'] as num?,
    maxItems: (j['maxItems'] as num?)?.toInt(),
    upload: j['upload'] is Map ? UploadRule.fromJson(_map(j['upload'])) : null,
    fields: fieldsFromJson(j['fields']),
  );

  static Map<String, FieldDef> fieldsFromJson(dynamic j) {
    final m = _map(j);
    return {
      for (final e in m.entries) e.key: FieldDef.fromJson(e.key, _map(e.value)),
    };
  }
}

class SectionSchema {
  final String key;
  final String label;
  final String page; // home | packages | policies | global
  final Map<String, FieldDef> fields;
  const SectionSchema({
    required this.key,
    required this.label,
    required this.page,
    required this.fields,
  });
}

class GalleryCategory {
  final String key;
  final String label;
  const GalleryCategory(this.key, this.label);
}

class WebsiteSchema {
  final Map<String, SectionSchema> sections;
  final List<GalleryCategory> galleryCategories;
  final UploadRule? galleryUpload;
  final Map<String, FieldDef> packageFields;
  final Map<String, FieldDef> addonFields;

  const WebsiteSchema({
    required this.sections,
    required this.galleryCategories,
    required this.galleryUpload,
    required this.packageFields,
    required this.addonFields,
  });

  factory WebsiteSchema.fromJson(Map<String, dynamic> j) {
    final sections = <String, SectionSchema>{};
    _map(j['sections']).forEach((key, raw) {
      final s = _map(raw);
      sections[key] = SectionSchema(
        key: key,
        label: s['label']?.toString() ?? key,
        page: s['page']?.toString() ?? 'home',
        fields: FieldDef.fieldsFromJson(s['fields']),
      );
    });
    final gallery = _map(j['gallery']);
    return WebsiteSchema(
      sections: sections,
      galleryCategories: (gallery['categories'] as List? ?? const [])
          .map(
            (c) => GalleryCategory(
              _map(c)['key'].toString(),
              _map(c)['label'].toString(),
            ),
          )
          .toList(),
      galleryUpload: gallery['upload'] is Map
          ? UploadRule.fromJson(_map(gallery['upload']))
          : null,
      packageFields: FieldDef.fieldsFromJson(j['packageFields']),
      addonFields: FieldDef.fieldsFromJson(j['addonFields']),
    );
  }

  String categoryLabel(String key) => galleryCategories
      .firstWhere((c) => c.key == key, orElse: () => GalleryCategory(key, key))
      .label;
}

/// Section status: empty (never saved), draft (never published),
/// published (live = draft), changed (live, with unpublished edits).
class SectionSummary {
  final String key;
  final String label;
  final String page;
  final String status;
  final DateTime? draftUpdatedAt;
  final DateTime? publishedAt;

  const SectionSummary({
    required this.key,
    required this.label,
    required this.page,
    required this.status,
    this.draftUpdatedAt,
    this.publishedAt,
  });

  factory SectionSummary.fromJson(Map<String, dynamic> j) => SectionSummary(
    key: j['key']?.toString() ?? '',
    label: j['label']?.toString() ?? '',
    page: j['page']?.toString() ?? 'home',
    status: j['status']?.toString() ?? 'empty',
    draftUpdatedAt: _date(j['draftUpdatedAt']),
    publishedAt: _date(j['publishedAt']),
  );
}

class SectionDetail extends SectionSummary {
  final Map<String, dynamic> draft;
  final Map<String, dynamic>? published;
  final String? draftUpdatedBy;
  final String? publishedBy;

  /// The website's built-in text for this section (what visitors see until it is published).
  final Map<String, dynamic> defaults;

  const SectionDetail({
    required super.key,
    required super.label,
    required super.page,
    required super.status,
    super.draftUpdatedAt,
    super.publishedAt,
    required this.draft,
    this.published,
    this.draftUpdatedBy,
    this.publishedBy,
    this.defaults = const {},
  });

  factory SectionDetail.fromJson(Map<String, dynamic> j) {
    final s = SectionSummary.fromJson(j);
    return SectionDetail(
      key: s.key,
      label: s.label,
      page: s.page,
      status: s.status,
      draftUpdatedAt: s.draftUpdatedAt,
      publishedAt: s.publishedAt,
      draft: _map(j['draft']),
      published: j['published'] is Map ? _map(j['published']) : null,
      draftUpdatedBy: j['draftUpdatedBy']?.toString(),
      publishedBy: j['publishedBy']?.toString(),
      defaults: _map(j['defaults']),
    );
  }
}

/// An uploaded website image as stored in content: { url, publicId, width, height, alt }.
class WebsiteImage {
  final String url;
  final String publicId;
  final int? width;
  final int? height;
  final String alt;

  const WebsiteImage({
    required this.url,
    required this.publicId,
    this.width,
    this.height,
    this.alt = '',
  });

  factory WebsiteImage.fromJson(Map<String, dynamic> j) => WebsiteImage(
    url: j['url']?.toString() ?? '',
    publicId: j['publicId']?.toString() ?? '',
    width: (j['width'] as num?)?.toInt(),
    height: (j['height'] as num?)?.toInt(),
    alt: j['alt']?.toString() ?? '',
  );

  static WebsiteImage? tryParse(dynamic v) {
    if (v is! Map) return null;
    final img = WebsiteImage.fromJson(_map(v));
    return img.url.isEmpty ? null : img;
  }

  WebsiteImage copyWith({String? alt}) => WebsiteImage(
    url: url,
    publicId: publicId,
    width: width,
    height: height,
    alt: alt ?? this.alt,
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    'publicId': publicId,
    'width': width,
    'height': height,
    'alt': alt,
  };
}

class GalleryItem {
  final String id;
  final WebsiteImage image;
  final String category;
  final String title;
  final String description;
  final bool active;
  final bool featuredOnHome;
  final int sortOrder;

  const GalleryItem({
    required this.id,
    required this.image,
    required this.category,
    required this.title,
    required this.description,
    required this.active,
    required this.featuredOnHome,
    required this.sortOrder,
  });

  factory GalleryItem.fromJson(Map<String, dynamic> j) => GalleryItem(
    id: j['id']?.toString() ?? '',
    image: WebsiteImage.fromJson(_map(j['image'])),
    category: j['category']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    description: j['description']?.toString() ?? '',
    active: j['active'] != false,
    featuredOnHome: j['featuredOnHome'] == true,
    sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
  );
}

/// A CRM package with its website block. Name / price / advance are read-only here.
class WebsitePackage {
  final String id;
  final String name;
  final num price;
  final num? advanceAmount;
  final String crmDescription;
  final Map<String, dynamic> website;

  const WebsitePackage({
    required this.id,
    required this.name,
    required this.price,
    required this.advanceAmount,
    required this.crmDescription,
    required this.website,
  });

  bool get show => website['show'] == true;

  factory WebsitePackage.fromJson(Map<String, dynamic> j) => WebsitePackage(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    price: (j['price'] as num?) ?? 0,
    advanceAmount: j['advanceAmount'] as num?,
    crmDescription: j['crmDescription']?.toString() ?? '',
    website: _map(j['website']),
  );
}

class WebsiteAddon {
  final String id;
  final String name;
  final num price;
  final String status; // active | inactive (inactive never shows on the site)
  final String crmDescription;
  final Map<String, dynamic> website;

  const WebsiteAddon({
    required this.id,
    required this.name,
    required this.price,
    required this.status,
    required this.crmDescription,
    required this.website,
  });

  bool get show => website['show'] == true;
  bool get isActive => status == 'active';

  factory WebsiteAddon.fromJson(Map<String, dynamic> j) => WebsiteAddon(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    price: (j['price'] as num?) ?? 0,
    status: j['status']?.toString() ?? 'active',
    crmDescription: j['crmDescription']?.toString() ?? '',
    website: _map(j['website']),
  );
}

class WebsitePackagesData {
  final List<WebsitePackage> packages;
  final List<WebsiteAddon> addons;
  const WebsitePackagesData(this.packages, this.addons);
}

/// The server refused a save because some fields are not valid (HTTP 422).
class WebsiteValidationException implements Exception {
  final String message;
  final List<String> errors;
  const WebsiteValidationException(this.message, this.errors);

  @override
  String toString() => message;
}

/// One enquiry sent from the website's booking or contact form.
class WebsiteEnquiry {
  final String id;
  final String type; // booking | contact
  final String name;
  final String phone;
  final String email;
  final String venue;
  final String message;
  final String? eventDate; // YYYY-MM-DD
  final String slot;
  final String packageName;
  final List<String> addonNames;

  /// Wedding location picked on the website (package prices depend on it).
  final String district;
  final String region;

  /// Package (for that location) + add-ons, from CRM prices, as the bride saw it.
  final double? quotedTotal;
  final Map<String, String> utm;
  final String? leadId;
  final String? leadName;
  final String? leadStatus;
  final String leadAction; // created | existing | failed | ''
  final String status; // new | contacted | closed | spam
  final String note;
  final String? handledBy;
  final DateTime? createdAt;

  const WebsiteEnquiry({
    required this.id,
    required this.type,
    required this.name,
    required this.phone,
    required this.email,
    required this.venue,
    required this.message,
    required this.eventDate,
    required this.slot,
    required this.packageName,
    required this.addonNames,
    this.district = '',
    this.region = '',
    this.quotedTotal,
    required this.utm,
    required this.leadId,
    required this.leadName,
    required this.leadStatus,
    required this.leadAction,
    required this.status,
    required this.note,
    required this.handledBy,
    required this.createdAt,
  });

  factory WebsiteEnquiry.fromJson(Map<String, dynamic> j) {
    final lead = j['lead'] is Map
        ? (j['lead'] as Map).cast<String, dynamic>()
        : null;
    final utm = j['utm'] is Map
        ? (j['utm'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return WebsiteEnquiry(
      id: j['id']?.toString() ?? '',
      type: j['type']?.toString() ?? 'contact',
      name: j['name']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      venue: j['venue']?.toString() ?? '',
      message: j['message']?.toString() ?? '',
      eventDate: j['eventDate']?.toString(),
      slot: j['slot']?.toString() ?? '',
      packageName: j['packageName']?.toString() ?? '',
      addonNames: (j['addonNames'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      district: j['district']?.toString() ?? '',
      region: j['region']?.toString() ?? '',
      quotedTotal: (j['quotedTotal'] as num?)?.toDouble(),
      utm: {
        for (final e in utm.entries)
          if ((e.value?.toString() ?? '').isNotEmpty) e.key: e.value.toString(),
      },
      leadId: lead?['id']?.toString(),
      leadName: lead?['name']?.toString(),
      leadStatus: lead?['status']?.toString(),
      leadAction: j['leadAction']?.toString() ?? '',
      status: j['status']?.toString() ?? 'new',
      note: j['note']?.toString() ?? '',
      handledBy: j['handledBy']?.toString(),
      createdAt: _date(j['createdAt']),
    );
  }
}

class WebsiteEnquiryPage {
  final List<WebsiteEnquiry> items;
  final int page;
  final int pages;
  final int total;
  final Map<String, int> counts; // per status
  const WebsiteEnquiryPage(
    this.items,
    this.page,
    this.pages,
    this.total,
    this.counts,
  );
}
