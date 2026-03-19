class ServiceRegion {
  final String id;
  final String name;
  final String status;

  const ServiceRegion({
    required this.id,
    required this.name,
    required this.status,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory ServiceRegion.fromJson(Map<String, dynamic> json) {
    return ServiceRegion(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'status': status};
  }
}
