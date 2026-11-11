import 'models/monthly_objective.dart';

// The numbers behind the Monthly Objectives page, worked out here (pure — test/monthly_objective_stats_test.dart) so the cards only draw
// what they are told: where each objective stands, the headline counts, the filters, what is worth pointing out, and the month's days.

// ── where one objective stands ───────────────────────────────────────────────

/// What an objective is up to, in one word. An open one is judged by its progress; a closed one by how it ended.
enum ObjectiveStatus {
  notStarted,
  inProgress,
  completed,
  partly,
  missed,
  cancelled,
  postponed;

  String get label => switch (this) {
    ObjectiveStatus.notStarted => 'Not started',
    ObjectiveStatus.inProgress => 'In progress',
    ObjectiveStatus.completed => 'Completed',
    ObjectiveStatus.partly => 'Partly done',
    ObjectiveStatus.missed => 'Missed',
    ObjectiveStatus.cancelled => 'Cancelled',
    ObjectiveStatus.postponed => 'Postponed',
  };

  /// Cancelled and postponed objectives are no longer the month's plan — the server leaves them out of the average too.
  bool get isDropped => this == ObjectiveStatus.cancelled || this == ObjectiveStatus.postponed;

  /// Closed without reaching the goal: partly, missed (and the dropped ones).
  bool get endedShort => this == ObjectiveStatus.partly || this == ObjectiveStatus.missed || isDropped;
}

/// Where [o] stands. Achieved, or open with every key result done, is completed; a several-month objective that continues is still
/// in progress; an open one with nothing done yet has not started.
ObjectiveStatus statusOf(MonthlyObjective o) {
  switch (o.result) {
    case ObjectiveResult.achieved:
      return ObjectiveStatus.completed;
    case ObjectiveResult.partly:
      return ObjectiveStatus.partly;
    case ObjectiveResult.missed:
      return ObjectiveStatus.missed;
    case ObjectiveResult.continued:
      return ObjectiveStatus.inProgress;
    case ObjectiveResult.cancelled:
      return ObjectiveStatus.cancelled;
    case ObjectiveResult.deferred:
      return ObjectiveStatus.postponed;
    case null:
      if (o.progress >= 100) return ObjectiveStatus.completed;
      return o.progress > 0 ? ObjectiveStatus.inProgress : ObjectiveStatus.notStarted;
  }
}

// ── the headline numbers ─────────────────────────────────────────────────────

class MonthlyStats {
  const MonthlyStats({
    this.total = 0,
    this.completed = 0,
    this.inProgress = 0,
    this.notStarted = 0,
    this.endedShort = 0,
    this.dropped = 0,
    this.avgProgress = 0,
    this.readyToClose = 0,
    this.previousCount,
  });

  final int total;
  final int completed;
  final int inProgress;
  final int notStarted;

  /// Closed partly or missed.
  final int endedShort;

  /// Cancelled or postponed.
  final int dropped;

  /// The average progress of what is still the month's plan (cancelled and postponed ones stay out, as on the server).
  final int avgProgress;

  /// Open, every key result done: one tap from "achieved".
  final int readyToClose;

  /// How many objectives the month before had (null when that is not known).
  final int? previousCount;

  /// Everything that is neither completed, in progress nor not started: ended short, or dropped.
  int get other => endedShort + dropped;

  /// Still to finish: not started or in progress.
  int get remaining => notStarted + inProgress;

  /// [n] as a whole percent of the total (0 when there is nothing).
  int percentOf(int n) => total == 0 ? 0 : (n * 100 / total).round();

  /// How the total compares with the month before: null when that is unknown or both months are empty.
  int? get change => previousCount == null ? null : total - previousCount!;

  factory MonthlyStats.of(List<MonthlyObjective> objectives, {int? previousCount}) {
    var completed = 0, inProgress = 0, notStarted = 0, partly = 0, dropped = 0, ready = 0;
    var counted = 0, sum = 0;
    for (final o in objectives) {
      final s = statusOf(o);
      switch (s) {
        case ObjectiveStatus.completed:
          completed++;
        case ObjectiveStatus.inProgress:
          inProgress++;
        case ObjectiveStatus.notStarted:
          notStarted++;
        case ObjectiveStatus.partly:
        case ObjectiveStatus.missed:
          partly++;
        case ObjectiveStatus.cancelled:
        case ObjectiveStatus.postponed:
          dropped++;
      }
      if (!s.isDropped) {
        counted++;
        sum += o.progress;
      }
      if (o.readyToClose && !o.isClosed) ready++;
    }
    return MonthlyStats(
      total: objectives.length,
      completed: completed,
      inProgress: inProgress,
      notStarted: notStarted,
      endedShort: partly,
      dropped: dropped,
      avgProgress: counted == 0 ? 0 : (sum / counted).round(),
      readyToClose: ready,
      previousCount: previousCount,
    );
  }
}

