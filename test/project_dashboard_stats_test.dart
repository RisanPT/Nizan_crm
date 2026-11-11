import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/project_dashboard_stats.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_dashboard_cards.dart' show timelineColumns;

// Company Projects → Dashboard: what it shows is worked out here, from the projects and tasks the server sends.
// Dates are fixed (Wed 11 Nov 2026) so nothing depends on the day the tests run.

final _now = DateTime(2026, 11, 11, 10, 30);
String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Project _p(
  String id, {
  String status = 'active',
  String dept = 'IT',
  DateTime? start,
  DateTime? end,
  int progress = 0,
  int tasks = 0,
  int done = 0,
  List<Map<String, dynamic>> depts = const [],
  List<Map<String, dynamic>> deptProgress = const [],
  String manager = 'm1',
  List<String> members = const [],
  Map<String, dynamic>? cost,
}) => Project.fromJson({
  '_id': id,
  'name': 'Project $id',
  'status': status,
  'targetDepartment': dept,
  'managerId': {'_id': manager, 'name': 'M'},
  'members': [
    for (final m in members) {'_id': m, 'name': m},
  ],
  if (start != null) 'startDate': _iso(start),
  if (end != null) 'endDate': _iso(end),
  'progress': progress,
  'totalTasks': tasks,
  'completedTasks': done,
  'departments': depts.isEmpty
      ? [
          {'name': dept, 'role': 'owner', 'status': 'accepted'},
        ]
      : depts,
  'departmentProgress': deptProgress,
  if (cost != null) 'cost': cost,
  if (cost != null) 'costStatus': 'approved',
});

ITTask _t(
  String id, {
  String project = 'p1',
  String status = 'todo',
  DateTime? due,
  DateTime? created,
  DateTime? completed,
  String? parent,
  String dept = '',
}) => ITTask.fromJson({
  '_id': id,
  'projectId': project,
  'title': 'Task $id',
  'status': status,
  if (parent != null) 'parentTaskId': parent,
  if (due != null) 'dueDate': due.toIso8601String(),
  if (created != null) 'createdAt': created.toIso8601String(),
  if (completed != null) 'completedAt': completed.toIso8601String(),
  'departmentName': dept,
});

