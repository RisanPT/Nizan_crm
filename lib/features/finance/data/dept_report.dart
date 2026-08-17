import 'package:intl/intl.dart';

// Data models for the config-driven departmental month-end reviews
// (GET/PUT /reports/department/:dept).

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

class DeptInfo {
  final String key, label;
  final int reviewMinutes, planningMinutes;
  const DeptInfo(this.key, this.label, this.reviewMinutes, this.planningMinutes);
  factory DeptInfo.fromJson(Map<String, dynamic> j) => DeptInfo(
        j['key'] as String? ?? '',
        j['label'] as String? ?? '',
        (j['reviewMinutes'] as num?)?.toInt() ?? 45,
        (j['planningMinutes'] as num?)?.toInt() ?? 30,
      );
}

class DeptMetric {
  final String key, label, unit; // unit: inr|pct|count|days|ratio|text
  final bool auto;
  final dynamic value; // num | String | null

  const DeptMetric({required this.key, required this.label, required this.unit, required this.auto, this.value});

  factory DeptMetric.fromJson(Map<String, dynamic> j) => DeptMetric(
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        unit: j['unit'] as String? ?? 'text',
        auto: j['auto'] as bool? ?? false,
        value: j['value'],
      );

  bool get isText => unit == 'text';
  bool get hasValue => value != null && value.toString().isNotEmpty;

  /// Human display of the current value.
  String get display {
    if (!hasValue) return '—';
    if (unit == 'text') return value.toString();
    final n = (value is num) ? value as num : num.tryParse(value.toString());
    if (n == null) return value.toString();
    return switch (unit) {
      'inr' => _inr.format(n),
      'pct' => '${n.toStringAsFixed(1)}%',
      'ratio' => n.toStringAsFixed(2),
      'days' => '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)} days',
      _ => n.toStringAsFixed(0),
    };
  }
}

class DeptSection {
  final String title;
  final List<DeptMetric> metrics;
  const DeptSection(this.title, this.metrics);
  factory DeptSection.fromJson(Map<String, dynamic> j) => DeptSection(
        j['title'] as String? ?? '',
        (j['metrics'] as List<dynamic>? ?? const [])
            .map((e) => DeptMetric.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DeptTargetField {
  final String key, label, unit;
  const DeptTargetField(this.key, this.label, this.unit);
  factory DeptTargetField.fromJson(Map<String, dynamic> j) =>
      DeptTargetField(j['key'] as String? ?? '', j['label'] as String? ?? '', j['unit'] as String? ?? 'text');
}

class DeptAllocation {
  final String name;
  final double amount;
  const DeptAllocation(this.name, this.amount);
  factory DeptAllocation.fromJson(Map<String, dynamic> j) =>
      DeptAllocation(j['name'] as String? ?? '', (j['amount'] as num?)?.toDouble() ?? 0);
  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};
}

class DeptActionItem {
  final String text, owner;
  final DateTime? dueDate;
  final bool done;
  const DeptActionItem({required this.text, this.owner = '', this.dueDate, this.done = false});
  factory DeptActionItem.fromJson(Map<String, dynamic> j) => DeptActionItem(
        text: j['text'] as String? ?? '',
        owner: j['owner'] as String? ?? '',
        dueDate: DateTime.tryParse(j['dueDate']?.toString() ?? '')?.toLocal(),
        done: j['done'] as bool? ?? false,
      );
  Map<String, dynamic> toJson() =>
      {'text': text, 'owner': owner, 'dueDate': dueDate?.toIso8601String(), 'done': done};
}

class DeptReport {
  final String department, label;
  final int month, year, reviewMinutes, planningMinutes;
  final List<DeptSection> sections;
  final List<DeptMetric> kpis;
  final List<DeptTargetField> targetsConfig;
  final Map<String, dynamic> targets;
  final List<DeptAllocation> allocations;
  final List<DeptActionItem> actionItems;
  final String notes;

  const DeptReport({
    required this.department,
    required this.label,
    required this.month,
    required this.year,
    required this.reviewMinutes,
    required this.planningMinutes,
    required this.sections,
    required this.kpis,
    required this.targetsConfig,
    required this.targets,
    required this.allocations,
    required this.actionItems,
    required this.notes,
  });

  factory DeptReport.fromJson(Map<String, dynamic> j) => DeptReport(
        department: j['department'] as String? ?? '',
        label: j['label'] as String? ?? '',
        month: (j['month'] as num?)?.toInt() ?? 1,
        year: (j['year'] as num?)?.toInt() ?? 2000,
        reviewMinutes: (j['reviewMinutes'] as num?)?.toInt() ?? 45,
        planningMinutes: (j['planningMinutes'] as num?)?.toInt() ?? 30,
        sections: (j['sections'] as List<dynamic>? ?? const [])
            .map((e) => DeptSection.fromJson(e as Map<String, dynamic>))
            .toList(),
        kpis: (j['kpis'] as List<dynamic>? ?? const [])
            .map((e) => DeptMetric.fromJson(e as Map<String, dynamic>))
            .toList(),
        targetsConfig: (j['targetsConfig'] as List<dynamic>? ?? const [])
            .map((e) => DeptTargetField.fromJson(e as Map<String, dynamic>))
            .toList(),
        targets: (j['targets'] as Map<String, dynamic>?) ?? const {},
        allocations: (j['allocations'] as List<dynamic>? ?? const [])
            .map((e) => DeptAllocation.fromJson(e as Map<String, dynamic>))
            .toList(),
        actionItems: (j['actionItems'] as List<dynamic>? ?? const [])
            .map((e) => DeptActionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: j['notes'] as String? ?? '',
      );

  /// All manually-entered metric keys → whether they currently hold a value
  /// (used to seed the edit form).
  List<DeptMetric> get manualMetrics =>
      sections.expand((s) => s.metrics).where((mm) => !mm.auto).toList();
}
