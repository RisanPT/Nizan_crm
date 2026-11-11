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

/// One department on a project. A project has exactly one [isOwner] department
/// (accountable for it); the others are invited by the project manager and their head
/// must accept before their people work on it.
class ProjectDepartment {
  final String name;
  final String role; // owner | participant
  final String leadId;
  final String leadName;
  final String status; // invited | accepted | declined

  const ProjectDepartment({required this.name, this.role = 'participant', this.leadId = '', this.leadName = '', this.status = 'accepted'});

  bool get isOwner => role == 'owner';
  bool get isInvited => status == 'invited';
  bool get isDeclined => status == 'declined';
  bool get isActive => status == 'accepted';

  factory ProjectDepartment.fromJson(Map<String, dynamic> j) {
    final lead = j['leadId'];
    return ProjectDepartment(
      name: (j['name'] ?? '').toString(),
      role: (j['role'] ?? 'participant').toString(),
      leadId: lead is Map ? (lead['_id'] ?? lead['id'] ?? '').toString() : (lead ?? '').toString(),
      leadName: lead is Map ? (lead['name'] ?? '').toString() : '',
      status: (j['status'] ?? 'accepted').toString(),
    );
  }
}

/// One line of a project's activity feed ("Project created", "Accounts joined the project", …), as the server
/// worked it out. [by] is empty when nobody is recorded for it.
class ProjectActivity {
  final String kind; // created | invited | joined | declined | status | decision | reminder | note
  final String text;
  final String by;
  final DateTime at;

  const ProjectActivity({required this.kind, required this.text, this.by = '', required this.at});

  static ProjectActivity? tryParse(Map<String, dynamic> j) {
    final at = DateTime.tryParse((j['at'] ?? '').toString())?.toLocal();
    final text = (j['text'] ?? '').toString();
    if (at == null || text.isEmpty) return null;
    return ProjectActivity(kind: (j['kind'] ?? 'note').toString(), text: text, by: (j['by'] ?? '').toString(), at: at);
  }
}

/// How far one department's own tasks have got (leaf tasks only, like the project total).
class DepartmentProgress {
  final String name;
  final int progress; // 0..100
  final int tasks;
  final int done;

  const DepartmentProgress({required this.name, this.progress = 0, this.tasks = 0, this.done = 0});

  factory DepartmentProgress.fromJson(Map<String, dynamic> j) => DepartmentProgress(
    name: (j['name'] ?? '').toString(),
    progress: (j['progress'] as num?)?.toInt() ?? 0,
    tasks: (j['tasks'] as num?)?.toInt() ?? 0,
    done: (j['done'] as num?)?.toInt() ?? 0,
  );
}

/// The kinds of cost a project's estimate can be broken into (key, label) — the same list the server accepts.
const projectCostCategories = <(String, String)>[
  ('manpower', 'Manpower'),
  ('vendors', 'Vendors & services'),
  ('tools', 'Tools & software'),
  ('travel', 'Travel & stay'),
  ('marketing', 'Marketing'),
  ('other', 'Other'),
];

String costCategoryLabel(String key) => projectCostCategories.where((c) => c.$1 == key).firstOrNull?.$2 ?? 'Other';

/// One line of a project's cost breakdown.
class CostLine {
  final String category;
  final double amount;
  final String note;
  const CostLine({required this.category, required this.amount, this.note = ''});

  factory CostLine.fromJson(Map<String, dynamic> j) =>
      CostLine(category: (j['category'] ?? 'other').toString(), amount: (j['amount'] as num?)?.toDouble() ?? 0, note: (j['note'] ?? '').toString());

  Map<String, dynamic> toJson() => {'category': category, 'amount': amount, if (note.isNotEmpty) 'note': note};
}

/// A change to the cost after it was approved: when, by whom, why, and what moved.
class CostChange {
  final DateTime at;
  final String byName;
  final String reason;
  final List<String> lines;
  const CostChange({required this.at, this.byName = '', this.reason = '', this.lines = const []});

