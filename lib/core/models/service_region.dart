class ServiceRegion {
  final String id;
  final String name;
  final String status;
  final String stateId;
  final String stateName;

  const ServiceRegion({
    required this.id,
    required this.name,
    required this.status,
    required this.stateId,
    required this.stateName,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory ServiceRegion.fromJson(Map<String, dynamic> json) {
    final state = json['state'];
    return ServiceRegion(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      stateId: state is Map<String, dynamic>
          ? (state['_id'] as String? ?? '')
          : (json['state'] as String? ?? ''),
      stateName: state is Map<String, dynamic>
          ? (state['name'] as String? ?? '')
          : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'stateId': stateId,
    };
  }
}
