import 'package:flutter/material.dart';

class StrategicPillar {
  final String id;
  final String name;
  final String icon;
  final Color color;
  final String description;
  final int order;

  const StrategicPillar({
    required this.id,
    required this.name,
    this.icon = 'flag',
    this.color = const Color(0xFF7C3AED),
    this.description = '',
    this.order = 0,
  });

  factory StrategicPillar.fromJson(Map<String, dynamic> json) {
    Color parseColor(String? hex) {
      if (hex == null || hex.isEmpty) return const Color(0xFF7C3AED);
      final clean = hex.replaceAll('#', '');
      return Color(int.tryParse('FF$clean', radix: 16) ?? 0xFF7C3AED);
    }

    return StrategicPillar(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'flag',
      color: parseColor(json['color']?.toString()),
      description: json['description']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': '#${color.toARGB32().toRadixString(16).substring(2)}',
        'description': description,
        'order': order,
      };
}

class StrategicHorizon {
  final int horizonNumber; // 1, 2, or 3
  final String name;
  final String subtitle;
  final int startYear;
  final int endYear;
  final String primaryFocus;
  final String status;

  const StrategicHorizon({
    required this.horizonNumber,
    required this.name,
    this.subtitle = '',
    required this.startYear,
    required this.endYear,
    this.primaryFocus = '',
    this.status = 'active',
  });

  factory StrategicHorizon.fromJson(Map<String, dynamic> json) {
    return StrategicHorizon(
      horizonNumber: (json['horizonNumber'] as num?)?.toInt() ?? 1,
      name: json['name']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      startYear: (json['startYear'] as num?)?.toInt() ?? 2026,
      endYear: (json['endYear'] as num?)?.toInt() ?? 2028,
      primaryFocus: json['primaryFocus']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
        'horizonNumber': horizonNumber,
        'name': name,
        'subtitle': subtitle,
        'startYear': startYear,
        'endYear': endYear,
        'primaryFocus': primaryFocus,
        'status': status,
      };
}

class StrategicMilestone {
  final String id;
  final String pillarId;
  final int horizonNumber;
  final String title;
  final String description;
  final int targetYear;
  final String targetQuarter;
  final String status; // planned | in-flight | achieved | at-risk
  final String metricLabel;
  final double targetMetric;
  final double currentMetric;
  final String metricUnit;
  final List<dynamic> linkedProjects;
  final int order;

  const StrategicMilestone({
    required this.id,
    required this.pillarId,
    required this.horizonNumber,
    required this.title,
    this.description = '',
    required this.targetYear,
    this.targetQuarter = 'Q4',
    this.status = 'planned',
    this.metricLabel = '',
    this.targetMetric = 100,
    this.currentMetric = 0,
    this.metricUnit = '%',
    this.linkedProjects = const [],
    this.order = 0,
  });

  double get progress {
    if (targetMetric <= 0) return 0;
    return (currentMetric / targetMetric).clamp(0.0, 1.0);
  }

  Color get statusColor => switch (status.toLowerCase()) {
        'achieved' => const Color(0xFF10B981),
        'in-flight' => const Color(0xFF3B82F6),
        'at-risk' => const Color(0xFFEF4444),
        _ => const Color(0xFF6B7280),
      };

  factory StrategicMilestone.fromJson(Map<String, dynamic> json) {
    return StrategicMilestone(
      id: json['id']?.toString() ?? '',
      pillarId: json['pillarId']?.toString() ?? '',
      horizonNumber: (json['horizonNumber'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      targetYear: (json['targetYear'] as num?)?.toInt() ?? 2027,
      targetQuarter: json['targetQuarter']?.toString() ?? 'Q4',
      status: json['status']?.toString() ?? 'planned',
      metricLabel: json['metricLabel']?.toString() ?? '',
      targetMetric: (json['targetMetric'] as num?)?.toDouble() ?? 100,
      currentMetric: (json['currentMetric'] as num?)?.toDouble() ?? 0,
      metricUnit: json['metricUnit']?.toString() ?? '%',
      linkedProjects: (json['linkedProjectIds'] as List?) ?? const [],
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pillarId': pillarId,
        'horizonNumber': horizonNumber,
        'title': title,
        'description': description,
        'targetYear': targetYear,
        'targetQuarter': targetQuarter,
        'status': status,
        'metricLabel': metricLabel,
        'targetMetric': targetMetric,
        'currentMetric': currentMetric,
        'metricUnit': metricUnit,
        'order': order,
      };
}

class StrategicVisionModel {
  final String id;
  final String title;
  final String visionStatement;
  final int startYear;
  final int targetYear;
  final String status;
  final List<StrategicHorizon> horizons;
  final List<StrategicPillar> pillars;
  final List<StrategicMilestone> milestones;

  const StrategicVisionModel({
    required this.id,
    required this.title,
    required this.visionStatement,
    required this.startYear,
    required this.targetYear,
    this.status = 'active',
    this.horizons = const [],
    this.pillars = const [],
    this.milestones = const [],
  });

  int get totalYears => (targetYear - startYear).clamp(1, 100);
  String get durationLabel => '$totalYears-Year';

  factory StrategicVisionModel.fromJson(Map<String, dynamic> json) {
    return StrategicVisionModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Vision 2040: Master Strategy',
      visionStatement: json['visionStatement']?.toString() ?? '',
      startYear: (json['startYear'] as num?)?.toInt() ?? 2026,
      targetYear: (json['targetYear'] as num?)?.toInt() ?? 2041,
      status: json['status']?.toString() ?? 'active',
      horizons: (json['horizons'] as List?)
              ?.map((e) => StrategicHorizon.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      pillars: (json['pillars'] as List?)
              ?.map((e) => StrategicPillar.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      milestones: (json['milestones'] as List?)
              ?.map((e) => StrategicMilestone.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'visionStatement': visionStatement,
        'startYear': startYear,
        'targetYear': targetYear,
        'horizons': horizons.map((h) => h.toJson()).toList(),
        'pillars': pillars.map((p) => p.toJson()).toList(),
      };
}

