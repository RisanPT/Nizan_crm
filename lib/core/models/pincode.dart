class Pincode {
  final String id;
  final String code;
  final String districtId;
  final String districtName;
  final String status;

  const Pincode({
    required this.id,
    required this.code,
    required this.districtId,
    required this.districtName,
    required this.status,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory Pincode.fromJson(Map<String, dynamic> json) {
    final district = json['district'];
    return Pincode(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      districtId: district is Map<String, dynamic>
          ? (district['_id'] as String? ?? '')
          : (json['district'] as String? ?? ''),
      districtName: district is Map<String, dynamic>
          ? (district['name'] as String? ?? '')
          : '',
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'districtId': districtId,
      'status': status,
    };
  }
}
