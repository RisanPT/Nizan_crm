import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
import 'package:nizan_crm/features/accounts/controllers/food_allowance_controller.dart';
import 'package:nizan_crm/features/accounts/data/food_allowance.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/data/work_cost.dart';
import 'package:nizan_crm/features/accounts/services/expense_service.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/presentation/screens/artist_finance_screen.dart';
import 'package:nizan_crm/services/employee_service.dart';

// Artist Finance with the meal logic: the artist files food under a meal + time and sees
// which work it will count under; Accounts sees, on each food expense, the work it was eaten
// for, opens the artist's day, and has a "Work costs" tab.

class _FakeBookingNotifier extends BookingNotifier {
  @override
  FutureOr<List<Booking>> build() => <Booking>[];
}

String _utc(int h, [int m = 0]) => DateTime.utc(2026, 10, 30, h, m).subtract(const Duration(hours: 5, minutes: 30)).toIso8601String();

Map<String, dynamic> _food(int i, {String meal = 'lunch', Map<String, dynamic>? allocation}) => {
      '_id': 'x$i',
      'category': 'food',
      'meal': meal,
      'workType': 'bridal',
      'amount': 200.0 + i,
      'status': 'pending',
      'date': _utc(13, 30),
      'employeeId': {'_id': 'e1', 'name': 'Anu'},
      'notes': 'Expense note $i',
      'allocation': ?allocation,
    };

const _beena = {
  'bookingId': 'b-Beena',
  'bookingNumber': 'BK-B',
  'customerName': 'Beena',
  'service': 'Bridal',
  'serviceStart': '2026-10-30T07:30:00.000Z',
  'serviceEnd': '2026-10-30T10:30:00.000Z',
  'amount': 200,
};

Map<String, dynamic> get _placed => {'mode': 'time', 'counted': true, 'reason': 'Lunch at 1:30 PM — during this work.', 'flag': '', 'meal': 'lunch', 'mealAt': _utc(13, 30), 'total': 200, 'shares': [_beena]};
Map<String, dynamic> get _unplaced => {'mode': 'unlinked', 'counted': true, 'reason': 'No meal recorded — not placed under a work.', 'flag': '', 'meal': '', 'mealAt': _utc(9), 'total': 90, 'shares': <Map<String, dynamic>>[]};

class _Server {
  final expQueries = <FinanceQuery>[];
  final collQueries = <FinanceQuery>[];
  List<Map<String, dynamic>> expenses = [_food(0, allocation: _placed), _food(1, meal: '', allocation: _unplaced), {..._food(2), 'category': 'travel', 'meal': ''}];

  FinancePage<ArtistExpense> expensePage(FinanceQuery q) {
    expQueries.add(q);
    return FinancePage(
      items: expenses.map(ArtistExpense.fromJson).toList(),
      page: q.page,
      limit: q.limit,
      totalItems: expenses.length,
      totalPages: 1,
      summary: FinanceSummary.fromJson({
        'byStatus': {'pending': {'count': expenses.length, 'amount': 600}},
        'shown': {'count': expenses.length, 'amount': 600},
        'byCategory': [],
        'byWorkType': [],
        'byArtist': [],
      }),
    );
  }

  FinancePage<ArtistCollection> collectionPage(FinanceQuery q) {
    collQueries.add(q);
    return FinancePage(items: const [], page: 1, limit: q.limit, totalItems: 0, totalPages: 1, summary: FinanceSummary.fromJson({}));
  }
}

class _FakeExpenseService extends ExpenseService {
  _FakeExpenseService() : super(Dio());
  final created = <Map<String, Object?>>[];
  final updated = <Map<String, Object?>>[];

  /// What the server says about the team's limit right after a save (null = nothing to report).
  Map<String, dynamic>? limitCheck;

  ArtistExpense _echo() => ArtistExpense.fromJson({..._food(9), 'limitCheck': ?limitCheck});

  @override
  Future<ArtistExpense> createExpense({
    required String employeeId,
    String? bookingId,
    required String category,
    required double amount,
    required DateTime date,
    String notes = '',
    String receiptImage = '',
    String workType = 'bridal',
    String meal = '',
    List<String> meals = const [],
  }) async {
    created.add({'employeeId': employeeId, 'bookingId': bookingId, 'category': category, 'amount': amount, 'date': date, 'workType': workType, 'meal': meal, 'meals': meals});
    return _echo();
  }

  @override
  Future<ArtistExpense> updateExpense({
    required String id,
    String? bookingId,
    String? category,
    double? amount,
    DateTime? date,
    String? notes,
    String? receiptImage,
    String? workType,
    String? meal,
    List<String>? meals,
  }) async {
    updated.add({'id': id, 'bookingId': bookingId, 'category': category, 'amount': amount, 'date': date, 'meal': meal, 'meals': meals});
    return _echo();
  }
}

MealPreview _preview({Map<String, dynamic>? team}) => MealPreview.fromJson({
      'dayKey': '2026-10-30',
      'works': [
        for (final (i, w) in ['Asha', 'Beena', 'Chitra'].indexed)
          {'bookingId': 'b-$w', 'bookingNumber': 'BK-$w', 'customerName': w, 'service': 'Bridal', 'serviceStart': _utc(8 + i * 5), 'serviceEnd': _utc(11 + i * 5)},
      ],
      'suggestion': {'bookingId': 'b-Beena', 'mode': 'time', 'reason': 'Lunch at 1:30 PM — during this work.', 'flag': '', 'minutes': 0},
      'team': ?team,
    });

Employee _employee(String id, String name) => Employee.fromJson({'_id': id, 'name': name, 'artistRole': 'artist', 'status': 'active'});

