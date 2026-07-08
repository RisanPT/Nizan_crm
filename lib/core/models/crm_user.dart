class CrmUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool active;
  final bool inventoryAccess;
  final String employeeId;
  final String zoneId;
  final String stateId;
  final String regionId;
  final String districtId;
  final String pincodeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CrmUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.inventoryAccess = false,
    this.employeeId = '',
    this.zoneId = '',
    this.stateId = '',
    this.regionId = '',
    this.districtId = '',
    this.pincodeId = '',
    this.createdAt,
    this.updatedAt,
  });

  factory CrmUser.fromJson(Map<String, dynamic> json) {
    return CrmUser(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'manager',
      active: json['active'] as bool? ?? true,
      inventoryAccess: json['inventoryAccess'] as bool? ?? false,
      employeeId: json['employeeId'] as String? ?? '',
      zoneId: json['zoneId'] as String? ?? '',
      stateId: json['stateId'] as String? ?? '',
      regionId: json['regionId'] as String? ?? '',
      districtId: json['districtId'] as String? ?? '',
      pincodeId: json['pincodeId'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  CrmUser copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    bool? active,
    bool? inventoryAccess,
    String? employeeId,
    String? zoneId,
    String? stateId,
    String? regionId,
    String? districtId,
    String? pincodeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CrmUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      active: active ?? this.active,
      inventoryAccess: inventoryAccess ?? this.inventoryAccess,
      employeeId: employeeId ?? this.employeeId,
      zoneId: zoneId ?? this.zoneId,
      stateId: stateId ?? this.stateId,
      regionId: regionId ?? this.regionId,
      districtId: districtId ?? this.districtId,
      pincodeId: pincodeId ?? this.pincodeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
