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

class ServicePackage {
  final String id;
  final String name;
  final double price;
  final double advanceAmount;
  final String description;
  final List<RegionalPrice> regionPrices;
  final List<DistrictPrice> districtPrices;

  const ServicePackage({
    required this.id,
    required this.name,
    required this.price,
    required this.advanceAmount,
    required this.description,
    required this.regionPrices,
    required this.districtPrices,
  });

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
    };
  }
}
