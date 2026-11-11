import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/models/trial.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/trial_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/presentation/screens/artist_finance_screen.dart';
import 'package:nizan_crm/services/employee_service.dart';

// Artist Finance: the Collections and Expenses tabs are filtered, sorted and paged
// on the server. These tests drive the real screen against a pretend server that
// records every query it is asked.

class _FakeBookingNotifier extends BookingNotifier {
  @override
  FutureOr<List<Booking>> build() => <Booking>[];
}

Map<String, dynamic> _coll(int i, {String status = 'verified'}) => {
      '_id': 'c$i',
      'amount': 1000.0 + i,
      'status': status,
      'paymentMode': i.isEven ? 'upi' : 'cash',
      'date': '2026-10-12T04:30:00.000Z',
      'bookingId': {'_id': 'b$i', 'bookingNumber': 'BK-$i', 'customerName': 'Client $i', 'service': 'Bridal'},
      'employeeId': {'_id': 'e1', 'name': 'Anu'},
    };

Map<String, dynamic> _exp(int i, {String status = 'verified'}) => {
      '_id': 'x$i',
      'amount': 300.0 + i,
      'status': status,
      'category': i.isEven ? 'food' : 'travel',
      'workType': i < 20 ? 'bridal' : 'model_shoot',
      'date': '2026-10-12T04:30:00.000Z',
      'employeeId': {'_id': 'e1', 'name': 'Anu'},
      'notes': 'Expense note $i',
    };

/// A pretend server: 45 collections and 30 expenses, paged the way the real one is.
/// The totals are fixed so that what the screen shows can be checked exactly.
class _Server {
  final collQueries = <FinanceQuery>[];
  final expQueries = <FinanceQuery>[];
  int collTotal = 45;
  int expTotal = 30;

  /// Called before a page is answered; return a future to hold the answer back,
  /// or throw to make the request fail.
  Future<void> Function(FinanceQuery q)? collGate;

  FinanceSummary _collSummary() => FinanceSummary.fromJson({
        'byStatus': {
          'pending': {'count': 5, 'amount': 5000},
          'verified': {'count': 35, 'amount': 40000},
          'rejected': {'count': 5, 'amount': 99999},
        },
        'shown': {'count': collTotal, 'amount': 144999},
        'byMode': [
          {'mode': 'upi', 'count': 25, 'amount': 30000},
          {'mode': 'cash', 'count': 20, 'amount': 15000},
        ],
        'byArtist': [
          {'employeeId': 'e1', 'name': 'Anu', 'count': 45, 'amount': 144999},
        ],
      });

  FinanceSummary _expSummary() => FinanceSummary.fromJson({
        'byStatus': {
          'pending': {'count': 4, 'amount': 1600},
          'verified': {'count': 26, 'amount': 9400},
        },
        'shown': {'count': expTotal, 'amount': 11000},
        'byCategory': [
          {'category': 'food', 'count': 15, 'amount': 5000},
          {'category': 'travel', 'count': 15, 'amount': 6000},
        ],
        'byWorkType': [
          {'workType': 'bridal', 'count': 20, 'amount': 8000},
          {'workType': 'model_shoot', 'count': 10, 'amount': 3000},
        ],
        'byArtist': [
          {'employeeId': 'e1', 'name': 'Anu', 'count': 30, 'amount': 11000},
        ],
      });

  Future<FinancePage<ArtistCollection>> collections(FinanceQuery q) async {
    collQueries.add(q);
    await collGate?.call(q);
    final start = (q.page - 1) * q.limit;
    final n = math.max(0, math.min(q.limit, collTotal - start));
    return FinancePage(
      items: [for (var i = start; i < start + n; i++) ArtistCollection.fromJson(_coll(i, status: i < 5 ? 'pending' : 'verified'))],
      page: q.page,
      limit: q.limit,
      totalItems: collTotal,
      totalPages: math.max(1, (collTotal / q.limit).ceil()),
      summary: _collSummary(),
    );
  }

  Future<FinancePage<ArtistExpense>> expenses(FinanceQuery q) async {
    expQueries.add(q);
    final start = (q.page - 1) * q.limit;
    final n = math.max(0, math.min(q.limit, expTotal - start));
    return FinancePage(
      items: [for (var i = start; i < start + n; i++) ArtistExpense.fromJson(_exp(i, status: i < 4 ? 'pending' : 'verified'))],
      page: q.page,
      limit: q.limit,
      totalItems: expTotal,
      totalPages: math.max(1, (expTotal / q.limit).ceil()),
      summary: _expSummary(),
    );
  }
}

