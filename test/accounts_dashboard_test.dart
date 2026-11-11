import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/data/accounts_dashboard_summary.dart';
import 'package:nizan_crm/features/accounts/data/dashboard_series.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/combined_accounts_dashboard_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/dashboard_charts.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';

// Accounts → Combined Dashboard: the figures worked out for it (money formats, the change against the earlier period,
// the trend chart's points, the expense lines the design groups, the downloaded report) and the screen itself.

Map<String, dynamic> _line(String key, String label, num amount, [int count = 0, bool estimated = false]) =>
    {'key': key, 'label': label, 'amount': amount, 'count': count, if (estimated) 'estimated': true};

Map<String, dynamic> _party(String name, num overdue, int days) => {'name': name, 'phone': '', 'outstanding': overdue, 'overdue': overdue, 'oldestDays': days};

/// A November like the design's: income 53,000, expense 22,500, net 30,500; receivables 2.36 Cr, cash & bank 14.1 L.
Map<String, dynamic> _json({bool withPrevious = true, bool payablesEmpty = true, int days = 30}) => {
      'from': '2026-11-01',
      'to': '2026-11-30',
      'income': {
        'total': 53000,
        'items': [
          _line('collections', 'Booking collections', 35000, 1),
          _line('advances', 'Booking advances', 18000, 6),
          _line('trial_fees', 'Trial fees', 0),
          _line('other_income', 'Other income (Cash In)', 0),
        ],
      },
      'expense': {
        'total': 22500,
        'items': [
          _line('salaries', 'Salaries', 6000, 2),
          _line('admin_expenses', 'Office & admin expenses', 1500, 3),
          _line('artist_expenses', 'Artist expenses', 1203, 4),
          _line('artist_payouts', 'Artist payouts', 0),
          _line('fleet', 'Fleet & fuel', 0),
          _line('hra', 'HRA', 0),
          _line('vendor_bills', 'Vendor bills', 0),
          _line('subscriptions', 'Subscriptions', 13797, 3, true),
          _line('refunds', 'Customer refunds', 0),
          _line('cash_out', 'Other expenses (Cash Out)', 0),
        ],
      },
      'net': 30500,
      'pending': {
        'total': 137150,
        'items': [
          _line('collections', 'Collections to verify', 127250, 5),
          _line('admin_expenses', 'Admin expenses to approve', 0),
          _line('artist_expenses', 'Artist expenses to verify', 100, 1),
          _line('fleet', 'Fleet expenses to approve', 9800, 6),
        ],
      },
      'cashBank': {'total': 1410000, 'bank': 1300000, 'cash': 110000},
      'receivables': {
        'totalOutstanding': 23634500,
        'totalOverdue': 9575500,
        'totalNotYetDue': 14059000,
        'buckets': {'current': 896000, 'days30': 359000, 'days60': 1285500, 'days90': 7035000},
        'partyCount': 40,
        'top': [
          _party('Ashna', 129000, 208),
          _party('Sruthy', 111000, 198),
          _party('Archana', 100500, 208),
          _party('Aparna', 95000, 193),
          _party('Priyanka', 90000, 215),
        ],
      },
      'payables': payablesEmpty
          ? {'totalOutstanding': 0, 'totalOverdue': 0, 'totalNotYetDue': 0, 'buckets': {'current': 0, 'days30': 0, 'days60': 0, 'days90': 0}, 'partyCount': 0, 'top': []}
          : {
              'totalOutstanding': 52000,
              'totalOverdue': 12000,
              'totalNotYetDue': 40000,
              'buckets': {'current': 12000, 'days30': 0, 'days60': 0, 'days90': 0},
              'partyCount': 2,
              'top': [_party('Vendor A', 12000, 40)],
            },
      'series': [
        for (var d = 1; d <= days; d++)
          {
            'date': '2026-11-${d.toString().padLeft(2, '0')}',
            'income': d == 2 ? 35000 : (d == 4 ? 18000 : 0),
            'incomeCount': d == 2 ? 1 : (d == 4 ? 6 : 0),
            'expense': d == 3 ? 8700 : (d == 9 ? 13800 : 0),
            'expenseCount': d == 3 ? 5 : (d == 9 ? 3 : 0),
          },
      ],
      'previous': withPrevious
          ? {
              'from': '2026-10-01',
              'to': '2026-10-30',
              'mode': 'month',
              'days': 30,
              'income': 47321.43,
              'expense': 21226.42,
              'net': 26095.0,
              'currentIncome': 53000,
              'currentExpense': 22500,
              'currentNet': 30500,
            }
          : null,
    };

