// Designation model — mirrors backend/models/Designation.js.

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String _idOf(dynamic v) {
  if (v is Map) return (v['_id'] as String?) ?? '';
  return (v as String?) ?? '';
}

String _nameOf(dynamic v) {
  if (v is Map) return (v['name'] as String?) ?? '';
  return '';
}

class Designation {
  final String id;
  final String name;
  final String code;
  final String departmentId;
  final String departmentName;
  final int level;
  final String description;
  final int order;
  final bool active;

  const Designation({
    required this.id,
    required this.name,
    this.code = '',
    this.departmentId = '',
    this.departmentName = '',
    this.level = 1,
    this.description = '',
    this.order = 0,
    this.active = true,
  });

  factory Designation.fromJson(Map<String, dynamic> j) => Designation(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        code: j['code'] as String? ?? '',
        departmentId: _idOf(j['departmentId']),
        departmentName: _nameOf(j['departmentId']),
        level: j['level'] == null ? 1 : _i(j['level']),
        description: j['description'] as String? ?? '',
        order: _i(j['order']),
        active: j['active'] as bool? ?? true,
      );
}
