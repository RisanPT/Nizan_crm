import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';

// What the Company Projects dashboard shows, worked out from the projects and tasks the server already sends.
// Pure (no widgets, no providers) — test/project_dashboard_stats_test.dart.
//
// Nothing here is invented: where the data cannot answer a question (a project has no spend figure, no
// "completed on" date) the dashboard does not pretend to, see the notes on each function.

enum DashboardPeriod {
  week('This Week'),
  month('This Month'),
  quarter('This Quarter'),
  year('This Year'),
  custom('Custom');

  const DashboardPeriod(this.label);
  final String label;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [a] to [b] (UTC arithmetic: a daylight-saving change never makes a day 23 hours).
int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// A stretch of calendar days, both ends included.
class DaySpan {
  DaySpan(DateTime start, DateTime end) : start = _day(start), end = _day(end);

  final DateTime start;
  final DateTime end; // the LAST day

  int get days => daysBetween(start, end) + 1;

  bool contains(DateTime d) {
    final x = _day(d);
    return !x.isBefore(start) && !x.isAfter(end);
  }

  @override
  bool operator ==(Object other) => other is DaySpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// The days a period covers around [now]. Weeks run Monday to Sunday.
DaySpan periodSpan(DashboardPeriod p, DateTime now, {DaySpan? custom}) {
  final t = _day(now);
  switch (p) {
    case DashboardPeriod.week:
      final monday = DateTime(t.year, t.month, t.day - (t.weekday - 1));
      return DaySpan(monday, DateTime(monday.year, monday.month, monday.day + 6));
    case DashboardPeriod.month:
      return DaySpan(DateTime(t.year, t.month, 1), DateTime(t.year, t.month + 1, 0));
    case DashboardPeriod.quarter:
      final q = (t.month - 1) ~/ 3;
      return DaySpan(DateTime(t.year, q * 3 + 1, 1), DateTime(t.year, q * 3 + 4, 0));
    case DashboardPeriod.year:
      return DaySpan(DateTime(t.year, 1, 1), DateTime(t.year, 12, 31));
    case DashboardPeriod.custom:
      return custom ?? periodSpan(DashboardPeriod.year, now);
  }
}

/// What a project's status means on the dashboard.
enum ProjectBucket {
  completed('Completed'),
  inProgress('In Progress'),
  onHold('On Hold'),
  notStarted('Not Started'),
  cancelled('Cancelled');

  const ProjectBucket(this.label);
  final String label;
}

ProjectBucket bucketOf(Project p) => switch (p.status) {
  'completed' => ProjectBucket.completed,
  'active' => ProjectBucket.inProgress,
  'on-hold' => ProjectBucket.onHold,
  'cancelled' => ProjectBucket.cancelled,
  _ => ProjectBucket.notStarted, // planning, and a proposal still waiting for its decision
};

bool _finished(Project p) => p.status == 'completed' || p.status == 'cancelled';

/// Past its end date and not finished. The end day itself is still on time.
bool isOverdue(Project p, DateTime now) => p.endDate != null && _day(p.endDate!).isBefore(_day(now)) && !_finished(p);

/// Does the project run during [span]? A project with no dates cannot be placed on a calendar, so it is never
/// hidden; one with a start but no end is taken to be still running (unless it is finished).
bool projectInSpan(Project p, DaySpan span) {
  final s = p.startDate == null ? null : _day(p.startDate!);
  final e = p.endDate == null ? null : _day(p.endDate!);
  if (s == null && e == null) return true;
  final from = s ?? e!;
  final to = e ?? (_finished(p) ? from : DateTime(9999));
  return !from.isAfter(span.end) && !to.isBefore(span.start);
}

/// "it" → "IT", "hr" → "HR", "research-and-development" → "Research and development".
String deptLabel(String s) {
  final t = s.trim();
  if (t.isEmpty) return 'Unassigned';
  final l = t.toLowerCase();
  if (l == 'it' || l == 'hr' || l == 'crm') return l.toUpperCase();
  return t[0].toUpperCase() + t.substring(1).replaceAll('-', ' ');
}

class StatusSlice {
  const StatusSlice(this.bucket, this.count);
  final ProjectBucket bucket;
  final int count;
}

/// One department's share of the work.
class DeptStat {
  const DeptStat({required this.name, required this.projects, required this.progress, required this.tasks, required this.done});
  final String name;

