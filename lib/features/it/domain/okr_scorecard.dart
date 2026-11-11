import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';

// The OKR scorecard: how objectives are doing, added up by department, owner, level or project, and
// what needs somebody now (objectives in trouble, key results nobody has reported on). Pure.

/// What the scorecard adds objectives up by.
enum OkrGroupBy {
  department,
  owner,
  level,
  project;

  String get label => switch (this) {
        OkrGroupBy.department => 'Department',
        OkrGroupBy.owner => 'Owner',
        OkrGroupBy.level => 'Level',
        OkrGroupBy.project => 'Project',
      };
}

/// A key result that needs a check-in.
class OkrStaleKr {
  const OkrStaleKr(this.okr, this.kr, this.lastCheckIn);

  final OKRModel okr;
  final KeyResultItem kr;

  /// Null = never reported on.
  final DateTime? lastCheckIn;
}

/// An objective that needs attention, and where it stands.
class OkrAttention {
  const OkrAttention(this.okr, this.pace);

  final OKRModel okr;
  final OkrPace pace;
}

/// One line of the scorecard.
class OkrScoreGroup {
  const OkrScoreGroup({
    required this.name,
    required this.okrs,
    required this.health,
    required this.avgProgress,
    required this.overdue,
    required this.staleKeyResults,
    required this.keyResults,
    required this.nextDue,
  });

  final String name;
  final List<OKRModel> okrs;
  final Map<OkrHealth, int> health;

  /// The average progress of its objectives (percent).
  final int avgProgress;

  /// Objectives past their deadline and not finished.
  final int overdue;

  final int staleKeyResults;
  final int keyResults;

  /// The nearest deadline among the objectives still open (null if none has one).
  final DateTime? nextDue;

  int count(OkrHealth h) => health[h] ?? 0;

  /// At risk + off track + blocked.
  int get attention => health.entries.where((e) => e.key.needsAttention).fold(0, (a, e) => a + e.value);

  /// Of the objectives that can be judged (dated, started, not blocked-unknown), the share that is
  /// done or on track (percent). Null when none can be judged.
  int? get healthyPercent {
    final good = count(OkrHealth.done) + count(OkrHealth.onTrack);
    final judged = good + attention;
    return judged == 0 ? null : (good * 100 / judged).round();
  }
}

class OkrScorecard {
  const OkrScorecard({required this.overall, required this.groups, required this.attention, required this.stale});

  final OkrScoreGroup overall;
  final List<OkrScoreGroup> groups;

  /// Objectives in trouble, worst first.
  final List<OkrAttention> attention;

  /// Key results that need a check-in, longest-quiet first.
  final List<OkrStaleKr> stale;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

OkrScoreGroup _group(String name, List<OKRModel> okrs, DateTime now) {
  final health = <OkrHealth, int>{};
  var overdue = 0;
  var stale = 0;
  var krs = 0;
  DateTime? nextDue;
  var sum = 0;
  for (final o in okrs) {
    final pace = okrPace(o, now);
    health[pace.health] = (health[pace.health] ?? 0) + 1;
    if (pace.overdueDays > 0) overdue++;
    sum += pace.progress;
    krs += o.keyResults.length;
    stale += o.keyResults.where((k) => krIsStale(o, k, now)).length;
    final due = o.deadline;
    if (due != null && pace.health != OkrHealth.done) {
      final d = _day(due);
      if (!d.isBefore(_day(now)) && (nextDue == null || d.isBefore(nextDue))) nextDue = d;
    }
  }
  return OkrScoreGroup(
    name: name,
    okrs: okrs,
    health: health,
    avgProgress: okrs.isEmpty ? 0 : (sum / okrs.length).round(),
    overdue: overdue,
    staleKeyResults: stale,
    keyResults: krs,
    nextDue: nextDue,
  );
}

/// The name of the line [o] belongs to when adding up [by].
String okrGroupName(OKRModel o, OkrGroupBy by) {
  switch (by) {
    case OkrGroupBy.department:
      return switch (o.effectiveLevel) {
        'company' => 'Company-wide',
        'department' => o.department.trim().isEmpty ? 'No department' : o.department.trim(),
        _ => o.projectDepartment.trim().isEmpty ? 'Unassigned department' : o.projectDepartment.trim(),
      };
    case OkrGroupBy.owner:
      return o.projectHeadName.trim().isEmpty ? 'Nobody named' : o.projectHeadName.trim();
    case OkrGroupBy.level:
      return switch (o.effectiveLevel) {
        'company' => 'Company',
        'department' => 'Department',
        _ => 'Project',
      };
    case OkrGroupBy.project:
      return o.effectiveLevel == 'project' ? (o.projectName.trim().isEmpty ? 'Unnamed project' : o.projectName.trim()) : 'Not tied to a project';
  }
}

/// Adds [okrs] up on [now], by [by]. Lines run worst first (most objectives needing attention, then
/// the lowest progress); by level they run company → department → project.
OkrScorecard buildOkrScorecard(List<OKRModel> okrs, DateTime now, OkrGroupBy by) {
  final byName = <String, List<OKRModel>>{};
  for (final o in okrs) {
    (byName[okrGroupName(o, by)] ??= []).add(o);
  }
  final groups = [for (final e in byName.entries) _group(e.key, e.value, now)];
  if (by == OkrGroupBy.level) {
    const order = ['Company', 'Department', 'Project'];
    groups.sort((a, b) => order.indexOf(a.name).compareTo(order.indexOf(b.name)));
  } else {
    groups.sort((a, b) {
      final c = b.attention.compareTo(a.attention);
      if (c != 0) return c;
      final p = a.avgProgress.compareTo(b.avgProgress);
      return p != 0 ? p : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  final attention = <OkrAttention>[
    for (final o in okrs)
      if (okrPace(o, now).health.needsAttention) OkrAttention(o, okrPace(o, now)),
  ]..sort(_worstFirst);

  final stale = <OkrStaleKr>[
    for (final o in okrs)
      for (final k in o.keyResults)
        if (krIsStale(o, k, now)) OkrStaleKr(o, k, k.lastCheckInAt),
  ]..sort((a, b) {
      if (a.lastCheckIn == null || b.lastCheckIn == null) {
        if (a.lastCheckIn == b.lastCheckIn) return a.okr.objective.compareTo(b.okr.objective);
        return a.lastCheckIn == null ? -1 : 1; // never reported first
      }
      return a.lastCheckIn!.compareTo(b.lastCheckIn!);
    });

  return OkrScorecard(overall: _group('All objectives', okrs, now), groups: groups, attention: attention, stale: stale);
}

/// Overdue first (longest overdue first), then off track (furthest behind first), then blocked,
/// then at risk (furthest behind first); ties by title.
int _worstFirst(OkrAttention a, OkrAttention b) {
  int rank(OkrAttention x) {
    if (x.pace.overdueDays > 0) return 0;
    return switch (x.pace.health) {
      OkrHealth.offTrack => 1,
      OkrHealth.blocked => 2,
      _ => 3,
    };
  }

  final r = rank(a).compareTo(rank(b));
  if (r != 0) return r;
  final magnitude = rank(a) == 0 ? b.pace.overdueDays.compareTo(a.pace.overdueDays) : (b.pace.gap ?? 0).compareTo(a.pace.gap ?? 0);
  return magnitude != 0 ? magnitude : a.okr.objective.toLowerCase().compareTo(b.okr.objective.toLowerCase());
}
