import 'dart:convert';

class AuthSession {
  final String token;
  final String userId;
  final String name;
  final String email;
  final String role;
  /// Feature keys granted to this user's role, resolved by the backend from
  /// the editable Role record. Empty means "not supplied" — callers fall back
  /// to the built-in role defaults so older sessions keep working.
  final List<String> permissions;
  /// Landing page configured for this role (blank = use the built-in default).
  final String homeRoute;
  /// Whether this account may access the Inventory feature (artist opt-in).
  final bool inventoryAccess;
  /// The Employee record linked to this user (set for artist accounts).
  final String employeeId;
  final String zoneId;
  final String stateId;
  final String regionId;
  final String districtId;
  final String pincodeId;

  const AuthSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.permissions = const [],
    this.homeRoute = '',
    this.inventoryAccess = false,
    this.employeeId = '',
    this.zoneId = '',
    this.stateId = '',
    this.regionId = '',
    this.districtId = '',
    this.pincodeId = '',
  });

  Map<String, dynamic> toJson() => {
    'token': token,
    'user': {
      'id': userId,
      'name': name,
      'email': email,
      'role': role,
      'permissions': permissions,
      'homeRoute': homeRoute,
      'inventoryAccess': inventoryAccess,
      'employeeId': employeeId,
      'zoneId': zoneId,
      'stateId': stateId,
      'regionId': regionId,
      'districtId': districtId,
      'pincodeId': pincodeId,
    },
  };

  String toStorageValue() => jsonEncode(toJson());

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>? ?? const {});

    return AuthSession(
      token: json['token'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      name: user['name'] as String? ?? '',
      email: user['email'] as String? ?? '',
      role: user['role'] as String? ?? '',
      permissions: ((user['permissions'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      homeRoute: user['homeRoute'] as String? ?? '',
      inventoryAccess: user['inventoryAccess'] as bool? ?? false,
      employeeId: user['employeeId'] as String? ?? '',
      zoneId: user['zoneId'] as String? ?? '',
      stateId: user['stateId'] as String? ?? '',
      regionId: user['regionId'] as String? ?? '',
      districtId: user['districtId'] as String? ?? '',
      pincodeId: user['pincodeId'] as String? ?? '',
    );
  }

  factory AuthSession.fromStorageValue(String raw) {
    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