// ── the days of a month ──────────────────────────────────────────────────────

/// Where a month is relative to today.
enum MonthTiming { past, current, future }

MonthTiming timingOf(MonthKey m, DateTime now) {
  final a = m.year * 12 + m.month;
  final b = now.year * 12 + now.month;
  return a < b ? MonthTiming.past : (a > b ? MonthTiming.future : MonthTiming.current);
}

DateTime firstDayOf(MonthKey m) => DateTime(m.year, m.month, 1);
DateTime lastDayOf(MonthKey m) => DateTime(m.year, m.month + 1, 0);
int daysIn(MonthKey m) => lastDayOf(m).day;

String _dd(int d) => d.toString().padLeft(2, '0');
String _mon(int month) => kMonthNames[month - 1].substring(0, 3);

/// "30 Nov" — the month's last day, for "by 30 Nov".
String lastDayText(MonthKey m) => '${lastDayOf(m).day} ${_mon(m.month)}';

/// "01 Nov 2026 – 30 Nov 2026 (30 days)".
String rangeText(MonthKey m) => '${_dd(1)} ${_mon(m.month)} ${m.year} – ${_dd(daysIn(m))} ${_mon(m.month)} ${m.year} (${daysIn(m)} days)';

/// Days left in the month counting from [now] (0 on its last day; 0 for a month that is not the current one).
int daysLeft(MonthKey m, DateTime now) => timingOf(m, now) == MonthTiming.current ? daysIn(m) - now.day : 0;

// ── filters ──────────────────────────────────────────────────────────────────

/// What the table is narrowed to. Empty means everything.
class ObjectiveFilter {
  const ObjectiveFilter({this.query = '', this.statuses = const {}, this.priorities = const {}, this.departmentId, this.onlyMine = false});

  final String query;
  final Set<ObjectiveStatus> statuses;
  final Set<String> priorities;
  final String? departmentId;
  final bool onlyMine;

  /// How many of the filter's choices are in use (what the "Filters" button counts; the search box and the department have their own
  /// place on the page).
  int get activeCount => (statuses.isEmpty ? 0 : 1) + (priorities.isEmpty ? 0 : 1) + (onlyMine ? 1 : 0);

  bool get isEmpty => query.trim().isEmpty && activeCount == 0 && departmentId == null;

  ObjectiveFilter copyWith({String? query, Set<ObjectiveStatus>? statuses, Set<String>? priorities, Object? departmentId = _keep, bool? onlyMine}) => ObjectiveFilter(
    query: query ?? this.query,
    statuses: statuses ?? this.statuses,
    priorities: priorities ?? this.priorities,
    departmentId: identical(departmentId, _keep) ? this.departmentId : departmentId as String?,
    onlyMine: onlyMine ?? this.onlyMine,
  );

  bool matches(MonthlyObjective o) {
    if (departmentId != null && o.departmentId != departmentId) return false;
    if (statuses.isNotEmpty && !statuses.contains(statusOf(o))) return false;
    if (priorities.isNotEmpty && !priorities.contains(o.priority)) return false;
    if (onlyMine && !o.assignedToMe) return false;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = '${o.objective} ${o.ownerName} ${o.departmentName} ${o.description} ${o.keyResults.map((k) => k.title).join(' ')}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }

  List<MonthlyObjective> apply(List<MonthlyObjective> all) => [for (final o in all) if (matches(o)) o];
}

const Object _keep = Object();

// ── what is worth pointing out ───────────────────────────────────────────────

enum TakeawayTone { good, info, neutral, warn, bad }

class Takeaway {
  const Takeaway(this.tone, this.text);
  final TakeawayTone tone;
  final String text;

