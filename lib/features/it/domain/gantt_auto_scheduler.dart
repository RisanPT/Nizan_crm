import 'dart:math' as math;

/// Represents a task or milestone in the functional Gantt planning engine.
class GanttPlanTask {
  final String id;
  final String title;
  final String phaseName;
  final String departmentName;
  final String? assigneeId;
  final String? assigneeName;
  final int durationDays;
  final double estimatedHours;
  final List<String> predecessorIds;
  final bool isMilestone;
  final String priority;
  final DateTime? explicitStartDate;

  // Computed by GanttAutoScheduler
  DateTime? startDate;
  DateTime? endDate;
  int totalFloatDays;
  bool isCriticalPath;

  GanttPlanTask({
    required this.id,
    required this.title,
    this.phaseName = 'Execution',
    this.departmentName = 'General',
    this.assigneeId,
    this.assigneeName,
    this.durationDays = 1,
    this.estimatedHours = 8,
    this.predecessorIds = const [],
    this.isMilestone = false,
    this.priority = 'p2',
    this.explicitStartDate,
    this.startDate,
    this.endDate,
    this.totalFloatDays = 0,
    this.isCriticalPath = false,
  });

  GanttPlanTask copyWith({
    String? id,
    String? title,
    String? phaseName,
    String? departmentName,
    String? assigneeId,
    String? assigneeName,
    int? durationDays,
    double? estimatedHours,
    List<String>? predecessorIds,
    bool? isMilestone,
    String? priority,
    DateTime? explicitStartDate,
    DateTime? startDate,
    DateTime? endDate,
    int? totalFloatDays,
    bool? isCriticalPath,
  }) {
    return GanttPlanTask(
      id: id ?? this.id,
      title: title ?? this.title,
      phaseName: phaseName ?? this.phaseName,
      departmentName: departmentName ?? this.departmentName,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      durationDays: durationDays ?? this.durationDays,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      predecessorIds: predecessorIds ?? this.predecessorIds,
      isMilestone: isMilestone ?? this.isMilestone,
      priority: priority ?? this.priority,
      explicitStartDate: explicitStartDate ?? this.explicitStartDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalFloatDays: totalFloatDays ?? this.totalFloatDays,
      isCriticalPath: isCriticalPath ?? this.isCriticalPath,
    );
  }
}

/// Result of auto-scheduling a functional plan.
class GanttScheduleResult {
  final List<GanttPlanTask> scheduledTasks;
  final DateTime projectStartDate;
  final DateTime projectEndDate;
  final int totalDurationDays;
  final List<String> criticalPathTaskIds;
  final bool hasCycle;
  final String? cycleError;

  const GanttScheduleResult({
    required this.scheduledTasks,
    required this.projectStartDate,
    required this.projectEndDate,
    required this.totalDurationDays,
    required this.criticalPathTaskIds,
    this.hasCycle = false,
    this.cycleError,
  });
}

