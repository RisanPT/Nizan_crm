import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/website/data/visitor_stats.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Team N Website admin API (`/api/website/admin`).
class WebsiteService {
  final Dio _dio;
  WebsiteService(this._dio);

  static const _base = '/website/admin';

  Map<String, dynamic> _body(Response res) =>
      (res.data as Map).cast<String, dynamic>();

  /// 422 → [WebsiteValidationException] with the server's list of problems;
  /// anything else → [AppException] with a friendly message.
  Never _fail(Object e, String action) {
    if (e is DioException &&
        e.response?.statusCode == 422 &&
        e.response?.data is Map) {
      final data = (e.response!.data as Map).cast<String, dynamic>();
      final errors = (data['errors'] as List? ?? const [])
          .map((x) => x.toString())
          .toList();
      throw WebsiteValidationException(
        data['message']?.toString() ?? 'Some fields are not valid.',
        errors,
      );
    }
    throw AppException(e, action: action);
  }

  Future<WebsiteSchema> getSchema() async {
    try {
      return WebsiteSchema.fromJson(_body(await _dio.get('$_base/schema')));
    } catch (e) {
      _fail(e, 'load the website settings');
    }
  }

  // ── Sections ────────────────────────────────────────────────────────────
  Future<List<SectionSummary>> listSections() async {
    try {
      final data = _body(await _dio.get('$_base/sections'));
      return (data['sections'] as List)
          .map(
            (s) => SectionSummary.fromJson((s as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (e) {
      _fail(e, 'load website sections');
    }
  }

  Future<SectionDetail> getSection(String key) async {
    try {
      return SectionDetail.fromJson(
        _body(await _dio.get('$_base/sections/$key')),
      );
    } catch (e) {
      _fail(e, 'load the section');
    }
  }

  Future<void> saveDraft(String key, Map<String, dynamic> data) async {
    try {
      await _dio.put('$_base/sections/$key', data: data);
    } catch (e) {
      _fail(e, 'save the draft');
    }
  }

  Future<void> publish(String key) async {
    try {
      await _dio.post('$_base/sections/$key/publish');
    } catch (e) {
      _fail(e, 'publish the section');
    }
  }

  Future<void> revert(String key) async {
    try {
      await _dio.post('$_base/sections/$key/revert');
    } catch (e) {
      _fail(e, 'discard the changes');
    }
  }

  // ── Images ──────────────────────────────────────────────────────────────
  /// Uploads one image for a field, e.g. ('hero', 'imageDesktop'),
  /// ('gallery', 'image') or ('package', 'coverImage'). The server checks the
  /// real file type, size, pixel size and shape before storing it.
  Future<WebsiteImage> uploadImage({
    required String section,
    required String field,
    required Uint8List bytes,
    required String filename,
    required String mime,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(mime),
        ),
      });
      final data = _body(
        await _dio.post('$_base/media/$section/$field', data: form),
      );
      return WebsiteImage.fromJson(
        (data['value'] as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      _fail(e, 'upload the image');
    }
  }

  // ── Gallery ─────────────────────────────────────────────────────────────
  Future<List<GalleryItem>> listGallery() async {
    try {
      final data = _body(await _dio.get('$_base/gallery'));
      return (data['items'] as List)
          .map((g) => GalleryItem.fromJson((g as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      _fail(e, 'load the gallery');
    }
  }

  Future<void> createGalleryItem(Map<String, dynamic> body) async {
    try {
      await _dio.post('$_base/gallery', data: body);
    } catch (e) {
      _fail(e, 'add the photo');
    }
  }

  Future<void> updateGalleryItem(String id, Map<String, dynamic> body) async {
    try {
      await _dio.put('$_base/gallery/$id', data: body);
    } catch (e) {
      _fail(e, 'update the photo');
    }
  }

  Future<void> reorderGallery(List<String> ids) async {
    try {
      await _dio.put('$_base/gallery/reorder', data: {'ids': ids});
    } catch (e) {
      _fail(e, 'save the order');
    }
  }

  Future<void> deleteGalleryItem(String id) async {
    try {
      await _dio.delete('$_base/gallery/$id');
    } catch (e) {
      _fail(e, 'remove the photo');
    }
  }

  // ── Packages on website ─────────────────────────────────────────────────
  Future<WebsitePackagesData> listPackages() async {
    try {
      final data = _body(await _dio.get('$_base/packages'));
      return WebsitePackagesData(
        (data['packages'] as List)
            .map(
              (p) =>
                  WebsitePackage.fromJson((p as Map).cast<String, dynamic>()),
            )
            .toList(),
        (data['addons'] as List)
            .map(
              (a) => WebsiteAddon.fromJson((a as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
    } catch (e) {
      _fail(e, 'load packages');
    }
  }

  Future<void> updatePackageWebsite(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      await _dio.put('$_base/packages/$id', data: body);
    } catch (e) {
      _fail(e, 'update the package');
    }
  }

  Future<void> updateAddonWebsite(String id, Map<String, dynamic> body) async {
    try {
      await _dio.put('$_base/addons/$id', data: body);
    } catch (e) {
      _fail(e, 'update the add-on');
    }
  }

  // ── Enquiries ───────────────────────────────────────────────────────────
  Future<WebsiteEnquiryPage> listEnquiries({
    String status = '',
    int page = 1,
  }) async {
    try {
      final data = _body(
        await _dio.get(
          '$_base/enquiries',
          queryParameters: {
            if (status.isNotEmpty) 'status': status,
            'page': page,
          },
        ),
      );
      final counts = (data['counts'] as Map? ?? const {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      );
      return WebsiteEnquiryPage(
        (data['items'] as List)
            .map(
              (e) =>
                  WebsiteEnquiry.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
        (data['page'] as num?)?.toInt() ?? page,
        (data['pages'] as num?)?.toInt() ?? 1,
        (data['total'] as num?)?.toInt() ?? 0,
        counts,
      );
    } catch (e) {
      _fail(e, 'load website enquiries');
    }
  }

  Future<void> updateEnquiry(String id, {String? status, String? note}) async {
    try {
      await _dio.patch(
        '$_base/enquiries/$id',
        data: {'status': ?status, 'note': ?note},
      );
    } catch (e) {
      _fail(e, 'update the enquiry');
    }
  }

  // ── Draft preview ───────────────────────────────────────────────────────
  /// A one-hour link token that shows the website with saved drafts.
  // ── Visitors ────────────────────────────────────────────────────────────
  Future<VisitorStats> getVisitorStats(int days) async {
    try {
      return VisitorStats.fromJson(
        _body(await _dio.get('$_base/visitors', queryParameters: {'days': days})),
      );
    } catch (e) {
      _fail(e, 'load website visitors');
    }
  }

  Future<String> getPreviewToken() async {
    try {
      final data = _body(await _dio.post('$_base/preview-token'));
      return data['token'].toString();
    } catch (e) {
      _fail(e, 'open the preview');
    }
  }
}

/// Visitor counts for the last [days] days (7, 30 or 90).
final websiteVisitorsProvider = FutureProvider.family<VisitorStats, int>((
  ref,
  days,
) async {
  return ref.watch(websiteServiceProvider).getVisitorStats(days);
});

final websiteServiceProvider = Provider<WebsiteService>(
  (ref) => WebsiteService(ref.watch(dioProvider)),
);

final websiteSchemaProvider = FutureProvider<WebsiteSchema>((ref) async {
  return ref.watch(websiteServiceProvider).getSchema();
});

final websiteSectionsProvider = FutureProvider<List<SectionSummary>>((
  ref,
) async {
  return ref.watch(websiteServiceProvider).listSections();
});

final websiteSectionProvider = FutureProvider.family<SectionDetail, String>((
  ref,
  key,
) async {
  return ref.watch(websiteServiceProvider).getSection(key);
});

final websiteGalleryProvider = FutureProvider<List<GalleryItem>>((ref) async {
  return ref.watch(websiteServiceProvider).listGallery();
});

final websitePackagesProvider = FutureProvider<WebsitePackagesData>((
  ref,
) async {
  return ref.watch(websiteServiceProvider).listPackages();
});

/// Enquiries, keyed by (status filter, page). status '' = all.
final websiteEnquiriesProvider =
    FutureProvider.family<WebsiteEnquiryPage, ({String status, int page})>((
      ref,
      key,
    ) async {
      return ref
          .watch(websiteServiceProvider)
          .listEnquiries(status: key.status, page: key.page);
    });

/// The public website, for the draft Preview button.
/// Build with --dart-define=WEBSITE_URL=http://192.168.29.89:5173 to preview a local site.
const websiteBaseUrl = String.fromEnvironment(
  'WEBSITE_URL',
  defaultValue: 'https://teamnmakeovers.com',
);
