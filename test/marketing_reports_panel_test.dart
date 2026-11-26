import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/presentation/reports/marketing_reports_panel.dart';
import 'package:nizan_crm/features/marketing/services/marketing_reports_service.dart';

// Saved and Scheduled reports on a marketing Reports tab: a saved report opens the module's report for its period; only a manager
// switches a schedule; a member can remove only what they saved.

class _Fake extends MarketingReportsService {
  _Fake() : super(Dio());
  final changes = <(String, Map<String, dynamic>)>[];
  final removed = <String>[];
  @override
  Future<MarketingReportSchedule> updateSchedule(String key, Map<String, dynamic> change) async {
    changes.add((key, change));
    return MarketingReportSchedule(key: key);
  }

  @override
  Future<void> remove(String id) async => removed.add(id);
}

final _schedules = [
  MarketingReportSchedule.fromJson(const {'key': 'leads.weekly', 'label': 'Weekly Lead Report', 'when': 'Every Monday, 10:00 AM', 'enabled': true, 'nextRunAt': '2026-11-23T04:30:00.000Z', 'time': '10:00'}),
  MarketingReportSchedule.fromJson(const {'key': 'leads.campaign-performance', 'label': 'Campaign Performance (Monthly)', 'when': '1st of every month, 9:00 AM', 'enabled': false, 'time': '09:00'}),
];
final _saved = [
  MarketingSavedReport.fromJson(const {'id': 'r1', 'kind': 'weekly', 'name': 'Weekly Lead Report · 9 Nov – 15 Nov 2026', 'from': '2026-11-09', 'to': '2026-11-15', 'scheduled': true, 'createdByName': 'Scheduled', 'createdAt': '2026-11-16T04:31:00.000Z'}),
  MarketingSavedReport.fromJson(const {'id': 'r2', 'kind': 'source', 'name': 'Source report', 'from': '2026-11-01', 'to': '2026-11-15', 'brand': 'kerala', 'createdByName': 'Saeeda', 'mine': true}),
];

Future<_Fake> _pump(WidgetTester t, {required bool manager, required List<MarketingSavedReport> opened, double width = 1200}) async {
  t.view.physicalSize = Size(width, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final svc = _Fake();
  await t.pumpWidget(ProviderScope(
    overrides: [
      marketingReportsServiceProvider.overrideWithValue(svc),
      marketingReportSchedulesProvider.overrideWith((ref, m) async => (manager, _schedules)),
      marketingSavedReportsProvider.overrideWith((ref, m) async => _saved),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: MarketingReportsPanel(module: 'leads', onOpen: opened.add))),
    ),
  ));
  await t.pumpAndSettle();
  return svc;
}

void main() {
  testWidgets('saved reports list their period, brand and maker; opening one runs it again', (t) async {
    final opened = <MarketingSavedReport>[];
    await _pump(t, manager: false, opened: opened);
    expect(find.text('Weekly Lead Report · 9 Nov – 15 Nov 2026'), findsOneWidget);
    expect(find.textContaining('1 Nov – 15 Nov 2026 · Kerala · Saeeda'), findsOneWidget);
    await t.tap(find.byKey(const Key('mktSavedReportOpen_r2')));
    await t.pump();
    expect(opened.single.kind, 'source');
    expect(find.byKey(const Key('mktSavedReportRemove_r1')), findsNothing, reason: 'a scheduled report is not hers to remove');
    expect(find.byKey(const Key('mktSavedReportRemove_r2')), findsOneWidget);
  });

  testWidgets('a member sees the schedules but cannot switch them', (t) async {
    final svc = await _pump(t, manager: false, opened: []);
    expect(find.text('Every Monday, 10:00 AM · next 23 Nov, 10:00 AM'), findsOneWidget);
    expect(t.widget<Switch>(find.byKey(const Key('mktScheduleSwitch_leads.weekly'))).onChanged, isNull);
    expect(find.byKey(const Key('mktScheduleTime_leads.weekly')), findsNothing);
    expect(find.text('Only the Marketing Manager switches these.'), findsOneWidget);
    expect(svc.changes, isEmpty);
  });

  testWidgets('the manager switches a schedule on', (t) async {
    final svc = await _pump(t, manager: true, opened: []);
    await t.tap(find.byKey(const Key('mktScheduleSwitch_leads.campaign-performance')));
    await t.pumpAndSettle();
    expect(svc.changes.single.$1, 'leads.campaign-performance');
    expect(svc.changes.single.$2, {'enabled': true});
  });

  testWidgets('a link that names a saved report (the "report ready" notice) opens it once — not on every rebuild', (t) async {
    final opened = <MarketingSavedReport>[];
    final router = GoRouter(initialLocation: '/marketing/leads-report?tab=reports&report=r1', routes: [
      GoRoute(path: '/marketing/leads-report', builder: (_, _) => Scaffold(body: SingleChildScrollView(child: MarketingReportsPanel(module: 'leads', onOpen: opened.add)))),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
        marketingReportsServiceProvider.overrideWithValue(_Fake()),
        marketingReportSchedulesProvider.overrideWith((ref, m) async => (false, _schedules)),
        marketingSavedReportsProvider.overrideWith((ref, m) async => _saved),
      ],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await t.pumpAndSettle();
    expect(opened.map((r) => r.id), ['r1']);
    // the list reloads (a report was removed, a schedule switched): still opened once
    final c = ProviderScope.containerOf(t.element(find.byType(MarketingReportsPanel)));
    c.invalidate(marketingSavedReportsProvider('leads'));
    await t.pumpAndSettle();
    expect(opened, hasLength(1));
  });

  testWidgets('a link naming a report that is not in the list opens nothing', (t) async {
    final opened = <MarketingSavedReport>[];
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        marketingReportsServiceProvider.overrideWithValue(_Fake()),
        marketingReportSchedulesProvider.overrideWith((ref, m) async => (false, _schedules)),
        marketingSavedReportsProvider.overrideWith((ref, m) async => _saved),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: MarketingReportsPanel(module: 'leads', onOpen: opened.add, openId: 'gone')))),
    ));
    await t.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('a phone-width panel does not overflow', (t) async {
    await _pump(t, manager: true, opened: [], width: 390);
    expect(t.takeException(), isNull);
  });
}
