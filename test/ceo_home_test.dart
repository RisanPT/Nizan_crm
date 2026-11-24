import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/work_profit_controller.dart';
import 'package:nizan_crm/features/accounts/data/accounts_dashboard_summary.dart';
import 'package:nizan_crm/features/accounts/data/work_profit.dart';
import 'package:nizan_crm/features/ceo/data/ceo_inbox.dart';
import 'package:nizan_crm/features/ceo/data/decision_models.dart';
import 'package:nizan_crm/features/ceo/presentation/screens/ceo_home_screen.dart';
import 'package:nizan_crm/features/ceo/services/ceo_service.dart';
import 'package:nizan_crm/features/ceo/services/decision_service.dart';
import 'package:nizan_crm/features/dashboard/controllers/dashboard_analytics_provider.dart';
import 'package:nizan_crm/features/dashboard/data/dashboard_analytics.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart' show kDashBad, kDashGood;
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';
import 'package:nizan_crm/features/hr/analytics/service/hr_analytics_service.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';

// The leadership home: what needs a decision (real cards), what is stuck with the team, what was decided, and the company at a
// glance. Each section loads and fails on its own.

/// One request as the server sends it.
Map<String, dynamic> _req(
  String id, {
  String kind = 'spend_expense',
  String title = 'Studio ring lights',
  num? amount = 80000,
  String status = 'pending',
  bool canDecide = true,
  bool checked = true,
  Map<String, dynamic>? decision,
  String? deferredUntil,
}) =>
    {
      'id': id,
      'kind': kind,
      'status': status,
      'open': status == 'pending' || status == 'deferred',
      'title': title,
      'subtitle': 'Lights & Co',
      'department': 'Sales',
      'amount': amount,
      'requestedBy': {'id': 'u1', 'name': 'Saleem', 'role': 'sales'},
      'requestedAt': '2026-11-09T10:00:00.000Z',
      if (checked) 'checkedBy': {'id': 'u2', 'name': 'Dev', 'role': 'accounts', 'label': 'Accounts'},
      if (checked) 'checkedAt': '2026-11-09T12:00:00.000Z',
      'checkNote': checked ? 'Bills match' : '',
      'waitingDays': 3,
      'deferredUntil': deferredUntil,
      'decision': decision,
      'summary': [
        {'label': 'Vendor', 'value': 'Lights & Co'}
      ],
      'attachments': [],
      'canDecide': canDecide && (status == 'pending' || status == 'deferred'),
    };

CeoInbox _inbox({List<Map<String, dynamic>>? preview, int logOpen = 1, List<Map<String, dynamic>>? recent}) => CeoInbox.fromJson({
      'needsYou': 3,
      'withTeam': 7,
      'oldestTeamDays': 9,
      'items': [
        {'key': 'decision_requests', 'owner': 'you', 'label': 'Checked by the team, waiting for your decision', 'count': 2, 'oldestDays': 3, 'route': '/ceo/decisions'},
        {'key': 'ceo_decisions', 'owner': 'you', 'label': 'Open CEO decisions', 'count': logOpen, 'route': '/ceo/decisions'},
        {'key': 'hr_approvals', 'owner': 'team', 'label': 'HR approvals (leave, claims, revisions)', 'withWhom': 'HR / managers', 'count': 5, 'oldestDays': 9},
        {'key': 'admin_expenses', 'owner': 'team', 'label': 'Department expenses', 'withWhom': 'Accounts', 'count': 2, 'amount': 1200, 'oldestDays': 1, 'route': '/accounts/dashboard'},
      ],
      'decisions': {
        'open': 2,
        'pending': 2,
        'deferred': 0,
        'byKind': {'spend_expense': 1, 'hiring_plan': 1},
        'oldestDays': 3,
        'preview': preview ??
            [
              _req('r1'),
              _req('r2', kind: 'hiring_plan', title: 'Senior Stylist × 3', amount: null),
            ],
      },
      'recent': recent ??
          [
            _req('d1', title: 'New van', status: 'approved', canDecide: false, decision: {'by': {'id': 'u9', 'name': 'Anita', 'role': 'ceo'}, 'at': '2026-11-10T09:00:00.000Z', 'note': 'Go'}),
          ],
      'log': {'open': logOpen},
    });

/// Records what the leader did, instead of calling a server.
class _FakeDecisions extends DecisionService {
  _FakeDecisions() : super(Dio());
  final calls = <({String id, DecisionAction action, String note, DateTime? until})>[];
  DecisionConflict? refuse;

  @override
  Future<DecisionRequest> decide(String id, DecisionAction action, {String note = '', DateTime? until}) async {
    if (refuse != null) throw refuse!;
    calls.add((id: id, action: action, note: note, until: until));
    return DecisionRequest.fromJson(_req(id, status: action == DecisionAction.approve ? 'approved' : 'rejected', canDecide: false));
  }

