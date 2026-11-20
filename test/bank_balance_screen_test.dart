import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/presentation/screens/bank_balance_screen.dart';
import 'package:nizan_crm/features/finance/presentation/screens/bank_transactions_screen.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/bank_transactions_view.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';

// Finance → Bank & Cash Balance, redesigned: totals against last month, the accounts, the chosen
// account's transactions beside them (each saying what it was for), and the whole list on a screen of
// its own. These drive both screens against a pretend server that records every question it is asked.

final _axis = BankAccount.fromJson({
  '_id': 'b1', 'name': 'NIZAN BEAUTY VENTURES', 'kind': 'bank', 'bankName': 'AXIS BANK', 'accountNumber': '918020033928',
  'balance': 1035000, 'asOf': '2026-10-31T00:00:00.000Z', 'currentBalance': 1088941, 'previousBalance': 1035000,
  'ledger': {'_id': 'l1', 'code': 'BNK-01', 'name': 'AXIS BANK'},
});
final _cash = BankAccount.fromJson({
  '_id': 'c1', 'name': 'Cash in Hand', 'kind': 'cash', 'balance': 387068, 'asOf': '2026-10-31T00:00:00.000Z', 'currentBalance': 427016, 'previousBalance': 390300,
  'ledger': {'_id': 'l2', 'code': 'CSH-01', 'name': 'CASH IN HAND'},
});
final _petty = BankAccount.fromJson({'_id': 'c2', 'name': 'Petty Cash', 'kind': 'cash', 'balance': 12500, 'asOf': '2026-10-31T00:00:00.000Z', 'currentBalance': 12500});

Map<String, dynamic> _expense(int i) => {
      'id': 'x$i', 'date': '2026-11-15T06:30:00.000Z', 'voucherNo': 'PAY/2026-27/0${282 - i}', 'in': 0, 'out': 1400, 'balance': 428516 + i,
      'kind': 'artist_expense', 'kindLabel': 'Artist expense', 'particulars': 'Artist expense · Food', 'title': 'Megha', 'client': 'Megha', 'bookingNumber': '2604161274',
      'person': {'id': 'e1', 'name': 'Anjali TK', 'role': 'Artist'}, 'personKey': 'e1', 'group': 'artist_expense:food', 'groupLabel': 'Artist expense · Food',
      'loggedAmount': 1517, 'notes': 'afternoon fd 4 person', 'attachmentUrl': 'https://example.test/bill.jpg',
      'details': [
        {'label': 'Artist', 'value': 'Anjali TK'},
        {'label': 'Client / work', 'value': 'Megha'},
        {'label': 'Logged amount', 'value': '₹1,517'},
        {'label': 'Approved amount', 'value': '₹1,400'},
        {'label': 'Why it was reduced', 'value': 'Over the meal limit'},
        {'label': 'Voucher', 'value': 'PAY/2026-27/0282'},
      ],
    };

Map<String, dynamic> _collection(int i) => {
      'id': 'k$i', 'date': '2026-11-06T06:30:00.000Z', 'voucherNo': 'RCV/2026-27/0320', 'in': 28500, 'out': 0, 'balance': 437915,
      'kind': 'collection', 'kindLabel': 'Collection', 'particulars': 'Collection · Booking', 'title': 'Gayathri', 'client': 'Gayathri', 'bookingNumber': 'BK-77',
      'person': {'id': 'e2', 'name': 'Anaswara', 'role': 'Collected by'}, 'personKey': 'e2', 'group': 'collection:booking', 'groupLabel': 'Collection · Booking', 'reference': 'UTR-778',
      'details': [
        {'label': 'Client', 'value': 'Gayathri'},
        {'label': 'Collected by', 'value': 'Anaswara'},
        {'label': 'Payment mode', 'value': 'UPI'},
      ],
    };

/// The pretend server: 36 transactions, paged the way the real one is; remembers every query.
class _Server {
  final asked = <BankTxnQuery>[];
  int total = 36;
  bool fail = false;
  double? opening = 387068;