  /// Projects it is on (a project several departments work on counts under each of them).
  final int projects;

  /// 0..100, averaged over the department's own tasks (weighted by how many each project has).
  final int progress;
  final int tasks;
  final int done;
}

/// Per-department roll-up of [projects]: how many it is on and how far its own tasks have got. A project with
/// several departments carries each one's progress; one with a single department uses the project's own number.
List<DeptStat> departmentStats(List<Project> projects) {
  final names = <String, String>{}; // lower-case key → label
  final count = <String, int>{};
  final weighted = <String, double>{};
  final weight = <String, int>{};
  final tasks = <String, int>{};
  final done = <String, int>{};

  void add(String dept, {required int progress, required int taskCount, required int doneCount}) {
    final key = dept.trim().toLowerCase();
    names.putIfAbsent(key, () => deptLabel(dept));
    final w = taskCount < 1 ? 1 : taskCount; // a project with no tasks yet still counts, as 0%
    weighted[key] = (weighted[key] ?? 0) + progress * w;
    weight[key] = (weight[key] ?? 0) + w;
    tasks[key] = (tasks[key] ?? 0) + taskCount;
    done[key] = (done[key] ?? 0) + doneCount;
  }

  for (final p in projects) {
    final depts = p.departmentNames.isEmpty ? const ['Unassigned'] : p.departmentNames;
    for (final d in depts) {
      count[d.trim().toLowerCase()] = (count[d.trim().toLowerCase()] ?? 0) + 1;
    }
    final own = {for (final dp in p.departmentProgress) dp.name.trim().toLowerCase(): dp};
    for (final d in depts) {
      final dp = own[d.trim().toLowerCase()];
      if (dp != null) {
        add(d, progress: dp.progress, taskCount: dp.tasks, doneCount: dp.done);
      } else {
        add(d, progress: p.progress, taskCount: p.totalTasks, doneCount: p.completedTasks);
      }
    }
  }

  final out = [
    for (final k in names.keys)
      DeptStat(
        name: names[k]!,
        projects: count[k] ?? 0,
        progress: weight[k] == 0 ? 0 : (weighted[k]! / weight[k]!).round(),
        tasks: tasks[k] ?? 0,
        done: done[k] ?? 0,
      ),
  ];
  out.sort((a, b) => b.projects != a.projects ? b.projects.compareTo(a.projects) : a.name.compareTo(b.name));
  return out;
}

/// The departments ranked by how far their tasks have got — only those with some work to measure.
List<DeptStat> topDepartments(List<DeptStat> all, {int limit = 5}) {
  final ranked = all.where((d) => d.tasks > 0).toList()
    ..sort((a, b) => b.progress != a.progress ? b.progress.compareTo(a.progress) : b.tasks.compareTo(a.tasks));
  return ranked.take(limit).toList();
}

/// Tasks that are not split into smaller ones — the unit progress is counted in (the server does the same).
List<ITTask> leafTasks(List<ITTask> tasks) {
  final parents = {
    for (final t in tasks)
      if (t.parentTaskId != null && t.parentTaskId!.isNotEmpty) t.parentTaskId!,
  };
  return [
    for (final t in tasks)
      if (!parents.contains(t.id)) t,
  ];
}

class TaskTotals {
  const TaskTotals({this.total = 0, this.done = 0, this.overdue = 0});
  final int total;
  final int done;
  final int overdue; // not done, and past its due day
  int get open => total - done;
  int get percentDone => total == 0 ? 0 : (done * 100 / total).round();
}

TaskTotals taskTotals(List<ITTask> tasks, DateTime now) {
  final leaves = leafTasks(tasks);
  var done = 0, overdue = 0;
  for (final t in leaves) {
    if (t.isCompleted) {
      done++;
    } else if (t.dueDate != null && _day(t.dueDate!).isBefore(_day(now))) {
      overdue++;
    }
  }
  return TaskTotals(total: leaves.length, done: done, overdue: overdue);
}

/// Tasks per department: the task's own department, else the one that owns its project.
Map<String, int> tasksByDepartment(List<ITTask> tasks, Map<String, Project> projectsById) {
  final out = <String, int>{};
  for (final t in leafTasks(tasks)) {
    final dept = t.departmentName.isNotEmpty ? t.departmentName : (projectsById[t.projectId]?.targetDepartment ?? '');
    final label = deptLabel(dept);
    out[label] = (out[label] ?? 0) + 1;
  }
  return out;
}

enum TrendWindow {
  yearly('Yearly'),
  quarterly('Quarterly'),
  monthly('Monthly');

