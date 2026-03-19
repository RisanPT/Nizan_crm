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

class ServicePackage {
  final String id;
  final String name;
  final double price;
  final double advanceAmount;
  final String description;
  final List<RegionalPrice> regionPrices;

  const ServicePackage({
    required this.id,
    required this.name,
    required this.price,
    required this.advanceAmount,
    required this.description,
    required this.regionPrices,
  });

  double effectivePriceForRegion(String? regionId) {
    if (regionId == null || regionId.isEmpty) return price;
    final match = regionPrices.cast<RegionalPrice?>().firstWhere(
      (item) => item?.regionId == regionId,
      orElse: () => null,
    );
    return match?.price ?? price;
  }

  factory ServicePackage.fromJson(Map<String, dynamic> json) {
    final regionPricesJson = json['regionPrices'] as List? ?? const [];
    return ServicePackage(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      advanceAmount: (json['advanceAmount'] as num?)?.toDouble() ?? 3000,
      description: json['description'] as String? ?? '',
      regionPrices: regionPricesJson
          .map((item) => RegionalPrice.fromJson(item as Map<String, dynamic>))
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
    };
  }
}