/// Critical Path Method (CPM) and Auto-Scheduling Engine for Gantt Charts.
class GanttAutoScheduler {
  /// Auto-schedules tasks using Finish-to-Start (FS) precedence and CPM.
  static GanttScheduleResult schedule({
    required DateTime baseStartDate,
    required List<GanttPlanTask> inputTasks,
  }) {
    if (inputTasks.isEmpty) {
      final now = DateTime(baseStartDate.year, baseStartDate.month, baseStartDate.day);
      return GanttScheduleResult(
        scheduledTasks: const [],
        projectStartDate: now,
        projectEndDate: now,
        totalDurationDays: 0,
        criticalPathTaskIds: const [],
      );
    }

    final normalizedBase = DateTime(baseStartDate.year, baseStartDate.month, baseStartDate.day);
    final taskMap = <String, GanttPlanTask>{
      for (final t in inputTasks) t.id: t.copyWith(),
    };

    // 1. Cycle Detection via Kahn's algorithm
    final inDegree = <String, int>{for (final id in taskMap.keys) id: 0};
    final adjList = <String, List<String>>{for (final id in taskMap.keys) id: []};

    for (final task in taskMap.values) {
      for (final pid in task.predecessorIds) {
        if (taskMap.containsKey(pid)) {
          adjList[pid]!.add(task.id);
          inDegree[task.id] = (inDegree[task.id] ?? 0) + 1;
        }
      }
    }

    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) queue.add(entry.key);
    }

    final topologicalOrder = <String>[];
    while (queue.isNotEmpty) {
      final u = queue.removeAt(0);
      topologicalOrder.add(u);
      for (final v in adjList[u] ?? const <String>[]) {
        inDegree[v] = inDegree[v]! - 1;
        if (inDegree[v] == 0) queue.add(v);
      }
    }

    if (topologicalOrder.length < taskMap.length) {
      // Dependency cycle detected! Fallback to linear schedule and report cycle.
      var curr = normalizedBase;
      final fallbackList = <GanttPlanTask>[];
      for (final t in inputTasks) {
        final dur = t.isMilestone ? 0 : math.max(1, t.durationDays);
        final start = curr;
        final end = start.add(Duration(days: dur));
        curr = end;
        fallbackList.add(t.copyWith(
          startDate: start,
          endDate: end,
          isCriticalPath: false,
          totalFloatDays: 0,
        ));
      }
      return GanttScheduleResult(
        scheduledTasks: fallbackList,
        projectStartDate: normalizedBase,
        projectEndDate: curr,
        totalDurationDays: curr.difference(normalizedBase).inDays,
        criticalPathTaskIds: const [],
        hasCycle: true,
        cycleError: 'Circular dependency detected. Please resolve loops between tasks.',
      );
    }

    // 2. Forward Pass: Calculate Earliest Start (ES) and Earliest Finish (EF)
    DateTime maxProjectFinish = normalizedBase;

    for (final taskId in topologicalOrder) {
      final task = taskMap[taskId]!;
      DateTime earliestStart = task.explicitStartDate ?? normalizedBase;

      for (final pid in task.predecessorIds) {
        final pred = taskMap[pid];
        if (pred != null && pred.endDate != null) {
          if (pred.endDate!.isAfter(earliestStart)) {
            earliestStart = pred.endDate!;
          }
        }
      }

      final dur = task.isMilestone ? 0 : math.max(1, task.durationDays);
      final finish = earliestStart.add(Duration(days: dur));

      task.startDate = earliestStart;
      task.endDate = finish;

      if (finish.isAfter(maxProjectFinish)) {
        maxProjectFinish = finish;
      }
    }

    // 3. Backward Pass: Calculate Latest Finish (LF), Latest Start (LS), and Slack
    final reverseOrder = topologicalOrder.reversed.toList();
    final latestFinishMap = <String, DateTime>{
      for (final id in topologicalOrder) id: maxProjectFinish,
    };

    final criticalTaskIds = <String>[];

    for (final taskId in reverseOrder) {
      final task = taskMap[taskId]!;
      final dur = task.isMilestone ? 0 : math.max(1, task.durationDays);

      DateTime lf = latestFinishMap[taskId] ?? maxProjectFinish;
      DateTime ls = lf.subtract(Duration(days: dur));

      for (final pid in task.predecessorIds) {
        final currentPredLf = latestFinishMap[pid] ?? maxProjectFinish;
        if (ls.isBefore(currentPredLf)) {
          latestFinishMap[pid] = ls;
        }
      }

      final es = task.startDate!;
      final slackDays = ls.difference(es).inDays;
      task.totalFloatDays = math.max(0, slackDays);
      task.isCriticalPath = task.totalFloatDays == 0;

      if (task.isCriticalPath) {
        criticalTaskIds.add(task.id);
      }
    }

    // Collect ordered list according to original user order
    final scheduled = inputTasks.map((t) => taskMap[t.id]!).toList();
    final totalDuration = maxProjectFinish.difference(normalizedBase).inDays;

    return GanttScheduleResult(
      scheduledTasks: scheduled,
      projectStartDate: normalizedBase,
      projectEndDate: maxProjectFinish,
      totalDurationDays: totalDuration,
      criticalPathTaskIds: criticalTaskIds,
      hasCycle: false,
    );
  }

  /// Cascades a date shift on [changedTaskId] to all downstream successor tasks
  /// that depend on it directly or indirectly (Finish-to-Start dependency).
  /// Returns a map of all task IDs whose dates were updated.
  static Map<String, ({DateTime start, DateTime due})> rippleShift({
    required List<dynamic> allTasks, // accepts ITTaskModel or GanttPlanTask
    required String changedTaskId,
    required DateTime newStartDate,
    required DateTime newDueDate,
  }) {
    final taskMap = <String, ({String id, DateTime? start, DateTime? due, List<String> preds})>{};

    for (final item in allTasks) {
      if (item is GanttPlanTask) {
        taskMap[item.id] = (
          id: item.id,
          start: item.startDate,
          due: item.endDate,
          preds: item.predecessorIds,
        );
      } else {
        // ITTaskModel
        taskMap[item.id] = (
          id: item.id,
          start: item.startDate,
          due: item.dueDate,
          preds: item.predecessorIds,
        );
      }
    }

    if (!taskMap.containsKey(changedTaskId)) return const {};

    final shiftedDates = <String, ({DateTime start, DateTime due})>{
      changedTaskId: (start: newStartDate, due: newDueDate),
    };

    final queue = <String>[changedTaskId];

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final currentDue = shiftedDates[currentId]?.due ?? taskMap[currentId]?.due;
      if (currentDue == null) continue;

      for (final candidate in taskMap.values) {
        if (candidate.preds.contains(currentId)) {
          final candStart = shiftedDates[candidate.id]?.start ?? candidate.start;
          final candDue = shiftedDates[candidate.id]?.due ?? candidate.due;

          if (candStart == null || candDue == null) continue;

          // If predecessor finish is after candidate start, push candidate forward
          if (currentDue.isAfter(candStart)) {
            final duration = candDue.difference(candStart);
            final updatedStart = currentDue;
            final updatedDue = updatedStart.add(duration);

            shiftedDates[candidate.id] = (start: updatedStart, due: updatedDue);
            if (!queue.contains(candidate.id)) {
              queue.add(candidate.id);
            }
          }
        }
      }
    }

    return shiftedDates;
  }
}
