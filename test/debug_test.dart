import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/features/crm/data/crm_weekly_models.dart';
import 'package:nizan_crm/features/crm/presentation/screens/crm_weekly_report_screen.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';
import 'package:nizan_crm/features/crm/services/crm_weekly_service.dart';

class FakeCrmWeeklyService extends CrmWeeklyService {
  FakeCrmWeeklyService(this.report) : super(Dio());
  CrmWeeklyReport report;

  @override
  Future<CrmWeeklyReport> save(String week, Map<String, dynamic> typed) async => report;

  @override
  Future<CrmWeeklyReport> submit(String week) async => report;
}

Map<String, dynamic> _figures() => {
  'nextWeek': {'from': '2026-11-16', 'to': '2026-11-22', 'label': '16 Nov – 22 Nov 2026'},
  'trials': {'held': 5, 'completed': 4, 'cancelled': 1, 'postponed': 0, 'converted': 2, 'maturing': 1, 'prevHeld': 3},
  'photosReviews': {
    'worksDone': 12,
    'photos': 9,
    'photosPct': 75,
    'clientsDone': 10,
    'reviews': 6,
    'reviewsPct': 60,
    'missingPhotos': [],
    'missingReviews': [],
  },
  'support': {
    'clients': 31,
    'prevClients': 28,
    'monthToDate': 64,
    'monthTarget': 100,
    'monthFrom': '2026-11-01',
    'monthTo': '2026-11-15',
    'byMember': [],
  },
  'verification': {
    'thisWeek': {'from': '2026-11-09', 'to': '2026-11-15', 'works': 12, 'verified': 11, 'pct': 91.7, 'unverified': []},
    'nextWeek': {'from': '2026-11-16', 'to': '2026-11-22', 'works': 8, 'verified': 6, 'pct': 75, 'unverified': []},
  },
  'medical': {
    'withConditions': [],
    'emergencies': [],
  },
  'workload': {
    'thisWeek': {'booked': 14, 'capacity': 42, 'days': []},
    'nextWeek': {
      'from': '2026-11-16',
      'to': '2026-11-22',
      'booked': 25,
      'capacity': 42,
      'overDays': 0,
      'days': [
        for (var d = 16; d <= 22; d++)
          {'day': '2026-11-$d', 'booked': 2, 'capacity': 6, 'spare': 4, 'over': false, 'blocked': false},
      ],
    },
  },
  'outsource': {
    'total': 0,
    'lines': [],
    'byPerson': [],
  },
};

CrmWeeklyReport createFakeReport() {
  return CrmWeeklyReport.fromJson({
    'week': {'from': '2026-11-09', 'to': '2026-11-15', 'label': 'Week of 2026-11-09'},
    'status': 'draft',
    'live': true,
    'typed': {},
    'figures': _figures(),
    'records': {'worksDone': 12, 'photos': 9, 'clientsDone': 10, 'reviews': 6},
    'fields': [],
    'submittedByName': '',
    'submittedAt': null,
  });
}

void main() {
  testWidgets('debug overflow', (t) async {
    final report = createFakeReport();
    final svc = FakeCrmWeeklyService(report);

    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: CrmWeeklyReportScreen(now: DateTime(2026, 11, 16)))),
    ]);

    await t.pumpWidget(ProviderScope(
      overrides: [
        crmWeeklyServiceProvider.overrideWithValue(svc),
        crmMeProvider.overrideWith((ref) async => const CrmMe(viewer: 'head', userId: 'u', canAssign: true, seesTeam: true, canWrite: true)),
        crmWeeklyProvider.overrideWith((ref, w) async => svc.report),
        crmWeeksProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));

    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
