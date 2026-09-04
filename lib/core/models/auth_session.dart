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
  /// Whether this artist ALSO runs the studio inventory — grants the full
  /// inventory-manager toolset and enables the in-app workspace switcher.
  final bool inventoryManage;
  /// The Employee record linked to this user (set for artist accounts).
  final String employeeId;
  /// The Department this user belongs to (Department entity id), or ''.
  final String departmentId;
  /// The display name of that department (e.g. 'IT'), resolved by the backend.
  /// Used to scope/lock departmental expense submission to the head's own dept.
  final String departmentName;
  final String zoneId;
  final String stateId;
  final String regionId;
  final String districtId;
  final String pincodeId;
  /// True when this user is a Department Head and can manage their own team.
  final bool isDepartmentHead;
  /// True when this artist ALSO leads the artist team — grants the Artist Head
  /// dashboard on top of their artist role.
  final bool artistHead;

  const AuthSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.permissions = const [],
    this.homeRoute = '',
    this.inventoryAccess = false,
    this.inventoryManage = false,
    this.employeeId = '',
    this.departmentId = '',
    this.departmentName = '',
    this.zoneId = '',
    this.stateId = '',
    this.regionId = '',
    this.districtId = '',
    this.pincodeId = '',
    this.isDepartmentHead = false,
    this.artistHead = false,
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
      'inventoryManage': inventoryManage,
      'employeeId': employeeId,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'zoneId': zoneId,
      'stateId': stateId,
      'regionId': regionId,
      'districtId': districtId,
      'pincodeId': pincodeId,
      'isDepartmentHead': isDepartmentHead,
      'artistHead': artistHead,
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
      inventoryManage: user['inventoryManage'] as bool? ?? false,
      employeeId: user['employeeId'] as String? ?? '',
      departmentId: user['departmentId'] as String? ?? '',
      departmentName: user['departmentName'] as String? ?? '',
      zoneId: user['zoneId'] as String? ?? '',
      stateId: user['stateId'] as String? ?? '',
      regionId: user['regionId'] as String? ?? '',
      districtId: user['districtId'] as String? ?? '',
      pincodeId: user['pincodeId'] as String? ?? '',
      isDepartmentHead: user['isDepartmentHead'] as bool? ?? false,
      artistHead: user['artistHead'] as bool? ?? false,
    );
  }

  factory AuthSession.fromStorageValue(String raw) {
    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
