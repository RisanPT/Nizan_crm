import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_okr_timeline.dart';

// The OKR timeline: the alignment tree, what each person can do from it, dragging a bar, and
// the phone list. The judgement itself (on track / at risk …) is in okr_pace_test.dart.

/// "Today" for every test: Feb 15 2027, noon.
final _now = DateTime(2027, 2, 15, 12);

OKRModel _okr(
  String id,
  String title, {
  String level = 'project',
  String? parent,
  DateTime? start,
  DateTime? end,
  int progress = 0,
  OKRStatus status = OKRStatus.inProgress,
  List<KeyResultItem> krs = const [],
  OKRAccess access = OKRAccess.unrestricted,
  String owner = '',
  String project = '',
}) =>
    OKRModel(
      id: id,
      objective: title,
      level: level,
      parentObjectiveId: parent,
      startDate: start,
      deadline: end,
      progress: progress,
      status: status,
      keyResults: krs,
      access: access,
      projectHeadName: owner,
      projectName: project,
      department: level == 'department' ? 'Marketing' : 'company',
      createdAt: DateTime(2027, 1, 1),
    );

/// company ← department ← project, plus one with no dates:
///   Grow bridal revenue (Jan 1 – Mar 31, 65%)           on track
///   └ Cut cost per lead (Feb 1 – Apr 30, 5%)            at risk
///     └ Launch landing pages (Jan 25 – Feb 28, 0%)      off track, with a key result nobody reported on
///   Loose idea (no dates)                               no dates
List<OKRModel> _fixtures({OKRAccess access = OKRAccess.unrestricted}) => [
      _okr(
        'c',
        'Grow bridal revenue',
        level: 'company',
        start: DateTime(2027, 1, 1),
        end: DateTime(2027, 3, 31),
        progress: 65,
        owner: 'Mira Nair',
        access: access,
        krs: [
          KeyResultItem(
            id: 'k1',
            title: 'Revenue',
            targetValue: 100,
            currentValue: 30,
            unit: 'L',
            checkIns: [
              KeyResultCheckIn(value: 10, at: DateTime(2027, 1, 20), by: 'Mira'),
              KeyResultCheckIn(value: 30, at: DateTime(2027, 2, 5), by: 'Mira'),
            ],
          ),
          const KeyResultItem(id: 'k2', title: 'Conversion', targetValue: 25, currentValue: 25, completed: true),
        ],
      ),
      _okr('d', 'Cut cost per lead', level: 'department', parent: 'c', start: DateTime(2027, 2, 1), end: DateTime(2027, 4, 30), progress: 5, access: access),
      _okr(
        'p',
        'Launch landing pages',
        parent: 'd',
        start: DateTime(2027, 1, 25),
        end: DateTime(2027, 2, 28),
        access: access,
        project: 'Diwali',
        krs: const [KeyResultItem(id: 'k3', title: 'Pages live', targetValue: 10)],
      ),
      _okr('u', 'Loose idea', level: 'company', access: access),
    ];

class _Calls {
  final checkIns = <String>[];
  final shifted = <String>[];
  final edited = <String>[];
  final addedUnder = <String>[];
}

