import 'package:flutter/material.dart';

enum OKRStatus {
  notStarted,
  inProgress,
  completed,
  blocked;

  String get label => switch (this) {
        OKRStatus.notStarted => 'Not started',
        OKRStatus.inProgress => 'In progress',
        OKRStatus.completed => 'Completed',
        OKRStatus.blocked => 'Blocked',
      };

  String get slug => switch (this) {
        OKRStatus.notStarted => 'not-started',
        OKRStatus.inProgress => 'in-progress',
        OKRStatus.completed => 'completed',
        OKRStatus.blocked => 'blocked',
      };

  Color get color => switch (this) {
        OKRStatus.notStarted => const Color(0xFF6B7280),
        OKRStatus.inProgress => const Color(0xFFEAB308),
        OKRStatus.completed => const Color(0xFF10B981),
        OKRStatus.blocked => const Color(0xFFEF4444),
      };

  Color get bgColor => color.withValues(alpha: 0.15);

  static OKRStatus fromString(String? s) {
    return switch (s?.toLowerCase().replaceAll('_', '-')) {
      'not-started' || 'notstarted' || 'todo' => OKRStatus.notStarted,
      'in-progress' || 'inprogress' || 'active' => OKRStatus.inProgress,
      'completed' || 'done' || 'closed' => OKRStatus.completed,
      'blocked' || 'on-hold' => OKRStatus.blocked,
      _ => OKRStatus.inProgress,
    };
  }
}

enum OKRPriority {
  high,
  medium,
  low,
  critical;

  String get label => switch (this) {
        OKRPriority.critical => 'Critical',
        OKRPriority.high => 'High',
        OKRPriority.medium => 'Medium',
        OKRPriority.low => 'Low',
      };

  String get slug => switch (this) {
        OKRPriority.critical => 'critical',
        OKRPriority.high => 'high',
        OKRPriority.medium => 'medium',
        OKRPriority.low => 'low',
      };

  Color get color => switch (this) {
        OKRPriority.critical => const Color(0xFFDC2626),
        OKRPriority.high => const Color(0xFFE11D48),
        OKRPriority.medium => const Color(0xFFF59E0B),
        OKRPriority.low => const Color(0xFF10B981),
      };

  static OKRPriority fromString(String? s) {
    return switch (s?.toLowerCase()) {
      'critical' => OKRPriority.critical,
      'high' => OKRPriority.high,
      'low' => OKRPriority.low,
      _ => OKRPriority.medium,
    };
  }
}

/// One report on a key result: what it stood at, who said so, and when. The server writes
/// these (the app never sends them); the timeline plots them.
class KeyResultCheckIn {
  final double value;
  final bool completed;
  final DateTime at;
  final String by;

  const KeyResultCheckIn({required this.value, this.completed = false, required this.at, this.by = ''});

  factory KeyResultCheckIn.fromJson(Map<String, dynamic> json) => KeyResultCheckIn(
        value: (json['value'] as num?)?.toDouble() ?? 0,
        completed: json['completed'] == true,
        at: DateTime.tryParse(json['at']?.toString() ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
        by: json['by']?.toString() ?? '',
      );
}

class KeyResultItem {
  final String id;
  final String title;
  final String metric;
  final double targetValue;
  final double currentValue;
  final String unit;
  final bool completed;
  /// Oldest first. Empty for a key result nobody has reported on yet (or one older than the log).
  final List<KeyResultCheckIn> checkIns;

  const KeyResultItem({
    required this.id,
    required this.title,
    this.metric = '',
    this.targetValue = 100,
    this.currentValue = 0,
    this.unit = '%',
    this.completed = false,
    this.checkIns = const [],
  });

  /// When it was last reported on (null if never).
  DateTime? get lastCheckInAt => checkIns.isEmpty ? null : checkIns.map((c) => c.at).reduce((a, b) => a.isAfter(b) ? a : b);