  @override
  Future<DecisionRequest> one(String id) async => DecisionRequest.fromJson({..._req(id), 'history': [
        {'action': 'requested', 'at': '2026-11-09T10:00:00.000Z', 'by': {'name': 'Saleem'}, 'note': ''},
        {'action': 'checked', 'at': '2026-11-09T12:00:00.000Z', 'by': {'name': 'Dev'}, 'note': 'Bills match'},
      ]});

  @override
  Future<DecisionQueue> queue(DecisionFilter f, {String? cursor}) async => const DecisionQueue(items: []);
}

List<CeoSignal> _signals() => [
      CeoSignal.fromJson({'key': 'low_stock', 'label': 'Products at or below their stock threshold', 'value': 12, 'severity': 'alert'}),
      CeoSignal.fromJson({'key': 'cancellations', 'label': 'Cancelled works this month', 'value': 2, 'previous': 5, 'severity': 'ok'}),
      CeoSignal.fromJson({'key': 'nps', 'label': 'Client NPS, last 30 days', 'value': 55, 'previous': 61, 'severity': 'watch', 'route': '/marketing/insights'}),
    ];

AccountsDashboardSummary _summary() => AccountsDashboardSummary.fromJson({
      'income': {'total': 900000, 'items': []},
      'expense': {'total': 400000, 'items': []},
      'net': 500000,
      'cashBank': {'total': 2450000},
      'receivables': {'totalOutstanding': 640000, 'totalOverdue': 210000, 'buckets': {'current': 100000, 'days30': 60000, 'days60': 30000, 'days90': 20000}},
      'payables': {'totalOutstanding': 180000, 'totalOverdue': 30000, 'buckets': <String, dynamic>{}},
    });

MonthEndReview _review({double? target = 1000000, double pct = 82}) => MonthEndReview.fromJson({
      'revenue': {'total': 820000, 'previous': 700000, 'growthPct': 17, 'target': ?target, if (target != null) 'targetAchievedPct': pct},
      'profitability': {'netProfit': 210000, 'netMarginPct': 25.6, 'target': 300000, 'targetAchievedPct': 70},
      'kpis': {'burnRate': 250000, 'cashRunwayMonths': 9.8},
    });

WorkProfitPage _work({bool losses = true}) => WorkProfitPage.fromJson({
      'items': losses
          ? [
              {'bookingNumber': 'BK-1042', 'customerName': 'Fathima Rahman', 'service': 'Airbrush bridal', 'profit': -4200, 'marginPct': -12},
              {'bookingNumber': 'BK-1051', 'customerName': 'Anjali Menon', 'service': 'Platinum', 'profit': -1500, 'marginPct': -3},
            ]
          : [],
      'totals': {'profit': 540000, 'marginPct': 41, 'count': {'loss': losses ? 2 : 0, 'thin': 4}},
    });

SalesDashboard _sales() => SalesDashboard.fromJson({
      'kpis': {'revenue': 820000, 'orders': 31, 'enquiries': 120, 'conversion': 26, 'outstanding': 210000, 'cancelled': 2},
      'previous': {'revenue': 700000, 'orders': 28, 'enquiries': 100, 'conversion': 28, 'cancelled': 1},
      'byDistrict': [
        {'label': 'Kozhikode', 'count': 12, 'amount': 410000},
        {'label': 'Ernakulam', 'count': 8, 'amount': 220000},
      ],
      'bySalesperson': [
        {'label': 'Arjun', 'count': 14, 'amount': 380000, 'id': 'u1'},
      ],
    });

MarketingInsights _insights() => MarketingInsights.fromJson({
      'nps': {
        'nps': 55,
        'responses': 40,
        'trend': [
          {'month': '2026-09', 'nps': 61, 'responses': 20},
          {'month': '2026-10', 'nps': 58, 'responses': 20},
        ],
      },
      'csat': {'avgBrideScore': 4.6, 'avgTeamScore': 4.4, 'submitted': 40},
      'artistUtilization': {'pct': 72, 'busy': 18, 'total': 25},
      'slotUtilization': {'pct': 64, 'totalCapacity': 500, 'totalBooked': 320},
    });

HrAnalyticsSummary _hr() => HrAnalyticsSummary.fromJson({
      'headcount': {'active': 41, 'inactive': 6, 'total': 47},
      'newHiresThisMonth': 3,
      'pendingApprovals': 9,
      'pendingLeave': 4,
      'openGrievances': 1,
      'onboardingInProgress': 2,
      'exitsInProgress': 1,
    });

