import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_filters.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_detail.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_tree_view.dart';

import 'okr_test_data.dart';

// The OKR alignment map: where the cards go, folding, what rolls up, the filter, and the phone list.

Future<void> _pump(
  WidgetTester tester,
  List<OKRModel> okrs, {
  double width = 1200,
  OkrDetailActions actions = const OkrDetailActions(),
  OkrFilter? filter,
  ValueChanged<OkrFilter>? onFilterChanged,
  VoidCallback? onAddOkr,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: OkrTreeView(okrs: okrs, now: okrNow, actions: actions, filter: filter, onFilterChanged: onFilterChanged, onAddOkr: onAddOkr)),
  ));
  await tester.pumpAndSettle();
}

Offset _at(WidgetTester tester, String title) => tester.getTopLeft(find.text(title));

void main() {
  group('the map', () {
    testWidgets('company → department → project, each a column to the right of what it feeds, on one line when it is a chain', (tester) async {
      await _pump(tester, sampleOkrs());
      final c = _at(tester, 'Grow bridal revenue');
      final d = _at(tester, 'Cut cost per lead');
      final p = _at(tester, 'Launch landing pages');
      expect(d.dx > c.dx + 300, isTrue, reason: 'a whole card and its gap to the right');
      expect(p.dx > d.dx + 300, isTrue);
      expect((c.dy - d.dy).abs() < 2 && (d.dy - p.dy).abs() < 2, isTrue, reason: 'a single chain sits on one line');
      expect(_at(tester, 'Loose idea').dy > c.dy + 100, isTrue, reason: 'the next objective starts a new row below');
    });

    testWidgets('each card says how it is doing; each level has its chip', (tester) async {
      await _pump(tester, sampleOkrs());
      expect(find.textContaining('On track · '), findsOneWidget);
      expect(find.textContaining('At risk · '), findsOneWidget);
      expect(find.textContaining('Off track · '), findsOneWidget);
      expect(find.text('No dates'), findsWidgets);
      expect(find.text('65%'), findsOneWidget);
      expect(find.text('C'), findsWidgets);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
    });

    testWidgets('what feeds an objective rolls up beside its own progress, and says how much of it is in trouble', (tester) async {
      await _pump(tester, sampleOkrs());
      // c is fed by d (5%): avg 5%; d is fed by p (0%): avg 0%
      expect(find.text('fed by 1 · avg 5% · 2 need attention'), findsOneWidget, reason: 'below c: d is at risk and p is off track');
      expect(find.text('fed by 1 · avg 0% · 1 needs attention'), findsOneWidget, reason: 'below d: p is off track');
      expect(find.text('65%'), findsOneWidget, reason: 'c keeps its own number');
    });

    testWidgets('the card carries the owner, dates and key results, and flags one that needs a check-in', (tester) async {
      await _pump(tester, sampleOkrs());
      expect(find.text('Anu Menon · 25 Jan → 28 Feb · 1 KR'), findsOneWidget);
      expect(find.text('Mira Nair · 1 Jan → 31 Mar · 2 KRs'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget, reason: 'Pages live has never been reported on');
    });
  });

  group('folding', () {
    testWidgets('folding a card hides everything under it and says how much; unfolding brings it back', (tester) async {
      await _pump(tester, sampleOkrs());
      await tester.tap(find.byIcon(Icons.expand_more).first); // the company objective's
      await tester.pumpAndSettle();
      expect(find.text('Cut cost per lead'), findsNothing);
      expect(find.text('Launch landing pages'), findsNothing);
      expect(find.text('Grow bridal revenue'), findsOneWidget);
      expect(find.textContaining('2 folded'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();
      expect(find.text('Launch landing pages'), findsOneWidget);
    });

    testWidgets('fold everything / unfold everything', (tester) async {
      await _pump(tester, sampleOkrs());
      await tester.tap(find.byTooltip('Fold everything'));
      await tester.pumpAndSettle();
      expect(find.text('Cut cost per lead'), findsNothing);
      expect(find.text('Loose idea'), findsOneWidget);
      await tester.tap(find.byTooltip('Unfold everything'));
      await tester.pumpAndSettle();
      expect(find.text('Launch landing pages'), findsOneWidget);
    });

    testWidgets('an objective with nothing under it has no arrow', (tester) async {
      await _pump(tester, [okrFixture('a', 'Alone', level: 'company')]);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byTooltip('Fold everything'), findsNothing);
    });
  });

  group('opening and filtering', () {
    testWidgets('tapping a card opens its detail', (tester) async {
      await _pump(tester, sampleOkrs());
      await tester.tap(find.text('Launch landing pages'));
      await tester.pumpAndSettle();
      expect(find.text('Key results'), findsOneWidget);
      expect(find.textContaining('should be at'), findsOneWidget);
    });

    testWidgets('a state chip narrows the map; what is left whose parent is gone starts its own tree', (tester) async {
      await _pump(tester, sampleOkrs());
      await tester.tap(find.text('Off track  1'));
      await tester.pumpAndSettle();
      expect(find.text('Launch landing pages'), findsOneWidget);
      expect(find.text('Grow bridal revenue'), findsNothing);
      expect(tester.getTopLeft(find.text('Launch landing pages')).dx < 120, isTrue, reason: 'now in the first column');
    });

    testWidgets('with the filter given, the tree asks for a change and shows what it is told', (tester) async {
      final asked = <OkrFilter>[];
      await _pump(tester, sampleOkrs(), filter: const OkrFilter(), onFilterChanged: asked.add);
      await tester.tap(find.text('At risk  1'));
      await tester.pumpAndSettle();
      expect(asked.single.health, {OkrHealth.atRisk});
      expect(find.text('Launch landing pages'), findsOneWidget, reason: 'the filter is the caller\'s to change: nothing narrowed yet');

      await _pump(tester, sampleOkrs(), filter: const OkrFilter(health: {OkrHealth.atRisk}));
      expect(find.text('Cut cost per lead'), findsOneWidget);
      expect(find.text('Launch landing pages'), findsNothing);
    });

    testWidgets('filters that match nothing say so and can be cleared', (tester) async {
      final asked = <OkrFilter>[];
      await _pump(tester, sampleOkrs(), filter: const OkrFilter(health: {OkrHealth.done}), onFilterChanged: asked.add);
      expect(find.text('Nothing matches these filters'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      expect(asked.single.active, isFalse);
    });

    testWidgets('no objectives: says so and offers a new one', (tester) async {
      var added = 0;
      await _pump(tester, const [], onAddOkr: () => added++);
      expect(find.text('No objectives to map yet'), findsOneWidget);
      await tester.tap(find.text('New objective'));
      expect(added, 1);
    });
  });

  group('on a phone', () {
    testWidgets('an indented list, each level further in', (tester) async {
      await _pump(tester, sampleOkrs(), width: 390);
      final c = _at(tester, 'Grow bridal revenue').dx;
      final d = _at(tester, 'Cut cost per lead').dx;
      final p = _at(tester, 'Launch landing pages').dx;
      expect(d - c, closeTo(14, 1));
      expect(p - d, closeTo(14, 1));
      expect(_at(tester, 'Cut cost per lead').dy > _at(tester, 'Grow bridal revenue').dy, isTrue);
    });

    testWidgets('folding and opening work the same', (tester) async {
      await _pump(tester, sampleOkrs(), width: 390);
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pumpAndSettle();
      expect(find.text('Cut cost per lead'), findsNothing);
      expect(find.textContaining('2 folded'), findsOneWidget);

      await tester.tap(find.text('Loose idea'));
      await tester.pumpAndSettle();
      expect(find.text('Key results'), findsOneWidget);
    });
  });
}