  BankTxnResult statement(BankTxnQuery q) {
    asked.add(q);
    if (fail) throw Exception('down');
    final n = q.isFiltered ? 3 : total;
    final rows = [for (var i = 0; i < n; i++) i == 1 ? _collection(i) : _expense(i)];
    final pages = n == 0 ? 1 : (n / q.limit).ceil();
    return BankTxnResult.fromJson({
      'since': q.from == null ? '2026-10-31T00:00:00.000Z' : null,
      'opening': q.from == null ? opening : null,
      'closing': 427016,
      'rows': rows.skip((q.page - 1) * q.limit).take(q.limit).toList(),
      'page': q.page, 'limit': q.limit, 'totalItems': n, 'totalPages': pages,
      'totals': {'in': 28500, 'out': 49000, 'count': n},
      'allTotals': {'in': 256500, 'out': 216552, 'count': total},
      'facets': {
        'groups': [{'key': 'artist_expense:food', 'label': 'Artist expense · Food', 'count': 35}, {'key': 'collection:booking', 'label': 'Collection · Booking', 'count': 1}],
        'people': [{'key': 'e1', 'name': 'Anjali TK', 'count': 35}, {'key': 'e2', 'name': 'Anaswara', 'count': 1}],
      },
    });
  }
}

Future<GoRouter> _open(WidgetTester t, _Server server, {double width = 1400, double height = 1400, List<BankAccount>? accounts, String start = '/company-finance/bank-balance', PreviousBalances? previous}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final list = accounts ?? [_axis, _cash, _petty];
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(path: '/company-finance/bank-balance', builder: (_, _) => const BankBalanceScreen()),
      GoRoute(path: '/company-finance/bank-balance/:accountId/transactions', builder: (_, s) => BankTransactionsScreen(accountId: s.pathParameters['accountId'] ?? '')),
      GoRoute(path: '/company-finance/ledger', builder: (_, s) => Scaffold(body: Text('LEDGER ${s.uri.queryParameters['account']}'))),
    ],
  );
  await t.pumpWidget(ProviderScope(
    overrides: [
      bankAccountsProvider.overrideWith((ref) async => BankAccountsResult(
            accounts: list,
            totalBalance: list.fold(0, (a, b) => a + b.currentBalance),
            bankTotal: list.where((a) => !a.isCash).fold(0, (a, b) => a + b.currentBalance),
            cashTotal: list.where((a) => a.isCash).fold(0, (a, b) => a + b.currentBalance),
            previous: previous ?? const PreviousBalances(asOf: '2026-10-31', total: 1437800, bank: 1035000, cash: null),
          )),
      bankStatementProvider.overrideWith((ref, q) async => server.statement(q)),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  ));
  await t.pumpAndSettle();
  return router;
}

String _path(GoRouter r) => r.routerDelegate.currentConfiguration.uri.toString();
final _sideways = find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
String _text(WidgetTester t, Key k) => t.widget<Text>(find.byKey(k)).data ?? t.widget<Text>(find.byKey(k)).textSpan!.toPlainText();

