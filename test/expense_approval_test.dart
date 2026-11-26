import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_expenses_view.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/money_account_picker.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';

// Approving an artist expense can be for LESS than the artist logged. The popup shows the logged
// amount, asks for the approved one (never more than was logged), and says what comes out of the
// account; the lists show both numbers.

final _cash = BankAccount.fromJson({
  '_id': 'acc1',
  'name': 'Cash in hand',
  'kind': 'cash',
  'balance': 10000,
  'currentBalance': 10000,
  'ledger': {'_id': 'led1', 'code': '1000', 'name': 'Cash'},
});

List<Override> _banks() => [
      bankAccountsProvider.overrideWith((ref) async => BankAccountsResult(accounts: [_cash], totalBalance: 10000)),
    ];

/// A screen with one button that opens the popup; what it returns lands in [result].
class _Host {
  MoneyChoice? result;
  bool closed = false;
}

Future<_Host> _open(WidgetTester t, {bool adjustable = true, double amount = 1517}) async {
  final host = _Host();
  t.view.physicalSize = const Size(1000, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: _banks(),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () async {
                host.result = await showMoneyAccountPicker(
                  context,
                  title: 'Approve expense',
                  amount: amount,
                  moneyIn: false,
                  modes: kCollectionPayModes,
                  adjustableAmount: adjustable,
                );
                host.closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.byKey(const Key('open')));
  await t.pumpAndSettle();
  return host;
}

FilledButton _approve(WidgetTester t) => t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Approve'));

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(find.byKey(const Key('approvedAmountField')), text);
  await t.pump();
}

