import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/gantt_auto_scheduler.dart';

void main() {
  group('GanttAutoScheduler Tests', () {
    final baseDate = DateTime(2026, 11, 10);

    test('Single task scheduling', () {
      final task = GanttPlanTask(id: 't1', title: 'Setup Database', durationDays: 4);
      final result = GanttAutoScheduler.schedule(baseStartDate: baseDate, inputTasks: [task]);

      expect(result.hasCycle, isFalse);
      expect(result.totalDurationDays, 4);
      expect(result.scheduledTasks.first.startDate, baseDate);
      expect(result.scheduledTasks.first.endDate, DateTime(2026, 11, 14));
      expect(result.scheduledTasks.first.isCriticalPath, isTrue);
    });

    test('Sequential dependency chain (Finish-to-Start): A -> B -> C', () {
      final taskA = GanttPlanTask(id: 'a', title: 'Task A', durationDays: 3);
      final taskB = GanttPlanTask(id: 'b', title: 'Task B', durationDays: 2, predecessorIds: ['a']);
      final taskC = GanttPlanTask(id: 'c', title: 'Task C', durationDays: 5, predecessorIds: ['b']);

      final result = GanttAutoScheduler.schedule(
        baseStartDate: baseDate,
        inputTasks: [taskA, taskB, taskC],
      );

      expect(result.hasCycle, isFalse);
      expect(result.totalDurationDays, 10); // 3 + 2 + 5

      final scheduledA = result.scheduledTasks.firstWhere((t) => t.id == 'a');
      final scheduledB = result.scheduledTasks.firstWhere((t) => t.id == 'b');
      final scheduledC = result.scheduledTasks.firstWhere((t) => t.id == 'c');

      expect(scheduledA.startDate, DateTime(2026, 11, 10));
      expect(scheduledA.endDate, DateTime(2026, 11, 13));

      expect(scheduledB.startDate, DateTime(2026, 11, 13));
      expect(scheduledB.endDate, DateTime(2026, 11, 15));

      expect(scheduledC.startDate, DateTime(2026, 11, 15));
      expect(scheduledC.endDate, DateTime(2026, 11, 20));

      expect(result.criticalPathTaskIds.toSet(), {'a', 'b', 'c'});
    });

    test('Parallel paths and Critical Path identification', () {
      // Path 1: A (3d) -> B (4d) -> Total 7d
      // Path 2: A (3d) -> C (2d) -> Total 5d
      // Join: D (2d) depends on B and C
      // Critical path must be A -> B -> D (9 days)
      final taskA = GanttPlanTask(id: 'a', title: 'Task A', durationDays: 3);
      final taskB = GanttPlanTask(id: 'b', title: 'Task B', durationDays: 4, predecessorIds: ['a']);
      final taskC = GanttPlanTask(id: 'c', title: 'Task C', durationDays: 2, predecessorIds: ['a']);
      final taskD = GanttPlanTask(id: 'd', title: 'Task D', durationDays: 2, predecessorIds: ['b', 'c']);

      final result = GanttAutoScheduler.schedule(
        baseStartDate: baseDate,
        inputTasks: [taskA, taskB, taskC, taskD],
      );

      expect(result.hasCycle, isFalse);
      expect(result.totalDurationDays, 9); // 3 + 4 + 2

      final scheduledB = result.scheduledTasks.firstWhere((t) => t.id == 'b');
      final scheduledC = result.scheduledTasks.firstWhere((t) => t.id == 'c');
      final scheduledD = result.scheduledTasks.firstWhere((t) => t.id == 'd');

      // Task D must wait for the longest predecessor (B finishes Nov 17, C finishes Nov 15)
      expect(scheduledB.endDate, DateTime(2026, 11, 17));
      expect(scheduledC.endDate, DateTime(2026, 11, 15));
      expect(scheduledD.startDate, DateTime(2026, 11, 17));
      expect(scheduledD.endDate, DateTime(2026, 11, 19));

      // Task C has 2 days of float
      expect(scheduledC.totalFloatDays, 2);
      expect(scheduledC.isCriticalPath, isFalse);

      expect(result.criticalPathTaskIds.contains('a'), isTrue);
      expect(result.criticalPathTaskIds.contains('b'), isTrue);
      expect(result.criticalPathTaskIds.contains('d'), isTrue);
    });

    test('Circular dependency is detected and reported cleanly', () {
      final taskA = GanttPlanTask(id: 'a', title: 'Task A', durationDays: 2, predecessorIds: ['b']);
      final taskB = GanttPlanTask(id: 'b', title: 'Task B', durationDays: 3, predecessorIds: ['a']);

      final result = GanttAutoScheduler.schedule(
        baseStartDate: baseDate,
        inputTasks: [taskA, taskB],
      );

      expect(result.hasCycle, isTrue);
      expect(result.cycleError, contains('Circular dependency detected'));
    });

    test('Milestone (zero duration) checkpoint scheduling', () {
      final taskA = GanttPlanTask(id: 'a', title: 'Develop Feature', durationDays: 5);
      final milestone = GanttPlanTask(id: 'm1', title: 'Release Ready', isMilestone: true, predecessorIds: ['a']);

      final result = GanttAutoScheduler.schedule(
        baseStartDate: baseDate,
        inputTasks: [taskA, milestone],
      );

      final scheduledM = result.scheduledTasks.firstWhere((t) => t.id == 'm1');
      expect(scheduledM.startDate, DateTime(2026, 11, 15));
      expect(scheduledM.endDate, DateTime(2026, 11, 15));
    });

    test('rippleShift cascades date delays forward through dependent successor chain', () {
      final taskA = GanttPlanTask(
        id: 'a',
        title: 'Task A',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 13),
      );
      final taskB = GanttPlanTask(
        id: 'b',
        title: 'Task B',
        startDate: DateTime(2026, 11, 13),
        endDate: DateTime(2026, 11, 15),
        predecessorIds: ['a'],
      );
      final taskC = GanttPlanTask(
        id: 'c',
        title: 'Task C',
        startDate: DateTime(2026, 11, 15),
        endDate: DateTime(2026, 11, 20),
        predecessorIds: ['b'],
      );

      // Now Task A is delayed: finishes on Nov 17 instead of Nov 13
      final updates = GanttAutoScheduler.rippleShift(
        allTasks: [taskA, taskB, taskC],
        changedTaskId: 'a',
        newStartDate: DateTime(2026, 11, 12),
        newDueDate: DateTime(2026, 11, 17),
      );

      // Task A updated
      expect(updates['a']?.start, DateTime(2026, 11, 12));
      expect(updates['a']?.due, DateTime(2026, 11, 17));

      // Task B pushed: starts Nov 17, due Nov 19 (duration 2 days)
      expect(updates['b']?.start, DateTime(2026, 11, 17));
      expect(updates['b']?.due, DateTime(2026, 11, 19));

      // Task C pushed: starts Nov 19, due Nov 24 (duration 5 days)
      expect(updates['c']?.start, DateTime(2026, 11, 19));
      expect(updates['c']?.due, DateTime(2026, 11, 24));
    });
  });
}