List<Project> _projects() => [
      Project.fromJson({'_id': 'p1', 'name': 'Open Bangalore', 'status': 'proposed', 'targetDepartment': 'Management', 'progress': 0}),
      Project.fromJson({'_id': 'p2', 'name': 'Website', 'status': 'active', 'targetDepartment': 'IT', 'progress': 60, 'endDate': DateTime.now().subtract(const Duration(days: 10)).toIso8601String()}),
      Project.fromJson({'_id': 'p3', 'name': 'Studio kits', 'status': 'active', 'targetDepartment': 'Operations', 'progress': 40, 'endDate': DateTime.now().add(const Duration(days: 30)).toIso8601String()}),
      Project.fromJson({'_id': 'p4', 'name': 'Old one', 'status': 'completed', 'targetDepartment': 'IT', 'progress': 100}),
    ];

List<OKRModel> _okrs() => [
      OKRModel.fromJson({'_id': 'o1', 'objective': 'Grow', 'level': 'company', 'status': 'in-progress', 'progress': 50, 'startDate': '2026-01-01', 'deadline': '2026-12-31'}),
      OKRModel.fromJson({'_id': 'o2', 'objective': 'Retain', 'level': 'company', 'status': 'blocked', 'progress': 20}),
      OKRModel.fromJson({'_id': 'o3', 'objective': 'A project thing', 'level': 'project', 'status': 'in-progress', 'progress': 99}),
    ];

class _Data {
  int inboxLoads = 0;
  _FakeDecisions? fake;
  Access? access;
  CeoInbox? inbox;
  List<CeoSignal>? signals;
  bool signalsFail = false;
  bool reviewFail = false;
  double targetPct = 82;
  WorkProfitPage? work;
  _Data({this.inbox, this.signals, this.work});
}

Future<void> _pump(
  WidgetTester tester, {
  _Data? data,
  Size size = const Size(1400, 1400),
  bool withRoutes = false,
  bool someSourceIsDown = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final d = data ?? _Data(inbox: _inbox(), signals: _signals(), work: _work());
  final overrides = <Override>[
    decisionServiceProvider.overrideWithValue(d.fake ?? _FakeDecisions()),
    if (d.access != null) effectiveAccessProvider.overrideWithValue(d.access!),
    ceoInboxProvider.overrideWith((ref) async {
      d.inboxLoads++;
      return d.inbox ?? _inbox();
    }),
    ceoSignalsProvider.overrideWith((ref) async => d.signalsFail ? throw Exception('boom') : (d.signals ?? _signals())),
    accountsDashboardSummaryProvider.overrideWith((ref, key) async => _summary()),
    monthEndReviewProvider.overrideWith((ref, key) async => d.reviewFail ? throw Exception('review down') : _review(pct: d.targetPct)),
    workProfitPageProvider.overrideWith((ref, q) async => d.work ?? _work()),
    salesDashboardProvider.overrideWith((ref, q) async => _sales()),
    marketingInsightsProvider.overrideWith((ref) async => _insights()),
    hrAnalyticsSummaryProvider.overrideWith((ref) async => _hr()),
    companyProjectsProvider.overrideWith((ref, dept) async => _projects()),
    planningOkrsProvider.overrideWith((ref) async => _okrs()),
  ];
  await tester.pumpWidget(const SizedBox.shrink());

  final Widget home = const Scaffold(body: CeoHomeScreen());
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: withRoutes
        ? MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: GoRouter(routes: [
              GoRoute(path: '/', builder: (_, _) => home),
              GoRoute(path: '/projects', builder: (_, _) => const Scaffold(body: Text('PROJECTS SCREEN'))),
              GoRoute(path: '/ceo/decisions', builder: (_, state) => Scaffold(body: Text('DECISIONS SCREEN ${state.uri.queryParameters['tab'] ?? 'waiting'}'))),
              GoRoute(path: '/accounts/dashboard', builder: (_, _) => const Scaffold(body: Text('ACCOUNTS SCREEN'))),
              GoRoute(path: '/marketing/insights', builder: (_, _) => const Scaffold(body: Text('INSIGHTS SCREEN'))),
              GoRoute(path: '/accounts/work-profit', builder: (_, _) => const Scaffold(body: Text('WORK PROFIT SCREEN'))),
            ]),
          )
        : MaterialApp(theme: AppTheme.lightTheme, home: home),
  ));
  await tester.pumpAndSettle();
  if (!someSourceIsDown) {
    // a card that quietly failed to read its data would otherwise pass every test that looks for other things
    final errors = find.byType(AppErrorView).evaluate().map((e) => '${(e.widget as AppErrorView).error}').toList();
    expect(errors, isEmpty, reason: 'a card failed to load its fixture');
  }
}

Finder _k(String key) => find.byKey(Key(key));
String _text(WidgetTester t, Finder f) => t.widget<Text>(f).data!;

