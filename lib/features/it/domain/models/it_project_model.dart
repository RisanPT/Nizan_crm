enum ITProjectCategory {
  software,
  infrastructure,
  security,
  support,
  general;

  String get label => switch (this) {
        ITProjectCategory.software => 'Software',
        ITProjectCategory.infrastructure => 'Infrastructure',
        ITProjectCategory.security => 'Security',
        ITProjectCategory.support => 'Support',
        ITProjectCategory.general => 'General IT',
      };

  String get slug => switch (this) {
        ITProjectCategory.software => 'Software',
        ITProjectCategory.infrastructure => 'Infrastructure',
        ITProjectCategory.security => 'Security',
        ITProjectCategory.support => 'Support',
        ITProjectCategory.general => 'General',
      };

  static ITProjectCategory fromString(String? s) {
    return switch (s?.toLowerCase()) {
      'software' => ITProjectCategory.software,
      'infrastructure' || 'infra' => ITProjectCategory.infrastructure,
      'security' => ITProjectCategory.security,
      'support' => ITProjectCategory.support,
      _ => ITProjectCategory.software,
    };
  }
}

/// An IT / internal project model.
class ITProjectModel {
  final String id;
  final String name;
  final String description;
  final ITProjectCategory category;
  final String type; // internal | client
  final String targetDepartment;
  final String managerId;
  final String managerName;
  final String status; // planning | active | on-hold | completed | cancelled
  final String priority; // low | medium | high | critical
  final String phase; // discovery | design | development | testing | deployment | maintenance
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? targetReleaseDate;
  final List<String> memberIds;
  final List<String> memberNames;
  final int progress; // 0..100
  final int totalTasks;
  final int completedTasks;

  const ITProjectModel({
    required this.id,
    required this.name,
    this.description = '',
    this.category = ITProjectCategory.software,
    this.type = 'internal',
    this.targetDepartment = 'it',
    this.managerId = '',
    this.managerName = '',
    this.memberIds = const [],
    this.memberNames = const [],
    this.status = 'planning',
    this.priority = 'medium',
    this.phase = 'discovery',
    this.startDate,
    this.endDate,
    this.targetReleaseDate,
    this.progress = 0,
    this.totalTasks = 0,
    this.completedTasks = 0,
  });

  factory ITProjectModel.fromJson(Map<String, dynamic> j) {
    final mgr = j['managerId'];
    final rawMembers = (j['members'] as List?) ?? const [];
    final mIds = <String>[];
    final mNames = <String>[];
    for (final m in rawMembers) {
      if (m is Map) {
        mIds.add((m['_id'] ?? m['id'] ?? '').toString());
        mNames.add((m['name'] ?? '').toString());
      } else if (m != null) {
        mIds.add(m.toString());
      }
    }

    return ITProjectModel(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      category: ITProjectCategory.fromString(j['category']),
      type: (j['type'] ?? 'internal').toString(),
      targetDepartment: (j['targetDepartment'] ?? 'it').toString(),
      managerId: mgr is Map ? (mgr['_id'] ?? '').toString() : (mgr ?? '').toString(),
      managerName: mgr is Map ? (mgr['name'] ?? '').toString() : '',
      memberIds: mIds,
      memberNames: mNames,
      status: (j['status'] ?? 'planning').toString(),
      priority: (j['priority'] ?? 'medium').toString(),
      phase: (j['phase'] ?? 'discovery').toString(),
      startDate: _date(j['startDate']),
      endDate: _date(j['endDate']),
      targetReleaseDate: _date(j['targetReleaseDate']),
      progress: (j['progress'] as num?)?.toInt() ?? 0,
      totalTasks: (j['totalTasks'] as num?)?.toInt() ?? 0,
      completedTasks: (j['completedTasks'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'category': category.slug,
        'type': type,
        'targetDepartment': targetDepartment,
        'managerId': managerId.isNotEmpty ? managerId : null,
        'members': memberIds,
        'status': status,
        'priority': priority,
        'phase': phase,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (targetReleaseDate != null) 'targetReleaseDate': targetReleaseDate!.toIso8601String(),
      };

  static DateTime? _date(dynamic v) =>
      (v == null || v == '') ? null : DateTime.tryParse(v.toString())?.toLocal();
}
