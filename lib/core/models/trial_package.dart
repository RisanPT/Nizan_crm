class TrialPackage {
  final String id;
  final String name;
  final double price;
  final String description;

  const TrialPackage({
    required this.id,
    required this.name,
    required this.price,
    this.description = '',
  });

  factory TrialPackage.fromJson(Map<String, dynamic> json) {
    return TrialPackage(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'description': description,
    };
  }

  TrialPackage copyWith({
    String? id,
    String? name,
    double? price,
    String? description,
  }) {
    return TrialPackage(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
    );
  }
}
