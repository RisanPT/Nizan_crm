import 'package:flutter/material.dart';

enum ITTicketType {
  feature,
  bug,
  techDebt,
  infrastructure;

  String get label => switch (this) {
        ITTicketType.feature => 'Feature',
        ITTicketType.bug => 'Bug',
        ITTicketType.techDebt => 'Tech Debt',
        ITTicketType.infrastructure => 'Infrastructure',
      };

  String get slug => switch (this) {
        ITTicketType.feature => 'feature',
        ITTicketType.bug => 'bug',
        ITTicketType.techDebt => 'tech-debt',
        ITTicketType.infrastructure => 'infrastructure',
      };

  IconData get icon => switch (this) {
        ITTicketType.feature => Icons.auto_awesome,
        ITTicketType.bug => Icons.bug_report,
        ITTicketType.techDebt => Icons.build_circle_outlined,
        ITTicketType.infrastructure => Icons.cloud_queue,
      };

  Color get color => switch (this) {
        ITTicketType.feature => const Color(0xFF2563EB),
        ITTicketType.bug => const Color(0xFFDC2626),
        ITTicketType.techDebt => const Color(0xFFD97706),
        ITTicketType.infrastructure => const Color(0xFF7C3AED),
      };

  static ITTicketType fromString(String? s) {
    return switch (s?.toLowerCase().replaceAll('_', '-')) {
      'bug' => ITTicketType.bug,
      'tech-debt' || 'techdebt' || 'debt' => ITTicketType.techDebt,
      'infrastructure' || 'infra' => ITTicketType.infrastructure,
      _ => ITTicketType.feature,
    };
  }
}

enum ITSeverity {
  p0,
  p1,
  p2,
  p3;

  String get label => switch (this) {
        ITSeverity.p0 => 'P0 - Critical',
        ITSeverity.p1 => 'P1 - High',
        ITSeverity.p2 => 'P2 - Medium',
        ITSeverity.p3 => 'P3 - Low',
      };

  String get shortLabel => switch (this) {
        ITSeverity.p0 => 'P0',
        ITSeverity.p1 => 'P1',
        ITSeverity.p2 => 'P2',
        ITSeverity.p3 => 'P3',
      };

  String get slug => switch (this) {
        ITSeverity.p0 => 'p0',
        ITSeverity.p1 => 'p1',
        ITSeverity.p2 => 'p2',
        ITSeverity.p3 => 'p3',
      };

  Color get color => switch (this) {
        ITSeverity.p0 => const Color(0xFFEF4444),
        ITSeverity.p1 => const Color(0xFFF97316),
        ITSeverity.p2 => const Color(0xFFEAB308),
        ITSeverity.p3 => const Color(0xFF10B981),
      };

  static ITSeverity fromString(String? s) {
    return switch (s?.toLowerCase()) {
      'p0' || 'critical' => ITSeverity.p0,
      'p1' || 'high' => ITSeverity.p1,
      'p2' || 'medium' => ITSeverity.p2,
      'p3' || 'low' => ITSeverity.p3,
      _ => ITSeverity.p2,
    };
  }
}

enum ITSubTeam {
  frontend,
  backend,
  devops,
  qa,
  general;

  String get label => switch (this) {
        ITSubTeam.frontend => 'Frontend',
        ITSubTeam.backend => 'Backend',
        ITSubTeam.devops => 'DevOps',
        ITSubTeam.qa => 'QA',
        ITSubTeam.general => 'General IT',
      };

  String get slug => switch (this) {
        ITSubTeam.frontend => 'frontend',
        ITSubTeam.backend => 'backend',
        ITSubTeam.devops => 'devops',
        ITSubTeam.qa => 'qa',
        ITSubTeam.general => 'general',
      };

  IconData get icon => switch (this) {
        ITSubTeam.frontend => Icons.devices_outlined,
        ITSubTeam.backend => Icons.dns_outlined,
        ITSubTeam.devops => Icons.all_inclusive,
        ITSubTeam.qa => Icons.verified_user_outlined,
        ITSubTeam.general => Icons.laptop_chromebook,
      };

  Color get color => switch (this) {
        ITSubTeam.frontend => const Color(0xFF0284C7),
        ITSubTeam.backend => const Color(0xFF059669),
        ITSubTeam.devops => const Color(0xFF8B5CF6),
        ITSubTeam.qa => const Color(0xFFD946EF),
        ITSubTeam.general => const Color(0xFF64748B),
      };

  static ITSubTeam fromString(String? s) {
    return switch (s?.toLowerCase()) {
      'frontend' || 'ui' => ITSubTeam.frontend,
      'backend' || 'api' => ITSubTeam.backend,
      'devops' || 'cloud' || 'infra' => ITSubTeam.devops,
      'qa' || 'test' || 'testing' => ITSubTeam.qa,
      _ => ITSubTeam.general,
    };
  }
}

enum ITTaskStatus {
  backlog,
  todo,
  inProgress,
  codeReview,
  qaTesting,
  deployed,
  closed;

