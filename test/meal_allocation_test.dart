import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/data/food_allowance.dart';
import 'package:nizan_crm/features/accounts/data/work_cost.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_day_timeline.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/expense_allocation_line.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/meal_placement.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/work_costs_tab.dart';
import 'package:nizan_crm/features/accounts/services/expense_service.dart';

// An artist's FOOD expense is put under the work it was eaten for, by the time of the meal
// (the rule is the server's — backend utils/mealAllocation.js). These cover what the app
// does with it: the artist's meal form + preview, the allocation line on an expense, one
// artist's day as a timeline, and the Accounts cost-per-work tab.

// ── fixtures ────────────────────────────────────────────────────────────────

// 30 Oct 2026, IST → UTC
String _utc(int h, [int m = 0]) => DateTime.utc(2026, 10, 30, h, m).subtract(const Duration(hours: 5, minutes: 30)).toIso8601String();

Map<String, dynamic> _share(String name, {double amount = 200, int from = 13, int to = 16, String no = 'BK-B'}) => {
      'bookingId': 'b-$name',
      'bookingNumber': no,
      'customerName': name,
      'service': 'Bridal',
      'serviceStart': _utc(from),
      'serviceEnd': _utc(to),
      'period': 'afternoon',
      'amount': amount,
    };

Map<String, dynamic> _alloc({String mode = 'time', List<Map<String, dynamic>>? shares, String reason = 'Lunch at 1:30 PM — during this work.', String flag = '', String meal = 'lunch', bool counted = true}) => {
      'mode': mode,
      'counted': counted,
      'reason': reason,
      'flag': flag,
      'meal': meal,
      'mealAt': _utc(13, 30),
      'total': 200,
      'shares': shares ?? [_share('Beena')],
    };

ArtistExpense _expense({Map<String, dynamic>? allocation, String category = 'food', String meal = 'lunch', String status = 'pending'}) => ArtistExpense.fromJson({
      '_id': 'x1',
      'category': category,
      'meal': meal,
      'workType': 'bridal',
      'amount': 200,
      'status': status,
      'date': _utc(13, 30),
      'employeeId': {'_id': 'e1', 'name': 'Anu'},
      'allocation': ?allocation,
    });

MealPreview _preview({List<String> works = const ['Asha', 'Beena', 'Chitra'], String? pick = 'Beena', String reason = 'Lunch at 1:30 PM — during this work.', String flag = '', String mode = 'time'}) => MealPreview.fromJson({
      'dayKey': '2026-10-30',
      'works': [
        for (final (i, w) in works.indexed)
          {'bookingId': 'b-$w', 'bookingNumber': 'BK-$w', 'customerName': w, 'service': 'Bridal', 'serviceStart': _utc(8 + i * 5), 'serviceEnd': _utc(11 + i * 5), 'period': const ['morning', 'afternoon', 'evening'][i]},
      ],
      'suggestion': {'bookingId': pick == null ? null : 'b-$pick', 'mode': mode, 'basis': 'period', 'period': 'afternoon', 'reason': reason, 'flag': flag, 'minutes': 0},
    });

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

ExpenseService _svc(_Capture c) => ExpenseService(Dio()..httpClientAdapter = c);

Widget _host(Widget child, {List<Override> overrides = const []}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child)))),
    );