  const TrendWindow(this.label);
  final String label;
}

class TrendPoint {
  const TrendPoint(this.at, this.percent);
  final DateTime at;

  /// null = nothing existed yet to measure.
  final double? percent;
}

/// Share of tasks that were done at each point in time, from when tasks were created and completed.
/// A task finished before completion dates were recorded cannot be placed in time, so it is left out
/// altogether rather than guessed at. Yearly = 12 month ends, Quarterly = 13 weeks, Monthly = 30 days
/// in 3-day steps; the last point is always [now].
List<TrendPoint> completionTrend(List<ITTask> tasks, TrendWindow window, DateTime now) {
  final today = _day(now);
  final ends = <DateTime>[];
  switch (window) {
    case TrendWindow.yearly:
      for (var i = 11; i >= 1; i--) {
        ends.add(DateTime(today.year, today.month - i + 1, 0)); // last day of the month i months back
      }
      ends.add(today);
    case TrendWindow.quarterly:
      for (var i = 12; i >= 0; i--) {
        ends.add(DateTime(today.year, today.month, today.day - 7 * i));
      }
    case TrendWindow.monthly:
      for (var i = 10; i >= 0; i--) {
        ends.add(DateTime(today.year, today.month, today.day - 3 * i));
      }
  }

  final leaves = [
    for (final t in leafTasks(tasks))
      if (!(t.isCompleted && t.completedAt == null)) t,
  ];
  return [
    for (final end in ends)
      () {
        final until = DateTime(end.year, end.month, end.day, 23, 59, 59);
        var existing = 0, done = 0;
        for (final t in leaves) {
          if (t.createdAt != null && t.createdAt!.isAfter(until)) continue;
          existing++;
          if (t.completedAt != null && !t.completedAt!.isAfter(until)) done++;
        }
        return TrendPoint(end, existing == 0 ? null : done * 100 / existing);
      }(),
  ];
}

/// One row of "Upcoming & Ongoing Projects".
class TimelineRow {
  const TimelineRow(this.project, this.bucket, this.overdue);
  final Project project;
  final ProjectBucket bucket;
  final bool overdue;
}

/// Projects still to finish that have both dates (so they can be drawn), earliest start first.
List<TimelineRow> upcomingProjects(List<Project> projects, DateTime now, {int limit = 5}) {
  final rows = [
    for (final p in projects)
      if (p.startDate != null && p.endDate != null && !_finished(p) && !p.isProposed) TimelineRow(p, bucketOf(p), isOverdue(p, now)),
  ]..sort((a, b) => a.project.startDate!.compareTo(b.project.startDate!));
  return rows.take(limit).toList();
}

/// One department's share of the money: what the finance head approved for its projects, and what has been charged.
class DeptBudget {
  const DeptBudget({required this.name, required this.approved, required this.used});
  final String name;
  final double approved;
  final double used;
  double? get fraction => approved > 0 ? used / approved : null;
}

/// The money across the projects whose cost the finance head approved — only those whose amounts this person may see
/// (the server sends nobody else's), so what is totalled is exactly what they are allowed to know.
class BudgetTotals {
  const BudgetTotals({
    this.projects = 0,
    this.approved = 0,
    this.spent = 0,
    this.committed = 0,
    this.byDepartment = const [],
    this.over = const [],
    this.near = const [],
  });

