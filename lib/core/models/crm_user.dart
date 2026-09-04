class CrmUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool active;
  final bool inventoryAccess;
  /// Artist who also runs the studio inventory (workspace-switcher dual role).
  final bool inventoryManage;
  final String employeeId;
  /// The Department this user belongs to (Department entity id), or ''.
  final String departmentId;
  final String zoneId;
  final String stateId;
  final String regionId;
  final String districtId;
  final String pincodeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// True when this user can manage (add/edit/deactivate) staff in their own department.
  final bool isDepartmentHead;
  final bool artistHead;
  /// The user-ID of the Department Head who created this user; blank for Admin-created users.
  final String managedBy;

  const CrmUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.inventoryAccess = false,
    this.inventoryManage = false,
    this.employeeId = '',
    this.departmentId = '',
    this.zoneId = '',
    this.stateId = '',
    this.regionId = '',
    this.districtId = '',
    this.pincodeId = '',
    this.createdAt,
    this.updatedAt,
    this.isDepartmentHead = false,
    this.artistHead = false,
    this.managedBy = '',
  });

  factory CrmUser.fromJson(Map<String, dynamic> json) {
    return CrmUser(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'manager',
      active: json['active'] as bool? ?? true,
      inventoryAccess: json['inventoryAccess'] as bool? ?? false,
      inventoryManage: json['inventoryManage'] as bool? ?? false,
      employeeId: json['employeeId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      zoneId: json['zoneId'] as String? ?? '',
      stateId: json['stateId'] as String? ?? '',
      regionId: json['regionId'] as String? ?? '',
      districtId: json['districtId'] as String? ?? '',
      pincodeId: json['pincodeId'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      isDepartmentHead: json['isDepartmentHead'] as bool? ?? false,
      artistHead: json['artistHead'] as bool? ?? false,
      managedBy: json['managedBy'] as String? ?? '',
    );
  }

  CrmUser copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    bool? active,
    bool? inventoryAccess,
    bool? inventoryManage,
    String? employeeId,
    String? departmentId,
    String? zoneId,
    String? stateId,
    String? regionId,
    String? districtId,
    String? pincodeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDepartmentHead,
    bool? artistHead,
    String? managedBy,
  }) {
    return CrmUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      active: active ?? this.active,
      inventoryAccess: inventoryAccess ?? this.inventoryAccess,
      inventoryManage: inventoryManage ?? this.inventoryManage,
      employeeId: employeeId ?? this.employeeId,
      departmentId: departmentId ?? this.departmentId,
      zoneId: zoneId ?? this.zoneId,
      stateId: stateId ?? this.stateId,
      regionId: regionId ?? this.regionId,
      districtId: districtId ?? this.districtId,
      pincodeId: pincodeId ?? this.pincodeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDepartmentHead: isDepartmentHead ?? this.isDepartmentHead,
      artistHead: artistHead ?? this.artistHead,
      managedBy: managedBy ?? this.managedBy,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
