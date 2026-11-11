import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/wbs_rows.dart';

// What the WBS tab lists and counts: the strip's numbers, Tree / Table rows, search, filter, and what an export holds.

ITTask _t(
  String id,
  String title, {
  String? parent,
  int order = 0,
  int pct = 0,
  String owner = '',
  String ownerName = '',
  ITTaskStatus status = ITTaskStatus.todo,
  DateTime? start,
  DateTime? due,
}) =>
    ITTask(
      id: id,
      projectId: 'p1',
      title: title,
      parentTaskId: parent,
      order: order,
      percentComplete: pct,
      assigneeId: owner,
      assigneeName: ownerName,
      status: status,
      startDate: start,
      dueDate: due,
    );

// 1 Discovery (1.1 Requirements, 1.2 Alignment) · 2 Sourcing (2.1 Vendors) · 3 Launch
List<ITTask> _plan() => [
      _t('p1', 'Discovery & Planning', order: 1, start: DateTime(2026, 11, 5), due: DateTime(2026, 11, 8)),
      _t('t11', 'Requirements & Scope Approval', parent: 'p1', order: 1, owner: 'e1', ownerName: 'Adithya', pct: 100, status: ITTaskStatus.closed),
      _t('t12', 'Stakeholder Alignment', parent: 'p1', order: 2, owner: 'e2', ownerName: 'Amna', status: ITTaskStatus.inProgress, pct: 50),
      _t('p2', 'Sourcing & Procurement', order: 2),
      _t('t21', 'Vendor Contracts & Orders', parent: 'p2', order: 1, owner: 'e1', ownerName: 'Adithya'),
      _t('p3', 'Launch & Handoff', order: 3),
    ];

List<String> _ids(List<WbsRow> rows) => [for (final r in rows) r.node.task.id];

