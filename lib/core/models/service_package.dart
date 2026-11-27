class RegionalPrice {
  final String regionId;
  final String regionName;
  final double price;

  const RegionalPrice({
    required this.regionId,
    required this.regionName,
    required this.price,
  });

  factory RegionalPrice.fromJson(Map<String, dynamic> json) {
    final region = json['region'];
    return RegionalPrice(
      regionId: region is Map<String, dynamic>
          ? (region['_id'] as String? ?? region['id'] as String? ?? '')
          : (json['region'] as String? ?? ''),
      regionName: region is Map<String, dynamic>
          ? (region['name'] as String? ?? '')
          : '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'region': regionId, 'price': price};
  }
}

class DistrictPrice {
  final String districtId;
  final String districtName;
  final double price;

  const DistrictPrice({
    required this.districtId,
    required this.districtName,
    required this.price,
  });

  factory DistrictPrice.fromJson(Map<String, dynamic> json) {
    final district = json['district'];
    return DistrictPrice(
      districtId: district is Map<String, dynamic>
          ? (district['_id'] as String? ?? district['id'] as String? ?? '')
          : (json['district'] as String? ?? ''),
      districtName: district is Map<String, dynamic>
          ? (district['name'] as String? ?? '')
          : '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'district': districtId, 'price': price};
  }
}

/// What a package includes, for the Bridal Quote's "What's Included" table.
/// Set in Services → Packages (Add / Edit package).
class QuoteInclusions {
  /// Free-text rows, e.g. "Airbrush" / "Premium & high-end".
  final String technique;
  final String products;

  /// Ticked rows from [checks].
  final List<String> included;

  const QuoteInclusions({
    this.technique = '',
    this.products = '',
    this.included = const [],
  });

  static const techniqueLabel = 'Makeup technique';
  static const productsLabel = 'Products used';

  /// The yes / no rows, in table order.
  static const checks = [
    'Professional lenses & lashes',
    'Advanced bridal hairstyling',
    'Hair extensions, when required',
    'Professional saree draping',
    'Fully bespoke artistry & styling direction',
    'Dedicated pre-wedding styling consultations',
    'Optional offline styling support',
    'Personalised bridal styling & finishing',
  ];

  /// Every row, in table order.
  static const labels = [techniqueLabel, productsLabel, ...checks];

  /// Built-in values for the packages the quote knew before inclusions could
  /// be set in Services (matched by lower-case name). Used until the package
  /// is saved with its own inclusions.
  static const Map<String, QuoteInclusions> _builtIn = {
    'platinum': QuoteInclusions(
      technique: 'HD',
      products: 'Premium, skin-friendly',
      included: [
        'Professional lenses & lashes',
        'Advanced bridal hairstyling',
        'Hair extensions, when required',
      ],
    ),
    'airbrush': QuoteInclusions(
      technique: 'Airbrush',
      products: 'Premium & high-end',
      included: [
        'Professional lenses & lashes',
        'Advanced bridal hairstyling',
        'Hair extensions, when required',
        'Professional saree draping',
      ],
    ),
    'team n royal': QuoteInclusions(
      technique: 'Airbrush',
      products: 'Exclusive luxury',
      included: checks,
    ),
  };

  static QuoteInclusions? builtInFor(String packageName) =>
      _builtIn[packageName.trim().toLowerCase()];

  factory QuoteInclusions.fromJson(Map<String, dynamic> json) => QuoteInclusions(
        technique: (json['technique'] as String? ?? '').trim(),
        products: (json['products'] as String? ?? '').trim(),
        included: [
          for (final x in json['included'] as List? ?? const [])
            if (x is String && x.trim().isNotEmpty) x.trim(),
        ],
      );

  Map<String, dynamic> toJson() =>
      {'technique': technique, 'products': products, 'included': included};
}

/// Booking advance rule (same in New booking, Edit booking and the Bridal Quote):
///  • the package's own advance (Services → Packages), whatever the district;
///    none set → 15% of the price, at least ₹5,000 (never above the price);
///  • with add-ons: 15% of package + add-ons (before discount, travel not
///    counted) when that is higher than the package's advance.
const kAdvancePercent = 15;
const kMinAdvance = 5000.0;

double defaultAdvanceForPrice(double price) {
  if (price <= 0) return 0;
  final pct = (price * kAdvancePercent / 100).roundToDouble();
  final a = pct < kMinAdvance ? kMinAdvance : pct;
  return a > price ? price : a;
}

class ServicePackage {
  final String id;
  final String name;
  final double price;
  final double advanceAmount;
  final String description;
  final List<RegionalPrice> regionPrices;
  final List<DistrictPrice> districtPrices;

  /// Saved quote inclusions; null when never set in Services.
  final QuoteInclusions? quoteInclusions;

  const ServicePackage({
    required this.id,
    required this.name,
    required this.price,
    required this.advanceAmount,
    required this.description,
    required this.regionPrices,
    required this.districtPrices,
    this.quoteInclusions,
  });

  /// Saved inclusions, else the built-in ones for a known package name.
  QuoteInclusions? get effectiveQuoteInclusions =>
      quoteInclusions ?? QuoteInclusions.builtInFor(name);

  /// Advance for this package at [price] (the price quoted / booked) with
  /// [addons] worth of add-ons. See [defaultAdvanceForPrice] for the rule.
  double bookingAdvance({required double price, double addons = 0}) {
    final base = advanceAmount > 0 ? advanceAmount : defaultAdvanceForPrice(price);
    if (addons <= 0) return base;
    final pct = ((price + addons) * kAdvancePercent / 100).roundToDouble();
    return pct > base ? pct : base;
  }

  double effectivePriceForRegion(String? regionId) {
    if (regionId == null || regionId.isEmpty) return price;
    final match = regionPrices.cast<RegionalPrice?>().firstWhere(
      (item) => item?.regionId == regionId,
      orElse: () => null,
    );
    return match?.price ?? price;
  }

  double effectivePriceForDistrict(String? districtId) {
    if (districtId == null || districtId.isEmpty) return price;
    final match = districtPrices.cast<DistrictPrice?>().firstWhere(
      (item) => item?.districtId == districtId,
      orElse: () => null,
    );
    return match?.price ?? price;
  }

  factory ServicePackage.fromJson(Map<String, dynamic> json) {
    final regionPricesJson = json['regionPrices'] as List? ?? const [];
    final districtPricesJson = json['districtPrices'] as List? ?? const [];
    return ServicePackage(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      advanceAmount: (json['advanceAmount'] as num?)?.toDouble() ?? 3000,
      description: json['description'] as String? ?? '',
      regionPrices: regionPricesJson
          .map((item) => RegionalPrice.fromJson(item as Map<String, dynamic>))
          .toList(),
      districtPrices: districtPricesJson
          .map((item) => DistrictPrice.fromJson(item as Map<String, dynamic>))
          .toList(),
      quoteInclusions: json['quoteInclusions'] is Map
          ? QuoteInclusions.fromJson((json['quoteInclusions'] as Map).cast<String, dynamic>())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'advanceAmount': advanceAmount,
      'description': description,
      'regionPrices': regionPrices.map((item) => item.toJson()).toList(),
      'districtPrices': districtPrices.map((item) => item.toJson()).toList(),
      if (quoteInclusions != null) 'quoteInclusions': quoteInclusions!.toJson(),
    };
  }
}
