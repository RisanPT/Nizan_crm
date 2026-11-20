import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/routing/app_router.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/features/crm/presentation/screens/crm_case_screen.dart';
import 'package:nizan_crm/features/crm/presentation/screens/crm_dashboard_screen.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_dashboard_widgets.dart';
import 'package:nizan_crm/features/crm/presentation/screens/crm_my_work_screen.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';

// The CRM Head's dashboard and the team's work: who may open what, figures that cannot be known read "—" (never 0), the head hands
// work out and a member takes unassigned work, a case is resolved only with a note, and the report is downloaded without the login
// token in the address.

final _now = DateTime(2026, 11, 17, 12);

AuthSession _session(String role, {List<String> perms = const ['clients', 'calendar', 'bookings', 'trials'], String home = '/booking/requests'}) =>
    AuthSession(token: 't', userId: 'u-$role', name: role, email: '$role@x', role: role, permissions: perms, homeRoute: home);

Map<String, dynamic> _kpi(num? value, {num? prev, int? n, String unit = 'count', String better = 'up'}) => {'value': value, 'prev': prev, 'n': n, 'unit': unit, 'better': better};

CrmOverview _overview({bool partial = true, bool team = true}) => CrmOverview.fromJson({
  'range': {'from': '2026-11-01', 'to': '2026-11-30', 'label': '1 – 30 Nov 2026'},
  'previous': {'from': '2026-10-01', 'to': '2026-10-17'},
  'scope': team ? {'kind': 'team'} : {'kind': 'member', 'name': 'Asha'},
  'trackingSince': '2026-11-10T00:00:00.000Z',
  'partial': partial,
  'kpis': {
    'requestsReceived': _kpi(12, prev: 9),
    'requestsDecided': _kpi(10, prev: 10),
    'requestMedianHours': _kpi(null, unit: 'hours', better: 'down'),
    'requestWithinSlaPct': _kpi(80, prev: 90, n: 10, unit: 'pct'),
    'chatMedianReplyMins': _kpi(30, prev: 45, n: 8, unit: 'mins', better: 'down'),
    'nps': _kpi(null, unit: 'score'),
    'chatWaits': _kpi(36, prev: 40),
    'casesOpened': _kpi(18, prev: 15, better: 'down'),
    'trialsScheduled': _kpi(9, prev: 0),
    'reviewsSubmitted': _kpi(64),
    'avgRating': _kpi(4.8, unit: 'rating'),
  },
  'now': {'requests': 3, 'chats': 2, 'cases': 4, 'trials': 1, 'overdue': 2, 'total': 10},
  'unassigned': team ? {'requests': 2, 'chats': 0, 'cases': 1, 'trials': 0, 'overdue': 1, 'total': 3} : null,
  'trend': [
    {'key': '2026-11-01', 'requestsReceived': 2, 'chatWaits': 1},
    {'key': '2026-11-02', 'requestsReceived': 0, 'chatWaits': 3},
  ],
  'members': team
      ? [
          {'userId': 'u-asha', 'name': 'Asha', 'workload': {'total': 5, 'overdue': 1}, 'kpis': {'requestsDecided': _kpi(6)}},
          {'userId': 'u-bina', 'name': 'Bina', 'workload': {'total': 2, 'overdue': 0}, 'kpis': {'requestsDecided': _kpi(4)}},
        ]
      : [],
  'breaches': [
    {'type': 'case', 'id': 'c9', 'title': 'Diya', 'subtitle': 'CC-261117-AAAA · Complaint', 'ownerName': 'Bina', 'ownerId': 'u-bina', 'overdue': true, 'dueAt': '2026-11-16T06:00:00.000Z', 'link': '/crm/cases/c9'},
  ],
  'breachCount': 1,
  'recent': [
    {'kind': 'request', 'at': '2026-11-17T06:28:00.000Z', 'text': 'New booking request from Amina K.', 'refType': 'booking', 'refId': 'b1'},
    {'kind': 'case', 'at': '2026-11-17T06:02:00.000Z', 'text': 'Case C-1028 updated to', 'tag': 'In Progress', 'refType': 'case', 'refId': 'c9'},
  ],
  'upcomingTrials': [
    {'id': 't1', 'clientName': 'Fathima P.', 'what': 'Bridal Trial', 'date': '2026-11-18', 'startTime': '10:30', 'status': 'scheduled', 'artists': ['Anu']},
    {'id': 't2', 'clientName': 'Rizwana S.', 'what': 'Engagement Trial', 'date': '2026-11-19', 'startTime': '14:00', 'status': 'postponed'},
  ],
});

