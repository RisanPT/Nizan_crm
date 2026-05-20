class District {
  final String id;
  final String name;
  final String regionId;
  final String regionName;
  final String status;

  const District({
    required this.id,
    required this.name,
    required this.regionId,
    required this.regionName,
    required this.status,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory District.fromJson(Map<String, dynamic> json) {
    final region = json['region'];
    return District(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      regionId: region is Map<String, dynamic>
          ? (region['_id'] as String? ?? '')
          : (json['region'] as String? ?? ''),
      regionName: region is Map<String, dynamic>
          ? (region['name'] as String? ?? '')
          : '',
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'regionId': regionId,
      'status': status,
    };
  }
}