Employee _employee(String id, String name) => Employee.fromJson({'_id': id, 'name': name, 'artistRole': 'artist', 'status': 'active'});

Widget _app(_Server server, {String role = 'accounts', String employeeId = ''}) => ProviderScope(
      overrides: [
        financeCollectionsPageProvider.overrideWith((ref, q) => server.collections(q)),
        financeExpensesPageProvider.overrideWith((ref, q) => server.expenses(q)),
        employeesProvider.overrideWith((ref) async => [_employee('e1', 'Anu'), _employee('e2', 'Fathima')]),
        bookingProvider.overrideWith(() => _FakeBookingNotifier()),
        allTrialsProvider.overrideWith((ref) async => <Trial>[]),
        authSessionProvider.overrideWithValue(
          AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role, employeeId: employeeId),
        ),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: ArtistFinanceScreen())),
    );

void _size(WidgetTester t, {double w = 1400, double h = 12000}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _open(WidgetTester t, _Server server, {String role = 'accounts', String employeeId = '', double w = 1400}) async {
  _size(t, w: w);
  await t.pumpWidget(_app(server, role: role, employeeId: employeeId));
  await t.pumpAndSettle();
}

Future<void> _openExpenses(WidgetTester t) async {
  await t.tap(find.text('EXPENSES'));
  await t.pumpAndSettle();
}

ProviderContainer _container(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(ArtistFinanceScreen)));

