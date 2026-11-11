import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/accounts_fleet_expenses_screen.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_expense_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_price_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/vehicle_controller.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense_page.dart';
import 'package:nizan_crm/features/fleet/data/fuel_price.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fuel_expenses_screen.dart';
import 'package:nizan_crm/features/fleet/services/fuel_expense_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

// The two screens that list fuel expenses: the "Fuel prices" button (only for those who keep the
// prices), the bill's rate on each fill-up, and — on the fleet manager's form — the fill-in.

String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

FuelPrices _prices() => FuelPrices.fromJson({
  'items': [
    {
      '_id': 'p1',
      'fuelType': 'petrol',
      'unit': 'litre',
      'pricePerUnit': 110,
      'effectiveFrom': '2026-01-01',
      'note': '',
    },
    {
      '_id': 'd1',
      'fuelType': 'diesel',
      'unit': 'litre',
      'pricePerUnit': 96.5,
      'effectiveFrom': '2026-01-01',
      'note': '',
    },
  ],
  'current': {
    'petrol': {
      '_id': 'p1',
      'fuelType': 'petrol',
      'unit': 'litre',
      'pricePerUnit': 110,
      'effectiveFrom': '2026-01-01',
      'note': '',
    },
    'diesel': {
      '_id': 'd1',
      'fuelType': 'diesel',
      'unit': 'litre',
      'pricePerUnit': 96.5,
      'effectiveFrom': '2026-01-01',
      'note': '',
    },
    'cng': null,
    'electric': null,
  },
  'today': _today(),
  'tolerancePct': 10,
});

Map<String, dynamic> _fill(
  String id, {
  double liters = 40,
  double amount = 4400,
  Map<String, dynamic>? rateCheck,
  String driver = 'Ravi',
  String? date,
}) => {
  '_id': id,
  'category': 'fuel',
  'status': 'pending',
  'date': date ?? DateTime.now().toUtc().toIso8601String(),
  'dayKey': _today(),
  'totalAmount': amount,
  'liters': liters,
  'odometerKm': 0,
  'station': '',
  'notes': '',
  'paymentMode': 'cash',
  'billImage': 'https://x/bill.jpg',
  'vehicleId': {
    '_id': 'v1',
    'name': 'Innova',
    'registrationNumber': 'KL 11 AB 1234',
    'fuelType': 'petrol',
  },
  'driverId': {'_id': 'd_$driver', 'name': driver},
  'rateCheck': rateCheck,
};

Map<String, dynamic> _high() => {
  'status': 'high',
  'fuelType': 'petrol',
  'unit': 'litre',
  'rate': 130,
  'price': 110,
  'expected': 4400,
  'diff': 800,
  'diffPct': 18.2,
  'tolerancePct': 10,
};
Map<String, dynamic> _ok() => {
  'status': 'ok',
  'fuelType': 'petrol',
  'unit': 'litre',
  'rate': 110,
  'price': 110,
  'expected': 4400,
  'diff': 0,
  'diffPct': 0,
  'tolerancePct': 10,
};

AuthSession _session(String role) =>
    AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role);

