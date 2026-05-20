class ZoneModel {
  final String id;
  final String name;
  final String status;

  const ZoneModel({
    required this.id,
    required this.name,
    required this.status,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
    };
  }
}