void main() {
  group('meal helpers', () {
    test('guessMeal: the meal a time of day most likely is', () {
      DateTime at(int h, int m) => DateTime(2026, 10, 30, h, m);
      expect(guessMeal(at(6, 0)), 'breakfast');
      expect(guessMeal(at(10, 59)), 'breakfast');
      expect(guessMeal(at(11, 0)), 'lunch');
      expect(guessMeal(at(15, 29)), 'lunch');
      expect(guessMeal(at(15, 30)), 'snacks');
      expect(guessMeal(at(18, 29)), 'snacks');
      expect(guessMeal(at(18, 30)), 'dinner');
      expect(guessMeal(at(23, 45)), 'dinner');
      expect(guessMeal(at(0, 10)), 'breakfast');
    });

    test('labels', () {
      expect(mealLabel('snacks'), 'Snacks / tea');
      expect(mealLabel('lunch'), 'Lunch');
      expect(mealLabel(''), '');
      expect(mealLabel('brunch'), '');
    });
  });

  group('parsing', () {
    test('an expense carries its meal and, for Accounts, where it was placed', () {
      final e = _expense(allocation: _alloc());
      expect(e.meal, 'lunch');
      final a = e.allocation!;
      expect((a.mode, a.counted, a.isPlaced, a.isPinned, a.isFar), ('time', true, true, false, false));
      expect(a.shares.single.customerName, 'Beena');
      expect(a.shares.single.amount, 200);
      expect(a.shares.single.serviceStart, isNotNull);
      expect(a.reason, 'Lunch at 1:30 PM — during this work.');
    });

    test('an expense without allocation or meal (older / non-food) parses', () {
      final e = ArtistExpense.fromJson({'_id': 'x', 'category': 'travel', 'amount': 5, 'date': _utc(9)});
      expect((e.meal, e.allocation), ('', null));
    });

    test('allocation flags', () {
      expect(ExpenseAllocation.fromJson(_alloc(mode: 'pinned')).isPinned, isTrue);
      expect(ExpenseAllocation.fromJson(_alloc(flag: 'far')).isFar, isTrue);
      final loose = ExpenseAllocation.fromJson(_alloc(mode: 'unlinked', shares: []));
      expect(loose.isPlaced, isFalse);
      expect(loose.shares, isEmpty);
      expect(ExpenseAllocation.fromJson(_alloc(counted: false)).counted, isFalse);
      expect(ExpenseAllocation.fromJson({}).shares, isEmpty);
    });

    test('the time of day of a work (morning / afternoon / evening) and what decided the placement', () {
      expect(ExpenseAllocation.fromJson(_alloc()).shares.single.period, 'afternoon');
      expect(AllocationShare.fromJson({}).period, '');
      final p = _preview();
      expect(p.works.map((w) => w.period), ['morning', 'afternoon', 'evening']);
      expect((p.suggestion.basis, p.suggestion.period), ('period', 'afternoon'));
      expect([periodLabel('morning'), periodLabel('afternoon'), periodLabel('evening'), periodLabel('x'), periodLabel('')], ['Morning', 'Afternoon', 'Evening', '', '']);
    });

    test('a meal preview', () {
      final p = _preview();
      expect(p.works.map((w) => w.customerName), ['Asha', 'Beena', 'Chitra']);
      expect(p.suggestion.hasWork, isTrue);
      expect(p.workById(p.suggestion.bookingId)!.customerName, 'Beena');
      expect(p.workById('nope'), isNull);
      final none = _preview(works: [], pick: null, mode: 'unallocated');
      expect(none.suggestion.hasWork, isFalse);
      expect(none.works, isEmpty);
      expect(_preview(flag: 'far').suggestion.isFar, isTrue);
    });

    test('a day timeline and a cost-per-work page', () {
      final day = ArtistDay.fromJson({
        'employee': {'id': 'e1', 'name': 'Anu'},
        'dayKey': '2026-10-30',
        'works': [
          {'bookingId': 'b1', 'customerName': 'Asha', 'food': 150, 'other': 0, 'total': 150, 'outsideDay': false, 'expenses': [_line()]},
        ],
        'unplaced': [_line(mode: 'unlinked')],
        'totals': {'food': 150, 'other': 0, 'all': 150, 'unplaced': 10},
      });
      expect((day.employeeName, day.works.single.total, day.unplaced.single.mode, day.totals.unplaced), ('Anu', 150, 'unlinked', 10));
      expect(day.works.single.expenses.single.isFood, isTrue);

      final page = WorkCostPage.fromJson({
        'items': [
          {'bookingId': 'b1', 'customerName': 'Asha', 'food': 230, 'travel': 100, 'total': 330, 'artists': ['Anu'], 'expenseCount': 3, 'pendingCount': 1, 'lines': [_line()]},
        ],
        'page': 1,
        'limit': 20,
        'totalItems': 1,
        'totalPages': 1,
        'totals': {'food': 230, 'other': 100, 'total': 330, 'unplaced': 40, 'unplacedCount': 2},
        'truncated': true,
      });
      expect(page.items.single.nonFood, 100);
      expect((page.totals.unplacedCount, page.truncated), (2, true));
      expect(WorkCostPage.fromJson({}).totals.total, 0);
    });

    test('per head: the heads, the food per head, and who spent what', () {
      final row = WorkCostRow.fromJson({
        'bookingId': 'b', 'food': 330, 'total': 330, 'heads': 3, 'foodPerHead': 110,
        'people': [
          {'employeeId': 'e1', 'name': 'Anu', 'roleType': 'lead', 'assigned': true, 'food': 230},
          {'employeeId': 'e2', 'name': 'Fathima', 'roleType': 'assistant', 'assigned': true, 'food': 100},
          {'employeeId': 'e3', 'name': 'Ravi', 'roleType': '', 'assigned': false, 'food': 0},
        ],
        'lines': [_line(id: 'l1')..['employeeId'] = 'e1'],
      });
      expect((row.heads, row.foodPerHead), (3, 110.0));
      expect(row.people.map((p) => p.roleLabel), ['Lead', 'Assistant', 'Not assigned']);
      expect(row.people.map((p) => p.assigned), [true, true, false]);
      expect(row.lines.single.employeeId, 'e1');
      // an older server sends none of it
      final old = WorkCostRow.fromJson({'bookingId': 'b'});
      expect((old.heads, old.foodPerHead), (0, null));
      expect(old.people, isEmpty);
    });

    test('WorkCostQuery: params, equality, refiltered', () {
      const q = WorkCostQuery(from: '2026-10-01', to: '2026-10-31', employeeId: 'e1', search: ' beena ', page: 3, limit: 50);
      expect(q.toParams(), {'from': '2026-10-01', 'to': '2026-10-31', 'employeeId': 'e1', 'status': 'pending,verified', 'search': 'beena', 'page': '3', 'limit': '50'});
      final all = q.toParams(export: true);
      expect(all['export'], '1');
      expect(all.containsKey('page'), isFalse);
      expect(const WorkCostQuery().toParams().containsKey('from'), isFalse);
      expect(const WorkCostQuery(statuses: {'verified', 'pending'}), const WorkCostQuery(statuses: {'pending', 'verified'}));
      expect(const WorkCostQuery(statuses: {'verified'}), isNot(const WorkCostQuery()));
      expect(q.refiltered(search: 'x').page, 1);
      expect(q.copyWith(search: 'x').page, 3);
      expect(q.copyWith(employeeId: null).employeeId, isNull);
    });
  });

  group('services', () {
    test('a food expense is filed with its meal and the exact instant of the meal', () async {
      final cap = _Capture({'_id': 'x', 'category': 'food', 'meal': 'lunch', 'amount': 90, 'date': _utc(13, 30)});
      final at = DateTime(2026, 10, 30, 13, 30);
      await _svc(cap).createExpense(employeeId: 'e1', category: 'food', amount: 90, date: at, meal: 'lunch', bookingId: 'b-Beena');
      final body = cap.last!.data as Map;
      expect(body['meal'], 'lunch');
      expect(body['bookingId'], 'b-Beena');
      expect(body['date'], at.toUtc().toIso8601String(), reason: 'a UTC instant, so the server finds the right IST day and the right gap between works');
    });

    test('anything else is filed as before: no meal, the date as it was', () async {
      final cap = _Capture({'_id': 'x', 'category': 'travel', 'amount': 90, 'date': _utc(9)});
      final at = DateTime(2026, 10, 30, 9);
      await _svc(cap).createExpense(employeeId: 'e1', category: 'travel', amount: 90, date: at);
      final body = cap.last!.data as Map;
      expect(body.containsKey('meal'), isFalse);
      expect(body.containsKey('bookingId'), isFalse);
      expect(body['date'], at.toIso8601String());
    });

    test('editing: the meal, and "" takes a chosen work back off', () async {
      final cap = _Capture({'_id': 'x', 'category': 'food', 'meal': 'dinner', 'amount': 90, 'date': _utc(20, 30)});
      final at = DateTime(2026, 10, 30, 20, 30);
      await _svc(cap).updateExpense(id: 'x', category: 'food', meal: 'dinner', bookingId: '', date: at);
      final body = cap.last!.data as Map;
      expect((body['meal'], body['bookingId'], body['date']), ('dinner', '', at.toUtc().toIso8601String()));
      expect(cap.last!.path, '/expenses/x');
      await _svc(cap).updateExpense(id: 'x', amount: 5);
      expect((cap.last!.data as Map).containsKey('meal'), isFalse);
    });

    test('the meal preview asks with the instant, the meal and (for Accounts) the artist', () async {
      final cap = _Capture({'dayKey': '2026-10-30', 'works': [], 'suggestion': {'bookingId': null, 'mode': 'unallocated', 'reason': 'No work', 'flag': '', 'minutes': null}});
      final at = DateTime(2026, 10, 30, 13, 30);
      final p = await _svc(cap).getMealPreview(at: at, meal: 'lunch', employeeId: 'e1');
      expect(cap.last!.path, '/expenses/meal-preview');
      expect(cap.last!.queryParameters, {'at': at.toUtc().toIso8601String(), 'meal': 'lunch', 'employeeId': 'e1'});
      expect(p.suggestion.hasWork, isFalse);
      await _svc(cap).getMealPreview(at: at, meal: 'lunch');
      expect(cap.last!.queryParameters.containsKey('employeeId'), isFalse);
    });

    test('artist day, cost per work and its export', () async {
      final cap = _Capture({'employee': {'id': 'e1', 'name': 'Anu'}, 'dayKey': '2026-10-30', 'works': [], 'unplaced': [], 'totals': {}});
      await _svc(cap).getArtistDay(employeeId: 'e1', day: '2026-10-30');
      expect(cap.last!.path, '/expenses/artist-day');
      expect(cap.last!.queryParameters, {'employeeId': 'e1', 'day': '2026-10-30'});

      final cap2 = _Capture({'items': [], 'totals': {}});
      await _svc(cap2).getWorkCosts(const WorkCostQuery(from: '2026-10-01', to: '2026-10-31'));
      expect(cap2.last!.path, '/expenses/work-costs');
      expect(cap2.last!.queryParameters['page'], '1');
      await _svc(cap2).exportWorkCosts(const WorkCostQuery(from: '2026-10-01', to: '2026-10-31', page: 4));
      expect(cap2.last!.queryParameters['export'], '1');
      expect(cap2.last!.queryParameters.containsKey('page'), isFalse);
    });

    test('a failed request is a friendly AppException', () async {
      final cap = _Capture({'message': 'boom'}, status: 500);
      await expectLater(_svc(cap).getWorkCosts(const WorkCostQuery()), throwsA(isA<AppException>()));
      await expectLater(_svc(cap).getArtistDay(employeeId: 'e1', day: 'd'), throwsA(isA<AppException>()));
      await expectLater(_svc(cap).getMealPreview(at: DateTime.now(), meal: 'lunch'), throwsA(isA<AppException>()));
    });

    test('the Accounts expense list asks for the allocation only when told to', () {
      expect(const FinanceQuery().toParams().containsKey('withWorks'), isFalse);
      expect(const FinanceQuery(withWorks: true).toParams()['withWorks'], '1');
      expect(const FinanceQuery(withWorks: true).toParams(export: true)['withWorks'], '1');
      expect(const FinanceQuery(withWorks: true).refiltered(search: 'x').withWorks, isTrue, reason: 'changing a filter keeps it');
      expect(const FinanceQuery(withWorks: true), isNot(const FinanceQuery()));
    });
  });

  group('the artist\'s meal preview', () {
    final at = DateTime(2026, 10, 30, 13, 30);

    Widget card(MealPreview? p, {Object? error, String? pinned, ValueChanged<String?>? onPin, List<MealPreviewKey>? asked, String? employeeId}) => _host(
          MealPlacementCard(at: at, meal: 'lunch', employeeId: employeeId, pinnedBookingId: pinned, onPin: onPin ?? (_) {}),
          overrides: [
            mealPreviewProvider.overrideWith((ref, key) async {
              asked?.add(key);
              if (error != null) throw error;
              return p!;
            }),
          ],
        );

    testWidgets('says which work it will be counted under, and why', (t) async {
      final asked = <MealPreviewKey>[];
      await t.pumpWidget(card(_preview(), asked: asked));
      await t.pumpAndSettle();
      expect(find.text('Will be counted under'), findsOneWidget);
      expect(find.textContaining('Beena'), findsOneWidget);
      expect(find.byKey(const Key('mealPlacementWork')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('mealPlacementWork'))).data, contains('Afternoon · 1:00 PM – 4:00 PM'), reason: 'the work\'s time of day, then its hours');
      expect(find.text('Lunch at 1:30 PM — during this work.'), findsOneWidget);
      expect(find.byKey(const Key('mealPlacementFar')), findsNothing);
      expect(asked.single, (at: at.toUtc().toIso8601String(), meal: 'lunch', employeeId: '', bookingId: '', excludeId: ''));
    });

    testWidgets('Accounts adding for an artist names them', (t) async {
      final asked = <MealPreviewKey>[];
      await t.pumpWidget(card(_preview(), asked: asked, employeeId: 'e9'));
      await t.pumpAndSettle();
      expect(asked.single.employeeId, 'e9');
    });

    testWidgets('a meal far from every work is called out', (t) async {
      await t.pumpWidget(card(_preview(flag: 'far')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mealPlacementFar')), findsOneWidget);
    });

    testWidgets('Change lists the day\'s works; picking one reports it', (t) async {
      final picked = <String?>[];
      await t.pumpWidget(card(_preview(), onPin: picked.add));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('mealPlacementChange')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mealWorkOption_b-Asha')), findsOneWidget);
      expect(find.byKey(const Key('mealWorkOption_b-Chitra')), findsOneWidget);
      expect(find.textContaining('Morning · 8:00 AM – 11:00 AM'), findsOneWidget, reason: 'each choice says when in the day it is');
      expect(find.textContaining('Evening · 6:00 PM – 9:00 PM'), findsOneWidget);
      await t.tap(find.byKey(const Key('mealWorkOption_b-Chitra')));
      await t.pumpAndSettle();
      expect(picked, ['b-Chitra']);
    });

    testWidgets('a work the artist chose is shown as theirs, with a way back to automatic', (t) async {
      final picked = <String?>[];
      await t.pumpWidget(card(_preview(), pinned: 'b-Chitra', onPin: picked.add));
      await t.pumpAndSettle();
      expect(find.text('Counted under (your choice)'), findsOneWidget);
      expect(find.textContaining('Chitra'), findsOneWidget);
      expect(find.text('Lunch at 1:30 PM — during this work.'), findsNothing, reason: 'the time rule is not what decided it');
      await t.tap(find.byKey(const Key('mealPlacementAuto')));
      expect(picked, [null]);
    });

    testWidgets('one work that day: nothing to choose between', (t) async {
      await t.pumpWidget(card(_preview(works: ['Asha'], pick: 'Asha', mode: 'single', reason: 'The only work that day.')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mealPlacementChange')), findsNothing);
      expect(find.text('The only work that day.'), findsOneWidget);
    });

    testWidgets('no work that day: says Accounts will place it', (t) async {
      await t.pumpWidget(card(_preview(works: [], pick: null, mode: 'unallocated')));
      await t.pumpAndSettle();
      expect(find.textContaining('Accounts will place this meal'), findsOneWidget);
    });

    testWidgets('a failed check never blocks saving', (t) async {
      await t.pumpWidget(card(null, error: Exception('offline')));
      await t.pumpAndSettle();
      expect(find.textContaining('You can still save it'), findsOneWidget);
    });
  });

  group('the allocation line on an expense', () {
    Widget line(ArtistExpense e, {VoidCallback? onDay}) => _host(ExpenseAllocationLine(expense: e, onDay: onDay));

    testWidgets('a meal placed by time: meal, time, the work and its hours, and why', (t) async {
      await t.pumpWidget(line(_expense(allocation: _alloc())));
      expect(find.textContaining('Lunch · 1:30 PM'), findsOneWidget);
      expect(find.textContaining('Beena'), findsOneWidget);
      expect(find.textContaining('1:00 PM – 4:00 PM'), findsOneWidget);
      expect(find.textContaining('Afternoon'), findsOneWidget, reason: 'the work\'s time of day is shown beside its hours');
      expect(find.textContaining('BK-B'), findsOneWidget);
      expect(find.text('Lunch at 1:30 PM — during this work.'), findsOneWidget);
      expect(find.text('BY TIME'), findsOneWidget);
    });

    testWidgets('chosen by the artist, and the only work that day', (t) async {
      await t.pumpWidget(line(_expense(allocation: _alloc(mode: 'pinned', reason: 'Tied to this work.'))));
      expect(find.text('CHOSEN'), findsOneWidget);
      expect(find.text('Tied to this work.'), findsNothing, reason: 'no need to explain a choice');
      await t.pumpWidget(line(_expense(allocation: _alloc(mode: 'single', reason: 'The only work that day.'))));
      expect(find.text('ONLY WORK'), findsOneWidget);
    });

    testWidgets('far from any work is flagged', (t) async {
      await t.pumpWidget(line(_expense(allocation: _alloc(flag: 'far'))));
      expect(find.byKey(const Key('allocationFar')), findsOneWidget);
    });

    testWidgets('not placed (no meal recorded / no work): says so with the reason', (t) async {
      await t.pumpWidget(line(_expense(meal: '', allocation: _alloc(mode: 'unlinked', shares: [], meal: '', reason: 'No meal recorded — not placed under a work.'))));
      expect(find.textContaining('not placed under a work'), findsWidgets);
      expect(find.text('No meal recorded — not placed under a work.'), findsOneWidget);
      expect(find.byKey(const Key('allocationBadge')), findsNothing);
    });

    testWidgets('nothing for a non-food expense, or when the server sent no allocation', (t) async {
      await t.pumpWidget(line(_expense(category: 'travel', allocation: _alloc())));
      expect(find.byKey(const Key('allocationLine')), findsNothing);
      await t.pumpWidget(line(_expense()));
      expect(find.byKey(const Key('allocationLine')), findsNothing);
    });

    testWidgets('the Day button opens the artist\'s day', (t) async {
      var opened = 0;
      await t.pumpWidget(line(_expense(allocation: _alloc()), onDay: () => opened++));
      await t.tap(find.byKey(const Key('allocationDay')));
      expect(opened, 1);
      await t.pumpWidget(line(_expense(allocation: _alloc())));
      expect(find.byKey(const Key('allocationDay')), findsNothing);
    });
  });

  group('one artist\'s day as a timeline', () {
    ArtistDay day({bool noWorks = false}) => ArtistDay.fromJson({
          'employee': {'id': 'e1', 'name': 'Anu'},
          'dayKey': '2026-10-30',
          'works': noWorks
              ? []
              : [
                  {
                    'bookingId': 'b1', 'bookingNumber': 'BK-A', 'customerName': 'Asha', 'service': 'Bridal', 'serviceStart': _utc(8), 'serviceEnd': _utc(11), 'period': 'morning',
                    'place': 'Mavoor Rd', 'food': 150, 'other': 0, 'total': 150, 'outsideDay': false,
                    'expenses': [
                      _line(id: 'l1', meal: 'breakfast', at: _utc(7, 15), amount: 120, reason: 'Breakfast at 7:15 AM — 45 min before this work starts.'),
                      _line(id: 'l2', meal: 'snacks', at: _utc(11, 15), amount: 30, reason: 'Snacks at 11:15 AM — 15 min after this work ended.'),
                    ],
                  },
                  {
                    'bookingId': 'b2', 'bookingNumber': 'BK-B', 'customerName': 'Beena', 'service': 'Bridal', 'serviceStart': _utc(13), 'serviceEnd': _utc(16),
                    'place': '', 'food': 200, 'other': 400, 'total': 600, 'outsideDay': false,
                    'expenses': [_line(id: 'l3', meal: 'lunch', at: _utc(13, 30), amount: 200, flag: 'far'), _line(id: 'l4', category: 'travel', meal: '', amount: 400, mode: 'direct', reason: 'Tied to this work.')],
                  },
                  {
                    'bookingId': 'b9', 'customerName': 'Other-day', 'food': 77, 'other': 0, 'total': 77, 'outsideDay': true,
                    'expenses': [_line(id: 'l5', meal: 'dinner', at: _utc(20, 30), amount: 77, mode: 'pinned')],
                  },
                ],
          'unplaced': [_line(id: 'l6', meal: '', amount: 10, mode: 'unlinked', reason: 'No meal recorded — not placed under a work.', status: 'rejected', counted: false)],
          'totals': {'food': 427, 'other': 400, 'all': 827, 'unplaced': 0},
        });

    Widget timeline(Future<ArtistDay> Function() load) => _host(
          const ArtistDayTimeline(employeeId: 'e1', day: '2026-10-30'),
          overrides: [artistDayProvider.overrideWith((ref, key) => load())],
        );

    testWidgets('works in time order with the meals under each, totals on top', (t) async {
      t.view.physicalSize = const Size(900, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(timeline(() async => day()));
      await t.pumpAndSettle();
      expect(find.text('Anu'), findsOneWidget);
      expect(find.text('Fri 30 Oct 2026'), findsOneWidget);
      expect(find.textContaining('₹427'), findsWidgets);

      final asha = t.getTopLeft(find.byKey(const Key('dayWork_b1'))).dy;
      final beena = t.getTopLeft(find.byKey(const Key('dayWork_b2'))).dy;
      expect(asha, lessThan(beena));
      expect(find.textContaining('Morning  ·  8:00 AM – 11:00 AM'), findsOneWidget, reason: 'the work header says when in the day it is');
      expect(find.text('₹150'), findsWidgets);
      expect(find.text('Breakfast · 7:15 AM'), findsOneWidget);
      expect(find.text('Breakfast at 7:15 AM — 45 min before this work starts.'), findsOneWidget);
      expect(find.text('Lunch · 1:30 PM'), findsOneWidget);
      expect(find.byKey(const Key('costLineFar_l3')), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.textContaining('From another day'), findsOneWidget);
    });

    testWidgets('what could not be placed is set apart, and a rejected bill is struck through', (t) async {
      t.view.physicalSize = const Size(900, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(timeline(() async => day()));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('dayUnplaced')), findsOneWidget);
      expect(find.text('No meal recorded — not placed under a work.'), findsOneWidget);
      final amount = t.widget<Text>(find.descendant(of: find.byKey(const Key('costLine_l6')), matching: find.text('₹10')));
      expect(amount.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('a day with no work says so, and still lists the expenses', (t) async {
      await t.pumpWidget(timeline(() async => day(noWorks: true)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('dayNoWorks')), findsOneWidget);
      expect(find.byKey(const Key('dayUnplaced')), findsOneWidget);
    });

    testWidgets('a day that failed to load offers "Try again"', (t) async {
      await t.pumpWidget(timeline(() async => throw Exception('down')));
      await t.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
    });

    test('the IST day of an instant, whatever the device\'s zone', () {
      expect(istDay(DateTime.utc(2026, 10, 30, 18, 29)), '2026-10-30'); // 23:59 IST
      expect(istDay(DateTime.utc(2026, 10, 30, 18, 30)), '2026-10-31'); // 00:00 IST
      expect(istDay(DateTime.utc(2026, 10, 30, 0, 10)), '2026-10-30');
    });
  });

  group('cost per work (Accounts)', () {
    WorkCostPage page({int pageNo = 1, int pages = 1, int total = 2, bool truncated = false, List<Map<String, dynamic>>? items}) => WorkCostPage.fromJson({
          'items': items ?? [_work('b-B', 'Beena', food: 230, travel: 100, pending: 1), _work('b-A', 'Asha', food: 150)],
          'page': pageNo,
          'limit': 20,
          'totalItems': total,
          'totalPages': pages,
          'totals': {'food': 380, 'other': 100, 'total': 480, 'unplaced': 40, 'unplacedCount': 2},
          'truncated': truncated,
        });

    Widget tab({required Future<WorkCostPage> Function(WorkCostQuery q) load, String? from = '2026-10-01', String? to = '2026-10-31', List<NameOption> artists = const [(id: 'e1', name: 'Anu'), (id: 'e2', name: 'Fathima')], ExpenseService? service}) => _host(
          SizedBox(height: 2400, child: WorkCostsTab(from: from, to: to, artists: artists)),
          overrides: [
            workCostsPageProvider.overrideWith((ref, q) => load(q)),
            if (service != null) expenseServiceProvider.overrideWithValue(service),
          ],
        );

    Future<void> open(WidgetTester t, Widget w) async {
      t.view.physicalSize = const Size(1200, 2600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(w);
      await t.pumpAndSettle();
    }

    testWidgets('asks for the period shown above, page 1; totals and a card per work', (t) async {
      final asked = <WorkCostQuery>[];
      await open(t, tab(load: (q) async {
        asked.add(q);
        return page();
      }));
      expect((asked.single.from, asked.single.to, asked.single.page), ('2026-10-01', '2026-10-31', 1));
      expect(asked.single.statuses, {'pending', 'verified'});
      expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('costsFood')), matching: find.textContaining('₹'))).data, '₹380');
      expect(find.byKey(const Key('costsUnplaced')), findsOneWidget);
      expect(find.text('Not placed · 2'), findsOneWidget);
      expect(find.byKey(const Key('workCost_b-B')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('workCostTotal_b-B'))).data, '₹330');
      expect(find.text('Food ₹230'), findsOneWidget);
      expect(find.text('Travel ₹100'), findsOneWidget);
      expect(find.text('1 pending'), findsOneWidget);
      expect(find.text('2 works'), findsOneWidget);
      expect(find.textContaining('Afternoon'), findsWidgets, reason: 'each work says when in the day it is');
    });

    testWidgets('per head: a chip on the card, and who spent what when it opens', (t) async {
      await open(t, tab(load: (q) async => page()));
      expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('perHeadChip_b-B')), matching: find.byType(Text))).data, '2 heads · ₹115 food / head');
      expect(find.byKey(const Key('perHead_b-B')), findsNothing, reason: 'closed until the work is opened');
      await t.tap(find.byKey(const Key('workCost_b-B')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('perHead_b-B')), findsOneWidget);
      expect(find.textContaining('Anu'), findsWidgets);
      expect(find.text('Lead'), findsNothing);
      expect(find.textContaining('Lead'), findsWidgets);
      expect(find.text('No food filed'), findsOneWidget, reason: 'the assistant is a head too, even with no food');
      expect(find.text('Food ₹230 ÷ 2 heads = ₹115 per head'), findsOneWidget);
    });

    testWidgets('per head: no chip when there was no food, and "1 head" reads singular', (t) async {
      final onlyTravel = _work('b-T', 'Tara', travel: 100)..['heads'] = 1..['foodPerHead'] = 0.0;
      final solo = _work('b-S', 'Sana', food: 90)..['heads'] = 1..['foodPerHead'] = 90.0;
      await open(t, tab(load: (q) async => page(items: [onlyTravel, solo], total: 2)));
      expect(find.byKey(const Key('perHeadChip_b-T')), findsNothing);
      expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('perHeadChip_b-S')), matching: find.byType(Text))).data, '1 head · ₹90 food / head');
    });

    testWidgets('a work with no assignment data (older server) shows no per-head block', (t) async {
      final bare = _work('b-X', 'Xena', food: 50)..remove('heads')..remove('foodPerHead')..remove('people');
      await open(t, tab(load: (q) async => page(items: [bare], total: 1)));
      await t.tap(find.byKey(const Key('workCost_b-X')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('perHeadChip_b-X')), findsNothing);
      expect(find.byKey(const Key('perHead_b-X')), findsNothing);
    });

    testWidgets('a work opens to the lines behind its cost, each with the reason', (t) async {
      await open(t, tab(load: (q) async => page()));
      expect(find.text('Lunch at 1:30 PM — during this work.'), findsNothing);
      await t.tap(find.byKey(const Key('workCost_b-B')));
      await t.pumpAndSettle();
      expect(find.textContaining('Lunch · 1:30 PM'), findsWidgets);
      expect(find.text('Lunch at 1:30 PM — during this work.'), findsWidgets);
    });

    testWidgets('search waits for the typing to stop, then asks; artist and status narrow it; all start from page 1', (t) async {
      final asked = <WorkCostQuery>[];
      await open(t, tab(load: (q) async {
        asked.add(q);
        return page(pages: 3, total: 50);
      }));
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(asked.last.page, 2);

      final before = asked.length;
      await t.enterText(find.byKey(const Key('costsSearch')), 'bee');
      await t.pump(const Duration(milliseconds: 100));
      expect(asked.length, before, reason: 'nothing is sent while typing');
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      expect((asked.last.search, asked.last.page), ('bee', 1));

      await t.tap(find.byKey(const Key('costsStatus_verified')));
      await t.pumpAndSettle();
      expect(asked.last.statuses, {'verified'});
      await t.tap(find.byKey(const Key('costsArtist')));
      await t.pumpAndSettle();
      await t.tap(find.text('Fathima').last);
      await t.pumpAndSettle();
      expect(asked.last.employeeId, 'e2');
      expect(asked.last.search, 'bee', reason: 'still on');

      await t.tap(find.byKey(const Key('costsClear')));
      await t.pumpAndSettle();
      expect((asked.last.search, asked.last.employeeId), ('', null));
      expect(asked.last.statuses, {'pending', 'verified'});
      expect(find.byKey(const Key('costsClear')), findsNothing);
    });

    testWidgets('paging goes through the server', (t) async {
      final asked = <WorkCostQuery>[];
      await open(t, tab(load: (q) async {
        asked.add(q);
        return page(pageNo: q.page, pages: 3, total: 50);
      }));
      expect(find.textContaining('Showing 1–2 of 50'), findsOneWidget);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(asked.last.page, 2);
      await t.tap(find.text('Previous'));
      await t.pumpAndSettle();
      expect(asked.last.page, 1);
    });

    testWidgets('a new period (the month switcher above) re-asks from page 1', (t) async {
      final asked = <WorkCostQuery>[];
      Future<WorkCostPage> load(WorkCostQuery q) async {
        asked.add(q);
        return page(pages: 3, total: 50);
      }

      await open(t, tab(load: load));
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(asked.last.page, 2);
      await t.pumpWidget(tab(load: load, from: '2026-09-01', to: '2026-09-30'));
      await t.pumpAndSettle();
      expect((asked.last.from, asked.last.to, asked.last.page), ('2026-09-01', '2026-09-30', 1));
    });

    testWidgets('a partial result is flagged', (t) async {
      await open(t, tab(load: (q) async => page(truncated: true)));
      expect(find.byKey(const Key('costsTruncated')), findsOneWidget);
    });

    testWidgets('nothing in the period, and nothing matching', (t) async {
      await open(t, tab(load: (q) async => page(items: [], total: 0)));
      expect(find.text('No work costs in this period.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('costsSearch')), 'zzz');
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      expect(find.text('No works match these filters.'), findsOneWidget);
    });

    testWidgets('a page that fails keeps the last one and says so; a first failure shows "Try again"', (t) async {
      var fail = false;
      await open(t, tab(load: (q) async {
        if (fail && q.page == 2) throw Exception('timeout');
        return page(pages: 2, total: 40);
      }));
      fail = true;
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('workCost_b-B')), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await t.pumpWidget(const SizedBox()); // a fresh tab, not the one that already has a page
      await open(t, tab(load: (q) async => throw Exception('down')));
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byKey(const Key('workCost_b-B')), findsNothing);
    });

    testWidgets('Export asks the server for everything in the period', (t) async {
      final cap = _Capture({'items': [], 'totals': {}, 'totalItems': 0});
      await open(t, tab(load: (q) async => page(), service: _svc(cap)));
      await t.tap(find.byKey(const Key('costsExport')));
      await t.pumpAndSettle();
      await t.tap(find.text('Export CSV'));
      await t.pumpAndSettle();
      expect(cap.last!.queryParameters['export'], '1');
      expect(cap.last!.queryParameters['from'], '2026-10-01');
      expect(find.text('Nothing to export for this period.'), findsOneWidget);
    });

    test('the export has a row per cost line, with who, what, when and why', () {
      final rows = workCostExportRows(page().items);
      expect(kWorkCostExportHeaders.length, rows.first.length);
      expect(rows.length, 2);
      final lunch = rows.firstWhere((r) => r[4] == 'food' && r[1] == 'Beena');
      expect(lunch[3], 'Anu');
      expect(lunch[5], 'lunch');
      expect(lunch[7], '200.00');
      expect(lunch[9], 'By time of the meal');
      expect(lunch[10], 'Lunch at 1:30 PM — during this work.');
      expect(lunch[11], '2', reason: 'heads on the work');
      expect(lunch[12], '115.00', reason: 'the work\'s food per head');
      expect(DateFormat('dd MMM yyyy').format(DateTime(2026, 10, 30)), lunch[0]);
    });
  });

  // ── one bill for several meals, and how far the work is ────────────────────

  group('several meals on one bill', () {
    final all3 = ['breakfast', 'lunch', 'dinner'];

    test('labels, order, and the fields sent to the server', () {
      expect(mealsLabel(['dinner', 'breakfast', 'lunch']), 'Breakfast + Lunch + Dinner', reason: 'always in the order the day goes');
      expect(mealsLabel(['snacks']), 'Snacks / tea');
      expect(mealsLabel([]), '');
      expect(mealLabel('breakfast+lunch'), 'Breakfast + Lunch', reason: 'the key of a combined row reads as its meals');
      expect(orderMeals(['dinner', 'brunch', 'breakfast', 'dinner']), ['breakfast', 'dinner']);
      expect(mealFields(['lunch']).meals, ['lunch']);
      expect(mealFields(['lunch']).meal, 'lunch');
      expect(mealFields(['dinner', 'lunch']).meals, ['lunch', 'dinner']);
      expect(mealFields(['dinner', 'lunch']).meal, '', reason: '"meal" is only for exactly one');
      expect(mealFields([]).meals, isEmpty);
      expect(mealFields([]).meal, '');
    });

    test('an expense carries its meals; an older one still has just the one meal', () {
      final combined = ArtistExpense.fromJson({'_id': 'x', 'category': 'food', 'meal': '', 'meals': all3, 'amount': 450, 'date': _utc(13, 30)});
      expect(combined.meal, '');
      expect(combined.meals, all3);
      expect(combined.effectiveMeals, all3);
      expect(combined.isCombined, isTrue);
      final old = ArtistExpense.fromJson({'_id': 'x', 'category': 'food', 'meal': 'lunch', 'amount': 90, 'date': _utc(13, 30)});
      expect(old.meals, isEmpty);
      expect(old.effectiveMeals, ['lunch']);
      expect(old.isCombined, isFalse);
      final none = ArtistExpense.fromJson({'_id': 'x', 'category': 'food', 'amount': 90, 'date': _utc(13, 30)});
      expect(none.effectiveMeals, isEmpty);
    });

    test('the allocation, the cost lines and the works carry the meals and the distance', () {
      final a = ExpenseAllocation.fromJson({
        ..._alloc(mode: 'last', meal: ''),
        'meals': all3,
        'shares': [
          {..._share('Beena'), 'travelDistanceKm': 280.5},
        ],
      });
      expect(a.isLast, isTrue);
      expect(a.effectiveMeals, all3);
      expect(a.shares.single.travelDistanceKm, 280.5);
      expect(ExpenseAllocation.fromJson(_alloc()).effectiveMeals, ['lunch'], reason: 'an older server: just the one meal');
      expect(AllocationShare.fromJson({}).travelDistanceKm, 0);

      final line = CostLine.fromJson({..._line(meal: ''), 'meals': all3});
      expect(line.effectiveMeals, all3);
      expect(CostLine.fromJson(_line()).effectiveMeals, ['lunch']);

      expect(DayWorkBrief.fromJson({'bookingId': 'b', 'travelDistanceKm': 120}).travelDistanceKm, 120);
      expect(DayWork.fromJson({'bookingId': 'b', 'travelDistanceKm': 90}).travelDistanceKm, 90);
      expect(WorkCostRow.fromJson({..._work('b', 'Beena'), 'travelDistanceKm': 75}).travelDistanceKm, 75);
      expect(WorkCostRow.fromJson(_work('b', 'Beena')).travelDistanceKm, 0, reason: 'an older server sends none');

      final p = MealPreview.fromJson({
        'dayKey': '2026-10-30',
        'works': [],
        'suggestion': {'bookingId': 'b-Beena', 'mode': 'last', 'basis': 'last', 'reason': '', 'flag': '', 'minutes': null},
      });
      expect((p.suggestion.isLast, p.suggestion.mode), (true, 'last'));
    });

    test('the pool figures: meals on the limit, the check, the allowance row', () {
      final team = TeamMealState.fromJson({'workId': 'b', 'pinned': false, 'heads': 3, 'allowancePerHead': 450, 'limit': 1350, 'alreadySpent': 0, 'meals': all3});
      expect(team.meals, all3);
      final check = TeamMealCheck.fromJson({'workId': 'b', 'meal': 'breakfast+lunch+dinner', 'meals': all3, 'heads': 3, 'allowancePerHead': 450, 'limit': 1350, 'alreadySpent': 0, 'thisAmount': 1500, 'total': 1500, 'over': 150, 'status': 'over'});
      expect(check.meals, all3);
      expect(check.isOver, isTrue);
      expect(ExpenseLimit.fromJson({'meal': 'breakfast+lunch+dinner', 'meals': all3, 'heads': 3, 'allowancePerHead': 450, 'limit': 1350, 'teamTotal': 1500, 'over': 150, 'status': 'over'}).meals, all3);
      final row = MealAllowanceCheck.fromJson({'meal': 'breakfast+lunch+dinner', 'meals': all3, 'actual': 1500, 'allowancePerHead': 450, 'allowed': 1350, 'over': 150, 'status': 'over'});
      expect(row.isPool, isTrue);
      expect(MealAllowanceCheck.fromJson({'meal': 'lunch', 'actual': 1, 'status': 'within'}).isPool, isFalse);
    });

    test('filed with every meal it covers, at the exact instant; one meal is still just "meal"', () async {
      final cap = _Capture({'_id': 'x', 'category': 'food', 'amount': 450, 'date': _utc(13, 30)});
      final at = DateTime(2026, 10, 30, 13, 30);
      await _svc(cap).createExpense(employeeId: 'e1', category: 'food', amount: 450, date: at, meals: ['dinner', 'breakfast', 'lunch']);
      var body = cap.last!.data as Map;
      expect(body['meals'], all3, reason: 'in the order the day goes');
      expect(body['meal'], '', reason: 'the single meal is blank when there are several');
      expect(body['date'], at.toUtc().toIso8601String());

      await _svc(cap).createExpense(employeeId: 'e1', category: 'food', amount: 90, date: at, meal: 'lunch');
      body = cap.last!.data as Map;
      expect(body['meal'], 'lunch');
      expect(body['meals'], ['lunch'], reason: 'a caller giving only the meal is the same as meals: [meal]');

      await _svc(cap).createExpense(employeeId: 'e1', category: 'travel', amount: 90, date: at);
      body = cap.last!.data as Map;
      expect(body.containsKey('meals'), isFalse);
      expect(body.containsKey('meal'), isFalse);
    });

    test('editing sends the meals; an empty list takes them off', () async {
      final cap = _Capture({'_id': 'x', 'category': 'food', 'amount': 450, 'date': _utc(13, 30)});
      final at = DateTime(2026, 10, 30, 13, 30);
      await _svc(cap).updateExpense(id: 'x', category: 'food', meals: ['lunch', 'dinner'], meal: '', date: at);
      var body = cap.last!.data as Map;
      expect(body['meals'], ['lunch', 'dinner']);
      expect(body['meal'], '');
      expect(body['date'], at.toUtc().toIso8601String());
      await _svc(cap).updateExpense(id: 'x', category: 'travel', meals: <String>[], meal: '', date: at);
      body = cap.last!.data as Map;
      expect(body['meals'], isEmpty);
      expect(body['meal'], '');
      expect(body['date'], at.toIso8601String(), reason: 'no meal left: the date is a plain date again');
      await _svc(cap).updateExpense(id: 'x', amount: 5);
      expect((cap.last!.data as Map).containsKey('meals'), isFalse, reason: 'untouched when not mentioned');
    });

    test('the preview asks for one meal as "meal" and several as "meals"', () async {
      final cap = _Capture({'dayKey': '2026-10-30', 'works': [], 'suggestion': {'bookingId': null, 'mode': 'unallocated', 'reason': '', 'flag': '', 'minutes': null}});
      final at = DateTime(2026, 10, 30, 13, 30);
      await _svc(cap).getMealPreview(at: at, meals: ['dinner', 'breakfast']);
      expect(cap.last!.queryParameters, {'at': at.toUtc().toIso8601String(), 'meals': 'breakfast,dinner'});
      await _svc(cap).getMealPreview(at: at, meal: 'breakfast,lunch,dinner'); // what the provider's key carries
      expect(cap.last!.queryParameters, {'at': at.toUtc().toIso8601String(), 'meals': 'breakfast,lunch,dinner'});
      await _svc(cap).getMealPreview(at: at, meals: ['lunch']);
      expect(cap.last!.queryParameters, {'at': at.toUtc().toIso8601String(), 'meal': 'lunch'}, reason: 'one meal: exactly as before');
    });

    group('the artist\'s preview', () {
      final at = DateTime(2026, 10, 30, 13, 30);
      MealPreview preview({double km = 280, String mode = 'last', String reason = 'server words'}) => MealPreview.fromJson({
            'dayKey': '2026-10-30',
            'works': [
              for (final (i, w) in ['Asha', 'Beena'].indexed)
                {'bookingId': 'b-$w', 'bookingNumber': 'BK-$w', 'customerName': w, 'service': 'Bridal', 'serviceStart': _utc(8 + i * 8), 'serviceEnd': _utc(11 + i * 8), 'period': const ['morning', 'evening'][i], 'travelDistanceKm': i == 1 ? km : 0},
            ],
            'suggestion': {'bookingId': 'b-Beena', 'mode': mode, 'basis': mode == 'last' ? 'last' : 'period', 'period': 'afternoon', 'reason': reason, 'flag': '', 'minutes': null},
          });

      Widget card(MealPreview p, List<String> meals, {List<MealPreviewKey>? asked}) => _host(
            MealPlacementCard(at: at, meals: meals, employeeId: null, pinnedBookingId: null, onPin: (_) {}),
            overrides: [
              mealPreviewProvider.overrideWith((ref, key) async {
                asked?.add(key);
                return p;
              }),
            ],
          );

      testWidgets('asks about the whole set, and says it goes under the last work of the day', (t) async {
        final asked = <MealPreviewKey>[];
        await t.pumpWidget(card(preview(), ['dinner', 'breakfast', 'lunch'], asked: asked));
        await t.pumpAndSettle();
        expect(asked.single.meal, 'breakfast,lunch,dinner');
        expect(t.widget<Text>(find.byKey(const Key('mealPlacementLast'))).data, 'Covers breakfast, lunch and dinner — counted under the last work of the day.');
        expect(find.text('server words'), findsNothing, reason: 'our wording, not the server\'s');
        expect(t.widget<Text>(find.byKey(const Key('mealPlacementWork'))).data, startsWith('Beena'));
      });

      testWidgets('one work that day: the server\'s own reason stands', (t) async {
        await t.pumpWidget(card(preview(mode: 'single', reason: 'The only work that day.'), all3));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('mealPlacementLast')), findsNothing);
        expect(find.text('The only work that day.'), findsOneWidget);
      });

      testWidgets('the work\'s travel distance is shown when it is known, and not as "0 km" when it is not', (t) async {
        await t.pumpWidget(card(preview(), all3));
        await t.pumpAndSettle();
        expect(t.widget<Text>(find.byKey(const Key('mealPlacementDistance'))).data, 'Travel distance 280 km');
        await t.pumpWidget(const SizedBox()); // a fresh card, so the first answer is not reused
        await t.pumpWidget(card(preview(km: 0), all3));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('mealPlacementDistance')), findsNothing);
        expect(find.textContaining('0 km'), findsNothing);
      });

      testWidgets('Change lists each work with its distance', (t) async {
        await t.pumpWidget(card(preview(), all3));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('mealPlacementChange')));
        await t.pumpAndSettle();
        expect(find.textContaining('Travel distance 280 km'), findsWidgets);
        expect(find.descendant(of: find.byKey(const Key('mealWorkOption_b-Asha')), matching: find.textContaining('Travel distance')), findsNothing);
      });

      testWidgets('one meal behaves exactly as before (card still takes meal:)', (t) async {
        final asked = <MealPreviewKey>[];
        await t.pumpWidget(_host(
          MealPlacementCard(at: at, meal: 'lunch', employeeId: null, pinnedBookingId: null, onPin: (_) {}),
          overrides: [
            mealPreviewProvider.overrideWith((ref, key) async {
              asked.add(key);
              return preview(mode: 'time', reason: 'Lunch at 1:30 PM — during this work.');
            }),
          ],
        ));
        await t.pumpAndSettle();
        expect(asked.single.meal, 'lunch');
        expect(find.byKey(const Key('mealPlacementLast')), findsNothing);
        expect(find.text('Lunch at 1:30 PM — during this work.'), findsOneWidget);
      });
    });

    group('what Accounts reads on the expense', () {
      Map<String, dynamic> combined({double km = 280, String mode = 'last'}) => {
            ..._alloc(mode: mode, meal: '', reason: 'Covers breakfast, lunch and dinner — put under the last work of the day.'),
            'meals': all3,
            'shares': [
              {..._share('Beena', amount: 450), 'travelDistanceKm': km},
            ],
          };
      ArtistExpense combinedExpense(Map<String, dynamic> alloc) => ArtistExpense.fromJson({
            '_id': 'x1', 'category': 'food', 'meal': '', 'meals': all3, 'workType': 'bridal', 'amount': 450, 'status': 'pending', 'date': _utc(13, 30),
            'employeeId': {'_id': 'e1', 'name': 'Anu'},
            'allocation': alloc,
          });
      Widget line(ArtistExpense e) => _host(ExpenseAllocationLine(expense: e));

      testWidgets('lists every meal, the work it goes under, and the travel distance beside it', (t) async {
        await t.pumpWidget(line(combinedExpense(combined())));
        expect(find.textContaining('Breakfast + Lunch + Dinner · 1:30 PM'), findsOneWidget);
        expect(find.textContaining('Beena'), findsOneWidget);
        expect(find.text('LAST WORK'), findsOneWidget);
        expect(t.widget<Text>(find.byKey(const Key('allocationDistance'))).data, 'Travel distance 280 km');
        expect(find.textContaining('put under the last work of the day'), findsOneWidget);
      });

      testWidgets('a distance of 0 (not recorded) is not shown', (t) async {
        await t.pumpWidget(line(combinedExpense(combined(km: 0))));
        expect(find.byKey(const Key('allocationDistance')), findsNothing);
        expect(find.textContaining(' km'), findsNothing);
      });

      testWidgets('a single-meal expense gets the distance too, and an older row without it still renders', (t) async {
        await t.pumpWidget(line(_expense(allocation: {
          ..._alloc(),
          'shares': [
            {..._share('Beena'), 'travelDistanceKm': 12.5},
          ],
        })));
        expect(find.textContaining('Lunch · 1:30 PM'), findsOneWidget);
        expect(t.widget<Text>(find.byKey(const Key('allocationDistance'))).data, 'Travel distance 12.5 km');
        await t.pumpWidget(line(_expense(allocation: _alloc())));
        expect(find.textContaining('Lunch · 1:30 PM'), findsOneWidget);
        expect(find.byKey(const Key('allocationDistance')), findsNothing);
      });

      testWidgets('a pool over its limit names every meal in the warning', (t) async {
        final alloc = {
          ...combined(),
          'limit': {'meal': 'breakfast+lunch+dinner', 'meals': all3, 'heads': 3, 'allowancePerHead': 450, 'limit': 1350, 'teamTotal': 1500, 'over': 150, 'status': 'over'},
        };
        await t.pumpWidget(line(combinedExpense(alloc)));
        expect(t.widget<Text>(find.byKey(const Key('allocationOverLimit'))).data, contains('Team limit exceeded by ₹150 — Breakfast + Lunch + Dinner for the team'));
      });
    });

    group('the artist\'s day and the cost per work', () {
      ArtistDay day({double km = 280}) => ArtistDay.fromJson({
            'employee': {'id': 'e1', 'name': 'Anu'},
            'dayKey': '2026-10-30',
            'works': [
              {
                'bookingId': 'b1', 'bookingNumber': 'BK-A', 'customerName': 'Asha', 'serviceStart': _utc(8), 'serviceEnd': _utc(11), 'period': 'morning', 'place': 'Mavoor Rd',
                'travelDistanceKm': km, 'food': 450, 'other': 0, 'total': 450, 'outsideDay': false,
                'expenses': [
                  {..._line(id: 'l1', meal: '', at: _utc(13, 30), amount: 450, mode: 'last', reason: 'Covers breakfast, lunch and dinner — put under the last work of the day.'), 'meals': all3},
                ],
              },
              {
                'bookingId': 'b2', 'customerName': 'Beena', 'serviceStart': _utc(13), 'serviceEnd': _utc(16), 'food': 0, 'other': 0, 'total': 0, 'outsideDay': false, 'expenses': [],
              },
            ],
            'unplaced': [],
            'totals': {'food': 450, 'other': 0, 'all': 450, 'unplaced': 0},
          });

      Widget timeline(ArtistDay d) => _host(
            const ArtistDayTimeline(employeeId: 'e1', day: '2026-10-30'),
            overrides: [artistDayProvider.overrideWith((ref, key) async => d)],
          );

      testWidgets('each work of the day shows how far it is; a combined bill reads as all its meals', (t) async {
        t.view.physicalSize = const Size(900, 2400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(timeline(day()));
        await t.pumpAndSettle();
        expect(t.widget<Text>(find.byKey(const Key('dayWorkDistance_b1'))).data, 'Travel distance 280 km');
        expect(find.byKey(const Key('dayWorkDistance_b2')), findsNothing, reason: 'no distance recorded: nothing shown');
        expect(find.text('Breakfast + Lunch + Dinner · 1:30 PM'), findsOneWidget);
      });

      testWidgets('no distance at all: no distance line anywhere', (t) async {
        t.view.physicalSize = const Size(900, 2400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(timeline(day(km: 0)));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('dayWorkDistance_b1')), findsNothing);
        expect(find.textContaining(' km'), findsNothing);
      });

      Future<void> openCosts(WidgetTester t, List<Map<String, dynamic>> items) async {
        t.view.physicalSize = const Size(1200, 2600);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(_host(
          const SizedBox(height: 2400, child: WorkCostsTab(from: '2026-10-01', to: '2026-10-31')),
          overrides: [
            workCostsPageProvider.overrideWith((ref, q) async => WorkCostPage.fromJson({
                  'items': items,
                  'page': 1,
                  'limit': 20,
                  'totalItems': items.length,
                  'totalPages': 1,
                  'totals': {'food': 450, 'other': 0, 'total': 450, 'unplaced': 0, 'unplacedCount': 0},
                })),
          ],
        ));
        await t.pumpAndSettle();
      }

      testWidgets('a work card shows the travel distance as a chip, and none when it is not recorded', (t) async {
        await openCosts(t, [
          {..._work('b-far', 'Farah', food: 450), 'travelDistanceKm': 280},
          _work('b-near', 'Nila', food: 90),
        ]);
        expect(find.descendant(of: find.byKey(const Key('distanceChip_b-far')), matching: find.text('Travel distance 280 km')), findsOneWidget);
        expect(find.byKey(const Key('distanceChip_b-near')), findsNothing);
      });

      testWidgets('an allowance row for several meals is named after all of them', (t) async {
        await openCosts(t, [
          {
            ..._work('b-far', 'Farah', food: 1500),
            'allowance': {
              'meals': [
                {'meal': 'breakfast+lunch+dinner', 'meals': all3, 'actual': 1500, 'allowancePerHead': 450, 'allowed': 1350, 'over': 150, 'status': 'over'},
              ],
              'allowed': 1350, 'actual': 1500, 'over': 150, 'hasOver': true, 'noMeal': 0,
            },
          },
        ]);
        await t.tap(find.byKey(const Key('workCost_b-far')));
        await t.pumpAndSettle();
        final row = find.byKey(const Key('allowanceMeal_b-far_breakfast+lunch+dinner'));
        expect(row, findsOneWidget);
        expect(find.descendant(of: row, matching: find.textContaining('Breakfast + Lunch + Dinner')), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('Over by ₹150')), findsOneWidget);
      });

      test('the export names every meal, says "last work", and carries the distance', () {
        final rows = workCostExportRows(WorkCostPage.fromJson({
          'items': [
            {
              ..._work('b-far', 'Farah', food: 450),
              'travelDistanceKm': 280.5,
              'lines': [
                {..._line(id: 'c1', meal: '', amount: 450, mode: 'last'), 'meals': all3},
              ],
            },
            {..._work('b-near', 'Nila', food: 90), 'lines': [_line(id: 'c2')]},
          ],
        }).items);
        final col = kWorkCostExportHeaders.indexOf('Travel distance (km)');
        expect(col, greaterThan(0));
        expect(kWorkCostExportHeaders.length, rows.first.length);
        final far = rows.firstWhere((r) => r[1] == 'Farah');
        expect((far[5], far[9], far[col]), ('breakfast + lunch + dinner', 'Last work of the day', '280.5'));
        final near = rows.firstWhere((r) => r[1] == 'Nila');
        expect((near[5], near[col]), ('lunch', ''), reason: 'a work with no distance leaves the cell blank, not 0');
      });
    });
  });
}