  @override
  String toString() => '${tone.name}: $text';
}

String _plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// "IT, HR" / "IT, HR +2 more" — the first few distinct names.
String _names(Iterable<String> all, {int max = 3}) {
  final seen = <String>[];
  for (final n in all) {
    if (n.isNotEmpty && !seen.contains(n)) seen.add(n);
  }
  if (seen.length <= max) return seen.join(', ');
  return '${seen.take(max).join(', ')} +${seen.length - max} more';
}

/// What stands out about [departments]' month, most useful first: what is done, moving or not started and in whose hands; who has set
/// nothing; what is one tap from done; last month's loose ends; and — for the current month — how much is still to finish by its last day.
List<Takeaway> takeawaysFor(List<MonthlyDepartment> departments, MonthKey month, DateTime now) {
  final all = [for (final d in departments) ...d.objectives];
  final stats = MonthlyStats.of(all);
  List<String> deptsWith(bool Function(ObjectiveStatus) test) => [for (final o in all) if (test(statusOf(o))) o.departmentName];

  final out = <Takeaway>[];
  if (stats.completed > 0) {
    out.add(Takeaway(TakeawayTone.good, '${_plural(stats.completed, 'objective')} completed (${_names(deptsWith((s) => s == ObjectiveStatus.completed))})'));
  }
  if (stats.inProgress > 0) {
    out.add(Takeaway(TakeawayTone.info, '${_plural(stats.inProgress, 'objective')} in progress (${_names(deptsWith((s) => s == ObjectiveStatus.inProgress))})'));
  }
  if (stats.notStarted > 0) {
    out.add(Takeaway(TakeawayTone.neutral, '${_plural(stats.notStarted, 'objective')} not started (${_names(deptsWith((s) => s == ObjectiveStatus.notStarted))})'));
  }
  if (stats.other > 0) {
    out.add(Takeaway(TakeawayTone.warn, '${_plural(stats.other, 'objective')} ended short or ${stats.other == 1 ? 'was' : 'were'} dropped (${_names(deptsWith((s) => s.endedShort))})'));
  }
  final empty = [for (final d in departments) if (d.isEmpty) d.name];
  if (empty.isNotEmpty) {
    out.add(Takeaway(TakeawayTone.warn, 'No objectives set yet: ${_names(empty, max: 4)}'));
  }
  if (stats.readyToClose > 0) {
    out.add(Takeaway(TakeawayTone.good, '${_plural(stats.readyToClose, 'objective')} ready to close as achieved'));
  }
  final unclosed = departments.fold<int>(0, (s, d) => s + d.lastMonth.open);
  if (unclosed > 0) {
    out.add(Takeaway(TakeawayTone.warn, '${_plural(unclosed, 'objective')} from ${kMonthNames[prevMonthOf(month).month - 1]} ${unclosed == 1 ? 'was' : 'were'} never closed out'));
  }
  final left = stats.remaining;
  if (left > 0 && stats.total > 0) {
    switch (timingOf(month, now)) {
      case MonthTiming.current:
        final d = daysLeft(month, now);
        out.add(
          Takeaway(
            d <= 5 ? TakeawayTone.bad : TakeawayTone.info,
            '$left of ${stats.total} (${stats.percentOf(left)}%) still to finish by ${lastDayText(month)} — ${d == 0 ? 'last day today' : '${_plural(d, 'day')} left'}',
          ),
        );
      case MonthTiming.past:
        out.add(Takeaway(TakeawayTone.bad, '$left of ${stats.total} (${stats.percentOf(left)}%) ${left == 1 ? 'was' : 'were'} still open when ${kMonthNames[month.month - 1]} ended'));
      case MonthTiming.future:
        break;
    }
  }
  return out;
}

// ── key results across the month ─────────────────────────────────────────────

/// One key result with the objective it belongs to, for the Key Results tab.
class KeyResultRow {
  const KeyResultRow({required this.objective, required this.keyResult});
  final MonthlyObjective objective;
  final MonthlyKeyResult keyResult;

  bool get done => keyResult.completed || keyResult.attainment >= 100;
}

enum KeyResultFilter { all, open, done }

/// Every key result of [objectives] (cancelled and postponed objectives' are left out: they are no longer the plan), unfinished ones
/// first, then by department and objective as they were given.
List<KeyResultRow> keyResultRows(List<MonthlyObjective> objectives, {KeyResultFilter filter = KeyResultFilter.all}) {
  final rows = <KeyResultRow>[
    for (final o in objectives)
      if (!statusOf(o).isDropped)
        for (final k in o.keyResults) KeyResultRow(objective: o, keyResult: k),
  ];
  final shown = switch (filter) {
    KeyResultFilter.all => rows,
    KeyResultFilter.open => [for (final r in rows) if (!r.done) r],
    KeyResultFilter.done => [for (final r in rows) if (r.done) r],
  };
  // stable: Dart's List.sort is not, so rank by position too
  final order = <KeyResultRow, int>{for (var i = 0; i < shown.length; i++) shown[i]: i};
  shown.sort((a, b) {
    final c = (a.done ? 1 : 0) - (b.done ? 1 : 0);
    return c != 0 ? c : order[a]! - order[b]!;
  });
  return shown;
}

// ── the progress matrix ──────────────────────────────────────────────────────

/// How a cell of the matrix is judged, from a department's average progress in a month (null: it set nothing).
enum Heat { none, low, mid, high, full }

Heat heatOf(int? percent) {
  if (percent == null) return Heat.none;
  if (percent >= 100) return Heat.full;
  if (percent >= 70) return Heat.high;
  if (percent >= 40) return Heat.mid;
  return Heat.low;
}
