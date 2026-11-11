import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/accounts_fleet_expenses_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/fleet_expense_filters.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_expense_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/vehicle_controller.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense_page.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/features/fleet/services/fuel_expense_service.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/money_account_picker.dart';
import 'package:nizan_crm/services/employee_service.dart';

// ── fixtures ────────────────────────────────────────────────────────────────

Map<String, dynamic> _exp(
  String id, {
  String status = 'pending',
  String category = 'fuel',
  double amount = 1000,
  String driver = 'Ravi',
  Map<String, dynamic>? split,
  Map<String, dynamic>? kmCheck,
}) =>
    {
      '_id': id, 'category': category, 'status': status, 'date': '2026-10-23T03:30:00.000Z', 'dayKey': '2026-10-23',
      'totalAmount': amount, 'liters': 0, 'odometerKm': 0, 'station': '', 'notes': '', 'paymentMode': 'cash',
      'billImage': 'https://x/bill.jpg', 'vehicleId': {'_id': 'v1', 'name': 'Innova', 'registrationNumber': 'KL 11 AB 1234'},
      'driverId': {'_id': 'd_$driver', 'name': driver},
      'split': ?split,
      'kmCheck': ?kmCheck,
    };

/// A pretend server: 45 expenses (30 pending), paged exactly as the real one does.
class _Server {
  final seen = <FuelExpenseQuery>[];
  final all = [
    for (var i = 0; i < 45; i++)
      _exp('e$i', status: i < 30 ? 'pending' : (i < 40 ? 'approved' : 'rejected'), driver: i.isEven ? 'Ravi' : 'Suresh', amount: 1000 + i.toDouble()),
  ];

  FuelExpensePage page(FuelExpenseQuery q) {
    seen.add(q);
    final start = (q.page - 1) * q.limit;
    final items = all.skip(start).take(q.limit).map(FuelExpense.fromJson).toList();
    return FuelExpensePage(
      items: items,
      page: q.page,
      limit: q.limit,
      totalItems: all.length,
      totalPages: (all.length / q.limit).ceil(),
      summary: ExpenseSummary.fromJson({
        'byStatus': {
          'pending': {'count': 30, 'amount': 30000},
          'approved': {'count': 10, 'amount': 12000},
          'rejected': {'count': 5, 'amount': 2500},
        },
        'shown': {'count': 45, 'amount': 44500},
        'byCategory': [
          {'category': 'fuel', 'count': 30, 'amount': 30000},
          {'category': 'toll', 'count': 15, 'amount': 14500},
        ],
        'byDriver': [
          {'driverId': 'd_Ravi', 'name': 'Ravi', 'count': 23, 'amount': 24000},
          {'driverId': 'd_Suresh', 'name': 'Suresh', 'count': 22, 'amount': 20500},
        ],
      }),
    );
  }
}

class _FakeService extends FuelExpenseService {
  _FakeService() : super(Dio());
  final statusCalls = <(String, String)>[];
  FuelExpenseQuery? exportedQuery;
  List<FuelExpense> exportItems = const [];
  bool truncated = false;

  @override
  Future<FuelExpense> setStatus(String id, String status, {MoneyChoice? money}) async {
    statusCalls.add((id, status));
    return FuelExpense.fromJson(_exp(id, status: status));
  }

  @override
  Future<FuelExpenseExport> exportFuelExpenses(FuelExpenseQuery query) async {
    exportedQuery = query;
    return FuelExpenseExport(exportItems, exportItems.length, truncated);
  }
}

Widget _app(_Server server, {_FakeService? service, Future<void>? gatePage2}) => ProviderScope(
      overrides: [
        accountsFuelExpensePageProvider.overrideWith((ref, q) async {
          if (q.page == 2 && gatePage2 != null) await gatePage2;
          return server.page(q);
        }),
        employeesProvider.overrideWith((ref) async => <Employee>[]),
        vehiclesProvider.overrideWith((ref) async => <Vehicle>[]),
        if (service != null) fuelExpenseServiceProvider.overrideWithValue(service),
        authSessionProvider.overrideWithValue(const AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'accounts')),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: AccountsFleetExpensesScreen())),
    );

