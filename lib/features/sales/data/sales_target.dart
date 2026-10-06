/// Monthly sales targets — see the backend `/api/sales-targets`.
///
/// Achievement rule (server-side): bookings MADE in the month (IST), net of
/// discount, credited to the booking's salesperson or else the lead's owner.
library;

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

/// A salesperson's target for one month. Zero means "no target" for that part.
class SalesTarget {
  final double salesTarget;
  final int bookingsTarget;
  final String note;
  final String setByName;

  const SalesTarget({
    this.salesTarget = 0,
    this.bookingsTarget = 0,
    this.note = '',
    this.setByName = '',
  });

  bool get isEmpty => salesTarget <= 0 && bookingsTarget <= 0;

  factory SalesTarget.fromJson(Map<String, dynamic> j) => SalesTarget(
        salesTarget: _d(j['salesTarget']),
        bookingsTarget: _i(j['bookingsTarget']),
        note: j['note'] as String? ?? '',
        setByName: j['setByName'] as String? ?? '',
      );
}

/// What was actually sold in the month.
class SalesAchieved {
  final double salesValue;
  final int bookings;

  /// Net value booked per day of the month (index 0 = day 1). Own view only.
  final List<double> daily;

  const SalesAchieved({this.salesValue = 0, this.bookings = 0, this.daily = const []});

  factory SalesAchieved.fromJson(Map<String, dynamic> j) => SalesAchieved(
        salesValue: _d(j['salesValue']),
        bookings: _i(j['bookings']),
        daily: [for (final v in (j['daily'] as List? ?? const [])) _d(v)],
      );
}

/// The signed-in salesperson's month: target + progress.
class MyTargetProgress {
  final int month, year, daysInMonth, daysLeft;
  final SalesTarget? target;
  final SalesAchieved achieved;

  const MyTargetProgress({
    required this.month,
    required this.year,
    required this.daysInMonth,
    required this.daysLeft,
    required this.target,
    required this.achieved,
  });

  factory MyTargetProgress.fromJson(Map<String, dynamic> j) => MyTargetProgress(
        month: _i(j['month']),
        year: _i(j['year']),
        daysInMonth: _i(j['daysInMonth']),
        daysLeft: _i(j['daysLeft']),
        target: j['target'] == null
            ? null
            : SalesTarget.fromJson((j['target'] as Map).cast<String, dynamic>()),
        achieved: SalesAchieved.fromJson((j['achieved'] as Map? ?? const {}).cast<String, dynamic>()),
      );
}

/// One salesperson's row on the manager's targets screen.
class TeamTargetRow {
  final String userId, name, role;
  final bool active;
  final SalesTarget? target;
  final SalesAchieved achieved;

  const TeamTargetRow({
    required this.userId,
    required this.name,
    required this.role,
    required this.active,
    required this.target,
    required this.achieved,
  });

  factory TeamTargetRow.fromJson(Map<String, dynamic> j) {
    final u = (j['user'] as Map? ?? const {}).cast<String, dynamic>();
    return TeamTargetRow(
      userId: u['id'] as String? ?? '',
      name: u['name'] as String? ?? '',
      role: u['role'] as String? ?? '',
      active: u['active'] != false,
      target: j['target'] == null
          ? null
          : SalesTarget.fromJson((j['target'] as Map).cast<String, dynamic>()),
      achieved: SalesAchieved.fromJson((j['achieved'] as Map? ?? const {}).cast<String, dynamic>()),
    );
  }
}

class TeamTargets {
  final int month, year, daysInMonth, daysLeft;
  final List<TeamTargetRow> rows;
  final double salesTarget, salesValue;
  final int bookingsTarget, bookings;

  const TeamTargets({
    required this.month,
    required this.year,
    required this.daysInMonth,
    required this.daysLeft,
    required this.rows,
    required this.salesTarget,
    required this.salesValue,
    required this.bookingsTarget,
    required this.bookings,
  });

  factory TeamTargets.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map? ?? const {}).cast<String, dynamic>();
    return TeamTargets(
      month: _i(j['month']),
      year: _i(j['year']),
      daysInMonth: _i(j['daysInMonth']),
      daysLeft: _i(j['daysLeft']),
      rows: [
        for (final r in (j['rows'] as List? ?? const []))
          TeamTargetRow.fromJson((r as Map).cast<String, dynamic>()),
      ],
      salesTarget: _d(t['salesTarget']),
      salesValue: _d(t['salesValue']),
      bookingsTarget: _i(t['bookingsTarget']),
      bookings: _i(t['bookings']),
    );
  }
}

/// A target edit sent to the server.
class SalesTargetInput {
  final String userId;
  final double salesTarget;
  final int bookingsTarget;
  final String note;

  const SalesTargetInput({
    required this.userId,
    required this.salesTarget,
    required this.bookingsTarget,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'salesTarget': salesTarget,
        'bookingsTarget': bookingsTarget,
        'note': note,
      };
}