  static CostChange? tryParse(Map<String, dynamic> j) {
    final at = DateTime.tryParse((j['at'] ?? '').toString())?.toLocal();
    if (at == null) return null;
    return CostChange(
      at: at,
      byName: (j['byName'] ?? '').toString(),
      reason: (j['reason'] ?? '').toString(),
      lines: [for (final l in (j['lines'] as List?) ?? const []) l.toString()],
    );
  }
}

/// A project's money: what was asked for, what the finance head approved, how it breaks down. The server sends it only
/// to those who may see money (null for everyone else — they see only [ITProjectModel.costStatus]).
class ProjectCost {
  /// The estimated cost asked for (the breakdown's total when there is one).
  final double budget;

  /// What the finance head approved — the limit spending is held against. 0 until approved.
  final double approvedBudget;

  /// What the project is expected to bring in (client projects), optional.
  final double estimatedValue;
  final List<CostLine> plan;

  /// What has been charged to the project: approved expenses (spent) and ones waiting for approval (committed).
  final double spent;
  final double committed;

  /// The finance head's note on the last decision.
  final String note;
  final List<CostChange> changes;

  const ProjectCost({
    this.budget = 0,
    this.approvedBudget = 0,
    this.estimatedValue = 0,
    this.plan = const [],
    this.spent = 0,
    this.committed = 0,
    this.note = '',
    this.changes = const [],
  });

  factory ProjectCost.fromJson(Map<String, dynamic> j) => ProjectCost(
    budget: (j['budget'] as num?)?.toDouble() ?? 0,
    approvedBudget: (j['approvedBudget'] as num?)?.toDouble() ?? 0,
    estimatedValue: (j['estimatedValue'] as num?)?.toDouble() ?? 0,
    plan: [
      for (final l in (j['plan'] as List?) ?? const [])
        if (l is Map) CostLine.fromJson(l.cast<String, dynamic>()),
    ],
    spent: (j['spent'] as num?)?.toDouble() ?? 0,
    committed: (j['committed'] as num?)?.toDouble() ?? 0,
    note: (j['note'] ?? '').toString(),
    changes: [for (final c in (j['changes'] as List?) ?? const []) ?(c is Map ? CostChange.tryParse(c.cast<String, dynamic>()) : null)],
  );

  /// A change is with the finance head while an earlier amount is still the limit.
  bool get hasApproval => approvedBudget > 0;

  /// Spent plus committed.
  double get used => spent + committed;

  /// What is left of the approved limit (negative once over it).
  double get available => approvedBudget - used;

  /// How much of the approved limit is used, 0..∞ (null until a limit is approved).
  double? get usedFraction => approvedBudget > 0 ? used / approvedBudget : null;

  /// none (no limit yet) | ok | warn (from 80%) | over — the same words the server uses.
  String get level {
    if (approvedBudget <= 0) return 'none';
    if (used > approvedBudget) return 'over';
    return used * 100 >= approvedBudget * 80 ? 'warn' : 'ok';
  }
}

/// A project whose cost waits for the finance head — one row of Finance's "Project budgets" list.
class PendingProjectCost {
  final String id;
  final String name;
  final String department;
  final String managerName;
  final String requestedByName;
  final DateTime? requestedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final double budget;
  final double approvedBudget;
  final List<CostLine> plan;

  /// A change after an approval (the earlier amount is still the limit meanwhile), with the reason given and what moved.
  final bool isChange;
  final String changeReason;
  final List<String> changeLines;
  final bool canDecide;

  const PendingProjectCost({
    required this.id,
    required this.name,
    this.department = '',
    this.managerName = '',
    this.requestedByName = '',
    this.requestedAt,
    this.startDate,
    this.endDate,
    this.budget = 0,
    this.approvedBudget = 0,
    this.plan = const [],
    this.isChange = false,
    this.changeReason = '',
    this.changeLines = const [],
    this.canDecide = false,
  });

