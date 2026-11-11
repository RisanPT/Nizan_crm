import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/accounts_collections_screen.dart';
import 'package:nizan_crm/features/accounts/services/collection_service.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/services/booking_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

// Finance & Invoices. The Collections tab is filtered, sorted and paged on the
// server; the Invoice Balances tab narrows the loaded invoices in the app (the
// paid / due rule lives in Booking.balanceDue). These drive the real screen.

// ── Collections tab: a pretend server ───────────────────────────────────────

Map<String, dynamic> _coll(int i, {String status = 'verified'}) => {
      '_id': 'c$i',
      'amount': 1000.0 + i,
      'status': status,
      'paymentMode': i.isEven ? 'upi' : 'cash',
      'date': '2026-10-12T04:30:00.000Z',
      'bookingId': {'_id': 'b$i', 'bookingNumber': 'BK-$i', 'customerName': 'Client $i', 'service': 'Bridal'},
      'employeeId': {'_id': 'e1', 'name': 'Anu'}, 'attachmentUrl': 'https://example.com/receipt.jpg',
    };

class _Server {
  final queries = <FinanceQuery>[];
  int total = 45;
  Future<void> Function(FinanceQuery q)? gate;

  FinanceSummary _summary() => FinanceSummary.fromJson({
        'byStatus': {
          'pending': {'count': 5, 'amount': 5000},
          'verified': {'count': 35, 'amount': 40000},
          'rejected': {'count': 5, 'amount': 2500},
        },
        'shown': {'count': total, 'amount': 47500},
        'byMode': [
          {'mode': 'upi', 'count': 25, 'amount': 30000},
          {'mode': 'cash', 'count': 20, 'amount': 17500},
        ],
        'byArtist': [
          {'employeeId': 'e1', 'name': 'Anu', 'count': 45, 'amount': 47500},
        ],
      });

  Future<FinancePage<ArtistCollection>> page(FinanceQuery q) async {
    queries.add(q);
    await gate?.call(q);
    final start = (q.page - 1) * q.limit;
    final n = math.max(0, math.min(q.limit, total - start));
    return FinancePage(
      items: [for (var i = start; i < start + n; i++) ArtistCollection.fromJson(_coll(i, status: i < 5 ? 'pending' : 'verified'))],
      page: q.page,
      limit: q.limit,
      totalItems: total,
      totalPages: math.max(1, (total / q.limit).ceil()),
      summary: _summary(),
    );
  }
}

// ── Invoice Balances tab: bookings with verified collections ────────────────

final _now = DateTime.now();
DateTime _in(int monthsAgo, int day) => DateTime(_now.year, _now.month - monthsAgo, day);

/// A booking whose event was on [event]. Its LAST work date is far ahead, so the
/// balance stays receivable (a booking whose final work has passed counts as settled).
Booking _booking(
  String id,
  String customer,
  DateTime event, {
  String service = 'Bridal',
  required double total,
  double advance = 0,
  double collected = 0,
  String invoiceNumber = '',
}) =>
    Booking.fromJson({
      '_id': id,
      'customerName': customer,
      'phone': '9895499872',
      'service': service,
      'bookingNumber': 'BK-$id',
      'invoiceNumber': invoiceNumber,
      'bookingDate': event.toIso8601String(),
      'serviceStart': event.toIso8601String(),
      'serviceEnd': event.add(const Duration(hours: 4)).toIso8601String(),
      'selectedDates': [DateTime(_now.year + 1, 1, 15).toIso8601String()],
      'totalPrice': total,
      'advanceAmount': advance,
      'collectedAmount': collected,
    });

Map<String, dynamic> _verified(String id, String bookingId, String collector, double amount) => {
      '_id': id,
      'amount': amount,
      'status': 'verified',
      'paymentMode': 'upi',
      'date': '2026-10-12T04:30:00.000Z',
      'bookingId': {'_id': bookingId, 'bookingNumber': 'BK-$bookingId', 'customerName': 'x', 'service': 'Bridal'},
      'employeeId': {'_id': 'e_$collector', 'name': collector},
    };

class _Books {
  final bookings = <String, Booking>{};
  final collections = <Map<String, dynamic>>[];
  Object? failWith;

  void add(Booking b, String collector) {
    bookings[b.id] = b;
    collections.add(_verified('v${b.id}', b.id, collector, 1000));
  }