Widget _app(_Server server, {String role = 'accounts', String employeeId = '', _FakeExpenseService? service, List<WorkCostQuery>? costQueries, List<MealPreviewKey>? previews, Map<String, dynamic>? team, Map<String, dynamic>? Function(MealPreviewKey key)? teamFor}) => ProviderScope(
      overrides: <Override>[
        financeCollectionsPageProvider.overrideWith((ref, q) async => server.collectionPage(q)),
        financeExpensesPageProvider.overrideWith((ref, q) async => server.expensePage(q)),
        employeesProvider.overrideWith((ref) async => [_employee('e1', 'Anu'), _employee('e2', 'Fathima')]),
        bookingProvider.overrideWith(() => _FakeBookingNotifier()),
        allTrialsProvider.overrideWith((ref) async => <Trial>[]),
        authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role, employeeId: employeeId)),
        if (service != null) expenseServiceProvider.overrideWithValue(service),
        foodAllowanceRulesProvider.overrideWith((ref) async => [
              FoodAllowanceRule.fromJson({'_id': 'r2', 'meal': 'lunch', 'amountPerHead': 150, 'active': true, 'note': 'Standard rate'}),
            ]),
        mealPreviewProvider.overrideWith((ref, key) async {
          previews?.add(key);
          return _preview(team: teamFor != null ? teamFor(key) : team);
        }),
        artistDayProvider.overrideWith((ref, key) async => ArtistDay.fromJson({
              'employee': {'id': key.employeeId, 'name': 'Anu'},
              'dayKey': key.day,
              'works': [
                {'bookingId': 'b-Beena', 'customerName': 'Beena', 'serviceStart': _utc(13), 'serviceEnd': _utc(16), 'food': 200, 'other': 0, 'total': 200, 'outsideDay': false, 'expenses': []},
              ],
              'unplaced': [],
              'totals': {'food': 200, 'other': 0, 'all': 200, 'unplaced': 0},
            })),
        workCostsPageProvider.overrideWith((ref, q) async {
          costQueries?.add(q);
          return WorkCostPage.fromJson({
            'items': [
              {'bookingId': 'b-Beena', 'bookingNumber': 'BK-B', 'customerName': 'Beena', 'serviceStart': _utc(13), 'artists': ['Anu'], 'food': 230, 'total': 230, 'expenseCount': 2, 'pendingCount': 0, 'lines': []},
            ],
            'page': 1,
            'limit': 20,
            'totalItems': 1,
            'totalPages': 1,
            'totals': {'food': 230, 'other': 0, 'total': 230, 'unplaced': 0, 'unplacedCount': 0},
          });
        }),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: ArtistFinanceScreen())),
    );

Future<void> _open(WidgetTester t, _Server server, {String role = 'accounts', String employeeId = '', _FakeExpenseService? service, List<WorkCostQuery>? costQueries, List<MealPreviewKey>? previews, Map<String, dynamic>? team, Map<String, dynamic>? Function(MealPreviewKey key)? teamFor, double w = 1400, double h = 12000}) async {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(_app(server, role: role, employeeId: employeeId, service: service, costQueries: costQueries, previews: previews, team: team, teamFor: teamFor));
  await t.pumpAndSettle();
}

// The meal chips toggle (a bill can cover several meals), so "this meal" means: this one on, the others off.
bool _chipOn(WidgetTester t, String meal) => t.widget<FilterChip>(find.byKey(Key('meal_$meal'))).selected;
Future<void> _onlyMeal(WidgetTester t, String meal) async {
  if (!_chipOn(t, meal)) {
    await t.tap(find.byKey(Key('meal_$meal')));
    await t.pump();
  }
  for (final m in kMeals) {
    if (m.$1 != meal && _chipOn(t, m.$1)) {
      await t.tap(find.byKey(Key('meal_${m.$1}')));
      await t.pump();
    }
  }
  await t.pumpAndSettle();
}

Future<void> _openExpenses(WidgetTester t) async {
  await t.tap(find.text('EXPENSES'));
  await t.pumpAndSettle();
}

