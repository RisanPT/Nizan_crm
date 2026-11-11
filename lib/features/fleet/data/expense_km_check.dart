// The "km check" Accounts sees beside a driver's expense (computed by the server
// from the stored route plan — see services/expenseKmCheck.js): was there a work
// that day, how far was the route supposed to be, and what did the odometer say.

double? _num(Object? v) => (v as num?)?.toDouble();

class ExpenseKmCheck {
  final String dayKey;

  /// ok | over | under | in_progress | no_route | no_works
  final String status;

  /// ok | missing | stale — whether a current route plan was available.
  final String routeState;

  /// How many works the driver had that day.
  final int works;

  /// The day's planned route km (HQ → works → HQ); null when no current plan.
  final double? plannedKm;

  /// The way back to HQ — on no trip's odometer.
  final double? returnKm;

  /// plannedKm minus the way home: what the trips' odometer readings cover.
  final double? plannedTrackedKm;
  final double trackedKm;
  final double? varianceKm;
  final int? variancePercent;
  final double? estimatedDayKm;

  /// The work this expense was tied to (null = whole-day expense).
  final double? workPlannedKm;
  final double? workTrackedKm;
  final String? workTripStatus;

  /// It was tied to a work that is no longer on that day.
  final bool workMissing;

  const ExpenseKmCheck({
    required this.dayKey,
    required this.status,
    required this.routeState,
    required this.works,
    required this.plannedKm,
    required this.returnKm,
    required this.plannedTrackedKm,
    required this.trackedKm,
    required this.varianceKm,
    required this.variancePercent,
    required this.estimatedDayKm,
    required this.workPlannedKm,
    required this.workTrackedKm,
    required this.workTripStatus,
    required this.workMissing,
  });

  factory ExpenseKmCheck.fromJson(Map<String, dynamic> j) {
    final v = j['variance'];
    final w = j['work'];
    return ExpenseKmCheck(
      dayKey: j['dayKey'] as String? ?? '',
      status: j['status'] as String? ?? 'no_route',
      routeState: j['routeState'] as String? ?? 'ok',
      works: (j['works'] as num?)?.toInt() ?? 0,
      plannedKm: _num(j['plannedKm']),
      returnKm: _num(j['returnKm']),
      plannedTrackedKm: _num(j['plannedTrackedKm']),
      trackedKm: _num(j['trackedKm']) ?? 0,
      varianceKm: v is Map ? _num(v['km']) : null,
      variancePercent: v is Map ? (v['percent'] as num?)?.round() : null,
      estimatedDayKm: _num(j['estimatedDayKm']),
      workPlannedKm: w is Map ? _num(w['plannedKm']) : null,
      workTrackedKm: w is Map ? _num(w['trackedKm']) : null,
      workTripStatus: w is Map ? w['tripStatus'] as String? : null,
      workMissing: j['workMissing'] == true,
    );
  }
}