class _Capture implements HttpClientAdapter {
  RequestOptions? last;
  Object body;
  _Capture(this.body);
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void _wide(WidgetTester t, {double w = 1400, double h = 4200}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('FuelExpenseQuery', () {
    test('defaults: newest first, page 1 of 20, nothing filtered', () {
      const q = FuelExpenseQuery();
      expect((q.sort, q.page, q.limit, q.advancedCount), ('date_desc', 1, 20, 0));
      final p = q.toParams();
      expect(p, {'sort': 'date_desc', 'withWorks': '1', 'page': '1', 'limit': '20', 'summary': '1'});
    });

    test('every filter becomes the parameter the server reads', () {
      final q = const FuelExpenseQuery().copyWith(
        from: '2026-10-01',
        to: '2026-10-31',
        statuses: {'pending', 'approved'},
        categories: {'toll', 'fuel'},
        paymentModes: {'upi'},
        driverId: 'abc',
        vehicleId: 'def',
        bill: 'without',
        work: 'whole_day',
        minAmount: 500,
        maxAmount: 2500.5,
        search: '  fathima ',
        sort: 'amount_desc',
        page: 3,
        limit: 50,
      );
      expect(q.toParams(), {
        'from': '2026-10-01',
        'to': '2026-10-31',
        'status': 'approved,pending',
        'category': 'fuel,toll',
        'paymentMode': 'upi',
        'driverId': 'abc',
        'vehicleId': 'def',
        'bill': 'without',
        'work': 'whole_day',
        'minAmount': '500.0',
        'maxAmount': '2500.5',
        'search': 'fathima',
        'sort': 'amount_desc',
        'withWorks': '1',
        'page': '3',
        'limit': '50',
        'summary': '1',
      });
    });

    test('export asks for every match: no page, no summary', () {
      final p = const FuelExpenseQuery().copyWith(page: 4, search: 'x').toParams(export: true);
      expect(p['export'], '1');
      expect(p.containsKey('page'), isFalse);
      expect(p.containsKey('summary'), isFalse);
      expect(p['withWorks'], '1');
    });

    test('changing a filter goes back to page 1; changing only the page does not', () {
      final onPage3 = const FuelExpenseQuery().copyWith(page: 3);
      expect(onPage3.refiltered(search: 'x').page, 1);
      expect(onPage3.refiltered(statuses: {'pending'}).page, 1);
      expect(onPage3.copyWith(page: 4).page, 4);
      expect(onPage3.copyWith(search: 'x').page, 3);
    });

    test('a filter can be cleared back to "any" (null) as well as set', () {
      final q = const FuelExpenseQuery().copyWith(driverId: 'abc', bill: 'with', minAmount: 5);
      expect(q.refiltered(driverId: null).driverId, isNull);
      expect(q.refiltered(bill: null).bill, isNull);
      expect(q.refiltered(minAmount: null, maxAmount: null).minAmount, isNull);
      expect(q.refiltered(search: 'y').driverId, 'abc', reason: 'untouched fields are kept');
    });

    test('equal queries are the same cached request; any difference is a new one', () {
      FuelExpenseQuery mk() => const FuelExpenseQuery().copyWith(statuses: {'a', 'b'}, categories: {'fuel'}, from: '2026-10-01');
      expect(mk(), mk());
      expect(mk().hashCode, mk().hashCode);
      expect({mk(): 1}[mk()], 1);
      expect(mk() == mk().copyWith(page: 2), isFalse);
      expect(mk() == mk().copyWith(statuses: {'a'}), isFalse);
      expect(mk() == mk().copyWith(search: 'z'), isFalse);
    });

    test('advancedCount counts the Filters-panel filters only', () {
      var q = const FuelExpenseQuery().copyWith(search: 'x', statuses: {'pending'}, sort: 'amount_asc', from: '2026-10-01');
      expect(q.advancedCount, 0, reason: 'search, status, sort and period are in the bar');
      q = q.copyWith(driverId: 'd', vehicleId: 'v', categories: {'fuel'}, paymentModes: {'cash'}, bill: 'with', work: 'linked', minAmount: 1);
      expect(q.advancedCount, 7);
      expect(q.copyWith(maxAmount: 5, minAmount: null).advancedCount, 7, reason: 'min and max together are one filter');
    });

    test('monthBounds: whole months incl. February in a leap year and December', () {
      expect(FuelExpenseQuery.monthBounds(DateTime(2028, 2, 10)), ('2028-02-01', '2028-02-29'));
      expect(FuelExpenseQuery.monthBounds(DateTime(2026, 2, 10)), ('2026-02-01', '2026-02-28'));
      expect(FuelExpenseQuery.monthBounds(DateTime(2026, 12, 31)), ('2026-12-01', '2026-12-31'));
      expect(FuelExpenseQuery.monthBounds(DateTime(2026, 10, 1)), ('2026-10-01', '2026-10-31'));
    });
  });

  group('responses', () {
    test('a page with its whole-set summary parses', () {
      final p = _Server().page(const FuelExpenseQuery());
      expect((p.totalItems, p.totalPages, p.items.length), (45, 3, 20));
      final s = p.summary!;
      expect((s.allCount, s.allAmount, s.shownCount, s.shownAmount), (45, 44500.0, 45, 44500.0));
      expect(s.status('pending').count, 30);
      expect(s.status('nonsense').count, 0);
      expect(s.byCategory.map((c) => c.category), ['fuel', 'toll']);
      expect(s.byDriver.first.name, 'Ravi');
    });

    test('an older server (no summary) still parses', () {
      final p = FuelExpensePage.fromJson({'items': <Object>[], 'page': 1, 'limit': 20, 'totalItems': 0, 'totalPages': 1});
      expect(p.summary, isNull);
      expect(p.items, isEmpty);
    });

    test('the service sends the query and reads the page; export asks for everything', () async {
      final page = _Capture({'items': [_exp('a')], 'page': 2, 'limit': 10, 'totalItems': 11, 'totalPages': 2});
      final svc = FuelExpenseService(Dio()..httpClientAdapter = page);
      final got = await svc.getFuelExpensePage(const FuelExpenseQuery().copyWith(page: 2, limit: 10));
      expect(got.items.single.id, 'a');
      expect(page.last!.queryParameters['page'], '2');
      expect(page.last!.queryParameters['limit'], '10');

      final exp = _Capture({'items': [_exp('a'), _exp('b')], 'totalItems': 6000, 'truncated': true});
      final ex = await FuelExpenseService(Dio()..httpClientAdapter = exp).exportFuelExpenses(const FuelExpenseQuery());
      expect((ex.items.length, ex.totalItems, ex.truncated), (2, 6000, true));
      expect(exp.last!.queryParameters['export'], '1');
      expect(exp.last!.queryParameters.containsKey('page'), isFalse);
    });
  });

  group('screen', () {
    final thisMonth = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(thisMonth);
    final (monthFrom, monthTo) = FuelExpenseQuery.monthBounds(thisMonth);

    testWidgets('opens on THIS MONTH, newest first, page 1, with totals for the whole set', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      final q = s.seen.last;
      expect((q.from, q.to, q.page, q.limit, q.sort), (monthFrom, monthTo, 1, 20, 'date_desc'));
      expect(find.text(monthLabel), findsOneWidget);
      // the four cards come from the server's whole-set summary, not the 20 rows on screen
      expect(find.text('₹44,500'), findsWidgets);
      expect(find.text('Total · 45'), findsOneWidget);
      expect(find.text('Pending review · 30'), findsOneWidget);
      expect(find.text('Approved · 10'), findsOneWidget);
      expect(find.text('Rejected · 5'), findsOneWidget);
      expect(find.text('Showing 1–20 of 45  ·  ₹44,500'), findsOneWidget);
      expect(find.byType(Card), findsNothing); // (the cards are containers; just making sure nothing odd)
    });

    testWidgets('MONTH SWITCHER: previous month, back to this month; next is disabled on the current month', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      expect(t.widget<IconButton>(find.byKey(const Key('periodNext'))).onPressed, isNull);

      await t.tap(find.byKey(const Key('periodPrev')));
      await t.pumpAndSettle();
      final prev = DateTime(thisMonth.year, thisMonth.month - 1);
      final (pf, pt) = FuelExpenseQuery.monthBounds(prev);
      expect((s.seen.last.from, s.seen.last.to), (pf, pt));
      expect(find.text(DateFormat('MMMM yyyy').format(prev)), findsOneWidget);
      expect(t.widget<IconButton>(find.byKey(const Key('periodNext'))).onPressed, isNotNull);

      await t.tap(find.byKey(const Key('periodNext')));
      await t.pumpAndSettle();
      expect((s.seen.last.from, s.seen.last.to), (monthFrom, monthTo));
    });

    testWidgets('this month / last month chips, and ALL TIME drops the dates', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      await t.tap(find.text('Last month'));
      await t.pumpAndSettle();
      expect(s.seen.last.from, FuelExpenseQuery.monthBounds(DateTime(thisMonth.year, thisMonth.month - 1)).$1);
      await t.tap(find.byKey(const Key('periodAll')));
      await t.pumpAndSettle();
      expect((s.seen.last.from, s.seen.last.to), (null, null));
      expect(find.text('All time'), findsWidgets);
      await t.tap(find.text('This month'));
      await t.pumpAndSettle();
      expect(s.seen.last.from, monthFrom);
    });