  factory PendingProjectCost.fromJson(Map<String, dynamic> j) {
    DateTime? d(dynamic v) => (v == null || v == '') ? null : DateTime.tryParse(v.toString())?.toLocal();
    return PendingProjectCost(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      department: (j['department'] ?? '').toString(),
      managerName: (j['managerName'] ?? '').toString(),
      requestedByName: (j['requestedByName'] ?? '').toString(),
      requestedAt: d(j['requestedAt']),
      startDate: d(j['startDate']),
      endDate: d(j['endDate']),
      budget: (j['budget'] as num?)?.toDouble() ?? 0,
      approvedBudget: (j['approvedBudget'] as num?)?.toDouble() ?? 0,
      plan: [
        for (final l in (j['plan'] as List?) ?? const [])
          if (l is Map) CostLine.fromJson(l.cast<String, dynamic>()),
      ],
      isChange: j['isChange'] == true,
      changeReason: (j['changeReason'] ?? '').toString(),
      changeLines: [for (final l in (j['changeLines'] as List?) ?? const []) l.toString()],
      canDecide: j['canDecide'] == true,
    );
  }
}

/// What the signed-in user may do on one project — decided by the server, so the app
/// only has to hide what would be refused.
class ProjectAccess {
  final String role; // admin | manager | owner_head | dept_lead | member | viewer
  final bool canManage;
  final String editMode; // managed | open
  final bool canCreateTasks;
  final bool canEditAllTasks;
  final List<String> leadDepartments;
  final List<String> pendingInvitations;

  /// May approve / reject this project while it is a proposal.
  final bool canDecide;

  /// The cost: see the amounts, change it (those who run the project), and decide on it (the finance head, while it waits).
  final bool canSeeCost;
  final bool canEditCost;
  final bool canDecideCost;

  const ProjectAccess({
    this.role = 'viewer',
    this.canManage = false,
    this.editMode = 'open',
    this.canCreateTasks = false,
    this.canEditAllTasks = false,
    this.leadDepartments = const [],
    this.pendingInvitations = const [],
    this.canDecide = false,
    this.canSeeCost = false,
    this.canEditCost = false,
    this.canDecideCost = false,
  });

  /// Before the server says otherwise (a project built by hand, an older response):
  /// nothing is hidden, the server still refuses what is not allowed.
  static const unrestricted = ProjectAccess(
    role: 'manager',
    canManage: true,
    canCreateTasks: true,
    canEditAllTasks: true,
    canSeeCost: true,
    canEditCost: true,
  );

  bool get isManaged => editMode == 'managed';

  /// May change the plan of a task in [department] (title, dates, assignee, …).
  bool canPlanIn(String department) => canEditAllTasks || leadDepartments.any((d) => d.toLowerCase() == department.trim().toLowerCase());