void main() {
  final tasks = _plan();
  final forest = buildWbsForest(tasks);

  group('the strip', () {
    test('phases are the top-level items, tasks everything under them, and the rest follows', () {
      final s = wbsSummary(tasks, forest);
      expect(s.phases, 3);
      expect(s.tasks, 3);
      expect(s.total, 6);
      expect(s.completed, 1); // only the closed one (a phase is not "completed" by being at 0%)
      expect(s.remaining, 5);
    });

    test('overall progress is the average of the leaf tasks, not of the phases', () {
      // leaves: t11 100, t12 50, t21 0, p3 0 → 37.5 → 38
      expect(wbsSummary(tasks, forest).overall, 38);
    });

    test('no tasks at all: zeros, no divide-by-zero', () {
      final s = wbsSummary(const [], buildWbsForest(const []));
      expect([s.phases, s.tasks, s.total, s.completed, s.remaining, s.overall], [0, 0, 0, 0, 0, 0]);
    });

    test('a task that is 100% done counts as completed whatever its status', () {
      final done = [_t('a', 'A', pct: 100), _t('b', 'B')];
      expect(wbsSummary(done, buildWbsForest(done)).completed, 1);
    });

    test('a task with closed or deployed status counts as 100% in rollup even if pct is 0', () {
      final doneStatus = [_t('a', 'A', status: ITTaskStatus.closed, pct: 0), _t('b', 'B', pct: 0)];
      final f = buildWbsForest(doneStatus);
      expect(wbsSummary(doneStatus, f).completed, 1);
      expect(wbsSummary(doneStatus, f).overall, 50); // (100 + 0) / 2 = 50
      expect(rolledUpPercent(f.first), 100);
    });
  });

  group('Tree', () {
    test('every phase with its tasks, in order, with who is last among its siblings', () {
      final rows = wbsRows(forest, tree: true);
      expect(_ids(rows), ['p1', 't11', 't12', 'p2', 't21', 'p3']);
      expect(rows.map((r) => r.node.wbs), ['1', '1.1', '1.2', '2', '2.1', '3']);
      expect(rows.map((r) => r.isLast), [false, false, true, false, true, true]);
      expect(rows.map((r) => r.phase), [0, 0, 0, 1, 1, 2]);
      expect(rows.map((r) => r.hasChildren), [true, false, false, true, false, false]);
      expect(rows.where((r) => r.hasChildren).every((r) => r.open), isTrue);
    });

    test('a folded phase hides its tasks and says it is closed', () {
      final rows = wbsRows(forest, tree: true, collapsed: {'p1'});
      expect(_ids(rows), ['p1', 'p2', 't21', 'p3']);
      expect(rows.first.hasChildren, isTrue);
      expect(rows.first.open, isFalse);
    });

    test('a task with sub-tasks of its own folds too, and its connector level is its depth', () {
      final deep = [..._plan(), _t('t111', 'Sub-task', parent: 't11', order: 1)];
      final f = buildWbsForest(deep);
      expect(_ids(wbsRows(f, tree: true)), ['p1', 't11', 't111', 't12', 'p2', 't21', 'p3']);
      expect(_ids(wbsRows(f, tree: true, collapsed: {'t11'})), ['p1', 't11', 't12', 'p2', 't21', 'p3']);
      expect(wbsRows(f, tree: true).firstWhere((r) => r.node.task.id == 't111').node.depth, 2);
    });
  });

  group('Table', () {
    test('a flat list of every item in work-breakdown order, nothing folded or connected', () {
      final rows = wbsRows(forest, tree: false, collapsed: {'p1'}); // folding is a Tree thing
      expect(_ids(rows), ['p1', 't11', 't12', 'p2', 't21', 'p3']);
      expect(rows.every((r) => !r.hasChildren && !r.open && !r.isLast), isTrue);
      expect(rows.map((r) => r.phase), [0, 0, 0, 1, 1, 2]);
    });

    test('search and filter list only the items that match — no phases kept for company', () {
      expect(_ids(wbsRows(forest, tree: false, query: 'vendor')), ['t21']);
    });
  });

  group('search', () {
    test('looks in the title, the owner and the WBS number, ignoring case and spaces around it', () {
      expect(_ids(wbsRows(forest, tree: false, query: '  STAKEHOLDER ')), ['t12']);
      expect(_ids(wbsRows(forest, tree: false, query: 'amna')), ['t12']);
      expect(_ids(wbsRows(forest, tree: false, query: '2.1')), ['t21']);
      expect(_ids(wbsRows(forest, tree: false, query: 'nothing like this')), isEmpty);
      expect(_ids(wbsRows(forest, tree: false, query: '   ')), hasLength(6)); // blank = no search
    });

    test('Tree: a match keeps the phase above it, held open even if it was folded; non-matching siblings go', () {
      final rows = wbsRows(forest, tree: true, query: 'stakeholder', collapsed: {'p1'});
      expect(_ids(rows), ['p1', 't12']);
      expect(rows.first.open, isTrue);
      expect(rows.last.isLast, isTrue);
    });

    test('Tree: a phase that matches on its own is listed, with only the tasks that match under it', () {
      final rows = wbsRows(forest, tree: true, query: 'discovery');
      expect(_ids(rows), ['p1']);
    });
  });

  group('filter', () {
    test('by status', () {
      final f = const WbsFilter(statuses: {ITTaskStatus.inProgress});
      expect(_ids(wbsRows(forest, tree: false, filter: f)), ['t12']);
      expect(_ids(wbsRows(forest, tree: true, filter: f)), ['p1', 't12']);
    });

    test('several statuses at once', () {
      final f = const WbsFilter(statuses: {ITTaskStatus.inProgress, ITTaskStatus.closed});
      expect(_ids(wbsRows(forest, tree: false, filter: f)), ['t11', 't12']);
    });

    test('by owner, and "unassigned"', () {
      expect(_ids(wbsRows(forest, tree: false, filter: const WbsFilter(owner: 'e1'))), ['t11', 't21']);
      expect(_ids(wbsRows(forest, tree: false, filter: const WbsFilter(owner: kWbsUnassigned))), ['p1', 'p2', 'p3']);
    });

    test('filter and search together narrow it further', () {
      expect(_ids(wbsRows(forest, tree: false, query: 'vendor', filter: const WbsFilter(owner: 'e2'))), isEmpty);
      expect(_ids(wbsRows(forest, tree: false, query: 'vendor', filter: const WbsFilter(owner: 'e1'))), ['t21']);
    });

    test('how many things are narrowed, for the badge', () {
      expect(const WbsFilter().isActive, isFalse);
      expect(const WbsFilter().count, 0);
      expect(const WbsFilter(owner: 'e1').count, 1);
      expect(const WbsFilter(statuses: {ITTaskStatus.todo}, owner: 'e1').count, 2);
    });
  });

  group('export and durations', () {
    test('an export lists everything that matches, phases included, with the work-breakdown numbers', () {
      final rows = wbsExportRows(forest);
      expect(rows.map((r) => r[0]), ['1', '1.1', '1.2', '2', '2.1', '3']);
      expect(rows.first, ['1', 'Discovery & Planning', '', '5/11/26', '8/11/26', 3, 75, 'To Do']); // its own %: the average of 1.1 (100) and 1.2 (50)
      expect(rows[1], ['1.1', 'Requirements & Scope Approval', 'Adithya', '—', '—', '', 100, 'Done']); // a company project's word for closed
      expect(wbsExportHeaders.length, rows.first.length);
    });

    test('…whatever is folded on screen, and narrowed by the search and filter', () {
      expect(wbsExportRows(forest, query: 'amna').map((r) => r[0]), ['1', '1.2']);
      expect(wbsExportRows(forest, filter: const WbsFilter(owner: 'e1')).map((r) => r[0]), ['1', '1.1', '2', '2.1']);
    });

    test('status words follow the kind of project', () {
      final inReview = [_t('a', 'A', status: ITTaskStatus.codeReview)];
      final f = buildWbsForest(inReview);
      expect(wbsExportRows(f, isIt: true).single.last, 'Code Review');
      expect(wbsExportRows(f).single.last, 'In Review');
    });

    test('durations read "3 days", "1 day", or a dash', () {
      expect(durationText(_t('a', 'A', start: DateTime(2026, 11, 5), due: DateTime(2026, 11, 8))), '3 days');
      expect(durationText(_t('a', 'A', start: DateTime(2026, 11, 5), due: DateTime(2026, 11, 6))), '1 day');
      expect(durationText(_t('a', 'A')), '—');
    });
  });
}
