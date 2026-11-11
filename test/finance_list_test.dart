import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/services/collection_service.dart';
import 'package:nizan_crm/features/accounts/services/expense_service.dart';

// The request and the response of the two Accounts lists that are filtered, sorted
// and paged on the server: artist collections and artist expenses.

class _Capture implements HttpClientAdapter {
  RequestOptions? last;
  final Object body;
  final int status;
  _Capture(this.body, {this.status = 200});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Capture c) => Dio()..httpClientAdapter = c;

Map<String, dynamic> _collection(String id, {double amount = 1000, String status = 'verified'}) => {
      '_id': id,
      'amount': amount,
      'status': status,
      'paymentMode': 'upi',
      'date': '2026-10-12T04:30:00.000Z',
      'bookingId': {'_id': 'b1', 'bookingNumber': 'BK-1', 'customerName': 'Fathima', 'service': 'Bridal'},
      'employeeId': {'_id': 'e1', 'name': 'Anu'},
    };

Map<String, dynamic> _expense(String id, {double amount = 400}) => {
      '_id': id,
      'amount': amount,
      'status': 'pending',
      'category': 'food',
      'workType': 'bridal',
      'date': '2026-10-12T04:30:00.000Z',
      'employeeId': {'_id': 'e1', 'name': 'Anu'},
    };

const _summaryJson = {
  'byStatus': {
    'pending': {'count': 3, 'amount': 3000},
    'verified': {'count': 10, 'amount': 25500.5},
  },
  'shown': {'count': 13, 'amount': 28500.5},
  'byMode': [
    {'mode': 'upi', 'count': 8, 'amount': 20000},
    {'mode': 'cash', 'count': 5, 'amount': 8500.5},
  ],
  'byCategory': [
    {'category': 'food', 'count': 2, 'amount': 800},
  ],
  'byWorkType': [
    {'workType': 'bridal', 'count': 1, 'amount': 500},
    {'workType': 'model_shoot', 'count': 1, 'amount': 300},
  ],
  'byArtist': [
    {'employeeId': 'e1', 'name': 'Anu', 'count': 9, 'amount': 19000},
    {'employeeId': 'e2', 'count': 4, 'amount': 9500.5},
  ],
};