  /// How many projects are in the totals.
  final int projects;
  final double approved;
  final double spent;
  final double committed;
  final List<DeptBudget> byDepartment;

  /// Projects past their approved budget / at 80% or more of it (most used first).
  final List<Project> over;
  final List<Project> near;

  double get used => spent + committed;
  double get available => approved - used;
  double? get fraction => approved > 0 ? used / approved : null;
  String get level {
    if (approved <= 0) return 'none';
    if (used > approved) return 'over';
    return used * 100 >= approved * 80 ? 'warn' : 'ok';
  }
}

/// Totals over [projects]. A project the viewer may not see the money of (cost null), one with no approved limit yet, or a
/// cancelled one is left out.
BudgetTotals budgetTotals(List<Project> projects) {
  var approved = 0.0, spent = 0.0, committed = 0.0, n = 0;
  final dept = <String, (double, double)>{};
  final over = <Project>[], near = <Project>[];
  for (final p in projects) {
    final c = p.cost;
    if (c == null || c.approvedBudget <= 0 || p.status == 'cancelled') continue;
    n++;
    approved += c.approvedBudget;
    spent += c.spent;
    committed += c.committed;
    final key = deptLabel(p.targetDepartment);
    final cur = dept[key] ?? (0.0, 0.0);
    dept[key] = (cur.$1 + c.approvedBudget, cur.$2 + c.used);
    if (c.level == 'over') {
      over.add(p);
    } else if (c.level == 'warn') {
      near.add(p);
    }
  }
  int byUse(Project a, Project b) => (b.cost!.usedFraction ?? 0).compareTo(a.cost!.usedFraction ?? 0);
  over.sort(byUse);
  near.sort(byUse);
  final rows = [for (final e in dept.entries) DeptBudget(name: e.key, approved: e.value.$1, used: e.value.$2)]..sort((a, b) => b.used.compareTo(a.used));
  return BudgetTotals(projects: n, approved: approved, spent: spent, committed: committed, byDepartment: rows, over: over, near: near);
}

/// A short sentence the dashboard can say about the portfolio, with how it should feel.
enum InsightTone { good, info, warn, bad }

class Insight {
  const Insight(this.tone, this.title, this.detail);
  final InsightTone tone;
  final String title;
  final String detail;
}

/// Everything the dashboard shows about the projects that run in the chosen period.
class ProjectDashboardStats {
  ProjectDashboardStats._({
    required this.span,
    required this.projects,
    required this.slices,
    required this.progress,
    required this.overdue,
    required this.startedInSpan,
    required this.people,
    required this.departments,
    required this.dueSoon,
    required this.budget,
  });

  factory ProjectDashboardStats.compute(List<Project> all, DaySpan span, DateTime now) {
    final projects = [
      for (final p in all)
        if (projectInSpan(p, span)) p,
    ];
    final counts = <ProjectBucket, int>{};
    for (final p in projects) {
      counts[bucketOf(p)] = (counts[bucketOf(p)] ?? 0) + 1;
    }
    final measured = projects.where((p) => p.status != 'cancelled').toList(); // a cancelled project is not "progress"
    final progress = measured.isEmpty ? 0 : (measured.map((p) => p.progress).reduce((a, b) => a + b) / measured.length).round();
    final people = <String>{
      for (final p in projects) ...[if (p.managerId.isNotEmpty) p.managerId, ...p.memberIds.where((m) => m.isNotEmpty)],
    };
    final today = _day(now);
    return ProjectDashboardStats._(
      span: span,
      projects: projects,
      slices: [for (final b in ProjectBucket.values) StatusSlice(b, counts[b] ?? 0)],
      progress: progress,
      overdue: projects.where((p) => isOverdue(p, now)).toList(),
      startedInSpan: projects.where((p) => p.startDate != null && span.contains(p.startDate!)).length,
      people: people.length,
      departments: departmentStats(projects),
      budget: budgetTotals(projects),
      dueSoon: [
        for (final p in projects)
          if (!_finished(p) && p.endDate != null && !_day(p.endDate!).isBefore(today) && daysBetween(today, p.endDate!) <= 30) p,
      ]..sort((a, b) => a.endDate!.compareTo(b.endDate!)),
    );
  }

