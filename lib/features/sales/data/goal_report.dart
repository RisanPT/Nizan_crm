// Models for the company Goals + day-wise report — see backend `/api/goals`.

/// Metric keys, in display order.
const kGoalMetrics = ['leads', 'bookings', 'revenue', 'trials'];

const kGoalMetricLabels = {
  'leads': 'Leads',
  'bookings': 'Bookings',
  'revenue': 'Revenue',
  'trials': 'Trial bookings',
};

double _d(Object? v) => (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
double? _dn(Object? v) => v == null ? null : _d(v);

/// One metric for the selected period: actual vs target.
class GoalMetric {
  final String key;
  final String label;
  final double actual;
  final double? target;
  final double? pct;
  const GoalMetric({required this.key, required this.label, required this.actual, this.target, this.pct});

  factory GoalMetric.fromJson(Map<String, dynamic> j) => GoalMetric(
        key: '${j['key']}',
        label: '${j['label'] ?? kGoalMetricLabels[j['key']] ?? j['key']}',
        actual: _d(j['actual']),
        target: _dn(j['target']),
        pct: _dn(j['pct']),
      );
}

/// One day inside a week / month, with its own day goals (if any).
class GoalDay {
  final String day; // yyyy-MM-dd
  final Map<String, double> values;
  final Map<String, double?> targets;
  const GoalDay({required this.day, required this.values, required this.targets});

  factory GoalDay.fromJson(Map<String, dynamic> j) {
    final t = (j['targets'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GoalDay(
      day: '${j['day']}',
      values: {for (final k in kGoalMetrics) k: _d(j[k])},
      targets: {for (final k in kGoalMetrics) k: _dn(t[k])},
    );
  }
}

class GoalReport {
  final String granularity; // day | week | month
  final String basis; // added | event
  final String start;
  final String end;
  final List<GoalMetric> metrics;
  final List<GoalDay> days;
  final bool canEdit;
  const GoalReport({
    required this.granularity,
    required this.basis,
    required this.start,
    required this.end,
    required this.metrics,
    required this.days,
    required this.canEdit,
  });

  factory GoalReport.fromJson(Map<String, dynamic> j) {
    final p = (j['period'] as Map).cast<String, dynamic>();
    return GoalReport(
      granularity: '${j['granularity']}',
      basis: '${j['basis']}',
      start: '${p['start']}',
      end: '${p['end']}',
      metrics: [for (final m in (j['metrics'] as List)) GoalMetric.fromJson((m as Map).cast<String, dynamic>())],
      days: [for (final d in (j['days'] as List)) GoalDay.fromJson((d as Map).cast<String, dynamic>())],
      canEdit: j['canEdit'] == true,
    );
  }
}

/// Month-to-date for one metric.
class MtdMetric {
  final String key;
  final String label;
  final double achieved;
  final double goal;
  final double proRatedGoal;
  final double? ratioPct;
  final double? monthPct;
  final String status; // no_goal | on_track | slightly_behind | behind
  const MtdMetric({
    required this.key,
    required this.label,
    required this.achieved,
    required this.goal,
    required this.proRatedGoal,
    this.ratioPct,
    this.monthPct,
    required this.status,
  });

  factory MtdMetric.fromJson(Map<String, dynamic> j) => MtdMetric(
        key: '${j['key']}',
        label: '${j['label'] ?? kGoalMetricLabels[j['key']] ?? j['key']}',
        achieved: _d(j['achieved']),
        goal: _d(j['goal']),
        proRatedGoal: _d(j['proRatedGoal']),
        ratioPct: _dn(j['ratioPct']),
        monthPct: _dn(j['monthPct']),
        status: '${j['status']}',
      );
}

class MtdReport {
  final String month; // yyyy-MM
  final String asOf; // yyyy-MM-dd
  final int dayOfMonth;
  final int daysInMonth;
  final String method;
  final List<MtdMetric> metrics;
  const MtdReport({
    required this.month,
    required this.asOf,
    required this.dayOfMonth,
    required this.daysInMonth,
    required this.method,
    required this.metrics,
  });

  factory MtdReport.fromJson(Map<String, dynamic> j) => MtdReport(
        month: '${j['month']}',
        asOf: '${j['asOf']}',
        dayOfMonth: (j['dayOfMonth'] as num).toInt(),
        daysInMonth: (j['daysInMonth'] as num).toInt(),
        method: '${j['method'] ?? ''}',
        metrics: [for (final m in (j['metrics'] as List)) MtdMetric.fromJson((m as Map).cast<String, dynamic>())],
      );
}

/// The goals stored for one period (null = not set).
class GoalSet {
  final String periodType;
  final String periodStart;
  final String periodEnd;
  final Map<String, double?> goals;
  final bool canEdit;
  const GoalSet({
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.goals,
    required this.canEdit,
  });

  factory GoalSet.fromJson(Map<String, dynamic> j) {
    final g = (j['goals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GoalSet(
      periodType: '${j['periodType']}',
      periodStart: '${j['periodStart']}',
      periodEnd: '${j['periodEnd'] ?? j['periodStart']}',
      goals: {for (final k in kGoalMetrics) k: _dn(g[k])},
      canEdit: j['canEdit'] == true,
    );
  }
}
