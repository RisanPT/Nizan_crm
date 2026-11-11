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
import 'package:nizan_crm/features/accounts/controllers/food_allowance_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/food_allowance.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/expense_allocation_line.dart';
import 'package:nizan_crm/features/accounts/services/expense_service.dart';
import 'package:nizan_crm/features/accounts/data/work_cost.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/food_allowance_manager.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/meal_placement.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/work_costs_tab.dart';
import 'package:nizan_crm/features/accounts/services/food_allowance_service.dart';

// The FOOD ALLOWANCE per head. Accounts adds, edits, switches off and deletes the rules (one amount
// per meal, optional dates); a work's food is checked against heads × the amount and flagged when
// over; the artist sees the allowance as a hint while adding a meal. The rule is the server's
// (backend utils/foodAllowance.js) — these cover what the app does with it.

Map<String, dynamic> _rule(String id, String meal, double amount, {String from = '', String to = '', bool active = true, String note = ''}) => {
      '_id': id,
      'meal': meal,
      'amountPerHead': amount,
      'effectiveFrom': from,
      'effectiveTo': to,
      'active': active,
      'note': note,
    };

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

FoodAllowanceService _svc(_Capture c) => FoodAllowanceService(Dio()..httpClientAdapter = c);

/// An in-memory server: the rules, and what the screen asked it to do.
class _FakeService extends FoodAllowanceService {
  _FakeService(List<Map<String, dynamic>> rules)
      : rules = [for (final r in rules) FoodAllowanceRule.fromJson(r)],
        super(Dio());

  List<FoodAllowanceRule> rules;
  final calls = <String>[];
  Map<String, Object>? lastBody;
  Object? failWith;
  int _next = 100;

  @override
  Future<List<FoodAllowanceRule>> list() async => [...rules];

  @override
  Future<FoodAllowanceRule> create(FoodAllowanceRule rule) async {
    calls.add('create');
    lastBody = rule.toBody();
    if (failWith != null) throw failWith!;
    final made = FoodAllowanceRule(id: 'n${_next++}', meal: rule.meal, amountPerHead: rule.amountPerHead, effectiveFrom: rule.effectiveFrom, effectiveTo: rule.effectiveTo, active: rule.active, note: rule.note);
    rules = [...rules, made];
    return made;
  }

  @override
  Future<FoodAllowanceRule> update(String id, FoodAllowanceRule rule) async {
    calls.add('update $id');
    lastBody = rule.toBody();
    if (failWith != null) throw failWith!;
    final next = FoodAllowanceRule(id: id, meal: rule.meal, amountPerHead: rule.amountPerHead, effectiveFrom: rule.effectiveFrom, effectiveTo: rule.effectiveTo, active: rule.active, note: rule.note);
    rules = [for (final r in rules) r.id == id ? next : r];
    return next;
  }

  @override
  Future<FoodAllowanceRule> setActive(String id, bool active) async {
    calls.add('active $id $active');
    if (failWith != null) throw failWith!;
    final old = rules.firstWhere((r) => r.id == id);
    final next = FoodAllowanceRule(id: id, meal: old.meal, amountPerHead: old.amountPerHead, effectiveFrom: old.effectiveFrom, effectiveTo: old.effectiveTo, active: active, note: old.note);
    rules = [for (final r in rules) r.id == id ? next : r];
    return next;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    rules = [for (final r in rules) if (r.id != id) r];
  }
}

Widget _host(Widget child, {List<Override> overrides = const []}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child)))),
    );

Widget _manager(_FakeService svc) => _host(const FoodAllowanceManager(), overrides: [foodAllowanceServiceProvider.overrideWithValue(svc)]);

