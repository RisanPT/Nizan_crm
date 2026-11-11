import 'package:nizan_crm/features/it/domain/gantt_auto_scheduler.dart';

// Scheduling a plan that is still a draft (the Gantt Plan Wizard), where a task can have sub-tasks.
//
// A task with sub-tasks is a summary: it has no length of its own, it spans its sub-tasks. So only the tasks at the
// bottom ("leaves") are scheduled; a summary takes the earliest start and latest end of what is under it. What a summary
// waits for, its sub-tasks wait for; and something that waits for a summary waits for all of its sub-tasks.
//
// Pure — test/plan_drafts_test.dart.

class DraftTask {
  const DraftTask({
    required this.id,
    this.parentId,
    this.durationDays = 1,
    this.isMilestone = false,
    this.predecessorIds = const [],
    this.explicitStart,
    this.sameDay = false,
  });

  final String id;

  /// The task this is a sub-task of; null for a task straight under its phase.
  final String? parentId;
  final int durationDays;
  final bool isMilestone;
  final List<String> predecessorIds;

  /// A start day the planner fixed: the task does not begin before it. What it waits for can still push it later,
  /// so a fixed start never makes a task begin ahead of its predecessors. Only a task with no sub-tasks has one.
  final DateTime? explicitStart;

  /// A short job that starts and ends on the same day. It takes the one day in the plan (whatever waits for it starts the
  /// next day) but its own end is its start, so a time of day (10:00 – 13:00) means something.
  final bool sameDay;
}

