import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/data/work_cost.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_by_work_view.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_collections_view.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_expenses_view.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_list_kit.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_overview_view.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart' show FinancePeriod, NameOption;
import 'package:nizan_crm/features/accounts/presentation/widgets/work_costs_tab.dart';
import 'package:nizan_crm/features/accounts/services/expense_service.dart';

// The desktop Artist Finance tabs. The side-panel filters and the 10-column table made the Expenses
// and Collections tabs scroll sideways, and Overview / By Work were mock-ups; these tests hold the
// replacements to: no horizontal scrolling at any width, real data only (an empty period says so),
// the real filter controls, and fuel (and every other kind) showing on the By Work tab.

Future<void> _show(WidgetTester t, Widget child, {double width = 1200, double height = 1600, List<Override> overrides = const []}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child)),
  ));
  await t.pumpAndSettle();
}

/// A pretend server that answers every request with [body].
class _Answer implements HttpClientAdapter {
  final Object body;
  _Answer(this.body);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

final _sideways = find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);

Map<String, dynamic> _expJson(String id, {String status = 'verified', String category = 'food', double amount = 300, bool booking = true, String workType = 'bridal', String notes = '', String artist = 'Anu'}) => {
      '_id': id,
      'amount': amount,
      'status': status,
      'category': category,
      'workType': workType,
      'date': '2026-11-12T04:30:00.000Z',
      'employeeId': {'_id': 'e1', 'name': artist},
      'notes': notes,
      if (booking) 'bookingId': {'_id': 'b-$id', 'bookingNumber': 'BK-$id', 'customerName': 'Client $id', 'service': 'Bridal'},
    };

Map<String, dynamic> _collJson(String id, {String status = 'verified', double amount = 1000, String mode = 'upi', String artist = 'Anu', bool trial = false}) => {
      '_id': id,
      'amount': amount,
      'status': status,
      'paymentMode': mode,
      'date': '2026-11-12T04:30:00.000Z',
      'employeeId': {'_id': 'e1', 'name': artist},
      'notes': 'note $id',
      if (status == 'verified') 'verifiedBy': {'name': 'Meera'},
      if (trial) 'trialId': {'_id': 't-$id', 'trialNumber': 'TR-$id', 'clientName': 'Trial client $id'} else 'bookingId': {'_id': 'b-$id', 'bookingNumber': 'BK-$id', 'customerName': 'Client $id', 'service': 'Bridal'},
    };

FinanceSummary _summary({Map<String, List<num>>? status, double shown = 0, List<Map<String, dynamic>> byCategory = const [], List<Map<String, dynamic>> byMode = const [], List<Map<String, dynamic>> byArtist = const []}) =>
    FinanceSummary.fromJson({
      'byStatus': {
        for (final e in (status ?? {'pending': [0, 0], 'verified': [0, 0], 'rejected': [0, 0]}).entries) e.key: {'count': e.value[0], 'amount': e.value[1]},
      },
      'shown': {'count': 0, 'amount': shown},
      'byCategory': byCategory,
      'byMode': byMode,
      'byWorkType': const [],
      'byArtist': byArtist,
    });

FinancePage<ArtistExpense> _expPage(List<Map<String, dynamic>> rows, {FinanceSummary? summary, int? total}) => FinancePage(
      items: [for (final r in rows) ArtistExpense.fromJson(r)],
      page: 1,
      limit: 20,
      totalItems: total ?? rows.length,
      totalPages: 1,
      summary: summary ?? _summary(status: {'pending': [1, 1600], 'verified': [2, 9400], 'rejected': [0, 0]}, shown: 11000),
    );

FinancePage<ArtistCollection> _collPage(List<Map<String, dynamic>> rows, {FinanceSummary? summary}) => FinancePage(
      items: [for (final r in rows) ArtistCollection.fromJson(r)],
      page: 1,
      limit: 20,
      totalItems: rows.length,
      totalPages: 1,
      summary: summary ?? _summary(status: {'pending': [1, 500], 'verified': [2, 40000], 'rejected': [1, 250]}, shown: 40750),
    );

const _artists = <NameOption>[(id: 'e1', name: 'Anu'), (id: 'e2', name: 'Fathima')];

// things the old mock-ups showed, whatever the data was
const _mockMarks = ['BK-260932007', 'Fathima Nihala', 'Anjali TK', 'Nov 1, 2026', '↑ +12% vs Oct', '↓ -8% vs Oct'];