  String get label => switch (this) {
        ITTaskStatus.backlog => 'Backlog',
        ITTaskStatus.todo => 'To Do',
        ITTaskStatus.inProgress => 'In Progress',
        ITTaskStatus.codeReview => 'Code Review',
        ITTaskStatus.qaTesting => 'QA Testing',
        ITTaskStatus.deployed => 'Deployed',
        ITTaskStatus.closed => 'Closed',
      };

  String get slug => switch (this) {
        ITTaskStatus.backlog => 'backlog',
        ITTaskStatus.todo => 'todo',
        ITTaskStatus.inProgress => 'in-progress',
        ITTaskStatus.codeReview => 'code-review',
        ITTaskStatus.qaTesting => 'qa-testing',
        ITTaskStatus.deployed => 'deployed',
        ITTaskStatus.closed => 'closed',
      };

  Color get color => switch (this) {
        ITTaskStatus.backlog => const Color(0xFF64748B),
        ITTaskStatus.todo => const Color(0xFF3B82F6),
        ITTaskStatus.inProgress => const Color(0xFF0EA5E9),
        ITTaskStatus.codeReview => const Color(0xFFF59E0B),
        ITTaskStatus.qaTesting => const Color(0xFF8B5CF6),
        ITTaskStatus.deployed => const Color(0xFF10B981),
        ITTaskStatus.closed => const Color(0xFF059669),
      };

  static ITTaskStatus fromString(String? s) {
    return switch (s?.toLowerCase().replaceAll('_', '-')) {
      'backlog' => ITTaskStatus.backlog,
      'todo' || 'to-do' => ITTaskStatus.todo,
      'in-progress' || 'progress' || 'active' => ITTaskStatus.inProgress,
      'code-review' || 'review' => ITTaskStatus.codeReview,
      'qa-testing' || 'qa' || 'testing' => ITTaskStatus.qaTesting,
      'deployed' || 'release' => ITTaskStatus.deployed,
      'closed' || 'completed' || 'done' => ITTaskStatus.closed,
      _ => ITTaskStatus.todo,
    };
  }
}

class ITSubtask {
  final String id;
  final String title;
  final bool isCompleted;