/// How many days the dates [start] → [end] make as the plan counts them: the end is the day the task is handed over, so
/// 5 Nov → 8 Nov is 3 days. The same day, or an end before the start, is one day.
int daysBetweenPicked(DateTime start, DateTime end) {
  final d = DateTime.utc(end.year, end.month, end.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  return d < 1 ? 1 : d;
}

class DraftSchedule {
  const DraftSchedule({
    required this.dates,
    required this.critical,
    required this.float,
    required this.leafIds,
    required this.start,
    required this.end,
    required this.totalDays,
    this.hasCycle = false,
    this.cycleError,
  });

  /// When each task starts and ends (a task with sub-tasks: across them). The end is the day after the last working
  /// day — a 3-day task from the 5th ends on the 8th. A same-day task ends on its start day.
  final Map<String, ({DateTime start, DateTime end})> dates;

  /// Tasks on the critical path (a task with sub-tasks is on it when any of them is).
  final Set<String> critical;

  /// How many days each task can slip without moving the end of the plan (a task with sub-tasks: its tightest one).
  final Map<String, int> float;

  /// The tasks that are scheduled in their own right: those with no sub-tasks.
  final Set<String> leafIds;
  final DateTime start;
  final DateTime end;
  final int totalDays;
  final bool hasCycle;
  final String? cycleError;

  int get criticalLeafCount => critical.where(leafIds.contains).length;
}

DraftSchedule scheduleDraftTasks({required DateTime baseStart, required List<DraftTask> tasks}) {
  final ids = {for (final t in tasks) t.id};
  final kids = <String, List<String>>{};
  for (final t in tasks) {
    final p = t.parentId;
    if (p != null && p != t.id && ids.contains(p)) (kids[p] ??= []).add(t.id);
  }
  final byId = {for (final t in tasks) t.id: t};
  bool isGroup(String id) => (kids[id] ?? const []).isNotEmpty;

  final leavesMemo = <String, List<String>>{};
  List<String> leavesOf(String id, [Set<String>? seen]) {
    final cached = leavesMemo[id];
    if (cached != null) return cached;
    final guard = seen ?? <String>{};
    if (!guard.add(id)) return const [];
    final out = isGroup(id) ? [for (final c in kids[id]!) ...leavesOf(c, guard)] : [id];
    return leavesMemo[id] = out;
  }

  List<String> ancestorsOf(String id) {
    final out = <String>[];
    var p = byId[id]?.parentId;
    while (p != null && ids.contains(p) && !out.contains(p) && p != id) {
      out.add(p);
      p = byId[p]?.parentId;
    }
    return out;
  }

  final leaves = [
    for (final t in tasks)
      if (!isGroup(t.id)) t,
  ];
  final planTasks = <GanttPlanTask>[];
  for (final leaf in leaves) {
    final waitsFor = <String>{};
    for (final source in [leaf.id, ...ancestorsOf(leaf.id)]) {
      for (final pid in byId[source]!.predecessorIds) {
        if (ids.contains(pid)) waitsFor.addAll(leavesOf(pid));
      }
    }
    waitsFor.remove(leaf.id);
    final fixed = leaf.explicitStart;
    planTasks.add(
      GanttPlanTask(
        id: leaf.id,
        title: leaf.id,
        durationDays: leaf.isMilestone ? 0 : (leaf.durationDays < 1 ? 1 : leaf.durationDays),
        isMilestone: leaf.isMilestone,
        predecessorIds: waitsFor.toList(),
        explicitStartDate: fixed == null ? null : DateTime(fixed.year, fixed.month, fixed.day),
      ),
    );
  }

  final result = GanttAutoScheduler.schedule(baseStartDate: baseStart, inputTasks: planTasks);

  final dates = <String, ({DateTime start, DateTime end})>{};
  final critical = <String>{};
  final float = <String, int>{};
  final sameDay = {
    for (final l in leaves)
      if (l.sameDay && !l.isMilestone) l.id,
  };
  for (final st in result.scheduledTasks) {
    if (st.startDate == null || st.endDate == null) continue;
    dates[st.id] = (start: st.startDate!, end: sameDay.contains(st.id) ? st.startDate! : st.endDate!);
    float[st.id] = st.totalFloatDays;
    if (st.isCriticalPath) critical.add(st.id);
  }
  for (final t in tasks) {
    if (!isGroup(t.id)) continue;
    DateTime? s, e;
    int? slack;
    var isCritical = false;
    for (final l in leavesOf(t.id)) {
      final d = dates[l];
      if (d == null) continue;
      if (s == null || d.start.isBefore(s)) s = d.start;
      if (e == null || d.end.isAfter(e)) e = d.end;
      isCritical = isCritical || critical.contains(l);
      final f = float[l] ?? 0;
      if (slack == null || f < slack) slack = f;
    }
    if (s != null && e != null) dates[t.id] = (start: s, end: e);
    if (slack != null) float[t.id] = slack;
    if (isCritical) critical.add(t.id);
  }

  return DraftSchedule(
    dates: dates,
    critical: result.hasCycle ? <String>{} : critical,
    float: float,
    leafIds: {for (final l in leaves) l.id},
    start: result.projectStartDate,
    end: result.projectEndDate,
    totalDays: result.totalDurationDays,
    hasCycle: result.hasCycle,
    cycleError: result.cycleError,
  );
}

/// Would making [predecessorId] a predecessor of [taskId] make the plan loop back on itself? Judged on the real
/// schedule, so a loop that only shows once a task's sub-tasks are counted is found too.
bool draftWouldCycle(List<DraftTask> tasks, String taskId, String predecessorId) {
  if (taskId == predecessorId) return true;
  final changed = [
    for (final t in tasks)
      if (t.id == taskId)
        DraftTask(
          id: t.id,
          parentId: t.parentId,
          durationDays: t.durationDays,
          isMilestone: t.isMilestone,
          explicitStart: t.explicitStart,
          sameDay: t.sameDay,
          predecessorIds: [...t.predecessorIds.where((p) => p != predecessorId), predecessorId],
        )
      else
        t,
  ];
  return scheduleDraftTasks(baseStart: DateTime(2000), tasks: changed).hasCycle;
}

/// The tasks [taskId] could be made to wait for: not itself, not the task it sits under or anything under it (a task
/// does not wait for its own summary), not one it already waits for, and none that would loop the plan.
List<String> eligiblePredecessorIds(List<DraftTask> tasks, String taskId) {
  final self = tasks.where((t) => t.id == taskId).firstOrNull;
  if (self == null) return const [];
  final under = <String>{};
  void collect(String id) {
    for (final t in tasks) {
      if (t.parentId == id && under.add(t.id)) collect(t.id);
    }
  }

  collect(taskId);
  final above = <String>{};
  var p = self.parentId;
  while (p != null && above.add(p)) {
    p = tasks.where((t) => t.id == p).firstOrNull?.parentId;
  }
  return [
    for (final t in tasks)
      if (t.id != taskId &&
          !under.contains(t.id) &&
          !above.contains(t.id) &&
          !self.predecessorIds.contains(t.id) &&
          !draftWouldCycle(tasks, taskId, t.id))
        t.id,
  ];
}
