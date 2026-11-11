import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_okr_view.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';

// The OKR tab's four ways of looking (timeline, tree, scorecard, table): switching between them, the
// one filter they share, and acting on an objective from the scorecard.

class _Okrs extends OKRService {
  _Okrs(this.list) : super(Dio());

  final List<OKRModel> list;
  final patches = <String>[];

  @override
  Future<List<OKRModel>> getOKRs({String? projectId, String? department, String? status, bool? completed, String? search, bool companyScope = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return list;
  }

  @override
  Future<OKRModel> updateKeyResult(String okrId, String krId, Map<String, dynamic> patch) async {
    patches.add('$okrId/$krId $patch');
    return list.firstWhere((o) => o.id == okrId);
  }
}

void main() {
  final today = DateTime.now();
  DateTime day(int offset) => DateTime(today.year, today.month, today.day).add(Duration(days: offset));

  // "Falling behind": 20% done a third of the way in → at risk. "Fine": 90% done → on track.
  List<OKRModel> objectives() => [
        OKRModel(
          id: 'behind',
          objective: 'Falling behind',
          level: 'company',
          startDate: day(-30),
          deadline: day(60),
          progress: 20,
          createdAt: day(-30),
          keyResults: const [KeyResultItem(id: 'quiet', title: 'Quiet key result', targetValue: 10)],
        ),
        OKRModel(id: 'fine', objective: 'Going well', level: 'company', startDate: day(-30), deadline: day(60), progress: 90, createdAt: day(-30)),
      ];

  Future<_Okrs> pump(WidgetTester tester, {double width = 1280}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _Okrs(objectives());
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        okrServiceProvider.overrideWithValue(service),
        projectEmployeesProvider(null).overrideWithValue(const <Employee>[]),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const ITOkrView(projectId: null, projectName: 'the company')),
    ));
    await tester.pumpAndSettle();
    return service;
  }

  Finder mode(String label) => find.descendant(of: find.byType(SegmentedButton<OkrViewMode>), matching: find.text(label));

  testWidgets('four views, the timeline first; the tree and the scorecard are one tap away', (tester) async {
    await pump(tester);
    for (final m in ['Timeline', 'Tree', 'Scorecard', 'Table']) {
      expect(mode(m), findsOneWidget);
    }
    expect(find.text('Quarter'), findsOneWidget, reason: 'the timeline is showing');

    await tester.tap(mode('Tree'));
    await tester.pumpAndSettle();
    expect(find.text('Quarter'), findsNothing);
    expect(find.text('Falling behind'), findsOneWidget);
    expect(find.text('Going well'), findsOneWidget);

    await tester.tap(mode('Scorecard'));
    await tester.pumpAndSettle();
    expect(find.text('Attainment'), findsOneWidget);
    expect(find.text('Needs a check-in'), findsOneWidget);

    await tester.tap(mode('Timeline'));
    await tester.pumpAndSettle();
    expect(find.text('Quarter'), findsOneWidget);
  });

  testWidgets('a filter chosen in one view is still there in the next', (tester) async {
    await pump(tester);
    await tester.tap(find.text('At risk  1')); // on the timeline
    await tester.pumpAndSettle();
    expect(find.text('Going well'), findsNothing);

    await tester.tap(mode('Tree'));
    await tester.pumpAndSettle();
    expect(find.text('Falling behind'), findsOneWidget);
    expect(find.text('Going well'), findsNothing, reason: 'still narrowed to what is at risk');

    await tester.tap(mode('Scorecard'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.ancestor(of: find.text('Attainment'), matching: find.byType(Container)).first, matching: find.text('20%')), findsOneWidget, reason: 'one objective, 20%');

    await tester.tap(find.text('At risk  1')); // switch it off here
    await tester.pumpAndSettle();
    await tester.tap(mode('Tree'));
    await tester.pumpAndSettle();
    expect(find.text('Going well'), findsOneWidget);
  });

  testWidgets('a key result that needs a check-in can be checked in from the scorecard, and the view stays put', (tester) async {
    final service = await pump(tester);
    await tester.tap(mode('Scorecard'));
    await tester.pumpAndSettle();
    expect(find.text('Falling behind · never reported on'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();
    expect(find.text('Where it stands now'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), '4');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(service.patches, ['behind/quiet {currentValue: 4.0, completed: false}']);
    expect(find.text('Attainment'), findsOneWidget, reason: 'still on the scorecard, not reset to the timeline');
  });

  testWidgets('on a phone the switcher is four icons, with search and New under it', (tester) async {
    await pump(tester, width: 390);
    expect(mode('Tree'), findsNothing, reason: 'no room for four labels');
    for (final tip in ['Timeline', 'Tree', 'Scorecard', 'Table']) {
      expect(find.byTooltip(tip), findsOneWidget);
    }
    expect(find.text('New'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('Tree'));
    await tester.pumpAndSettle();
    expect(find.text('Falling behind'), findsOneWidget);
    await tester.tap(find.byTooltip('Scorecard'));
    await tester.pumpAndSettle();
    expect(find.text('Attainment'), findsOneWidget);
  });
}