void main() {
  final now = DateTime.now();
  final thisMonth = FinanceQuery.monthBounds(now);

  group('what Accounts sees', () {
    testWidgets('Accounts has a third tab, By work; an artist does not', (t) async {
      await _open(t, _Server());
      expect(find.text('BY WORK'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await _open(t, _Server(), role: 'artist', employeeId: 'e1');
      expect(find.text('BY WORK'), findsNothing);
      expect(find.text('EXPENSES'), findsOneWidget);
    });

    testWidgets('the expense list asks for where each food expense belongs; collections do not', (t) async {
      final server = _Server();
      await _open(t, server);
      await _openExpenses(t);
      expect(server.expQueries.every((q) => q.withWorks), isTrue);
      expect(server.expQueries.last.toParams()['withWorks'], '1');
      expect(server.collQueries.every((q) => !q.withWorks), isTrue);
    });

    testWidgets('a food expense says which work it was eaten for; one with no meal says it is not placed; travel shows nothing', (t) async {
      await _open(t, _Server());
      await _openExpenses(t);
      expect(find.byKey(const Key('allocationLine')), findsNWidgets(2), reason: 'the two food expenses, not the travel one');
      expect(find.textContaining('Lunch · 1:30 PM'), findsOneWidget);
      expect(find.textContaining('Beena'), findsOneWidget);
      expect(find.text('Lunch at 1:30 PM — during this work.'), findsOneWidget);
      expect(find.text('BY TIME'), findsOneWidget);
      expect(find.text('No meal recorded — not placed under a work.'), findsOneWidget);
    });

    testWidgets('Day opens the artist\'s day as a timeline', (t) async {
      await _open(t, _Server());
      await _openExpenses(t);
      await t.tap(find.byKey(const Key('allocationDay')).first);
      await t.pumpAndSettle();
      expect(find.text('Fri 30 Oct 2026'), findsOneWidget);
      expect(find.byKey(const Key('dayWork_b-Beena')), findsOneWidget);
    });

    testWidgets('clearing the filters keeps asking for the allocation', (t) async {
      final server = _Server();
      await _open(t, server);
      await _openExpenses(t);
      await t.tap(find.byKey(const Key('status_pending')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('clearAll')));
      await t.pumpAndSettle();
      expect(server.expQueries.last.withWorks, isTrue);
      expect(server.expQueries.last.statuses, isEmpty);
    });

    testWidgets('Work costs follows the month switcher above the tabs', (t) async {
      final costs = <WorkCostQuery>[];
      await _open(t, _Server(), costQueries: costs);
      await t.tap(find.text('BY WORK'));
      await t.pumpAndSettle();
      expect((costs.last.from, costs.last.to), (thisMonth.$1, thisMonth.$2));
      expect(find.byKey(const Key('workCost_b-Beena')), findsOneWidget);

      await t.tap(find.byKey(const Key('periodPrev')));
      await t.pumpAndSettle();
      final last = FinanceQuery.monthBounds(DateTime(now.year, now.month - 1));
      expect((costs.last.from, costs.last.to), (last.$1, last.$2));

      await t.tap(find.byKey(const Key('periodAll')));
      await t.pumpAndSettle();
      expect((costs.last.from, costs.last.to), (null, null));
    });
  });

  group('the food allowance (Accounts)', () {
    testWidgets('Accounts finds "Food allowance per head" on the Expenses tab and it opens the rules', (t) async {
      await _open(t, _Server());
      await _openExpenses(t);
      expect(find.byKey(const Key('foodAllowanceButton')), findsOneWidget);
      await t.tap(find.byKey(const Key('foodAllowanceButton')));
      await t.pumpAndSettle();
      expect(find.text('Food allowance per head'), findsWidgets);
      expect(find.byKey(const Key('allowanceRow_r2')), findsOneWidget);
      expect(find.textContaining('₹150 per head'), findsOneWidget);
      expect(find.byKey(const Key('allowanceAdd')), findsOneWidget);
    });

    testWidgets('an artist does not get the button', (t) async {
      await _open(t, _Server(), role: 'artist', employeeId: 'e1');
      await _openExpenses(t);
      expect(find.byKey(const Key('foodAllowanceButton')), findsNothing);
    });

    testWidgets('on a phone it opens as a sheet', (t) async {
      final other = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        final text = d.toDiagnosticsNode().toStringDeep();
        if (!text.contains('RenderFlex overflowed')) other.add(text.split('\n').take(6).join(' | '));
      };
      addTearDown(() => FlutterError.onError = previous);
      await _open(t, _Server(), w: 390, h: 1700);
      await t.drag(find.byType(TabBarView), const Offset(-300, 0));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('foodAllowanceButton')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('allowanceRow_r2')), findsOneWidget);
      expect(other, isEmpty);
    });
  });

  group('the artist files a meal', () {
    Future<void> openForm(WidgetTester t, _Server server, _FakeExpenseService service, {List<MealPreviewKey>? previews, Map<String, dynamic>? team}) async {
      await _open(t, server, role: 'artist', employeeId: 'e1', service: service, previews: previews, team: team);
      await t.tap(find.text('EXPENSE'));
      await t.pumpAndSettle();
    }

    // the time shown in the "Time of the meal" field, e.g. "1:30 PM"
    String shownTime(WidgetTester t) => t
        .widget<Text>(find.descendant(
          of: find.byKey(const Key('mealTime')),
          matching: find.byWidgetPredicate((w) => w is Text && RegExp(r'^\d{1,2}:\d{2}\s?(AM|PM)$').hasMatch(w.data ?? '')),
        ))
        .data!;

    testWidgets('a new food expense starts on the meal it most likely is, with a time and a preview', (t) async {
      final previews = <MealPreviewKey>[];
      await openForm(t, _Server(), _FakeExpenseService(), previews: previews);
      final guessed = guessMeal(DateTime.now());
      for (final m in kMeals) {
        expect(t.widget<FilterChip>(find.byKey(Key('meal_${m.$1}'))).selected, m.$1 == guessed, reason: m.$1);
      }
      expect(find.byKey(const Key('mealTime')), findsOneWidget);
      expect(find.byKey(const Key('mealPlacement')), findsOneWidget);
      expect(find.text('Will be counted under'), findsOneWidget);
      expect(previews.last.meal, guessed);
    });

    testWidgets('choosing a meal moves an untouched time to its usual hour and re-checks the placement', (t) async {
      final previews = <MealPreviewKey>[];
      await openForm(t, _Server(), _FakeExpenseService(), previews: previews);
      final before = previews.length;
      // pick a meal that is NOT the current one, so the time has to move
      final other = guessMeal(DateTime.now()) == 'dinner' ? 'breakfast' : 'dinner';
      await _onlyMeal(t, other);
      await t.pumpAndSettle();
      expect(shownTime(t), other == 'dinner' ? '8:30 PM' : '8:00 AM');
      expect(previews.length, greaterThan(before));
      expect(previews.last.meal, other);
    });

    testWidgets('Change picks another of the day\'s works; the expense is filed with the meal, the time and that work', (t) async {
      final service = _FakeExpenseService();
      await openForm(t, _Server(), service);
      await _onlyMeal(t, 'lunch');
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('mealPlacementChange')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('mealWorkOption_b-Chitra')));
      await t.pumpAndSettle();
      expect(find.text('Counted under (your choice)'), findsOneWidget);

      await t.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '90');
      final timeOnScreen = shownTime(t);
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();

      expect(service.created, hasLength(1));
      final c = service.created.single;
      expect((c['category'], c['meal'], c['bookingId'], c['amount'], c['employeeId']), ('food', 'lunch', 'b-Chitra', 90.0, 'e1'));
      final date = c['date'] as DateTime;
      expect(DateFormat('h:mm a').format(date), timeOnScreen, reason: 'the time the artist saw is the time that was filed');
    });

    testWidgets('left on automatic, no work is sent and the server decides by time', (t) async {
      final service = _FakeExpenseService();
      await openForm(t, _Server(), service);
      await _onlyMeal(t, 'snacks');
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '30');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      final c = service.created.single;
      expect((c['meal'], c['bookingId']), ('snacks', null));
    });

    testWidgets('a model shoot or a non-food expense has no meal form and is filed without one', (t) async {
      final service = _FakeExpenseService();
      await openForm(t, _Server(), service);
      expect(find.byKey(const Key('meal_lunch')), findsOneWidget);

      await t.tap(find.text('Model Shoot'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('meal_lunch')), findsNothing, reason: 'a shoot is not under a client work');
      await t.tap(find.text('Bridal Work'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('meal_lunch')), findsOneWidget);

      await t.tap(find.byType(DropdownButtonFormField<String>).last);
      await t.pumpAndSettle();
      await t.tap(find.text('Travel').last);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('meal_lunch')), findsNothing);
      await t.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), '50');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      final c = service.created.single;
      expect((c['category'], c['meal'], c['bookingId']), ('travel', '', null));
    });

    testWidgets('an older food entry with no meal must be given one before it can be saved', (t) async {
      // 80 rupees: under the amount that needs a bill photo
      final server = _Server()..expenses = [{..._food(1, meal: ''), 'amount': 80.0}];
      final service = _FakeExpenseService();
      await _open(t, server, role: 'artist', employeeId: 'e1', service: service);
      await _openExpenses(t);
      await t.tap(find.byTooltip('Edit this expense'));
      await t.pumpAndSettle();
      for (final m in kMeals) {
        expect(t.widget<FilterChip>(find.byKey(Key('meal_${m.$1}'))).selected, isFalse, reason: 'nothing is assumed for an old entry');
      }
      await t.tap(find.text('SAVE CHANGES'));
      await t.pumpAndSettle();
      expect(find.text('Pick which meal(s) this was'), findsOneWidget);
      expect(service.updated, isEmpty);

      await _onlyMeal(t, 'dinner');
      await t.pumpAndSettle();
      await t.tap(find.text('SAVE CHANGES'));
      await t.pumpAndSettle();
      expect(service.updated, hasLength(1));
      expect((service.updated.single['meal'], service.updated.single['id']), ('dinner', 'x1'));
    });

    testWidgets('an artist\'s own list asks for the allocation too, and never shows a Work costs tab', (t) async {
      final server = _Server();
      await _open(t, server, role: 'artist', employeeId: 'e1');
      await _openExpenses(t);
      expect(server.expQueries.last.withWorks, isTrue);
      expect(find.text('BY WORK'), findsNothing);
    });
  });

  group('the team limit while logging a meal', () {
    // 3 heads × ₹150 = ₹450; the team has already logged ₹440 for this meal on the work
    final team = {'workId': 'b-Beena', 'pinned': false, 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'alreadySpent': 440};

    Future<void> openForm(WidgetTester t, _FakeExpenseService service, {List<MealPreviewKey>? previews}) async {
      await _open(t, _Server(), role: 'artist', employeeId: 'e1', service: service, previews: previews, team: team);
      await t.tap(find.text('EXPENSE'));
      await t.pumpAndSettle();
      await _onlyMeal(t, 'lunch');
      await t.pumpAndSettle();
    }

    Future<void> typeAmount(WidgetTester t, String v) async {
      await t.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), v);
      await t.pump();
    }

    testWidgets('as the amount is typed the form says the team limit is exceeded, then within it again', (t) async {
      await openForm(t, _FakeExpenseService());
      expect(find.byKey(const Key('teamLimitOver')), findsNothing, reason: 'the field starts with what is left (₹10), which is within the limit');
      await typeAmount(t, '90');
      expect(find.byKey(const Key('teamLimitOver')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('teamLimitTitle'))).data, 'Team limit exceeded by ₹80');
      expect(t.widget<Text>(find.byKey(const Key('teamLimitSum'))).data, 'Already logged ₹440 + this ₹90 = ₹530.');
      await typeAmount(t, '5');
      expect(find.byKey(const Key('teamLimitWithin')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('teamLimitTitle'))).data, 'Within the team limit — ₹5 left');
    });

    testWidgets('saving an over-the-limit meal still saves, and tells the artist the limit was exceeded', (t) async {
      final service = _FakeExpenseService()
        ..limitCheck = {'workId': 'b-Beena', 'meal': 'lunch', 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'alreadySpent': 440, 'thisAmount': 90, 'total': 530, 'over': 80, 'status': 'over'};
      await openForm(t, service);
      await typeAmount(t, '90');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      expect(service.created, hasLength(1), reason: 'it is flagged, not blocked');
      expect(find.byKey(const Key('teamLimitSnack')), findsOneWidget);
      expect(find.textContaining('Saved — the team limit for lunch is exceeded by ₹80'), findsOneWidget);
      expect(find.textContaining('3 heads × ₹150 = ₹450'), findsOneWidget);
      expect(find.textContaining('the team has logged ₹530'), findsOneWidget);
    });

    testWidgets('saving within the limit says nothing', (t) async {
      final service = _FakeExpenseService()
        ..limitCheck = {'workId': 'b-Beena', 'meal': 'lunch', 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'alreadySpent': 440, 'thisAmount': 5, 'total': 445, 'over': 0, 'status': 'within'};
      await openForm(t, service);
      await typeAmount(t, '5');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      expect(service.created, hasLength(1));
      expect(find.byKey(const Key('teamLimitSnack')), findsNothing);
    });

    testWidgets('a server that reports no limit (older, or no allowance set) saves quietly', (t) async {
      final service = _FakeExpenseService();
      await openForm(t, service);
      await typeAmount(t, '90');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      expect(service.created, hasLength(1));
      expect(find.byKey(const Key('teamLimitSnack')), findsNothing);
    });

    testWidgets('the work the artist picks is what the team limit is asked about', (t) async {
      final previews = <MealPreviewKey>[];
      await openForm(t, _FakeExpenseService(), previews: previews);
      await t.tap(find.byKey(const Key('mealPlacementChange')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('mealWorkOption_b-Chitra')));
      await t.pumpAndSettle();
      expect(previews.last.bookingId, 'b-Chitra');
      await t.tap(find.byKey(const Key('mealPlacementAuto')));
      await t.pumpAndSettle();
      expect(previews.last.bookingId, '');
    });

    testWidgets('editing: the expense being edited is left out of what the team has logged', (t) async {
      final previews = <MealPreviewKey>[];
      final server = _Server()..expenses = [{..._food(1), 'amount': 80.0}];
      await _open(t, server, role: 'artist', employeeId: 'e1', service: _FakeExpenseService(), previews: previews, team: team);
      await _openExpenses(t);
      await t.tap(find.byTooltip('Edit this expense'));
      await t.pumpAndSettle();
      expect(previews, isNotEmpty);
      expect(previews.last.excludeId, 'x1');
    });
  });

  group('the amount is worked out from the team on the work', () {
    Map<String, dynamic> team({int heads = 3, num per = 150, num spent = 0, String workId = 'b-Beena'}) =>
        {'workId': workId, 'pinned': false, 'heads': heads, 'allowancePerHead': per, 'limit': per * heads, 'alreadySpent': spent};

    final amountField = find.widgetWithText(TextFormField, 'Amount (₹) *');
    String amountOf(WidgetTester t) => t.widget<TextFormField>(amountField).controller!.text;
    bool chipSelected(WidgetTester t, String key) => t.widget<ChoiceChip>(find.byKey(Key(key))).selected;

    Future<void> openLunch(WidgetTester t, {Map<String, dynamic>? team, Map<String, dynamic>? Function(MealPreviewKey)? teamFor, _FakeExpenseService? service, List<MealPreviewKey>? previews}) async {
      await _open(t, _Server(), role: 'artist', employeeId: 'e1', service: service ?? _FakeExpenseService(), previews: previews, team: team, teamFor: teamFor);
      await t.tap(find.text('EXPENSE'));
      await t.pumpAndSettle();
      await _onlyMeal(t, 'lunch');
      await t.pumpAndSettle();
    }

    testWidgets('a team of 3 at ₹150 fills in ₹450, and says how it got there', (t) async {
      await openLunch(t, team: team());
      expect(amountOf(t), '450');
      expect(t.widget<Text>(find.byKey(const Key('teamAmountLine'))).data, 'Team of 3 — 3 × ₹150 = ₹450');
      expect(find.byKey(const Key('teamAmountLeft')), findsNothing, reason: 'nobody has logged this meal yet');
      expect(chipSelected(t, 'teamAmountWhole'), isTrue);
      expect(chipSelected(t, 'teamAmountMe'), isFalse);
      expect(t.widget<Text>(find.byKey(const Key('teamLimitTitle'))).data, 'Within the team limit — ₹0 left');
    });

    testWidgets('Just me puts one share in the field; it stays when the meal changes', (t) async {
      await openLunch(t, team: team());
      await t.tap(find.byKey(const Key('teamAmountMe')));
      await t.pumpAndSettle();
      expect(amountOf(t), '150');
      expect(chipSelected(t, 'teamAmountMe'), isTrue);
      await _onlyMeal(t, 'dinner');
      await t.pumpAndSettle();
      expect(amountOf(t), '150', reason: 'the artist chose it');
      await t.tap(find.byKey(const Key('teamAmountWhole')));
      await t.pumpAndSettle();
      expect(amountOf(t), '450');
    });

    testWidgets('what the artist types is never overwritten', (t) async {
      await openLunch(t, team: team());
      await t.enterText(amountField, '120');
      await t.pump();
      await _onlyMeal(t, 'dinner');
      await t.pumpAndSettle();
      expect(amountOf(t), '120');
    });

    testWidgets('while the app filled it in, a different meal or team re-calculates it', (t) async {
      // dinner has a ₹200 allowance for 2 heads on another work; lunch is 3 × ₹150
      await openLunch(t, teamFor: (k) => k.meal == 'dinner' ? team(heads: 2, per: 200, workId: 'b-Beena') : team());
      expect(amountOf(t), '450');
      await _onlyMeal(t, 'dinner');
      await t.pumpAndSettle();
      expect(amountOf(t), '400');
      expect(t.widget<Text>(find.byKey(const Key('teamAmountLine'))).data, 'Team of 2 — 2 × ₹200 = ₹400');
    });

    testWidgets('choosing another work with a different team re-calculates it', (t) async {
      await openLunch(t, teamFor: (k) => k.bookingId == 'b-Chitra' ? team(heads: 5, per: 100, workId: 'b-Chitra') : team());
      expect(amountOf(t), '450');
      await t.tap(find.byKey(const Key('mealPlacementChange')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('mealWorkOption_b-Chitra')));
      await t.pumpAndSettle();
      expect(amountOf(t), '500');
      expect(t.widget<Text>(find.byKey(const Key('teamAmountLine'))).data, 'Team of 5 — 5 × ₹100 = ₹500');
    });

    testWidgets('once someone on the team has logged the meal, only what is left is suggested', (t) async {
      await openLunch(t, team: team(spent: 300));
      expect(amountOf(t), '150');
      expect(find.byKey(const Key('teamAmountLeft')), findsOneWidget);
      expect(chipSelected(t, 'teamAmountLeft'), isTrue);
      await t.tap(find.byKey(const Key('teamAmountWhole')));
      await t.pumpAndSettle();
      expect(amountOf(t), '450');
      expect(find.byKey(const Key('teamLimitOver')), findsOneWidget, reason: '₹300 already + ₹450 = ₹750 against ₹450');
    });

    testWidgets('a meal the team has used up is left blank', (t) async {
      await openLunch(t, team: team(spent: 450));
      expect(amountOf(t), '');
      expect(find.byKey(const Key('teamAmountLeft')), findsNothing);
      expect(find.byKey(const Key('teamAmountWhole')), findsOneWidget);
    });

    testWidgets('alone on the work: the allowance itself, with one choice', (t) async {
      await openLunch(t, team: team(heads: 1));
      expect(amountOf(t), '150');
      expect(t.widget<Text>(find.byKey(const Key('teamAmountLine'))).data, 'You are the only one on this work');
      expect(find.byKey(const Key('teamAmountMe')), findsNothing);
    });

    testWidgets('no allowance set for the meal: nothing is filled in and no choices are offered', (t) async {
      await openLunch(t, team: {'workId': 'b-Beena', 'pinned': false, 'heads': 3, 'allowancePerHead': null, 'limit': null, 'alreadySpent': 0});
      expect(amountOf(t), '');
      expect(find.byKey(const Key('teamAmountLine')), findsNothing);
    });

    testWidgets('a server that sends no team (older) fills in nothing', (t) async {
      await openLunch(t);
      expect(amountOf(t), '');
      expect(find.byKey(const Key('teamAmountLine')), findsNothing);
    });

    testWidgets('editing an entry keeps its own amount', (t) async {
      final server = _Server()..expenses = [{..._food(1), 'amount': 80.0}];
      await _open(t, server, role: 'artist', employeeId: 'e1', service: _FakeExpenseService(), team: team());
      await _openExpenses(t);
      await t.tap(find.byTooltip('Edit this expense'));
      await t.pumpAndSettle();
      expect(amountOf(t), '80');
    });

    testWidgets('on a phone the three choices wrap and nothing overflows', (t) async {
      // the form's own title row overflows in the (very wide) test font; only the new widgets are judged
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.toDiagnosticsNode().toStringDeep());
      try {
        await _open(t, _Server(), role: 'artist', employeeId: 'e1', service: _FakeExpenseService(), team: team(spent: 300), w: 360, h: 900);
        await t.tap(find.text('EXPENSE'));
        await t.pumpAndSettle();
        await _onlyMeal(t, 'lunch');
        await t.pumpAndSettle();
      } finally {
        FlutterError.onError = previous;
      }
      expect(find.byKey(const Key('teamAmountLeft')), findsOneWidget);
      expect(find.byKey(const Key('teamAmountWhole')), findsOneWidget);
      expect(find.byKey(const Key('teamAmountMe')), findsOneWidget);
      expect(errors.where((e) => e.contains('meal_placement.dart')), isEmpty);
    });

    testWidgets('the filled-in amount is what gets saved', (t) async {
      final service = _FakeExpenseService();
      // 3 heads × ₹30 = ₹90 (under ₹100, so no bill photo is asked for)
      await openLunch(t, team: team(per: 30), service: service);
      expect(amountOf(t), '90');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      expect(service.created, hasLength(1));
      expect(service.created.single['amount'], 90.0);
    });
  });

  group('the limit on the expense Accounts reads', () {
    testWidgets('a food expense whose team is over the limit is flagged on the card', (t) async {
      final server = _Server()
        ..expenses = [
          _food(0, allocation: {
            ..._placed,
            'limit': {'meal': 'lunch', 'heads': 3, 'allowancePerHead': 150, 'limit': 450, 'teamTotal': 700, 'over': 250, 'status': 'over'},
          }),
        ];
      await _open(t, server);
      await _openExpenses(t);
      expect(find.byKey(const Key('allocationOverLimit')), findsOneWidget);
      expect(find.textContaining('Team limit exceeded by ₹250'), findsOneWidget);
    });
  });

  group('phone', () {
    testWidgets('the meal form fits a phone: chips wrap, time and preview stack', (t) async {
      final other = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        final text = d.toDiagnosticsNode().toStringDeep();
        // the screen's own quick-action row overflows in the (very wide) test font; not this work
        if (!text.contains('RenderFlex overflowed')) other.add(text.split('\n').take(6).join(' | '));
      };
      addTearDown(() => FlutterError.onError = previous);

      await _open(t, _Server(), role: 'artist', employeeId: 'e1', service: _FakeExpenseService(), w: 360, h: 1400);
      await t.tap(find.text('EXPENSE'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mealPlacement')), findsOneWidget);
      expect(other, isEmpty);
    });

    testWidgets('the By work tab fits a phone and sits in from the edge like the other tabs', (t) async {
      final other = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        final text = d.toDiagnosticsNode().toStringDeep();
        if (!text.contains('RenderFlex overflowed')) other.add(text.split('\n').take(6).join(' | '));
      };
      addTearDown(() => FlutterError.onError = previous);

      await _open(t, _Server(), w: 390, h: 1600);
      // swipe to the third tab (the test font is so wide that the label sits under the PDF button)
      for (var i = 0; i < 2; i++) {
        await t.drag(find.byType(TabBarView), const Offset(-300, 0));
        await t.pumpAndSettle();
      }
      expect(find.byKey(const Key('workCost_b-Beena')), findsOneWidget);
      expect(t.getTopLeft(find.byKey(const Key('workCost_b-Beena'))).dx, 16, reason: 'inset like the Collections and Expenses lists');
      expect(other, isEmpty);
    });
  });

  group('one bill for several meals', () {
    final amountField = find.widgetWithText(TextFormField, 'Amount (₹) *');
    String amountOf(WidgetTester t) => t.widget<TextFormField>(amountField).controller!.text;
    String shownTime(WidgetTester t) => t
        .widget<Text>(find.descendant(
          of: find.byKey(const Key('mealTime')),
          matching: find.byWidgetPredicate((w) => w is Text && RegExp(r'^\d{1,2}:\d{2}\s?(AM|PM)$').hasMatch(w.data ?? '')),
        ))
        .data!;
    Map<String, dynamic> team({int heads = 3, num per = 150}) =>
        {'workId': 'b-Beena', 'pinned': false, 'heads': heads, 'allowancePerHead': per, 'limit': per * heads, 'alreadySpent': 0};

    Future<void> openForm(WidgetTester t, _FakeExpenseService service, {List<MealPreviewKey>? previews, Map<String, dynamic>? Function(MealPreviewKey)? teamFor}) async {
      await _open(t, _Server(), role: 'artist', employeeId: 'e1', service: service, previews: previews, teamFor: teamFor);
      await t.tap(find.text('EXPENSE'));
      await t.pumpAndSettle();
    }

    Future<void> tapMeal(WidgetTester t, String meal) async {
      await t.tap(find.byKey(Key('meal_$meal')));
      await t.pumpAndSettle();
    }

    List<String> selected(WidgetTester t) => [for (final m in kMeals) if (_chipOn(t, m.$1)) m.$1];

    testWidgets('the chips toggle: several meals can be on at once, and each can be turned off again', (t) async {
      await openForm(t, _FakeExpenseService());
      await _onlyMeal(t, 'breakfast');
      expect(selected(t), ['breakfast']);
      await tapMeal(t, 'lunch');
      await tapMeal(t, 'dinner');
      expect(selected(t), ['breakfast', 'lunch', 'dinner']);
      expect(find.byType(ChoiceChip).evaluate().where((e) => e.widget.key.toString().contains('meal_')), isEmpty, reason: 'multi-select chips, not single-choice ones');
      await tapMeal(t, 'lunch');
      expect(selected(t), ['breakfast', 'dinner']);
    });

    testWidgets('the preview is asked about the whole set, in the order of the day, and the time field says "bill"', (t) async {
      final previews = <MealPreviewKey>[];
      await openForm(t, _FakeExpenseService(), previews: previews);
      await _onlyMeal(t, 'dinner');
      expect(find.text('Time of the meal'), findsOneWidget);
      expect(find.byKey(const Key('mealsOneBill')), findsNothing);
      await tapMeal(t, 'breakfast');
      await tapMeal(t, 'lunch');
      expect(previews.last.meal, 'breakfast,lunch,dinner');
      expect(find.text('Time of the bill'), findsOneWidget);
      expect(find.text('Time of the meal'), findsNothing);
      expect(t.widget<Text>(find.byKey(const Key('mealsOneBill'))).data, 'One bill for breakfast + lunch + dinner. Enter the total below.');
    });

    testWidgets('filed with every meal picked: meals in the order of the day, "meal" blank, one amount', (t) async {
      final service = _FakeExpenseService();
      await openForm(t, service);
      await _onlyMeal(t, 'breakfast');
      await tapMeal(t, 'dinner');
      await tapMeal(t, 'lunch');
      await t.enterText(amountField, '90');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      expect(service.created, hasLength(1));
      final c = service.created.single;
      expect(c['meals'], ['breakfast', 'lunch', 'dinner']);
      expect(c['meal'], '');
      expect(c['amount'], 90.0);
      expect(c['bookingId'], isNull, reason: 'left on automatic: the server decides where it goes');
    });

    testWidgets('one meal is filed as before (meal plus a one-item meals)', (t) async {
      final service = _FakeExpenseService();
      await openForm(t, service);
      await _onlyMeal(t, 'snacks');
      await t.enterText(amountField, '30');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      final c = service.created.single;
      expect(c['meal'], 'snacks');
      expect(c['meals'], ['snacks']);
    });

    testWidgets('with every chip off it cannot be filed, and says why', (t) async {
      final service = _FakeExpenseService();
      await openForm(t, service);
      await _onlyMeal(t, 'lunch');
      await tapMeal(t, 'lunch'); // off — nothing is picked
      expect(selected(t), isEmpty);
      expect(find.byKey(const Key('mealPlacement')), findsNothing, reason: 'nothing to place');
      await t.enterText(amountField, '30');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      expect(find.text('Pick which meal(s) this was'), findsOneWidget);
      expect(service.created, isEmpty);
    });

    testWidgets('an untouched time follows the earliest meal picked', (t) async {
      await openForm(t, _FakeExpenseService());
      // a later meal that is not the one the clock suggests, so the time has to move to it
      final later = guessMeal(DateTime.now()) == 'lunch' ? 'dinner' : 'lunch';
      final laterAt = later == 'lunch' ? '1:30 PM' : '8:30 PM';
      await _onlyMeal(t, later);
      expect(shownTime(t), laterAt);
      await tapMeal(t, 'breakfast');
      expect(shownTime(t), laterAt, reason: 'the time still suits one of the meals picked');
      await tapMeal(t, later); // off → breakfast is the earliest (only) one left
      expect(selected(t), ['breakfast']);
      expect(shownTime(t), '8:00 AM');
    });

    testWidgets('a time the artist set is kept', (t) async {
      await openForm(t, _FakeExpenseService());
      await _onlyMeal(t, 'lunch');
      await t.tap(find.byKey(const Key('mealTime')));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      final kept = shownTime(t);
      await tapMeal(t, 'dinner');
      await tapMeal(t, 'lunch');
      expect(selected(t), ['dinner']);
      expect(shownTime(t), kept);
    });

    testWidgets('the amount starts at the team allowance for all the meals picked together', (t) async {
      // each meal alone is 3 × ₹150; the three together are 3 × ₹450 (the server adds the allowances up)
      await openForm(t, _FakeExpenseService(), teamFor: (k) => team(per: k.meal == 'breakfast,lunch,dinner' ? 450 : 150));
      await _onlyMeal(t, 'breakfast');
      expect(amountOf(t), '450');
      await tapMeal(t, 'lunch');
      await tapMeal(t, 'dinner');
      expect(amountOf(t), '1350', reason: 'the app filled the field, so it follows the meals picked');
      expect(t.widget<Text>(find.byKey(const Key('teamAmountLine'))).data, 'Team of 3 — 3 × ₹450 = ₹1350');
    });

    testWidgets('the limit banner is for the pool: typing past 3 × the summed allowance says exceeded, naming the meals', (t) async {
      await openForm(t, _FakeExpenseService(), teamFor: (k) => team(per: 450));
      await _onlyMeal(t, 'breakfast');
      await tapMeal(t, 'lunch');
      await tapMeal(t, 'dinner');
      await t.enterText(amountField, '1500');
      await t.pump();
      expect(t.widget<Text>(find.byKey(const Key('teamLimitTitle'))).data, 'Team limit exceeded by ₹150');
      expect(t.widget<Text>(find.byKey(const Key('teamLimitLimit'))).data, 'Breakfast + Lunch + Dinner limit for the team: 3 heads × ₹450 = ₹1350.');
    });

    testWidgets('a pool wider than the picked meals (a lunch bill already filed) is what the limit is named after', (t) async {
      await openForm(t, _FakeExpenseService(), teamFor: (k) => {...team(per: 300), 'meals': ['breakfast', 'lunch']});
      await _onlyMeal(t, 'breakfast');
      await t.enterText(amountField, '1000');
      await t.pump();
      expect(t.widget<Text>(find.byKey(const Key('teamLimitLimit'))).data, startsWith('Breakfast + Lunch limit for the team'));
    });

    testWidgets('saving a bill over the limit names every meal in the message', (t) async {
      final service = _FakeExpenseService()
        ..limitCheck = {
          'workId': 'b-Beena', 'meal': 'breakfast+lunch+dinner', 'meals': ['breakfast', 'lunch', 'dinner'], 'heads': 3, 'allowancePerHead': 450,
          'limit': 1350, 'alreadySpent': 0, 'thisAmount': 1500, 'total': 1500, 'over': 150, 'status': 'over',
        };
      await openForm(t, service);
      await _onlyMeal(t, 'breakfast');
      await tapMeal(t, 'lunch');
      await tapMeal(t, 'dinner');
      await t.enterText(amountField, '90');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      expect(find.textContaining('Saved — the team limit for breakfast + lunch + dinner is exceeded by ₹150'), findsOneWidget);
      expect(find.textContaining('3 heads × ₹450 = ₹1350'), findsOneWidget);
    });

    testWidgets('editing a combined bill opens with its meals picked, and saves them again', (t) async {
      final server = _Server()..expenses = [{..._food(1, meal: ''), 'meals': ['lunch', 'dinner'], 'amount': 80.0}];
      final service = _FakeExpenseService();
      await _open(t, server, role: 'artist', employeeId: 'e1', service: service);
      await _openExpenses(t);
      await t.tap(find.byTooltip('Edit this expense'));
      await t.pumpAndSettle();
      expect(selected(t), ['lunch', 'dinner']);
      await tapMeal(t, 'breakfast');
      await t.tap(find.text('SAVE CHANGES'));
      await t.pumpAndSettle();
      final u = service.updated.single;
      expect(u['meals'], ['breakfast', 'lunch', 'dinner']);
      expect(u['meal'], '');
      expect(u['id'], 'x1');
    });

    testWidgets('an older single-meal entry opens with its one meal picked and saves as one meal', (t) async {
      final server = _Server()..expenses = [{..._food(1), 'amount': 80.0}]; // meal: lunch, no meals list
      final service = _FakeExpenseService();
      await _open(t, server, role: 'artist', employeeId: 'e1', service: service);
      await _openExpenses(t);
      await t.tap(find.byTooltip('Edit this expense'));
      await t.pumpAndSettle();
      expect(selected(t), ['lunch']);
      await t.tap(find.text('SAVE CHANGES'));
      await t.pumpAndSettle();
      final u = service.updated.single;
      expect(u['meal'], 'lunch');
      expect(u['meals'], ['lunch']);
    });

    testWidgets('a non-food expense still files no meals', (t) async {
      final service = _FakeExpenseService();
      await openForm(t, service);
      await t.tap(find.byType(DropdownButtonFormField<String>).last);
      await t.pumpAndSettle();
      await t.tap(find.text('Travel').last);
      await t.pumpAndSettle();
      await t.enterText(amountField, '50');
      await t.tap(find.text('LOG EXPENSE'));
      await t.pumpAndSettle();
      final c = service.created.single;
      expect((c['category'], c['meal']), ('travel', ''));
      expect(c['meals'], isEmpty);
    });
  });

  group('what Accounts sees on a combined bill', () {
    final all3 = ['breakfast', 'lunch', 'dinner'];

    testWidgets('the card says every meal, which work it went under, and the travel distance to check the amount against', (t) async {
      final server = _Server()
        ..expenses = [
          {
            ..._food(0, meal: ''),
            'meals': all3,
            'amount': 450.0,
            'allocation': {
              'mode': 'last', 'counted': true, 'reason': 'Covers breakfast, lunch and dinner — put under the last work of the day.', 'flag': '', 'meal': '', 'meals': all3, 'mealAt': _utc(13, 30), 'total': 450,
              'shares': [
                {..._beena, 'amount': 450, 'travelDistanceKm': 280},
              ],
            },
          },
          // another work with no distance recorded
          {
            ..._food(1),
            'allocation': {
              'mode': 'time', 'counted': true, 'reason': 'Lunch at 1:30 PM — during this work.', 'flag': '', 'meal': 'lunch', 'mealAt': _utc(13, 30), 'total': 200,
              'shares': [_beena],
            },
          },
        ];
      await _open(t, server);
      await _openExpenses(t);
      expect(find.textContaining('Breakfast + Lunch + Dinner · 1:30 PM'), findsOneWidget);
      expect(find.text('LAST WORK'), findsOneWidget);
      expect(find.byKey(const Key('allocationDistance')), findsOneWidget, reason: 'only the work with a distance shows one');
      expect(t.widget<Text>(find.byKey(const Key('allocationDistance'))).data, 'Travel distance 280 km');
    });
  });
}
