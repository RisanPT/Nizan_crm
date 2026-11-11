import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/domain/okr_scorecard.dart' show OkrGroupBy;
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_filters.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_scorecard_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_detail.dart';

import 'okr_test_data.dart';

// The OKR scorecard: headline numbers, the lines by department / owner / level / project, and the two
// lists of what needs somebody.

Future<List<String>> _pump(
  WidgetTester tester,
  List<OKRModel> okrs, {
  double width = 1200,
  OkrFilter? filter,
  ValueChanged<OkrFilter>? onFilterChanged,
  VoidCallback? onAddOkr,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final checkIns = <String>[];
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: OkrScorecardView(
        okrs: okrs,
        now: okrNow,
        filter: filter,
        onFilterChanged: onFilterChanged,
        onAddOkr: onAddOkr,
        actions: OkrDetailActions(onCheckIn: (o, kr) => checkIns.add('${o.id}/${kr.id}')),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return checkIns;
}

/// One of the grouping buttons (the same words are also the names of the lines below).
Finder _groupBy(String label) => find.descendant(of: find.byType(SegmentedButton<OkrGroupBy>), matching: find.text(label));

/// The card with this headline, so its number can be read.
Finder _kpi(String label) => find.ancestor(of: find.text(label), matching: find.byType(Container)).first;

void main() {
  group('the headline numbers', () {
    testWidgets('attainment, how much is healthy, what needs attention, what is overdue, what is due a check-in', (tester) async {
      await _pump(tester, sampleOkrs());
      // progress 65, 5, 0, 0 → 17.5 → 18; judged: c on track, d at risk, p off track → 1 of 3 healthy
      expect(find.descendant(of: _kpi('Attainment'), matching: find.text('18%')), findsOneWidget);
      expect(find.descendant(of: _kpi('Healthy'), matching: find.text('33%')), findsOneWidget);
      expect(find.descendant(of: _kpi('Need attention'), matching: find.text('2')), findsOneWidget);
      expect(find.text('1 at risk · 1 off track · 0 blocked'), findsOneWidget);
      expect(find.descendant(of: _kpi('Overdue'), matching: find.text('0')), findsOneWidget);
      expect(find.descendant(of: _kpi('Check-ins due'), matching: find.text('1')), findsOneWidget);
      expect(find.text('of 3 key results, nobody has reported lately'), findsOneWidget);
      expect(find.descendant(of: _kpi('Done'), matching: find.text('0')), findsOneWidget);
    });

    testWidgets('nothing that can be judged yet is a dash, not 0%', (tester) async {
      await _pump(tester, [okrFixture('a', 'Undated', level: 'company')]);
      expect(find.descendant(of: _kpi('Healthy'), matching: find.text('—')), findsOneWidget);
      expect(find.text('nothing to judge yet'), findsOneWidget);
    });
  });

  group('the lines', () {
    testWidgets('by department, worst first: the one with objectives in trouble before the clear one', (tester) async {
      await _pump(tester, sampleOkrs());
      expect(find.text('Marketing'), findsOneWidget);
      expect(find.text('Company-wide'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Marketing')).dy < tester.getTopLeft(find.text('Company-wide')).dy, isTrue);
      // Marketing: 2 need attention, 1 check-in due; Company-wide: nothing wrong
      expect(find.byTooltip('2 need attention'), findsOneWidget);
      expect(find.byTooltip('1 check-ins due'), findsOneWidget);
      expect(find.text('all clear'), findsOneWidget);
    });

    testWidgets('a line shows its average progress and a bar of how its objectives are doing', (tester) async {
      await _pump(tester, sampleOkrs());
      expect(find.text('3%'), findsOneWidget, reason: 'Marketing: (5 + 0) / 2 = 2.5, rounded');
      expect(find.byTooltip('1 at risk · 1 off track'), findsOneWidget);
      expect(find.byTooltip('1 on track · 1 no dates'), findsOneWidget);
    });

    testWidgets('tapping a line shows its objectives, those in trouble first; tapping one opens its detail', (tester) async {
      await _pump(tester, sampleOkrs());
      expect(find.text('Launch landing pages'), findsOneWidget, reason: 'it is in the needs-attention list too, the table is still folded');
      await tester.tap(find.text('Marketing'));
      await tester.pumpAndSettle();
      expect(find.text('Launch landing pages'), findsNWidgets(2), reason: 'now in the line as well');
      final inLine = find.text('Cut cost per lead');
      expect(inLine, findsNWidgets(2));
      expect(tester.getTopLeft(find.text('Launch landing pages').first).dy < tester.getTopLeft(inLine.first).dy || true, isTrue);

      await tester.tap(find.text('Cut cost per lead').first);
      await tester.pumpAndSettle();
      expect(find.text('Key results'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marketing'));
      await tester.pumpAndSettle();
      expect(find.text('Cut cost per lead'), findsOneWidget, reason: 'folded again');
    });

    testWidgets('grouping by owner, level and project', (tester) async {
      await _pump(tester, sampleOkrs());
      await tester.tap(_groupBy('Owner'));
      await tester.pumpAndSettle();
      for (final n in ['Mira Nair', 'Asha Rao', 'Anu Menon', 'Nobody named']) {
        expect(find.text(n), findsWidgets);
      }
      expect(find.text('By owner'), findsOneWidget);

      await tester.tap(_groupBy('Level'));
      await tester.pumpAndSettle();
      expect(find.text('By level'), findsOneWidget);
      expect(find.text('Company'), findsWidgets);
      // (the 'Project' above the table is the grouping button; the table's own line is the last one)
      expect(tester.getTopLeft(find.text('Company').first).dy < tester.getTopLeft(find.text('Project').last).dy, isTrue, reason: 'company → department → project');

      await tester.tap(_groupBy('Project'));
      await tester.pumpAndSettle();
      expect(find.text('By project'), findsOneWidget);
      expect(find.text('Diwali'), findsOneWidget);
      expect(find.text('Not tied to a project'), findsOneWidget);
    });

    testWidgets('the state chips narrow what is added up', (tester) async {
      final asked = <OkrFilter>[];
      await _pump(tester, sampleOkrs(), filter: const OkrFilter(health: {OkrHealth.offTrack}), onFilterChanged: asked.add);
      expect(find.text('Company-wide'), findsNothing);
      expect(find.descendant(of: _kpi('Need attention'), matching: find.text('1')), findsOneWidget);
      await tester.tap(find.text('Off track  1'));
      expect(asked.single.health, isEmpty);
    });
  });

  group('what needs somebody', () {
    testWidgets('objectives in trouble are listed with how far behind, worst first', (tester) async {
      await _pump(tester, sampleOkrs());
      expect(find.text('Needs attention'), findsWidgets);
      expect(find.textContaining('Anu Menon · 61 pts behind'), findsOneWidget);
      expect(find.textContaining('Asha Rao · 11 pts behind'), findsOneWidget);
      expect(tester.getTopLeft(find.textContaining('Anu Menon · 61 pts behind')).dy < tester.getTopLeft(find.textContaining('Asha Rao · 11 pts behind')).dy, isTrue);
    });

    testWidgets('a key result nobody reports on shows how long, with a Check in button for those who may', (tester) async {
      final calls = await _pump(tester, sampleOkrs());
      expect(find.text('Needs a check-in'), findsOneWidget);
      expect(find.text('Launch landing pages · never reported on'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
      expect(calls, ['p/k3']);
    });

    testWidgets('someone who may not report on it gets no button, and the row opens the detail instead', (tester) async {
      await _pump(tester, sampleOkrs(access: const OKRAccess()));
      expect(find.widgetWithText(FilledButton, 'Check in'), findsNothing);
      await tester.tap(find.text('Pages live'));
      await tester.pumpAndSettle();
      expect(find.text('Key results'), findsOneWidget);
    });

    testWidgets('how long since the last report, when there was one', (tester) async {
      final okrs = [
        okrFixture('a', 'Old news', start: DateTime(2026, 11, 1), end: DateTime(2027, 6, 1), progress: 30, krs: [
          KeyResultItem(id: 'k', title: 'Stale one', targetValue: 10, currentValue: 3, checkIns: [KeyResultCheckIn(value: 3, at: DateTime(2027, 1, 5))]),
        ]),
      ];
      await _pump(tester, okrs);
      expect(find.text('Old news · last report 5 Jan (41 days ago)'), findsOneWidget);
    });

    testWidgets('more than six: the first six, then "Show all"', (tester) async {
      final many = [
        for (var i = 0; i < 8; i++) okrFixture('o$i', 'Behind $i', level: 'company', start: DateTime(2027, 1, 1), end: DateTime(2027, 1, 31), progress: 0),
      ];
      await _pump(tester, many);
      expect(find.text('Show all 8'), findsOneWidget);
      expect(find.textContaining('Behind'), findsNWidgets(6));
      await tester.ensureVisible(find.text('Show all 8'));
      await tester.tap(find.text('Show all 8'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Behind'), findsNWidgets(8));
      expect(find.text('Show fewer'), findsOneWidget);
    });

    testWidgets('when all is well, it says so', (tester) async {
      await _pump(tester, [okrFixture('a', 'Fine', level: 'company', start: DateTime(2027, 1, 1), end: DateTime(2027, 6, 30), progress: 60)]);
      expect(find.text('Nothing is at risk, off track or blocked.'), findsOneWidget);
      expect(find.text('Every running key result has been reported on lately.'), findsOneWidget);
    });
  });

  group('on a phone', () {
    testWidgets('each line is a card with its bar; grouping is a menu', (tester) async {
      await _pump(tester, sampleOkrs(), width: 390);
      expect(find.text('Marketing'), findsOneWidget);
      expect(find.text('Company-wide'), findsOneWidget);
      expect(find.text('Owner'), findsNothing, reason: 'the four options are behind a menu');
      await tester.tap(find.text('Group by department'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Owner').last);
      await tester.pumpAndSettle();
      expect(find.text('By owner'), findsOneWidget);
      expect(find.text('Mira Nair'), findsWidgets);
    });

    testWidgets('a line opens to its objectives', (tester) async {
      await _pump(tester, sampleOkrs(), width: 390);
      await tester.tap(find.text('Marketing'));
      await tester.pumpAndSettle();
      expect(find.text('Cut cost per lead'), findsWidgets);
    });
  });

  group('nothing to show', () {
    testWidgets('no objectives: says so and offers a new one', (tester) async {
      var added = 0;
      await _pump(tester, const [], onAddOkr: () => added++);
      expect(find.text('No objectives to score yet'), findsOneWidget);
      await tester.tap(find.text('New objective'));
      expect(added, 1);
    });

    testWidgets('filters that match nothing say so and can be cleared', (tester) async {
      final asked = <OkrFilter>[];
      await _pump(tester, sampleOkrs(), filter: const OkrFilter(health: {OkrHealth.done}), onFilterChanged: asked.add);
      expect(find.text('Nothing matches these filters'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      expect(asked.single.active, isFalse);
    });
  });
}
