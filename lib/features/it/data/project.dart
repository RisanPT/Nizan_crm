/// An IT / internal project. Mirrors backend models/Project.js.
class Project {
  final String id;
  final String name;
  final String description;
  final String type; // internal | client
  final String targetDepartment;
  final String managerId;
  final String managerName;
  final String status; // planning | active | on-hold | completed | cancelled
  final String priority; // low | medium | high | critical
  final String phase; // discovery | design | development | testing | deployment | maintenance
  final DateTime? startDate;
  final DateTime? endDate;
  final int progress; // 0..100
  final int totalTasks;
  final int completedTasks;

  const Project({
    required this.id,
    required this.name,
    this.description = '',
    this.type = 'internal',
    this.targetDepartment = 'it',
    this.managerId = '',
    this.managerName = '',
    this.status = 'planning',
    this.priority = 'medium',
    this.phase = 'discovery',
    this.startDate,
    this.endDate,
    this.progress = 0,
    this.totalTasks = 0,
    this.completedTasks = 0,
  });

  factory Project.fromJson(Map<String, dynamic> j) {
    final mgr = j['managerId'];
    return Project(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      type: (j['type'] ?? 'internal').toString(),
      targetDepartment: (j['targetDepartment'] ?? 'it').toString(),
      managerId: mgr is Map ? (mgr['_id'] ?? '').toString() : (mgr ?? '').toString(),
      managerName: mgr is Map ? (mgr['name'] ?? '').toString() : '',
      status: (j['status'] ?? 'planning').toString(),
      priority: (j['priority'] ?? 'medium').toString(),
      phase: (j['phase'] ?? 'discovery').toString(),
      startDate: _date(j['startDate']),
      endDate: _date(j['endDate']),
      progress: (j['progress'] as num?)?.toInt() ?? 0,
      totalTasks: (j['totalTasks'] as num?)?.toInt() ?? 0,
      completedTasks: (j['completedTasks'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _date(dynamic v) =>
      (v == null || v == '') ? null : DateTime.tryParse(v.toString())?.toLocal();
}
