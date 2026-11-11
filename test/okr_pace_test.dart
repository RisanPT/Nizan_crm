import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';

// How the OKR timeline judges an objective, orders the alignment tree and sizes its window.

OKRModel _okr(
  String id, {
  DateTime? start,
  DateTime? end,
  int progress = 0,
  OKRStatus status = OKRStatus.inProgress,
  String? parent,
  String level = 'project',
  int order = 0,
  DateTime? created,
  List<KeyResultItem> krs = const [],
  String title = '',
}) =>
    OKRModel(
      id: id,
      objective: title.isEmpty ? 'Objective $id' : title,
      startDate: start,
      deadline: end,
      progress: progress,
      status: status,
      parentObjectiveId: parent,
      level: level,
      order: order,
      createdAt: created,
      keyResults: krs,
    );

final _jan1 = DateTime(2027, 1, 1);
final _jan31 = DateTime(2027, 1, 31);

/// Jan 1 – Jan 31 is 31 whole days, so noon on Jan 16 is exactly half way.
final _half = DateTime(2027, 1, 16, 12);

void main() {
  group('judging an objective against the clock', () {
    OkrPace at(int progress, DateTime now, {OKRStatus status = OKRStatus.inProgress}) =>
        okrPace(_okr('a', start: _jan1, end: _jan31, progress: progress, status: status), now);

    test('half way through, with half done, is on track', () {
      final p = at(50, _half);
      expect(p.expectedPercent, 50);
      expect(p.gap, 0);
      expect(p.health, OkrHealth.onTrack);
    });

    test('behind by more than 10 points is at risk, by more than 25 is off track — and exactly on the line is not', () {
      expect(at(40, _half).health, OkrHealth.onTrack, reason: '10 behind is still fine');
      expect(at(39, _half).health, OkrHealth.atRisk, reason: '11 behind');
      expect(at(25, _half).health, OkrHealth.atRisk, reason: '25 behind');
      expect(at(24, _half).health, OkrHealth.offTrack, reason: '26 behind');
      expect(at(24, _half).gap, 26);
    });

    test('ahead of the line is on track, and says by how much', () {
      final p = at(80, _half);
      expect(p.health, OkrHealth.onTrack);
      expect(p.gap, -30);
      expect(okrPaceNote(p), '30 pts ahead');
    });

    test('finished is done however late; blocked is blocked however early', () {
      expect(at(100, DateTime(2027, 3, 1)).health, OkrHealth.done);
      expect(at(10, _half, status: OKRStatus.completed).health, OkrHealth.done);
      expect(at(90, _half, status: OKRStatus.blocked).health, OkrHealth.blocked);
      expect(at(90, _half, status: OKRStatus.blocked).health.needsAttention, isTrue);
    });

    test('before its start it has not started — unless somebody already made progress', () {
      expect(at(0, DateTime(2026, 12, 20)).health, OkrHealth.notStarted);
      expect(okrPaceNote(at(0, DateTime(2026, 12, 20))), 'starts later');
      expect(at(5, DateTime(2026, 12, 20)).health, OkrHealth.onTrack);
    });

    test('on the deadline day it is not yet overdue; the day after it is, and says for how long', () {
      final onTheDay = at(60, DateTime(2027, 1, 31, 18));
      expect(onTheDay.overdueDays, 0);
      expect(onTheDay.health, OkrHealth.offTrack);

      final late = at(60, DateTime(2027, 2, 5, 9));
      expect(late.health, OkrHealth.offTrack);
      expect(late.overdueDays, 5);
      expect(okrPaceNote(late), 'overdue by 5 days');
      expect(okrPaceNote(at(60, DateTime(2027, 2, 1, 9))), 'overdue by 1 day');
    });

    test('with no dates there is nothing to judge against', () {
      final p = okrPace(_okr('x', progress: 30), _half);
      expect(p.health, OkrHealth.unscheduled);
      expect(p.expected, isNull);
      expect(p.gap, isNull);
      expect(okrPace(_okr('x', status: OKRStatus.notStarted), _half).health, OkrHealth.notStarted);
      expect(okrPace(_okr('x', start: _jan1, progress: 30), _half).health, OkrHealth.unscheduled, reason: 'a start but no deadline');
    });

    test('the sentence beside a bar', () {
      expect(okrPaceNote(at(39, _half)), '11 pts behind');
      expect(okrPaceNote(at(49, _half)), 'on pace', reason: '1 behind is noise');
      expect(okrPaceNote(at(100, _half)), '');
    });

    test('counting objectives by state', () {
      final counts = okrHealthCounts([
        _okr('a', start: _jan1, end: _jan31, progress: 50),
        _okr('b', start: _jan1, end: _jan31, progress: 10),
        _okr('c', start: _jan1, end: _jan31, progress: 100),
        _okr('d', start: _jan1, end: _jan31, status: OKRStatus.blocked),
      ], _half);
      expect(counts[OkrHealth.onTrack], 1);
      expect(counts[OkrHealth.offTrack], 1);
      expect(counts[OkrHealth.done], 1);
      expect(counts[OkrHealth.blocked], 1);
    });
  });

  group('where an objective is drawn', () {
    test('its own dates, whole days', () {
      final s = okrSpan(_okr('a', start: DateTime(2027, 1, 1, 15), end: DateTime(2027, 1, 31, 9)));
      expect(s.start, DateTime(2027, 1, 1));
      expect(s.end, DateTime(2027, 1, 31));
      expect(s.dated, isTrue);
    });

    test('without dates: from when it was created, for 30 days, marked as not really dated', () {
      final s = okrSpan(_okr('a', created: DateTime(2027, 2, 10, 8)));
      expect(s.start, DateTime(2027, 2, 10));
      expect(s.end, DateTime(2027, 3, 12));
      expect(s.dated, isFalse);
    });

    test('a deadline before the start does not draw a backwards bar', () {
      final s = okrSpan(_okr('a', start: DateTime(2027, 3, 10), end: DateTime(2027, 3, 1)));
      expect(s.end, s.start);
    });

    test('the window is a month back to four ahead, stretched to cover everything, in whole months', () {
      final now = DateTime(2027, 6, 15);
      final plain = okrTimelineBounds(const [], now);
      expect(plain.start, DateTime(2027, 5, 1));
      expect(plain.end, DateTime(2027, 10, 31));

      final wide = okrTimelineBounds([_okr('a', start: DateTime(2027, 1, 20), end: DateTime(2028, 2, 3))], now);
      expect(wide.start, DateTime(2027, 1, 1));
      expect(wide.end, DateTime(2028, 2, 29));
    });
  });

  group('key results nobody reports on', () {
    final now = DateTime(2027, 3, 1);
    final running = _okr('a', start: DateTime(2027, 1, 1), end: DateTime(2027, 6, 30), progress: 20);
    KeyResultItem kr({double current = 0, bool done = false, DateTime? last}) => KeyResultItem(
          id: 'k',
          title: 'k',
          currentValue: current,
          completed: done,
          checkIns: [if (last != null) KeyResultCheckIn(value: current, at: last)],
        );

    test('a last report more than 21 days ago is stale; 21 days is not', () {
      expect(krIsStale(running, kr(current: 5, last: now.subtract(const Duration(days: 22))), now), isTrue);
      expect(krIsStale(running, kr(current: 5, last: now.subtract(const Duration(days: 21))), now), isFalse);
      expect(krIsStale(running, kr(current: 5, last: now.subtract(const Duration(days: 2))), now), isFalse);
    });

    test('never reported on: stale if it still stands at zero; a legacy one with a value is not blamed', () {
      expect(krIsStale(running, kr(current: 0), now), isTrue);
      expect(krIsStale(running, kr(current: 7), now), isFalse);
    });

    test('a finished key result, or one on an objective that is not running, is never stale', () {
      expect(krIsStale(running, kr(done: true), now), isFalse);
      expect(krIsStale(_okr('b', start: DateTime(2027, 1, 1), end: DateTime(2027, 6, 30), status: OKRStatus.blocked), kr(), now), isFalse);
      expect(krIsStale(_okr('c', start: DateTime(2027, 1, 1), end: DateTime(2027, 6, 30), status: OKRStatus.completed), kr(), now), isFalse);
    });

    test('an objective that has only just started cannot have stale key results', () {
      final fresh = _okr('d', start: DateTime(2027, 2, 20), end: DateTime(2027, 6, 30));
      expect(krIsStale(fresh, kr(), now), isFalse);
    });

    test('the log is read oldest first, and the last report is the newest', () {
      final k = KeyResultItem.fromJson({
        'id': 'k',
        'title': 'k',
        'checkIns': [
          {'value': 40, 'at': '2027-02-10T10:00:00.000Z', 'by': 'B'},
          {'value': 30, 'at': '2027-01-10T10:00:00.000Z', 'by': 'A'},
        ],
      });
      expect(k.checkIns.map((c) => c.value), [30, 40]);
      expect(k.lastCheckInAt!.toUtc(), DateTime.utc(2027, 2, 10, 10));
      expect(KeyResultItem.fromJson({'id': 'k', 'title': 'k'}).lastCheckInAt, isNull);
    });
  });

  group('the alignment tree', () {
    List<String> ids(List<OkrNode> nodes) => [for (final n in nodes) n.okr.id];

    test('an objective goes under the one it contributes to; the rest are roots', () {
      final roots = buildOkrTree([
        _okr('company', level: 'company'),
        _okr('dept', level: 'department', parent: 'company'),
        _okr('proj', parent: 'dept'),
        _okr('alone'),
      ]);
      expect(ids(roots), ['company', 'alone']);
      expect(ids(roots.first.children), ['dept']);
      expect(ids(roots.first.children.first.children), ['proj']);
      expect(roots.first.children.first.children.first.depth, 2);
    });

    test('a parent that is not in the list (another project\'s, or filtered out) makes it a root', () {
      final roots = buildOkrTree([_okr('a', parent: 'elsewhere')]);
      expect(ids(roots), ['a']);
      expect(roots.single.depth, 0);
    });

    test('roots run company → department → project, then by order, start date, title', () {
      final roots = buildOkrTree([
        _okr('p', level: 'project', start: DateTime(2027, 1, 1)),
        _okr('d', level: 'department', start: DateTime(2027, 2, 1)),
        _okr('c2', level: 'company', start: DateTime(2027, 3, 1)),
        _okr('c1', level: 'company', start: DateTime(2027, 1, 5)),
      ]);
      expect(ids(roots), ['c1', 'c2', 'd', 'p']);
    });

    test('siblings: explicit order first, then earlier start, undated last, then alphabetical', () {
      final roots = buildOkrTree([
        _okr('top'),
        _okr('late', parent: 'top', start: DateTime(2027, 5, 1)),
        _okr('early', parent: 'top', start: DateTime(2027, 1, 1)),
        _okr('undated-b', parent: 'top', title: 'b'),
        _okr('undated-a', parent: 'top', title: 'a'),
        _okr('pinned', parent: 'top', order: -1, start: DateTime(2028, 1, 1)),
      ]);
      expect(ids(roots.single.children), ['pinned', 'early', 'late', 'undated-a', 'undated-b']);
    });

    test('a loop in bad data cannot hang it and nothing is lost', () {
      final roots = buildOkrTree([_okr('a', parent: 'b'), _okr('b', parent: 'a'), _okr('self', parent: 'self')]);
      final all = <String>[];
      void walk(OkrNode n) {
        all.add(n.okr.id);
        n.children.forEach(walk);
      }

      roots.forEach(walk);
      expect(all.toSet(), {'a', 'b', 'self'});
      expect(all.length, 3, reason: 'each exactly once');
    });
  });

  group('the lines of the timeline', () {
    const kr = KeyResultItem(id: 'k1', title: 'Revenue');
    final tree = buildOkrTree([
      _okr('company', level: 'company', krs: const [kr]),
      _okr('dept', level: 'department', parent: 'company'),
      _okr('other', level: 'company'),
    ]);

    String describe(List<OkrRow> rows) => [
          for (final r in rows)
            switch (r) {
              OkrProjectRow() => '[${r.projectName}]',
              OkrObjectiveRow() => '${'-' * r.depth}${r.okr.id}',
              OkrKeyResultRow() => '${'-' * r.depth}kr:${r.kr.id}',
            },
        ].join(' ');

    test('each objective, its key results, then what contributes to it', () {
      expect(describe(okrRows(tree)), 'company kr:k1 -dept other');
    });

    test('grouping by project puts project as main and OKRs under it', () {
      final pRows = okrProjectRows([
        OKRModel(id: 'c1', objective: 'Company Goal', level: 'company'),
        OKRModel(id: 'p1', objective: 'Pan India Goal', projectName: 'Pan Indian Expansion'),
        OKRModel(id: 'p2', objective: 'ERP Task', projectName: 'ERP'),
      ]);
      expect(describe(pRows), '[Company Initiatives] -c1 [ERP] -p2 [Pan Indian Expansion] -p1');
    });

    test('a collapsed objective hides its key results and everything under it', () {
      expect(describe(okrRows(tree, collapsed: {'company'})), 'company other');
      final row = okrRows(tree, collapsed: {'company'}).first as OkrObjectiveRow;
      expect(row.collapsed, isTrue);
      expect(row.expandable, isTrue);
    });

    test('an objective with nothing under it is not expandable', () {
      final leaf = okrRows(tree).whereType<OkrObjectiveRow>().firstWhere((r) => r.okr.id == 'other');
      expect(leaf.expandable, isFalse);
    });
  });

  group('the level of an objective', () {
    test('the server\'s word wins; older ones are read the old way', () {
      expect(OKRModel(id: 'a', objective: 'x', level: 'department', department: 'company').effectiveLevel, 'department');
      expect(OKRModel(id: 'a', objective: 'x', projectId: 'p1').effectiveLevel, 'project');
      expect(OKRModel(id: 'a', objective: 'x', department: 'Company').effectiveLevel, 'company');
      expect(OKRModel(id: 'a', objective: 'x', department: 'research-and-development').effectiveLevel, 'company');
      expect(OKRModel(id: 'a', objective: 'x', department: 'Marketing').effectiveLevel, 'department');
    });

    test('what the caller may do: from the server, or unrestricted when it says nothing', () {
      expect(OKRModel.fromJson({'_id': 'a', 'objective': 'x'}).access.canManage, isTrue);
      final locked = OKRModel.fromJson({'_id': 'a', 'objective': 'x', 'access': {'canManage': false, 'canCheckIn': true}}).access;
      expect([locked.canManage, locked.canCheckIn], [false, true]);
    });
  });
}