Map<String, dynamic> _line({String id = 'l', String category = 'food', String meal = 'lunch', String? at, double amount = 200, String mode = 'time', String reason = 'Lunch at 1:30 PM — during this work.', String flag = '', String status = 'pending', bool counted = true, String artist = 'Anu'}) => {
      'expenseId': id,
      'category': category,
      'meal': meal,
      'at': at ?? _utc(13, 30),
      'amount': amount,
      'status': status,
      'counted': counted,
      'notes': '',
      'mode': mode,
      'reason': reason,
      'flag': flag,
      'artist': artist,
    };

Map<String, dynamic> _work(String id, String name, {double food = 0, double travel = 0, int pending = 0}) => {
      'bookingId': id,
      'bookingNumber': 'BK-$name',
      'customerName': name,
      'service': 'Bridal',
      'serviceStart': _utc(13),
      'period': 'afternoon',
      'artists': ['Anu'],
      'food': food,
      'travel': travel,
      'stay': 0,
      'materials': 0,
      'fuel': 0,
      'other': 0,
      'total': food + travel,
      'expenseCount': 2,
      'pendingCount': pending,
      'lines': [_line(id: 'ln-$name', amount: 200)],
      // two heads: the lead who spent it all, and an assistant who filed none
      'heads': 2,
      'foodPerHead': food / 2,
      'people': [
        {'employeeId': 'e1', 'name': 'Anu', 'roleType': 'lead', 'assigned': true, 'food': food},
        {'employeeId': 'e2', 'name': 'Fathima', 'roleType': 'assistant', 'assigned': true, 'food': 0},
      ],
    };
