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

  /// True for a sales manager: the target is the sum of every salesperson's
  /// target, computed by the server — never edited directly.
  final bool derived;

  /// For a derived target: how many salespeople it adds up.
  final int teamSize;

  const SalesTarget({
    this.salesTarget = 0,
    this.bookingsTarget = 0,
    this.note = '',
    this.setByName = '',
    this.derived = false,
    this.teamSize = 0,
  });

  bool get isEmpty => salesTarget <= 0 && bookingsTarget <= 0;

  factory SalesTarget.fromJson(Map<String, dynamic> j) => SalesTarget(
        salesTarget: _d(j['salesTarget']),
        bookingsTarget: _i(j['bookingsTarget']),
        note: j['note'] as String? ?? '',
        setByName: j['setByName'] as String? ?? '',
        derived: j['derived'] == true,
        teamSize: _i(j['teamSize']),
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

  /// Sales manager only: their own credited sales (already inside [achieved]).
  final SalesAchieved? own;

  const MyTargetProgress({
    required this.month,
    required this.year,
    required this.daysInMonth,
    required this.daysLeft,
    required this.target,
    required this.achieved,
    this.own,
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
        own: j['own'] == null ? null : SalesAchieved.fromJson((j['own'] as Map).cast<String, dynamic>()),
      );
}

/// One salesperson's row on the manager's targets screen.
class TeamTargetRow {
  final String userId, name, role;
  final bool active;
  final SalesTarget? target;
  final SalesAchieved achieved;

  /// Sales manager rows: their own credited sales (inside [achieved]).
  final SalesAchieved? own;

  const TeamTargetRow({
    required this.userId,
    required this.name,
    required this.role,
    required this.active,
    required this.target,
    required this.achieved,
    this.own,
  });

  /// A sales manager row — target is the team total, not editable.
  bool get isTeamTotal => target?.derived ?? false;

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
      own: j['own'] == null ? null : SalesAchieved.fromJson((j['own'] as Map).cast<String, dynamic>()),
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

/// One salesperson's share of a combined target.
class CombinedContribution {
  final String userId, name;
  final double salesValue;
  final int bookings;

  const CombinedContribution({
    required this.userId,
    required this.name,
    required this.salesValue,
    required this.bookings,
  });

  factory CombinedContribution.fromJson(Map<String, dynamic> j) => CombinedContribution(
        userId: j['userId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        salesValue: _d(j['salesValue']),
        bookings: _i(j['bookings']),
      );
}

/// A combined (pool) target: one goal the whole sales team works toward over
/// a date window, optionally for one package only.
class CombinedTarget {
  final String id, title, note, setByName;

  /// Inclusive IST days, 'YYYY-MM-DD'.
  final String startDay, endDay;
  final double salesTarget;
  final int bookingsTarget;

  /// Package family ('Airbrush' …); empty = every package.
  final String service;
  final SalesAchieved achieved;

  /// The signed-in user's own share.
  final SalesAchieved mine;

  /// Everyone's share (managers) or just the viewer's (salespeople).
  final List<CombinedContribution> contributions;
  final int contributors, totalDays, daysLeft;

  /// 'upcoming' | 'active' | 'ended'.
  final String status;

  const CombinedTarget({
    required this.id,
    required this.title,
    required this.note,
    required this.setByName,
    required this.startDay,
    required this.endDay,
    required this.salesTarget,
    required this.bookingsTarget,
    required this.service,
    required this.achieved,
    required this.mine,
    required this.contributions,
    required this.contributors,
    required this.totalDays,
    required this.daysLeft,
    required this.status,
  });

  DateTime get start => DateTime.parse(startDay);
  DateTime get end => DateTime.parse(endDay);

  /// Progress on the value goal, else the bookings goal (0–1+).
  double get pct => salesTarget > 0
      ? achieved.salesValue / salesTarget
      : bookingsTarget > 0
          ? achieved.bookings / bookingsTarget
          : 0;

  /// Share of the window already gone (for on-track colouring).
  double get elapsed => status == 'ended'
      ? 1
      : status == 'upcoming' || totalDays == 0
          ? 0
          : (totalDays - daysLeft + 1) / totalDays;

  factory CombinedTarget.fromJson(Map<String, dynamic> j) => CombinedTarget(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        note: j['note'] as String? ?? '',
        setByName: j['setByName'] as String? ?? '',
        startDay: j['startDay'] as String? ?? '',
        endDay: j['endDay'] as String? ?? '',
        salesTarget: _d(j['salesTarget']),
        bookingsTarget: _i(j['bookingsTarget']),
        service: j['service'] as String? ?? '',
        achieved: SalesAchieved.fromJson((j['achieved'] as Map? ?? const {}).cast<String, dynamic>()),
        mine: SalesAchieved.fromJson((j['mine'] as Map? ?? const {}).cast<String, dynamic>()),
        contributions: [
          for (final c in (j['contributions'] as List? ?? const []))
            CombinedContribution.fromJson((c as Map).cast<String, dynamic>()),
        ],
        contributors: _i(j['contributors']),
        totalDays: _i(j['totalDays']),
        daysLeft: _i(j['daysLeft']),
        status: j['status'] as String? ?? 'active',
      );
}

/// A combined target as sent to the server (create / edit).
class CombinedTargetInput {
  final String title, startDay, endDay, service, note;
  final double salesTarget;
  final int bookingsTarget;

  const CombinedTargetInput({
    required this.title,
    required this.startDay,
    required this.endDay,
    required this.salesTarget,
    required this.bookingsTarget,
    this.service = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'startDay': startDay,
        'endDay': endDay,
        'salesTarget': salesTarget,
        'bookingsTarget': bookingsTarget,
        'service': service,
        'note': note,
      };
}