void _noMockData() {
  for (final m in _mockMarks) {
    expect(find.textContaining(m), findsNothing, reason: 'mock "$m" must be gone');
  }
}

ArtistFinanceExpensesView _expView(
  FinancePage<ArtistExpense>? data, {
  FinanceQuery query = const FinanceQuery(),
  ValueChanged<FinanceQuery>? onQuery,
  ValueChanged<ArtistExpense>? onApprove,
  FinanceSummary? previous,
  bool canVerify = true,
  bool loading = false,
}) =>
    ArtistFinanceExpensesView(
      data: data,
      query: query,
      onQueryChanged: onQuery ?? (_) {},
      artists: _artists,
      onExport: () {},
      onApprove: onApprove ?? (_) {},
      onReject: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
      onViewReceipt: (_) {},
      canVerify: canVerify,
      loading: loading,
      previous: previous,
      previousLabel: 'Oct',
    );

void main() {
  group('the period before', () {
    test('a month → the month before; January reaches back into December', () {
      final p = priorStretch(FinancePeriod.month, DateTime(2026, 11, 15), null)!;
      expect((p.from, p.to, p.label), ('2026-10-01', '2026-10-31', 'Oct'));
      final j = priorStretch(FinancePeriod.month, DateTime(2027, 1, 3), null)!;
      expect((j.from, j.to, j.label), ('2026-12-01', '2026-12-31', 'Dec'));
      final m = priorStretch(FinancePeriod.month, DateTime(2028, 3, 1), null)!;
      expect((m.from, m.to), ('2028-02-01', '2028-02-29'), reason: 'a leap year');
    });

    test('a custom range → the same number of days straight before it', () {
      final p = priorStretch(FinancePeriod.range, DateTime(2026, 11), DateTimeRange(start: DateTime(2026, 11, 10), end: DateTime(2026, 11, 17)))!;
      expect((p.from, p.to, p.label), ('2026-11-02', '2026-11-09', 'the 8 days before'));
      final across = priorStretch(FinancePeriod.range, DateTime(2026, 11), DateTimeRange(start: DateTime(2026, 11, 3), end: DateTime(2026, 11, 5)))!;
      expect((across.from, across.to), ('2026-10-31', '2026-11-02'));
    });

    test('all time, or a range not picked yet, has nothing before it', () {
      expect(priorStretch(FinancePeriod.all, DateTime(2026, 11), null), isNull);
      expect(priorStretch(FinancePeriod.range, DateTime(2026, 11), null), isNull);
    });

    test('the comparison text: direction, percentage and colour', () {
      final up = afDeltaText(current: 120000, previous: 100000, previousLabel: 'Oct', higherIsGood: true)!;
      expect((up.text, up.color), ('↑ +20% vs Oct (₹1,00,000)', AfTheme.green));
      final spendUp = afDeltaText(current: 120000, previous: 100000, previousLabel: 'Oct', higherIsGood: false)!;
      expect(spendUp.color, AfTheme.red, reason: 'spending more is not good news');
      final spendDown = afDeltaText(current: 80000, previous: 100000, previousLabel: 'Oct', higherIsGood: false)!;
      expect((spendDown.text, spendDown.color), ('↓ 20% vs Oct (₹1,00,000)', AfTheme.green));
      expect(afDeltaText(current: 5, previous: 5, previousLabel: 'Oct', higherIsGood: true)!.text, 'Same as Oct (₹5)');
      expect(afDeltaText(current: 5, previous: null, previousLabel: 'Oct', higherIsGood: true), isNull);
      expect(afDeltaText(current: 5, previous: 0, previousLabel: 'Oct', higherIsGood: true), isNull, reason: 'nothing to divide by');
    });
  });

  group('Expenses (desktop)', () {
    final rows = [
      _expJson('x1', amount: 250, notes: 'Team lunch'),
      _expJson('x2', category: 'fuel', amount: 1500, booking: false, status: 'pending', notes: 'Car fuel'),
      _expJson('x3', category: 'stay', amount: 1800, workType: 'model_shoot', booking: false),
    ];

    for (final width in [1500.0, 1200.0, 1000.0, 820.0]) {
      testWidgets('no horizontal scrolling and no overflow at $width px', (t) async {
        await _show(t, _expView(_expPage(rows)), width: width);
        expect(_sideways, findsNothing);
        expect(t.takeException(), isNull);
        expect(find.byKey(const Key('afExpenseRow_x1')), findsOneWidget);
        expect(find.byKey(const Key('afExpenseRow_x3')), findsOneWidget);
        // the side panel is gone: the filters are one toolbar across the card
        expect(find.byKey(const Key('searchField')), findsOneWidget);
        expect(find.byKey(const Key('filtersButton')), findsOneWidget);
        expect(find.byKey(const Key('status_pending')), findsOneWidget);
        expect(find.text('Apply Filters'), findsNothing);
        expect(find.text('Save View'), findsNothing);
      });
    }

    testWidgets('a narrow window gets cards, not a squeezed table', (t) async {
      await _show(t, _expView(_expPage(rows)), width: 560);
      expect(_sideways, findsNothing);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('afExpenseRow_x2')), findsOneWidget);
      expect(find.text('Category'), findsNothing, reason: 'there is no column header in the card layout');
    });

    testWidgets('only what the server sent: totals, rows and the paging line are all real', (t) async {
      await _show(t, _expView(_expPage(rows)));
      _noMockData();
      expect(find.text(AfTheme.formatCurrency(11000)), findsOneWidget, reason: 'Total Expenses = pending + approved + rejected, from the summary');
      expect(find.text(AfTheme.formatCurrency(9400)), findsOneWidget);
      expect(find.text(AfTheme.formatCurrency(1600)), findsOneWidget);
      expect(find.textContaining('3 expenses'), findsOneWidget);
      expect(find.textContaining('Showing 1–3 of 3'), findsOneWidget);
      expect(find.text('Team lunch'), findsOneWidget);
      expect(find.text('Client x1'), findsOneWidget);
    });

    testWidgets('an expense not tied to a work says so — fuel is the usual case', (t) async {
      await _show(t, _expView(_expPage(rows)));
      final warn = t.widget<Text>(find.descendant(of: find.byKey(const Key('afExpenseRow_x2')), matching: find.text('Not tied to a work')));
      expect(warn.style?.color, AfTheme.yellow);
      expect(find.descendant(of: find.byKey(const Key('afExpenseRow_x3')), matching: find.text('Model shoot')), findsOneWidget);
    });

    testWidgets('a period with nothing says so — no invented rows', (t) async {
      final empty = _expPage(const [], summary: _summary());
      await _show(t, _expView(empty));
      _noMockData();
      expect(find.text('No expenses in this period'), findsOneWidget);
      expect(find.byKey(const Key('afExpenseRow_x1')), findsNothing);
      expect(find.textContaining('Showing'), findsNothing);
    });

    testWidgets('a search that matches nothing offers to clear it, keeping the period and sort', (t) async {
      FinanceQuery? asked;
      const q = FinanceQuery(from: '2026-11-01', to: '2026-11-30', search: 'zzz', sort: 'amount_desc', limit: 50);
      await _show(t, _expView(_expPage(const [], summary: _summary()), query: q, onQuery: (n) => asked = n));
      expect(find.text('No matching expenses'), findsOneWidget);
      await t.tap(find.text('Clear filters'));
      expect(asked, isNotNull);
      expect((asked!.from, asked!.to, asked!.sort, asked!.limit), ('2026-11-01', '2026-11-30', 'amount_desc', 50), reason: 'the period is not a filter');
      expect(asked!.search, '');
      expect(asked!.statuses, isEmpty);
      expect(asked!.advancedCount, 0);
    });

    testWidgets('still loading: a spinner, not placeholder rows', (t) async {
      t.view.physicalSize = const Size(1200, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: _expView(null, loading: true))));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      _noMockData();
    });

    testWidgets('the status chips and the breakdown filter through the query', (t) async {
      final asked = <FinanceQuery>[];
      final page = _expPage(rows, summary: _summary(status: {'pending': [1, 1600], 'verified': [2, 9400], 'rejected': [0, 0]}, shown: 11000, byCategory: [
        {'category': 'fuel', 'count': 1, 'amount': 1500},
        {'category': 'food', 'count': 1, 'amount': 250},
      ]));
      await _show(t, _expView(page, onQuery: asked.add));
      await t.tap(find.byKey(const Key('status_pending')));
      expect(asked.last.statuses, {'pending'});
      await t.tap(find.byKey(const Key('category_fuel')));
      expect(asked.last.categories, {'fuel'}, reason: 'the breakdown chip filters to fuel');
    });

    testWidgets('typing in the search sends it once, after a pause', (t) async {
      final asked = <FinanceQuery>[];
      await _show(t, _expView(_expPage(rows), onQuery: asked.add));
      await t.enterText(find.byKey(const Key('searchField')), 'petrol');
      expect(asked, isEmpty, reason: 'not on every keystroke');
      await t.pump(const Duration(milliseconds: 450));
      expect(asked.single.search, 'petrol');
      expect(asked.single.page, 1);
    });

    testWidgets('approve is offered on a pending expense to someone who can verify — and only then', (t) async {
      ArtistExpense? approved;
      await _show(t, _expView(_expPage(rows), onApprove: (e) => approved = e));
      await t.tap(find.byKey(const Key('afExpenseMenu_x2')));
      await t.pumpAndSettle();
      expect(find.text('Approve expense'), findsOneWidget);
      await t.tap(find.text('Approve expense'));
      await t.pumpAndSettle();
      expect(approved?.id, 'x2');

      await t.tap(find.byKey(const Key('afExpenseMenu_x1')));
      await t.pumpAndSettle();
      expect(find.text('Approve expense'), findsNothing, reason: 'x1 is already approved');
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();

      await _show(t, _expView(_expPage(rows), canVerify: false));
      await t.tap(find.byKey(const Key('afExpenseMenu_x2')));
      await t.pumpAndSettle();
      expect(find.text('Approve expense'), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('"vs Oct": spending down is good news; hidden when there is nothing before it', (t) async {
      final before = _summary(status: {'pending': [0, 0], 'verified': [10, 20000], 'rejected': [0, 0]});
      await _show(t, _expView(_expPage(rows), previous: before));
      expect(find.text('↓ 45% vs Oct (₹20,000)'), findsOneWidget);
      final text = t.widget<Text>(find.text('↓ 45% vs Oct (₹20,000)'));
      expect(text.style?.color, AfTheme.green);

      await _show(t, _expView(_expPage(rows)));
      expect(find.textContaining('vs Oct'), findsNothing);
      expect(find.text('3 claims'), findsOneWidget, reason: 'the honest line instead');
    });
  });

  group('Collections (desktop)', () {
    final rows = [_collJson('c1'), _collJson('c2', status: 'pending', mode: 'cash', amount: 500), _collJson('c3', trial: true, status: 'rejected', mode: 'bank_transfer', amount: 250)];

    ArtistFinanceCollectionsView view(FinancePage<ArtistCollection>? data, {ValueChanged<ArtistCollection>? onVerify, FinanceSummary? previous}) => ArtistFinanceCollectionsView(
          data: data,
          query: const FinanceQuery(),
          onQueryChanged: (_) {},
          artists: _artists,
          onExport: () {},
          onVerify: onVerify ?? (_) {},
          onReject: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
          onViewReceipt: (_) {},
          previous: previous,
          previousLabel: 'Oct',
        );

    for (final width in [1500.0, 1100.0, 900.0]) {
      testWidgets('no horizontal scrolling and no overflow at $width px', (t) async {
        await _show(t, view(_collPage(rows)), width: width);
        expect(_sideways, findsNothing);
        expect(t.takeException(), isNull);
        expect(find.byKey(const Key('afCollectionRow_c1')), findsOneWidget);
        expect(find.byKey(const Key('searchField')), findsOneWidget);
        expect(find.text('Apply Filters'), findsNothing);
      });
    }

    testWidgets('a narrow window gets cards', (t) async {
      await _show(t, view(_collPage(rows)), width: 520);
      expect(_sideways, findsNothing);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('afCollectionRow_c3')), findsOneWidget);
    });

    testWidgets('real rows: the booking or trial, the mode as its name, who verified it', (t) async {
      await _show(t, view(_collPage(rows)));
      _noMockData();
      final c1 = find.byKey(const Key('afCollectionRow_c1'));
      expect(find.descendant(of: c1, matching: find.text('Client c1')), findsOneWidget);
      expect(find.descendant(of: c1, matching: find.text('UPI')), findsOneWidget);
      expect(find.descendant(of: c1, matching: find.text('by Meera')), findsOneWidget);
      final c3 = find.byKey(const Key('afCollectionRow_c3'));
      expect(find.descendant(of: c3, matching: find.text('Trial client c3')), findsOneWidget);
      expect(find.descendant(of: c3, matching: find.text('Bank transfer')), findsOneWidget);
      expect(find.text(AfTheme.formatCurrency(40750)), findsOneWidget);
    });

    testWidgets('an empty period says so', (t) async {
      await _show(t, view(_collPage(const [], summary: _summary())));
      _noMockData();
      expect(find.text('No collections in this period'), findsOneWidget);
    });

    testWidgets('verify is offered on a pending collection', (t) async {
      ArtistCollection? verified;
      await _show(t, view(_collPage(rows), onVerify: (c) => verified = c));
      await t.tap(find.byKey(const Key('afCollectionMenu_c2')));
      await t.pumpAndSettle();
      await t.tap(find.text('Verify collection'));
      await t.pumpAndSettle();
      expect(verified?.id, 'c2');
    });

    testWidgets('more collected is good news', (t) async {
      final before = _summary(status: {'pending': [0, 0], 'verified': [3, 30000], 'rejected': [0, 0]});
      await _show(t, view(_collPage(rows), previous: before));
      final up = find.text('↑ +36% vs Oct (₹30,000)');
      expect(up, findsOneWidget);
      expect(t.widget<Text>(up).style?.color, AfTheme.green);
    });
  });

  group('Overview (desktop)', () {
    Widget overview({FinancePage<ArtistCollection>? c, FinancePage<ArtistExpense>? e, List<LabelTotal> top = const [], FinanceSummary? pc, FinanceSummary? pe, VoidCallback? onPayouts, ValueChanged<int>? onTab}) =>
        ArtistFinanceOverviewView(
          collections: c,
          expenses: e,
          topArtists: top,
          previousCollections: pc,
          previousExpenses: pe,
          previousLabel: 'Oct',
          periodText: 'November 2026',
          onAddCollection: () {},
          onAddExpense: () => {},
          onRecordPayout: onPayouts,
          onGenerateReport: () {},
          onNavigateTab: onTab ?? (_) {},
        );

    final collections = _collPage([_collJson('c1', amount: 40000), _collJson('c2', status: 'pending', amount: 500)],
        summary: _summary(status: {'pending': [1, 500], 'verified': [2, 40000], 'rejected': [1, 250]}));
    final expenses = _expPage([_expJson('x1', amount: 250, category: 'food'), _expJson('x2', amount: 1500, category: 'fuel', booking: false)],
        summary: _summary(status: {'pending': [1, 1600], 'verified': [2, 9400], 'rejected': [2, 700]}, byCategory: [
          {'category': 'fuel', 'count': 2, 'amount': 6000},
          {'category': 'food', 'count': 3, 'amount': 5000},
        ]));

    testWidgets('before anything has loaded: dashes and "Loading…", never invented figures', (t) async {
      await _show(t, overview());
      _noMockData();
      expect(find.text('—'), findsWidgets);
      expect(find.text('Loading…'), findsWidgets);
      for (final fake in ['190,750', '35,049', '67,500', '3,250']) {
        expect(find.textContaining(fake), findsNothing);
      }
    });

    testWidgets('the figures are the period\'s own: collected = verified; expenses = approved + pending; net between them', (t) async {
      await _show(t, overview(c: collections, e: expenses));
      expect(find.text(AfTheme.formatCurrency(40000)), findsWidgets, reason: 'collected');
      expect(find.text(AfTheme.formatCurrency(11000)), findsWidgets, reason: '9,400 + 1,600 — the 700 rejected is not spend (also the breakdown\'s total)');
      expect(find.text(AfTheme.formatCurrency(29000)), findsOneWidget, reason: 'net');
      expect(find.text(AfTheme.formatCurrency(2100)), findsOneWidget, reason: 'pending: 500 collected + 1,600 expenses');
      expect(find.text('2 items to check'), findsOneWidget);
      expect(find.text(AfTheme.formatCurrency(950)), findsOneWidget, reason: 'rejected: 250 + 700');
    });

    testWidgets('against the month before — and nothing invented when there is none', (t) async {
      final pc = _summary(status: {'pending': [0, 0], 'verified': [5, 32000], 'rejected': [0, 0]});
      final pe = _summary(status: {'pending': [0, 0], 'verified': [5, 10000], 'rejected': [0, 0]});
      await _show(t, overview(c: collections, e: expenses, pc: pc, pe: pe));
      expect(find.text('↑ +25% vs Oct (₹32,000)'), findsOneWidget);
      expect(find.text('↑ +10% vs Oct (₹10,000)'), findsOneWidget, reason: 'spending UP');
      expect(t.widget<Text>(find.text('↑ +10% vs Oct (₹10,000)')).style?.color, AfTheme.red);
      expect(find.byKey(const Key('afOverviewCompare')), findsOneWidget);

      await _show(t, overview(c: collections, e: expenses));
      expect(find.textContaining('vs Oct ('), findsNothing);
      expect(find.text('Approved + pending'), findsOneWidget);
    });

    testWidgets('where the spending went: the categories the server counted, fuel included', (t) async {
      await _show(t, overview(c: collections, e: expenses));
      expect(find.byKey(const Key('afBreakdown_fuel')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('afBreakdown_fuel')), matching: find.text('Fuel')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('afBreakdown_fuel')), matching: find.text('55%')), findsOneWidget, reason: '6,000 of 11,000');
      expect(find.byKey(const Key('afBreakdown_stay')), findsNothing, reason: 'a kind with nothing spent is not listed');
    });

    testWidgets('top artists come from the verified collections, best first', (t) async {
      await _show(t, overview(c: collections, e: expenses, top: const [LabelTotal('e1', 'Anu', 3, 30000), LabelTotal('e2', 'Fathima', 1, 10000)]));
      final card = find.byKey(const Key('afOverviewTopArtists'));
      expect(find.descendant(of: card, matching: find.text('Anu')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Fathima')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('November 2026')), findsOneWidget);
      await _show(t, overview(c: collections, e: expenses));
      expect(find.text('No verified collections in this period.'), findsOneWidget);
    });

    testWidgets('recent transactions are the real latest entries; the pills narrow them', (t) async {
      await _show(t, overview(c: collections, e: expenses));
      final recent = find.byKey(const Key('afOverviewRecent'));
      expect(find.descendant(of: recent, matching: find.text('Client c1')), findsOneWidget);
      expect(find.descendant(of: recent, matching: find.text('Fuel')), findsOneWidget);
      await t.tap(find.byKey(const Key('afTxPill_expenses')));
      await t.pump();
      expect(find.descendant(of: recent, matching: find.text('Client c1')), findsNothing);
      expect(find.descendant(of: recent, matching: find.text('Fuel')), findsOneWidget);
      expect(find.byKey(const Key('afTxPill_payouts')), findsNothing, reason: 'there is no payout data here, so no Payouts pill');
    });

    testWidgets('the payouts shortcut only exists for someone who can process payouts', (t) async {
      await _show(t, overview(c: collections, e: expenses));
      expect(find.text('Artist Payouts'), findsNothing);
      var opened = 0;
      await _show(t, overview(c: collections, e: expenses, onPayouts: () => opened++));
      await t.tap(find.text('Artist Payouts'));
      expect(opened, 1);
    });

    for (final width in [1400.0, 700.0]) {
      testWidgets('two entries that look exactly alike (same day, kind, amount) are two rows, not a crash — at $width px', (t) async {
        // e.g. two ₹100 tolls logged by the same artist on the same day
        final twin = (String id) => _expJson(id, category: 'travel', amount: 100, booking: false, artist: 'Anjali TK');
        final twinColl = (String id) => _collJson(id, amount: 500);
        await _show(
          t,
          overview(
            c: _collPage([twinColl('c1'), twinColl('c2')], summary: _summary(status: {'pending': [0, 0], 'verified': [2, 1000], 'rejected': [0, 0]})),
            e: _expPage([twin('x1'), twin('x2'), twin('x3')], summary: _summary(status: {'pending': [0, 0], 'verified': [3, 300], 'rejected': [0, 0]})),
          ),
          width: width,
          height: 2400,
        );
        expect(t.takeException(), isNull, reason: 'no duplicate-key assertion');
        final recent = find.byKey(const Key('afOverviewRecent'));
        expect(find.descendant(of: recent, matching: find.text('Travel')), findsNWidgets(3));
        expect(find.byKey(const Key('afTx_e_x1')), findsOneWidget);
        expect(find.byKey(const Key('afTx_e_x2')), findsOneWidget);
        expect(find.byKey(const Key('afTx_e_x3')), findsOneWidget);
        expect(find.byKey(const Key('afTx_c_c1')), findsOneWidget);
        expect(find.byKey(const Key('afTx_c_c2')), findsOneWidget);
      });
    }

    testWidgets('identical Expenses and Collections rows (different ids) are separate rows too', (t) async {
      final e = (String id) => _expJson(id, category: 'travel', amount: 100, booking: false);
      await _show(t, _expView(_expPage([e('a'), e('b')])));
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('afExpenseRow_a')), findsOneWidget);
      expect(find.byKey(const Key('afExpenseRow_b')), findsOneWidget);
    });

    for (final width in [1400.0, 1000.0, 700.0]) {
      testWidgets('no horizontal scrolling at $width px', (t) async {
        await _show(t, overview(c: collections, e: expenses, top: const [LabelTotal('e1', 'Anu', 3, 30000)]), width: width, height: 2400);
        expect(_sideways, findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('By Work (desktop)', () {
    WorkCostPage page({Map<String, dynamic>? totals, List<Map<String, dynamic>> unplaced = const [], bool unplacedTruncated = false}) => WorkCostPage.fromJson({
          'items': [
            {
              'bookingId': 'b1',
              'bookingNumber': 'BK-1',
              'customerName': 'Asha',
              'service': 'Bridal',
              'serviceStart': '2026-11-12T04:30:00.000Z',
              'artists': ['Anu'],
              'food': 0, 'travel': 300, 'stay': 0, 'materials': 0, 'fuel': 1000, 'other': 0,
              'total': 1300,
              'expenseCount': 2,
              'pendingCount': 0,
              'lines': const [],
            },
          ],
          'page': 1,
          'limit': 20,
          'totalItems': 1,
          'totalPages': 1,
          'totals': totals ??
              {
                'food': 0, 'other': 1300, 'total': 1300, 'unplaced': 1850, 'unplacedCount': 2,
                'byCategory': {'food': 0, 'travel': 300, 'stay': 0, 'materials': 0, 'fuel': 1500, 'other': 0},
                'unplacedByCategory': {'food': 0, 'travel': 0, 'stay': 1200, 'materials': 0, 'fuel': 650, 'other': 0},
              },
          'unplaced': unplaced,
          'unplacedTruncated': unplacedTruncated,
          'truncated': false,
        });

    Map<String, dynamic> line(String id, String category, double amount, {String artist = 'Anu', String status = 'verified', String notes = '', bool counted = true}) => {
          'expenseId': id,
          'category': category,
          'meal': '',
          'at': '2026-11-12T01:30:00.000Z',
          'amount': amount,
          'status': status,
          'counted': counted,
          'notes': notes,
          'mode': 'unlinked',
          'reason': 'Not tied to a work.',
          'flag': '',
          'artist': artist,
        };

    Future<void> open(WidgetTester t, WorkCostPage p, {double width = 1200}) => _show(
          t,
          ArtistFinanceByWorkView(from: '2026-11-01', to: '2026-11-30', artists: _artists),
          width: width,
          height: 2400,
          overrides: [workCostsPageProvider.overrideWith((ref, q) async => p)],
        );

    testWidgets('it is the real cost-per-work tab, not a mock-up', (t) async {
      await open(t, page());
      expect(find.byType(WorkCostsTab), findsOneWidget);
      expect(find.byKey(const Key('workCost_b1')), findsOneWidget);
      expect(find.text('Fuel ₹1,000'), findsOneWidget, reason: 'the work\'s card shows its fuel');
      for (final m in _mockMarks) {
        expect(find.textContaining(m), findsNothing);
      }
      expect(_sideways, findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('fuel and every other kind are totalled — with what is not on a work beside each', (t) async {
      await open(t, page());
      final fuel = find.byKey(const Key('costsKind_fuel'));
      expect(find.descendant(of: fuel, matching: find.text('₹1,500')), findsOneWidget);
      expect(find.descendant(of: fuel, matching: find.text('+ ₹650 not on a work')), findsOneWidget);
      final stay = find.byKey(const Key('costsKind_stay'));
      expect(find.descendant(of: stay, matching: find.text('₹0')), findsOneWidget, reason: 'nothing under a work yet…');
      expect(find.descendant(of: stay, matching: find.text('+ ₹1,200 not on a work')), findsOneWidget, reason: '…but it was spent, and is not lost');
      expect(find.byKey(const Key('costsKind_travel')), findsOneWidget);
      expect(find.byKey(const Key('costsKind_food')), findsNothing, reason: 'food has its own pill');
      expect(find.byKey(const Key('costsKind_materials')), findsNothing, reason: 'nothing spent on materials');
    });

    testWidgets('the entries not under a work are listed, each with who, when and why', (t) async {
      await open(t, page(unplaced: [line('u1', 'fuel', 650, notes: 'petrol for the drive'), line('u2', 'stay', 1200, artist: 'Fathima', status: 'pending')]));
      expect(find.byKey(const Key('costsUnplacedList')), findsOneWidget);
      expect(find.text('Not tied to a work · 2 entries · ₹1,850'), findsOneWidget);
      expect(find.text('Stay ₹1,200  ·  Fuel ₹650'), findsOneWidget, reason: 'the summary names the kinds');
      final fuel = find.byKey(const Key('costsUnplacedLine_u1'));
      expect(find.descendant(of: fuel, matching: find.text('Fuel  ·  Anu')), findsOneWidget);
      expect(find.descendant(of: fuel, matching: find.textContaining('petrol for the drive')), findsOneWidget);
      expect(find.descendant(of: fuel, matching: find.text('Not tied to a work.')), findsOneWidget);
      expect(find.descendant(of: fuel, matching: find.text('Approved')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('costsUnplacedLine_u2')), matching: find.text('Pending')), findsOneWidget);
    });

    testWidgets('a rejected bill in the list is struck through', (t) async {
      await open(t, page(unplaced: [line('u3', 'fuel', 99, status: 'rejected', counted: false)]));
      final amount = t.widget<Text>(find.descendant(of: find.byKey(const Key('costsUnplacedLine_u3')), matching: find.text('₹99')));
      expect(amount.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('no list when nothing is unplaced — and an older server\'s page invents no per-kind totals', (t) async {
      await open(t, page(totals: {'food': 0, 'other': 1300, 'total': 1300, 'unplaced': 0, 'unplacedCount': 0}));
      expect(find.byKey(const Key('costsUnplacedList')), findsNothing);
      expect(find.byKey(const Key('costsKinds')), findsNothing);
    });

    testWidgets('"showing the first N" when the list was cut short', (t) async {
      await open(t, page(unplaced: [for (var i = 0; i < 3; i++) line('v$i', 'fuel', 10.0 + i)], unplacedTruncated: true));
      expect(find.byKey(const Key('costsUnplacedTruncated')), findsOneWidget);
    });

    testWidgets('a period with ONLY unplaced entries is not "nothing to export"', (t) async {
      final svc = ExpenseService(Dio()
        ..httpClientAdapter = _Answer({
          'items': const [],
          'totalItems': 0,
          'totals': {'unplaced': 650, 'unplacedCount': 1},
          'unplaced': [line('u1', 'fuel', 650)],
        }));
      t.view.physicalSize = const Size(1200, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: [
          workCostsPageProvider.overrideWith((ref, q) async => page()),
          expenseServiceProvider.overrideWithValue(svc),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: ArtistFinanceByWorkView(from: '2026-11-01', to: '2026-11-30', artists: _artists))),
      ));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('costsExport')));
      await t.pumpAndSettle();
      await t.tap(find.text('Export CSV'));
      await t.pumpAndSettle();
      expect(find.text('Nothing to export for this period.'), findsNothing, reason: 'the fuel entry is something to export');
    });

    testWidgets('the export carries the unplaced entries too, marked "Not placed"', (t) async {
      final p = page(unplaced: [line('u1', 'fuel', 650, notes: 'petrol')]);
      final rows = workCostExportRows(p.items, unplaced: p.unplaced);
      final fuel = rows.firstWhere((r) => r[9] == 'Not placed');
      expect(fuel[3], 'Anu');
      expect(fuel[4], 'fuel');
      expect(fuel[7], '650.00');
      expect(fuel[1], '', reason: 'no client — it is not on a work');
      expect(rows.length, p.items.fold<int>(0, (a, w) => a + w.lines.length) + 1);
      expect(workCostExportRows(p.items).any((r) => r[9] == 'Not placed'), isFalse, reason: 'the old call is unchanged');
    });
  });

  group('the work-cost model', () {
    test('per-kind totals: every kind is always there, and under + not-under = all', () {
      final t = WorkCostTotals.fromJson({
        'food': 0, 'other': 0, 'total': 0, 'unplaced': 0, 'unplacedCount': 0,
        'byCategory': {'fuel': 1500},
        'unplacedByCategory': {'fuel': 650, 'stay': 1200},
      });
      expect(t.byCategory.keys, workCostCategories);
      expect((t.under('fuel'), t.notUnder('fuel'), t.all('fuel')), (1500, 650, 2150));
      expect((t.under('stay'), t.notUnder('stay'), t.all('stay')), (0, 1200, 1200));
      expect(t.all('materials'), 0);
      expect(WorkCostTotals.zero.all('fuel'), 0, reason: 'an older server');
      expect(WorkCostPage.fromJson(const {}).unplaced, isEmpty);
    });
  });
}