AccountsDashboardSummary _summary({bool withPrevious = true, bool payablesEmpty = true, int days = 30}) =>
    AccountsDashboardSummary.fromJson(_json(withPrevious: withPrevious, payablesEmpty: payablesEmpty, days: days));

void main() {
  group('how money is written', () {
    test('in full: whole rupees with Indian grouping', () {
      expect(inrFull(53000), '₹53,000');
      expect(inrFull(23634500), '₹2,36,34,500');
      expect(inrFull(-1250.4), '-₹1,250');
      expect(inrFull(0), '₹0');
    });

    test('compact, for a big number on a card: full under a lakh, then lakhs, then crores', () {
      expect(inrCompact(0), '₹0');
      expect(inrCompact(53000), '₹53,000');
      expect(inrCompact(99999), '₹99,999');
      expect(inrCompact(100000), '₹1.0 L');
      expect(inrCompact(1410000), '₹14.1 L');
      expect(inrCompact(23634500), '₹2.36 Cr');
      expect(inrCompact(-30500), '-₹30,500');
      expect(inrCompact(-250000), '-₹2.5 L');
    });

    test('on the chart axis: ₹0, ₹500, ₹20k, ₹1.5L, ₹2Cr', () {
      expect(axisMoney(0), '₹0');
      expect(axisMoney(500), '₹500');
      expect(axisMoney(20000), '₹20k');
      expect(axisMoney(2500), '₹2.5k');
      expect(axisMoney(150000), '₹1.5L');
      expect(axisMoney(20000000), '₹2Cr');
    });
  });

  group('the change against the earlier period', () {
    test('up and down, in percent', () {
      expect(pctChange(112, 100), closeTo(12, 1e-9));
      expect(pctChange(94, 100), closeTo(-6, 1e-9));
      expect(pctChange(100, 100), 0);
    });

    test('nothing to measure against: no percentage', () {
      expect(pctChange(500, 0), isNull);
      expect(pctChange(0, 0), isNull);
    });

    test('a loss that got smaller is an improvement (the base is its size, not its sign)', () {
      expect(pctChange(-50, -100), closeTo(50, 1e-9));
      expect(pctChange(-150, -100), closeTo(-50, 1e-9));
    });

    test('written as +12%, −6%; under 1% keeps a decimal so a small move is not "0%"', () {
      expect(pctText(12.4), '+12%');
      expect(pctText(-6), '−6%');
      expect(pctText(0.4), '+0.4%');
      expect(pctText(-0.4), '−0.4%');
      expect(pctText(0), '+0.0%');
    });

    test('what it is measured against, in words', () {
      PeriodComparison cmp(String mode, String from, String to) =>
          PeriodComparison(from: from, to: to, mode: mode, days: 5, income: 0, expense: 0, net: 0, currentIncome: 0, currentExpense: 0, currentNet: 0);
      expect(comparisonText(cmp('month', '2026-10-01', '2026-10-05')), 'the same days of the month before (1 Oct – 5 Oct 2026)');
      expect(comparisonText(cmp('fy', '2025-04-01', '2025-11-05')), 'the same dates a year earlier (1 Apr – 5 Nov 2025)');
      expect(comparisonText(cmp('preceding', '2026-10-27', '2026-11-02')), 'the period just before (27 Oct – 2 Nov 2026)');
      expect(comparisonText(cmp('preceding', '2026-11-04', '2026-11-04')), 'the period just before (4 Nov)');
    });
  });

  group('reading the summary', () {
    test('the daily series and the comparison come through', () {
      final s = _summary();
      expect(s.series, hasLength(30));
      expect(s.series[1].date, DateTime(2026, 11, 2));
      expect([s.series[1].income, s.series[1].incomeCount], [35000, 1]);
      expect(s.previous!.mode, 'month');
      expect(s.previous!.income, closeTo(47321.43, 1e-6));
      expect(s.previous!.currentNet, 30500);
    });

    test('an older server (no series, no previous) still reads', () {
      final j = _json()..remove('series')..remove('previous');
      final s = AccountsDashboardSummary.fromJson(j);
      expect(s.series, isEmpty);
      expect(s.previous, isNull);
      expect(s.income.total, 53000);
    });
  });

  group('the trend chart\'s points', () {
    List<DayPoint> days(int n, {DateTime? start}) => [
          for (var i = 0; i < n; i++)
            DayPoint(date: (start ?? DateTime(2026, 11, 1)).add(Duration(days: i)), income: 100.0 + i, expense: 10, incomeCount: 1, expenseCount: 2),
        ];

    test('a month or less: a point per day, labelled "Nov 3"', () {
      final b = bucketSeries(days(30));
      expect(b, hasLength(30));
      expect(b[2].label, 'Nov 3');
      expect(b[2].tooltip, 'Tue, 3 Nov 2026');
      expect([b[2].income, b[2].expense, b[2].incomeCount], [102, 10, 1]);
    });

    test('up to 62 days stays daily; past that it is weekly', () {
      expect(bucketSeries(days(62)), hasLength(62));
      final w = bucketSeries(days(90));
      expect(w, hasLength(13));
      expect(w.first.income, 100 + 101 + 102 + 103 + 104 + 105 + 106);
      expect(w.first.expenseCount, 14);
      expect(w.last.start, DateTime(2026, 11, 1).add(const Duration(days: 84)), reason: 'the last, short week');
      expect(w.fold<double>(0, (s, x) => s + x.income), days(90).fold<double>(0, (s, x) => s + x.income), reason: 'nothing is lost in the grouping');
    });

    test('a financial year: a point per month, and nothing lost', () {
      final y = days(219, start: DateTime(2026, 4, 1));
      final m = bucketSeries(y);
      expect(m, hasLength(8), reason: 'Apr … Nov');
      expect(m.first.label, 'Apr');
      expect(m.first.tooltip, 'April 2026');
      expect(m.first.income, 100.0 * 30 + (29 * 30 / 2), reason: 'the 30 days of April');
      expect(m.fold<double>(0, (s, x) => s + x.income), y.fold<double>(0, (s, x) => s + x.income));
    });

    test('over a year, the month label carries the year', () {
      expect(bucketSeries(days(400, start: DateTime(2025, 4, 1))).first.label, 'Apr 25');
    });

    test('no days: no points', () => expect(bucketSeries(const []), isEmpty));

    test('the y axis ends on a round number above the highest point, with round gridlines', () {
      expect(niceScale(0).max, 100);
      var s = niceScale(35000);
      expect(s.max, greaterThan(35000));
      expect(s.max % s.step, 0);
      expect(s.step, 10000);
      s = niceScale(80000);
      expect([s.max, s.step], [100000, 20000]);
      expect(niceScale(7).max, greaterThan(7));
    });
  });

  group('the breakdown cards', () {
    test('income: its lines as they come', () {
      final l = incomeBreakdown(_summary().income);
      expect(l.map((x) => x.label), ['Booking collections', 'Booking advances', 'Trial fees', 'Other income (Cash In)']);
      expect([l[1].amount, l[1].count], [18000, 6]);
    });

    test('expense: the five main lines, then everything else as "Others"', () {
      final l = expenseBreakdown(_summary().expense);
      expect(l.map((x) => x.label), ['Salaries', 'Office & admin expenses', 'Artist expenses', 'Artist payouts', 'Fleet & fuel', 'Others']);
      expect(l[2].count, 4);
      expect(l.last.amount, 13797, reason: 'the subscription estimate');
      expect(l.last.estimated, isTrue);
      expect(l.last.detail, 'Subscriptions ₹13,797 (est.)');
      expect(l.fold<double>(0, (s, x) => s + x.amount), 22500, reason: 'grouping loses no money');
    });

    test('"Others" with nothing in it has no detail and is not an estimate', () {
      final j = _json();
      for (final i in (j['expense'] as Map)['items'] as List) {
        if (i['key'] == 'subscriptions') {
          i['amount'] = 0;
          i['estimated'] = false;
        }
      }
      final l = expenseBreakdown(AccountsDashboardSummary.fromJson(j).expense);
      expect([l.last.amount, l.last.estimated, l.last.detail], [0, false, '']);
    });
  });

  group('the downloaded report', () {
    test('every line (not grouped), the totals, the result, the dues, the balances and what awaits approval', () {
      final r = buildDashboardReport(_summary(), 'November 2026');
      expect(r.title, 'Combined Accounts Report — November 2026');
      expect(r.fileBase, 'combined_accounts_november_2026');
      expect(r.headers, ['Section', 'Item', 'Count', 'Amount (INR)']);
      List<dynamic> row(String section, String item) => r.rows.firstWhere((x) => x[0] == section && x[1] == item);
      expect(row('Income', 'Booking advances'), ['Income', 'Booking advances', 6, '18000.00']);
      expect(row('Income', 'Total income')[3], '53000.00');
      expect(row('Expense', 'Subscriptions (estimate)')[3], '13797.00');
      expect(row('Expense', 'Total expense')[3], '22500.00');
      expect(row('Result', 'Net profit')[3], '30500.00');
      expect(row('Dues (today)', 'Receivables outstanding')[3], '23634500.00');
      expect(row('Balances (today)', 'Cash & bank')[3], '1410000.00');
      expect(row('Awaiting approval', 'Total pending')[3], '137150.00');
      expect(r.rows.where((x) => x[0] == 'Compared with'), hasLength(2));
    });

    test('a loss is called a loss; with no earlier period there is no comparison', () {
      final j = _json(withPrevious: false);
      j['net'] = -1000;
      final r = buildDashboardReport(AccountsDashboardSummary.fromJson(j), 'FY 2026-27');
      expect(r.rows.firstWhere((x) => x[0] == 'Result')[1], 'Net loss');
      expect(r.rows.where((x) => x[0] == 'Compared with'), isEmpty);
      expect(r.fileBase, 'combined_accounts_fy_2026_27');
    });
  });

  group('the screen', () {
    late List<({String from, String to})> asked;
    final iso = DateFormat('yyyy-MM-dd');

    Future<void> open(WidgetTester tester, {AccountsDashboardSummary? summary, Size size = const Size(1500, 1500)}) async {
      asked = [];
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final data = summary ?? _summary();
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const CombinedAccountsDashboardScreen()),
        GoRoute(path: '/company-finance/bank-balance', builder: (_, _) => const Scaffold(body: Text('BANK BALANCE SCREEN'))),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWithValue(const AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'admin')),
            accountsDashboardSummaryProvider.overrideWith((ref, key) async {
              asked.add(key);
              return data;
            }),
          ],
          child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    CrmTheme crmOf(WidgetTester t) => AppTheme.lightTheme.extension<CrmTheme>()!;
    String textIn(WidgetTester t, Key k) => t.widgetList<Text>(find.descendant(of: find.byKey(k), matching: find.byType(Text))).map((x) => x.data ?? x.textSpan?.toPlainText() ?? '').join('|');

    testWidgets('the header: breadcrumb, title, the period, the month menu and Download Report', (tester) async {
      await open(tester);
      expect(find.text('Combined Accounts Dashboard'), findsOneWidget);
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Combined Dashboard'), findsOneWidget);
      final month = DateFormat('MMMM yyyy').format(DateTime.now());
      expect(find.text('Company income, expenses and dues · $month'), findsOneWidget);
      expect(textIn(tester, const Key('month_menu')), month);
      expect(find.text('Download Report'), findsOneWidget);
      expect(find.byKey(const Key('period_this_month')), findsOneWidget);
      expect(find.byKey(const Key('period_last_month')), findsOneWidget);
      expect(find.byKey(const Key('period_fy')), findsOneWidget);
      expect(find.byKey(const Key('period_custom')), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Custom range'), findsOneWidget);
    });

    testWidgets('three headline figures with the change against the earlier period', (tester) async {
      await open(tester);
      expect(textIn(tester, const Key('kpi_income')), contains('₹53,000'));
      expect(textIn(tester, const Key('kpi_expense')), contains('₹22,500'));
      expect(textIn(tester, const Key('kpi_net')), contains('₹30,500'));
      expect(textIn(tester, const Key('delta_income')), '+12%');
      expect(textIn(tester, const Key('delta_expense')), '+6%');
      expect(textIn(tester, const Key('delta_net')), '+17%'); // 30,500 vs 26,095
    });

    testWidgets('green when the move is good news: more income and profit are green, MORE EXPENSE is red', (tester) async {
      await open(tester);
      final crm = crmOf(tester);
      Color colorOf(String k) => tester.widget<Text>(find.descendant(of: find.byKey(Key(k)), matching: find.byType(Text))).style!.color!;
      expect(colorOf('delta_income'), crm.success);
      expect(colorOf('delta_expense'), crm.destructive);
      expect(colorOf('delta_net'), crm.success);
    });

    testWidgets('less expense is green too; a drop in income is red', (tester) async {
      final j = _json();
      (j['previous'] as Map)['expense'] = 30000;
      (j['previous'] as Map)['income'] = 70000;
      await open(tester, summary: AccountsDashboardSummary.fromJson(j));
      final crm = crmOf(tester);
      Color colorOf(String k) => tester.widget<Text>(find.descendant(of: find.byKey(Key(k)), matching: find.byType(Text))).style!.color!;
      expect(textIn(tester, const Key('delta_expense')), '−25%');
      expect(colorOf('delta_expense'), crm.success);
      expect(textIn(tester, const Key('delta_income')), '−24%');
      expect(colorOf('delta_income'), crm.destructive);
    });

    testWidgets('no earlier period, no percentages — and no invented ones', (tester) async {
      await open(tester, summary: _summary(withPrevious: false));
      expect(find.byKey(const Key('delta_income')), findsNothing);
      expect(find.byKey(const Key('delta_expense')), findsNothing);
      expect(find.byKey(const Key('delta_net')), findsNothing);
      expect(textIn(tester, const Key('kpi_income')), contains('₹53,000'));
    });

    testWidgets('nothing in the earlier period either: no percentage, not a division by zero', (tester) async {
      final j = _json();
      (j['previous'] as Map)['income'] = 0;
      await open(tester, summary: AccountsDashboardSummary.fromJson(j));
      expect(find.byKey(const Key('delta_income')), findsNothing);
      expect(find.byKey(const Key('delta_expense')), findsOneWidget);
    });

    testWidgets('receivables, payables and cash & bank, in lakhs and crores', (tester) async {
      await open(tester);
      expect(textIn(tester, const Key('kpi_receivables')), contains('₹2.36 Cr'));
      expect(textIn(tester, const Key('kpi_payables')), contains('₹0'));
      expect(textIn(tester, const Key('kpi_cash')), contains('₹14.1 L'));
      expect(textIn(tester, const Key('kpi_cash')), contains('Bank ₹13.0 L · Cash ₹1.1 L'));
    });

    testWidgets('the trend chart switches between Amount and Count', (tester) async {
      await open(tester);
      TrendChart chart() => tester.widget<TrendChart>(find.byKey(const Key('trend_chart')));
      expect(chart().amount, isTrue);
      expect(chart().buckets, hasLength(30));
      await tester.tap(find.byKey(const Key('trend_count')));
      await tester.pumpAndSettle();
      expect(chart().amount, isFalse);
      await tester.tap(find.byKey(const Key('trend_amount')));
      await tester.pumpAndSettle();
      expect(chart().amount, isTrue);
    });

    testWidgets('the ring: income against expense with their shares', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('donut')), findsOneWidget);
      final t = textIn(tester, const Key('card_donut'));
      expect(t, contains('Income vs Expense (Total)'));
      expect(t, contains('₹53,000'));
      expect(t, contains('70.2%'));
      expect(t, contains('29.8%'));
    });

    testWidgets('the breakdown: income lines, expense lines with "Others", and the net summary', (tester) async {
      await open(tester);
      final income = textIn(tester, const Key('card_income_breakdown'));
      expect(income, contains('Booking collections'));
      expect(income, contains('Booking advances'));
      expect(income, contains('(6)'));
      expect(income, contains('₹18,000'));
      expect(income, contains('Total Income'));
      expect(income, contains('₹53,000'));

      final expense = textIn(tester, const Key('card_expense_breakdown'));
      expect(expense, contains('Salaries'));
      expect(expense, contains('Artist expenses'));
      expect(expense, contains('(4)'));
      expect(expense, contains('Others'));
      expect(expense, contains('₹13,797'));
      expect(expense, contains('Total Expense'));
      expect(expense, contains('₹22,500'));
      expect(find.byTooltip('Subscriptions ₹13,797 (est.)'), findsOneWidget, reason: 'what is inside "Others"');

      final net = textIn(tester, const Key('card_net_summary'));
      expect(net, contains('Total Income'));
      expect(net, contains('Total Expense'));
      expect(net, contains('Net Profit / Loss'));
      expect(net, contains('₹30,500'));
      expect(net, contains('+17%'));
    });

    testWidgets('a loss shows as a loss in red', (tester) async {
      final j = _json();
      j['net'] = -4000;
      await open(tester, summary: AccountsDashboardSummary.fromJson(j));
      expect(textIn(tester, const Key('kpi_net')), contains('-₹4,000'));
      expect(textIn(tester, const Key('card_net_summary')), contains('Net Loss'));
    });

    testWidgets('the period pills ask the server for that period', (tester) async {
      await open(tester);
      final now = DateTime.now();
      expect(asked.last, (from: iso.format(DateTime(now.year, now.month, 1)), to: iso.format(DateTime(now.year, now.month + 1, 0))));
      await tester.tap(find.byKey(const Key('period_last_month')));
      await tester.pumpAndSettle();
      expect(asked.last, (from: iso.format(DateTime(now.year, now.month - 1, 1)), to: iso.format(DateTime(now.year, now.month, 0))));
      expect(find.text('Company income, expenses and dues · ${DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1, 1))}'), findsOneWidget);
      await tester.tap(find.byKey(const Key('period_fy')));
      await tester.pumpAndSettle();
      final fyStart = now.month >= 4 ? now.year : now.year - 1;
      expect(asked.last.from, '$fyStart-04-01');
      expect(asked.last.to, iso.format(DateTime(now.year, now.month, now.day)));
      expect(textIn(tester, const Key('month_menu')), 'FY $fyStart-${(fyStart + 1) % 100}');
    });

    testWidgets('the month menu lists the last twelve months; picking an old one asks for that whole month', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('month_menu')));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<DateTime>), findsNWidgets(12));
      final now = DateTime.now();
      final target = DateTime(now.year, now.month - 3, 1);
      await tester.tap(find.widgetWithText(PopupMenuItem<DateTime>, DateFormat('MMMM yyyy').format(target)));
      await tester.pumpAndSettle();
      expect(asked.last, (from: iso.format(target), to: iso.format(DateTime(target.year, target.month + 1, 0))));
      expect(textIn(tester, const Key('month_menu')), DateFormat('MMMM yyyy').format(target));
      // and this month, from the menu, is the same as the "This month" pill
      await tester.tap(find.byKey(const Key('month_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<DateTime>, DateFormat('MMMM yyyy').format(now)));
      await tester.pumpAndSettle();
      expect(textIn(tester, const Key('month_menu')), DateFormat('MMMM yyyy').format(now));
      expect(find.text('Company income, expenses and dues · ${DateFormat('MMMM yyyy').format(now)}'), findsOneWidget);
    });

    testWidgets('"Custom range" opens the date range picker', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('period_custom')));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    });

    testWidgets('Download Report offers a PDF and a CSV', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('download_report')));
      await tester.pumpAndSettle();
      expect(find.text('Download as PDF'), findsOneWidget);
      expect(find.text('Download as CSV'), findsOneWidget);
    });

    testWidgets('Cash & Bank opens the bank balance screen; the breadcrumb home goes home', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('kpi_cash')));
      await tester.pumpAndSettle();
      expect(find.text('BANK BALANCE SCREEN'), findsOneWidget);
    });

    testWidgets('Receivables and Payables open the dues view', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('card_receivables')), findsNothing);
      await tester.tap(find.byKey(const Key('kpi_receivables')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card_receivables')), findsOneWidget);
      await tester.tap(find.byKey(const Key('view_overview')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kpi_income')), findsOneWidget);
      await tester.tap(find.byKey(const Key('kpi_payables')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card_payables')), findsOneWidget);
    });

    testWidgets('Dues & approvals: the four figures', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('view_dues')));
      await tester.pumpAndSettle();
      expect(textIn(tester, const Key('dues_kpi_receivables')), contains('₹2,36,34,500'));
      expect(textIn(tester, const Key('dues_kpi_overdue')), contains('₹95,75,500'));
      expect(textIn(tester, const Key('dues_kpi_not_due')), contains('₹1,40,59,000'));
      expect(textIn(tester, const Key('dues_kpi_pending')), contains('₹1,37,150'));
    });

    testWidgets('Dues & approvals: receivables aged, the top overdue customers, payables, and what awaits approval', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('view_dues')));
      await tester.pumpAndSettle();
      final rec = textIn(tester, const Key('card_receivables'));
      expect(rec, contains('Customers who owe us'));
      expect(rec, contains('Outstanding'));
      expect(rec, contains('0 – 30 days'));
      expect(rec, contains('90+ days'));
      expect(rec, contains('₹70,35,000'));

      final top = textIn(tester, const Key('card_top_overdue'));
      expect(top, contains('Top 5 Overdue Customers'));
      expect(top, contains('Ashna'));
      expect(top, contains('208d overdue'));
      expect(top, contains('₹1,29,000'));
      expect(top, contains('AS'), reason: 'initials');

      expect(textIn(tester, const Key('card_payables')), contains('Nothing outstanding.'));

      final awaiting = textIn(tester, const Key('card_awaiting'));
      expect(awaiting, contains('Not counted in income or expense until approved'));
      expect(awaiting, contains('Collections to verify'));
      expect(awaiting, contains('₹1,27,250'));
      expect(awaiting, contains('Fleet expenses to approve'));
      expect(awaiting, isNot(contains('Admin expenses to approve')), reason: 'a ₹0 line is left out');
      expect(awaiting, contains('Total Pending'));
      expect(awaiting, contains('₹1,37,150'));
    });

    testWidgets('payables with something owed show their ageing instead of "Nothing outstanding."', (tester) async {
      await open(tester, summary: _summary(payablesEmpty: false));
      await tester.tap(find.byKey(const Key('view_dues')));
      await tester.pumpAndSettle();
      final pay = textIn(tester, const Key('card_payables'));
      expect(pay, isNot(contains('Nothing outstanding.')));
      expect(pay, contains('₹52,000'));
      expect(pay, contains('Vendors we owe'));
    });

    testWidgets('customers who are not overdue are not in the overdue list; none overdue says so', (tester) async {
      final j = _json();
      (j['receivables'] as Map)['top'] = [_party('On time Ltd', 0, 0)];
      await open(tester, summary: AccountsDashboardSummary.fromJson(j));
      await tester.tap(find.byKey(const Key('view_dues')));
      await tester.pumpAndSettle();
      expect(textIn(tester, const Key('card_top_overdue')), contains('No overdue customers.'));
      expect(textIn(tester, const Key('card_top_overdue')), isNot(contains('On time Ltd')));
    });

    testWidgets('nothing waiting for approval says so', (tester) async {
      final j = _json();
      j['pending'] = {'total': 0, 'items': <dynamic>[]};
      await open(tester, summary: AccountsDashboardSummary.fromJson(j));
      await tester.tap(find.byKey(const Key('view_dues')));
      await tester.pumpAndSettle();
      expect(textIn(tester, const Key('card_awaiting')), contains('Nothing is waiting for approval.'));
    });

    testWidgets('a financial year (219 days) draws a point per month', (tester) async {
      await open(tester, summary: _summary(days: 30));
      await tester.tap(find.byKey(const Key('period_fy')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final view in ['view_overview', 'view_dues']) {
      testWidgets('on a phone nothing overflows ($view)', (tester) async {
        await open(tester, size: const Size(390, 2400));
        await tester.tap(find.byKey(Key(view)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Combined Accounts Dashboard'), findsOneWidget);
      });
    }

    testWidgets('on a tablet the cards fall back to two columns without overflow', (tester) async {
      await open(tester, size: const Size(760, 2400));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('card_net_summary')), findsOneWidget);
    });
  });
}
