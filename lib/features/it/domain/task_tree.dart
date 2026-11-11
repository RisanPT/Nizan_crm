import 'package:nizan_crm/features/it/data/it_task.dart';

// The plan as a tree (phase → task → sub-task): which tasks hang under one, and in what order a list of tasks reads.
// Pure — test/task_tree_test.dart.

/// Ids of everything below [rootId] (children, their children …), not [rootId] itself. The server deletes a task together
/// with all of these, so a screen that drops the task must drop them too.
Set<String> descendantIds(List<ITTask> tasks, String rootId) {
  final kids = <String, List<String>>{};
  for (final t in tasks) {
    final p = t.parentTaskId;
    if (p != null && p.isNotEmpty) (kids[p] ??= []).add(t.id);
  }
  final out = <String>{};
  final queue = <String>[rootId];
  while (queue.isNotEmpty) {
    for (final c in kids[queue.removeLast()] ?? const <String>[]) {
      if (c != rootId && out.add(c)) queue.add(c);
    }
  }
  return out;
}

/// [tasks] the way a plan reads: a phase, then its tasks, then each task's sub-tasks. Siblings go by their `order`
/// and, when that ties, stay in the order they came in. A task whose parent is not in [tasks] (filtered out, or in
/// another lane) starts a branch of its own, so nothing is dropped. [depth] says how far in each one sits (0 = starts a branch).
({List<ITTask> tasks, Map<String, int> depth}) inPlanOrder(List<ITTask> tasks) {
  final ids = {for (final t in tasks) t.id};
  final index = {for (var i = 0; i < tasks.length; i++) tasks[i].id: i};
  final kids = <String, List<ITTask>>{};
  final roots = <ITTask>[];
  for (final t in tasks) {
    final p = t.parentTaskId;
    if (p != null && p != t.id && ids.contains(p)) {
      (kids[p] ??= []).add(t);
    } else {
      roots.add(t);
    }
  }
  int byOrder(ITTask a, ITTask b) => a.order != b.order ? a.order.compareTo(b.order) : index[a.id]!.compareTo(index[b.id]!);
  roots.sort(byOrder);
  for (final l in kids.values) {
    l.sort(byOrder);
  }

  final out = <ITTask>[];
  final depth = <String, int>{};
  void walk(ITTask t, int d) {
    if (depth.containsKey(t.id)) return; // a loop of parents
    depth[t.id] = d;
    out.add(t);
    for (final c in kids[t.id] ?? const <ITTask>[]) {
      walk(c, d + 1);
    }
  }

  for (final r in roots) {
    walk(r, 0);
  }
  // tasks that only point at each other as parents are never reached from a root: still list them
  for (final t in tasks) {
    walk(t, 0);
  }
  return (tasks: out, depth: depth);
}

/// What to write so [taskId] moves one place [delta] (-1 up, +1 down) among its siblings: the `order` each task that has
/// to change should now have, keyed by id. Empty when it is already at that end (or is not there).
///
/// Siblings are the tasks under the same parent — a parent that is not in [tasks] counts as none, as in [inPlanOrder].
/// When their orders are all different the two simply trade; when some tie (a plan made before orders were kept apart),
/// they are all numbered afresh in the new order so the move sticks.
Map<String, int> orderAfterMove(List<ITTask> tasks, String taskId, int delta) {
  final me = tasks.where((t) => t.id == taskId).firstOrNull;
  if (me == null || delta == 0) return const {};
  final ids = {for (final t in tasks) t.id};
  final index = {for (var i = 0; i < tasks.length; i++) tasks[i].id: i};
  String parentOf(ITTask t) {
    final p = t.parentTaskId;
    return (p != null && p != t.id && ids.contains(p)) ? p : '';
  }

  final sibs = tasks.where((t) => parentOf(t) == parentOf(me)).toList()
    ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : index[a.id]!.compareTo(index[b.id]!));
  final i = sibs.indexWhere((t) => t.id == taskId);
  final j = i + delta;
  if (j < 0 || j >= sibs.length) return const {};

  if (sibs.map((t) => t.order).toSet().length == sibs.length) {
    return {sibs[i].id: sibs[j].order, sibs[j].id: sibs[i].order};
  }
  final moved = [...sibs];
  moved.insert(j, moved.removeAt(i));
  return {
    for (var k = 0; k < moved.length; k++)
      if (moved[k].order != k) moved[k].id: k,
  };
}