final _queue = CrmQueue.fromJson({
  'counts': {'total': 2, 'overdue': 1},
  'items': [
    {'type': 'booking', 'id': 'b1', 'title': 'Client One', 'subtitle': 'Bridal', 'overdue': true, 'dueAt': '2026-11-16T06:00:00.000Z'},
    {'type': 'conversation', 'id': 'v1', 'title': 'Esha', 'subtitle': 'Is 20 Jan free?', 'dueAt': '2026-11-17T08:00:00.000Z'},
  ],
});

const _team = CrmTeam(members: [
  CrmTeamMember(userId: 'u-asha', name: 'Asha'),
  CrmTeamMember(userId: 'u-bina', name: 'Bina'),
]);

/// The pretend server's writes.
class _FakeCrm extends CrmService {
  _FakeCrm() : super(Dio());
  final assigned = <(List<String>, String?)>[];
  final updates = <Map<String, dynamic>>[];

  @override
  Future<CrmAssignResult> assign(List<({String type, String id})> items, String? ownerId) async {
    assigned.add(([for (final i in items) '${i.type}:${i.id}'], ownerId));
    return CrmAssignResult(assigned: items.length);
  }

  @override
  Future<CrmCase> updateCase(String id, Map<String, dynamic> body) async {
    updates.add(body);
    return CrmCase(id: id, status: body['status'] as String? ?? 'open');
  }
}

CrmMe _me(String viewer, {String userId = 'u-me'}) => CrmMe(
  viewer: viewer,
  userId: userId,
  name: 'Me',
  canAssign: viewer == 'head' || viewer == 'admin',
  seesTeam: viewer != 'member',
  canWrite: viewer != 'leadership',
  onTeam: true,
);

Future<void> _pump(WidgetTester t, Widget screen, {required CrmMe me, required _FakeCrm svc, CrmOverview? overview, CrmCase? kase}) async {
  t.view.physicalSize = const Size(1400, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => screen),
    GoRoute(path: '/crm/cases/:id', builder: (_, s) => Scaffold(body: Text('CASE ${s.pathParameters['id']}'))),
  ]);
  await t.pumpWidget(ProviderScope(
    overrides: [
      crmServiceProvider.overrideWithValue(svc),
      crmMeProvider.overrideWith((ref) async => me),
      crmOverviewProvider.overrideWith((ref, q) async => overview ?? _overview()),
      crmQueueProvider.overrideWith((ref, q) async => q.scope == 'mine' ? const CrmQueue() : _queue),
      crmTeamProvider.overrideWith((ref) async => _team),
      crmCasesProvider.overrideWith((ref, q) async => const CrmCasePage()),
      if (kase != null) crmCaseProvider.overrideWith((ref, id) async => kase),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  ));
  await t.pumpAndSettle();
}

String _text(WidgetTester t, Key k) => t.widget<Text>(find.byKey(k)).data ?? '';