void main() {
  group('checking what was typed', () {
    test('in full, for less, with paise and thousands separators', () {
      expect(checkApprovedAmount('1517', 1517).value, 1517);
      expect(checkApprovedAmount('1400', 1517).value, 1400);
      expect(checkApprovedAmount(' 1,400 ', 1517).value, 1400);
      expect(checkApprovedAmount('1400.456', 1517).value, 1400.46);
      expect(checkApprovedAmount('0.01', 1517).value, 0.01);
      expect(checkApprovedAmount('1400', 1517).error, isNull);
    });

    test('never more than was logged, never nothing, never not a number', () {
      expect(checkApprovedAmount('1518', 1517).error, "Can't be more than the ₹1,517 that was logged");
      expect(checkApprovedAmount('1517.01', 1517).error, isNotNull);
      expect(checkApprovedAmount('0', 1517).error, contains('more than ₹0'));
      expect(checkApprovedAmount('-5', 1517).error, contains('more than ₹0'));
      expect(checkApprovedAmount('0.004', 1517).error, contains('more than ₹0'), reason: 'rounds to nothing');
      expect(checkApprovedAmount('', 1517).error, contains('Enter'));
      expect(checkApprovedAmount('abc', 1517).error, contains('Enter'));
      for (final bad in ['', 'abc', '0', '1518']) {
        expect(checkApprovedAmount(bad, 1517).value, isNull);
      }
    });

    test('paise in the logged amount are honoured', () {
      expect(checkApprovedAmount('99.5', 99.5).value, 99.5);
      expect(checkApprovedAmount('99.51', 99.5).error, contains('₹99.50'));
    });
  });

  group('the approval popup', () {
    testWidgets('shows what was logged and starts at approving it in full', (t) async {
      await _open(t);
      expect(find.byKey(const Key('approveAmountBlock')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('approveLoggedAmount'))).data, '₹1,517');
      expect(t.widget<TextField>(find.byKey(const Key('approvedAmountField'))).controller!.text, '1517');
      expect(find.text('Approved in full — ₹1,517 comes out of the account.'), findsOneWidget);
      expect(find.text('₹1,517 paid — which account paid it?'), findsOneWidget);
      expect(find.byKey(const Key('approvalNoteField')), findsNothing, reason: 'a reason only matters when it is reduced');
      expect(_approve(t).onPressed, isNotNull);
    });

    testWidgets('approving for less: says what comes out of the account, asks why, and returns both', (t) async {
      final host = await _open(t);
      await _type(t, '1400');
      expect(find.text('₹117 less than logged — only ₹1,400 comes out of the account.'), findsOneWidget);
      expect(find.text('₹1,400 paid — which account paid it?'), findsOneWidget, reason: 'the heading follows the approved amount');
      await t.enterText(find.byKey(const Key('approvalNoteField')), '  over the meal limit ');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Approve'));
      await t.pumpAndSettle();
      final r = host.result!;
      expect(r.approvedAmount, 1400);
      expect(r.approvalNote, 'over the meal limit');
      expect(r.moneyAccountId, 'acc1');
      final json = r.toJson();
      expect(json['approvedAmount'], 1400);
      expect(json['approvalNote'], 'over the meal limit');
    });

    testWidgets('approving in full still sends the amount, and no note', (t) async {
      final host = await _open(t);
      await t.enterText(find.byKey(const Key('approvedAmountField')), '1400');
      await t.pump();
      await t.enterText(find.byKey(const Key('approvalNoteField')), 'oops');
      await _type(t, '1517'); // changed back: the reason no longer applies
      expect(find.byKey(const Key('approvalNoteField')), findsNothing);
      await t.tap(find.widgetWithText(FilledButton, 'Approve'));
      await t.pumpAndSettle();
      expect(host.result!.approvedAmount, 1517);
      expect(host.result!.approvalNote, '');
      expect(host.result!.toJson().containsKey('approvalNote'), isFalse);
    });

    for (final (typed, why) in [('1600', "Can't be more than the ₹1,517 that was logged"), ('0', 'Must be more than ₹0'), ('', 'Enter the amount')]) {
      testWidgets('"$typed" is refused: $why — and Approve is off', (t) async {
        final host = await _open(t);
        await _type(t, typed);
        expect(find.textContaining(why), findsOneWidget);
        expect(find.byKey(const Key('approveAmountHint')), findsNothing);
        expect(_approve(t).onPressed, isNull);
        expect(find.text('₹1,517 paid — which account paid it?'), findsOneWidget, reason: 'until it is acceptable the heading stays on the logged amount');
        await t.tap(find.widgetWithText(FilledButton, 'Approve'), warnIfMissed: false);
        await t.pumpAndSettle();
        expect(host.closed, isFalse, reason: 'the popup stays open');
      });
    }

    testWidgets('a popup that does not adjust (collections, everything else) is as it was', (t) async {
      final host = await _open(t, adjustable: false);
      expect(find.byKey(const Key('approveAmountBlock')), findsNothing);
      expect(find.text('₹1,517 paid — which account paid it?'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Approve'));
      await t.pumpAndSettle();
      expect(host.result!.approvedAmount, isNull);
      expect(host.result!.toJson().containsKey('approvedAmount'), isFalse);
    });

    testWidgets('Cancel returns nothing', (t) async {
      final host = await _open(t);
      await _type(t, '1400');
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(host.result, isNull);
      expect(host.closed, isTrue);
    });

    testWidgets('paise: a logged ₹99.50 is shown with its paise', (t) async {
      await _open(t, amount: 99.5);
      expect(t.widget<Text>(find.byKey(const Key('approveLoggedAmount'))).data, '₹99.50');
      expect(t.widget<TextField>(find.byKey(const Key('approvedAmountField'))).controller!.text, '99.50');
    });
  });

  group('the expense', () {
    Map<String, dynamic> json({double amount = 1400, double? logged = 1517, String note = 'over the meal limit'}) => {
          '_id': 'x1',
          'amount': amount,
          'loggedAmount': ?logged,
          'approvalNote': note,
          'status': 'verified',
          'category': 'food',
          'date': '2026-11-12T04:30:00.000Z',
          'employeeId': {'_id': 'e1', 'name': 'Anu'},
        };

    test('reduced: the amount that counts is the approved one and the logged one is kept beside it', () {
      final e = ArtistExpense.fromJson(json());
      expect((e.amount, e.loggedAmount, e.claimedAmount), (1400, 1517, 1517));
      expect(e.isReduced, isTrue);
      expect(e.approvalNote, 'over the meal limit');
    });

    test('not reduced (older servers, pending, approved in full): one number', () {
      final e = ArtistExpense.fromJson(json(amount: 300, logged: null, note: ''));
      expect((e.amount, e.loggedAmount, e.claimedAmount), (300, null, 300));
      expect(e.isReduced, isFalse);
      expect(ArtistExpense.fromJson(json(amount: 1517, logged: 1517)).isReduced, isFalse);
      expect(ArtistExpense.fromJson({'_id': 'x2', 'amount': 5, 'status': 'pending', 'category': 'other', 'date': '2026-11-12T04:30:00.000Z'}).approvalNote, '');
    });
  });

  group('the desktop Expenses table', () {
    FinancePage<ArtistExpense> page() => FinancePage(
          items: [
            ArtistExpense.fromJson({
              '_id': 'x1', 'amount': 1400, 'loggedAmount': 1517, 'approvalNote': 'over the meal limit', 'status': 'verified', 'category': 'food',
              'date': '2026-11-12T04:30:00.000Z', 'employeeId': {'_id': 'e1', 'name': 'Anu'},
            }),
            ArtistExpense.fromJson({
              '_id': 'x2', 'amount': 300, 'status': 'verified', 'category': 'travel', 'date': '2026-11-12T04:30:00.000Z', 'employeeId': {'_id': 'e1', 'name': 'Anu'},
            }),
          ],
          page: 1,
          limit: 20,
          totalItems: 2,
          totalPages: 1,
          summary: FinanceSummary.fromJson({
            'byStatus': {'verified': {'count': 2, 'amount': 1700}},
            'shown': {'count': 2, 'amount': 1700},
          }),
        );

    Future<void> show(WidgetTester t, double width) async {
      t.view.physicalSize = Size(width, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ArtistFinanceExpensesView(
            data: page(),
            query: const FinanceQuery(),
            onQueryChanged: (_) {},
            artists: const [],
            onExport: () {},
            onApprove: (_) {},
            onReject: (_) {},
            onEdit: (_) {},
            onDelete: (_) {},
            onViewReceipt: (_) {},
          ),
        ),
      ));
      await t.pumpAndSettle();
    }

    for (final width in [1300.0, 560.0]) {
      testWidgets('at $width px a reduced expense shows the approved amount with the logged one under it', (t) async {
        await show(t, width);
        expect(t.takeException(), isNull);
        final row = find.byKey(const Key('afExpenseReduced_x1'));
        expect(row, findsOneWidget);
        expect(find.descendant(of: row, matching: find.text(AfTheme.formatCurrency(1400))), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('Logged ${AfTheme.formatCurrency(1517)}')), findsOneWidget);
        expect(find.byKey(const Key('afExpenseReduced_x2')), findsNothing, reason: 'approved in full: just the one number');
        expect(find.byTooltip('Approved for less: over the meal limit'), findsOneWidget, reason: 'the reason is on hover');
      });
    }
  });
}