void _size(WidgetTester t, {double w = 1400, double h = 3600}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

class _FakeFuelService extends FuelExpenseService {
  _FakeFuelService() : super(Dio());
  final saved = <Map<String, Object?>>[];

  @override
  Future<FuelExpense> saveFuelExpense({
    String? id,
    required String vehicleId,
    String? driverId,
    required String category,
    required DateTime date,
    required double odometerKm,
    required double liters,
    required double totalAmount,
    required String paymentMode,
    required String station,
    required String notes,
    String billImage = '',
    String? bookingId,
    bool clearWork = false,
  }) async {
    saved.add({
      'vehicleId': vehicleId,
      'category': category,
      'liters': liters,
      'totalAmount': totalAmount,
    });
    return FuelExpense.fromJson(
      _fill('n1', liters: liters, amount: totalAmount),
    );
  }
}

void main() {
  group('Accounts: Fleet Expenses', () {
    Widget app({String role = 'accounts'}) => ProviderScope(
      overrides: <Override>[
        accountsFuelExpensePageProvider.overrideWith((ref, q) async {
          final items = [
            FuelExpense.fromJson(
              _fill('hi', amount: 5200, rateCheck: _high(), driver: 'Hari'),
            ),
            FuelExpense.fromJson(_fill('ok', rateCheck: _ok(), driver: 'Omar')),
            FuelExpense.fromJson(_fill('none', driver: 'Nina')),
          ];
          return FuelExpensePage(
            items: items,
            page: 1,
            limit: 20,
            totalItems: items.length,
            totalPages: 1,
            summary: ExpenseSummary.fromJson({
              'byStatus': {
                'pending': {'count': 3, 'amount': 14000},
              },
              'shown': {'count': 3, 'amount': 14000},
              'byCategory': [
                {'category': 'fuel', 'count': 3, 'amount': 14000},
              ],
              'byDriver': <Map<String, dynamic>>[],
            }),
          );
        }),
        employeesProvider.overrideWith((ref) async => <Employee>[]),
        vehiclesProvider.overrideWith((ref) async => <Vehicle>[]),
        fuelPricesProvider.overrideWith((ref) async => _prices()),
        authSessionProvider.overrideWithValue(_session(role)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: AccountsFleetExpensesScreen()),
      ),
    );

    testWidgets(
      'a fill-up whose rate is off is called out; one that matches says so quietly; one with no check shows nothing',
      (t) async {
        _size(t);
        await t.pumpWidget(app());
        await t.pumpAndSettle();
        expect(find.byKey(const Key('rateCheckFlag')), findsOneWidget);
        expect(
          find.text('Rate ₹130/L · 18.2% above the ₹110/L price · ₹800 over'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('rateCheckOk')), findsOneWidget);
        expect(
          find.text('Rate ₹110/L · matches the ₹110/L price'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Accounts has a Fuel prices button, and it opens the prices', (
      t,
    ) async {
      _size(t);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.byKey(const Key('fuelPricesButton')), findsOneWidget);
      await t.tap(find.byKey(const Key('fuelPricesButton')));
      await t.pumpAndSettle();
      expect(find.text('Fuel prices'), findsWidgets);
      expect(find.text('₹110 per litre'), findsOneWidget);
      expect(find.text('₹96.50 per litre'), findsOneWidget);
    });

    testWidgets('someone who does not keep the prices has no such button', (
      t,
    ) async {
      _size(t);
      await t.pumpWidget(app(role: 'sales'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('fuelPricesButton')), findsNothing);
      expect(
        find.byKey(const Key('rateCheckFlag')),
        findsOneWidget,
        reason: 'the list itself is unchanged',
      );
    });
  });

  group('the fleet manager\'s Fuel Expenses', () {
    final vehicles = [
      Vehicle.fromJson({
        '_id': 'v1',
        'name': 'Innova',
        'registrationNumber': 'KL 11 AB 1234',
        'fuelType': 'petrol',
      }),
      Vehicle.fromJson({
        '_id': 'v2',
        'name': 'Tempo',
        'registrationNumber': 'KL 11 CD 5678',
        'fuelType': 'diesel',
      }),
    ];

    Widget app(
      _FakeFuelService svc, {
      String role = 'fleet_manager',
      List<Map<String, dynamic>>? rows,
      FuelPrices? prices,
      Future<FuelPrices>? pricesLater,
    }) => ProviderScope(
      overrides: <Override>[
        fuelExpensesProvider.overrideWith(
          (ref) async => [
            for (final r
                in rows ??
                    [
                      _fill('hi', amount: 5200, rateCheck: _high()),
                      _fill('ok', rateCheck: _ok()),
                    ])
              FuelExpense.fromJson(r),
          ],
        ),
        vehiclesProvider.overrideWith((ref) async => vehicles),
        employeesProvider.overrideWith((ref) async => <Employee>[]),
        fuelExpenseServiceProvider.overrideWithValue(svc),
        fuelPricesProvider.overrideWith(
          (ref) => pricesLater ?? Future.value(prices ?? _prices()),
        ),
        authSessionProvider.overrideWithValue(_session(role)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: FuelExpensesScreen()),
      ),
    );

    testWidgets(
      'only a rate that is off is called out on the list (a matching one adds no noise)',
      (t) async {
        _size(t);
        await t.pumpWidget(app(_FakeFuelService()));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('rateCheckFlag')), findsOneWidget);
        expect(find.byKey(const Key('rateCheckOk')), findsNothing);
      },
    );

    testWidgets('…on a phone too', (t) async {
      _size(t, w: 390, h: 2400);
      await t.pumpWidget(app(_FakeFuelService()));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('rateCheckFlag')), findsOneWidget);
    });

    testWidgets(
      'the fleet manager has a Fuel prices button; a driver-like role does not',
      (t) async {
        _size(t);
        await t.pumpWidget(app(_FakeFuelService()));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('fuelPricesButton')), findsOneWidget);
        await t.pumpWidget(app(_FakeFuelService(), role: 'driver'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('fuelPricesButton')), findsNothing);
      },
    );

    group('the add form', () {
      final amountBox = find.widgetWithText(TextField, 'Total amount');
      final litresBox = find.widgetWithText(TextField, 'Liters');
      String amountText(WidgetTester t) =>
          t.widget<TextField>(amountBox).controller!.text;

      Future<void> openForm(
        WidgetTester t,
        _FakeFuelService svc, {
        FuelPrices? prices,
        Future<FuelPrices>? pricesLater,
      }) async {
        _size(t, h: 4000);
        await t.pumpWidget(app(svc, prices: prices, pricesLater: pricesLater));
        await t.pumpAndSettle();
        await t.tap(find.text('Add Expense'));
        await t.pumpAndSettle();
      }

      Future<void> pickVehicle(WidgetTester t, String name) async {
        await t.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'Vehicle'),
        );
        await t.pumpAndSettle();
        await t.tap(find.textContaining(name).last);
        await t.pumpAndSettle();
      }

      testWidgets(
        'with a vehicle chosen, typing the litres fills the amount in from the price, and the hint names it',
        (t) async {
          await openForm(t, _FakeFuelService());
          await pickVehicle(t, 'Innova');
          await t.enterText(litresBox, '40');
          await t.pump();
          expect(amountText(t), '4400');
          expect(
            find.text(
              "Today's petrol price: ₹110/litre — the amount fills in from the litres",
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'the price follows the vehicle: a diesel one fills in the diesel price',
        (t) async {
          await openForm(t, _FakeFuelService());
          await pickVehicle(t, 'Innova');
          await t.enterText(litresBox, '10');
          await t.pump();
          expect(amountText(t), '1100');
          await pickVehicle(t, 'Tempo');
          expect(
            amountText(t),
            '965',
            reason: 'changing the vehicle re-calculates what the app filled in',
          );
        },
      );

      testWidgets(
        'a number typed in the amount box is never overwritten, and the hint checks it',
        (t) async {
          await openForm(t, _FakeFuelService());
          await pickVehicle(t, 'Innova');
          await t.enterText(amountBox, '5200');
          await t.enterText(litresBox, '40');
          await t.pump();
          expect(amountText(t), '5200');
          expect(find.byKey(const Key('fuelRateWarning')), findsOneWidget);
        },
      );

      testWidgets('no vehicle yet, or no price: nothing is filled in', (
        t,
      ) async {
        await openForm(t, _FakeFuelService());
        await t.enterText(litresBox, '40');
        await t.pump();
        expect(amountText(t), '');
        expect(find.byKey(const Key('fuelRateHint')), findsNothing);
      });

      testWidgets(
        'the prices arriving after the litres were typed still fill in',
        (t) async {
          final later = Completer<FuelPrices>();
          await openForm(t, _FakeFuelService(), pricesLater: later.future);
          await pickVehicle(t, 'Innova');
          await t.enterText(litresBox, '40');
          await t.pump();
          expect(amountText(t), '', reason: 'no prices yet');
          later.complete(_prices());
          await t.pump();
          await t.pump();
          expect(amountText(t), '4400');
        },
      );
    });
  });
}
