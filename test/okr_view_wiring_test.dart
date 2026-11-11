import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_okr_timeline.dart' show OkrZoomScale;
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_okr_view.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';

// The OKR tab end to end (view → timeline → service): the timeline is the default view, a check-in
// from the detail sheet reaches the server as a single-key-result request, and a dragged bar saves
// its dates together with the version the screen was showing — and none of it resets the timeline.

class _Okrs extends OKRService {
  _Okrs(this.list) : super(Dio());

  List<OKRModel> list;
  final patches = <String>[];
  final puts = <Map<String, dynamic>>[];

  @override
  Future<List<OKRModel>> getOKRs({String? projectId, String? department, String? status, bool? completed, String? search, bool companyScope = false}) async {
    // a real request takes a while; frames are drawn meanwhile (an instant answer would hide a flash to a spinner)
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return list;
  }

  @override
  Future<OKRModel> updateKeyResult(String okrId, String krId, Map<String, dynamic> patch) async {
    patches.add('$okrId/$krId $patch');
    list = [
      for (final o in list)
        if (o.id == okrId)
          o.copyWith(keyResults: [for (final k in o.keyResults) if (k.id == krId) k.copyWith(currentValue: (patch['currentValue'] as num).toDouble()) else k])
        else
          o,
    ];
    return list.firstWhere((o) => o.id == okrId);
  }

  @override
  Future<OKRModel> updateOKR(String id, Map<String, dynamic> updates) async {
    puts.add(updates);
    list = [
      for (final o in list)
        if (o.id == id) o.copyWith(startDate: DateTime.parse(updates['startDate'] as String), deadline: DateTime.parse(updates['deadline'] as String)) else o,
    ];
    return list.firstWhere((o) => o.id == id);
  }
}

void main() {
  final today = DateTime.now();
  final updated = DateTime.utc(2027, 1, 5, 10);
  OKRModel okr() => OKRModel(
        id: 'o1',
        objective: 'Launch landing pages',
        level: 'project',
        startDate: DateTime(today.year, today.month, today.day).subtract(const Duration(days: 30)),
        deadline: DateTime(today.year, today.month, today.day).add(const Duration(days: 60)),
        progress: 20,
        updatedAt: updated,
        createdAt: updated,
        keyResults: const [KeyResultItem(id: 'k1', title: 'Pages live', targetValue: 10, currentValue: 2)],
      );

  Future<_Okrs> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _Okrs([okr()]);
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

  Finder bar() => find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith('Launch landing pages\n'));

  testWidgets('opens on the timeline, with the table one tap away', (tester) async {
    await pump(tester);
    expect(find.text('Quarter'), findsOneWidget, reason: 'the timeline\'s zoom is showing');
    expect(bar(), findsOneWidget);
    expect(find.text('Table'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
  });

  testWidgets('a check-in from the detail reaches the server for that one key result, and the timeline keeps its place', (tester) async {
    final service = await pump(tester);
    await tester.tap(find.text('Week')); // a view setting that a rebuild from scratch would lose
    await tester.pumpAndSettle();

    await tester.tap(bar());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();
    expect(find.text('Where it stands now'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    // part-way through the refresh (pumpAndSettle would jump straight to the end): the timeline is
    // still there, not replaced by a spinner
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'a refresh must not blank the timeline (frame $i)');
    }
    await tester.pumpAndSettle();

    expect(service.patches, ['o1/k1 {currentValue: 5.0, completed: false}']);
    // the sheet is still open and shows the new number; the timeline is still on Week, not reset
    expect(find.textContaining('5 / 10'), findsOneWidget);
    final selected = tester.widget<SegmentedButton<OkrZoomScale>>(find.byType(SegmentedButton<OkrZoomScale>)).selected;
    expect(selected, {OkrZoomScale.week});
  });

  testWidgets('a dragged bar saves both dates with the version it was showing', (tester) async {
    final service = await pump(tester);
    final g = await tester.startGesture(tester.getCenter(bar()));
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    await g.moveBy(const Offset(36, 0)); // 12 px a day in the month view: three days
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();

    expect(service.puts, hasLength(1));
    final put = service.puts.single;
    final start = DateTime.parse(put['startDate'] as String);
    final deadline = DateTime.parse(put['deadline'] as String);
    expect(start, DateTime(today.year, today.month, today.day).subtract(const Duration(days: 27)));
    expect(deadline, DateTime(today.year, today.month, today.day).add(const Duration(days: 63)));
    expect(put['expectedUpdatedAt'], updated.toIso8601String(), reason: 'so someone else\'s change in the meantime is refused, not overwritten');
    expect(put.containsKey('keyResults'), isFalse, reason: 'only the dates travel');
  });
}