void main() {
  final now = DateTime.now();
  final thisMonth = FinanceQuery.monthBounds(now);
  final lastMonthStart = DateTime(now.year, now.month - 1);
  final lastMonth = FinanceQuery.monthBounds(lastMonthStart);

  group('first look', () {
    testWidgets('opens on this month: both tabs ask the server for page 1 of the current month, newest first', (t) async {
      final server = _Server();
      await _open(t, server);
      expect(server.collQueries, hasLength(1));
      expect(server.expQueries, hasLength(1));
      for (final q in [server.collQueries.single, server.expQueries.single]) {
        expect((q.from, q.to), (thisMonth.$1, thisMonth.$2));
        expect((q.page, q.limit, q.sort), (1, 20, 'date_desc'));
        expect(q.isFiltered, isFalse);
      }
      expect(find.text(DateFormat('MMMM yyyy').format(now)), findsOneWidget, reason: 'the period bar names the month');
      expect(find.textContaining('Showing 1–20 of 45'), findsOneWidget);
      expect(find.text('Client 0'), findsOneWidget);
      expect(find.text('Client 19'), findsOneWidget);
      expect(find.text('Client 20'), findsNothing, reason: 'only one page is on screen');
    });

    testWidgets('the cards come from the server totals: verified only, and no invented trend', (t) async {
      await _open(t, _Server());
      expect(find.text('TOTAL COLLECTED'), findsOneWidget);
      // verified = 40000; the rejected 99999 and the pending 5000 are not "collected"
      expect(find.text('₹ 40000'), findsOneWidget);
      expect(find.textContaining('35 verified'), findsOneWidget);
      expect(find.textContaining('+12%'), findsNothing);
      // pending = 5 collections + 4 expenses
      expect(find.text('9'), findsOneWidget);
      expect(find.text('5 collections · 4 expenses'), findsOneWidget);
    });

    testWidgets('status chips carry the whole-set counts', (t) async {
      await _open(t, _Server());
      expect(find.text('All (45)'), findsOneWidget);
      expect(find.text('Pending (5)'), findsOneWidget);
      expect(find.text('Verified (35)'), findsOneWidget);
      expect(find.text('Rejected (5)'), findsOneWidget);
    });
  });

  group('month switcher', () {
    testWidgets('stepping back a month re-asks BOTH tabs, from page 1', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(server.collQueries.last.page, 2);

      await t.tap(find.byKey(const Key('periodPrev')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.page, 1, reason: 'a new period starts at the first page');
      expect((server.collQueries.last.from, server.collQueries.last.to), (lastMonth.$1, lastMonth.$2));
      expect((server.expQueries.last.from, server.expQueries.last.to), (lastMonth.$1, lastMonth.$2));
      expect(find.text(DateFormat('MMMM yyyy').format(lastMonthStart)), findsOneWidget);
    });

    testWidgets('"All time" drops the dates; "This month" brings them back', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.byKey(const Key('periodAll')));
      await t.pumpAndSettle();
      expect((server.collQueries.last.from, server.collQueries.last.to), (null, null));
      expect((server.expQueries.last.from, server.expQueries.last.to), (null, null));
      expect(find.text('All time'), findsWidgets);

      await t.tap(find.text('This month'));
      await t.pumpAndSettle();
      expect((server.collQueries.last.from, server.collQueries.last.to), (thisMonth.$1, thisMonth.$2));
    });

    testWidgets('changing the month keeps each tab\'s own filters', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.byKey(const Key('status_pending')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('periodPrev')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.statuses, {'pending'});
      expect(server.collQueries.last.from, lastMonth.$1);
    });
  });

  group('paging', () {
    testWidgets('Next asks for page 2 and shows it; Previous goes back', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(server.collQueries.last.page, 2);
      expect(find.text('Client 20'), findsOneWidget);
      expect(find.text('Client 0'), findsNothing);
      expect(find.textContaining('Showing 21–40 of 45'), findsOneWidget);

      await t.tap(find.text('Previous'));
      await t.pumpAndSettle();
      expect(server.collQueries.last.page, 1);
      expect(find.text('Client 0'), findsOneWidget);
    });

    testWidgets('the last page is a short one, and Next is off', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(server.collQueries.last.page, 3);
      expect(find.textContaining('Showing 41–45 of 45'), findsOneWidget);
      expect(find.text('Client 44'), findsOneWidget);
      expect(find.text('Client 45'), findsNothing);
    });

    testWidgets('the page that was on screen stays visible, with a progress bar, while the next one loads', (t) async {
      final server = _Server();
      final release = Completer<void>();
      server.collGate = (q) async {
        if (q.page == 2) await release.future;
      };
      await _open(t, server);
      await t.tap(find.text('Next'));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('Client 0'), findsOneWidget, reason: 'no blank screen between pages');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      release.complete();
      await t.pumpAndSettle();
      expect(find.text('Client 20'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('each tab pages on its own', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.text('Next')); // collections → page 2
      await t.pumpAndSettle();
      await _openExpenses(t);
      expect(server.expQueries.last.page, 1, reason: 'collections page 2 does not move the expenses');
      expect(find.textContaining('Showing 1–20 of 30'), findsOneWidget);

      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(server.expQueries.last.page, 2);
      expect(find.textContaining('Showing 21–30 of 30'), findsOneWidget);

      await t.tap(find.text('COLLECTIONS'));
      await t.pumpAndSettle();
      expect(find.textContaining('Showing 21–40 of 45'), findsOneWidget, reason: 'collections is still on its own page 2');
    });

    testWidgets('page size: 50 per page asks for limit 50 from page 1', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('pageSizeMenu')));
      await t.pumpAndSettle();
      await t.tap(find.text('50 per page'));
      await t.pumpAndSettle();
      expect((server.collQueries.last.limit, server.collQueries.last.page), (50, 1));
      expect(find.textContaining('Showing 1–45 of 45'), findsOneWidget);
    });

    testWidgets('when the last entry of the last page goes away, the screen steps back to a page that exists', (t) async {
      final server = _Server()..collTotal = 41; // 3 pages, the last holding one entry
      await _open(t, server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(server.collQueries.last.page, 3);
      expect(find.text('Client 40'), findsOneWidget);

      server.collTotal = 40; // that one was approved elsewhere / deleted
      _container(t).invalidate(financeCollectionsPageProvider);
      await t.pumpAndSettle();
      expect(server.collQueries.last.page, 2);
      expect(find.textContaining('Showing 21–40 of 40'), findsOneWidget);
      expect(find.text('Client 39'), findsOneWidget);
    });
  });

  group('search, status, sort', () {
    testWidgets('search waits for the typing to stop, then asks the server and shows a removable chip', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      final before = server.collQueries.length;

      await t.enterText(find.byKey(const Key('searchField')), 'an');
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(find.byKey(const Key('searchField')), 'anu');
      await t.pump(const Duration(milliseconds: 200));
      expect(server.collQueries.length, before, reason: 'nothing is sent while the user is still typing');

      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(server.collQueries.length, before + 1, reason: 'one request for the whole word');
      expect(server.collQueries.last.search, 'anu');
      expect(server.collQueries.last.page, 1);
      expect(find.text('Search: "anu"'), findsOneWidget);

      await t.tap(find.byKey(const Key('clearAll')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.search, '');
      expect(find.text('Search: "anu"'), findsNothing);
      expect(t.widget<TextField>(find.byKey(const Key('searchField'))).controller!.text, '');
    });

    testWidgets('a status chip filters on the server and is that tab\'s alone', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('status_pending')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.statuses, {'pending'});
      expect(server.collQueries.last.page, 1);
      expect(find.text('Status: Pending'), findsOneWidget);

      await _openExpenses(t);
      expect(server.expQueries.last.statuses, isEmpty);
      await t.tap(find.text('COLLECTIONS'));
      await t.pumpAndSettle();
      expect(server.collQueries.last.statuses, {'pending'}, reason: 'still set when you come back');

      await t.tap(find.byKey(const Key('status_all')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.statuses, isEmpty);
    });

    testWidgets('sorting by amount asks for it and returns to page 1', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sortMenu')));
      await t.pumpAndSettle();
      await t.tap(find.text('Highest amount').last);
      await t.pumpAndSettle();
      expect(server.collQueries.last.sort, 'amount_desc');
      expect(server.collQueries.last.page, 1);
    });
  });

  group('advanced filters', () {
    testWidgets('the collection filters apply on the server and show as chips with a count', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      expect(find.text('Payment mode'.toUpperCase()), findsOneWidget);
      expect(find.text('Category'.toUpperCase()), findsNothing, reason: 'categories are for expenses');

      await t.tap(find.widgetWithText(FilterChip, 'UPI'));
      await t.enterText(find.byKey(const Key('filterMin')), '500');
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();

      final q = server.collQueries.last;
      expect(q.paymentModes, {'upi'});
      expect(q.minAmount, 500.0);
      expect(q.page, 1);
      expect(q.advancedCount, 2);
      expect(find.text('Payment: UPI'), findsOneWidget);
      expect(find.textContaining('Amount: ₹500'), findsOneWidget);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('2')), findsOneWidget);
    });

    testWidgets('a chip\'s ✕ takes off just that filter', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilterChip, 'UPI'));
      await t.enterText(find.byKey(const Key('filterMin')), '500');
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();

      final chip = find.widgetWithText(InputChip, 'Payment: UPI');
      await t.tap(find.descendant(of: chip, matching: find.byTooltip('Delete')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.paymentModes, isEmpty);
      expect(server.collQueries.last.minAmount, 500.0, reason: 'the amount filter is still on');
    });

    testWidgets('Expenses has its own filters (category, work type), apart from Collections\'', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilterChip, 'Cash'));
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.paymentModes, {'cash'});

      await _openExpenses(t);
      expect(server.expQueries.last.paymentModes, isEmpty, reason: 'a payment mode means nothing to expenses');
      expect(find.text('Payment: Cash'), findsNothing);

      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      expect(find.text('Category'.toUpperCase()), findsOneWidget);
      expect(find.text('Payment mode'.toUpperCase()), findsNothing);
      await t.tap(find.widgetWithText(FilterChip, 'Food'));
      await t.tap(find.text('Model shoot'));
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();
      expect(server.expQueries.last.categories, {'food'});
      expect(server.expQueries.last.workType, 'model_shoot');
      expect(find.text('Category: Food'), findsOneWidget);
    });

    testWidgets('a minimum above the maximum is refused before anything is sent', (t) async {
      final server = _Server();
      await _open(t, server);
      final before = server.collQueries.length;
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('filterMin')), '900');
      await t.enterText(find.byKey(const Key('filterMax')), '100');
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();
      expect(find.text('The minimum is more than the maximum.'), findsOneWidget);
      expect(server.collQueries.length, before);
    });

    testWidgets('the artist filter picks from the artists, and filters on the server', (t) async {
      final server = _Server();
      await _open(t, server);
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String?>));
      await t.pumpAndSettle();
      await t.tap(find.text('Fathima').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.employeeId, 'e2');
      expect(find.text('Artist: Fathima'), findsOneWidget);
    });
  });

  group('breakdown', () {
    testWidgets('collections: tapping a payment mode or an artist filters to it, tapping again undoes it', (t) async {
      final server = _Server();
      await _open(t, server);
      expect(find.text('BY PAYMENT MODE'), findsOneWidget);
      await t.tap(find.byKey(const Key('mode_upi')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.paymentModes, {'upi'});
      await t.tap(find.byKey(const Key('mode_upi')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.paymentModes, isEmpty);

      await t.tap(find.byKey(const Key('artist_e1')));
      await t.pumpAndSettle();
      expect(server.collQueries.last.employeeId, 'e1');
    });

    testWidgets('expenses: by category and by work type', (t) async {
      final server = _Server();
      await _open(t, server);
      await _openExpenses(t);
      expect(find.text('BY CATEGORY'), findsOneWidget);
      expect(find.text('BY WORK TYPE'), findsOneWidget);
      await t.tap(find.byKey(const Key('category_travel')));
      await t.pumpAndSettle();
      expect(server.expQueries.last.categories, {'travel'});
      await t.tap(find.byKey(const Key('work_model_shoot')));
      await t.pumpAndSettle();
      expect(server.expQueries.last.workType, 'model_shoot');
      await t.tap(find.byKey(const Key('work_model_shoot')));
      await t.pumpAndSettle();
      expect(server.expQueries.last.workType, isNull);
    });

    testWidgets('the bridal and model-shoot cards are the totals of the whole filtered set', (t) async {
      final server = _Server();
      await _open(t, server);
      await _openExpenses(t);
      expect(find.text('Bridal Work'), findsOneWidget);
      expect(find.text('₹ 8000'), findsOneWidget);
      expect(find.text('Model Shoot'), findsOneWidget);
      expect(find.text('₹ 3000'), findsOneWidget);
    });
  });

  group('who sees what', () {
    testWidgets('Accounts can approve a pending entry, and cannot edit it', (t) async {
      await _open(t, _Server());
      expect(find.byTooltip('Approve'), findsWidgets);
      expect(find.byTooltip('Reject'), findsWidgets);
      expect(find.byTooltip('Edit this collection'), findsNothing);
    });

    testWidgets('an artist gets only their own: no artist picker, no artist breakdown, no approve — but can edit a pending one', (t) async {
      final server = _Server();
      await _open(t, server, role: 'artist', employeeId: 'e1');
      expect(find.byTooltip('Approve'), findsNothing);
      expect(find.byTooltip('Edit this collection'), findsWidgets);
      expect(find.byKey(const Key('mode_upi')), findsOneWidget);
      expect(find.byKey(const Key('artist_e1')), findsNothing, reason: 'nobody else to compare with');
      expect(find.text('BY ARTIST'), findsNothing);

      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
      // the server scopes an artist to their own entries — the app does not need to ask for it
      expect(server.collQueries.every((q) => q.employeeId == null), isTrue);
    });
  });

  group('empty and failing', () {
    testWidgets('a month with nothing says so, and a search with nothing offers to clear', (t) async {
      final server = _Server()
        ..collTotal = 0
        ..expTotal = 0;
      await _open(t, server);
      expect(find.text('No collections in ${DateFormat('MMMM yyyy').format(now)}'), findsOneWidget);
      expect(find.text('No collections'), findsOneWidget, reason: 'the "Showing" line');

      await t.enterText(find.byKey(const Key('searchField')), 'zzz');
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      expect(find.text('No matching collections'), findsOneWidget);
      await t.tap(find.text('Clear filters'));
      await t.pumpAndSettle();
      expect(server.collQueries.last.search, '');
      expect(find.text('No collections in ${DateFormat('MMMM yyyy').format(now)}'), findsOneWidget);

      await t.tap(find.byKey(const Key('periodAll')));
      await t.pumpAndSettle();
      expect(find.text('No collections logged yet'), findsOneWidget);
      await _openExpenses(t);
      expect(find.text('No expenses logged yet'), findsOneWidget);
    });

    testWidgets('a first load that fails offers "Try again", and the retry works', (t) async {
      final server = _Server();
      var fail = true;
      server.collGate = (q) async {
        if (fail) throw Exception('server down');
      };
      await _open(t, server);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Client 0'), findsNothing);

      fail = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('Client 0'), findsOneWidget);
    });

    testWidgets('a page that fails keeps the old one on screen, says so, and can be retried', (t) async {
      final server = _Server();
      var fail = false;
      server.collGate = (q) async {
        if (fail && q.page == 2) throw Exception('timeout');
      };
      await _open(t, server);
      fail = true;
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.text('Client 0'), findsOneWidget, reason: 'the last good page is not thrown away');
      expect(find.text('Try again'), findsOneWidget, reason: 'but the failure is not hidden');

      fail = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('Client 20'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('phone', () {
    testWidgets('both tabs lay out at 360px with no overflow; search, filters, sort and page size stack up', (t) async {
      final server = _Server();
      await _open(t, server, w: 360);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('filtersButton')), findsOneWidget);
      expect(find.byKey(const Key('searchField')), findsOneWidget);
      expect(find.byKey(const Key('sortMenu')), findsOneWidget);
      expect(find.byKey(const Key('pageSizeMenu')), findsOneWidget);

      // swipe to Expenses (the tab label can sit under the PDF button at this width)
      await t.drag(find.byType(TabBarView), const Offset(-300, 0));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Bridal Work'), findsOneWidget);
      expect(server.expQueries, isNotEmpty);
    });
  });
}
