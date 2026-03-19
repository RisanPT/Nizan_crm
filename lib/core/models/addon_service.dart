class AddonService {
  final String id;
  final String name;
  final double price;
  final String description;
  final String status;

  const AddonService({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.status,
  });

  factory AddonService.fromJson(Map<String, dynamic> json) {
    return AddonService(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'status': status,
    };
  }
}
