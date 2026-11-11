import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/domain/okr_scorecard.dart';
import 'package:nizan_crm/features/it/domain/okr_tree_layout.dart';

// The OKR alignment map (where each card goes, what rolls up) and the scorecard (how objectives add
// up by department / owner / level / project, and what needs somebody).

OKRModel _okr(
  String id, {
  String level = 'project',
  String? parent,
  DateTime? start,
  DateTime? end,
  int progress = 0,
  OKRStatus status = OKRStatus.inProgress,
  String department = '',
  String owner = '',
  String project = '',
  String projectDept = '',
  List<KeyResultItem> krs = const [],
  String? title,
  int order = 0,
}) =>
    OKRModel(
      id: id,
      objective: title ?? 'Objective $id',
      level: level,
      parentObjectiveId: parent,
      startDate: start,
      deadline: end,
      progress: progress,
      status: status,
      department: department,
      projectHeadName: owner,
      projectName: project,
      projectDepartment: projectDept,
      keyResults: krs,
      order: order,
      createdAt: DateTime(2027, 1, 1),
    );

/// Jan 1 – Jan 31, noon on Jan 16 is half way: expected 50%.
final _jan1 = DateTime(2027, 1, 1);
final _jan31 = DateTime(2027, 1, 31);
final _now = DateTime(2027, 1, 16, 12);

OKRModel _dated(String id, int progress, {OKRStatus status = OKRStatus.inProgress, String level = 'project', String department = '', String owner = '', String project = '', String projectDept = '', List<KeyResultItem> krs = const []}) =>
    _okr(id, start: _jan1, end: _jan31, progress: progress, status: status, level: level, department: department, owner: owner, project: project, projectDept: projectDept, krs: krs);