void main() {
  group('the period', () {
    test('a week runs Monday to Sunday', () {
      final w = periodSpan(DashboardPeriod.week, _now);
      expect(w.start, DateTime(2026, 11, 9));
      expect(w.end, DateTime(2026, 11, 15));
    });

    test('a Sunday still belongs to the week that began on the Monday before', () {
      final w = periodSpan(DashboardPeriod.week, DateTime(2026, 11, 15, 23, 0));
      expect(w.start, DateTime(2026, 11, 9));
    });

    test('month, quarter and year', () {
      expect(periodSpan(DashboardPeriod.month, _now), DaySpan(DateTime(2026, 11, 1), DateTime(2026, 11, 30)));
      expect(periodSpan(DashboardPeriod.quarter, _now), DaySpan(DateTime(2026, 10, 1), DateTime(2026, 12, 31)));
      expect(periodSpan(DashboardPeriod.quarter, DateTime(2026, 2, 3)), DaySpan(DateTime(2026, 1, 1), DateTime(2026, 3, 31)));
      expect(periodSpan(DashboardPeriod.year, _now), DaySpan(DateTime(2026, 1, 1), DateTime(2026, 12, 31)));
    });

    test('February in a leap year has its 29th', () {
      expect(periodSpan(DashboardPeriod.month, DateTime(2028, 2, 10)).end, DateTime(2028, 2, 29));
    });

    test('a custom range is used as chosen; none chosen falls back to the year', () {
      final c = DaySpan(DateTime(2026, 3, 5), DateTime(2026, 4, 20));
      expect(periodSpan(DashboardPeriod.custom, _now, custom: c), c);
      expect(periodSpan(DashboardPeriod.custom, _now).start, DateTime(2026, 1, 1));
    });

    test('days counts both ends', () {
      expect(DaySpan(DateTime(2026, 11, 1), DateTime(2026, 11, 30)).days, 30);
      expect(DaySpan(DateTime(2026, 11, 1), DateTime(2026, 11, 1)).days, 1);
    });

    test('a daylight-saving change never makes a day short', () {
      expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
      expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
    });
  });

  group('which projects run in the period', () {
    final nov = periodSpan(DashboardPeriod.month, _now);

    test('one that overlaps it at all', () {
      expect(projectInSpan(_p('a', start: DateTime(2026, 10, 20), end: DateTime(2026, 11, 2)), nov), isTrue); // ends inside
      expect(projectInSpan(_p('b', start: DateTime(2026, 11, 20), end: DateTime(2027, 2, 1)), nov), isTrue); // starts inside
      expect(projectInSpan(_p('c', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1)), nov), isTrue); // spans it
    });

    test('not one that ended before or starts after', () {
      expect(projectInSpan(_p('a', start: DateTime(2026, 8, 1), end: DateTime(2026, 10, 31)), nov), isFalse);
      expect(projectInSpan(_p('b', start: DateTime(2026, 12, 1), end: DateTime(2027, 1, 31)), nov), isFalse);
    });

    test('the first and the last day count', () {
      expect(projectInSpan(_p('a', start: DateTime(2026, 10, 1), end: DateTime(2026, 11, 1)), nov), isTrue);
      expect(projectInSpan(_p('b', start: DateTime(2026, 11, 30), end: DateTime(2026, 12, 15)), nov), isTrue);
    });

    test('a project with no dates is never hidden — it cannot be placed on a calendar', () {
      expect(projectInSpan(_p('a'), nov), isTrue);
    });

    test('a start and no end is still running; once finished it ends where it began', () {
      expect(projectInSpan(_p('a', start: DateTime(2026, 5, 1)), nov), isTrue);
      expect(projectInSpan(_p('b', start: DateTime(2026, 5, 1), status: 'completed'), nov), isFalse);
    });
  });

  group('status and overdue', () {
    test('every status lands in one bucket; a proposal has not started', () {
      expect(bucketOf(_p('a', status: 'active')), ProjectBucket.inProgress);
      expect(bucketOf(_p('a', status: 'completed')), ProjectBucket.completed);
      expect(bucketOf(_p('a', status: 'on-hold')), ProjectBucket.onHold);
      expect(bucketOf(_p('a', status: 'cancelled')), ProjectBucket.cancelled);
      expect(bucketOf(_p('a', status: 'planning')), ProjectBucket.notStarted);
      expect(bucketOf(_p('a', status: 'proposed')), ProjectBucket.notStarted);
    });

    test('overdue is past the end DAY and not finished: the end day itself is on time', () {
      expect(isOverdue(_p('a', end: DateTime(2026, 11, 10)), _now), isTrue);
      expect(isOverdue(_p('a', end: DateTime(2026, 11, 11)), _now), isFalse);
      expect(isOverdue(_p('a', end: DateTime(2026, 11, 10), status: 'completed'), _now), isFalse);
      expect(isOverdue(_p('a', end: DateTime(2026, 11, 10), status: 'cancelled'), _now), isFalse);
      expect(isOverdue(_p('a'), _now), isFalse); // no end date: nothing to be late for
    });
  });

  group('the headline numbers', () {
    final year = periodSpan(DashboardPeriod.year, _now);
    final projects = [
      _p('1', status: 'active', start: DateTime(2026, 2, 1), end: DateTime(2026, 12, 1), progress: 60, manager: 'm1', members: ['a', 'b']),
      _p('2', status: 'completed', start: DateTime(2026, 1, 10), end: DateTime(2026, 5, 1), progress: 100, manager: 'm1', members: ['b', 'c']),
      _p('3', status: 'on-hold', start: DateTime(2026, 6, 1), end: DateTime(2026, 9, 1), progress: 20, manager: 'm2'), // overdue too
      _p('4', status: 'planning', start: DateTime(2026, 12, 1), end: DateTime(2027, 3, 1), progress: 0, manager: 'm2'),
      _p('5', status: 'cancelled', start: DateTime(2026, 3, 1), end: DateTime(2026, 4, 1), progress: 80, manager: 'm3'),
      _p('old', status: 'completed', start: DateTime(2024, 1, 1), end: DateTime(2024, 6, 1), progress: 100), // another year
    ];
    final s = ProjectDashboardStats.compute(projects, year, _now);

    test('only the projects running in the period are counted', () {
      expect(s.total, 5);
      expect(s.projects.map((p) => p.id), isNot(contains('old')));
    });

    test('counts per status', () {
      expect(s.active, 1);
      expect(s.completed, 1);
      expect(s.onHold, 1);
      expect(s.notStarted, 1);
      expect(s.cancelled, 1);
      expect(s.slices.fold<int>(0, (a, b) => a + b.count), s.total);
    });

    test('overall progress averages the live projects — a cancelled one is not "progress"', () {
      expect(s.progress, 45); // (60 + 100 + 20 + 0) / 4
    });

    test('overdue ones are listed', () {
      expect(s.overdue.map((p) => p.id), ['3']);
    });

    test('percent of the total rounds, and an empty period never divides by zero', () {
      expect(s.percentOfTotal(1), 20);
      final none = ProjectDashboardStats.compute(const [], year, _now);
      expect(none.percentOfTotal(3), 0);
      expect(none.progress, 0);
      expect(none.total, 0);
    });

    test('how many started inside the period', () {
      final nov = ProjectDashboardStats.compute(projects, periodSpan(DashboardPeriod.month, _now), _now);
      expect(nov.startedInSpan, 0);
      expect(s.startedInSpan, 5); // all five began in 2026
    });

    test('people are counted once, however many projects they are on — managers and members alike', () {
      expect(s.people, 6); // m1, m2, m3, a, b, c
    });

    test('ending within 30 days, soonest first', () {
      final soon = ProjectDashboardStats.compute(
        [
          _p('x', end: DateTime(2026, 11, 20), start: DateTime(2026, 10, 1)),
          _p('y', end: DateTime(2026, 11, 12), start: DateTime(2026, 10, 1)),
          _p('z', end: DateTime(2026, 12, 25), start: DateTime(2026, 10, 1)), // 44 days away
          _p('f', end: DateTime(2026, 11, 15), start: DateTime(2026, 10, 1), status: 'completed'),
        ],
        year,
        _now,
      );
      expect(soon.dueSoon.map((p) => p.id), ['y', 'x']);
    });
  });

  group('departments', () {
    test('a project several departments work on counts under each, with each one\'s own progress', () {
      final ds = departmentStats([
        _p(
          '1',
          dept: 'IT',
          progress: 50,
          tasks: 10,
          done: 5,
          depts: [
            {'name': 'IT', 'role': 'owner', 'status': 'accepted'},
            {'name': 'Marketing', 'role': 'participant', 'status': 'accepted'},
          ],
          deptProgress: [
            {'name': 'IT', 'progress': 80, 'tasks': 5, 'done': 4},
            {'name': 'Marketing', 'progress': 20, 'tasks': 5, 'done': 1},
          ],
        ),
      ]);
      expect(ds.map((d) => d.name).toSet(), {'IT', 'Marketing'});
      expect(ds.firstWhere((d) => d.name == 'IT').progress, 80);
      expect(ds.firstWhere((d) => d.name == 'Marketing').progress, 20);
      expect(ds.every((d) => d.projects == 1), isTrue);
    });

    test('a project of one department uses the project\'s own progress, weighted by its tasks', () {
      final ds = departmentStats([
        _p('1', dept: 'Finance', progress: 100, tasks: 3, done: 3),
        _p('2', dept: 'Finance', progress: 0, tasks: 1, done: 0),
      ]);
      expect(ds.single.projects, 2);
      expect(ds.single.progress, 75); // (100*3 + 0*1) / 4
      expect(ds.single.tasks, 4);
      expect(ds.single.done, 3);
    });

    test('a project with no tasks yet still counts, as 0%', () {
      final ds = departmentStats([_p('1', dept: 'HR', progress: 0)]);
      expect(ds.single.projects, 1);
      expect(ds.single.progress, 0);
      expect(ds.single.tasks, 0);
    });

    test('names are tidied and "it"/"IT" are one department', () {
      final ds = departmentStats([_p('1', dept: 'it'), _p('2', dept: 'IT'), _p('3', dept: 'research-and-development')]);
      expect(ds.map((d) => d.name), containsAll(['IT', 'Research and development']));
      expect(ds.firstWhere((d) => d.name == 'IT').projects, 2);
      expect(deptLabel(''), 'Unassigned');
      expect(deptLabel('hr'), 'HR');
    });

    test('the busiest department comes first', () {
      final ds = departmentStats([_p('1', dept: 'Sales'), _p('2', dept: 'Sales'), _p('3', dept: 'HR')]);
      expect(ds.first.name, 'Sales');
    });

    test('"top" ranks by how far the tasks have got, leaves out departments with no tasks, and stops at the limit', () {
      final all = [
        const DeptStat(name: 'A', projects: 1, progress: 40, tasks: 10, done: 4),
        const DeptStat(name: 'B', projects: 1, progress: 90, tasks: 10, done: 9),
        const DeptStat(name: 'C', projects: 1, progress: 99, tasks: 0, done: 0), // nothing to measure
        const DeptStat(name: 'D', projects: 1, progress: 90, tasks: 20, done: 18),
      ];
      expect(topDepartments(all).map((d) => d.name), ['D', 'B', 'A']); // tie on 90 → more tasks first
      expect(topDepartments(all, limit: 1).map((d) => d.name), ['D']);
    });
  });

  group('tasks', () {
    test('a task split into smaller ones is not counted itself — only its pieces are', () {
      final leaves = leafTasks([_t('phase'), _t('a', parent: 'phase'), _t('b', parent: 'phase'), _t('solo')]);
      expect(leaves.map((t) => t.id), ['a', 'b', 'solo']);
    });

    test('totals: done, overdue (not done and past due) and open', () {
      final t = taskTotals([
        _t('1', status: 'closed'),
        _t('2', status: 'deployed'),
        _t('3', status: 'in-progress', due: DateTime(2026, 11, 1)), // overdue
        _t('4', status: 'todo', due: DateTime(2026, 11, 11)), // due today: still on time
        _t('5', status: 'todo'),
        _t('6', status: 'closed', due: DateTime(2026, 1, 1)), // done, so never overdue
      ], _now);
      expect(t.total, 6);
      expect(t.done, 3);
      expect(t.overdue, 1);
      expect(t.open, 3);
      expect(t.percentDone, 50);
    });

    test('no tasks → 0%, not a division by zero', () {
      expect(taskTotals(const [], _now).percentDone, 0);
    });

    test('per department: the task\'s own, else the project\'s owning department', () {
      final byProject = {'p1': _p('p1', dept: 'Marketing'), 'p2': _p('p2', dept: 'Sales')};
      final out = tasksByDepartment([
        _t('1', project: 'p1'),
        _t('2', project: 'p1', dept: 'IT'),
        _t('3', project: 'p2'),
        _t('4', project: 'missing'),
      ], byProject);
      expect(out, {'Marketing': 1, 'IT': 1, 'Sales': 1, 'Unassigned': 1});
    });
  });

  group('the completion trend', () {
    test('share of tasks done at each point, from when they were made and finished', () {
      final tasks = [
        _t('1', created: DateTime(2026, 9, 1), completed: DateTime(2026, 9, 20), status: 'closed'),
        _t('2', created: DateTime(2026, 9, 1), completed: DateTime(2026, 10, 15), status: 'closed'),
        _t('3', created: DateTime(2026, 10, 5)), // made in October, not done yet
        _t('4', created: DateTime(2026, 9, 1)), // never done
      ];
      final p = completionTrend(tasks, TrendWindow.yearly, _now);
      expect(p.length, 12);
      double? at(int m) => p.firstWhere((e) => e.at.year == 2026 && e.at.month == m).percent;
      expect(at(8), isNull); // nothing existed yet
      expect(at(9), closeTo(100 / 3, 0.001)); // 1 of the 3 that existed by 30 Sep
      expect(at(10), 50); // 2 of the 4 by 31 Oct
      expect(at(11), 50); // today
    });

    test('a task that did not exist yet is not in that month\'s share', () {
      final tasks = [
        _t('1', created: DateTime(2026, 9, 1), completed: DateTime(2026, 9, 20), status: 'closed'),
        _t('2', created: DateTime(2026, 10, 5)),
      ];
      final p = completionTrend(tasks, TrendWindow.yearly, _now);
      double? at(int m) => p.firstWhere((e) => e.at.year == 2026 && e.at.month == m).percent;
      expect(at(9), 100); // one task, done
      expect(at(10), 50); // the second was made in October and is not done
    });

    test('a task done before completion dates were recorded cannot be placed, so it is left out', () {
      final tasks = [
        _t('legacy', created: DateTime(2026, 1, 1), status: 'closed'), // done, but no completedAt
        _t('a', created: DateTime(2026, 9, 1), completed: DateTime(2026, 9, 2), status: 'closed'),
        _t('b', created: DateTime(2026, 9, 1)),
      ];
      final p = completionTrend(tasks, TrendWindow.yearly, _now);
      expect(p.last.percent, 50); // a done, b open — the legacy one is not guessed at
    });

    test('the last point is today and the window has the right number of points', () {
      final tasks = [_t('1', created: DateTime(2026, 1, 1))];
      expect(completionTrend(tasks, TrendWindow.yearly, _now).last.at, DateTime(2026, 11, 11));
      final q = completionTrend(tasks, TrendWindow.quarterly, _now);
      expect(q.length, 13);
      expect(q.last.at, DateTime(2026, 11, 11));
      expect(q[q.length - 2].at, DateTime(2026, 11, 4));
      final m = completionTrend(tasks, TrendWindow.monthly, _now);
      expect(m.length, 11);
      expect(m.first.at, DateTime(2026, 10, 12));
    });

    test('no tasks at all gives no measurable points', () {
      expect(completionTrend(const [], TrendWindow.yearly, _now).every((p) => p.percent == null), isTrue);
    });

    test('pieces count, not the phase they hang under', () {
      final tasks = [
        _t('phase', created: DateTime(2026, 9, 1)),
        _t('a', parent: 'phase', created: DateTime(2026, 9, 1), completed: DateTime(2026, 9, 5), status: 'closed'),
        _t('b', parent: 'phase', created: DateTime(2026, 9, 1)),
      ];
      expect(completionTrend(tasks, TrendWindow.yearly, _now).last.percent, 50);
    });
  });

  group('upcoming projects', () {
    test('dated, not finished, not a proposal; earliest start first; limited', () {
      final rows = upcomingProjects([
        _p('late', start: DateTime(2026, 9, 1), end: DateTime(2026, 12, 1)),
        _p('early', start: DateTime(2026, 3, 1), end: DateTime(2026, 12, 1)),
        _p('done', start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 1), status: 'completed'),
        _p('nodate'),
        _p('noend', start: DateTime(2026, 1, 1)),
        _p('proposal', start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 1), status: 'proposed'),
        _p('hold', start: DateTime(2026, 5, 1), end: DateTime(2026, 12, 1), status: 'on-hold'),
      ], _now);
      expect(rows.map((r) => r.project.id), ['early', 'hold', 'late']);
      expect(upcomingProjects([for (var i = 0; i < 9; i++) _p('p$i', start: DateTime(2026, 1, i + 1), end: DateTime(2026, 12, 1))], _now).length, 5);
    });

    test('a row says whether it is overdue', () {
      final r = upcomingProjects([_p('a', start: DateTime(2026, 1, 1), end: DateTime(2026, 10, 1))], _now).single;
      expect(r.overdue, isTrue);
    });
  });

  group('what stands out', () {
    final year = periodSpan(DashboardPeriod.year, _now);

    test('nothing to say about an empty period', () {
      expect(ProjectDashboardStats.compute(const [], year, _now).insights(), isEmpty);
    });

    test('trouble comes first: overdue, then blocked objectives, then on hold', () {
      final s = ProjectDashboardStats.compute(
        [
          _p('late', start: DateTime(2026, 1, 1), end: DateTime(2026, 9, 1)),
          _p('hold', status: 'on-hold', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1)),
        ],
        year,
        _now,
      );
      final i = s.insights(blockedObjectives: 2);
      expect(i[0].tone, InsightTone.bad);
      expect(i[0].title, '1 project is overdue');
      expect(i[0].detail, 'Project late');
      expect(i[1].title, '2 objectives are blocked');
      expect(i[2].tone, InsightTone.warn);
      expect(i[2].title, '1 project is on hold');
    });

    test('plurals and "and N more"', () {
      final s = ProjectDashboardStats.compute(
        [for (var i = 0; i < 4; i++) _p('o$i', start: DateTime(2026, 1, 1), end: DateTime(2026, 9, 1))],
        year,
        _now,
      );
      expect(s.insights().first.title, '4 projects are overdue');
      expect(s.insights().first.detail, 'Project o0, Project o1 and 2 more');
    });

    test('when nothing is wrong it says so first', () {
      final s = ProjectDashboardStats.compute([_p('ok', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1), progress: 50)], year, _now);
      final i = s.insights();
      expect(i.first.tone, InsightTone.good);
      expect(i.first.title, 'Nothing is behind');
    });

    test('it is not said when something is wrong', () {
      final s = ProjectDashboardStats.compute([_p('late', start: DateTime(2026, 1, 1), end: DateTime(2026, 9, 1))], year, _now);
      expect(s.insights().map((e) => e.title), isNot(contains('Nothing is behind')));
    });

    test('the number completed is always said, and at most five lines are shown', () {
      final s = ProjectDashboardStats.compute(
        [
          _p('late', start: DateTime(2026, 1, 1), end: DateTime(2026, 9, 1)),
          _p('hold', status: 'on-hold', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1)),
          _p('soon', start: DateTime(2026, 1, 1), end: DateTime(2026, 11, 20), tasks: 2, done: 2, progress: 100),
          _p('done', status: 'completed', start: DateTime(2026, 1, 1), end: DateTime(2026, 6, 1), progress: 100, tasks: 4, done: 4),
        ],
        year,
        _now,
      );
      final i = s.insights(blockedObjectives: 1);
      expect(i.length, lessThanOrEqualTo(5));
      final all = s.insights(blockedObjectives: 1, limit: 10).map((e) => e.title);
      expect(all, contains('1 of 4 completed'));
      expect(all, contains('1 ending within 30 days'));
    });
  });

  group('the timeline scale', () {
    test('a quarter is shown in months, and the columns add up to the days', () {
      final span = DaySpan(DateTime(2026, 10, 1), DateTime(2026, 12, 31));
      final cols = timelineColumns(span);
      expect(cols.map((c) => c.label), ['Oct 2026', 'Nov 2026', 'Dec 2026']);
      expect(cols.map((c) => c.days), [31, 30, 31]);
      expect(cols.fold<int>(0, (a, c) => a + c.days), span.days);
    });

    test('a year is shown in quarters', () {
      final span = DaySpan(DateTime(2026, 1, 1), DateTime(2026, 12, 31));
      final cols = timelineColumns(span);
      expect(cols.map((c) => c.label), ['Q1 2026', 'Q2 2026', 'Q3 2026', 'Q4 2026']);
      expect(cols.fold<int>(0, (a, c) => a + c.days), 365);
    });

    test('a range that starts mid-quarter clips its first column', () {
      final span = DaySpan(DateTime(2026, 2, 15), DateTime(2026, 8, 10));
      final cols = timelineColumns(span);
      expect(cols.first.label, 'Q1 2026');
      expect(cols.first.days, daysBetween(DateTime(2026, 2, 15), DateTime(2026, 3, 31)) + 1);
      expect(cols.fold<int>(0, (a, c) => a + c.days), span.days);
    });

    test('several years are shown as years', () {
      final span = DaySpan(DateTime(2026, 1, 1), DateTime(2030, 12, 31));
      final cols = timelineColumns(span);
      expect(cols.map((c) => c.label), ['2026', '2027', '2028', '2029', '2030']);
      expect(cols.fold<int>(0, (a, c) => a + c.days), span.days);
    });
  });

  group('the money across the projects', () {
    Map<String, dynamic> money(double approved, double spent, [double committed = 0]) => {
      'budget': approved,
      'approvedBudget': approved,
      'spent': spent,
      'committed': committed,
    };

    test('what was approved, spent and committed, over the projects whose amounts can be seen', () {
      final t = budgetTotals([_p('a', dept: 'Marketing', cost: money(100000, 30000, 20000)), _p('b', dept: 'IT', cost: money(50000, 10000))]);
      expect(t.projects, 2);
      expect(t.approved, 150000);
      expect(t.spent, 40000);
      expect(t.committed, 20000);
      expect(t.used, 60000);
      expect(t.available, 90000);
      expect(t.fraction, 0.4);
      expect(t.level, 'ok');
    });

    test('a project whose money this person cannot see, one with no approved limit, and a cancelled one are left out', () {
      final t = budgetTotals([
        _p('hidden'), // no cost sent
        _p('waiting', cost: {'budget': 90000, 'approvedBudget': 0, 'spent': 0, 'committed': 0}),
        _p('gone', status: 'cancelled', cost: money(40000, 1000)),
        _p('counted', cost: money(10000, 1000)),
      ]);
      expect(t.projects, 1);
      expect(t.approved, 10000);
    });

    test('nothing to total', () {
      final t = budgetTotals(const []);
      expect(t.projects, 0);
      expect(t.fraction, isNull);
      expect(t.level, 'none');
      expect(t.byDepartment, isEmpty);
    });

    test('by department: each one\'s approved and used, most used first, names tidied', () {
      final t = budgetTotals([
        _p('a', dept: 'it', cost: money(100000, 70000)),
        _p('b', dept: 'IT', cost: money(50000, 20000)),
        _p('c', dept: 'Marketing', cost: money(100000, 95000)),
      ]);
      expect(t.byDepartment.map((d) => d.name), ['Marketing', 'IT']);
      expect(t.byDepartment.last.approved, 150000);
      expect(t.byDepartment.last.used, 90000);
      expect(t.byDepartment.last.fraction, 0.6);
    });

    test('over and near, most used first; exactly the limit is not over', () {
      final t = budgetTotals([
        _p('ok', cost: money(1000, 100)),
        _p('near', cost: money(1000, 850)),
        _p('edge', cost: money(1000, 1000)),
        _p('over', cost: money(1000, 1200)),
        _p('wayover', cost: money(1000, 3000)),
      ]);
      expect(t.over.map((p) => p.id), ['wayover', 'over']);
      expect(t.near.map((p) => p.id), ['edge', 'near']);
      expect(t.level, 'over');
    });

    test('committed counts toward being near or over', () {
      final t = budgetTotals([_p('a', cost: money(1000, 500, 600))]);
      expect(t.over.single.id, 'a');
    });
  });

  group('the money in what stands out', () {
    final year = periodSpan(DashboardPeriod.year, _now);
    Map<String, dynamic> money(double approved, double spent) => {'budget': approved, 'approvedBudget': approved, 'spent': spent, 'committed': 0};

    test('a project over its budget comes first, named', () {
      final s = ProjectDashboardStats.compute(
        [
          _p('late', start: DateTime(2026, 1, 1), end: DateTime(2026, 9, 1)),
          _p('over', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1), cost: money(1000, 1500)),
        ],
        year,
        _now,
      );
      final i = s.insights();
      expect(i.first.tone, InsightTone.bad);
      expect(i.first.title, '1 project is over budget');
      expect(i.first.detail, 'Project over');
      expect(i[1].title, '1 project is overdue');
    });

    test('one nearing its budget is mentioned, as a warning', () {
      final s = ProjectDashboardStats.compute(
        [_p('near', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1), cost: money(1000, 900))],
        year,
        _now,
      );
      final w = s.insights(limit: 10).firstWhere((e) => e.title.contains('budget'));
      expect(w.tone, InsightTone.warn);
      expect(w.title, '1 nearing its budget');
    });

    test('several: plural wording', () {
      final s = ProjectDashboardStats.compute(
        [
          _p('a', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1), cost: money(1000, 900)),
          _p('b', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1), cost: money(1000, 850)),
        ],
        year,
        _now,
      );
      expect(s.insights(limit: 10).any((e) => e.title == '2 near their budget'), isTrue);
    });

    test('"nothing is behind" is not said while a project is over budget', () {
      final s = ProjectDashboardStats.compute(
        [_p('over', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1), cost: money(1000, 1500))],
        year,
        _now,
      );
      expect(s.insights().map((e) => e.title), isNot(contains('Nothing is behind')));
    });

    test('a project whose money cannot be seen says nothing about it', () {
      final s = ProjectDashboardStats.compute([_p('x', start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1), progress: 50)], year, _now);
      expect(s.insights().any((e) => e.title.contains('budget')), isFalse);
    });
  });
}