  factory ProjectAccess.fromJson(Map<String, dynamic>? j) {
    if (j == null) return unrestricted;
    List<String> names(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];
    return ProjectAccess(
      role: (j['role'] ?? 'viewer').toString(),
      canManage: j['canManage'] == true,
      editMode: (j['editMode'] ?? 'open').toString(),
      canCreateTasks: j['canCreateTasks'] == true,
      canEditAllTasks: j['canEditAllTasks'] == true,
      leadDepartments: names(j['leadDepartments']),
      pendingInvitations: names(j['pendingInvitations']),
      canDecide: j['canDecide'] == true,
      canSeeCost: j['canSeeCost'] == true,
      canEditCost: j['canEditCost'] == true,
      canDecideCost: j['canDecideCost'] == true,
    );
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
  final List<ProjectDepartment> departments;
  final List<DepartmentProgress> departmentProgress;
  final String editMode; // managed | open
  final String decisionNote; // why a proposal was rejected
  final int horizonNumber; // 1 | 2 | 3
  final String strategicPillar;
  final int? targetYear;
  final ProjectAccess access;

  /// Where the estimated cost stands: none (a project from before costs existed) | pending (with the finance head) |
  /// approved | returned (sent back to be revised). Everyone who can open the project sees this.
  final String costStatus;

  /// The amounts — only for those who may see money, otherwise null.
  final ProjectCost? cost;

  /// What has happened to the project, oldest first. Only a single project's response carries it (the
  /// list does not), so it is empty for a project read from the list.
  final List<ProjectActivity> activity;

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
    this.departments = const [],
    this.departmentProgress = const [],
    this.editMode = 'open',
    this.decisionNote = '',
    this.horizonNumber = 1,
    this.strategicPillar = '',
    this.targetYear,
    this.access = ProjectAccess.unrestricted,
    this.activity = const [],
    this.costStatus = 'none',
    this.cost,
  });

  bool get isProposed => status == 'proposed';

  /// The cost is with the finance head / was sent back: the project cannot start until it is approved.
  bool get costWaiting => costStatus == 'pending';
  bool get costReturned => costStatus == 'returned';
  bool get costApproved => costStatus == 'approved';
  bool get mayStart => !costWaiting && !costReturned;
  bool get isRejected => status == 'cancelled' && decisionNote.isNotEmpty;

  /// The departments actually working on it (owner + those that accepted).
  List<ProjectDepartment> get activeDepartments => departments.where((d) => d.isActive).toList();

  /// Everyone invited who has not answered yet.
  List<ProjectDepartment> get invitedDepartments => departments.where((d) => d.isInvited).toList();

  /// Names of the departments a task here can belong to (owner first).
  List<String> get departmentNames {
    final names = activeDepartments.map((d) => d.name).toList();
    if (names.isEmpty && targetDepartment.isNotEmpty) names.add(targetDepartment);
    return names;
  }

  bool get isCrossDepartment => departments.where((d) => !d.isDeclined).length > 1;

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
      departments: _list(j['departments']).map(ProjectDepartment.fromJson).toList(),
      departmentProgress: _list(j['departmentProgress']).map(DepartmentProgress.fromJson).toList(),
      editMode: (j['editMode'] ?? 'open').toString(),
      decisionNote: (j['decisionNote'] ?? '').toString(),
      horizonNumber: (j['horizonNumber'] as num?)?.toInt() ?? 1,
      strategicPillar: (j['strategicPillar'] ?? '').toString(),
      targetYear: (j['targetYear'] as num?)?.toInt(),
      access: ProjectAccess.fromJson(j['access'] is Map ? (j['access'] as Map).cast<String, dynamic>() : null),
      activity: [for (final e in _list(j['activity'])) ?ProjectActivity.tryParse(e)],
      costStatus: (j['costStatus'] ?? 'none').toString(),
      cost: j['cost'] is Map ? ProjectCost.fromJson((j['cost'] as Map).cast<String, dynamic>()) : null,
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
    'editMode': editMode,
    'horizonNumber': horizonNumber,
    'strategicPillar': strategicPillar,
    if (targetYear != null) 'targetYear': targetYear,
    // the owner is [targetDepartment]; the server keeps it and adds the invited ones
    'departments': [
      for (final d in departments.where((d) => !d.isOwner && !d.isDeclined)) {'name': d.name, if (d.leadId.isNotEmpty) 'leadId': d.leadId},
    ],
    if (startDate != null) 'startDate': startDate!.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    if (targetReleaseDate != null) 'targetReleaseDate': targetReleaseDate!.toIso8601String(),
  };

  static List<Map<String, dynamic>> _list(dynamic v) => v is List
      ? [
          for (final e in v)
            if (e is Map) e.cast<String, dynamic>(),
        ]
      : const [];

  static DateTime? _date(dynamic v) => (v == null || v == '') ? null : DateTime.tryParse(v.toString())?.toLocal();
}