Future<void> _open(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(1100, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(w);
  await t.pumpAndSettle();
}

final _defaults = [
  _rule('r1', 'breakfast', 100),
  _rule('r2', 'lunch', 150, note: 'Standard rate'),
  _rule('r3', 'snacks', 50, active: false),
  _rule('r4', 'dinner', 150, from: '2026-10-01'),
];

void main() {
  group('parsing', () {
    test('a rule, and the body sent back to the server', () {
      final r = FoodAllowanceRule.fromJson(_rule('r2', 'lunch', 150.5, from: '2026-10-01', to: '2026-12-31', note: 'Festival'));
      expect((r.id, r.meal, r.amountPerHead, r.effectiveFrom, r.effectiveTo, r.active, r.note), ('r2', 'lunch', 150.5, '2026-10-01', '2026-12-31', true, 'Festival'));
      expect(r.toBody(), {'meal': 'lunch', 'amountPerHead': 150.5, 'effectiveFrom': '2026-10-01', 'effectiveTo': '2026-12-31', 'active': true, 'note': 'Festival'});
      expect(FoodAllowanceRule.fromJson({'_id': 'x', 'meal': 'lunch', 'amountPerHead': 100, 'active': false}).active, isFalse);
      expect(FoodAllowanceRule.fromJson({'meal': 'lunch'}).amountPerHead, 0);
    });

    test('the dates a rule applies to, in words', () {
      String text(Map<String, dynamic> j) => allowanceDatesText(FoodAllowanceRule.fromJson(j));
      expect(text(_rule('a', 'lunch', 1)), 'All dates');
      expect(text(_rule('a', 'lunch', 1, from: '2026-10-01')), 'From 1 Oct 2026');
      expect(text(_rule('a', 'lunch', 1, to: '2026-09-30')), 'Until 30 Sep 2026');
      expect(text(_rule('a', 'lunch', 1, from: '2026-10-01', to: '2026-12-31')), '1 Oct 2026 – 31 Dec 2026');
    });

    test('a work\'s food against the allowance', () {
      final a = AllowanceCheck.fromJson({
        'meals': [
          {'meal': 'lunch', 'actual': 700, 'allowancePerHead': 150, 'allowed': 450, 'over': 250, 'status': 'over'},
          {'meal': 'snacks', 'actual': 30, 'allowancePerHead': 50, 'allowed': 150, 'over': 0, 'status': 'within'},
          {'meal': 'dinner', 'actual': 99, 'allowancePerHead': null, 'allowed': null, 'over': 0, 'status': 'no_rule'},
        ],
        'allowed': 600, 'actual': 730, 'over': 250, 'hasOver': true, 'noMeal': 20,
      });
      expect(a.meals.map((m) => (m.meal, m.isOver)), [('lunch', true), ('snacks', false), ('dinner', false)]);
      expect(a.meals.last.allowed, isNull);
      expect((a.allowed, a.over, a.hasOver, a.noMeal), (600, 250, true, 20));
    });

    test('a work row and the totals carry it; an older server sends none', () {
      final row = WorkCostRow.fromJson({
        'bookingId': 'b', 'food': 730, 'total': 730,
        'allowance': {'meals': [], 'allowed': 0, 'actual': 0, 'over': 250, 'hasOver': true, 'noMeal': 0},
      });
      expect((row.allowance.hasOver, row.allowance.over), (true, 250));
      final old = WorkCostRow.fromJson({'bookingId': 'b'});
      expect(old.allowance.hasOver, isFalse);
      expect(old.allowance.meals, isEmpty);
      final t = WorkCostTotals.fromJson({'food': 1, 'overAllowanceCount': 2, 'overAllowanceAmount': 310.5});
      expect((t.overAllowanceCount, t.overAllowanceAmount), (2, 310.5));
      expect(WorkCostTotals.fromJson({}).overAllowanceCount, 0);
    });

    test('the hint the artist gets: the allowance per head and what it makes for the team', () {
      final p = MealPreview.fromJson({
        'dayKey': 'd', 'works': [], 'suggestion': {'mode': 'time', 'reason': '', 'flag': ''},
        'allowance': {'amountPerHead': 150, 'heads': 3},
      });
      expect((p.allowance!.amountPerHead, p.allowance!.heads, p.allowance!.teamAllowance), (150, 3, 450));
      expect(MealPreview.fromJson({'dayKey': 'd', 'works': [], 'suggestion': {}}).allowance, isNull);
    });
  });

  group('service', () {
    test('list / create / edit / switch off / delete go to /food-allowances', () async {
      final cap = _Capture([_rule('r1', 'lunch', 150)]);
      final svc = _svc(cap);
      final rules = await svc.list();
      expect((cap.last!.method, cap.last!.path, rules.single.meal), ('GET', '/food-allowances', 'lunch'));

      final c2 = _Capture(_rule('n1', 'dinner', 160));
      final made = await _svc(c2).create(const FoodAllowanceRule(id: '', meal: 'dinner', amountPerHead: 160, effectiveFrom: '2026-10-01'));
      expect((c2.last!.method, c2.last!.path), ('POST', '/food-allowances'));
      expect(c2.last!.data, {'meal': 'dinner', 'amountPerHead': 160.0, 'effectiveFrom': '2026-10-01', 'effectiveTo': '', 'active': true, 'note': ''});
      expect(made.id, 'n1');

      await _svc(c2).update('r1', const FoodAllowanceRule(id: 'r1', meal: 'lunch', amountPerHead: 175));
      expect((c2.last!.method, c2.last!.path), ('PUT', '/food-allowances/r1'));
      expect((c2.last!.data as Map)['amountPerHead'], 175.0);

      await _svc(c2).setActive('r1', false);
      expect(c2.last!.data, {'active': false}, reason: 'switching off sends nothing else');

      await _svc(c2).delete('r1');
      expect((c2.last!.method, c2.last!.path), ('DELETE', '/food-allowances/r1'));
    });

    test('a refusal is a friendly AppException', () async {
      final cap = _Capture({'message': 'Only Accounts or an admin can change the food allowance.'}, status: 403);
      await expectLater(_svc(cap).create(const FoodAllowanceRule(id: '', meal: 'lunch', amountPerHead: 1)), throwsA(isA<AppException>()));
      await expectLater(_svc(cap).list(), throwsA(isA<AppException>()));
      await expectLater(_svc(cap).delete('x'), throwsA(isA<AppException>()));
    });
  });

  group('Accounts manages the rules', () {
    testWidgets('no rules yet: says so and offers to add one', (t) async {
      await _open(t, _manager(_FakeService([])));
      expect(find.byKey(const Key('allowanceEmpty')), findsOneWidget);
      expect(find.byKey(const Key('allowanceAdd')), findsOneWidget);
    });

    testWidgets('lists every rule: the meal, ₹ per head, its dates, its note, and whether it is switched off', (t) async {
      await _open(t, _manager(_FakeService(_defaults)));
      expect(find.byKey(const Key('allowanceRow_r1')), findsOneWidget);
      expect(find.textContaining('Breakfast'), findsOneWidget);
      expect(find.textContaining('₹100 per head'), findsOneWidget);
      expect(find.textContaining('Standard rate'), findsOneWidget);
      expect(find.textContaining('From 1 Oct 2026'), findsOneWidget);
      expect(find.textContaining('Switched off'), findsOneWidget);
      expect(t.widget<Switch>(find.byKey(const Key('allowanceSwitch_r3'))).value, isFalse);
      expect(t.widget<Switch>(find.byKey(const Key('allowanceSwitch_r1'))).value, isTrue);
    });

    testWidgets('add: pick the meal, type the amount, save — the list shows it', (t) async {
      final svc = _FakeService([]);
      await _open(t, _manager(svc));
      await t.tap(find.byKey(const Key('allowanceAdd')));
      await t.pumpAndSettle();
      expect(find.text('Add allowance'), findsWidgets);

      await t.tap(find.byKey(const Key('allowanceMeal')));
      await t.pumpAndSettle();
      await t.tap(find.text('Dinner').last);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('allowanceAmount')), '175.5');
      await t.enterText(find.byKey(const Key('allowanceNote')), 'Wedding season');
      await t.tap(find.byKey(const Key('allowanceSave')));
      await t.pumpAndSettle();

      expect(svc.calls, ['create']);
      expect(svc.lastBody, {'meal': 'dinner', 'amountPerHead': 175.5, 'effectiveFrom': '', 'effectiveTo': '', 'active': true, 'note': 'Wedding season'});
      expect(find.byKey(const Key('allowanceForm')), findsNothing);
      expect(find.textContaining('₹176 per head'), findsOneWidget, reason: 'the new rule is on the list (₹175.5 shown in whole rupees)');
      expect(find.byKey(const Key('allowanceEmpty')), findsNothing);
    });

    testWidgets('add: an empty or negative amount is refused before anything is sent', (t) async {
      final svc = _FakeService([]);
      await _open(t, _manager(svc));
      await t.tap(find.byKey(const Key('allowanceAdd')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('allowanceSave')));
      await t.pumpAndSettle();
      expect(find.text('Enter the amount allowed per head (0 or more).'), findsOneWidget);
      await t.enterText(find.byKey(const Key('allowanceAmount')), '-5');
      await t.tap(find.byKey(const Key('allowanceSave')));
      await t.pumpAndSettle();
      expect(find.text('Enter the amount allowed per head (0 or more).'), findsOneWidget);
      expect(svc.calls, isEmpty);
      await t.enterText(find.byKey(const Key('allowanceAmount')), '0');
      await t.tap(find.byKey(const Key('allowanceSave')));
      await t.pumpAndSettle();
      expect(svc.calls, ['create'], reason: '₹0 is a valid allowance');
    });

    testWidgets('add: the server\'s refusal (a clash with another rule) is shown in the form, which stays open', (t) async {
      final svc = _FakeService(_defaults)..failWith = Exception('There is already an active lunch allowance for those dates (₹150 per head). Change its dates or switch it off first.');
      await _open(t, _manager(svc));
      await t.tap(find.byKey(const Key('allowanceAdd')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('allowanceAmount')), '160');
      await t.tap(find.byKey(const Key('allowanceSave')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('allowanceError')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('allowanceError'))).data, contains('already an active lunch allowance'));
      expect(find.byKey(const Key('allowanceSave')), findsOneWidget, reason: 'still open, to fix it');
      expect(t.widget<FilledButton>(find.byKey(const Key('allowanceSave'))).onPressed, isNotNull, reason: 'and can be tried again');
    });

    testWidgets('dates: from and to are optional, can be cleared, and from after to is refused', (t) async {
      final svc = _FakeService([]);
      await _open(t, _manager(svc));
      await t.tap(find.byKey(const Key('allowanceAdd')));
      await t.pumpAndSettle();
      expect(find.text('No limit'), findsNWidgets(2));

      Future<void> pickDay(Key field, String day) async {
        await t.tap(find.byKey(field));
        await t.pumpAndSettle();
        await t.tap(find.text(day).last);
        await t.tap(find.text('OK'));
        await t.pumpAndSettle();
      }

      final month = DateFormat('yyyy-MM').format(DateTime.now());
      await pickDay(const Key('allowanceFrom'), '20');
      await pickDay(const Key('allowanceTo'), '10');
      await t.enterText(find.byKey(const Key('allowanceAmount')), '90');
      await t.tap(find.byKey(const Key('allowanceSave')));
      await t.pumpAndSettle();
      expect(find.text('The "from" date is after the "to" date.'), findsOneWidget);
      expect(svc.calls, isEmpty);

      await pickDay(const Key('allowanceTo'), '25');
      await t.tap(find.byKey(const Key('allowanceSave')));
      await t.pumpAndSettle();
      expect(svc.lastBody!['effectiveFrom'], '$month-20');
      expect(svc.lastBody!['effectiveTo'], '$month-25');
    });

    testWidgets('edit: the form starts with what the rule is; saving changes only that rule', (t) async {
      final svc = _FakeService(_defaults);
      await _open(t, _manager(svc));
      await t.tap(find.byKey(const Key('allowanceEdit_r2')));
      await t.pumpAndSettle();
      expect(find.text('Edit allowance'), findsOneWidget);
      expect(t.widget<TextField>(find.byKey(const Key('allowanceAmount'))).controller!.text, '150');
      expect(t.widget<TextField>(find.byKey(const Key('allowanceNote'))).controller!.text, 'Standard rate');
      expect(find.text('Lunch'), findsWidgets);

      await t.enterText(find.byKey(const Key('allowanceAmount')), '165');
      await t.tap(find.byKey(const Key('allowanceSave')));
      await t.pumpAndSettle();
      expect(svc.calls, ['update r2']);
      expect(svc.lastBody!['amountPerHead'], 165.0);
      expect(svc.lastBody!['note'], 'Standard rate', reason: 'what was not touched is sent back as it was');
      expect(find.textContaining('₹165 per head'), findsOneWidget);
      expect(find.textContaining('₹150 per head'), findsOneWidget, reason: 'the dinner rule is still ₹150');
    });

    testWidgets('switch a rule off and on without opening it', (t) async {
      final svc = _FakeService(_defaults);
      await _open(t, _manager(svc));
      await t.tap(find.byKey(const Key('allowanceSwitch_r1')));
      await t.pumpAndSettle();
      expect(svc.calls, ['active r1 false']);
      expect(find.textContaining('Switched off'), findsNWidgets(2));
      await t.tap(find.byKey(const Key('allowanceSwitch_r3')));
      await t.pumpAndSettle();
      expect(svc.calls.last, 'active r3 true');
      expect(find.textContaining('Switched off'), findsOneWidget);
    });

    testWidgets('switching on a rule that would clash tells Accounts why, and leaves it off', (t) async {
      final svc = _FakeService(_defaults)..failWith = Exception('There is already an active snacks allowance for those dates.');
      await _open(t, _manager(svc));
      await t.tap(find.byKey(const Key('allowanceSwitch_r3')));
      await t.pumpAndSettle();
      expect(find.textContaining('already an active snacks allowance'), findsOneWidget);
      expect(t.widget<Switch>(find.byKey(const Key('allowanceSwitch_r3'))).value, isFalse);
    });

    testWidgets('delete asks first; Cancel keeps it, Delete removes it', (t) async {
      final svc = _FakeService(_defaults);
      await _open(t, _manager(svc));
      await t.tap(find.byKey(const Key('allowanceDelete_r2')));
      await t.pumpAndSettle();
      expect(find.text('Delete this allowance?'), findsOneWidget);
      expect(find.textContaining('lunch allowance of ₹150 per head'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(svc.calls, isEmpty);
      expect(find.byKey(const Key('allowanceRow_r2')), findsOneWidget);

      await t.tap(find.byKey(const Key('allowanceDelete_r2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('allowanceConfirmDelete')));
      await t.pumpAndSettle();
      expect(svc.calls, ['delete r2']);
      expect(find.byKey(const Key('allowanceRow_r2')), findsNothing);
      expect(find.byKey(const Key('allowanceRow_r1')), findsOneWidget);
    });

    testWidgets('rules that cannot be loaded offer "Try again"', (t) async {
      var fail = true;
      await _open(t, _host(const FoodAllowanceManager(), overrides: [
        foodAllowanceRulesProvider.overrideWith((ref) async {
          if (fail) throw Exception('down');
          return [FoodAllowanceRule.fromJson(_rule('r1', 'lunch', 150))];
        }),
      ]));
      expect(find.text('Try again'), findsOneWidget);
      fail = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('allowanceRow_r1')), findsOneWidget);
    });

    testWidgets('it fits a phone', (t) async {
      t.view.physicalSize = const Size(360, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_manager(_FakeService(_defaults)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('allowanceEdit_r2')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('over the allowance, on the cost-per-work report', () {
    Map<String, dynamic> work(String id, String name, {bool over = false, int heads = 3}) => {
          'bookingId': id, 'bookingNumber': 'BK-$name', 'customerName': name, 'serviceStart': '2026-10-30T07:30:00.000Z', 'period': 'afternoon',
          'artists': ['Anu'], 'food': 730, 'total': 730, 'expenseCount': 3, 'pendingCount': 0, 'lines': [],
          'heads': heads, 'foodPerHead': 730 / heads,
          'people': [
            {'employeeId': 'e1', 'name': 'Anu', 'roleType': 'lead', 'assigned': true, 'food': 730},
          ],
          'allowance': {
            'meals': [
              {'meal': 'lunch', 'actual': over ? 700 : 300, 'allowancePerHead': 150, 'allowed': 450, 'over': over ? 250 : 0, 'status': over ? 'over' : 'within'},
              {'meal': 'dinner', 'actual': 30, 'allowancePerHead': null, 'allowed': null, 'over': 0, 'status': 'no_rule'},
            ],
            'allowed': 450, 'actual': over ? 700 : 300, 'over': over ? 250 : 0, 'hasOver': over, 'noMeal': 20,
          },
        };

    WorkCostPage page(List<Map<String, dynamic>> items, {int overCount = 0, double overAmount = 0}) => WorkCostPage.fromJson({
          'items': items, 'page': 1, 'limit': 20, 'totalItems': items.length, 'totalPages': 1,
          'totals': {'food': 1460, 'other': 0, 'total': 1460, 'unplaced': 0, 'unplacedCount': 0, 'overAllowanceCount': overCount, 'overAllowanceAmount': overAmount},
        });

    Widget tab(WorkCostPage p) => _host(
          SizedBox(height: 2400, child: WorkCostsTab(from: '2026-10-01', to: '2026-10-31', artists: const [])),
          overrides: [workCostsPageProvider.overrideWith((ref, q) async => p)],
        );

    testWidgets('a work over its allowance is marked on the card, with the amount', (t) async {
      await _open(t, tab(page([work('b1', 'Beena', over: true), work('b2', 'Asha')], overCount: 1, overAmount: 250)));
      expect(t.widget<Text>(find.descendant(of: find.byKey(const Key('overChip_b1')), matching: find.byType(Text))).data, 'Over allowance ₹250');
      expect(find.byKey(const Key('overChip_b2')), findsNothing, reason: 'within the allowance: nothing to flag');
    });

    testWidgets('the header says how many works are over, and by how much', (t) async {
      await _open(t, tab(page([work('b1', 'Beena', over: true)], overCount: 1, overAmount: 250)));
      expect(find.text('Over food allowance · 1 work'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('costsOverAllowance')), matching: find.text('₹250')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await _open(t, tab(page([work('b1', 'Beena', over: true), work('b3', 'Chitra', over: true)], overCount: 2, overAmount: 500)));
      expect(find.text('Over food allowance · 2 works'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await _open(t, tab(page([work('b2', 'Asha')])));
      expect(find.byKey(const Key('costsOverAllowance')), findsNothing, reason: 'nothing over: no pill');
    });

    testWidgets('opened, a work shows each meal against heads × the allowance', (t) async {
      await _open(t, tab(page([work('b1', 'Beena', over: true)], overCount: 1, overAmount: 250)));
      expect(find.byKey(const Key('allowance_b1')), findsNothing);
      await t.tap(find.byKey(const Key('workCost_b1')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('allowance_b1')), findsOneWidget);
      expect(find.textContaining('₹700 of ₹450 (3 × ₹150)'), findsOneWidget);
      expect(find.text('Over by ₹250'), findsOneWidget);
      expect(find.text('No allowance set'), findsOneWidget, reason: 'dinner has no rule: shown, not checked');
      expect(find.textContaining('₹20 with no meal recorded — not checked'), findsOneWidget);
    });

    testWidgets('within the allowance reads as Within', (t) async {
      await _open(t, tab(page([work('b2', 'Asha')])));
      await t.tap(find.byKey(const Key('workCost_b2')));
      await t.pumpAndSettle();
      expect(find.text('Within'), findsOneWidget);
      expect(find.textContaining('Over by'), findsNothing);
    });

    testWidgets('a work with nothing to check shows no allowance block (an older server, or no meals)', (t) async {
      final bare = {...work('b4', 'Dana'), 'allowance': {'meals': [], 'allowed': 0, 'actual': 0, 'over': 0, 'hasOver': false, 'noMeal': 0}};
      await _open(t, tab(page([bare])));
      await t.tap(find.byKey(const Key('workCost_b4')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('allowance_b4')), findsNothing);
    });

    test('the export says what was allowed and what was over, work by work', () {
      final rows = workCostExportRows(page([
        {...work('b1', 'Beena', over: true), 'lines': [_line()]},
      ]).items);
      expect(kWorkCostExportHeaders.length, rows.first.length);
      expect(kWorkCostExportHeaders.sublist(kWorkCostExportHeaders.length - 2), ['Work food allowed', 'Work food over allowance']);
      expect(rows.first.sublist(rows.first.length - 2), ['450.00', '250.00']);
      final within = workCostExportRows(page([
        {...work('b2', 'Asha'), 'lines': [_line()]},
      ]).items);
      expect(within.first.last, '', reason: 'nothing over: blank');
      final unchecked = workCostExportRows(page([
        {...work('b3', 'Ela'), 'lines': [_line()], 'allowance': {'meals': [], 'hasOver': false}},
      ]).items);
      expect(unchecked.first.sublist(unchecked.first.length - 2), ['', ''], reason: 'nothing was checked: blank, not ₹0');
    });
  });

  group('the artist\'s hint', () {
    Widget card(MealPreview p) => _host(
          MealPlacementCard(at: DateTime(2026, 10, 30, 13, 30), meal: 'lunch', employeeId: null, pinnedBookingId: null, onPin: (_) {}),
          overrides: [mealPreviewProvider.overrideWith((ref, key) async => p)],
        );

    MealPreview preview(Map<String, dynamic>? allowance) => MealPreview.fromJson({
          'dayKey': '2026-10-30',
          'works': [
            {'bookingId': 'b1', 'bookingNumber': 'BK-1', 'customerName': 'Beena', 'service': 'Bridal', 'serviceStart': '2026-10-30T07:30:00.000Z', 'serviceEnd': '2026-10-30T10:30:00.000Z', 'period': 'afternoon'},
          ],
          'suggestion': {'bookingId': 'b1', 'mode': 'time', 'basis': 'period', 'period': 'afternoon', 'reason': 'Lunch at 1:30 PM — under the afternoon work.', 'flag': '', 'minutes': 0},
          'allowance': ?allowance,
        });

    testWidgets('the allowance per head and what it makes for the team', (t) async {
      await _open(t, card(preview({'amountPerHead': 150, 'heads': 3})));
      expect(t.widget<Text>(find.byKey(const Key('mealAllowanceHint'))).data, 'Allowance: ₹150 per head × 3 heads = ₹450');
    });

    testWidgets('one head reads singular; no work that day just gives the amount', (t) async {
      await _open(t, card(preview({'amountPerHead': 100, 'heads': 1})));
      expect(t.widget<Text>(find.byKey(const Key('mealAllowanceHint'))).data, 'Allowance: ₹100 per head × 1 head = ₹100');
      await t.pumpWidget(const SizedBox());
      await _open(t, card(preview({'amountPerHead': 100.5, 'heads': 0})));
      expect(t.widget<Text>(find.byKey(const Key('mealAllowanceHint'))).data, 'Allowance: ₹100.50 per head');
    });

    testWidgets('no allowance set for the meal: no hint', (t) async {
      await _open(t, card(preview(null)));
      expect(find.byKey(const Key('mealAllowanceHint')), findsNothing);
      expect(find.byKey(const Key('mealPlacement')), findsOneWidget);
    });
  });

  group('the TEAM limit, checked as the artist types', () {
    TeamMealState state({int heads = 3, double? per = 150, double spent = 300, bool pinned = false}) => TeamMealState.fromJson({
          'workId': 'b1', 'pinned': pinned, 'heads': heads, 'allowancePerHead': per, 'limit': per == null ? null : per * heads, 'alreadySpent': spent,
        });

    group('the check (the same arithmetic as the server)', () {
      test('3 heads × ₹150 = ₹450; ₹300 already + ₹200 now = ₹500 → exceeded by ₹50', () {
        final c = TeamMealCheck.compute(state(), 200, meal: 'lunch');
        expect((c.status, c.isOver, c.limit, c.alreadySpent, c.thisAmount, c.total, c.over, c.left), ('over', true, 450.0, 300.0, 200.0, 500.0, 50.0, 0.0));
      });

      test('within, and what is left', () {
        final c = TeamMealCheck.compute(state(), 100);
        expect((c.status, c.isWithin, c.over, c.left, c.total), ('within', true, 0.0, 50.0, 400.0));
      });

      test('exactly at the limit is not over', () {
        final c = TeamMealCheck.compute(state(), 150);
        expect((c.status, c.total, c.over, c.left), ('within', 450.0, 0.0, 0.0));
      });

      test('nothing logged yet: the amount alone is judged', () {
        expect(TeamMealCheck.compute(state(spent: 0), 500).over, 50.0);
        expect(TeamMealCheck.compute(state(spent: 0), 450).status, 'within');
      });

      test('already over before this amount: the whole amount is over', () {
        final c = TeamMealCheck.compute(state(heads: 2, per: 100, spent: 260), 40);
        expect((c.limit, c.total, c.over), (200.0, 300.0, 100.0));
      });

      test('no allowance set, or nobody assigned: no limit, nothing flagged', () {
        final none = TeamMealCheck.compute(state(per: null), 999);
        expect((none.status, none.limit, none.over, none.isOver), ('no_rule', null, 0.0, false));
        final solo = TeamMealCheck.compute(state(heads: 0), 999);
        expect((solo.status, solo.limit, solo.isOver), ('no_heads', null, false));
      });

      test('paise are exact, and a ₹0 allowance makes any spend over', () {
        final c = TeamMealCheck.compute(state(per: 33.33, spent: 99.98), 0.02);
        expect((c.limit, c.total, c.over, c.status), (99.99, 100.0, 0.01, 'over'));
        expect(TeamMealCheck.compute(state(heads: 2, per: 0, spent: 0), 1).isOver, isTrue);
      });

      test('what the server sends back after a save', () {
        final c = TeamMealCheck.fromJson({'workId': 'b1', 'meal': 'lunch', 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'alreadySpent': 300, 'thisAmount': 200, 'total': 500, 'over': 50, 'status': 'over'});
        expect((c.meal, c.isOver, c.over, c.total, c.limit), ('lunch', true, 50.0, 500.0, 450.0));
        final e = ArtistExpense.fromJson({'_id': 'x', 'category': 'food', 'amount': 200, 'date': '2026-10-30T08:00:00.000Z', 'limitCheck': {'meal': 'lunch', 'heads': 3, 'status': 'over', 'over': 50}});
        expect(e.limitCheck!.isOver, isTrue);
        expect(ArtistExpense.fromJson({'_id': 'x', 'category': 'food', 'date': '2026-10-30T08:00:00.000Z'}).limitCheck, isNull);
      });
    });

    group('the amount worked out for the team', () {
      test('3 heads × ₹150: nothing logged yet → the whole team\'s meal, ₹450, is what the field starts with', () {
        final a = TeamAmount.of(state(spent: 0))!;
        expect((a.heads, a.perHead, a.whole, a.alreadySpent, a.left, a.someoneLogged, a.suggested), (3, 150.0, 450.0, 0.0, 450.0, false, 450.0));
      });

      test('someone already logged ₹300 → what is left, ₹150', () {
        final a = TeamAmount.of(state())!;
        expect((a.whole, a.alreadySpent, a.left, a.someoneLogged, a.suggested), (450.0, 300.0, 150.0, true, 150.0));
      });

      test('the meal is already used up (or over) → nothing to suggest, left never negative', () {
        expect(TeamAmount.of(state(spent: 450))!.suggested, isNull);
        final over = TeamAmount.of(state(spent: 700))!;
        expect((over.left, over.suggested, over.whole), (0.0, null, 450.0));
      });

      test('no allowance set, nobody assigned, or no team at all → nothing to work from', () {
        expect(TeamAmount.of(state(per: null)), isNull);
        expect(TeamAmount.of(state(heads: 0)), isNull);
        expect(TeamAmount.of(null), isNull);
      });

      test('one head is just the allowance; paise are exact', () {
        expect(TeamAmount.of(state(heads: 1, spent: 0))!.suggested, 150.0);
        final a = TeamAmount.of(state(heads: 3, per: 33.33, spent: 0))!;
        expect((a.whole, a.suggested), (99.99, 99.99));
      });

      test('the number as written in the field: whole rupees have no decimals', () {
        expect(TeamAmount.fieldText(450), '450');
        expect(TeamAmount.fieldText(99.99), '99.99');
        expect(TeamAmount.fieldText(37.5), '37.50');
      });
    });

    group('parsing', () {
      test('the team state on a preview', () {
        final p = MealPreview.fromJson({
          'dayKey': 'd', 'works': [], 'suggestion': {},
          'team': {'workId': 'b1', 'pinned': true, 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'alreadySpent': 300},
        });
        expect((p.team!.heads, p.team!.pinned, p.team!.limit, p.team!.alreadySpent), (3, true, 450.0, 300.0));
        expect(MealPreview.fromJson({'dayKey': 'd', 'works': [], 'suggestion': {}}).team, isNull);
        expect(TeamMealState.fromJson({'workId': 'b', 'heads': 2, 'allowancePerHead': null}).limit, isNull);
      });

      test('the limit on an expense Accounts reads', () {
        final a = ExpenseAllocation.fromJson({
          'mode': 'time', 'counted': true, 'reason': '', 'flag': '', 'meal': 'lunch', 'mealAt': '2026-10-30T08:00:00.000Z', 'shares': [],
          'limit': {'meal': 'lunch', 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'teamTotal': 700, 'over': 250, 'status': 'over'},
        });
        expect((a.limit!.isOver, a.limit!.teamTotal, a.limit!.over, a.limit!.heads), (true, 700.0, 250.0, 3));
        expect(ExpenseAllocation.fromJson({'mode': 'time', 'shares': []}).limit, isNull);
      });
    });

    test('the preview asks about the chosen work and leaves out the expense being edited', () async {
      final cap = _Capture({'dayKey': 'd', 'works': [], 'suggestion': {}});
      final at = DateTime(2026, 10, 30, 13, 30);
      await ExpenseService(Dio()..httpClientAdapter = cap).getMealPreview(at: at, meal: 'lunch', bookingId: 'b-Chitra', excludeId: 'x9');
      expect(cap.last!.queryParameters, {'at': at.toUtc().toIso8601String(), 'meal': 'lunch', 'bookingId': 'b-Chitra', 'excludeId': 'x9'});
      await ExpenseService(Dio()..httpClientAdapter = cap).getMealPreview(at: at, meal: 'lunch');
      expect(cap.last!.queryParameters.keys, containsAll(['at', 'meal']));
      expect(cap.last!.queryParameters.containsKey('bookingId'), isFalse);
      expect(cap.last!.queryParameters.containsKey('excludeId'), isFalse);
    });

    group('the warning in the form', () {
      MealPreview preview({Map<String, dynamic>? team}) => MealPreview.fromJson({
            'dayKey': '2026-10-30',
            'works': [
              {'bookingId': 'b1', 'bookingNumber': 'BK-1', 'customerName': 'Beena', 'service': 'Bridal', 'serviceStart': '2026-10-30T07:30:00.000Z', 'serviceEnd': '2026-10-30T10:30:00.000Z', 'period': 'afternoon'},
            ],
            'suggestion': {'bookingId': 'b1', 'mode': 'time', 'basis': 'period', 'period': 'afternoon', 'reason': 'Lunch at 1:30 PM — under the afternoon work.', 'flag': '', 'minutes': 0},
            'allowance': {'amountPerHead': 150, 'heads': 3},
            'team': ?team,
          });
      final team = {'workId': 'b1', 'pinned': false, 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'alreadySpent': 300};

      /// The card with an amount that can be changed, as the amount field does.
      Widget form(MealPreview p, {List<MealPreviewKey>? asked, double? initial, String? pinned, String? exclude}) => _host(
            _AmountHarness(initial: initial, pinned: pinned, exclude: exclude),
            overrides: [
              mealPreviewProvider.overrideWith((ref, key) async {
                asked?.add(key);
                return p;
              }),
            ],
          );

      testWidgets('over: says the team limit is exceeded, by how much, and why', (t) async {
        await _open(t, form(preview(team: team), initial: 200));
        expect(find.byKey(const Key('teamLimitOver')), findsOneWidget);
        expect(t.widget<Text>(find.byKey(const Key('teamLimitTitle'))).data, 'Team limit exceeded by ₹50');
        expect(t.widget<Text>(find.byKey(const Key('teamLimitLimit'))).data, 'Lunch limit for the team: 3 heads × ₹150 = ₹450.');
        expect(t.widget<Text>(find.byKey(const Key('teamLimitSum'))).data, 'Already logged ₹300 + this ₹200 = ₹500.');
        expect(find.byKey(const Key('teamLimitWithin')), findsNothing);
      });

      testWidgets('within: says how much is left', (t) async {
        await _open(t, form(preview(team: team), initial: 100));
        expect(find.byKey(const Key('teamLimitWithin')), findsOneWidget);
        expect(t.widget<Text>(find.byKey(const Key('teamLimitTitle'))).data, 'Within the team limit — ₹50 left');
        expect(find.byKey(const Key('teamLimitOver')), findsNothing);
      });

      testWidgets('nothing logged yet: just this amount against the limit', (t) async {
        await _open(t, form(preview(team: {...team, 'alreadySpent': 0}), initial: 500));
        expect(t.widget<Text>(find.byKey(const Key('teamLimitTitle'))).data, 'Team limit exceeded by ₹50');
        expect(t.widget<Text>(find.byKey(const Key('teamLimitSum'))).data, 'This ₹500.');
      });

      testWidgets('it follows the typing — the banner changes as the amount does, with NO new request', (t) async {
        final asked = <MealPreviewKey>[];
        await _open(t, form(preview(team: team), asked: asked));
        expect(find.byKey(const Key('teamLimitOver')), findsNothing, reason: 'nothing typed yet: only the allowance hint');
        expect(find.byKey(const Key('teamLimitWithin')), findsNothing);
        expect(find.byKey(const Key('mealAllowanceHint')), findsOneWidget);

        await t.enterText(find.byKey(const Key('harnessAmount')), '90');
        await t.pump();
        expect(find.byKey(const Key('teamLimitWithin')), findsOneWidget);
        await t.enterText(find.byKey(const Key('harnessAmount')), '160');
        await t.pump();
        expect(find.byKey(const Key('teamLimitOver')), findsOneWidget);
        expect(t.widget<Text>(find.byKey(const Key('teamLimitTitle'))).data, 'Team limit exceeded by ₹10');
        await t.enterText(find.byKey(const Key('harnessAmount')), '');
        await t.pump();
        expect(find.byKey(const Key('teamLimitOver')), findsNothing);
        expect(asked, hasLength(1), reason: 'the server was asked once, not once per keystroke');
      });

      testWidgets('no banner when no allowance is set for the meal, or nobody is assigned', (t) async {
        await _open(t, form(preview(team: {...team, 'allowancePerHead': null, 'limit': null}), initial: 999));
        expect(find.byKey(const Key('teamLimitOver')), findsNothing);
        expect(find.byKey(const Key('teamLimitWithin')), findsNothing);
        await t.pumpWidget(const SizedBox());
        await _open(t, form(preview(team: {...team, 'heads': 0, 'limit': null}), initial: 999));
        expect(find.byKey(const Key('teamLimitOver')), findsNothing);
        await t.pumpWidget(const SizedBox());
        await _open(t, form(preview(), initial: 999));
        expect(find.byKey(const Key('teamLimitOver')), findsNothing, reason: 'an older server sends no team state');
      });

      testWidgets('the work the artist chose, and the expense being edited, are part of the question', (t) async {
        final asked = <MealPreviewKey>[];
        await _open(t, form(preview(team: team), asked: asked, pinned: 'b-Chitra', exclude: 'x9', initial: 10));
        expect(asked.single.bookingId, 'b-Chitra');
        expect(asked.single.excludeId, 'x9');
      });
    });

    group('flagged for Accounts', () {
      ArtistExpense expense(Map<String, dynamic>? limit) => ArtistExpense.fromJson({
            '_id': 'x1', 'category': 'food', 'meal': 'lunch', 'amount': 200, 'status': 'pending', 'date': '2026-10-30T08:00:00.000Z',
            'allocation': {
              'mode': 'time', 'counted': true, 'reason': 'Lunch at 1:30 PM — under the afternoon work.', 'flag': '', 'meal': 'lunch', 'mealAt': '2026-10-30T08:00:00.000Z',
              'shares': [{'bookingId': 'b1', 'bookingNumber': 'BK-1', 'customerName': 'Beena', 'amount': 200, 'period': 'afternoon'}],
              'limit': ?limit,
            },
          });

      testWidgets('an expense whose team is over the limit says so, with the team total', (t) async {
        await _open(t, _host(ExpenseAllocationLine(expense: expense({'meal': 'lunch', 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'teamTotal': 700, 'over': 250, 'status': 'over'}))));
        expect(t.widget<Text>(find.byKey(const Key('allocationOverLimit'))).data, 'Team limit exceeded by ₹250 — Lunch for the team ₹700 vs ₹450 (3 × ₹150)');
      });

      testWidgets('within the limit, or no allowance set: nothing extra', (t) async {
        await _open(t, _host(ExpenseAllocationLine(expense: expense({'meal': 'lunch', 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'teamTotal': 300, 'over': 0, 'status': 'within'}))));
        expect(find.byKey(const Key('allocationOverLimit')), findsNothing);
        await t.pumpWidget(const SizedBox());
        await _open(t, _host(ExpenseAllocationLine(expense: expense(null))));
        expect(find.byKey(const Key('allocationOverLimit')), findsNothing);
        expect(find.byKey(const Key('allocationLine')), findsOneWidget);
      });
    });
  });

  // One bill for several meals is checked together: the team may spend heads × the SUM of the
  // allowances of those meals (the server adds them up and sends that as the per-head figure, so the
  // arithmetic here is unchanged — only the names and the bigger number differ).
  group('one bill for several meals, checked together', () {
    final all3 = ['breakfast', 'lunch', 'dinner'];
    // 100 + 150 + 200 = ₹450 per head, 3 heads
    TeamMealState pool({double spent = 0, List<String>? meals}) => TeamMealState.fromJson({
          'workId': 'b1', 'pinned': false, 'heads': 3, 'allowancePerHead': 450, 'limit': 1350, 'alreadySpent': spent, 'meals': meals ?? all3,
        });

    test('the pool\'s team amount is heads × the summed allowance, less what is already logged', () {
      final whole = TeamAmount.of(pool())!;
      expect((whole.heads, whole.perHead, whole.whole, whole.suggested), (3, 450.0, 1350.0, 1350.0));
      final left = TeamAmount.of(pool(spent: 400))!;
      expect((left.left, left.suggested), (950.0, 950.0));
      expect(TeamAmount.of(pool(spent: 1350))!.suggested, isNull, reason: 'nothing left to suggest');
    });

    test('the check carries the meals and judges the total against the pool', () {
      final over = TeamMealCheck.compute(pool(spent: 1000), 500, meal: 'breakfast+lunch+dinner', meals: all3);
      expect((over.status, over.limit, over.total, over.over), ('over', 1350.0, 1500.0, 150.0));
      expect(over.meal, 'breakfast+lunch+dinner');
      expect(over.meals, all3);
      final within = TeamMealCheck.compute(pool(), 1350, meals: all3);
      expect((within.status, within.over, within.left), ('within', 0.0, 0.0));
    });

    test('a pool with a meal that has no allowance has no limit — nothing is flagged', () {
      final none = TeamMealState.fromJson({'workId': 'b1', 'pinned': false, 'heads': 3, 'allowancePerHead': null, 'limit': null, 'alreadySpent': 0, 'meals': all3});
      final c = TeamMealCheck.compute(none, 9999, meals: all3);
      expect((c.status, c.isOver, c.limit), ('no_rule', false, null));
      expect(TeamAmount.of(none), isNull);
    });

    testWidgets('the banner is named after every meal in the pool', (t) async {
      final c = TeamMealCheck.compute(pool(), 1500, meal: 'breakfast+lunch+dinner', meals: all3);
      await _open(t, _host(TeamLimitBanner(check: c, meal: 'breakfast+lunch+dinner')));
      expect(t.widget<Text>(find.byKey(const Key('teamLimitTitle'))).data, 'Team limit exceeded by ₹150');
      expect(t.widget<Text>(find.byKey(const Key('teamLimitLimit'))).data, 'Breakfast + Lunch + Dinner limit for the team: 3 heads × ₹450 = ₹1350.');
    });

    group('the artist\'s hint', () {
      MealPreview preview() => MealPreview.fromJson({
            'dayKey': '2026-10-30',
            'works': [
              {'bookingId': 'b1', 'bookingNumber': 'BK-1', 'customerName': 'Beena', 'service': 'Bridal', 'serviceStart': '2026-10-30T07:30:00.000Z', 'serviceEnd': '2026-10-30T10:30:00.000Z', 'period': 'afternoon'},
            ],
            'suggestion': {'bookingId': 'b1', 'mode': 'single', 'basis': 'only', 'period': 'afternoon', 'reason': 'The only work that day.', 'flag': '', 'minutes': null},
            'allowance': {'amountPerHead': 450, 'heads': 3},
          });

      testWidgets('says which meals the allowance is for when there are several', (t) async {
        await _open(
          t,
          _host(
            MealPlacementCard(at: DateTime(2026, 10, 30, 13, 30), meals: all3, employeeId: null, pinnedBookingId: null, onPin: (_) {}),
            overrides: [mealPreviewProvider.overrideWith((ref, key) async => preview())],
          ),
        );
        expect(t.widget<Text>(find.byKey(const Key('mealAllowanceHint'))).data, 'Allowance (Breakfast + Lunch + Dinner): ₹450 per head × 3 heads = ₹1350');
      });

      testWidgets('one meal keeps the plain wording', (t) async {
        await _open(
          t,
          _host(
            MealPlacementCard(at: DateTime(2026, 10, 30, 13, 30), meals: const ['lunch'], employeeId: null, pinnedBookingId: null, onPin: (_) {}),
            overrides: [mealPreviewProvider.overrideWith((ref, key) async => preview())],
          ),
        );
        expect(t.widget<Text>(find.byKey(const Key('mealAllowanceHint'))).data, startsWith('Allowance: '));
      });
    });

    testWidgets('an older server (no "meals" anywhere) still works: just the one meal', (t) async {
      final c = TeamMealCheck.fromJson({'workId': 'b1', 'meal': 'lunch', 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'alreadySpent': 300, 'thisAmount': 200, 'total': 500, 'over': 50, 'status': 'over'});
      expect(c.meals, isEmpty);
      final e = ArtistExpense.fromJson({
        '_id': 'x1', 'category': 'food', 'meal': 'lunch', 'amount': 200, 'status': 'pending', 'date': '2026-10-30T08:00:00.000Z',
        'allocation': {
          'mode': 'time', 'counted': true, 'reason': '', 'flag': '', 'meal': 'lunch', 'mealAt': '2026-10-30T08:00:00.000Z', 'shares': [],
          'limit': {'meal': 'lunch', 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'teamTotal': 700, 'over': 250, 'status': 'over'},
        },
      });
      await _open(t, _host(ExpenseAllocationLine(expense: e)));
      expect(t.widget<Text>(find.byKey(const Key('allocationOverLimit'))).data, contains('Lunch for the team'));
    });
  });
}

Map<String, dynamic> _line() => {
      'expenseId': 'l1', 'category': 'food', 'meal': 'lunch', 'at': '2026-10-30T08:00:00.000Z', 'amount': 200, 'status': 'pending',
      'counted': true, 'notes': '', 'mode': 'time', 'reason': 'Lunch at 1:30 PM — under the afternoon work.', 'flag': '', 'artist': 'Anu', 'employeeId': 'e1',
    };

/// The meal card above an amount field, as the artist's form has them: typing in the field
/// changes what the card checks, without the card asking the server again.
class _AmountHarness extends StatefulWidget {
  final double? initial;
  final String? pinned;
  final String? exclude;
  const _AmountHarness({this.initial, this.pinned, this.exclude});

  @override
  State<_AmountHarness> createState() => _AmountHarnessState();
}

class _AmountHarnessState extends State<_AmountHarness> {
  late final _ctrl = TextEditingController(text: widget.initial == null ? '' : '${widget.initial}');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        MealPlacementCard(
          at: DateTime(2026, 10, 30, 13, 30),
          meal: 'lunch',
          employeeId: null,
          pinnedBookingId: widget.pinned,
          onPin: (_) {},
          amount: double.tryParse(_ctrl.text.trim()),
          excludeExpenseId: widget.exclude,
        ),
        TextField(key: const Key('harnessAmount'), controller: _ctrl, onChanged: (_) => setState(() {})),
      ]);
}