void main() {
  group('FinanceQuery', () {
    test('defaults: newest first, page 1 of 20, nothing filtered', () {
      const q = FinanceQuery();
      expect((q.sort, q.page, q.limit, q.advancedCount, q.isFiltered), ('date_desc', 1, 20, 0, false));
      expect(q.toParams(), {'sort': 'date_desc', 'page': '1', 'limit': '20', 'summary': '1'});
    });

    test('every filter becomes the parameter the server reads', () {
      final q = const FinanceQuery().copyWith(
        from: '2026-10-01',
        to: '2026-10-31',
        statuses: {'verified', 'pending'},
        employeeId: 'e1',
        paymentModes: {'upi', 'cash'},
        categories: {'travel', 'food'},
        workType: 'model_shoot',
        bill: 'with',
        link: 'trial',
        ocr: {'mismatch', 'match'},
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
        'status': 'pending,verified',
        'employeeId': 'e1',
        'paymentMode': 'cash,upi',
        'category': 'food,travel',
        'workType': 'model_shoot',
        'bill': 'with',
        'link': 'trial',
        'ocr': 'match,mismatch',
        'minAmount': '500.0',
        'maxAmount': '2500.5',
        'search': 'fathima',
        'sort': 'amount_desc',
        'page': '3',
        'limit': '50',
        'summary': '1',
      });
    });

    test('a blank search is not sent', () {
      expect(const FinanceQuery(search: '   ').toParams().containsKey('search'), isFalse);
    });

    test('export asks for every match: no page, limit or summary', () {
      final p = const FinanceQuery().copyWith(page: 4, search: 'x').toParams(export: true);
      expect(p['export'], '1');
      expect(p.containsKey('page'), isFalse);
      expect(p.containsKey('limit'), isFalse);
      expect(p.containsKey('summary'), isFalse);
      expect(p['search'], 'x');
    });

    test('changing a filter goes back to page 1; changing only the page does not', () {
      final onPage3 = const FinanceQuery().copyWith(page: 3);
      expect(onPage3.refiltered(search: 'x').page, 1);
      expect(onPage3.refiltered(statuses: {'pending'}).page, 1);
      expect(onPage3.refiltered(limit: 50).page, 1);
      expect(onPage3.refiltered(sort: 'amount_asc').page, 1);
      expect(onPage3.copyWith(search: 'x').page, 3);
      expect(onPage3.copyWith(page: 4).page, 4);
    });

    test('copyWith takes whole-number amounts (an int literal) and null clears a value', () {
      // an `as double?` cast used to throw on `500`
      final q = const FinanceQuery().copyWith(minAmount: 500, maxAmount: 900);
      expect((q.minAmount, q.maxAmount), (500.0, 900.0));
      final cleared = q.copyWith(minAmount: null, employeeId: null);
      expect(cleared.minAmount, isNull);
      expect(cleared.maxAmount, 900.0);
      final withArtist = const FinanceQuery().copyWith(employeeId: 'e1');
      expect(withArtist.copyWith(sort: 'amount_asc').employeeId, 'e1');
      expect(withArtist.copyWith(employeeId: null).employeeId, isNull);
      expect(withArtist.refiltered(employeeId: null).employeeId, isNull);
    });

    test('advancedCount counts each filter group once, and not the period, status, search or sort', () {
      expect(const FinanceQuery(from: '2026-10-01', to: '2026-10-31', statuses: {'pending'}, search: 'x', sort: 'amount_asc').advancedCount, 0);
      expect(const FinanceQuery(employeeId: 'e1').advancedCount, 1);
      expect(const FinanceQuery(paymentModes: {'upi', 'cash'}).advancedCount, 1);
      expect(const FinanceQuery(categories: {'food'}).advancedCount, 1);
      expect(const FinanceQuery(workType: 'bridal').advancedCount, 1);
      expect(const FinanceQuery(bill: 'with').advancedCount, 1);
      expect(const FinanceQuery(link: 'none').advancedCount, 1);
      expect(const FinanceQuery(ocr: {'match'}).advancedCount, 1);
      expect(const FinanceQuery(minAmount: 1).advancedCount, 1);
      expect(const FinanceQuery(maxAmount: 9).advancedCount, 1);
      expect(const FinanceQuery(minAmount: 1, maxAmount: 9).advancedCount, 1);
      expect(const FinanceQuery(employeeId: 'e1', bill: 'with', minAmount: 1, categories: {'food'}).advancedCount, 4);
    });

    test('isFiltered is true for anything besides the period', () {
      expect(const FinanceQuery(from: '2026-10-01', to: '2026-10-31').isFiltered, isFalse);
      expect(const FinanceQuery(search: ' ').isFiltered, isFalse);
      expect(const FinanceQuery(search: 'a').isFiltered, isTrue);
      expect(const FinanceQuery(statuses: {'pending'}).isFiltered, isTrue);
      expect(const FinanceQuery(employeeId: 'e1').isFiltered, isTrue);
    });

    test('equal queries are the same request, whatever order their sets were built in', () {
      final a = const FinanceQuery().copyWith(statuses: {'pending', 'verified'}, paymentModes: {'upi', 'cash'});
      final b = const FinanceQuery().copyWith(statuses: {'verified', 'pending'}, paymentModes: {'cash', 'upi'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(page: 2)));
      expect(a, isNot(a.copyWith(limit: 50)));
      expect(a, isNot(a.copyWith(search: 'x')));
      expect(a, isNot(a.copyWith(minAmount: 5)));
      expect({a, b}.length, 1);
    });

    test('monthBounds is the whole calendar month, leap years and December included', () {
      expect(FinanceQuery.monthBounds(DateTime(2026, 10, 17)), ('2026-10-01', '2026-10-31'));
      expect(FinanceQuery.monthBounds(DateTime(2028, 2, 3)), ('2028-02-01', '2028-02-29'));
      expect(FinanceQuery.monthBounds(DateTime(2027, 2, 28)), ('2027-02-01', '2027-02-28'));
      expect(FinanceQuery.monthBounds(DateTime(2026, 12, 31)), ('2026-12-01', '2026-12-31'));
      expect(FinanceQuery.monthBounds(DateTime(2027, 1, 1)), ('2027-01-01', '2027-01-31'));
    });
  });

  group('FinancePage / FinanceSummary', () {
    test('parses the items, the page numbers and the whole-set totals', () {
      final page = FinancePage.fromJson({
        'items': [_collection('c1'), _collection('c2', amount: 250)],
        'page': 2,
        'limit': 20,
        'totalItems': 42,
        'totalPages': 3,
        'summary': _summaryJson,
      }, ArtistCollection.fromJson);
      expect(page.items.map((c) => c.id), ['c1', 'c2']);
      expect(page.items.first.booking?.customerName, 'Fathima');
      expect((page.page, page.limit, page.totalItems, page.totalPages), (2, 20, 42, 3));

      final s = page.summary!;
      expect((s.shownCount, s.shownAmount), (13, 28500.5));
      expect(s.status('pending').count, 3);
      expect(s.status('verified').amount, 25500.5);
      expect(s.status('rejected').count, 0, reason: 'a status the server did not send is zero, not an error');
      expect(s.allCount, 13);
      expect(s.allAmount, 28500.5);
      expect(s.byMode.map((r) => (r.key, r.count, r.amount)), [('upi', 8, 20000.0), ('cash', 5, 8500.5)]);
      expect(s.byCategory.single.key, 'food');
      expect(s.byWorkType.map((r) => r.key), ['bridal', 'model_shoot']);
      expect(s.byArtist.first.name, 'Anu');
      expect(s.byArtist.last.name, 'Artist', reason: 'an artist with no name still reads as a person');
      expect(s.byArtist.last.key, 'e2');
    });

    test('a bare response still parses (no summary, nothing missing crashes)', () {
      final page = FinancePage.fromJson({}, ArtistExpense.fromJson);
      expect(page.items, isEmpty);
      expect((page.page, page.limit, page.totalItems, page.totalPages), (1, 20, 0, 1));
      expect(page.summary, isNull);
    });

    test('an empty summary is all zeros', () {
      final s = FinanceSummary.fromJson({});
      expect((s.shownCount, s.shownAmount, s.allCount, s.allAmount), (0, 0.0, 0, 0.0));
      expect([s.byMode, s.byCategory, s.byWorkType, s.byArtist].every((l) => l.isEmpty), isTrue);
    });

    test('an export says whether the server cut it short', () {
      final full = FinanceExport.fromJson({'items': [_expense('x1')], 'totalItems': 1, 'truncated': false}, ArtistExpense.fromJson);
      expect((full.items.length, full.totalItems, full.truncated), (1, 1, false));
      final cut = FinanceExport.fromJson({'items': [_expense('x1')], 'totalItems': 9000, 'truncated': true}, ArtistExpense.fromJson);
      expect((cut.totalItems, cut.truncated), (9000, true));
      expect(FinanceExport.fromJson({}, ArtistExpense.fromJson).truncated, isFalse);
    });
  });

  group('services', () {
    test('collections page: GET /collections with the query, parsed into a page', () async {
      final cap = _Capture({'items': [_collection('c1')], 'page': 2, 'limit': 10, 'totalItems': 11, 'totalPages': 2, 'summary': _summaryJson});
      final page = await CollectionService(_dio(cap)).getCollectionPage(
        const FinanceQuery(from: '2026-10-01', to: '2026-10-31', page: 2, limit: 10, paymentModes: {'upi'}, search: 'anu'),
      );
      expect(cap.last!.path, '/collections');
      expect(cap.last!.queryParameters, {
        'from': '2026-10-01',
        'to': '2026-10-31',
        'paymentMode': 'upi',
        'search': 'anu',
        'sort': 'date_desc',
        'page': '2',
        'limit': '10',
        'summary': '1',
      });
      expect(page.totalItems, 11);
      expect(page.items.single.id, 'c1');
      expect(page.summary!.shownCount, 13);
    });

    test('collections export: everything matching, no paging', () async {
      final cap = _Capture({'items': [_collection('c1'), _collection('c2')], 'totalItems': 2, 'truncated': false});
      final out = await CollectionService(_dio(cap)).exportCollections(const FinanceQuery(page: 5, statuses: {'verified'}));
      expect(cap.last!.queryParameters['export'], '1');
      expect(cap.last!.queryParameters.containsKey('page'), isFalse);
      expect(cap.last!.queryParameters['status'], 'verified');
      expect(out.items.length, 2);
    });

    test('expenses page: GET /expenses with the query, parsed into a page', () async {
      final cap = _Capture({'items': [_expense('x1')], 'page': 1, 'limit': 20, 'totalItems': 1, 'totalPages': 1, 'summary': _summaryJson});
      final page = await ExpenseService(_dio(cap)).getExpensePage(
        const FinanceQuery(categories: {'food', 'fuel'}, workType: 'bridal', minAmount: 100),
      );
      expect(cap.last!.path, '/expenses');
      expect(cap.last!.queryParameters['category'], 'food,fuel');
      expect(cap.last!.queryParameters['workType'], 'bridal');
      expect(cap.last!.queryParameters['minAmount'], '100.0');
      expect(page.items.single.category, 'food');
      expect(page.summary!.byWorkType.length, 2);
    });

    test('expenses export: everything matching, no paging', () async {
      final cap = _Capture({'items': [_expense('x1')], 'totalItems': 6000, 'truncated': true});
      final out = await ExpenseService(_dio(cap)).exportExpenses(const FinanceQuery(page: 3));
      expect(cap.last!.queryParameters['export'], '1');
      expect(cap.last!.queryParameters.containsKey('summary'), isFalse);
      expect(out.truncated, isTrue);
    });

    test('a failed request is reported as a friendly AppException, not a raw Dio error', () async {
      final cap = _Capture({'message': 'Invalid sort'}, status: 400);
      await expectLater(
        CollectionService(_dio(cap)).getCollectionPage(const FinanceQuery()),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        ExpenseService(_dio(cap)).getExpensePage(const FinanceQuery()),
        throwsA(isA<AppException>()),
      );
    });
  });
}