  /// How far this key result has got, 0..1 — the same rule the server uses to work out
  /// the objective's progress (done = 100%, else current / target, capped).
  double get attainment {
    if (completed) return 1;
    if (targetValue <= 0) return 0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  factory KeyResultItem.fromJson(Map<String, dynamic> json) {
    return KeyResultItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      metric: json['metric']?.toString() ?? '',
      targetValue: (json['targetValue'] as num?)?.toDouble() ?? 100,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? '%',
      completed: json['completed'] == true,
      checkIns: [
        for (final c in (json['checkIns'] as List?) ?? const [])
          if (c is Map) KeyResultCheckIn.fromJson(Map<String, dynamic>.from(c)),
      ]..sort((a, b) => a.at.compareTo(b.at)),
    );
  }

  // The check-in log is not sent back: the server keeps it.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'metric': metric,
        'targetValue': targetValue,
        'currentValue': currentValue,
        'unit': unit,
        'completed': completed,
      };

  KeyResultItem copyWith({
    String? id,
    String? title,
    String? metric,
    double? targetValue,
    double? currentValue,
    String? unit,
    bool? completed,
    List<KeyResultCheckIn>? checkIns,
  }) {
    return KeyResultItem(
      id: id ?? this.id,
      title: title ?? this.title,
      metric: metric ?? this.metric,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      completed: completed ?? this.completed,
      checkIns: checkIns ?? this.checkIns,
    );
  }
}

class OKRDocument {
  final String name;
  final String url;
  final DateTime? uploadedAt;

  const OKRDocument({
    required this.name,
    required this.url,
    this.uploadedAt,
  });