  final DaySpan span;
  final List<Project> projects;
  final List<StatusSlice> slices;

  /// 0..100 across the projects in the period (cancelled ones left out).
  final int progress;
  final List<Project> overdue;

  /// Projects whose start day falls inside the period.
  final int startedInSpan;
  final int people;
  final List<DeptStat> departments;

  /// Not finished, ending within the next 30 days.
  final List<Project> dueSoon;

  /// The money across these projects (only those whose amounts the viewer may see).
  final BudgetTotals budget;

  int get total => projects.length;
  int countOf(ProjectBucket b) => slices.firstWhere((s) => s.bucket == b).count;
  int get active => countOf(ProjectBucket.inProgress);
  int get completed => countOf(ProjectBucket.completed);
  int get onHold => countOf(ProjectBucket.onHold);
  int get notStarted => countOf(ProjectBucket.notStarted);
  int get cancelled => countOf(ProjectBucket.cancelled);

  int percentOfTotal(int n) => total == 0 ? 0 : (n * 100 / total).round();

  /// "What stands out", most important first. [blockedObjectives] is how many OKRs are blocked.
  List<Insight> insights({int blockedObjectives = 0, int limit = 5}) {
    if (total == 0) return const [];
    final out = <Insight>[];
    if (overdue.isNotEmpty) {
      out.add(Insight(InsightTone.bad, '${overdue.length} project${overdue.length == 1 ? ' is' : 's are'} overdue', _names(overdue)));
    }
    if (blockedObjectives > 0) {
      out.add(
        Insight(
          InsightTone.bad,
          '$blockedObjectives objective${blockedObjectives == 1 ? ' is' : 's are'} blocked',
          'Open Objectives & OKRs to unblock them.',
        ),
      );
    }
    // money first: a project past its approved budget is something someone has to act on
    final bo = budget.over;
    if (bo.isNotEmpty) {
      out.insert(0, Insight(InsightTone.bad, '${bo.length} project${bo.length == 1 ? ' is' : 's are'} over budget', _names(bo)));
    }
    final held = projects.where((p) => bucketOf(p) == ProjectBucket.onHold).toList();
    if (held.isNotEmpty) {
      out.add(Insight(InsightTone.warn, '${held.length} project${held.length == 1 ? ' is' : 's are'} on hold', _names(held)));
    }
    final bn = budget.near;
    if (bn.isNotEmpty) {
      out.add(Insight(InsightTone.warn, '${bn.length} near${bn.length == 1 ? 'ing its' : ' their'} budget', _names(bn)));
    }
    if (dueSoon.isNotEmpty) {
      out.add(Insight(InsightTone.info, '${dueSoon.length} ending within 30 days', _names(dueSoon)));
    }
    final top = topDepartments(departments, limit: 1);
    if (top.isNotEmpty && top.first.progress > 0) {
      out.add(Insight(InsightTone.good, '${top.first.name} is furthest ahead', '${top.first.progress}% of its tasks are done.'));
    }
    out.add(
      Insight(
        completed > 0 ? InsightTone.good : InsightTone.info,
        completed > 0 ? '$completed of $total completed' : 'None completed yet',
        'Average progress is $progress% across these projects.',
      ),
    );
    if (overdue.isEmpty && held.isEmpty && blockedObjectives == 0 && bo.isEmpty) {
      out.insert(0, const Insight(InsightTone.good, 'Nothing is behind', 'No project is overdue or on hold.'));
    }
    return out.take(limit).toList();
  }

  static String _names(List<Project> ps) {
    final n = ps.take(2).map((p) => p.name).join(', ');
    return ps.length > 2 ? '$n and ${ps.length - 2} more' : n;
  }
}