void main() {
  group('the inbox model', () {
    CeoInboxItem item(String owner, int? days) => CeoInboxItem.fromJson({'key': 'k', 'label': 'L', 'owner': owner, 'count': 1, 'oldestDays': days});

    test('a team approval is stale from 3 days; a decision of the CEO\'s own never is; no age, never', () {
      expect(item('team', 3).isStale, isTrue);
      expect(item('team', 12).isStale, isTrue);
      expect(item('team', 2).isStale, isFalse);
      expect(item('team', null).isStale, isFalse);
      expect(item('you', 30).isStale, isFalse);
    });

    test('a stale team item is marked in amber in the list, a fresh one is not', () {
      expect(item('team', 9).isMine, isFalse);
      expect(item('you', 1).isMine, isTrue);
    });

    test('a route that is blank is no route', () {
      expect(CeoInboxItem.fromJson({'key': 'k', 'label': 'L', 'owner': 'team', 'count': 1, 'route': ''}).route, isNull);
      expect(CeoInboxItem.fromJson({'key': 'k', 'label': 'L', 'owner': 'team', 'count': 1, 'route': '/projects'}).route, '/projects');
    });

    test('a signal says how it moved, in whole numbers where it can', () {
      CeoSignal s(num v, num? p) => CeoSignal.fromJson({'key': 'k', 'label': 'L', 'value': v, 'previous': ?p, 'severity': 'ok'});
      expect(s(2, 5).change, '−3 on before');
      expect(s(8, 5).change, '+3 on before');
      expect(s(5, 5).change, 'same as before');
      expect(s(5.5, 5).change, '+0.5 on before');
      expect(s(5, null).change, isNull);
    });

    test('unknown severities are read as fine', () {
      expect(CeoSeverity.parse('alert'), CeoSeverity.alert);
      expect(CeoSeverity.parse('watch'), CeoSeverity.watch);
      expect(CeoSeverity.parse('ok'), CeoSeverity.ok);
      expect(CeoSeverity.parse('whatever'), CeoSeverity.ok);
      expect(CeoSeverity.parse(null), CeoSeverity.ok);
    });
  });

  group('needs your decision', () {
    testWidgets('each thing the team has checked is a card: what, how much, who asked, who verified it — with the three choices on it', (tester) async {
      await _pump(tester);
      expect(find.text('Needs your decision'), findsOneWidget);
      expect(_k('ceo_decision_r1'), findsOneWidget);
      expect(find.text('Studio ring lights'), findsOneWidget);
      expect(_text(tester, _k('ceo_decision_amount_r1')), '₹80,000');
      expect(find.text('Senior Stylist × 3'), findsOneWidget);
      expect(_k('ceo_decision_amount_r2'), findsNothing, reason: 'a hiring plan has no amount');
      expect(find.text('Verified by Accounts (Dev)'), findsNWidgets(2));
      expect(find.text('Asked by Saleem · 3 d'), findsNWidgets(2));
      expect(find.textContaining('Bills match'), findsNWidgets(2));
      for (final id in ['r1', 'r2']) {
        expect(_k('ceo_approve_$id'), findsOneWidget);
        expect(_k('ceo_reject_$id'), findsOneWidget);
        expect(_k('ceo_defer_$id'), findsOneWidget);
      }
      expect(_text(tester, _k('ceo_needs_count')), '3');
      expect(find.textContaining('The longest has waited 3 days'), findsOneWidget);
    });

    testWidgets('a proposal nobody has checked says nothing about verification', (tester) async {
      await _pump(tester, data: _Data(inbox: _inbox(preview: [_req('p1', kind: 'project_proposal', title: 'Open Bangalore', checked: false, amount: null)]), signals: _signals(), work: _work()));
      expect(find.text('Open Bangalore'), findsOneWidget);
      expect(_k('ceo_verified_p1'), findsNothing);
    });

    testWidgets('approving: a note is optional; the decision is sent and confirmed', (tester) async {
      final fake = _FakeDecisions();
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..fake = fake);
      await tester.tap(_k('ceo_approve_r1'));
      await tester.pumpAndSettle();
      expect(_k('ceo_note_field'), findsOneWidget);
      await tester.tap(_k('ceo_note_submit')); // no note typed
      await tester.pumpAndSettle();
      expect(fake.calls.single.id, 'r1');
      expect(fake.calls.single.action, DecisionAction.approve);
      expect(fake.calls.single.note, '');
      expect(_k('ceo_decision_done'), findsOneWidget);
    });

    testWidgets('after a decision (and after losing a race) the desk is read again, so the card is replaced by what really happened', (tester) async {
      final d = _Data(inbox: _inbox(), signals: _signals(), work: _work())..fake = _FakeDecisions();
      await _pump(tester, data: d);
      final before = d.inboxLoads;
      await tester.tap(_k('ceo_approve_r1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('ceo_note_submit'));
      await tester.pumpAndSettle();
      expect(d.inboxLoads, greaterThan(before));
      final lost = _Data(inbox: _inbox(), signals: _signals(), work: _work())..fake = (_FakeDecisions()..refuse = const DecisionConflict(code: 'ALREADY_DECIDED', message: 'Already rejected by Dev'));
      await _pump(tester, data: lost);
      final beforeLost = lost.inboxLoads;
      await tester.tap(_k('ceo_approve_r1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('ceo_note_submit'));
      await tester.pumpAndSettle();
      expect(lost.inboxLoads, greaterThan(beforeLost));
    });

    testWidgets('rejecting needs a reason: the button stays off until there is one, and the quick reasons fill it in', (tester) async {
      final fake = _FakeDecisions();
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..fake = fake);
      await tester.tap(_k('ceo_reject_r1'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(_k('ceo_note_submit')).onPressed, isNull);
      await tester.enterText(_k('ceo_note_field'), 'no');
      await tester.pump();
      expect(tester.widget<FilledButton>(_k('ceo_note_submit')).onPressed, isNull, reason: '2 characters is not a reason');
      await tester.tap(_k('ceo_reason_0'));
      await tester.pump();
      expect(tester.widget<FilledButton>(_k('ceo_note_submit')).onPressed, isNotNull);
      await tester.tap(_k('ceo_note_submit'));
      await tester.pumpAndSettle();
      expect(fake.calls.single.action, DecisionAction.reject);
      expect(fake.calls.single.note, 'Not in the budget');
    });

    testWidgets('backing out of the sheet decides nothing', (tester) async {
      final fake = _FakeDecisions();
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..fake = fake);
      await tester.tap(_k('ceo_reject_r1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('ceo_note_cancel'));
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
    });

    testWidgets('deferring: tomorrow by default, or a week; the date goes with the decision', (tester) async {
      final fake = _FakeDecisions();
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..fake = fake);
      await tester.tap(_k('ceo_defer_r1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('ceo_defer_week'));
      await tester.pump();
      await tester.tap(_k('ceo_note_submit'));
      await tester.pumpAndSettle();
      final call = fake.calls.single;
      expect(call.action, DecisionAction.defer);
      final days = call.until!.difference(DateTime.now()).inDays;
      expect(days, inInclusiveRange(6, 7));
    });

    testWidgets('the other leader decided first: the message says who, and what — nothing is recorded twice', (tester) async {
      final fake = _FakeDecisions()
        ..refuse = const DecisionConflict(
          code: 'ALREADY_DECIDED',
          message: 'Already approved by Dev (Executive Director): “Fine”',
          decision: DecisionOutcome(by: DecisionPerson(name: 'Dev', role: 'executive_director'), note: 'Fine'),
        );
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..fake = fake);
      await tester.tap(_k('ceo_approve_r1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('ceo_note_submit'));
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
      expect(_k('ceo_decision_done'), findsNothing);
      expect(find.textContaining('Already approved by Dev (Executive Director)'), findsOneWidget);
    });

    testWidgets('tapping a card opens what the team attached and its history', (tester) async {
      await _pump(tester);
      await tester.tap(_k('ceo_decision_open_r1'));
      await tester.pumpAndSettle();
      expect(_k('ceo_detail_title'), findsOneWidget);
      expect(find.text('Lights & Co'), findsWidgets);
      expect(find.textContaining('Asked by Saleem'), findsWidgets);
      expect(find.textContaining('Checked by Dev'), findsOneWidget);
      expect(_k('ceo_detail_approve'), findsOneWidget);
    });

    testWidgets('a decision put off to a later date is marked, and not offered as a new one', (tester) async {
      final later = DateTime.now().add(const Duration(days: 4)).toIso8601String();
      await _pump(tester, data: _Data(inbox: _inbox(preview: [_req('r1', status: 'deferred', deferredUntil: later), _req('r2', title: 'Second')]), signals: _signals(), work: _work()));
      expect(_k('ceo_decision_r1'), findsNothing);
      expect(_k('ceo_decision_r2'), findsOneWidget);
    });

    testWidgets('your own decisions log is one line with a count, linking to it', (tester) async {
      await _pump(tester, withRoutes: true);
      expect(find.text('1 open entry in your decisions log'), findsOneWidget);
      await tester.ensureVisible(_k('ceo_log_open'));
      await tester.tap(_k('ceo_log_open'));
      await tester.pumpAndSettle();
      expect(find.text('DECISIONS SCREEN log'), findsOneWidget);
    });

    testWidgets('"See all" goes to the Decisions screen', (tester) async {
      await _pump(tester, withRoutes: true);
      await tester.ensureVisible(_k('ceo_see_all_decisions'));
      await tester.tap(_k('ceo_see_all_decisions'));
      await tester.pumpAndSettle();
      expect(find.text('DECISIONS SCREEN waiting'), findsOneWidget);
    });

    testWidgets('nothing waiting for the leader: says so, kindly', (tester) async {
      await _pump(tester, data: _Data(inbox: CeoInbox.fromJson({'items': [], 'needsYou': 0, 'withTeam': 0, 'oldestTeamDays': 0}), signals: _signals(), work: _work()));
      expect(_k('ceo_nothing_for_you'), findsOneWidget);
      expect(find.text('Waiting with the team'), findsNothing);
    });
  });

  group('waiting with the team', () {
    testWidgets('what other people are handling, with who has it and how long', (tester) async {
      await _pump(tester);
      expect(find.text('Waiting with the team'), findsOneWidget);
      expect(find.textContaining('The longest has waited 9 days'), findsWidgets);
      expect(find.textContaining('with HR / managers'), findsWidgets);
      expect(find.textContaining('with Accounts'), findsOneWidget);
      expect(find.textContaining('oldest 9 days'), findsWidgets);
    });

    testWidgets('an approval that has waited 3 days or more is picked out in amber; a fresh one is not', (tester) async {
      await _pump(tester);
      // (the stuck ones are listed twice — under "Needs attention" and under the team — both are amber)
      Color? chip(String key) => (tester.widgetList<Container>(_k('ceo_count_$key')).first.decoration as BoxDecoration).color;
      expect(chip('hr_approvals')!.toARGB32() & 0x00FFFFFF, 0xB7791F);
      expect(chip('admin_expenses')!.toARGB32() & 0x00FFFFFF, isNot(0xB7791F));
    });

    testWidgets('an approval with a screen is a link; one nobody on this login can open is not', (tester) async {
      await _pump(tester);
      expect(_k('ceo_item_admin_expenses'), findsOneWidget);
      expect(_k('ceo_item_hr_approvals'), findsNothing);
    });

    testWidgets('the stuck ones (3 days or more) are also in "Needs attention"', (tester) async {
      await _pump(tester);
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('HR approvals (leave, claims, revisions)'), findsNWidgets(2)); // the attention list and the team list
      expect(find.text('Department expenses'), findsOneWidget, reason: 'waited 1 day: only in the team list, not "Needs attention"');
    });
  });

  group('recently decided', () {
    testWidgets('the last decisions, by whichever leader, with who and when', (tester) async {
      await _pump(tester);
      expect(find.text('Recently decided'), findsOneWidget);
      expect(find.text('New van'), findsOneWidget);
      expect(find.textContaining('Anita (CEO) · 10 Nov'), findsOneWidget);
    });

    testWidgets('nothing decided yet: no empty box', (tester) async {
      await _pump(tester, data: _Data(inbox: _inbox(recent: []), signals: _signals(), work: _work()));
      expect(find.text('Recently decided'), findsNothing);
    });
  });

  group('the header', () {
    testWidgets('says who is signed in: the Executive Director sees that title, the CEO theirs', (tester) async {
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..access = const Access(AppRole.ceo, {}, roleKey: 'executive_director'));
      expect(find.text('Executive Director'), findsOneWidget);
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..access = const Access(AppRole.ceo, {}, roleKey: 'ceo'));
      expect(find.text('CEO'), findsOneWidget);
    });

    testWidgets('says when it was last updated', (tester) async {
      await _pump(tester);
      expect(_k('ceo_updated'), findsOneWidget);
    });
  });

  group('the pulse', () {
    testWidgets('revenue, profit, cash and what clients owe — four numbers, each a link', (tester) async {
      await _pump(tester);
      for (final k in ['revenue', 'profit', 'cash', 'owed']) {
        expect(_k('ceo_pulse_$k'), findsOneWidget, reason: k);
      }
      expect(find.descendant(of: _k('ceo_pulse_revenue'), matching: find.text('₹8.2L')), findsOneWidget);
      expect(find.descendant(of: _k('ceo_pulse_revenue'), matching: find.text('82% of target')), findsOneWidget);
      expect(find.descendant(of: _k('ceo_pulse_profit'), matching: find.text('₹2.1L')), findsOneWidget);
      expect(find.descendant(of: _k('ceo_pulse_cash'), matching: find.text('₹24.5L')), findsOneWidget);
      expect(find.descendant(of: _k('ceo_pulse_owed'), matching: find.text('₹6.4L')), findsOneWidget);
      expect(find.descendant(of: _k('ceo_pulse_owed'), matching: find.text('₹2.1L overdue')), findsOneWidget);
    });

    testWidgets('a source that is down shows a dash in its tile; the others still show', (tester) async {
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..reviewFail = true, someSourceIsDown: true);
      expect(find.descendant(of: _k('ceo_pulse_revenue'), matching: find.text('—')), findsOneWidget);
      expect(find.descendant(of: _k('ceo_pulse_cash'), matching: find.text('₹24.5L')), findsOneWidget);
    });
  });

  group('money', () {
    testWidgets('runway and what is overdue (revenue, profit, cash and what is owed are in the pulse, not repeated here)', (tester) async {
      await _pump(tester);
      expect(find.text('Money'), findsOneWidget);
      expect(find.text('9.8 mo'), findsOneWidget);
      expect(find.textContaining('burn ₹2.5L/mo'), findsOneWidget);
      expect(find.text('Over 90 days'), findsOneWidget);
      expect(find.textContaining('chase these first'), findsOneWidget);
      expect(find.text('We owe'), findsOneWidget);
      expect(find.text('Cash + bank'), findsNothing, reason: 'it is in the pulse');
      expect(find.text('CASH + BANK'), findsOneWidget, reason: 'only as the pulse tile');
      expect(find.text('CLIENTS OWE'), findsOneWidget);
      expect(find.text('Clients owe'), findsNothing);
    });

    testWidgets('under target part-way through the month is not red; once the target is reached it is green', (tester) async {
      Color colourOf(String text) => tester.widget<Text>(find.text(text)).style!.color!;
      await _pump(tester);
      expect(colourOf('82% of target'), isNot(kDashBad));
      expect(colourOf('82% of target'), isNot(kDashGood));
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..targetPct = 104);
      expect(colourOf('104% of target'), kDashGood);
    });

    testWidgets('the works that lose money, worst first, and how many in all', (tester) async {
      await _pump(tester);
      expect(find.text('Fathima Rahman'), findsOneWidget);
      expect(find.text('Anjali Menon'), findsOneWidget);
      expect(find.text('BK-1042 · Airbrush bridal'), findsOneWidget);
      expect(find.textContaining('2 works at a loss · 4 on a thin margin'), findsOneWidget);
    });

    testWidgets('no work at a loss: says so', (tester) async {
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work(losses: false)));
      expect(_k('ceo_no_losses'), findsOneWidget);
    });
  });

  group('sales & capacity', () {
    testWidgets('revenue, bookings, enquiries and conversion — with how they moved — and the leaders', (tester) async {
      await _pump(tester);
      expect(find.text('Sales & capacity'), findsOneWidget);
      expect(find.textContaining('+17% vs'), findsWidgets); // revenue 820k vs 700k
      expect(find.text('31'), findsOneWidget); // bookings
      expect(find.text('120'), findsOneWidget); // enquiries
      expect(find.text('26%'), findsOneWidget);
      expect(find.textContaining('Kozhikode · ₹4.1L'), findsOneWidget);
      expect(find.textContaining('Arjun · ₹3.8L'), findsOneWidget);
    });

    testWidgets('slot and artist utilisation', (tester) async {
      await _pump(tester);
      expect(find.text('64%'), findsOneWidget);
      expect(find.text('320 of 500'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('18 of 25'), findsOneWidget);
    });
  });

  group('people & customers', () {
    testWidgets('headcount, what is pending, grievances, joiners and leavers', (tester) async {
      await _pump(tester);
      expect(find.text('People & customers'), findsOneWidget);
      expect(find.text('41'), findsOneWidget);
      expect(find.text('3 joined this month'), findsOneWidget);
      expect(find.text('9'), findsOneWidget); // approvals pending
      expect(find.text('Open grievances'), findsOneWidget);
    });

    testWidgets('NPS with which way it moved since last month, and the scores', (tester) async {
      await _pump(tester);
      expect(find.text('55'), findsWidgets); // the year's NPS
      expect(find.text('NPS, this year'), findsOneWidget);
      expect(find.text('Latest month 58 (−3)'), findsOneWidget); // the latest month against the month before (61 → 58)
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('4.4'), findsOneWidget);
    });
  });

  group('strategy & risks', () {
    testWidgets('projects: active, average progress, past their end date, proposals waiting', (tester) async {
      await _pump(tester);
      expect(find.text('Strategy & risks'), findsOneWidget);
      expect(find.text('Active projects'), findsOneWidget);
      expect(find.text('Past end date'), findsOneWidget);
      expect(find.text('Proposals waiting'), findsOneWidget);
      // 3 not finished (proposed, 2 active); the completed one is left out of the average: (0 + 60 + 40) / 3 = 33
      expect(find.text('33%'), findsOneWidget);
    });

    testWidgets('company objectives only — a project\'s own objective does not count', (tester) async {
      await _pump(tester);
      expect(find.textContaining('2 set · average progress'), findsOneWidget); // not 3
      expect(find.text('35%'), findsOneWidget); // (50 + 20) / 2, not pulled up by the project one at 99
      expect(find.text('Need attention'), findsOneWidget);
    });

    testWidgets('the watch list, worst first, with how each moved; an alert is red', (tester) async {
      await _pump(tester);
      expect(find.text('Watch list'.toUpperCase()), findsOneWidget);
      expect(find.text('Products at or below their stock threshold'), findsNWidgets(2)); // under "Needs attention" and in the list
      final dot = tester.widgetList<Container>(_k('ceo_signal_dot_low_stock')).last;
      expect((dot.decoration as BoxDecoration).color, const Color(0xFFB42318));
      expect(find.textContaining('−3 on before'), findsOneWidget); // cancellations 2 vs 5
      expect(_k('ceo_signal_nps'), findsOneWidget); // has a screen
      expect(_k('ceo_signal_low_stock'), findsNothing); // has none
    });

    testWidgets('a watch list with nothing wrong says "All quiet"', (tester) async {
      await _pump(tester, data: _Data(inbox: _inbox(), signals: [CeoSignal.fromJson({'key': 'low_stock', 'label': 'Low stock', 'value': 0, 'severity': 'ok'})], work: _work()));
      expect(_k('ceo_all_quiet'), findsOneWidget);
    });

    testWidgets('tapping a signal with a screen opens it', (tester) async {
      await _pump(tester, withRoutes: true);
      await tester.ensureVisible(_k('ceo_signal_nps'));
      await tester.pumpAndSettle();
      await tester.tap(_k('ceo_signal_nps'));
      await tester.pumpAndSettle();
      expect(find.text('INSIGHTS SCREEN'), findsOneWidget);
    });
  });

  group('one broken source never blanks the page', () {
    testWidgets('the watch list fails: it says so, with Try again — everything else is still there', (tester) async {
      await _pump(tester, data: _Data(inbox: _inbox(), work: _work())..signalsFail = true, someSourceIsDown: true);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Needs your decision'), findsOneWidget);
      expect(find.text('₹24.5L'), findsOneWidget); // money still shown
      expect(find.text('Active projects'), findsOneWidget);
    });

    testWidgets('the month-end review fails: the money card shows the error, the cash figures below it still load', (tester) async {
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..reviewFail = true, someSourceIsDown: true);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('₹24.5L'), findsOneWidget);
      expect(find.text('Fathima Rahman'), findsOneWidget);
      expect(find.text('Needs your decision'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('a phone (360): one column, nothing overflows, the decisions come first', (tester) async {
      await _pump(tester, size: const Size(360, 2600));
      expect(tester.takeException(), isNull);
      final inbox = tester.getTopLeft(find.text('Needs your decision')).dy;
      final money = tester.getTopLeft(find.text('Money')).dy;
      final sales = tester.getTopLeft(find.text('Sales & capacity')).dy;
      expect(inbox, lessThan(money));
      expect(money, lessThan(sales));
      // one column: the cards share a left edge and are as wide as the screen allows
      final a = tester.getRect(find.ancestor(of: find.text('Money'), matching: find.byType(Container)).first);
      expect(a.width, greaterThan(360 - 40));
    });

    testWidgets('a laptop (1400): the four cards sit two by two under the decisions', (tester) async {
      await _pump(tester);
      expect(tester.takeException(), isNull);
      final money = tester.getTopLeft(find.text('Money'));
      final sales = tester.getTopLeft(find.text('Sales & capacity'));
      final people = tester.getTopLeft(find.text('People & customers'));
      expect(sales.dx, greaterThan(money.dx + 300)); // side by side
      expect((sales.dy - money.dy).abs(), lessThan(6)); // on the same row
      expect(people.dx, money.dx); // the next row starts at the left again
      expect(people.dy, greaterThan(money.dy + 100));
    });

    testWidgets('a tablet (768) is one column and fits', (tester) async {
      await _pump(tester, size: const Size(768, 2600));
      expect(tester.takeException(), isNull);
    });
  });

  group('refresh', () {
    testWidgets('the refresh button reloads the decisions (new items appear)', (tester) async {
      final d = _Data(inbox: _inbox(), signals: _signals(), work: _work());
      await _pump(tester, data: d);
      expect(find.text('Hire a trainer'), findsNothing);
      d.inbox = _inbox(preview: [_req('r9', kind: 'hiring_plan', title: 'Hire a trainer', amount: null)]);
      await tester.tap(_k('ceo_refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Hire a trainer'), findsOneWidget);
      expect(find.text('Studio ring lights'), findsNothing);
    });
  });
}