    testWidgets('changing the month goes back to page 1', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(s.seen.last.page, 2);
      await t.tap(find.byKey(const Key('periodPrev')));
      await t.pumpAndSettle();
      expect(s.seen.last.page, 1);
    });

    testWidgets('PAGINATION: next / previous move through the pages', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      // (Previous is an outlined button, Next an elevated one)
      expect(t.widget<OutlinedButton>(find.ancestor(of: find.text('Previous'), matching: find.bySubtype<OutlinedButton>())).onPressed, isNull);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(s.seen.last.page, 2);
      expect(find.text('Showing 21–40 of 45  ·  ₹44,500'), findsOneWidget);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.text('Showing 41–45 of 45  ·  ₹44,500'), findsOneWidget);
      expect(t.widget<ElevatedButton>(find.ancestor(of: find.text('Next'), matching: find.bySubtype<ElevatedButton>())).onPressed, isNull);
      await t.tap(find.text('Previous'));
      await t.pumpAndSettle();
      expect(s.seen.last.page, 2);
    });

    testWidgets('rows per page: 50 → one page, and back to page 1', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('pageSizeMenu')));
      await t.pumpAndSettle();
      await t.tap(find.text('50 per page'));
      await t.pumpAndSettle();
      expect((s.seen.last.limit, s.seen.last.page), (50, 1));
      expect(find.text('Showing 1–45 of 45  ·  ₹44,500'), findsOneWidget);
    });

    testWidgets('the previous page stays on screen (with a progress bar) while the next one loads', (t) async {
      _wide(t);
      final gate = Completer<void>();
      final s = _Server();
      await t.pumpWidget(_app(s, gatePage2: gate.future));
      await t.pumpAndSettle();
      expect(find.text('Showing 1–20 of 45  ·  ₹44,500'), findsOneWidget);
      await t.tap(find.text('Next'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Showing 1–20 of 45  ·  ₹44,500'), findsOneWidget, reason: 'no blank flash while loading');
      gate.complete();
      await t.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Showing 21–40 of 45  ·  ₹44,500'), findsOneWidget);
    });

    testWidgets('STATUS chips carry counts and filter the list', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      expect(find.text('All (45)'), findsOneWidget);
      expect(find.text('Pending (30)'), findsOneWidget);
      await t.tap(find.byKey(const Key('status_pending')));
      await t.pumpAndSettle();
      expect(s.seen.last.statuses, {'pending'});
      await t.tap(find.byKey(const Key('status_all')));
      await t.pumpAndSettle();
      expect(s.seen.last.statuses, isEmpty);
    });

    testWidgets('SEARCH waits for a pause in typing, then searches from page 1', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      final before = s.seen.length;
      await t.enterText(find.byKey(const Key('searchField')), 'fath');
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(find.byKey(const Key('searchField')), 'fathima');
      await t.pump(const Duration(milliseconds: 200));
      expect(s.seen.length, before, reason: 'still typing: no request yet');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      expect(s.seen.length, before + 1, reason: 'one request for the whole word');
      expect((s.seen.last.search, s.seen.last.page), ('fathima', 1));
      expect(find.text('Search: "fathima"'), findsOneWidget);
    });

    testWidgets('SORT: highest amount first', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sortMenu')));
      await t.pumpAndSettle();
      await t.tap(find.text('Highest amount').last);
      await t.pumpAndSettle();
      expect(s.seen.last.sort, 'amount_desc');
      expect(find.text('Highest amount'), findsOneWidget);
    });

    testWidgets('ADVANCED FILTERS: category, bill, amount range → applied, counted on the button, shown as chips', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      final dialog = find.byType(Dialog);
      await t.tap(find.descendant(of: dialog, matching: find.widgetWithText(FilterChip, 'Toll')));
      await t.tap(find.descendant(of: dialog, matching: find.widgetWithText(FilterChip, 'UPI')));
      await t.tap(find.descendant(of: dialog, matching: find.text('With bill')));
      await t.tap(find.descendant(of: dialog, matching: find.text('Whole day')));
      await t.enterText(find.byKey(const Key('filterMin')), '500');
      await t.enterText(find.byKey(const Key('filterMax')), '2500');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();
      final q = s.seen.last;
      expect(q.categories, {'toll'});
      expect(q.paymentModes, {'upi'});
      expect((q.bill, q.work, q.minAmount, q.maxAmount), ('with', 'whole_day', 500.0, 2500.0));
      expect(q.advancedCount, 5);
      expect(find.text('5'), findsWidgets); // the badge on the Filters button
      expect(find.text('Category: Toll'), findsOneWidget);
      expect(find.text('Payment: UPI'), findsOneWidget);
      expect(find.text('With bill'), findsOneWidget);
      expect(find.text('Whole day'), findsOneWidget);
      expect(find.text('Amount: ₹500 – ₹2,500'), findsOneWidget);
    });

    testWidgets('the filters form refuses nonsense amounts and keeps what was set when re-opened', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('filterMin')), '900');
      await t.enterText(find.byKey(const Key('filterMax')), '100');
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();
      expect(find.text('The minimum is more than the maximum.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('filterMin')), 'abc');
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();
      expect(find.text('Amounts must be numbers, 0 or more.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('filterMin')), '100');
      await t.enterText(find.byKey(const Key('filterMax')), '900');
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();
      // re-open: the values are still there
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(find.byKey(const Key('filterMin'))).controller!.text, '100');
      expect(t.widget<TextField>(find.byKey(const Key('filterMax'))).controller!.text, '900');
      // Reset clears the form
      await t.tap(find.text('Reset'));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(find.byKey(const Key('filterMin'))).controller!.text, '');
    });

    testWidgets('a chip removes just its filter; Clear all removes the filters and search but keeps the month', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      await t.tap(find.descendant(of: find.byType(Dialog), matching: find.text('With bill')));
      await t.tap(find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(FilterChip, 'Fuel')));
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('status_pending')));
      await t.pumpAndSettle();
      expect(s.seen.last.bill, 'with');

      t.widget<InputChip>(find.widgetWithText(InputChip, 'With bill')).onDeleted!();
      await t.pumpAndSettle();
      expect(s.seen.last.bill, isNull);
      expect(s.seen.last.categories, {'fuel'});
      expect(s.seen.last.statuses, {'pending'});

      await t.tap(find.byKey(const Key('clearAll')));
      await t.pumpAndSettle();
      final q = s.seen.last;
      expect(q.categories, isEmpty);
      expect(q.statuses, isEmpty);
      expect(q.advancedCount, 0);
      expect((q.from, q.to), (monthFrom, monthTo), reason: 'the month is the period, not a filter');
      expect(find.byKey(const Key('clearAll')), findsNothing);
    });

    testWidgets('BREAKDOWN: tap a category or a driver to filter to it, tap again to undo', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      expect(find.text('Fuel  ₹30,000'), findsOneWidget);
      await t.tap(find.byKey(const Key('cat_fuel')));
      await t.pumpAndSettle();
      expect(s.seen.last.categories, {'fuel'});
      await t.tap(find.byKey(const Key('cat_fuel')));
      await t.pumpAndSettle();
      expect(s.seen.last.categories, isEmpty);
      await t.tap(find.byKey(const Key('drv_d_Suresh')));
      await t.pumpAndSettle();
      expect(s.seen.last.driverId, 'd_Suresh');
      await t.tap(find.byKey(const Key('drv_d_Suresh')));
      await t.pumpAndSettle();
      expect(s.seen.last.driverId, isNull);
    });

    testWidgets('empty results: with filters → "match these filters" + Clear; without → "in this period"', (t) async {
      _wide(t);
      final s = _Server()..all.clear();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      expect(find.text('No fleet expenses in this period.'), findsOneWidget);
      await t.tap(find.byKey(const Key('status_pending')));
      await t.pumpAndSettle();
      expect(find.text('No fleet expenses match these filters.'), findsOneWidget);
      await t.tap(find.text('Clear filters'));
      await t.pumpAndSettle();
      expect(find.text('No fleet expenses in this period.'), findsOneWidget);
    });

    testWidgets('a server error on the first load shows the error with Retry', (t) async {
      _wide(t);
      await t.pumpWidget(ProviderScope(
        overrides: [
          accountsFuelExpensePageProvider.overrideWith((ref, q) async => throw AppException(Exception('boom'), action: 'load fuel expenses')),
          employeesProvider.overrideWith((ref) async => <Employee>[]),
          vehiclesProvider.overrideWith((ref) async => <Vehicle>[]),
          authSessionProvider.overrideWithValue(const AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'accounts')),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: AccountsFleetExpensesScreen())),
      ));
      await t.pumpAndSettle();
      expect(find.textContaining('Exception'), findsNothing, reason: 'no raw exception text or stack');
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('BULK: tick pending expenses → bar with count and total; select all; reject them all', (t) async {
      _wide(t);
      final s = _Server();
      final svc = _FakeService();
      await t.pumpWidget(_app(s, service: svc));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('bulkReject')), findsNothing);

      await t.tap(find.byKey(const Key('select_e0')));
      await t.tap(find.byKey(const Key('select_e1')));
      await t.pumpAndSettle();
      expect(find.text('2 selected · ₹2,001'), findsOneWidget); // 1000 + 1001

      await t.tap(find.byKey(const Key('selectAllPending')));
      await t.pumpAndSettle();
      expect(find.textContaining('20 selected'), findsOneWidget);
      await t.tap(find.byKey(const Key('selectAllPending')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('bulkReject')), findsNothing, reason: 'unticking all removes the bar');

      await t.tap(find.byKey(const Key('select_e2')));
      await t.tap(find.byKey(const Key('select_e3')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('bulkReject')));
      await t.pumpAndSettle();
      expect(find.text('Reject 2 expenses?'), findsOneWidget);
      await t.tap(find.text('Reject all'));
      await t.pumpAndSettle();
      expect(svc.statusCalls, [('e2', 'rejected'), ('e3', 'rejected')]);
      expect(find.text('Rejected 2 expenses.'), findsOneWidget);
      expect(find.byKey(const Key('bulkReject')), findsNothing, reason: 'selection cleared');
    });

    testWidgets('BULK: cancelling the confirmation changes nothing; a change of filter clears the ticks', (t) async {
      _wide(t);
      final s = _Server();
      final svc = _FakeService();
      await t.pumpWidget(_app(s, service: svc));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('select_e0')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('bulkReject')));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(svc.statusCalls, isEmpty);
      expect(find.byKey(const Key('bulkReject')), findsOneWidget, reason: 'still ticked');
      await t.tap(find.byKey(const Key('status_approved')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('bulkReject')), findsNothing, reason: 'the ticked rows are no longer on screen');
    });

    testWidgets('BULK approve asks which bank / cash account for the whole batch', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s, service: _FakeService()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('select_e0')));
      await t.tap(find.byKey(const Key('select_e1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('bulkApprove')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Approve 2 fleet expenses'), findsOneWidget);
      expect(find.text('Approve all'), findsOneWidget);
    });

    testWidgets('only pending expenses can be ticked', (t) async {
      _wide(t);
      final s = _Server();
      await t.pumpWidget(_app(s));
      await t.pumpAndSettle();
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      // page 2 = e20..e39: e20–e29 pending, e30–e39 approved
      expect(find.byKey(const Key('select_e25')), findsOneWidget);
      expect(find.byKey(const Key('select_e35')), findsNothing);
    });

    testWidgets('EXPORT sends the current filters and exports every match, not the page', (t) async {
      _wide(t);
      final s = _Server();
      final svc = _FakeService()..exportItems = s.all.take(3).map(FuelExpense.fromJson).toList();
      await t.pumpWidget(_app(s, service: svc));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('status_pending')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('exportButton')));
      await t.pumpAndSettle();
      expect(svc.exportedQuery!.statuses, {'pending'});
      expect(svc.exportedQuery!.from, monthFrom);
      expect(find.text('Export Fleet Expenses $monthLabel'), findsOneWidget);
    });

    testWidgets('export with nothing to export says so; a capped export says how much was left out', (t) async {
      _wide(t);
      final s = _Server();
      final empty = _FakeService();
      await t.pumpWidget(_app(s, service: empty));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('exportButton')));
      await t.pumpAndSettle();
      expect(find.text('Nothing to export for these filters.'), findsOneWidget);
    });
  });

  group('export rows (for Accounts)', () {
    FuelExpense withSplit(Map<String, dynamic> split) => FuelExpense.fromJson(_exp('x', split: split, kmCheck: {
          'dayKey': '2026-10-23', 'status': 'over', 'routeState': 'ok', 'works': 2, 'trackedKm': 30, 'workMissing': false,
        }));

    Map<String, dynamic> work(String client, String artist, [String no = 'BK-1']) => {
          'bookingId': client, 'bookingNumber': no, 'customerName': client, 'amount': 150, 'place': '', 'mapUrl': '',
          'artists': [{'name': artist, 'roleType': 'lead'}],
        };

    test('a whole-day expense: how it was shared, the clients and the artists', () {
      final row = fleetExpenseExportRow(withSplit({
        'mode': 'shared', 'counted': true, 'reason': '', 'total': 300,
        'works': [work('Fathima Rahman', 'Priya'), work('Anjali Menon', 'Kavya', 'BK-2')],
      }));
      expect(row.length, kFleetExpenseExportHeaders.length);
      final byName = {for (var i = 0; i < row.length; i++) kFleetExpenseExportHeaders[i]: row[i]};
      expect(byName['Tied to'], 'Whole day (shared equally)');
      expect(byName['Client(s)'], 'Fathima Rahman; Anjali Menon');
      expect(byName['Artist(s)'], 'Priya; Kavya');
      expect(byName['Km check'], 'Over plan');
      expect(byName['Category'], 'Fuel');
    });

    test('one work, no work, and an old expense with no split', () {
      String col(List<String> row, String h) => row[kFleetExpenseExportHeaders.indexOf(h)];
      final one = fleetExpenseExportRow(withSplit({'mode': 'direct', 'counted': true, 'reason': '', 'total': 150, 'works': [work('Fathima Rahman', 'Priya')]}));
      expect(col(one, 'Tied to'), 'One work');
      final none = fleetExpenseExportRow(withSplit({'mode': 'unallocated', 'counted': true, 'reason': 'x', 'total': 150, 'works': <Object>[]}));
      expect(col(none, 'Tied to'), 'No work');
      expect(col(none, 'Client(s)'), '');
      final old = fleetExpenseExportRow(FuelExpense.fromJson(_exp('o')));
      expect(col(old, 'Tied to'), '');
      expect(col(old, 'Km check'), '');
    });
  });

  group('the filter widgets fit a phone (360 px) with no overflow', () {
    void phone(WidgetTester t) {
      t.view.physicalSize = const Size(1080, 4000);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
    }

    Widget host(Widget child) => MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)));

    testWidgets('period bar — month, range and all-time labels', (t) async {
      phone(t);
      for (final p in FinancePeriod.values) {
        await t.pumpWidget(host(FinancePeriodBar(
          period: p,
          month: DateTime(2026, 9),
          range: DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 10, 31)),
          onMonth: (_) {},
          onRange: (_) {},
          onAll: () {},
        )));
        expect(t.takeException(), isNull, reason: '$p');
      }
    });

    testWidgets('active filter chips with every filter on, and the breakdown', (t) async {
      phone(t);
      final q = const FuelExpenseQuery().copyWith(
        search: 'a long search phrase here', statuses: {'pending'}, driverId: 'd', vehicleId: 'v',
        categories: {'fuel', 'toll', 'parking'}, paymentModes: {'cash', 'upi'}, bill: 'with', work: 'linked', minAmount: 100, maxAmount: 99999,
      );
      await t.pumpWidget(host(Column(children: [
        ActiveFilterChips(query: q, driverName: 'Ravi Menon Kumar', vehicleName: 'Innova · KL 11 AB 1234', onChanged: (_) {}, onClearAll: () {}),
        const SizedBox(height: 12),
        ExpenseBreakdown(summary: _Server().page(const FuelExpenseQuery()).summary!, query: q, onCategory: (_) {}, onDriver: (_) {}),
        const SizedBox(height: 12),
        BulkActionBar(count: 12, amount: 123456, busy: false, onApprove: () {}, onReject: () {}, onClear: () {}),
      ])));
      expect(t.takeException(), isNull);
    });

    testWidgets('the advanced-filters form as a bottom sheet', (t) async {
      phone(t);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showExpenseFilters(context, current: const FuelExpenseQuery(), drivers: [(id: 'd', name: 'Ravi')], vehicles: [(id: 'v', name: 'Innova · KL 11 AB 1234')]),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('Filters'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