  const ITSubtask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  factory ITSubtask.fromJson(Map<String, dynamic> json) {
    return ITSubtask(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      isCompleted: json['completed'] == true || json['isCompleted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': isCompleted,
      };

  ITSubtask copyWith({String? id, String? title, bool? isCompleted}) {
    return ITSubtask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class ITActivityLog {
  final String id;
  final String message;
  final String authorName;
  final String type; // note, status_change, date_shift
  final DateTime timestamp;

  const ITActivityLog({
    required this.id,
    required this.message,
    this.authorName = 'Team Member',
    this.type = 'note',
    required this.timestamp,
  });

  factory ITActivityLog.fromJson(Map<String, dynamic> json) {
    return ITActivityLog(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      authorName: (json['author'] ?? json['authorName'] ?? 'Team Member').toString(),
      type: (json['type'] ?? 'note').toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'author': authorName,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
      };
}

class ITTaskModel {
  final String id;
  final String projectId;
  final String projectName;
  final String? parentTaskId;
  final String title;
  final String description;
  final ITTicketType ticketType;
  final ITSeverity severity;
  final ITSubTeam subTeam;
  final ITTaskStatus status;
  final String assigneeId;
  final String assigneeName;
  final DateTime? startDate;
  final DateTime? dueDate;
  final double estimatedHours;
  final double actualHours;
  final int percentComplete;
  final int order;
  final List<String> predecessorIds;
  final List<ITSubtask> subtasks;
  final List<ITActivityLog> activityLogs;
  final DateTime? completedAt;
  final DateTime? createdAt;

  const ITTaskModel({
    required this.id,
    required this.projectId,
    this.projectName = '',
    this.parentTaskId,
    required this.title,
    this.description = '',
    this.ticketType = ITTicketType.feature,
    this.severity = ITSeverity.p2,
    this.subTeam = ITSubTeam.general,
    this.status = ITTaskStatus.todo,
    this.assigneeId = '',
    this.assigneeName = '',
    this.startDate,
    this.dueDate,
    this.estimatedHours = 0,
    this.actualHours = 0,
    this.percentComplete = 0,
    this.order = 0,
    this.predecessorIds = const [],
    this.subtasks = const [],
    this.activityLogs = const [],
    this.completedAt,
    this.createdAt,
  });

  /// Readable ticket key like IT-042
  String get ticketKey {
    if (id.length <= 4) return 'IT-$id';
    final tail = id.substring(id.length - 4).toUpperCase();
    return 'IT-$tail';
  }

  DateTime? get deadline => dueDate;
  String get category => ticketType.slug;
  String get priority => severity.slug;
  String get assignedToId => assigneeId;
  String get assignedToName => assigneeName;

  bool get isCompleted =>
      status == ITTaskStatus.closed ||
      status == ITTaskStatus.deployed ||
      percentComplete >= 100;

  bool get isBlocked => predecessorIds.isNotEmpty;

  factory ITTaskModel.fromJson(Map<String, dynamic> j) {
    final proj = j['projectId'];
    final assignee = j['assignedTo'];
    final parent = j['parentTaskId'];

    final rawPreds = j['predecessorIds'];
    final preds = <String>[];
    if (rawPreds is List) {
      for (final p in rawPreds) {
        if (p is Map) {
          preds.add((p['_id'] ?? p['id'] ?? '').toString());
        } else if (p != null) {
          preds.add(p.toString());
        }
      }
    }

    final rawSubtasks = j['subtasks'];
    final subs = <ITSubtask>[];
    if (rawSubtasks is List) {
      for (final s in rawSubtasks) {
        if (s is Map<String, dynamic>) {
          subs.add(ITSubtask.fromJson(s));
        } else if (s is Map) {
          subs.add(ITSubtask.fromJson(s.cast<String, dynamic>()));
        }
      }
    }

    final rawLogs = j['activityLogs'];
    final logs = <ITActivityLog>[];
    if (rawLogs is List) {
      for (final l in rawLogs) {
        if (l is Map<String, dynamic>) {
          logs.add(ITActivityLog.fromJson(l));
        } else if (l is Map) {
          logs.add(ITActivityLog.fromJson(l.cast<String, dynamic>()));
        }
      }
    }

    final sDate = _parseDate(j['startDate']);
    final dDate = _parseDate(j['dueDate'] ?? j['deadline']);

    return ITTaskModel(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      projectId: proj is Map ? (proj['_id'] ?? proj['id'] ?? '').toString() : (proj ?? '').toString(),
      projectName: proj is Map ? (proj['name'] ?? '').toString() : '',
      parentTaskId: parent == null || parent == ''
          ? null
          : (parent is Map ? (parent['_id'] ?? parent['id'] ?? '').toString() : parent.toString()),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      ticketType: ITTicketType.fromString(j['ticketType'] ?? j['category']),
      severity: ITSeverity.fromString(j['severity'] ?? j['priority']),
      subTeam: ITSubTeam.fromString(j['subTeam']),
      status: ITTaskStatus.fromString(j['status']),
      assigneeId: assignee is Map ? (assignee['_id'] ?? assignee['id'] ?? '').toString() : (assignee ?? '').toString(),
      assigneeName: assignee is Map ? (assignee['name'] ?? '').toString() : '',
      startDate: sDate,
      dueDate: dDate,
      estimatedHours: (j['estimatedHours'] as num?)?.toDouble() ?? 0,
      actualHours: (j['actualHours'] as num?)?.toDouble() ?? 0,
      percentComplete: (j['percentComplete'] as num?)?.toInt() ?? 0,
      order: (j['order'] as num?)?.toInt() ?? 0,
      predecessorIds: preds,
      subtasks: subs,
      activityLogs: logs,
      completedAt: _parseDate(j['completedAt']),
      createdAt: _parseDate(j['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        if (parentTaskId != null) 'parentTaskId': parentTaskId,
        'title': title,
        'description': description,
        'ticketType': ticketType.slug,
        'category': ticketType.slug,
        'severity': severity.slug,
        'priority': severity.slug,
        'subTeam': subTeam.slug,
        'status': status.slug,
        'assignedTo': assigneeId.isNotEmpty ? assigneeId : null,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (dueDate != null) 'deadline': dueDate!.toIso8601String(),
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
        'estimatedHours': estimatedHours,
        'actualHours': actualHours,
        'percentComplete': percentComplete,
        'order': order,
        'predecessorIds': predecessorIds,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'activityLogs': activityLogs.map((l) => l.toJson()).toList(),
      };

  ITTaskModel copyWith({
    String? id,
    String? projectId,
    String? projectName,
    Object? parentTaskId = _sentinel,
    String? title,
    String? description,
    ITTicketType? ticketType,
    ITSeverity? severity,
    ITSubTeam? subTeam,
    ITTaskStatus? status,
    String? assigneeId,
    String? assigneeName,
    Object? startDate = _sentinel,
    Object? dueDate = _sentinel,
    double? estimatedHours,
    double? actualHours,
    int? percentComplete,
    int? order,
    List<String>? predecessorIds,
    List<ITSubtask>? subtasks,
    List<ITActivityLog>? activityLogs,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return ITTaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      parentTaskId: parentTaskId == _sentinel ? this.parentTaskId : parentTaskId as String?,
      title: title ?? this.title,
      description: description ?? this.description,
      ticketType: ticketType ?? this.ticketType,
      severity: severity ?? this.severity,
      subTeam: subTeam ?? this.subTeam,
      status: status ?? this.status,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      startDate: startDate == _sentinel ? this.startDate : startDate as DateTime?,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as DateTime?,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      percentComplete: percentComplete ?? this.percentComplete,
      order: order ?? this.order,
      predecessorIds: predecessorIds ?? this.predecessorIds,
      subtasks: subtasks ?? this.subtasks,
      activityLogs: activityLogs ?? this.activityLogs,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static const _sentinel = Object();

  static DateTime? _parseDate(dynamic v) {
    if (v == null || v == '') return null;
    if (v is DateTime) return v.toLocal();
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}