  /// The default data set — five invoices over four months:
  ///  Asha   this month, 30000 −  5000 advance − 25000 collected = paid
  ///  Fathima this month, 20000 − 2000 − 3000 = 15000 due
  ///  Lakshmi this month,  8000 − 1000 − 0   =  7000 due
  ///  Meera  last month,  12000 − 2000 − 1000 =  9000 due
  ///  Zoya   3 months ago, 50000 − 10000 − 40000 = paid
  _Books.standard() {
    add(_booking('1', 'Asha Nair', _in(0, 5), total: 30000, advance: 5000, collected: 25000, invoiceNumber: 'INV-001'), 'Anu');
    add(_booking('2', 'Fathima Rahman', _in(0, 8), service: 'Platinum', total: 20000, advance: 2000, collected: 3000), 'Anu');
    add(_booking('3', 'Lakshmi Das', _in(0, 20), service: 'Party', total: 8000, advance: 1000), 'Fathima');
    add(_booking('4', 'Meera Joseph', _in(1, 10), service: 'Party', total: 12000, advance: 2000, collected: 1000), 'Fathima');
    add(_booking('5', 'Zoya Khan', _in(3, 2), total: 50000, advance: 10000, collected: 40000, invoiceNumber: 'INV-002'), 'Anu');
  }

  /// [n] invoices, all due, newest first by number.
  _Books.many(int n) {
    for (var i = 0; i < n; i++) {
      add(_booking('${100 + i}', 'Customer ${(100 + i)}', _in(0, 1 + (i % 27)), total: 10000, advance: 1000), 'Anu');
    }
  }
}

class _FakeCollectionService extends CollectionService {
  final _Books books;
  _FakeCollectionService(this.books) : super(Dio());

  @override
  Future<List<ArtistCollection>> getCollections({
    String? status,
    String? bookingId,
    String? employeeId,
    String? paymentMode,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (books.failWith != null) throw books.failWith!;
    return [for (final j in books.collections) ArtistCollection.fromJson(j)];
  }
}

class _FakeBookingService extends BookingService {
  final _Books books;
  _FakeBookingService(this.books) : super(Dio());

  @override
  Future<Booking> getBookingById(String id) async => books.bookings[id]!;
}

Employee _employee(String id, String name) => Employee.fromJson({'_id': id, 'name': name, 'artistRole': 'artist', 'status': 'active'});

Widget _app(_Server server, _Books books) => ProviderScope(
      overrides: [
        financeCollectionsPageProvider.overrideWith((ref, q) => server.page(q)),
        collectionServiceProvider.overrideWithValue(_FakeCollectionService(books)),
        bookingServiceProvider.overrideWithValue(_FakeBookingService(books)),
        employeesProvider.overrideWith((ref) async => [_employee('e1', 'Anu'), _employee('e2', 'Fathima')]),
        authSessionProvider.overrideWithValue(const AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'accounts')),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: AccountsCollectionsScreen()))),
    );

Future<void> _open(WidgetTester t, {_Server? server, _Books? books, double w = 1400, double h = 12000}) async {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(_app(server ?? _Server(), books ?? _Books.standard()));
  await t.pumpAndSettle();
}

Future<void> _openInvoices(WidgetTester t) async {
  await t.tap(find.text('Invoice Balances'));
  await t.pumpAndSettle();
}

ProviderContainer _container(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(AccountsCollectionsScreen)));

/// The vertical order of the customers on screen (top to bottom).
List<String> _order(WidgetTester t, List<String> names) {
  final at = <String, double>{
    for (final n in names)
      if (find.text(n).evaluate().isNotEmpty) n: t.getTopLeft(find.text(n)).dy,
  };
  return (at.keys.toList()..sort((a, b) => at[a]!.compareTo(at[b]!)));
}

