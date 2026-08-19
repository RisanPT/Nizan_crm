// Department entity — first-class org unit grouped into Administrative /
// Creative divisions. Carries the delegation boundary (allowedRoleKeys) and the
// geography scope (zone/state/region ids) for later phases.

const kDivisions = <String>['administrative', 'creative'];
String divisionLabel(String d) => d == 'creative' ? 'Creative' : 'Administrative';

/// Best-effort mapping of a Role.key to the department it belongs to — so
/// pickers can show "this department's people". Returns null for cross-cutting
/// roles (admin/manager) that aren't tied to a single department.
String? departmentKeyForRole(String role) {
  final r = role.toLowerCase().trim();
  if (r.startsWith('sales')) return 'sales';
  if (r.startsWith('hr')) return 'hr';
  if (r.startsWith('marketing')) return 'marketing';
  if (r.startsWith('crm')) return 'crm';
  if (r.startsWith('accounts')) return 'accounts';
  if (r.startsWith('finance')) return 'finance';
  if (r == 'artist') return 'artist';
  if (r == 'driver' || r.startsWith('fleet')) return 'fleet';
  if (r.startsWith('it')) return 'it';
  return null; // admin, manager, inventory_manager, custom cross-dept roles
}

/// A staff member (Employee) shown under a department.
class DeptMember {
  final String id, name, email, role, category, department, status;
  final bool fromTimebox;
  const DeptMember({
    this.id = '', this.name = '', this.email = '', this.role = '',
    this.category = '', this.department = '', this.status = 'active', this.fromTimebox = false,
  });
  factory DeptMember.fromJson(Map<String, dynamic> j) => DeptMember(
        id: j['_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        role: j['role'] as String? ?? '',
        category: j['category'] as String? ?? '',
        department: j['department'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        fromTimebox: j['timeboxEmployeeId'] != null,
      );
}

class DeptHead {
  final String id, name, email, role;
  const DeptHead({this.id = '', this.name = '', this.email = '', this.role = ''});
  factory DeptHead.fromJson(Map<String, dynamic> j) => DeptHead(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        role: j['role'] as String? ?? '',
      );
}

class Department {
  final String id, key, name, division, description;
  final DeptHead? head;
  final List<String> allowedRoleKeys;
  final List<String> zoneIds, stateIds, regionIds;
  final bool active, isSystem;
  final int memberCount;

  const Department({
    this.id = '',
    this.key = '',
    this.name = '',
    this.division = 'administrative',
    this.description = '',
    this.head,
    this.allowedRoleKeys = const [],
    this.zoneIds = const [],
    this.stateIds = const [],
    this.regionIds = const [],
    this.active = true,
    this.isSystem = false,
    this.memberCount = 0,
  });

  static List<String> _ids(dynamic v) =>
      (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();

  factory Department.fromJson(Map<String, dynamic> j) => Department(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        key: j['key'] as String? ?? '',
        name: j['name'] as String? ?? '',
        division: j['division'] as String? ?? 'administrative',
        description: j['description'] as String? ?? '',
        head: j['head'] is Map ? DeptHead.fromJson(j['head'] as Map<String, dynamic>) : null,
        allowedRoleKeys: _ids(j['allowedRoleKeys']),
        zoneIds: _ids(j['zoneIds']),
        stateIds: _ids(j['stateIds']),
        regionIds: _ids(j['regionIds']),
        active: j['active'] as bool? ?? true,
        isSystem: j['isSystem'] as bool? ?? false,
        memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (key.isNotEmpty) 'key': key,
        'name': name,
        'division': division,
        'description': description,
        'head': head?.id.isNotEmpty == true ? head!.id : null,
        'allowedRoleKeys': allowedRoleKeys,
        'zoneIds': zoneIds,
        'stateIds': stateIds,
        'regionIds': regionIds,
        'active': active,
      };
}
