import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/work_profit_controller.dart';
import 'package:nizan_crm/features/accounts/data/accounts_dashboard_summary.dart';
import 'package:nizan_crm/features/accounts/data/work_profit.dart';
import 'package:nizan_crm/features/ceo/data/ceo_inbox.dart';
import 'package:nizan_crm/features/ceo/presentation/screens/ceo_home_screen.dart';
import 'package:nizan_crm/features/ceo/services/ceo_service.dart';
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

// The CEO's home: what needs a decision, what is waiting with the team, and the company at a glance. Each card loads and
// fails on its own.

CeoInbox _inbox() => CeoInbox.fromJson({
      'needsYou': 3,
      'withTeam': 7,
      'oldestTeamDays': 9,
      'items': [
        {'key': 'project_proposals', 'owner': 'you', 'label': 'Project proposals to decide', 'count': 2, 'oldestDays': 3, 'route': '/projects'},
        {'key': 'ceo_decisions', 'owner': 'you', 'label': 'Open CEO decisions', 'count': 1, 'amount': 800000, 'oldestDays': 1, 'route': '/ceo/decisions'},
        {'key': 'hr_approvals', 'owner': 'team', 'label': 'HR approvals (leave, claims, revisions)', 'withWhom': 'HR / managers', 'count': 5, 'oldestDays': 9},
        {'key': 'admin_expenses', 'owner': 'team', 'label': 'Department expenses', 'withWhom': 'Accounts', 'count': 2, 'amount': 1200, 'oldestDays': 1, 'route': '/accounts/dashboard'},
      ],
    });

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
    ceoInboxProvider.overrideWith((ref) async => d.inbox ?? _inbox()),
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
              GoRoute(path: '/ceo/decisions', builder: (_, _) => const Scaffold(body: Text('DECISIONS SCREEN'))),
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
    testWidgets('the CEO\'s own decisions, with how many and how old; the team\'s separately, with who has them', (tester) async {
      await _pump(tester);
      expect(find.text('Needs your decision'), findsOneWidget);
      expect(find.text('Project proposals to decide'), findsOneWidget);
      expect(find.text('Open CEO decisions'), findsOneWidget);
      expect(_text(tester, find.descendant(of: _k('ceo_count_project_proposals'), matching: find.byType(Text))), '2');
      expect(find.textContaining('oldest 3 days'), findsOneWidget);
      expect(find.textContaining('₹8.0L'), findsOneWidget); // the capex decision's amount

      expect(find.text('Waiting with the team'), findsOneWidget);
      expect(find.textContaining('The longest has waited 9 days'), findsOneWidget);
      expect(find.textContaining('with HR / managers'), findsOneWidget);
      expect(find.textContaining('with Accounts'), findsOneWidget);
      expect(find.textContaining('oldest 9 days'), findsOneWidget);
    });

    testWidgets('an approval that has waited 3 days or more is picked out in amber; a fresh one is not', (tester) async {
      await _pump(tester);
      Color? chip(String key) => (tester.widget<Container>(_k('ceo_count_$key')).decoration as BoxDecoration).color;
      // HR approvals: 9 days. Department expenses: 1 day.
      expect(chip('hr_approvals')!.toARGB32() & 0x00FFFFFF, 0xB7791F);
      expect(chip('admin_expenses')!.toARGB32() & 0x00FFFFFF, isNot(0xB7791F));
    });

    testWidgets('a decision with a screen is a link; an approval nobody on the CEO login can open is not', (tester) async {
      await _pump(tester);
      expect(_k('ceo_item_project_proposals'), findsOneWidget);
      expect(_k('ceo_item_ceo_decisions'), findsOneWidget);
      expect(_k('ceo_item_admin_expenses'), findsOneWidget);
      expect(_k('ceo_item_hr_approvals'), findsNothing); // no route: just shown, so a stuck approval is seen
    });

    testWidgets('nothing waiting for the CEO: says so, kindly', (tester) async {
      await _pump(tester, data: _Data(inbox: CeoInbox.fromJson({'items': [], 'needsYou': 0, 'withTeam': 0, 'oldestTeamDays': 0})));
      expect(_k('ceo_nothing_for_you'), findsOneWidget);
      expect(find.text('Waiting with the team'), findsNothing);
    });

    testWidgets('tapping a decision opens its screen', (tester) async {
      await _pump(tester, withRoutes: true);
      await tester.tap(_k('ceo_item_project_proposals'));
      await tester.pumpAndSettle();
      expect(find.text('PROJECTS SCREEN'), findsOneWidget);
    });

    testWidgets('…and the CEO Decisions one goes to the decisions log', (tester) async {
      await _pump(tester, withRoutes: true);
      await tester.tap(_k('ceo_item_ceo_decisions'));
      await tester.pumpAndSettle();
      expect(find.text('DECISIONS SCREEN'), findsOneWidget);
    });
  });

  group('money', () {
    testWidgets('revenue and profit against their targets, runway, cash and what is owed', (tester) async {
      await _pump(tester);
      expect(find.text('Money'), findsOneWidget);
      expect(find.text('₹8.2L'), findsWidgets); // revenue (also on the sales card)
      expect(find.textContaining('82% of ₹10.0L target'), findsOneWidget);
      expect(find.text('₹2.1L'), findsWidgets); // profit (and the overdue figure shares the format)
      expect(find.textContaining('70% of ₹3.0L target'), findsOneWidget);
      expect(find.text('9.8 mo'), findsOneWidget);
      expect(find.textContaining('burn ₹2.5L/mo'), findsOneWidget);
      expect(find.text('₹24.5L'), findsOneWidget); // cash + bank
      expect(find.text('₹6.4L'), findsOneWidget); // clients owe
      expect(find.text('Over 90 days'), findsOneWidget);
      expect(find.textContaining('chase these first'), findsOneWidget);
    });

    testWidgets('under target part-way through the month is not red; once the target is reached it is green', (tester) async {
      Color colourOf(String text) => tester.widget<Text>(find.text(text)).style!.color!;
      await _pump(tester);
      expect(colourOf('82% of ₹10.0L target'), isNot(kDashBad));
      expect(colourOf('82% of ₹10.0L target'), isNot(kDashGood));
      await _pump(tester, data: _Data(inbox: _inbox(), signals: _signals(), work: _work())..targetPct = 104);
      expect(colourOf('104% of ₹10.0L target'), kDashGood);
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
      expect(find.text('Products at or below their stock threshold'), findsOneWidget);
      final dot = tester.widget<Container>(_k('ceo_signal_dot_low_stock'));
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
      d.inbox = CeoInbox.fromJson({
        'needsYou': 1,
        'withTeam': 0,
        'oldestTeamDays': 0,
        'items': [
          {'key': 'ceo_decisions', 'owner': 'you', 'label': 'Hire a trainer', 'count': 1, 'route': '/ceo/decisions'}
        ],
      });
      await tester.tap(_k('ceo_refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Hire a trainer'), findsOneWidget);
    });
  });
}