Future<_Calls> _pump(
  WidgetTester tester,
  List<OKRModel> okrs, {
  double width = 1200,
  bool Function(OKRModel)? canAddUnder,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = _Calls();
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: ITOkrTimeline(
        okrs: okrs,
        now: _now,
        onEditOkr: (o) => calls.edited.add(o.id),
        onCheckInKeyResult: (o, kr) => calls.checkIns.add('${o.id}/${kr.id}'),
        onAddChild: (o) => calls.addedUnder.add(o.id),
        canAddUnder: canAddUnder,
        onChangeDates: (o, s, e) async => calls.shifted.add('${o.id} ${_d(s)} → ${_d(e)}'),
        onDelete: (_) {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return calls;
}

/// The timeline opens scrolled to today, which tucks bars that started earlier under the left
/// pane; the drag tests scroll back to the start so every bar (and its ends) can be reached.
Future<void> _scrollToStart(WidgetTester tester) async {
  final horizontal = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right);
  tester.state<ScrollableState>(horizontal.first).position.jumpTo(0);
  await tester.pumpAndSettle();
}

String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Finder _bar(String title) => find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith('$title\n'));

/// Drag from the middle of [finder] by exactly [dx] after the touch slop has been used up, so the
/// bar sees a drag of [dx] (a plain tester.drag counts the slop inside the distance).
Future<void> _dragBy(WidgetTester tester, Offset from, double dx) async {
  final g = await tester.startGesture(from);
  await g.moveBy(const Offset(30, 0)); // past the slop: the drag is recognised here
  await tester.pump();
  await g.moveBy(Offset(dx, 0));
  await tester.pump();
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  group('the alignment tree', () {
    testWidgets('company, then the department that feeds it, then the project objective — each indented under its parent', (tester) async {
      await _pump(tester, _fixtures());
      final x = {for (final t in ['Grow bridal revenue', 'Cut cost per lead', 'Launch landing pages']) t: tester.getTopLeft(find.text(t)).dx};
      expect(x['Cut cost per lead']! > x['Grow bridal revenue']!, isTrue);
      expect(x['Launch landing pages']! > x['Cut cost per lead']!, isTrue);

      final y = {for (final t in ['Grow bridal revenue', 'Cut cost per lead', 'Launch landing pages', 'Loose idea']) t: tester.getTopLeft(find.text(t)).dy};
      expect(y['Grow bridal revenue']! < y['Cut cost per lead']!, isTrue);
      expect(y['Cut cost per lead']! < y['Launch landing pages']!, isTrue);
      expect(y['Launch landing pages']! < y['Loose idea']!, isTrue, reason: 'the unrelated one comes after the whole tree above it');
    });

    testWidgets('each objective shows its level, and key results sit under their objective', (tester) async {
      await _pump(tester, _fixtures());
      expect(find.text('C'), findsWidgets);
      expect(find.text('D'), findsWidgets);
      expect(find.text('P'), findsWidgets);
      expect(find.text('Revenue'), findsOneWidget);
      expect(find.text('Pages live'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Revenue')).dy > tester.getTopLeft(find.text('Grow bridal revenue')).dy, isTrue);
    });

    testWidgets('collapsing an objective hides its key results and everything that contributes to it', (tester) async {
      await _pump(tester, _fixtures());
      final chevron = find.descendant(of: find.ancestor(of: find.text('Grow bridal revenue'), matching: find.byType(InkWell)).first, matching: find.byIcon(Icons.arrow_drop_down)).first;
      await tester.tap(chevron);
      await tester.pumpAndSettle();
      expect(find.text('Revenue'), findsNothing);
      expect(find.text('Cut cost per lead'), findsNothing);
      expect(find.text('Launch landing pages'), findsNothing);
      expect(find.text('Grow bridal revenue'), findsOneWidget);
      expect(find.text('Loose idea'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_right).first);
      await tester.pumpAndSettle();
      expect(find.text('Cut cost per lead'), findsOneWidget);
    });
  });

  group('how each objective is doing', () {
    testWidgets('the chips count objectives by state, and tapping one narrows the timeline to them', (tester) async {
      await _pump(tester, _fixtures());
      expect(find.text('On track  1'), findsOneWidget);
      expect(find.text('At risk  1'), findsOneWidget);
      expect(find.text('Off track  1'), findsOneWidget);
      expect(find.text('No dates  1'), findsOneWidget);

      await tester.tap(find.text('Off track  1'));
      await tester.pumpAndSettle();
      expect(find.text('Launch landing pages'), findsOneWidget);
      expect(find.text('Grow bridal revenue'), findsNothing);
      expect(find.text('Loose idea'), findsNothing);

      // two at once
      await tester.tap(find.text('At risk  1'));
      await tester.pumpAndSettle();
      expect(find.text('Cut cost per lead'), findsOneWidget);
      expect(find.text('Launch landing pages'), findsOneWidget);

      // and off again
      await tester.tap(find.text('Off track  1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('At risk  1'));
      await tester.pumpAndSettle();
      expect(find.text('Grow bridal revenue'), findsOneWidget);
    });

    testWidgets('a bar says how it is doing beside it', (tester) async {
      await _pump(tester, _fixtures());
      expect(find.textContaining('Off track · '), findsWidgets);
      expect(find.textContaining('pts behind'), findsWidgets);
    });

    testWidgets('a key result nobody has reported on is flagged', (tester) async {
      await _pump(tester, _fixtures());
      // Pages live: 0 of 10, no reports, on an objective running for 3 weeks
      expect(find.byIcon(Icons.schedule), findsWidgets);
    });

    testWidgets('filters that match nothing say so and can be cleared', (tester) async {
      await _pump(tester, _fixtures());
      // the only off-track objective is a project one; ask for department objectives too
      await tester.tap(find.text('Off track  1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All levels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Department objective').last);
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches these filters'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches these filters'), findsNothing);
      expect(find.text('Grow bridal revenue'), findsOneWidget);
      expect(find.text('Launch landing pages'), findsOneWidget);
    });
  });

  group('the detail', () {
    testWidgets('tapping an objective opens where it stands against the calendar, and its key results', (tester) async {
      await _pump(tester, _fixtures());
      await tester.tap(_bar('Launch landing pages'));
      await tester.pumpAndSettle();

      expect(find.text('Key results'), findsOneWidget);
      expect(find.textContaining('should be at'), findsOneWidget);
      expect(find.text('Off track'), findsWidgets);
      expect(find.text('Pages live'), findsWidgets);
      expect(find.textContaining('no reports yet'), findsOneWidget);
      expect(find.textContaining('needs a check-in'), findsOneWidget);
      expect(find.textContaining('Contributes to'), findsOneWidget);
      expect(find.text('Cut cost per lead'), findsWidgets, reason: 'named as what it contributes to');
    });

    testWidgets('a key result shows its last report and who made it', (tester) async {
      await _pump(tester, _fixtures());
      await tester.tap(_bar('Grow bridal revenue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('last report 5 Feb by Mira'), findsOneWidget);
      expect(find.textContaining('30 / 100 L'), findsOneWidget);
    });

    testWidgets('Check in hands the key result to the screen', (tester) async {
      final calls = await _pump(tester, _fixtures());
      await tester.tap(_bar('Launch landing pages'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
      await tester.pump();
      expect(calls.checkIns, ['p/k3']);
    });

    testWidgets('someone who may only look sees no buttons', (tester) async {
      await _pump(tester, _fixtures(access: const OKRAccess()));
      await tester.tap(_bar('Launch landing pages'));
      await tester.pumpAndSettle();
      expect(find.text('Key results'), findsOneWidget);
      expect(find.text('Check in'), findsNothing);
      expect(find.text('Edit objective'), findsNothing);
      expect(find.textContaining('Add a contributing'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('someone who may report but not manage gets Check in only', (tester) async {
      await _pump(tester, _fixtures(access: const OKRAccess(canCheckIn: true)));
      await tester.tap(_bar('Launch landing pages'));
      await tester.pumpAndSettle();
      expect(find.text('Check in'), findsOneWidget);
      expect(find.text('Edit objective'), findsNothing);
    });

    testWidgets('a manager can edit and add under it — unless adding under it makes no sense', (tester) async {
      final calls = await _pump(tester, _fixtures(), canAddUnder: (o) => o.effectiveLevel != 'project');
      await tester.tap(_bar('Cut cost per lead'));
      await tester.pumpAndSettle();
      expect(find.text('Edit objective'), findsOneWidget);
      await tester.tap(find.textContaining('Add a contributing'));
      await tester.pump();
      expect(calls.addedUnder, ['d']);
      await tester.tap(find.text('Edit objective'));
      await tester.pump();
      expect(calls.edited, ['d']);

      // close, then a project objective: edit yes, add-under no
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(_bar('Launch landing pages'));
      await tester.pumpAndSettle();
      expect(find.text('Edit objective'), findsOneWidget);
      expect(find.textContaining('Add a contributing'), findsNothing);
    });

    testWidgets('the sheet follows the list: an objective that disappears closes it', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final list = ValueNotifier(_fixtures());
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: ValueListenableBuilder(valueListenable: list, builder: (_, v, _) => ITOkrTimeline(okrs: v, now: _now))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(_bar('Cut cost per lead'));
      await tester.pumpAndSettle();
      expect(find.text('Key results'), findsOneWidget);

      list.value = _fixtures().where((o) => o.id != 'd').toList();
      await tester.pumpAndSettle();
      expect(find.text('Key results'), findsNothing);
    });
  });

  group('moving a bar', () {
    // month zoom: 12 px a day
    testWidgets('dragging the bar moves both dates by the days dragged', (tester) async {
      final calls = await _pump(tester, _fixtures());
      await _scrollToStart(tester);
      await _dragBy(tester, tester.getCenter(_bar('Launch landing pages')), 36);
      expect(calls.shifted, ['p 2027-01-28 → 2027-03-03']);
    });

    testWidgets('dragging backwards moves it earlier', (tester) async {
      final calls = await _pump(tester, _fixtures());
      await _scrollToStart(tester);
      await _dragBy(tester, tester.getCenter(_bar('Launch landing pages')), -24);
      expect(calls.shifted, ['p 2027-01-23 → 2027-02-26']);
    });

    testWidgets('dragging the right end changes only the deadline; the left end only the start', (tester) async {
      final calls = await _pump(tester, _fixtures());
      await _scrollToStart(tester);
      final r = tester.getRect(_bar('Launch landing pages'));
      await _dragBy(tester, Offset(r.right - 3, r.center.dy), 24);
      expect(calls.shifted.last, 'p 2027-01-25 → 2027-03-02');

      final r2 = tester.getRect(_bar('Launch landing pages'));
      await _dragBy(tester, Offset(r2.left + 3, r2.center.dy), 24);
      expect(calls.shifted.last, 'p 2027-01-27 → 2027-02-28');
    });

    testWidgets('a start dragged past the deadline stops at it', (tester) async {
      final calls = await _pump(tester, _fixtures());
      await _scrollToStart(tester);
      final r = tester.getRect(_bar('Launch landing pages'));
      await _dragBy(tester, Offset(r.left + 3, r.center.dy), 600);
      expect(calls.shifted.single, 'p 2027-02-28 → 2027-02-28');
    });

    testWidgets('a drag too small to be a day changes nothing', (tester) async {
      final calls = await _pump(tester, _fixtures());
      await _scrollToStart(tester);
      await _dragBy(tester, tester.getCenter(_bar('Launch landing pages')), 4);
      expect(calls.shifted, isEmpty);
    });

    testWidgets('someone who may not manage the objective cannot move it — the bar just opens it', (tester) async {
      final calls = await _pump(tester, _fixtures(access: const OKRAccess(canCheckIn: true)));
      await _scrollToStart(tester);
      await _dragBy(tester, tester.getCenter(_bar('Launch landing pages')), 36);
      expect(calls.shifted, isEmpty);
    });

    testWidgets('an objective with no dates can be dragged to give it some (from when it was created)', (tester) async {
      final calls = await _pump(tester, _fixtures());
      await _scrollToStart(tester);
      await _dragBy(tester, tester.getCenter(_bar('Loose idea')), 24);
      expect(calls.shifted.single, 'u 2027-01-03 → 2027-02-02');
    });
  });

  group('on a phone', () {
    testWidgets('a list by the month each objective falls due, with its state and key results', (tester) async {
      await _pump(tester, _fixtures(), width: 390);
      expect(find.text('February 2027'), findsOneWidget);
      expect(find.text('March 2027'), findsOneWidget);
      expect(find.text('April 2027'), findsOneWidget);
      expect(find.text('No deadline'), findsOneWidget);
      expect(find.text('this month'), findsOneWidget);
      expect(find.text('Launch landing pages'), findsOneWidget);
      expect(find.text('Pages live'), findsOneWidget);
      expect(find.textContaining('contributes to Cut cost per lead'), findsOneWidget);
      // no horizontal Gantt
      expect(find.text('Quarter'), findsNothing);
      expect(find.text('Today'), findsNothing);
    });

    testWidgets('the same filters work, and a card opens the same detail', (tester) async {
      await _pump(tester, _fixtures(), width: 390);
      await tester.tap(find.text('Off track  1'));
      await tester.pumpAndSettle();
      expect(find.text('Launch landing pages'), findsOneWidget);
      expect(find.text('Cut cost per lead'), findsNothing);

      await tester.tap(find.text('Launch landing pages'));
      await tester.pumpAndSettle();
      expect(find.text('Key results'), findsOneWidget);
      expect(find.text('Check in'), findsOneWidget);
    });
  });

  group('nothing to show', () {
    testWidgets('no objectives: says so and offers a new one', (tester) async {
      var added = 0;
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: ITOkrTimeline(okrs: const [], now: _now, onAddOkr: () => added++))));
      expect(find.text('No objectives to show on the timeline'), findsOneWidget);
      await tester.tap(find.text('New objective'));
      expect(added, 1);
    });

    testWidgets('the level and owner pickers appear only when there is a choice', (tester) async {
      await _pump(tester, [_okr('a', 'One', start: DateTime(2027, 1, 1), end: DateTime(2027, 4, 1), owner: 'Mira')]);
      expect(find.text('All levels'), findsNothing);
      expect(find.text('Everyone'), findsNothing);

      await _pump(tester, _fixtures());
      expect(find.text('All levels'), findsOneWidget);
    });

    testWidgets('picking a level narrows the list', (tester) async {
      await _pump(tester, _fixtures());
      await tester.tap(find.text('All levels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Department objective').last);
      await tester.pumpAndSettle();
      expect(find.text('Cut cost per lead'), findsOneWidget);
      expect(find.text('Grow bridal revenue'), findsNothing);
      expect(find.text('Launch landing pages'), findsNothing);
    });
  });

  group('project-first grouping', () {
    testWidgets('shows project headers as main and objectives underneath', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final okrs = [
        _okr('o1', 'Company Initiative OKR', level: 'company'),
        _okr('o2', 'Pan India Expansion 2027', project: 'Pan Indian Expansion', owner: 'Fathima'),
        _okr('o3', 'Web Release V1', project: 'WedEasy', owner: 'Midlaj'),
      ];

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ITOkrTimeline(
            okrs: okrs,
            now: _now,
            groupByProject: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Project headers appear as main rows
      expect(find.text('Pan Indian Expansion'), findsOneWidget);
      expect(find.text('WedEasy'), findsOneWidget);
      expect(find.text('Company Initiatives'), findsOneWidget);

      // Objectives appear under their projects
      expect(find.text('Pan India Expansion 2027'), findsOneWidget);
      expect(find.text('Web Release V1'), findsOneWidget);
      expect(find.text('Company Initiative OKR'), findsOneWidget);

      // The project is positioned above its objective vertically
      final projectY = tester.getTopLeft(find.text('Pan Indian Expansion')).dy;
      final objectiveY = tester.getTopLeft(find.text('Pan India Expansion 2027')).dy;
      expect(projectY < objectiveY, isTrue, reason: 'project header must sit above objective');

      // The objective is indented under the project
      final projectX = tester.getTopLeft(find.text('Pan Indian Expansion')).dx;
      final objectiveX = tester.getTopLeft(find.text('Pan India Expansion 2027')).dx;
      expect(objectiveX > projectX, isTrue, reason: 'objective must be indented under project');
    });
  });
}