void main() {
  group('who may open what', () {
    final head = Access.of(_session('crm_manager'));
    final member = Access.of(_session('crm'));
    final sales = Access.of(_session('sales', perms: const ['sales', 'clients']));
    final ceo = Access.of(_session('ceo', perms: const []));

    test('the CRM Head is the crm_manager login; a crm login is a member', () {
      expect((head.isCrmTeam, head.isCrmHead, head.canAssignCrmWork), (true, true, true));
      expect((member.isCrmTeam, member.isCrmHead, member.canAssignCrmWork), (true, false, false));
      expect(sales.canSeeCrmWork, isFalse);
    });

    test('the dashboard is the head\'s (and leadership\'s); a member\'s own work and the cases are the whole team\'s', () {
      for (final p in ['/crm/dashboard', '/crm/team/u1', '/crm/month-end']) {
        expect(isRouteAllowed(p, head), isTrue, reason: p);
        expect(isRouteAllowed(p, member), isFalse, reason: p);
        expect(isRouteAllowed(p, sales), isFalse, reason: p);
      }
      for (final p in ['/crm/my-work', '/crm/cases', '/crm/cases/c1', '/crm/re-engagement']) {
        expect(isRouteAllowed(p, member), isTrue, reason: p);
        expect(isRouteAllowed(p, sales), isFalse, reason: p);
      }
      expect(isRouteAllowed('/crm/dashboard', ceo), isTrue, reason: 'leadership reads');
      expect(isRouteAllowed('/crm/cases/c1', ceo), isTrue);
      expect(isRouteAllowed('/crm/my-work', ceo), isFalse, reason: 'leadership has no queue of its own');
    });

    test('the head lands on the CRM dashboard; a member on their home (booking requests)', () {
      expect(landingRouteFor(head), '/crm/dashboard');
      expect(landingRouteFor(member), '/booking/requests');
    });
  });

  group('the figures', () {
    test('a figure that cannot be known is "—"; the change says which way is better', () {
      expect(formatCrmFigure(null, 'hours'), '—');
      expect(formatCrmFigure(0, 'count'), '0', reason: 'a real zero is a zero');
      expect(formatCrmFigure(66.66, 'pct'), '66.7%');
      expect(formatCrmFigure(9, 'hours'), '9 h');
      const faster = CrmKpi(value: 30, prev: 45, unit: 'mins', better: 'down');
      expect((faster.changeText, faster.improved), ('−15 min vs before', true));
      const worse = CrmKpi(value: 80, prev: 90, unit: 'pct');
      expect((worse.changeText, worse.improved), ('−10 pts vs before', false));
      expect(const CrmKpi(value: 3).changeText, isNull, reason: 'nothing to compare with');
    });
  });

  group('the head\'s dashboard', () {
    testWidgets('figures, "—" for what was not recorded, the tracking note, what is overdue', (t) async {
      await _pump(t, CrmDashboardScreen(now: _now), me: _me('head'), svc: _FakeCrm());
      expect(_text(t, const Key('crmKpiValue_requestsReceived')), '12');
      expect(_text(t, const Key('crmToday_requestMedianHours')), '—', reason: 'not recorded: "—", never 0');
      expect(find.byKey(const Key('crmTrackingBanner')), findsOneWidget);
      expect(find.text('Overdue now (1)'), findsOneWidget);
      expect(find.byKey(const Key('crmSettingsButton')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('the five figures with their change on the period before: green when better, red when worse, none when nothing to compare', (t) async {
      await _pump(t, CrmDashboardScreen(now: _now), me: _me('head'), svc: _FakeCrm());
      expect(_text(t, const Key('crmKpiChange_requestsReceived')), '+33%');
      expect(_text(t, const Key('crmKpiChange_chatWaits')), '−10%');
      expect(_text(t, const Key('crmKpiChange_casesOpened')), '+20%');
      Color colour(String k) => t.widget<Text>(find.byKey(Key('crmKpiChange_$k'))).style!.color!;
      expect(colour('requestsReceived'), kCrmGreen);
      expect(colour('casesOpened'), isNot(kCrmGreen), reason: 'more cases opened is worse');
      expect(find.byKey(const Key('crmKpiChange_trialsScheduled')), findsNothing, reason: 'none before: no percentage');
      expect(find.byKey(const Key('crmKpiChange_reviewsSubmitted')), findsNothing);
      expect(_text(t, const Key('crmKpiValue_reviewsSubmitted')), '64');
    });

    testWidgets('open work as a ring with its total, what is overdue and not assigned; today; chat; reviews & cases', (t) async {
      await _pump(t, CrmDashboardScreen(now: _now), me: _me('head'), svc: _FakeCrm());
      expect(_text(t, const Key('crmOpen_total')), '10');
      expect(_text(t, const Key('crmOpen_cases')), '4');
      expect(_text(t, const Key('crmOpen_overdue')), '2');
      expect(_text(t, const Key('crmOpen_unassigned')), '3');
      expect(_text(t, const Key('crmToday_requestsReceived')), '12');
      expect(find.byKey(const Key('crmRequestsChart')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('crmChatCard')), matching: find.text('30 min', findRichText: true)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('crmCareCard')), matching: find.text('4.8 / 5', findRichText: true)), findsOneWidget, reason: 'a big 4.8 and a small "/ 5"');
    });

    testWidgets('recent activities with their time and a case\'s status; upcoming trials by day, time and artist; a case opens', (t) async {
      await _pump(t, CrmDashboardScreen(now: _now), me: _me('head'), svc: _FakeCrm());
      expect(find.text('New booking request from Amina K.'), findsOneWidget);
      expect(find.text('2 min ago'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Bridal Trial – Fathima P.'), findsOneWidget);
      expect(find.text('10:30 AM – Anu'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('crmTrial_t2')), matching: find.text('Postponed')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('crmTrial_t2')), matching: find.text('2:00 PM')), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('crmRecent_1')));
      await t.tap(find.byKey(const Key('crmRecent_1')));
      await t.pumpAndSettle();
      expect(find.text('CASE c9'), findsOneWidget);
    });

    testWidgets('the period is one pill: it says the dates and offers the presets', (t) async {
      await _pump(t, CrmDashboardScreen(now: _now), me: _me('head'), svc: _FakeCrm());
      expect(_text(t, const Key('crmPeriodLabel')), '1 Nov 2026  –  30 Nov 2026');
      await t.tap(find.byKey(const Key('crmPeriodPill')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('crmPeriod_today')));
      await t.pumpAndSettle();
      expect(_text(t, const Key('crmPeriodLabel')), '17 Nov 2026  –  17 Nov 2026');
    });

    testWidgets('the head ticks unassigned work and gives it to a member', (t) async {
      final svc = _FakeCrm();
      await _pump(t, CrmDashboardScreen(now: _now), me: _me('head'), svc: svc);
      await t.tap(find.text('Queue'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('crmAssignSelected')), findsNothing, reason: 'nothing ticked yet');
      await t.tap(find.byKey(const Key('crmQueueCheck_booking:b1')));
      await t.tap(find.byKey(const Key('crmQueueCheck_conversation:v1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('crmAssignSelected')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('crmAssignTo_u-bina')));
      await t.pumpAndSettle();
      expect(svc.assigned.single.$1, ['booking:b1', 'conversation:v1']);
      expect(svc.assigned.single.$2, 'u-bina');
    });

    testWidgets('leadership reads: no settings, no ticking', (t) async {
      await _pump(t, CrmDashboardScreen(now: _now), me: _me('leadership'), svc: _FakeCrm());
      expect(find.byKey(const Key('crmSettingsButton')), findsNothing);
      await t.tap(find.text('Queue'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('crmQueueCheck_booking:b1')), findsNothing);
    });

    testWidgets('a phone-width dashboard does not overflow', (t) async {
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: [
          crmServiceProvider.overrideWithValue(_FakeCrm()),
          crmMeProvider.overrideWith((ref) async => _me('head')),
          crmOverviewProvider.overrideWith((ref, q) async => _overview()),
          crmQueueProvider.overrideWith((ref, q) async => _queue),
          crmTeamProvider.overrideWith((ref) async => _team),
          crmCasesProvider.overrideWith((ref, q) async => const CrmCasePage()),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: CrmDashboardScreen(now: _now)),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.text('Team'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('crmMember_u-asha')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('a member\'s own work', () {
    testWidgets('a member takes an unassigned request for themselves — and cannot tick or give work away', (t) async {
      final svc = _FakeCrm();
      await _pump(t, CrmMyWorkScreen(now: _now), me: _me('member', userId: 'u-asha'), svc: svc, overview: _overview(team: false));
      expect(find.byKey(const Key('crmQueueEmpty')), findsOneWidget, reason: 'nothing of her own yet');
      expect(find.byKey(const Key('crmQueueCheck_booking:b1')), findsNothing);
      await t.tap(find.byKey(const Key('crmTake_booking:b1')));
      await t.pumpAndSettle();
      expect(svc.assigned.single.$1, ['booking:b1']);
      expect(svc.assigned.single.$2, 'u-asha', reason: 'for herself');
    });
  });

  group('a case', () {
    final open = CrmCase.fromJson({
      'id': 'c1', 'caseNumber': 'CC-261117-ABCD', 'kind': 'complaint', 'title': 'Unhappy client', 'customerName': 'Diya', 'phone': '9895011111',
      'ownerId': 'u-asha', 'ownerName': 'Asha', 'status': 'in_progress', 'dueAt': '2026-11-19T06:00:00.000Z', 'createdAt': '2026-11-17T06:00:00.000Z',
      'activities': [{'type': 'call', 'text': 'Called', 'outcome': 'reached', 'at': '2026-11-17T07:00:00.000Z', 'byName': 'Asha'}],
    });

    testWidgets('resolving needs a note of what was done', (t) async {
      final svc = _FakeCrm();
      await _pump(t, const CrmCaseScreen(caseId: 'c1'), me: _me('member', userId: 'u-asha'), svc: svc, kase: open);
      await t.tap(find.byKey(const Key('crmCaseResolve')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('crmResolveSave')));
      await t.pumpAndSettle();
      expect(svc.updates, isEmpty, reason: 'no note, no resolving');
      expect(find.text('Write what was done first.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('crmResolveNote')), 'Apologised and refunded the trial');
      await t.tap(find.byKey(const Key('crmResolveSave')));
      await t.pumpAndSettle();
      expect(svc.updates.single, {'status': 'resolved', 'resolutionNote': 'Apologised and refunded the trial'});
    });

    testWidgets('someone else\'s case: no actions for a member', (t) async {
      await _pump(t, const CrmCaseScreen(caseId: 'c1'), me: _me('member', userId: 'u-bina'), svc: _FakeCrm(), kase: open);
      expect(find.byKey(const Key('crmCaseResolve')), findsNothing);
      expect(find.byKey(const Key('crmCaseReassign')), findsNothing);
      expect(find.byKey(const Key('crmCaseNote')), findsNothing);
    });

    testWidgets('the head works any case and can reassign it', (t) async {
      await _pump(t, const CrmCaseScreen(caseId: 'c1'), me: _me('head'), svc: _FakeCrm(), kase: open);
      expect(find.byKey(const Key('crmCaseResolve')), findsOneWidget);
      expect(find.byKey(const Key('crmCaseReassign')), findsOneWidget);
    });
  });

  group('the report download', () {
    test('asks for the dates and the format, keeps the login out of the address, and names the file as the server does', () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api'))..httpClientAdapter = adapter;
      final (name, bytes) = await CrmService(dio).downloadReport(
        ReportRange(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 17)),
        format: 'xlsx',
        memberId: 'u-asha',
      );
      final asked = adapter.asked.single;
      expect(asked.path, '/crm/report');
      expect(asked.queryParameters, {'from': '2026-11-01', 'to': '2026-11-17', 'memberId': 'u-asha', 'format': 'xlsx'});
      expect(asked.uri.toString().contains('token'), isFalse);
      expect(asked.responseType, ResponseType.bytes);
      expect((name, bytes.length), ('CRM_Report_2026-11-01_to_2026-11-17_Asha.xlsx', 4));
    });
  });
}

class _Adapter implements HttpClientAdapter {
  final asked = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    asked.add(options);
    return ResponseBody.fromBytes(Uint8List.fromList([80, 75, 3, 4]), 200, headers: {
      'content-disposition': ['attachment; filename="CRM_Report_2026-11-01_to_2026-11-17_Asha.xlsx"'],
      'content-type': ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    });
  }

  @override
  void close({bool force = false}) {}
}
