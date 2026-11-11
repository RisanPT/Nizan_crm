import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/models/monthly_objective.dart';
import 'package:nizan_crm/features/it/domain/models/monthly_trend.dart';
import 'package:nizan_crm/features/it/domain/monthly_objective_stats.dart';

// The numbers behind the Monthly Objectives page: where each objective stands, the headline counts, the filters, what stands out, the
// days of the month, the key results across it and the progress matrix.

MonthlyObjective _o(
  String id, {
  int progress = 0,
  String? result,
  String dept = 'd1',
  String deptName = 'IT',
  String priority = 'medium',
  String owner = '',
  bool mine = false,
  bool ready = false,
  String title = 'An objective',
  String description = '',
  List<Map<String, dynamic>> krs = const [],
}) => MonthlyObjective.fromJson({
  'id': id,
  'departmentId': dept,
  'departmentName': deptName,
  'year': 2026,
  'month': 11,
  'objective': title,
  'description': description,
  'priority': priority,
  'ownerName': owner,
  'progress': progress,
  'result': result,
  'assignedToMe': mine,
  'readyToClose': ready,
  'keyResults': krs,
});

Map<String, dynamic> _kr(String id, String title, {double target = 10, double current = 0, bool done = false}) => {
  'id': id,
  'title': title,
  'kind': 'number',
  'targetValue': target,
  'currentValue': current,
  'completed': done,
};

MonthlyDepartment _d(String id, String name, {List<MonthlyObjective> objectives = const [], int lastOpen = 0}) => MonthlyDepartment(
  departmentId: id,
  name: name,
  objectives: objectives,
  lastMonth: MonthlySummary(count: lastOpen, open: lastOpen),
);

