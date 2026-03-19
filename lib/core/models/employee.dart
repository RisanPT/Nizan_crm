class Employee {
  final String id;
  final String name;
  final String email;
  final String type;
  final String artistRole;
  final String specialization;
  final String phone;
  final String status;
  final String regionId;
  final String regionName;

  const Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.type,
    required this.artistRole,
    required this.specialization,
    required this.phone,
    required this.status,
    required this.regionId,
    required this.regionName,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    final region = json['regionId'];
    return Employee(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      type: json['type'] as String? ?? 'outsource',
      artistRole: json['artistRole'] as String? ?? 'artist',
      specialization: json['specialization'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      regionId: region is Map<String, dynamic>
          ? (region['_id'] as String? ?? '')
          : (json['regionId'] as String? ?? ''),
      regionName: region is Map<String, dynamic>
          ? (region['name'] as String? ?? '')
          : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'type': type,
      'artistRole': artistRole,
      'specialization': specialization,
      'phone': phone,
      'status': status,
      'regionId': regionId,
    };
  }
}