void main() {
  group('the alignment map', () {
    const m = OkrTreeMetrics(); // 300 x 120, gaps 64 / 14, padding 16
    double col(int depth) => 16 + depth * 364.0;
    double row(num r) => 16 + r * 134.0;

    test('objectives with nothing under them stack, one row each, in the first column', () {
      final l = layoutOkrTree(buildOkrTree([_okr('a'), _okr('b'), _okr('c')]));
      expect([for (final n in l.nodes) (n.x, n.y)], [(col(0), row(0)), (col(0), row(1)), (col(0), row(2))]);
      expect(l.width, 16 * 2 + 300);
      expect(l.height, 16 * 2 + 3 * 120 + 2 * 14);
    });

    test('what feeds an objective goes one column to the right, and the parent sits level with the middle of them', () {
      final l = layoutOkrTree(buildOkrTree([
        _okr('c', level: 'company'),
        _okr('d1', level: 'department', parent: 'c'),
        _okr('d2', level: 'department', parent: 'c'),
        _okr('d3', level: 'department', parent: 'c'),
      ]));
      final at = {for (final n in l.nodes) n.node.okr.id: n};
      expect(at['d1']!.x, col(1));
      expect([at['d1']!.y, at['d2']!.y, at['d3']!.y], [row(0), row(1), row(2)]);
      expect(at['c']!.x, col(0));
      expect(at['c']!.y, row(1), reason: 'level with the middle child');
      expect(l.width, 16 * 2 + 2 * 300 + 64);
    });

    test('an even number of children centres between the two in the middle', () {
      final l = layoutOkrTree(buildOkrTree([_okr('c'), _okr('a', parent: 'c'), _okr('b', parent: 'c')]));
      expect(l.byId('c')!.y, row(0.5));
    });

    test('three levels: company → department → project, each a column further right; the next root starts below', () {
      final l = layoutOkrTree(buildOkrTree([
        _okr('c', level: 'company'),
        _okr('d', level: 'department', parent: 'c'),
        _okr('p1', parent: 'd'),
        _okr('p2', parent: 'd'),
        _okr('c2', level: 'company', start: DateTime(2028)),
      ]));
      final at = {for (final n in l.nodes) n.node.okr.id: n};
      expect([at['c']!.x, at['d']!.x, at['p1']!.x], [col(0), col(1), col(2)]);
      expect(at['p1']!.y, row(0));
      expect(at['p2']!.y, row(1));
      expect(at['d']!.y, row(0.5));
      expect(at['c']!.y, row(0.5), reason: 'one child: level with it');
      expect(at['c2']!.y, row(2));
      expect(l.width, 16 * 2 + 3 * 300 + 2 * 64);
    });

    test('parents come before what is under them, and each card knows its parent', () {
      final l = layoutOkrTree(buildOkrTree([_okr('c'), _okr('d', parent: 'c'), _okr('p', parent: 'd')]));
      expect([for (final n in l.nodes) n.node.okr.id], ['c', 'd', 'p']);
      expect([for (final n in l.nodes) n.parentId], [null, 'c', 'd']);
    });

    test('a folded objective is one card, and its row is not held open by what it hides', () {
      final tree = buildOkrTree([_okr('c'), _okr('a', parent: 'c'), _okr('b', parent: 'c'), _okr('other')]);
      final l = layoutOkrTree(tree, collapsed: {'c'});
      expect([for (final n in l.nodes) n.node.okr.id], ['c', 'other']);
      final c = l.byId('c')!;
      expect(c.collapsed, isTrue);
      expect(c.hasChildren, isTrue);
      expect(c.y, row(0));
      expect(l.byId('other')!.y, row(1));
      expect(l.width, 16 * 2 + 300, reason: 'no second column while it is folded');
    });

    test('folding something with no children does nothing; nothing at all is an empty map', () {
      final l = layoutOkrTree(buildOkrTree([_okr('a')]), collapsed: {'a'});
      expect(l.byId('a')!.collapsed, isFalse);
      final none = layoutOkrTree(const []);
      expect([none.nodes.length, none.width, none.height], [0, 0, 0]);
    });

    test('the metrics can be changed', () {
      const small = OkrTreeMetrics(nodeWidth: 100, nodeHeight: 50, gapX: 10, gapY: 5, padding: 0);
      final l = layoutOkrTree(buildOkrTree([_okr('c'), _okr('a', parent: 'c'), _okr('b', parent: 'c')]), metrics: small);
      expect(l.byId('b')!.x, 110);
      expect(l.byId('b')!.y, 55);
      expect([l.width, l.height], [210, 105]);
      expect(m.nodeHeight, 120);
    });

    test('every objective with something under it can be found (for "collapse all"), the others cannot', () {
      final tree = buildOkrTree([_okr('c'), _okr('d', parent: 'c'), _okr('p', parent: 'd'), _okr('x')]);
      expect(okrIdsWithChildren(tree), {'c', 'd'});
    });

    test('the narrow list is the same tree top to bottom, with folded branches skipped', () {
      final tree = buildOkrTree([_okr('c'), _okr('d', parent: 'c'), _okr('p', parent: 'd'), _okr('x')]);
      expect([for (final n in listOkrNodes(tree)) '${n.depth}:${n.node.okr.id}'], ['0:c', '1:d', '2:p', '0:x']);
      final folded = listOkrNodes(tree, collapsed: {'d'});
      expect([for (final n in folded) n.node.okr.id], ['c', 'd', 'x']);
      expect(folded[1].collapsed, isTrue);
      expect(folded[1].hasChildren, isTrue);
    });
  });

  group('what rolls up', () {
    test('the average of what feeds an objective directly, beside its own progress', () {
      final tree = buildOkrTree([
        _okr('c', level: 'company', progress: 90),
        _okr('a', parent: 'c', progress: 20),
        _okr('b', parent: 'c', progress: 61),
      ]);
      final below = okrBelow(tree.single, _now);
      expect(below.fedBy, 2);
      expect(below.total, 2);
      expect(below.rollup, 41, reason: '(20 + 61) / 2 = 40.5, rounded');
      expect(tree.single.okr.progress, 90, reason: 'its own number is untouched');
    });

    test('only the direct children count towards the average, but everything beneath counts for health', () {
      final tree = buildOkrTree([
        _dated('c', 50, level: 'company'),
        _okr('d', level: 'department', parent: 'c', progress: 80, start: _jan1, end: _jan31),
        _okr('p', parent: 'd', progress: 0, start: _jan1, end: _jan31), // off track
        _okr('q', parent: 'd', progress: 100, status: OKRStatus.completed),
      ]);
      final below = okrBelow(tree.single, _now);
      expect(below.fedBy, 1);
      expect(below.total, 3);
      expect(below.rollup, 80);
      expect(below.health[OkrHealth.offTrack], 1);
      expect(below.health[OkrHealth.done], 1);
      expect(below.attention, 1 + 0, reason: 'd is on track (80 vs 50), p is off track');
    });

    test('nothing under it: no roll-up', () {
      final below = okrBelow(buildOkrTree([_okr('a')]).single, _now);
      expect([below.fedBy, below.total, below.rollup, below.attention], [0, 0, null, 0]);
    });
  });

  group('adding objectives up', () {
    test('a department line: company-wide ones together, department ones by name, project ones by their project\'s department', () {
      expect(okrGroupName(_okr('a', level: 'company'), OkrGroupBy.department), 'Company-wide');
      expect(okrGroupName(_okr('a', level: 'department', department: 'Marketing'), OkrGroupBy.department), 'Marketing');
      expect(okrGroupName(_okr('a', level: 'department'), OkrGroupBy.department), 'No department');
      expect(okrGroupName(_okr('a', projectDept: 'Finance'), OkrGroupBy.department), 'Finance');
      expect(okrGroupName(_okr('a'), OkrGroupBy.department), 'Unassigned department');
    });

    test('by owner, level and project', () {
      expect(okrGroupName(_okr('a', owner: ' Mira Nair '), OkrGroupBy.owner), 'Mira Nair');
      expect(okrGroupName(_okr('a'), OkrGroupBy.owner), 'Nobody named');
      expect([for (final l in ['company', 'department', 'project']) okrGroupName(_okr('a', level: l), OkrGroupBy.level)], ['Company', 'Department', 'Project']);
      expect(okrGroupName(_okr('a', project: 'Diwali'), OkrGroupBy.project), 'Diwali');
      expect(okrGroupName(_okr('a'), OkrGroupBy.project), 'Unnamed project');
      expect(okrGroupName(_okr('a', level: 'company'), OkrGroupBy.project), 'Not tied to a project');
    });

    test('a line counts its objectives by state, averages their progress, and says what is overdue', () {
      final sc = buildOkrScorecard([
        _dated('a', 50, owner: 'Mira'), // on track
        _dated('b', 10, owner: 'Mira'), // off track
        _okr('c', start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 20), progress: 60, owner: 'Mira'), // overdue
        _dated('d', 100, owner: 'Mira', status: OKRStatus.completed),
      ], _now, OkrGroupBy.owner);
      final g = sc.groups.single;
      expect(g.name, 'Mira');
      expect(g.okrs.length, 4);
      expect(g.count(OkrHealth.onTrack), 1);
      expect(g.count(OkrHealth.offTrack), 2, reason: 'one behind, one overdue');
      expect(g.count(OkrHealth.done), 1);
      expect(g.avgProgress, 55, reason: '(50 + 10 + 60 + 100) / 4 = 55');
      expect(g.overdue, 1);
      expect(g.attention, 2);
    });

    test('the share that is healthy leaves out what cannot be judged', () {
      final sc = buildOkrScorecard([
        _dated('a', 50), // on track
        _dated('b', 100, status: OKRStatus.completed), // done
        _dated('c', 35), // at risk (15 behind)
        _dated('d', 0, status: OKRStatus.blocked),
        _okr('e'), // no dates
        _okr('f', start: DateTime(2027, 6, 1), end: DateTime(2027, 9, 1)), // not started
      ], _now, OkrGroupBy.level);
      expect(sc.overall.healthyPercent, 50, reason: '2 of the 4 that can be judged');
      expect(buildOkrScorecard([_okr('e')], _now, OkrGroupBy.level).overall.healthyPercent, isNull);
    });

    test('the next deadline skips what is finished or already past', () {
      final sc = buildOkrScorecard([
        _okr('past', start: DateTime(2026, 11, 1), end: DateTime(2026, 12, 1), progress: 10),
        _okr('done', start: _jan1, end: DateTime(2027, 1, 17), progress: 100, status: OKRStatus.completed),
        _okr('soon', start: _jan1, end: DateTime(2027, 2, 5), progress: 10),
        _okr('later', start: _jan1, end: DateTime(2027, 3, 5), progress: 10),
        _okr('today', start: _jan1, end: DateTime(2027, 1, 16, 9), progress: 10),
      ], _now, OkrGroupBy.level);
      expect(sc.overall.nextDue, DateTime(2027, 1, 16));
      expect(buildOkrScorecard([_okr('x')], _now, OkrGroupBy.level).overall.nextDue, isNull);
    });

    test('key results are counted, and the ones nobody reports on are counted apart', () {
      final started = _okr('a', start: DateTime(2026, 12, 1), end: DateTime(2027, 4, 1), progress: 10, krs: const [
        KeyResultItem(id: 'k1', title: 'quiet', targetValue: 10),
        KeyResultItem(id: 'k2', title: 'has a value', targetValue: 10, currentValue: 4),
        KeyResultItem(id: 'k3', title: 'done', completed: true),
      ]);
      final g = buildOkrScorecard([started], _now, OkrGroupBy.level).overall;
      expect(g.keyResults, 3);
      expect(g.staleKeyResults, 1);
    });

    test('lines run worst first — most needing attention, then lowest progress, then name', () {
      final sc = buildOkrScorecard([
        _dated('a1', 50, owner: 'Calm'),
        _dated('b1', 5, owner: 'Trouble'),
        _dated('b2', 5, owner: 'Trouble'),
        _dated('c1', 5, owner: 'Some trouble'),
        _dated('d1', 60, owner: 'Alpha'),
        _dated('e1', 60, owner: 'Beta'),
      ], _now, OkrGroupBy.owner);
      expect([for (final g in sc.groups) g.name], ['Trouble', 'Some trouble', 'Calm', 'Alpha', 'Beta']);
    });

    test('by level the lines keep company → department → project, whatever the state', () {
      final sc = buildOkrScorecard([_dated('p', 0), _dated('c', 90, level: 'company'), _dated('d', 50, level: 'department', department: 'X')], _now, OkrGroupBy.level);
      expect([for (final g in sc.groups) g.name], ['Company', 'Department', 'Project']);
    });

    test('nothing at all adds up to nothing', () {
      final sc = buildOkrScorecard(const [], _now, OkrGroupBy.department);
      expect(sc.groups, isEmpty);
      expect([sc.overall.avgProgress, sc.overall.attention, sc.attention.length, sc.stale.length], [0, 0, 0, 0]);
    });
  });

  group('what needs somebody', () {
    test('objectives in trouble: longest overdue, then furthest behind off track, then blocked, then at risk', () {
      final sc = buildOkrScorecard([
        _okr('overdue2', start: DateTime(2026, 12, 1), end: DateTime(2027, 1, 14), progress: 10, title: 'overdue 2 days'),
        _okr('overdue10', start: DateTime(2026, 12, 1), end: DateTime(2027, 1, 6), progress: 10, title: 'overdue 10 days'),
        _dated('off', 20), // 30 behind
        _dated('offer', 10), // 40 behind
        _dated('blocked', 0, status: OKRStatus.blocked),
        _dated('risk', 36), // 14 behind
        _dated('riskier', 30), // 20 behind
        _dated('fine', 55),
      ], _now, OkrGroupBy.level);
      expect([for (final a in sc.attention) a.okr.id], ['overdue10', 'overdue2', 'offer', 'off', 'blocked', 'riskier', 'risk']);
    });

    test('key results that need a check-in: never reported on first, then the longest quiet', () {
      OKRModel okr(String id, List<KeyResultCheckIn> log, {double value = 0}) => _okr(id, start: DateTime(2026, 11, 1), end: DateTime(2027, 6, 1), progress: 10, krs: [
            KeyResultItem(id: 'k$id', title: 'kr $id', targetValue: 10, currentValue: value, checkIns: log),
          ]);
      final sc = buildOkrScorecard([
        okr('recent', [KeyResultCheckIn(value: 3, at: DateTime(2027, 1, 10))], value: 3), // 6 days: fine
        okr('old', [KeyResultCheckIn(value: 3, at: DateTime(2026, 12, 1))], value: 3),
        okr('older', [KeyResultCheckIn(value: 3, at: DateTime(2026, 11, 20))], value: 3),
        okr('never', const []),
      ], _now, OkrGroupBy.level);
      expect([for (final s in sc.stale) s.okr.id], ['never', 'older', 'old']);
      expect(sc.stale.first.lastCheckIn, isNull);
    });
  });
}
