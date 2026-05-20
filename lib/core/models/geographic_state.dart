class GeographicState {
  final String id;
  final String name;
  final String zoneId;
  final String zoneName;
  final String status;

  const GeographicState({
    required this.id,
    required this.name,
    required this.zoneId,
    required this.zoneName,
    required this.status,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory GeographicState.fromJson(Map<String, dynamic> json) {
    final zone = json['zone'];
    return GeographicState(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      zoneId: zone is Map<String, dynamic>
          ? (zone['_id'] as String? ?? '')
          : (json['zone'] as String? ?? ''),
      zoneName: zone is Map<String, dynamic>
          ? (zone['name'] as String? ?? '')
          : '',
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'zoneId': zoneId,
      'status': status,
    };
  }
}
