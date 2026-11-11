// How the last few months went (GET /api/monthly-objectives/trend): for the whole company and for each department this person may
// see — how many objectives were set and how far they got on average. Mirrors backend `trendSeries` in utils/monthlyObjectives.js.

import 'monthly_objective.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

/// One department in one month.
class TrendDepartment {
  const TrendDepartment({required this.departmentId, required this.name, this.count = 0, this.avgProgress = 0, this.closed = 0});
  final String departmentId;
  final String name;
  final int count;
  final int avgProgress;
  final int closed;

  /// Did it set anything that month? A month with nothing set has no progress to speak of (it is a gap, not 0%).
  bool get hasData => count > 0;

  factory TrendDepartment.fromJson(Map<String, dynamic> j) => TrendDepartment(
    departmentId: _s(j['departmentId']),
    name: _s(j['name']),
    count: _i(j['count']),
    avgProgress: _i(j['avgProgress']),
    closed: _i(j['closed']),
  );
}

/// One month: the whole (visible) company, and each department.
class TrendMonth {
  const TrendMonth({required this.year, required this.month, this.count = 0, this.avgProgress = 0, this.closed = 0, this.achieved = 0, this.departments = const []});
  final int year;
  final int month;
  final int count;
  final int avgProgress;
  final int closed;
  final int achieved;
  final List<TrendDepartment> departments;

  MonthKey get key => (year: year, month: month);
  bool get hasData => count > 0;

  /// "Nov" — the short name the chart and the matrix head their columns with.
  String get shortName => kMonthNames[month - 1].substring(0, 3);

  /// What [departmentId] did that month, or the whole company when it is null. Null when it has no such department.
  ({int count, int avgProgress, bool hasData})? of(String? departmentId) {
    if (departmentId == null) return (count: count, avgProgress: avgProgress, hasData: hasData);
    for (final d in departments) {
      if (d.departmentId == departmentId) return (count: d.count, avgProgress: d.avgProgress, hasData: d.hasData);
    }
    return null;
  }

  factory TrendMonth.fromJson(Map<String, dynamic> j) => TrendMonth(
    year: _i(j['year']),
    month: _i(j['month']),
    count: _i(j['count']),
    avgProgress: _i(j['avgProgress']),
    closed: _i(j['closed']),
    achieved: _i(j['achieved']),
    departments: [
      for (final d in (j['departments'] as List?) ?? const [])
        if (d is Map) TrendDepartment.fromJson(Map<String, dynamic>.from(d)),
    ],
  );
}

class MonthlyTrend {
  const MonthlyTrend({this.months = const []});

  /// Oldest first; the last is the month that was asked for.
  final List<TrendMonth> months;

  /// Has any month in it got something set? (Otherwise there is no trend to draw.)
  bool get hasAny => months.any((m) => m.hasData);

  /// How many months have something to plot — a line needs at least two.
  int measured(String? departmentId) => months.where((m) => m.of(departmentId)?.hasData ?? false).length;

  /// The departments of the latest month (that is the list the matrix has a row for).
  List<TrendDepartment> get departments => months.isEmpty ? const [] : months.last.departments;

  factory MonthlyTrend.fromJson(Map<String, dynamic> j) => MonthlyTrend(
    months: [
      for (final m in (j['months'] as List?) ?? const [])
        if (m is Map) TrendMonth.fromJson(Map<String, dynamic>.from(m)),
    ],
  );
}