void main() {
  // ── where one objective stands ────────────────────────────────────────────

  group('where an objective stands', () {
    test('an open one is judged by its progress', () {
      expect(statusOf(_o('a', progress: 0)), ObjectiveStatus.notStarted);
      expect(statusOf(_o('a', progress: 1)), ObjectiveStatus.inProgress);
      expect(statusOf(_o('a', progress: 40)), ObjectiveStatus.inProgress);
      expect(statusOf(_o('a', progress: 99)), ObjectiveStatus.inProgress);
      expect(statusOf(_o('a', progress: 100)), ObjectiveStatus.completed);
    });

    test('a closed one is judged by how it ended — whatever its progress was', () {
      expect(statusOf(_o('a', progress: 40, result: 'achieved')), ObjectiveStatus.completed);
      expect(statusOf(_o('a', progress: 100, result: 'partly')), ObjectiveStatus.partly);
      expect(statusOf(_o('a', progress: 90, result: 'missed')), ObjectiveStatus.missed);
      expect(statusOf(_o('a', progress: 0, result: 'cancelled')), ObjectiveStatus.cancelled);
      expect(statusOf(_o('a', progress: 50, result: 'deferred')), ObjectiveStatus.postponed);
    });

    test('a several-month objective that continues is still in progress, even with nothing done', () {
      expect(statusOf(_o('a', progress: 0, result: 'continued')), ObjectiveStatus.inProgress);
    });

    test('the words', () {
      expect(ObjectiveStatus.notStarted.label, 'Not started');
      expect(ObjectiveStatus.inProgress.label, 'In progress');
      expect(ObjectiveStatus.completed.label, 'Completed');
      expect(ObjectiveStatus.partly.label, 'Partly done');
      expect(ObjectiveStatus.missed.label, 'Missed');
      expect(ObjectiveStatus.cancelled.label, 'Cancelled');
      expect(ObjectiveStatus.postponed.label, 'Postponed');
    });

    test('dropped is cancelled or postponed; ended short is those and partly and missed', () {
      for (final s in ObjectiveStatus.values) {
        expect(s.isDropped, s == ObjectiveStatus.cancelled || s == ObjectiveStatus.postponed, reason: s.name);
        expect(s.endedShort, s.isDropped || s == ObjectiveStatus.partly || s == ObjectiveStatus.missed, reason: s.name);
      }
    });
  });

  // ── the headline numbers ──────────────────────────────────────────────────

  group('the headline numbers', () {
    final all = [
      _o('1', progress: 100),
      _o('2', progress: 40),
      _o('3', progress: 0),
      _o('4', progress: 50, result: 'partly'),
      _o('5', progress: 20, result: 'missed'),
      _o('6', progress: 0, result: 'cancelled'),
      _o('7', progress: 30, result: 'deferred'),
    ];

    test('counts each kind', () {
      final s = MonthlyStats.of(all);
      expect(s.total, 7);
      expect(s.completed, 1);
      expect(s.inProgress, 1);
      expect(s.notStarted, 1);
      expect(s.endedShort, 2);
      expect(s.dropped, 2);
      expect(s.other, 4);
      expect(s.remaining, 2);
    });

    test('the average leaves cancelled and postponed objectives out, as the server does', () {
      // (100 + 40 + 0 + 50 + 20) / 5 = 42
      expect(MonthlyStats.of(all).avgProgress, 42);
    });

    test('the average rounds', () {
      expect(MonthlyStats.of([_o('a', progress: 33), _o('b', progress: 34)]).avgProgress, 34); // 33.5
    });

    test('nothing at all is zeros, not a crash', () {
      final s = MonthlyStats.of(const []);
      expect([s.total, s.completed, s.avgProgress, s.other, s.remaining], [0, 0, 0, 0, 0]);
      expect(s.percentOf(0), 0);
    });

    test('only dropped ones: no average to speak of', () {
      expect(MonthlyStats.of([_o('a', progress: 80, result: 'cancelled')]).avgProgress, 0);
    });

    test('a share of the total, as a whole percent', () {
      final s = MonthlyStats.of([_o('a', progress: 100), _o('b'), _o('c')]);
      expect(s.percentOf(s.completed), 33);
      expect(s.percentOf(2), 67);
    });

    test('ready to close counts only open objectives with every key result done', () {
      final s = MonthlyStats.of([_o('a', ready: true), _o('b', ready: true, result: 'achieved'), _o('c')]);
      expect(s.readyToClose, 1);
    });

    test('compared with the month before', () {
      final s = MonthlyStats.of([_o('a'), _o('b'), _o('c')], previousCount: 2);
      expect(s.previousCount, 2);
      expect(s.change, 1);
      expect(MonthlyStats.of([_o('a')], previousCount: 3).change, -2);
      expect(MonthlyStats.of([_o('a')], previousCount: 1).change, 0);
      expect(MonthlyStats.of([_o('a')]).change, isNull);
    });
  });

  // ── the days of a month ───────────────────────────────────────────────────

  group('the days of a month', () {
    test('how many days, leap years included', () {
      expect(daysIn((year: 2026, month: 11)), 30);
      expect(daysIn((year: 2026, month: 12)), 31);
      expect(daysIn((year: 2027, month: 2)), 28);
      expect(daysIn((year: 2028, month: 2)), 29);
    });

    test('first and last day', () {
      expect(firstDayOf((year: 2026, month: 11)), DateTime(2026, 11, 1));
      expect(lastDayOf((year: 2026, month: 11)), DateTime(2026, 11, 30));
      expect(lastDayOf((year: 2026, month: 12)), DateTime(2026, 12, 31));
    });

    test('the range as the page writes it', () {
      expect(rangeText((year: 2026, month: 11)), '01 Nov 2026 – 30 Nov 2026 (30 days)');
      expect(rangeText((year: 2028, month: 2)), '01 Feb 2028 – 29 Feb 2028 (29 days)');
      expect(rangeText((year: 2026, month: 12)), '01 Dec 2026 – 31 Dec 2026 (31 days)');
    });

    test('the last day, for "by 30 Nov"', () {
      expect(lastDayText((year: 2026, month: 11)), '30 Nov');
      expect(lastDayText((year: 2027, month: 2)), '28 Feb');
    });

    test('before, during or after', () {
      final now = DateTime(2026, 11, 11);
      expect(timingOf((year: 2026, month: 10), now), MonthTiming.past);
      expect(timingOf((year: 2026, month: 11), now), MonthTiming.current);
      expect(timingOf((year: 2026, month: 12), now), MonthTiming.future);
      expect(timingOf((year: 2025, month: 12), now), MonthTiming.past);
      expect(timingOf((year: 2027, month: 1), now), MonthTiming.future);
    });

    test('days left in the current month only', () {
      expect(daysLeft((year: 2026, month: 11), DateTime(2026, 11, 11)), 19);
      expect(daysLeft((year: 2026, month: 11), DateTime(2026, 11, 30)), 0);
      expect(daysLeft((year: 2026, month: 10), DateTime(2026, 11, 11)), 0);
      expect(daysLeft((year: 2026, month: 12), DateTime(2026, 11, 11)), 0);
    });
  });

  // ── filters ───────────────────────────────────────────────────────────────

  group('narrowing the list', () {
    final a = _o('a', title: 'Marketing Automation', owner: 'Akash', progress: 0, priority: 'high', dept: 'd1', deptName: 'IT', krs: [_kr('k', 'Leads captured')]);
    final b = _o('b', title: 'Upgrade CRM Integration', owner: 'Shuhaib', progress: 40, priority: 'medium', dept: 'd1', deptName: 'IT', mine: true);
    final c = _o('c', title: 'System Security Review', owner: 'Shuhaib', progress: 100, priority: 'high', dept: 'd2', deptName: 'HR', description: 'passwords and access');
    final all = [a, b, c];

    ids(ObjectiveFilter f) => [for (final o in f.apply(all)) o.id];

    test('no filter shows everything', () {
      expect(ids(const ObjectiveFilter()), ['a', 'b', 'c']);
      expect(const ObjectiveFilter().isEmpty, isTrue);
      expect(const ObjectiveFilter().activeCount, 0);
    });

    test('search finds the title, the owner, the department, the description and a key result — in any case', () {
      expect(ids(const ObjectiveFilter(query: 'crm')), ['b']);
      expect(ids(const ObjectiveFilter(query: 'SHUHAIB')), ['b', 'c']);
      expect(ids(const ObjectiveFilter(query: 'hr')), ['c']);
      expect(ids(const ObjectiveFilter(query: 'passwords')), ['c']);
      expect(ids(const ObjectiveFilter(query: 'leads')), ['a']);
      expect(ids(const ObjectiveFilter(query: '  crm  ')), ['b'], reason: 'spaces around it do not matter');
      expect(ids(const ObjectiveFilter(query: 'zzz')), isEmpty);
    });

    test('by status', () {
      expect(ids(const ObjectiveFilter(statuses: {ObjectiveStatus.notStarted})), ['a']);
      expect(ids(const ObjectiveFilter(statuses: {ObjectiveStatus.notStarted, ObjectiveStatus.completed})), ['a', 'c']);
    });

    test('by priority', () {
      expect(ids(const ObjectiveFilter(priorities: {'high'})), ['a', 'c']);
      expect(ids(const ObjectiveFilter(priorities: {'low'})), isEmpty);
    });

    test('by department', () {
      expect(ids(const ObjectiveFilter(departmentId: 'd2')), ['c']);
    });

    test('only what is given to me', () {
      expect(ids(const ObjectiveFilter(onlyMine: true)), ['b']);
    });

    test('every choice has to hold at once', () {
      expect(ids(const ObjectiveFilter(query: 'shuhaib', priorities: {'high'})), ['c']);
      expect(ids(const ObjectiveFilter(departmentId: 'd1', statuses: {ObjectiveStatus.completed})), isEmpty);
    });

    test('the Filters button counts its own choices — not the search box or the department', () {
      expect(const ObjectiveFilter(query: 'x', departmentId: 'd1').activeCount, 0);
      expect(const ObjectiveFilter(statuses: {ObjectiveStatus.completed, ObjectiveStatus.missed}).activeCount, 1);
      expect(const ObjectiveFilter(statuses: {ObjectiveStatus.completed}, priorities: {'high'}, onlyMine: true).activeCount, 3);
    });

    test('empty means no search, no choices and no department', () {
      expect(const ObjectiveFilter(query: '  ').isEmpty, isTrue);
      expect(const ObjectiveFilter(query: 'a').isEmpty, isFalse);
      expect(const ObjectiveFilter(departmentId: 'd1').isEmpty, isFalse);
      expect(const ObjectiveFilter(onlyMine: true).isEmpty, isFalse);
    });

    test('copyWith changes one thing and keeps the rest; the department can be cleared', () {
      const f = ObjectiveFilter(query: 'q', statuses: {ObjectiveStatus.missed}, priorities: {'high'}, departmentId: 'd1', onlyMine: true);
      final g = f.copyWith(query: 'z');
      expect([g.query, g.statuses, g.priorities, g.departmentId, g.onlyMine], ['z', {ObjectiveStatus.missed}, {'high'}, 'd1', true]);
      expect(f.copyWith(departmentId: null).departmentId, isNull, reason: 'null clears it');
      expect(f.copyWith(departmentId: 'd2').departmentId, 'd2');
      expect(f.copyWith(onlyMine: false).onlyMine, isFalse);
      expect(f.copyWith(statuses: const {}).statuses, isEmpty);
    });
  });

  // ── what is worth pointing out ────────────────────────────────────────────

  group('what stands out', () {
    const nov = (year: 2026, month: 11);
    final mid = DateTime(2026, 11, 11);
    List<String> say(List<MonthlyDepartment> d, {DateTime? now, MonthKey month = nov}) => [for (final t in takeawaysFor(d, month, now ?? mid)) t.text];

    test('what is done, moving and not started — and in whose hands', () {
      final lines = say([
        _d('d1', 'IT', objectives: [_o('a', progress: 100), _o('b', progress: 40), _o('c', progress: 0)]),
      ]);
      expect(lines[0], '1 objective completed (IT)');
      expect(lines[1], '1 objective in progress (IT)');
      expect(lines[2], '1 objective not started (IT)');
    });

    test('the tones', () {
      final t = takeawaysFor([_d('d1', 'IT', objectives: [_o('a', progress: 100), _o('b', progress: 40), _o('c', progress: 0)])], nov, mid);
      expect(t[0].tone, TakeawayTone.good);
      expect(t[1].tone, TakeawayTone.info);
      expect(t[2].tone, TakeawayTone.neutral);
    });

    test('plural and singular', () {
      final lines = say([
        _d('d1', 'IT', objectives: [_o('a', progress: 100), _o('b', progress: 100)]),
      ]);
      expect(lines[0], '2 objectives completed (IT)');
    });

    test('departments are named once each, and only the first few', () {
      final lines = say([
        _d('d1', 'IT', objectives: [_o('a', progress: 100, deptName: 'IT'), _o('b', progress: 100, deptName: 'IT')]),
        _d('d2', 'HR', objectives: [_o('c', progress: 100, deptName: 'HR')]),
        _d('d3', 'Finance', objectives: [_o('d', progress: 100, deptName: 'Finance')]),
        _d('d4', 'CRM', objectives: [_o('e', progress: 100, deptName: 'CRM')]),
        _d('d5', 'Accounts', objectives: [_o('f', progress: 100, deptName: 'Accounts')]),
      ]);
      expect(lines[0], '6 objectives completed (IT, HR, Finance +2 more)');
    });

    test('ended short or dropped is said, with who', () {
      final lines = say([
        _d('d1', 'IT', objectives: [_o('a', progress: 30, result: 'missed'), _o('b', result: 'cancelled'), _o('c', progress: 0, result: 'deferred')]),
      ]);
      expect(lines.firstWhere((l) => l.contains('ended short')), '3 objectives ended short or were dropped (IT)');
      expect(say([_d('d1', 'IT', objectives: [_o('a', result: 'cancelled')])]).first, '1 objective ended short or was dropped (IT)');
    });

    test('departments that have set nothing are named', () {
      final lines = say([_d('d1', 'IT', objectives: [_o('a')]), _d('d2', 'Finance'), _d('d3', 'Management')]);
      expect(lines, contains('No objectives set yet: Finance, Management'));
    });

    test('what is one tap from done', () {
      final lines = say([
        _d('d1', 'IT', objectives: [_o('a', progress: 100, ready: true), _o('b', progress: 100, ready: true)]),
      ]);
      expect(lines, contains('2 objectives ready to close as achieved'));
    });

    test('last month\'s loose ends', () {
      expect(say([_d('d1', 'IT', objectives: [_o('a')], lastOpen: 1)]), contains('1 objective from October was never closed out'));
      expect(say([_d('d1', 'IT', objectives: [_o('a')], lastOpen: 3), _d('d2', 'HR', lastOpen: 2)]), contains('5 objectives from October were never closed out'));
      expect(say([_d('d1', 'IT', objectives: [_o('a')])]).where((l) => l.contains('never closed')), isEmpty);
    });

    test('this month: how much is still to finish by the last day, and how long is left', () {
      final lines = say([
        _d('d1', 'IT', objectives: [_o('a', progress: 100), _o('b', progress: 40), _o('c', progress: 0)]),
      ]);
      expect(lines.last, '2 of 3 (67%) still to finish by 30 Nov — 19 days left');
    });

    test('with a day left it says "1 day"; on the last day, "last day today"; and it is urgent from five days out', () {
      final d = [
        _d('d1', 'IT', objectives: [_o('a', progress: 40)]),
      ];
      expect(say(d, now: DateTime(2026, 11, 29)).last, '1 of 1 (100%) still to finish by 30 Nov — 1 day left');
      expect(say(d, now: DateTime(2026, 11, 30)).last, '1 of 1 (100%) still to finish by 30 Nov — last day today');
      expect(takeawaysFor(d, nov, DateTime(2026, 11, 25)).last.tone, TakeawayTone.bad, reason: '5 days left');
      expect(takeawaysFor(d, nov, DateTime(2026, 11, 24)).last.tone, TakeawayTone.info, reason: '6 days left');
    });

    test('a month that is over: what was still open when it ended', () {
      final d = [
        _d('d1', 'IT', objectives: [_o('a', progress: 100), _o('b', progress: 40)]),
      ];
      final lines = say(d, month: (year: 2026, month: 10), now: mid);
      expect(lines.last, '1 of 2 (50%) was still open when October ended');
      expect(takeawaysFor(d, (year: 2026, month: 10), mid).last.tone, TakeawayTone.bad);
    });

    test('a month still to come has no pace to speak of', () {
      final d = [
        _d('d1', 'IT', objectives: [_o('a', progress: 0)]),
      ];
      expect(say(d, month: (year: 2026, month: 12)).where((l) => l.contains('still to finish') || l.contains('still open')), isEmpty);
    });

    test('everything finished: no "still to finish"', () {
      expect(say([_d('d1', 'IT', objectives: [_o('a', progress: 100)])]).where((l) => l.contains('still to finish')), isEmpty);
    });

    test('nothing set anywhere says only who has set nothing', () {
      final lines = say([_d('d1', 'IT'), _d('d2', 'HR')]);
      expect(lines, ['No objectives set yet: IT, HR']);
    });
  });

  // ── key results across the month ──────────────────────────────────────────

  group('key results across the month', () {
    final objs = [
      _o('a', title: 'First', krs: [_kr('k1', 'Open one', current: 2), _kr('k2', 'Done one', current: 10, done: true), _kr('k3', 'Reached', current: 10)]),
      _o('b', title: 'Second', krs: [_kr('k4', 'Other open')]),
      _o('c', title: 'Dropped', result: 'cancelled', krs: [_kr('k5', 'From a cancelled one')]),
    ];

    List<String> ids(KeyResultFilter f) => [for (final r in keyResultRows(objs, filter: f)) r.keyResult.id];

    test('unfinished first, then by objective as given; a cancelled objective\'s are left out', () {
      expect(ids(KeyResultFilter.all), ['k1', 'k4', 'k2', 'k3']);
    });

    test('open and done', () {
      expect(ids(KeyResultFilter.open), ['k1', 'k4']);
      expect(ids(KeyResultFilter.done), ['k2', 'k3']);
    });

    test('done is ticked or reached its target', () {
      final rows = keyResultRows(objs);
      expect(rows.firstWhere((r) => r.keyResult.id == 'k2').done, isTrue);
      expect(rows.firstWhere((r) => r.keyResult.id == 'k3').done, isTrue, reason: 'reached 10 of 10');
      expect(rows.firstWhere((r) => r.keyResult.id == 'k1').done, isFalse);
    });

    test('each row knows its objective', () {
      expect(keyResultRows(objs).first.objective.id, 'a');
    });

    test('nothing to list is an empty list', () {
      expect(keyResultRows(const []), isEmpty);
    });
  });

  // ── the progress matrix ───────────────────────────────────────────────────

  group('the progress matrix', () {
    test('how a cell is judged', () {
      expect(heatOf(null), Heat.none);
      expect(heatOf(0), Heat.low);
      expect(heatOf(39), Heat.low);
      expect(heatOf(40), Heat.mid);
      expect(heatOf(69), Heat.mid);
      expect(heatOf(70), Heat.high);
      expect(heatOf(99), Heat.high);
      expect(heatOf(100), Heat.full);
    });
  });

  // ── the trend ─────────────────────────────────────────────────────────────

  group('the trend as the server sends it', () {
    final trend = MonthlyTrend.fromJson({
      'end': {'year': 2026, 'month': 11},
      'months': [
        {
          'year': 2026,
          'month': 9,
          'count': 0,
          'avgProgress': 0,
          'closed': 0,
          'achieved': 0,
          'departments': [
            {'departmentId': 'd1', 'name': 'IT', 'count': 0, 'avgProgress': 0, 'closed': 0},
            {'departmentId': 'd2', 'name': 'HR', 'count': 0, 'avgProgress': 0, 'closed': 0},
          ],
        },
        {
          'year': 2026,
          'month': 10,
          'count': 2,
          'avgProgress': 45,
          'closed': 1,
          'achieved': 1,
          'departments': [
            {'departmentId': 'd1', 'name': 'IT', 'count': 2, 'avgProgress': 45, 'closed': 1},
            {'departmentId': 'd2', 'name': 'HR', 'count': 0, 'avgProgress': 0, 'closed': 0},
          ],
        },
        {
          'year': 2026,
          'month': 11,
          'count': 3,
          'avgProgress': 33,
          'closed': 1,
          'achieved': 1,
          'departments': [
            {'departmentId': 'd1', 'name': 'IT', 'count': 2, 'avgProgress': 20, 'closed': 1},
            {'departmentId': 'd2', 'name': 'HR', 'count': 1, 'avgProgress': 60, 'closed': 0},
          ],
        },
      ],
    });

    test('is read month by month, oldest first', () {
      expect(trend.months.map((m) => m.key), [(year: 2026, month: 9), (year: 2026, month: 10), (year: 2026, month: 11)]);
      expect(trend.months.map((m) => m.shortName), ['Sep', 'Oct', 'Nov']);
      expect(trend.months[2].avgProgress, 33);
      expect(trend.months[2].achieved, 1);
    });

    test('a month with nothing set has no data — a gap, not a 0%', () {
      expect(trend.months[0].hasData, isFalse);
      expect(trend.months[1].hasData, isTrue);
      expect(trend.hasAny, isTrue);
      expect(const MonthlyTrend().hasAny, isFalse);
      expect(trend.months[0].departments.first.hasData, isFalse);
    });

    test('a month for the whole company or for one department', () {
      final nov = trend.months[2];
      expect(nov.of(null), (count: 3, avgProgress: 33, hasData: true));
      expect(nov.of('d1'), (count: 2, avgProgress: 20, hasData: true));
      expect(nov.of('d2'), (count: 1, avgProgress: 60, hasData: true));
      expect(nov.of('nope'), isNull);
      expect(trend.months[1].of('d2')!.hasData, isFalse);
    });

    test('how many months have something to plot — a line needs two', () {
      expect(trend.measured(null), 2);
      expect(trend.measured('d1'), 2);
      expect(trend.measured('d2'), 1);
      expect(trend.measured('nope'), 0);
    });

    test('the departments are those of the latest month', () {
      expect(trend.departments.map((d) => d.name), ['IT', 'HR']);
      expect(const MonthlyTrend().departments, isEmpty);
    });

    test('a response with nothing in it is an empty trend', () {
      expect(MonthlyTrend.fromJson(const {}).months, isEmpty);
    });
  });
}
