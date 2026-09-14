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

class KeyResultItem {
  final String id;
  final String title;
  final String metric;
  final double targetValue;
  final double currentValue;
  final String unit;
  final bool completed;

  const KeyResultItem({
    required this.id,
    required this.title,
    this.metric = '',
    this.targetValue = 100,
    this.currentValue = 0,
    this.unit = '%',
    this.completed = false,
  });

  factory KeyResultItem.fromJson(Map<String, dynamic> json) {
    return KeyResultItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      metric: json['metric']?.toString() ?? '',
      targetValue: (json['targetValue'] as num?)?.toDouble() ?? 100,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? '%',
      completed: json['completed'] == true,
    );
  }

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
  }) {
    return KeyResultItem(
      id: id ?? this.id,
      title: title ?? this.title,
      metric: metric ?? this.metric,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      completed: completed ?? this.completed,
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

class OKRModel {
  final String id;
  final String? projectId;
  final String department;
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

  const OKRModel({
    required this.id,
    this.projectId,
    this.department = 'research-and-development',
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
  });

  factory OKRModel.fromJson(Map<String, dynamic> json) {
    return OKRModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      projectId: json['projectId'] is Map ? json['projectId']['_id']?.toString() : json['projectId']?.toString(),
      department: json['department']?.toString() ?? 'research-and-development',
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'department': department,
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
    String? department,
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
      department: department ?? this.department,
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
    );
  }
}
