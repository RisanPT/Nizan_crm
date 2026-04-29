class CrmUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool active;
  final String employeeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CrmUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.employeeId = '',
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
      employeeId: json['employeeId'] as String? ?? '',
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
    String? employeeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CrmUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      active: active ?? this.active,
      employeeId: employeeId ?? this.employeeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