void main() {
  group('the helpers', () {
    test('percent against last month — and nothing to say when there is nothing to compare with', () {
      expect(percentChange(110, 100), closeTo(10, 1e-9));
      expect(percentChange(90, 100), closeTo(-10, 1e-9));
      expect(percentChange(100, null), isNull);
      expect(percentChange(100, 0), isNull, reason: 'cannot divide by nothing');
      expect(percentChange(50, -100), closeTo(150, 1e-9), reason: 'against an overdrawn balance the size is what counts');
    });

    test('the period: since the last balance sends no dates; a month sends its first and last day', () {
      expect((BankPeriod.sinceBalance.fromIso, BankPeriod.sinceBalance.toIso, BankPeriod.sinceBalance.label), (null, null, 'Since last balance'));
      final feb = BankPeriod.month(DateTime(2028, 2, 14));
      expect((feb.fromIso, feb.toIso), ('2028-02-01', '2028-02-29'));
      expect(feb.label, '01 Feb 2028 – 29 Feb 2028');
      expect(BankPeriod.month(DateTime(2026, 11, 3)), BankPeriod.month(DateTime(2026, 11, 28)), reason: 'the same month is the same period');
    });

    test('the query: only what is set is sent; a filter change goes back to page 1; export asks for everything', () {
      const q = BankTxnQuery(accountId: 'c1', page: 3, limit: 8);
      expect(q.toParams(), {'page': '3', 'limit': '8'});
      final f = q.refiltered(direction: 'out', group: 'artist_expense:food', person: 'e1', search: ' megha ');
      expect(f.toParams(), {'direction': 'out', 'group': 'artist_expense:food', 'person': 'e1', 'search': 'megha', 'page': '1', 'limit': '8'});
      expect(f.isFiltered, isTrue);
      expect(f.cleared.isFiltered, isFalse);
      expect(q.copyWith(from: '2026-11-01', to: '2026-11-30').toParams(export: true), {'from': '2026-11-01', 'to': '2026-11-30', 'export': '1'});
      expect(q.refiltered(direction: 'in').refiltered(direction: null).direction, isNull, reason: 'a filter can be taken off again');
      expect(const BankTxnQuery(accountId: 'a') == const BankTxnQuery(accountId: 'a'), isTrue);
      expect(const BankTxnQuery(accountId: 'a') == const BankTxnQuery(accountId: 'a', page: 2), isFalse);
    });

    test('a row says who and which work on one line, without repeating itself', () {
      final e = BankTxn.fromJson(_expense(0));
      expect(e.heading, 'Artist expense · Food');
      expect(e.whoLine, 'Anjali TK · Megha · 2604161274');
      expect((e.isIn, e.signed, e.loggedAmount), (false, -1400, 1517));
      final c = BankTxn.fromJson(_collection(1));
      expect(c.whoLine, 'Gayathri · BK-77 · by Anaswara', reason: 'money in reads client first');
      final salary = BankTxn.fromJson({'in': 0, 'out': 5, 'particulars': 'Salary', 'title': 'Hana', 'person': {'name': 'Hana'}});
      expect(salary.whoLine, 'Hana', reason: 'the employee is not said twice');
      final old = BankTxn.fromJson({'in': 5, 'out': 0, 'narration': 'Collection · advance', 'voucherNo': 'RCV/1'});
      expect((old.heading, old.whoLine, old.balance), ('Collection · advance', '', null), reason: 'an older server sends only the narration');
    });

    test('the export has a row per transaction with who, the voucher, in / out and the balance', () {
      final rows = bankStatementRows([BankTxn.fromJson(_expense(0)), BankTxn.fromJson(_collection(1)), BankTxn.fromJson({'in': 5, 'out': 0, 'narration': 'x'})]);
      expect(rows.first.length, kBankStatementHeaders.length);
      expect(rows[0], ['15 Nov 2026', 'Artist expense · Food', 'Anjali TK · Megha · 2604161274', 'PAY/2026-27/0282', 'Artist expense', '', '1400.00', '428516.00', 'afternoon fd 4 person']);
      expect(rows[1][3], 'RCV/2026-27/0320 / UTR-778');
      expect((rows[1][5], rows[1][6]), ('28500.00', ''));
      expect(rows[2][7], '', reason: 'no known balance is left blank, not zero');
    });
  });

  group('Bank & Cash Balance (wide)', () {
    testWidgets('totals against last month: up, flat, and silent where there is nothing to compare with', (t) async {
      await _open(t, _Server());
      expect(find.descendant(of: find.byKey(const Key('bankKpi_total')), matching: find.text('₹15,28,457')), findsOneWidget);
      expect(_text(t, const Key('bankKpiChange_total')), '+6.3% vs last month');
      expect(_text(t, const Key('bankKpiChange_bank')), '+5.2%');
      expect(_text(t, const Key('bankKpiChange_cash_c1')), '+9.4%');
      expect(_text(t, const Key('bankKpiChange_cash_c2')), '—', reason: 'Petty Cash has no balance for the end of last month');
      expect(find.descendant(of: find.byKey(const Key('bankKpi_cash_c1')), matching: find.text('Cash in Hand')), findsOneWidget, reason: 'each cash box has its own card');
    });

    testWidgets('a balance that fell is shown as a fall', (t) async {
      await _open(t, _Server(), previous: const PreviousBalances(asOf: '2026-10-31', total: 2000000, bank: 1088941, cash: null));
      expect(_text(t, const Key('bankKpiChange_total')), '−23.6% vs last month');
      expect(_text(t, const Key('bankKpiChange_bank')), '0.0%');
    });

    testWidgets('more than two cash boxes share one card', (t) async {
      final extra = BankAccount.fromJson({'_id': 'c3', 'name': 'Studio till', 'kind': 'cash', 'balance': 100, 'currentBalance': 100});
      await _open(t, _Server(), accounts: [_axis, _cash, _petty, extra]);
      expect(find.byKey(const Key('bankKpi_cash')), findsOneWidget);
      expect(find.text('Cash in Hand (3)'), findsOneWidget);
      expect(find.byKey(const Key('bankKpi_cash_c1')), findsNothing);
    });

    testWidgets('the first account\'s transactions show beside the list, a short page of 8, since the last balance', (t) async {
      final server = _Server();
      await _open(t, server);
      expect(find.text('NIZAN BEAUTY VENTURES — Transactions'), findsOneWidget);
      expect(find.textContaining('Since the 31 Oct 2026 balance'), findsOneWidget);
      expect(find.textContaining('Ledger BNK-01 · AXIS BANK'), findsOneWidget);
      final q = server.asked.last;
      expect((q.accountId, q.from, q.to, q.page, q.limit, q.isFiltered), ('b1', null, null, 1, 8, false));
      expect(find.byKey(const Key('bankTxn_x0')), findsOneWidget);
      expect(find.byKey(const Key('bankTxn_x7')), findsOneWidget);
      expect(find.byKey(const Key('bankTxn_x8')), findsNothing, reason: 'only one page is on screen');
      expect(_text(t, const Key('bankTxnShowing')), 'Showing 1 – 8 of 36 transactions');
      expect(_text(t, const Key('bankOpeningAmount')), '₹3,87,068');
      expect(_sideways, findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('an expense row says what it was for, who, which work and what was logged; a collection the same', (t) async {
      await _open(t, _Server());
      final e = find.byKey(const Key('bankTxn_x0'));
      expect(find.descendant(of: e, matching: find.text('Artist expense · Food')), findsOneWidget);
      expect(find.descendant(of: e, matching: find.text('Anjali TK · Megha · 2604161274')), findsOneWidget);
      expect(find.descendant(of: e, matching: find.text('−₹1,400')), findsOneWidget);
      expect(find.descendant(of: e, matching: find.text('logged ₹1,517')), findsOneWidget);
      expect(find.descendant(of: e, matching: find.text('PAY/2026-27/0282')), findsOneWidget);
      final c = find.byKey(const Key('bankTxn_k1'));
      expect(find.descendant(of: c, matching: find.text('Collection · Booking')), findsOneWidget);
      expect(find.descendant(of: c, matching: find.text('Gayathri · BK-77 · by Anaswara')), findsOneWidget);
      expect(find.descendant(of: c, matching: find.text('+₹28,500')), findsOneWidget);
      expect(find.descendant(of: c, matching: find.text('UTR-778')), findsOneWidget);
    });

    testWidgets('choosing another account shows ITS transactions, from page 1, with no filters carried over', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.byKey(const Key('bankPage_2')));
      await t.pumpAndSettle();
      expect(server.asked.last.page, 2);
      await t.tap(find.byKey(const Key('bankAccount_c1')));
      await t.pumpAndSettle();
      expect(find.text('Cash in Hand — Transactions'), findsOneWidget);
      expect((server.asked.last.accountId, server.asked.last.page), ('c1', 1));
    });

    testWidgets('an account with no ledger says so instead of an empty list', (t) async {
      final server = _Server();
      await _open(t, server);
      final before = server.asked.length;
      await t.tap(find.byKey(const Key('bankAccount_c2')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('bankNotLinked')), findsOneWidget);
      expect(server.asked.length, before, reason: 'there is nothing to ask the server for');
    });

    testWidgets('paging: the numbers and the arrows ask for that page', (t) async {
      final server = _Server();
      await _open(t, server);
      for (final p in [1, 2, 3, 4, 5]) {
        expect(find.byKey(Key('bankPage_$p')), findsOneWidget);
      }
      await t.tap(find.byKey(const Key('bankPage_3')));
      await t.pumpAndSettle();
      expect(server.asked.last.page, 3);
      expect(_text(t, const Key('bankTxnShowing')), 'Showing 17 – 24 of 36 transactions');
      await t.tap(find.byKey(const Key('bankPageNext')));
      await t.pumpAndSettle();
      expect(server.asked.last.page, 4);
      await t.tap(find.byKey(const Key('bankPagePrev')));
      await t.pumpAndSettle();
      expect(server.asked.last.page, 3);
    });

    testWidgets('filters: money out, a category, a person and a search each go to the server, from page 1', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.byKey(const Key('bankPage_2')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('bankFilterDirection')));
      await t.pumpAndSettle();
      await t.tap(find.text('Money out').last);
      await t.pumpAndSettle();
      expect((server.asked.last.direction, server.asked.last.page), ('out', 1));

      await t.tap(find.byKey(const Key('bankFilterGroup')));
      await t.pumpAndSettle();
      await t.tap(find.text('Artist expense · Food  (35)'));
      await t.pumpAndSettle();
      expect(server.asked.last.group, 'artist_expense:food');

      await t.tap(find.byKey(const Key('bankFilterPerson')));
      await t.pumpAndSettle();
      await t.tap(find.text('Anjali TK  (35)'));
      await t.pumpAndSettle();
      expect(server.asked.last.person, 'e1');

      await t.enterText(find.byKey(const Key('bankSearch')), 'megha');
      await t.pump(const Duration(milliseconds: 450));
      await t.pumpAndSettle();
      expect(server.asked.last.search, 'megha');
      expect((server.asked.last.direction, server.asked.last.group, server.asked.last.person), ('out', 'artist_expense:food', 'e1'), reason: 'filters add up');

      // taking one off again
      await t.tap(find.byKey(const Key('bankFilterDirection')));
      await t.pumpAndSettle();
      await t.tap(find.text('All Transactions').last);
      await t.pumpAndSettle();
      expect(server.asked.last.direction, isNull);
    });

    testWidgets('nothing matching offers to clear the filters; nothing at all says so plainly', (t) async {
      final server = _Server()..total = 0;
      await _open(t, server);
      expect(find.text('No transactions since that balance.'), findsOneWidget);
      expect(find.byKey(const Key('bankTxnClear')), findsNothing);
      expect(find.byKey(const Key('bankViewAll')), findsNothing);
    });

    testWidgets('a period chosen in the header sends its dates and drops "since the balance"', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.byKey(const Key('bankPage_2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('bankPeriod')));
      await t.pumpAndSettle();
      await t.tap(find.text('This month'));
      await t.pumpAndSettle();
      final now = DateTime.now();
      final month = BankPeriod.month(now);
      expect((server.asked.last.from, server.asked.last.to), (month.fromIso, month.toIso));
      expect(server.asked.last.page, 1, reason: 'other dates are another list: it starts at its first page');
      expect(find.textContaining('Since the 31 Oct 2026 balance'), findsNothing);
      expect(find.text('Opening balance'), findsOneWidget);
      expect(_text(t, const Key('bankOpeningAmount')), 'Not recorded', reason: 'the server could not know it: not shown as zero');
    });

    testWidgets('tapping a row opens everything known about it', (t) async {
      await _open(t, _Server());
      await t.tap(find.byKey(const Key('bankTxn_x0')));
      await t.pumpAndSettle();
      final d = find.byKey(const Key('bankTxnDetail'));
      expect(d, findsOneWidget);
      expect(_text(t, const Key('bankTxnDetailAmount')), '−₹1,400');
      expect(find.descendant(of: d, matching: find.text('Logged ₹1,517 — approved for less')), findsOneWidget);
      for (final (label, value) in [('Artist', 'Anjali TK'), ('Client / work', 'Megha'), ('Why it was reduced', 'Over the meal limit'), ('Voucher', 'PAY/2026-27/0282')]) {
        expect(find.descendant(of: find.byKey(Key('bankTxnDetail_$label')), matching: find.text(value)), findsOneWidget, reason: label);
      }
      expect(find.byKey(const Key('bankTxnAttachment')), findsOneWidget, reason: 'the bill can be opened');
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
      expect(d, findsNothing);
    });

    testWidgets('"View all transactions" opens the account\'s own screen; "View Ledger" the ledger', (t) async {
      final router = await _open(t, _Server());
      await t.tap(find.byKey(const Key('bankViewAll')));
      await t.pumpAndSettle();
      expect(_path(router), '/company-finance/bank-balance/b1/transactions');
      expect(find.byType(BankTransactionsScreen), findsOneWidget);

      await t.tap(find.byKey(const Key('bankTxnBack')));
      await t.pumpAndSettle();
      expect(_path(router), '/company-finance/bank-balance');
      await t.tap(find.byKey(const Key('bankViewLedger')));
      await t.pumpAndSettle();
      expect(find.text('LEDGER l1'), findsOneWidget);
    });

    testWidgets('no accounts yet: says so and offers to add one', (t) async {
      await _open(t, _Server(), accounts: []);
      expect(find.byKey(const Key('bankNoAccounts')), findsOneWidget);
      expect(find.text('Add Account'), findsOneWidget);
      expect(find.byKey(const Key('bankTransactionsPanel')), findsNothing);
    });

    for (final width in [1700.0, 1100.0, 1000.0]) {
      testWidgets('lays out at $width px with no overflow and no sideways scrolling', (t) async {
        await _open(t, _Server(), width: width);
        expect(t.takeException(), isNull);
        expect(_sideways, findsNothing);
        expect(find.byKey(const Key('bankTransactionsPanel')), findsOneWidget);
      });
    }
  });

  group('Bank & Cash Balance (phone)', () {
    testWidgets('the accounts are a list; tapping one opens its transactions screen', (t) async {
      final server = _Server();
      final router = await _open(t, server, width: 390, height: 2400);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('bankTransactionsPanel')), findsNothing, reason: 'no side panel on a phone');
      expect(server.asked, isEmpty, reason: 'nothing is fetched until an account is opened');
      expect(find.byKey(const Key('bankPeriod')), findsNothing);
      await t.tap(find.byKey(const Key('bankAccount_c1')));
      await t.pumpAndSettle();
      expect(_path(router), '/company-finance/bank-balance/c1/transactions');
      expect(t.takeException(), isNull);
    });
  });

  group('the Transactions screen', () {
    const path = '/company-finance/bank-balance/c1/transactions';

    testWidgets('the whole list, 25 to a page, with what came in, what went out and the balances', (t) async {
      final server = _Server();
      await _open(t, server, start: path);
      expect(find.text('Cash in Hand — Transactions'), findsOneWidget);
      expect((server.asked.last.accountId, server.asked.last.limit, server.asked.last.page), ('c1', 25, 1));
      expect(find.descendant(of: find.byKey(const Key('bankSummary_opening')), matching: find.text('₹3,87,068')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('bankSummary_in')), matching: find.text('+₹2,56,500')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('bankSummary_out')), matching: find.text('−₹2,16,552')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('bankSummary_closing')), matching: find.text('₹4,27,016')), findsOneWidget);
      expect(find.text('Current balance'), findsOneWidget);
      expect(_text(t, const Key('bankTxnShowing')), 'Showing 1 – 25 of 36 transactions');
      expect(find.byKey(const Key('bankViewAll')), findsNothing, reason: 'this IS the whole list');
      expect(find.byKey(const Key('bankOpeningStrip')), findsNothing, reason: 'the balance it starts from is already in the summary');
      expect(_sideways, findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('the totals are the account\'s for the period — a filter narrows the list, not them', (t) async {
      final server = _Server();
      await _open(t, server, start: path);
      await t.tap(find.byKey(const Key('bankFilterDirection')));
      await t.pumpAndSettle();
      await t.tap(find.text('Money in').last);
      await t.pumpAndSettle();
      expect(server.asked.last.direction, 'in');
      expect(_text(t, const Key('bankTxnShowing')), 'Showing 1 – 3 of 3 transactions');
      expect(find.descendant(of: find.byKey(const Key('bankSummary_out')), matching: find.text('−₹2,16,552')), findsOneWidget);
    });

    testWidgets('a period turns the tiles into opening and closing — "—" where the opening is not known', (t) async {
      await _open(t, _Server(), start: path);
      await t.tap(find.byKey(const Key('bankPeriod')));
      await t.pumpAndSettle();
      await t.tap(find.text('Last month'));
      await t.pumpAndSettle();
      expect(find.text('Opening balance'), findsOneWidget);
      expect(find.text('Closing balance'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('bankSummary_opening')), matching: find.text('—')), findsOneWidget);
    });

    testWidgets('a phone-width window gets cards, and still no overflow', (t) async {
      await _open(t, _Server(), start: path, width: 390, height: 6000);
      expect(t.takeException(), isNull);
      expect(_sideways, findsNothing);
      expect(find.byKey(const Key('bankTxn_x0')), findsOneWidget);
      expect(find.text('Reference / Voucher'), findsNothing, reason: 'no column headers in the card layout');
      expect(find.textContaining('Balance ₹4,28,516'), findsOneWidget);
    });

    testWidgets('an account that is gone says so and leads back', (t) async {
      final router = await _open(t, _Server(), start: '/company-finance/bank-balance/nope/transactions');
      expect(find.byKey(const Key('bankAccountGone')), findsOneWidget);
      await t.tap(find.text('Back to Bank & Cash Balance'));
      await t.pumpAndSettle();
      expect(_path(router), '/company-finance/bank-balance');
    });

    testWidgets('a list that will not load offers "Try again"', (t) async {
      final server = _Server()..fail = true;
      await _open(t, server, start: path);
      expect(find.text('Try again'), findsOneWidget);
      server.fail = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('bankTxn_x0')), findsOneWidget);
    });
  });
}