  factory OKRDocument.fromJson(Map<String, dynamic> json) {
    return OKRDocument(
      name: json['name']?.toString() ?? 'Document',
      url: json['url']?.toString() ?? '',
      uploadedAt: json['uploadedAt'] != null ? DateTime.tryParse(json['uploadedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'uploadedAt': uploadedAt?.toIso8601String(),
      };
}

/// What the signed-in person may do to one objective — decided by the server, so the app
/// only has to hide what would be refused.
class OKRAccess {
  final bool canManage; // edit it, move its dates, add under it, delete it
  final bool canCheckIn; // report on its key results

  const OKRAccess({this.canManage = false, this.canCheckIn = false});

  /// Before the server says otherwise (an older server, an objective built by hand): nothing
  /// is hidden — the server still refuses what is not allowed.
  static const unrestricted = OKRAccess(canManage: true, canCheckIn: true);

  factory OKRAccess.fromJson(Map<String, dynamic>? json) => json == null
      ? unrestricted
      : OKRAccess(canManage: json['canManage'] == true, canCheckIn: json['canCheckIn'] == true);
}

class OKRModel {
  final String id;
  final String? projectId;
  final String projectName;
  /// The department that owns the project (for a project objective), when the server says.
  final String projectDepartment;
  final String department;
  /// company | department | project — spelled out by the server (it used to be guessed
  /// from the department text).
  final String level;
  final String objective;
  final String description;
  final String? projectHeadId;
  final String projectHeadName;
  final DateTime? startDate;
  final DateTime? deadline;
  final OKRStatus status;
  final OKRPriority priority;
  final int progress; // 0 - 100
  final List<KeyResultItem> keyResults;
  final List<OKRDocument> documents;
  final String? parentObjectiveId;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final OKRAccess access;

  /// company | department | project. The server spells it out; an objective saved before
  /// that is read the old way (a project's; else company-wide by a blank / 'Company' /
  /// R&D department; else a department's).
  String get effectiveLevel {
    if (level.isNotEmpty) return level;
    if (projectId != null && projectId!.isNotEmpty) return 'project';
    final d = department.trim().toLowerCase();
    return d.isEmpty || d == 'company' || d == 'research-and-development' ? 'company' : 'department';
  }

  /// With key results, progress is worked out from them by the server — the objective's
  /// own number is only typed when it has none.
  bool get progressFromKeyResults => keyResults.isNotEmpty;

  /// The progress these key results add up to (percent), as the server works it out.
  static int progressOf(List<KeyResultItem> keyResults, {int manual = 0}) {
    if (keyResults.isEmpty) return manual;
    final avg = keyResults.map((k) => k.attainment).reduce((a, b) => a + b) / keyResults.length;
    return (avg * 100).round();
  }

  const OKRModel({
    required this.id,
    this.projectId,
    this.projectName = '',
    this.projectDepartment = '',
    this.department = 'research-and-development',
    this.level = '',
    required this.objective,
    this.description = '',
    this.projectHeadId,
    this.projectHeadName = '',
    this.startDate,
    this.deadline,
    this.status = OKRStatus.inProgress,
    this.priority = OKRPriority.high,
    this.progress = 0,
    this.keyResults = const [],
    this.documents = const [],
    this.parentObjectiveId,
    this.order = 0,
    this.createdAt,
    this.updatedAt,
    this.access = OKRAccess.unrestricted,
  });

  factory OKRModel.fromJson(Map<String, dynamic> json) {
    return OKRModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      projectId: json['projectId'] is Map ? json['projectId']['_id']?.toString() : json['projectId']?.toString(),
      projectName: json['projectId'] is Map
          ? (json['projectId']['name']?.toString() ?? '')
          : (json['projectName']?.toString() ?? ''),
      projectDepartment: json['projectId'] is Map
          ? (json['projectId']['targetDepartment']?.toString() ?? '')
          : (json['projectDepartment']?.toString() ?? ''),
      department: json['department']?.toString() ?? 'research-and-development',
      level: json['level']?.toString() ?? '',
      objective: json['objective']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      projectHeadId: json['projectHeadId'] is Map
          ? json['projectHeadId']['_id']?.toString()
          : json['projectHeadId']?.toString(),
      projectHeadName: json['projectHeadId'] is Map
          ? (json['projectHeadId']['name']?.toString() ?? json['projectHeadName']?.toString() ?? '')
          : (json['projectHeadName']?.toString() ?? ''),
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'].toString())?.toLocal() : null,
      deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline'].toString())?.toLocal() : null,
      status: OKRStatus.fromString(json['status']?.toString()),
      priority: OKRPriority.fromString(json['priority']?.toString()),
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      keyResults: (json['keyResults'] as List?)
              ?.map((e) => KeyResultItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      documents: (json['documents'] as List?)
              ?.map((e) => OKRDocument.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      parentObjectiveId: json['parentObjectiveId']?.toString(),
      order: (json['order'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString())?.toLocal() : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString())?.toLocal() : null,
      access: OKRAccess.fromJson(json['access'] is Map ? Map<String, dynamic>.from(json['access'] as Map) : null),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'department': department,
        if (level.isNotEmpty) 'level': level,
        'objective': objective,
        'description': description,
        'projectHeadId': projectHeadId,
        'projectHeadName': projectHeadName,
        'startDate': startDate?.toIso8601String(),
        'deadline': deadline?.toIso8601String(),
        'status': status.slug,
        'priority': priority.slug,
        'progress': progress,
        'keyResults': keyResults.map((e) => e.toJson()).toList(),
        'documents': documents.map((e) => e.toJson()).toList(),
        'parentObjectiveId': parentObjectiveId,
        'order': order,
      };

  OKRModel copyWith({
    String? id,
    String? projectId,
    String? projectName,
    String? projectDepartment,
    String? department,
    String? level,
    String? objective,
    String? description,
    String? projectHeadId,
    String? projectHeadName,
    DateTime? startDate,
    DateTime? deadline,
    OKRStatus? status,
    OKRPriority? priority,
    int? progress,
    List<KeyResultItem>? keyResults,
    List<OKRDocument>? documents,
    String? parentObjectiveId,
    int? order,
  }) {
    return OKRModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      projectDepartment: projectDepartment ?? this.projectDepartment,
      department: department ?? this.department,
      level: level ?? this.level,
      objective: objective ?? this.objective,
      description: description ?? this.description,
      projectHeadId: projectHeadId ?? this.projectHeadId,
      projectHeadName: projectHeadName ?? this.projectHeadName,
      startDate: startDate ?? this.startDate,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
      keyResults: keyResults ?? this.keyResults,
      documents: documents ?? this.documents,
      parentObjectiveId: parentObjectiveId ?? this.parentObjectiveId,
      order: order ?? this.order,
      createdAt: createdAt,
      updatedAt: updatedAt,
      access: access,
    );
  }
}