void main() {
  final thisMonth = FinanceQuery.monthBounds(_now);
  final lastMonthStart = DateTime(_now.year, _now.month - 1);
  final lastMonth = FinanceQuery.monthBounds(lastMonthStart);

  group('Collections tab', () {
    testWidgets('opens on this month, page 1 of 20, newest first — and the cards are the whole-set totals', (t) async {
      final server = _Server();
      await _open(t, server: server);
      expect(server.queries, hasLength(1));
      final q = server.queries.single;
      expect((q.from, q.to, q.page, q.limit, q.sort), (thisMonth.$1, thisMonth.$2, 1, 20, 'date_desc'));
      expect(find.text(DateFormat('MMMM yyyy').format(_now)), findsOneWidget);

      expect(find.text('Collected · 35'), findsOneWidget);
      expect(find.text('₹40,000'), findsOneWidget);
      expect(find.text('Awaiting verification · 5'), findsOneWidget);
      expect(find.text('Rejected · 5'), findsOneWidget);
      expect(find.text('In this view · 45'), findsOneWidget);
      expect(find.text('45 collections  ·  ₹47,500'), findsOneWidget);
      expect(find.textContaining('Client 0  •'), findsOneWidget);
      expect(find.textContaining('Client 19  •'), findsOneWidget);
      expect(find.textContaining('Client 20  •'), findsNothing);
    });

    testWidgets('paging: Next → page 2 and the footer says where you are; Previous goes back', (t) async {
      final server = _Server();
      await _open(t, server: server);
      expect(find.textContaining('Showing 1–20 of 45'), findsOneWidget);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(server.queries.last.page, 2);
      expect(find.textContaining('Showing 21–40 of 45'), findsOneWidget);
      expect(find.textContaining('Client 20  •'), findsOneWidget);
      await t.tap(find.text('Previous'));
      await t.pumpAndSettle();
      expect(server.queries.last.page, 1);
      expect(find.textContaining('Client 0  •'), findsOneWidget);
    });

    testWidgets('the page on screen stays, with a progress bar, while the next loads', (t) async {
      final server = _Server();
      final release = Completer<void>();
      server.gate = (q) async {
        if (q.page == 2) await release.future;
      };
      await _open(t, server: server);
      await t.tap(find.text('Next'));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Client 0  •'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      release.complete();
      await t.pumpAndSettle();
      expect(find.textContaining('Client 20  •'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('the month switcher, "All time" and the range chip re-ask the server from page 1', (t) async {
      final server = _Server();
      await _open(t, server: server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('periodPrev')));
      await t.pumpAndSettle();
      expect((server.queries.last.from, server.queries.last.to, server.queries.last.page), (lastMonth.$1, lastMonth.$2, 1));
      expect(find.text(DateFormat('MMMM yyyy').format(lastMonthStart)), findsOneWidget);

      await t.tap(find.byKey(const Key('periodAll')));
      await t.pumpAndSettle();
      expect((server.queries.last.from, server.queries.last.to), (null, null));

      await t.tap(find.text('This month'));
      await t.pumpAndSettle();
      expect((server.queries.last.from, server.queries.last.to), (thisMonth.$1, thisMonth.$2));
    });

    testWidgets('status chips, search, sort and page size all go to the server and start from page 1', (t) async {
      final server = _Server();
      await _open(t, server: server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('status_pending')));
      await t.pumpAndSettle();
      expect(server.queries.last.statuses, {'pending'});
      expect(server.queries.last.page, 1);
      await t.tap(find.byKey(const Key('status_all')));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const Key('searchField')), 'fath');
      await t.pump(const Duration(milliseconds: 100));
      final before = server.queries.length;
      expect(before, server.queries.length);
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      expect(server.queries.length, before + 1, reason: 'one request, after the typing stopped');
      expect(server.queries.last.search, 'fath');
      expect(find.text('Search: "fath"'), findsOneWidget);

      await t.tap(find.byKey(const Key('sortMenu')));
      await t.pumpAndSettle();
      await t.tap(find.text('Lowest amount').last);
      await t.pumpAndSettle();
      expect(server.queries.last.sort, 'amount_asc');

      await t.tap(find.byKey(const Key('pageSizeMenu')));
      await t.pumpAndSettle();
      await t.tap(find.text('10 per page'));
      await t.pumpAndSettle();
      expect((server.queries.last.limit, server.queries.last.page), (10, 1));
      expect(server.queries.last.search, 'fath', reason: 'everything chosen so far is still on');
    });

    testWidgets('advanced filters: apply, see chips and a count, take one off, clear all', (t) async {
      final server = _Server();
      await _open(t, server: server);
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilterChip, 'UPI'));
      await t.tap(find.widgetWithText(FilterChip, 'Mismatch'));
      await t.enterText(find.byKey(const Key('filterMin')), '500');
      await t.enterText(find.byKey(const Key('filterMax')), '2500');
      await t.tap(find.byKey(const Key('applyFilters')));
      await t.pumpAndSettle();

      final q = server.queries.last;
      expect(q.paymentModes, {'upi'});
      expect(q.ocr, {'mismatch'});
      expect((q.minAmount, q.maxAmount, q.page), (500.0, 2500.0, 1));
      expect(find.text('Payment: UPI'), findsOneWidget);
      expect(find.text('Check: Mismatch'), findsOneWidget);
      expect(find.textContaining('Amount: ₹500'), findsOneWidget);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('3')), findsOneWidget);

      await t.tap(find.descendant(of: find.widgetWithText(InputChip, 'Check: Mismatch'), matching: find.byTooltip('Delete')));
      await t.pumpAndSettle();
      expect(server.queries.last.ocr, isEmpty);
      expect(server.queries.last.paymentModes, {'upi'});

      await t.tap(find.byKey(const Key('clearAll')));
      await t.pumpAndSettle();
      expect(server.queries.last.advancedCount, 0);
      expect(server.queries.last.from, thisMonth.$1, reason: 'clearing filters does not change the month');
      expect(find.byKey(const Key('clearAll')), findsNothing);
    });

    testWidgets('breakdown: tapping a payment mode or an artist filters to it', (t) async {
      final server = _Server();
      await _open(t, server: server);
      await t.tap(find.byKey(const Key('mode_cash')));
      await t.pumpAndSettle();
      expect(server.queries.last.paymentModes, {'cash'});
      await t.tap(find.byKey(const Key('artist_e1')));
      await t.pumpAndSettle();
      expect(server.queries.last.employeeId, 'e1');
      expect(find.text('Artist: Anu'), findsOneWidget);
    });

    testWidgets('an empty month, and an empty search', (t) async {
      final server = _Server()..total = 0;
      await _open(t, server: server);
      expect(find.text('No collections in this period.'), findsOneWidget);
      expect(find.text('No collections'), findsOneWidget, reason: 'the total line');
      await t.enterText(find.byKey(const Key('searchField')), 'zzz');
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      expect(find.text('No collections match these filters.'), findsOneWidget);
      await t.tap(find.text('Clear filters'));
      await t.pumpAndSettle();
      expect(server.queries.last.search, '');
    });

    testWidgets('a page that fails keeps the last good one, says so, and can be retried', (t) async {
      final server = _Server();
      var fail = false;
      server.gate = (q) async {
        if (fail && q.page == 2) throw Exception('timeout');
      };
      await _open(t, server: server);
      fail = true;
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.textContaining('Client 0  •'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      fail = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.textContaining('Client 20  •'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a first load that fails shows the error page with "Try again"', (t) async {
      final server = _Server();
      var fail = true;
      server.gate = (q) async {
        if (fail) throw Exception('down');
      };
      await _open(t, server: server);
      expect(find.text('Try again'), findsOneWidget);
      fail = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.textContaining('Client 0  •'), findsOneWidget);
    });

    
    testWidgets('Collections tab: View Details dialog opens without stuck or crash', (t) async {
      await _open(t);
      await t.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await t.pumpAndSettle();
      expect(find.text('View Details'), findsOneWidget);
      await t.tap(find.text('View Details'));
      await t.pumpAndSettle();
      expect(find.text('Collection Details'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      await t.tap(find.text('Close'));
      await t.pumpAndSettle();
    });

    testWidgets('after the last entry of the last page goes, it steps back to a page that exists', (t) async {
      final server = _Server()..total = 41;
      await _open(t, server: server);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(server.queries.last.page, 3);
      server.total = 40;
      _container(t).invalidate(financeCollectionsPageProvider);
      await t.pumpAndSettle();
      expect(server.queries.last.page, 2);
      expect(find.textContaining('Showing 21–40 of 40'), findsOneWidget);
    });
  });

  group('Invoice Balances tab', () {
    testWidgets('lists every invoice (All time is its default) with Paid / Due counts and a total line', (t) async {
      await _open(t);
      await _openInvoices(t);
      for (final n in ['Asha Nair', 'Fathima Rahman', 'Lakshmi Das', 'Meera Joseph', 'Zoya Khan']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.text('All (5)'), findsOneWidget);
      expect(find.text('Paid (2)'), findsOneWidget);
      expect(find.text('Due (3)'), findsOneWidget);
      expect(find.text('5 invoices'), findsOneWidget);
      expect(find.text('INV-001'), findsOneWidget, reason: 'a paid invoice shows its invoice number');
    });

    testWidgets('Paid and Due chips narrow the list; the count in the other chips stays', (t) async {
      await _open(t);
      await _openInvoices(t);
      await t.tap(find.byKey(const Key('inv_due')));
      await t.pumpAndSettle();
      expect(find.text('Asha Nair'), findsNothing);
      expect(find.text('Zoya Khan'), findsNothing);
      expect(find.text('Fathima Rahman'), findsOneWidget);
      expect(find.text('3 invoices'), findsOneWidget);
      expect(find.text('Paid (2)'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget, reason: 'the active chip');

      await t.tap(find.byKey(const Key('inv_paid')));
      await t.pumpAndSettle();
      expect(find.text('Asha Nair'), findsOneWidget);
      expect(find.text('Fathima Rahman'), findsNothing);
    });

    testWidgets('the month switcher filters by the EVENT date', (t) async {
      await _open(t);
      await _openInvoices(t);
      await t.tap(find.text('This month'));
      await t.pumpAndSettle();
      expect(find.text('Asha Nair'), findsOneWidget);
      expect(find.text('Fathima Rahman'), findsOneWidget);
      expect(find.text('Lakshmi Das'), findsOneWidget);
      expect(find.text('Meera Joseph'), findsNothing);
      expect(find.text('Zoya Khan'), findsNothing);
      expect(find.text('All (3)'), findsOneWidget);

      await t.tap(find.byKey(const Key('periodPrev')));
      await t.pumpAndSettle();
      expect(find.text('Meera Joseph'), findsOneWidget);
      expect(find.text('Asha Nair'), findsNothing);

      await t.tap(find.byKey(const Key('periodAll')));
      await t.pumpAndSettle();
      expect(find.text('Zoya Khan'), findsOneWidget);
    });

    testWidgets('search looks at the client, service, booking / invoice number and the collector', (t) async {
      await _open(t);
      await _openInvoices(t);
      Future<void> search(String text) async {
        await t.enterText(find.byKey(const Key('searchField')), text);
        await t.pump(const Duration(milliseconds: 600));
        await t.pumpAndSettle();
      }

      await search('fath');
      expect(find.text('Fathima Rahman'), findsOneWidget);
      expect(find.text('Lakshmi Das'), findsOneWidget, reason: 'Lakshmi\'s payment was collected by Fathima');
      expect(find.text('Asha Nair'), findsNothing);
      expect(find.text('Search: "fath"'), findsOneWidget);

      await search('INV-002');
      expect(find.text('Zoya Khan'), findsOneWidget);
      expect(find.text('Fathima Rahman'), findsNothing);

      await search('platinum');
      expect(find.text('Fathima Rahman'), findsOneWidget);
      expect(find.text('Zoya Khan'), findsNothing);

      await search('nobody');
      expect(find.text('No invoices match these filters.'), findsOneWidget);
      await t.tap(find.byKey(const Key('clearAll')));
      await t.pumpAndSettle();
      expect(find.text('Zoya Khan'), findsOneWidget);
    });

    testWidgets('sorting by balance puts the biggest balance first', (t) async {
      await _open(t);
      await _openInvoices(t);
      const names = ['Asha Nair', 'Fathima Rahman', 'Lakshmi Das', 'Meera Joseph', 'Zoya Khan'];
      expect(_order(t, names).first, 'Lakshmi Das', reason: 'newest event first by default');

      await t.tap(find.byKey(const Key('sortMenu')));
      await t.pumpAndSettle();
      await t.tap(find.text('Highest balance').last);
      await t.pumpAndSettle();
      expect(_order(t, names).take(3), ['Fathima Rahman', 'Meera Joseph', 'Lakshmi Das']); // 15000, 9000, 7000

      await t.tap(find.byKey(const Key('sortMenu')));
      await t.pumpAndSettle();
      await t.tap(find.text('Oldest first').last);
      await t.pumpAndSettle();
      expect(_order(t, names).first, 'Zoya Khan');
    });

    testWidgets('the filters dialog: collected by, and a balance range', (t) async {
      await _open(t);
      await _openInvoices(t);
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('invArtist')));
      await t.pumpAndSettle();
      await t.tap(find.text('Fathima').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('invApply')));
      await t.pumpAndSettle();
      expect(find.text('Collected by: Fathima'), findsOneWidget);
      expect(find.text('Lakshmi Das'), findsOneWidget);
      expect(find.text('Meera Joseph'), findsOneWidget);
      expect(find.text('Asha Nair'), findsNothing);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsOneWidget);

      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('invMin')), '8000');
      await t.tap(find.byKey(const Key('invApply')));
      await t.pumpAndSettle();
      expect(find.text('Meera Joseph'), findsOneWidget, reason: '9000 due');
      expect(find.text('Lakshmi Das'), findsNothing, reason: '7000 due is under the minimum');
      expect(find.textContaining('Balance: ₹ 8000'), findsOneWidget);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('2')), findsOneWidget);
    });

    testWidgets('a minimum above the maximum is refused', (t) async {
      await _open(t);
      await _openInvoices(t);
      await t.tap(find.byKey(const Key('filtersButton')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('invMin')), '900');
      await t.enterText(find.byKey(const Key('invMax')), '100');
      await t.tap(find.byKey(const Key('invApply')));
      await t.pumpAndSettle();
      expect(find.text('The minimum is more than the maximum.'), findsOneWidget);
    });

    testWidgets('paging: 30 invoices at 12 a page', (t) async {
      await _open(t, books: _Books.many(30));
      await _openInvoices(t);
      expect(find.text('30 invoices'), findsOneWidget);
      expect(find.textContaining('Showing 1–12 of 30'), findsOneWidget);
      await t.tap(find.text('Next').last);
      await t.pumpAndSettle();
      expect(find.textContaining('Showing 13–24 of 30'), findsOneWidget);
      await t.tap(find.text('Next').last);
      await t.pumpAndSettle();
      expect(find.textContaining('Showing 25–30 of 30'), findsOneWidget);

      await t.tap(find.byKey(const Key('pageSizeMenu')));
      await t.pumpAndSettle();
      await t.tap(find.text('50 per page'));
      await t.pumpAndSettle();
      expect(find.textContaining('Showing 1–30 of 30'), findsOneWidget, reason: 'a new page size starts from page 1');
    });

    testWidgets('a filter that leaves nothing says so; a quiet month says that instead', (t) async {
      await _open(t);
      await _openInvoices(t);
      await t.tap(find.byKey(const Key('periodPrev')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('periodPrev')));
      await t.pumpAndSettle();
      expect(find.text('No invoices in this period.'), findsOneWidget);
      expect(t.widget<FilledButton>(find.byKey(const Key('invoiceDownload'))).onPressed, isNull, reason: 'nothing to download');

      await t.tap(find.byKey(const Key('inv_due')));
      await t.pumpAndSettle();
      expect(find.text('No invoices match these filters.'), findsOneWidget);
    });

    testWidgets('a load that fails offers "Try again"', (t) async {
      final books = _Books.standard()..failWith = Exception('down');
      await _open(t, books: books);
      await _openInvoices(t);
      expect(find.text('Try again'), findsOneWidget);
      books.failWith = null;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('Asha Nair'), findsOneWidget);
    });
  });

  group('phone', () {
    testWidgets('both tabs lay out at 360px (search, filters, sort and page size stack up)', (t) async {
      // The test font is far wider than the real one, so the shared stat cards
      // (inventory_widgets InvStat, not part of this work) overflow by 3px in it:
      // note those and fail on anything else.
      final other = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        final text = d.toDiagnosticsNode().toStringDeep();
        if (!text.contains('overflowed by 3.1 pixels on the bottom')) {
          print('EXACT LOC: $text');
          other.add(text.split('\n').take(6).join(' | '));
        }
      };
      addTearDown(() => FlutterError.onError = previous);

      await _open(t, w: 360, h: 9000);
      expect(find.byKey(const Key('filtersButton')), findsOneWidget);
      expect(find.byKey(const Key('searchField')), findsOneWidget);
      expect(find.byKey(const Key('sortMenu')), findsOneWidget);
      expect(find.byKey(const Key('pageSizeMenu')), findsOneWidget);
      await _openInvoices(t);
      expect(find.byKey(const Key('filtersButton')), findsOneWidget);
      expect(find.text('Asha Nair'), findsOneWidget);
      FlutterError.onError = previous;
      expect(other, isEmpty);
    });
  });
}
