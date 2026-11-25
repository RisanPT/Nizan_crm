import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/presentation/screens/finance_head_dashboard_screen.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';
import 'package:nizan_crm/features/finance/services/tax_filing_service.dart';

// The Finance dashboard's balances: each bank row shows the balance NOW — the one the Total adds up (the balance entered from the
// statement plus the ledger's receipts and payments since) — and says what it is made of; an account that only moves when someone types
// a balance, and was last typed over a week ago, says so. The Cash & bank figure on top is the same accounts' (the month-end review
// reads them too), and a month that spent less than it earned says "No burn" instead of a bare dash.

final _now = DateTime.now();

BankAccount _acct(String id, String name, {required double balance, required double current, DateTime? asOf, bool linked = true, int entries = 0, String kind = 'bank', String bank = ''}) => BankAccount.fromJson({
      '_id': id,
      'name': name,
      'kind': kind,
      'bankName': bank,
      'balance': balance,
      'asOf': asOf?.toIso8601String(),
      'currentBalance': current,
      if (linked) 'ledger': {'_id': 'l$id', 'code': '1010', 'name': name},
      if (linked) 'movement': {'in': current - balance > 0 ? current - balance : 0, 'out': 0, 'count': entries},
    });

final _accounts = [
  _acct('a1', 'NIZAN BEAUTY VENTURES PRIVATE LIMITED', balance: 561823, current: 1561824, asOf: DateTime(2026, 10, 1), entries: 24, bank: 'AXIS BANK'),
  _acct('a2', 'CASH IN HAND', balance: 387068, current: 385245, asOf: DateTime(2026, 10, 31), entries: 3, kind: 'cash'),
  _acct('a3', 'PETTY CASH', balance: 20000, current: 20000, asOf: _now.subtract(const Duration(days: 20)), linked: false, kind: 'cash'),
];

Future<void> _pump(WidgetTester t, {Map<String, dynamic>? cashFlow, Map<String, dynamic>? kpis}) async {
  t.view.physicalSize = const Size(1400, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!d.toString().contains('overflowed')) original?.call(d); // the test font is wider than the real one
  };
  addTearDown(() => FlutterError.onError = original);
  final overrides = <Override>[
    monthEndReviewProvider.overrideWith((ref, key) async => MonthEndReview.fromJson({
          'revenue': {'total': 1860000, 'previous': 1080000},
          'profitability': {'netProfit': 1815000, 'netMarginPct': 97.6},
          'cashFlow': cashFlow ?? {'bankBalance': 1561824, 'cashBalance': 405245, 'totalLiquid': 1967069, 'cashSource': 'accounts', 'cashMissing': 0},
          'kpis': kpis ?? {'burnRate': 0, 'cashRunwayMonths': null},
        })),
    bankAccountsProvider.overrideWith((ref) async => BankAccountsResult(accounts: _accounts, totalBalance: 1967069, bankTotal: 1561824, cashTotal: 405245)),
    collectionsProvider.overrideWith((ref) async => const []),
    expensesProvider.overrideWith((ref) async => const []),
    adminExpenseStatsProvider.overrideWith((ref) async => throw Exception('not in this test')),
    taxFilingBoardProvider.overrideWith((ref, key) async => throw Exception('not in this test')),
    openDecisionsProvider.overrideWith((ref) async => const []),
  ];
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: const FinanceHeadDashboardScreen())));
  await t.pumpAndSettle();
}

String _texts(WidgetTester t, Finder f) => t.widgetList<Text>(find.descendant(of: f, matching: find.byType(Text))).map((x) => x.data ?? '').join(' | ');

void main() {
  test('what a bank row\'s balance is made of', () {
    expect(bankRowNote(_accounts[0], now: _now), 'AXIS BANK · 1 Oct balance + 24 entries since');
    expect(bankRowNote(_acct('x', 'X', balance: 5, current: 5, asOf: DateTime(2026, 11, 20), entries: 0), now: _now), 'as of 20 Nov, no entries since');
    expect(bankRowNote(_accounts[2], now: _now), contains('not linked to a ledger — update the balance'), reason: 'typed 20 days ago and nothing moves it');
    expect(bankRowStale(_accounts[2], now: _now), isTrue);
    final fresh = _acct('y', 'Y', balance: 5, current: 5, asOf: _now.subtract(const Duration(days: 2)), linked: false);
    expect([bankRowStale(fresh, now: _now), bankRowNote(fresh, now: _now).contains('update')], [false, false]);
    expect(bankRowStale(_accounts[0], now: _now), isFalse, reason: 'a linked account moves by itself');
  });

  testWidgets('each bank row shows its balance now, so the rows add up to the Total', (t) async {
    await _pump(t);
    expect(_texts(t, find.byKey(const Key('fh_bank_a1'))), allOf(contains('₹15,61,824'), contains('1 Oct balance + 24 entries since')));
    expect(_texts(t, find.byKey(const Key('fh_bank_a1'))), isNot(contains('₹5,61,823')), reason: 'not the balance typed on 1 Oct');
    expect(_texts(t, find.byKey(const Key('fh_bank_a2'))), contains('₹3,85,245'));
    expect(_texts(t, find.byKey(const Key('fh_bank_a3'))), contains('update the balance'));
    expect(_texts(t, find.byKey(const Key('fh_bank_total'))), contains('₹19,67,069'));
    final sum = _accounts.fold<double>(0, (s, a) => s + a.currentBalance);
    expect(sum, 1967069, reason: 'the rows add up to the Total');
  });

  testWidgets('Cash & bank on top is the same figure; a month that spent less than it earned says "No burn"', (t) async {
    await _pump(t);
    expect(find.textContaining('Bank ₹15.6L · Cash ₹4.1L'), findsOneWidget);
    expect(find.text('No burn'), findsOneWidget);
    expect(find.text('Earning more than spending this month'), findsOneWidget);
  });

  testWidgets('a past month whose accounts had no balance yet says so; a burning month shows its runway', (t) async {
    await _pump(t,
        cashFlow: {'bankBalance': 561823, 'cashBalance': 387068, 'totalLiquid': 948891, 'cashSource': 'accounts', 'cashMissing': 1},
        kpis: {'burnRate': 200000, 'cashRunwayMonths': 4.7});
    expect(find.textContaining('1 account had no balance then'), findsOneWidget);
    expect(find.text('4.7 mo'), findsOneWidget);
    expect(find.textContaining('Burn ₹2.0L / month'), findsOneWidget);
  });
}
