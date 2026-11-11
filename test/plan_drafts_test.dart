import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/plan_drafts.dart';

// Scheduling a draft plan where a task can have sub-tasks: a task with sub-tasks spans them; they inherit what it
// waits for; what waits for it waits for all of them.

final _start = DateTime(2026, 11, 2); // a Monday
DateTime _day(int n) => DateTime(2026, 11, 2 + n);

DraftTask _t(String id, {int days = 1, String? parent, List<String> after = const [], bool milestone = false}) =>
    DraftTask(id: id, parentId: parent, durationDays: days, predecessorIds: after, isMilestone: milestone);

({DateTime start, DateTime end}) _d(DraftSchedule s, String id) => s.dates[id]!;

void main() {
  DraftSchedule run(List<DraftTask> tasks) => scheduleDraftTasks(baseStart: _start, tasks: tasks);

  group('a plan with no sub-tasks', () {
    test('runs one after another along its predecessors, and on its own from the first day', () {
      final s = run([
        _t('a', days: 3),
        _t('b', days: 2, after: ['a']),
        _t('c', days: 4),
      ]);
      expect(_d(s, 'a'), (start: _day(0), end: _day(3)));
      expect(_d(s, 'b'), (start: _day(3), end: _day(5)));
      expect(_d(s, 'c'), (start: _day(0), end: _day(4)));
      expect(s.totalDays, 5);
      expect(s.end, _day(5));
      expect(s.hasCycle, isFalse);
    });

    test('a milestone takes no time; a length under one day counts as one', () {
      final s = run([
        _t('a', days: 0),
        _t('m', milestone: true, days: 9, after: ['a']),
      ]);
      expect(_d(s, 'a'), (start: _day(0), end: _day(1)));
      expect(_d(s, 'm'), (start: _day(1), end: _day(1)));
    });

    test('nothing to schedule', () {
      final s = run(const []);
      expect(s.dates, isEmpty);
      expect(s.totalDays, 0);
      expect(s.hasCycle, isFalse);
    });
  });

  group('sub-tasks', () {
    test('a task with sub-tasks has no length of its own: it spans them', () {
      final s = run([
        _t('g', days: 30), // its own 30 days mean nothing once it has sub-tasks
        _t('a', parent: 'g', days: 2),
        _t('b', parent: 'g', days: 3, after: ['a']),
      ]);
      expect(_d(s, 'g'), (start: _day(0), end: _day(5)));
      expect(s.totalDays, 5);
      expect(s.leafIds, {'a', 'b'});
    });

    test('sub-tasks start at the earliest, and a summary ends with the last of them', () {
      final s = run([_t('g'), _t('a', parent: 'g', days: 2), _t('b', parent: 'g', days: 5)]);
      expect(_d(s, 'a').start, _day(0));
      expect(_d(s, 'b').start, _day(0));
      expect(_d(s, 'g'), (start: _day(0), end: _day(5)));
    });

    test('sub-tasks wait for whatever their summary waits for', () {
      final s = run([
        _t('p', days: 3),
        _t('g', after: ['p']),
        _t('a', parent: 'g', days: 2),
        _t('b', parent: 'g', days: 1, after: ['a']),
      ]);
      expect(_d(s, 'a').start, _day(3));
      expect(_d(s, 'b').start, _day(5));
      expect(_d(s, 'g'), (start: _day(3), end: _day(6)));
    });

    test('something that waits for a summary waits for all of its sub-tasks', () {
      final s = run([
        _t('g'),
        _t('a', parent: 'g', days: 2),
        _t('b', parent: 'g', days: 5),
        _t('x', days: 1, after: ['g']),
      ]);
      expect(_d(s, 'x').start, _day(5)); // after the slower sub-task, not the quicker one
    });

    test('sub-tasks of sub-tasks work the same', () {
      final s = run([
        _t('g'),
        _t('h', parent: 'g'),
        _t('a', parent: 'h', days: 2),
        _t('b', parent: 'h', days: 2, after: ['a']),
        _t('c', parent: 'g', days: 1, after: ['h']),
      ]);
      expect(_d(s, 'h'), (start: _day(0), end: _day(4)));
      expect(_d(s, 'c').start, _day(4));
      expect(_d(s, 'g'), (start: _day(0), end: _day(5)));
    });

    test('a summary is on the critical path when any of its sub-tasks is; the count is of tasks that are scheduled themselves', () {
      final s = run([_t('g'), _t('a', parent: 'g', days: 5), _t('b', parent: 'g', days: 1), _t('z', days: 2)]);
      expect(s.critical, containsAll(['g', 'a']));
      expect(s.critical, isNot(contains('b')));
      expect(s.critical, isNot(contains('z')));
      expect(s.criticalLeafCount, 1);
    });

    test('a parent that is not in the plan counts for nothing: the task stands alone', () {
      final s = run([_t('a', parent: 'gone', days: 2)]);
      expect(_d(s, 'a'), (start: _day(0), end: _day(2)));
      expect(s.leafIds, {'a'});
    });
  });

  group('loops', () {
    test('a plain loop is found', () {
      final s = run([
        _t('a', after: ['b']),
        _t('b', after: ['a']),
      ]);
      expect(s.hasCycle, isTrue);
      expect(s.cycleError, isNotNull);
      expect(s.critical, isEmpty);
    });

    test('a loop that only shows once the sub-tasks are counted is found too', () {
      // c is under g and waits for x; x waits for g — and g is c.
      final tasks = [
        _t('g'),
        _t('c', parent: 'g'),
        _t('x', after: ['g']),
      ];
      expect(run(tasks).hasCycle, isFalse);
      expect(draftWouldCycle(tasks, 'c', 'x'), isTrue);
    });

    test('a task cannot wait for itself', () {
      expect(draftWouldCycle([_t('a')], 'a', 'a'), isTrue);
    });
  });

  group('who a task can be made to wait for', () {
    final tasks = [
      _t('g'),
      _t('a', parent: 'g'),
      _t('b', parent: 'g', after: ['a']),
      _t('x'),
      _t('y', after: ['x']),
    ];

    test('not itself, not its own summary, not what is under it, not what it already waits for', () {
      expect(eligiblePredecessorIds(tasks, 'a'), unorderedEquals(['x', 'y']));
      expect(eligiblePredecessorIds(tasks, 'g'), unorderedEquals(['x', 'y']));
      expect(eligiblePredecessorIds(tasks, 'b'), unorderedEquals(['x', 'y']));
    });

    test('not what would send the plan round in a circle', () {
      // y already waits for x, so x cannot wait for y
      expect(eligiblePredecessorIds(tasks, 'x'), isNot(contains('y')));
      expect(eligiblePredecessorIds(tasks, 'x'), containsAll(['g', 'a', 'b']));
    });

    test('an unknown task has no candidates', () {
      expect(eligiblePredecessorIds(tasks, 'nope'), isEmpty);
    });
  });

  // A planner can fix when a task starts, and end a short job on the day it starts.
  group('a start the planner fixed', () {
    DraftTask fixed(
      String id,
      DateTime start, {
      int days = 1,
      List<String> after = const [],
      bool sameDay = false,
      bool milestone = false,
      String? parent,
    }) => DraftTask(
      id: id,
      parentId: parent,
      durationDays: days,
      predecessorIds: after,
      explicitStart: start,
      sameDay: sameDay,
      isMilestone: milestone,
    );

    test('starts on that day, not on the first day of the plan', () {
      final s = run([fixed('a', _day(5), days: 3)]);
      expect(_d(s, 'a'), (start: _day(5), end: _day(8)));
      expect(s.end, _day(8));
      expect(s.totalDays, 8);
    });

    test('a task that waits for it starts when it ends', () {
      final s = run([
        fixed('a', _day(5), days: 3),
        _t('b', days: 2, after: ['a']),
      ]);
      expect(_d(s, 'b'), (start: _day(8), end: _day(10)));
    });

    test('"not before": what it waits for can push it later, never earlier', () {
      final s = run([
        _t('a', days: 6),
        fixed('b', _day(2), days: 2, after: ['a']),
      ]);
      expect(_d(s, 'b'), (start: _day(6), end: _day(8))); // a is not done until day 6
    });

    test('a fixed day after what it waits for is kept', () {
      final s = run([
        _t('a', days: 2),
        fixed('b', _day(4), days: 2, after: ['a']),
      ]);
      expect(_d(s, 'b'), (start: _day(4), end: _day(6)));
    });

    test('a start before the plan began is kept as it is', () {
      final s = run([fixed('a', _day(-3), days: 2)]);
      expect(_d(s, 'a').start, _day(-3));
    });

    test('the time of day on the date does not matter — it is the day that counts', () {
      final s = run([DraftTask(id: 'a', durationDays: 2, explicitStart: DateTime(2026, 11, 9, 17, 45))]);
      expect(_d(s, 'a'), (start: _day(7), end: _day(9)));
    });

    test('a task with sub-tasks takes its dates from them, not from a start fixed on it', () {
      final s = run([
        fixed('g', _day(9)),
        _t('x', days: 2, parent: 'g'),
        _t('y', days: 3, parent: 'g', after: ['x']),
      ]);
      expect(_d(s, 'g'), (start: _day(0), end: _day(5)));
    });

    test('a sub-task can have a fixed start, and its summary follows', () {
      final s = run([_t('g'), fixed('x', _day(4), days: 2, parent: 'g'), _t('y', days: 1, parent: 'g')]);
      expect(_d(s, 'x'), (start: _day(4), end: _day(6)));
      expect(_d(s, 'g'), (start: _day(0), end: _day(6)));
    });

    test('it does not break the check for a loop', () {
      final tasks = [
        fixed('a', _day(3)),
        fixed('b', _day(1), after: ['a']),
      ];
      expect(draftWouldCycle(tasks, 'a', 'b'), isTrue);
      expect(eligiblePredecessorIds(tasks, 'a'), isEmpty);
    });
  });

  group('a job that starts and ends on the same day', () {
    test('ends where it starts', () {
      final s = run([DraftTask(id: 'a', explicitStart: _day(3), sameDay: true)]);
      expect(_d(s, 'a'), (start: _day(3), end: _day(3)));
    });

    test('still takes the day in the plan: what waits for it starts the next day', () {
      final s = run([
        DraftTask(id: 'a', explicitStart: _day(3), sameDay: true),
        _t('b', days: 2, after: ['a']),
      ]);
      expect(_d(s, 'b'), (start: _day(4), end: _day(6)));
      expect(s.end, _day(6));
    });

    test('a summary over it ends on that day too', () {
      final s = run([_t('g'), DraftTask(id: 'x', parentId: 'g', explicitStart: _day(2), sameDay: true)]);
      expect(_d(s, 'g'), (start: _day(2), end: _day(2)));
    });

    test('a milestone is on its day anyway', () {
      final s = run([DraftTask(id: 'm', isMilestone: true, sameDay: true, explicitStart: _day(2))]);
      expect(_d(s, 'm'), (start: _day(2), end: _day(2)));
    });

    test('without the flag a one-day job ends the next day, as before', () {
      expect(_d(run([DraftTask(id: 'a', explicitStart: _day(3))]), 'a'), (start: _day(3), end: _day(4)));
    });
  });

  group('the days two dates make', () {
    test('the end is the day it is handed over: 5th to the 8th is three days', () {
      expect(daysBetweenPicked(DateTime(2026, 11, 5), DateTime(2026, 11, 8)), 3);
    });

    test('the same day, or an end before the start, is one day', () {
      expect(daysBetweenPicked(DateTime(2026, 11, 5), DateTime(2026, 11, 5)), 1);
      expect(daysBetweenPicked(DateTime(2026, 11, 5), DateTime(2026, 11, 2)), 1);
    });

    test('time of day does not change the count, and neither does a clock change', () {
      expect(daysBetweenPicked(DateTime(2026, 11, 5, 23, 0), DateTime(2026, 11, 8, 1, 0)), 3);
      expect(daysBetweenPicked(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    });

    test('across a month end', () {
      expect(daysBetweenPicked(DateTime(2026, 11, 28), DateTime(2026, 12, 3)), 5);
    });
  });
}
