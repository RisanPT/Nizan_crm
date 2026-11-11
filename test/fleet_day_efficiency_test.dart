import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/day_sheet.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/features/fleet/data/vehicle_categories.dart';
import 'package:nizan_crm/features/fleet/data/vehicle_efficiency.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/driver_add_expense_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fleet_day_sheet_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/vehicle_efficiency_sheet.dart';
import 'package:nizan_crm/features/fleet/controllers/vehicle_controller.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/vehicle_capacity_hint.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/vehicle_profile_fields.dart';
import 'package:nizan_crm/features/fleet/services/fuel_expense_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

// ── helpers ─────────────────────────────────────────────────────────────────

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode({'_id': 'e1', 'date': '2026-10-23T00:00:00.000Z', 'totalAmount': 10}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<Map<String, dynamic>> _sendExpense({String? bookingId, bool clearWork = false}) async {
  final adapter = _CaptureAdapter();
  final dio = Dio()..httpClientAdapter = adapter;
  await FuelExpenseService(dio).saveFuelExpense(
    vehicleId: 'v1',
    category: 'toll',
    date: DateTime(2026, 10, 23, 12),
    odometerKm: 0,
    liters: 0,
    totalAmount: 10,
    paymentMode: 'cash',
    station: '',
    notes: '',
    bookingId: bookingId,
    clearWork: clearWork,
  );
  return (adapter.last!.data as Map).cast<String, dynamic>();
}

FleetJob _job(String id, DateTime start, {dynamic vehicle = 'v1'}) => FleetJob(
      id: id,
      bookingNumber: 'BK-$id',
      vehicleId: vehicle,
      customerName: 'Client $id',
      service: 'Bridal',
      serviceStart: start,
      serviceEnd: start.add(const Duration(hours: 3)),
      assignedStaff: const [],
    );

Widget _expenseApp(List<FleetJob> jobs, {String? jobId}) => ProviderScope(
      overrides: [driverJobsProvider.overrideWith((ref) async => jobs)],
      child: MaterialApp(theme: AppTheme.lightTheme, home: DriverAddExpenseScreen(jobId: jobId)),
    );

/// A day sheet as the server sends it: two works (HQ → A → B → HQ), one direct
/// expense, one shared whole-day expense, and one expense with no work.
Map<String, dynamic> _sheetJson({bool variance = true}) => {
      'dayKey': '2026-10-23',
      'driver': {'id': 'd1', 'name': 'Ravi Driver', 'phone': ''},
      'hq': 'HiLITE Business Park, Kozhikode',
      'works': [
        {
          'id': 'w1', 'bookingNumber': 'BK-1', 'label': 'BK-1 · Asha', 'customerName': 'Asha', 'service': 'Bridal',
          'eventSlot': 'Morning', 'serviceStart': '2026-10-23T03:30:00.000Z', 'serviceEnd': '2026-10-23T06:30:00.000Z',
          'tripStatus': 'completed', 'startKm': 1000, 'endKm': 1012.4, 'trackedKm': 12.4, 'plannedKm': 10, 'located': true,
          'approximate': false,
          'vehicle': {'id': 'v1', 'name': 'Innova', 'registrationNumber': 'KL 11 AB 1234', 'category': 'xl', 'seats': 6},
          'team': {'count': 5, 'suggested': {'key': 'xl', 'label': 'XL (Innova / Ertiga type)', 'needsMultiple': false}, 'fits': true},
          'costs': {'total': 1650, 'direct': 1500, 'shared': 150, 'byCategory': {'fuel': 1500, 'toll': 150}},
        },
        {
          'id': 'w2', 'bookingNumber': 'BK-2', 'label': 'BK-2 · Meera', 'customerName': 'Meera', 'service': 'Party',
          'eventSlot': '', 'serviceStart': '2026-10-23T09:30:00.000Z', 'serviceEnd': '2026-10-23T12:30:00.000Z',
          'tripStatus': 'completed', 'startKm': 1012.4, 'endKm': 1030, 'trackedKm': 17.6, 'plannedKm': 50, 'located': true,
          'approximate': false,
          'vehicle': {'id': 'v1', 'name': 'Innova', 'registrationNumber': 'KL 11 AB 1234', 'category': 'xl', 'seats': 6},
          'team': {'count': 7, 'suggested': {'key': 'mpv', 'label': 'MPV', 'needsMultiple': false}, 'fits': false},
          'costs': {'total': 270, 'direct': 120, 'shared': 150, 'byCategory': {'food': 120, 'toll': 150}},
        },
      ],
      'plan': {
        'rule': 'multi_stop',
        'legs': [
          {'kind': 'out', 'from': 'HQ', 'to': 'BK-1 · Asha', 'km': 10, 'durationMin': 20, 'mirrored': false, 'note': ''},
          {'kind': 'between', 'from': 'BK-1 · Asha', 'to': 'BK-2 · Meera', 'km': 20, 'durationMin': 40, 'mirrored': false, 'note': ''},
          {'kind': 'return', 'from': 'BK-2 · Meera', 'to': 'HQ', 'km': 30, 'durationMin': 60, 'mirrored': false, 'note': ''},
        ],
        'plannedKm': 60,
        'plannedMin': 120,
        'approximate': false,
        'warnings': <String>[],
        'planError': '',
      },
      'distance': {
        'plannedKm': 60, 'returnKm': 30, 'plannedTrackedKm': 30, 'trackedKm': 30,
        'variance': variance ? {'km': 0, 'percent': 0} : null,
        'estimatedDayKm': 60,
      },
      'fuelEstimate': {'vehicleId': 'v1', 'unit': 'km/l', 'ratedMileage': 12, 'units': 5, 'basis': 'rated'},
      'expenses': [
        {
          'id': 'e1', 'category': 'fuel', 'amount': 1500, 'status': 'pending', 'date': '2026-10-23T03:30:00.000Z',
          'station': 'Shell', 'notes': '', 'billImage': '', 'liters': 20, 'odometerKm': 10000, 'vehicleName': 'KL 11 AB 1234',
          'bookingId': 'w1', 'mode': 'direct', 'reason': '', 'allocations': [{'bookingId': 'w1', 'amount': 1500}],
        },
        {
          'id': 'e2', 'category': 'toll', 'amount': 300, 'status': 'approved', 'date': '2026-10-23T02:30:00.000Z',
          'station': '', 'notes': '', 'billImage': '', 'liters': 0, 'odometerKm': 0, 'vehicleName': 'KL 11 AB 1234',
          'bookingId': null, 'mode': 'shared', 'reason': '',
          'allocations': [
            {'bookingId': 'w1', 'amount': 150},
            {'bookingId': 'w2', 'amount': 150},
          ],
        },
        {
          'id': 'e3', 'category': 'parking', 'amount': 90, 'status': 'pending', 'date': '2026-10-23T05:30:00.000Z',
          'station': '', 'notes': '', 'billImage': '', 'liters': 0, 'odometerKm': 0, 'vehicleName': '',
          'bookingId': 'gone', 'mode': 'unallocated', 'reason': 'The work it was for is no longer on this day.',
          'allocations': <Map<String, dynamic>>[],
        },
      ],
      'totals': {
        'amount': 1890,
        'byCategory': {'fuel': 1500, 'toll': 300, 'parking': 90},
        'shared': 300,
        'unallocated': 90,
      },
    };

Widget _daySheetApp(Map<String, dynamic> json, {bool driverMode = true}) => ProviderScope(
      overrides: [
        daySheetProvider.overrideWith((ref, q) async => DaySheet.fromJson(json)),
        employeesProvider.overrideWith((ref) async => <Employee>[]),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: FleetDaySheetScreen(driverMode: driverMode)),
      ),
    );

void main() {
  group('vehicle categories (mirror of the backend list)', () {
    test('suggests the smallest category that takes the team', () {
      String key(int n) => suggestVehicleCategory(n).category.key;
      expect(key(0), 'sedan');
      expect(key(4), 'sedan');
      expect(key(5), 'xl');
      expect(key(6), 'xl');
      expect(key(7), 'mpv');
      expect(key(8), 'tempo_traveller');
      expect(key(12), 'tempo_traveller');
      expect(suggestVehicleCategory(12).needsMultiple, isFalse);
      expect(suggestVehicleCategory(13).needsMultiple, isTrue);
    });

    test('unknown capacity is "can\'t say", not "fits"', () {
      expect(seatsFit(0, 3), isNull);
      expect(seatsFit(4, 4), isTrue);
      expect(seatsFit(4, 5), isFalse);
      expect(defaultSeatsFor('mpv'), 7);
      expect(defaultSeatsFor('nope'), 0);
    });

    test('labels and units', () {
      expect(vehicleCategoryShortLabel('sedan'), 'Sedan');
      expect(vehicleCategoryShortLabel('xl'), 'XL');
      expect(vehicleCategoryShortLabel(''), '');
      expect(mileageUnit('petrol'), 'km/l');
      expect(mileageUnit('cng'), 'km/kg');
      expect(mileageUnit('electric'), 'km/kWh');
      expect(fuelQuantityUnit('cng'), 'kg');
    });
  });

  group('Vehicle / VehicleProfileForm', () {
    test('new fields are read; an older payload without them still parses', () {
      final v = Vehicle.fromJson({
        '_id': 'v1', 'name': 'Innova', 'registrationNumber': 'KL 1', 'category': 'xl',
        'seats': 6, 'ratedMileage': 12.5, 'tankCapacity': 55,
      });
      expect((v.category, v.seats, v.ratedMileage, v.tankCapacity), ('xl', 6, 12.5, 55.0));
      final old = Vehicle.fromJson({'_id': 'v2', 'name': 'Old'});
      expect((old.category, old.seats, old.ratedMileage, old.tankCapacity), ('', 0, 0.0, 0.0));
    });

    test('a new vehicle with nothing typed sends nothing (the server fills in the usual seats)', () {
      final f = VehicleProfileForm(null);
      expect(f.validate(), isNull);
      expect(f.seatsValue, isNull);
      expect(f.ratedMileageValue, isNull);
      expect(f.tankCapacityValue, isNull);
      f.dispose();
    });

    test('clearing a value an existing vehicle had sends 0 (clears it), not "leave as is"', () {
      final f = VehicleProfileForm(Vehicle.fromJson({
        '_id': 'v', 'name': 'N', 'seats': 6, 'ratedMileage': 12, 'tankCapacity': 55,
      }));
      expect(f.ratedMileageValue, 12.0);
      f.ratedMileage.clear();
      f.seats.clear();
      f.tankCapacity.clear();
      expect((f.seatsValue, f.ratedMileageValue, f.tankCapacityValue), (0, 0.0, 0.0));
      f.dispose();
    });

    test('bad input gets a plain message', () {
      final f = VehicleProfileForm(null);
      f.seats.text = '70';
      expect(f.validate(), contains('Seats'));
      f.seats.text = '4';
      f.ratedMileage.text = '12.x';
      expect(f.validate(), contains('Rated mileage'));
      f.ratedMileage.text = '12.5';
      f.tankCapacity.text = '5000';
      expect(f.validate(), contains('Tank capacity'));
      f.tankCapacity.text = '45';
      expect(f.validate(), isNull);
      expect(f.ratedMileageValue, 12.5);
      f.dispose();
    });
  });

  group('fuel efficiency parsing', () {
    test('full detail and the light fleet-list form both parse', () {
      final e = VehicleEfficiency.fromJson({
        'vehicleId': 'v1', 'name': 'Dzire', 'registrationNumber': 'KL 2', 'unit': 'km/l', 'rated': 20, 'actual': 15,
        'vsRatedPercent': 75, 'status': 'watch', 'method': 'fill_ups', 'confidence': 'medium', 'intervalsUsed': 2,
        'kmTracked': 600, 'litresUsed': 40, 'costPerKm': 6.83, 'ratedRangeKm': 740, 'actualRangeKm': 555,
        'monthly': [
          {'month': '2026-09', 'liters': 70, 'spend': 7100, 'km': 600, 'efficiency': 15},
        ],
        'intervals': [
          {'date': '2026-09-15T03:30:00.000Z', 'fromKm': 5300, 'toKm': 5600, 'km': 300, 'liters': 20, 'efficiency': 15, 'suspect': false},
        ],
      });
      expect(e.actual, 15);
      expect(e.status, 'watch');
      expect(e.monthly.single.efficiency, 15);
      expect(e.intervals.single.suspect, isFalse);

      final fleet = FleetEfficiency.fromJson({
        'days': 365,
        'summary': {'vehicles': 2, 'measured': 1, 'poor': 0, 'watch': 1, 'good': 0, 'missingRatedMileage': 1},
        'items': [
          {'vehicleId': 'v1', 'status': 'watch', 'actual': 15},
          {'vehicleId': 'v2', 'status': 'unknown'},
        ],
      });
      expect(fleet.forVehicle('v1')!.actual, 15);
      expect(fleet.forVehicle('v2')!.hasFigure, isFalse);
      expect(fleet.forVehicle('zzz'), isNull);
      expect(fleet.missingRatedMileage, 1);
    });
  });

  group('expense ↔ work link', () {
    test('populated work, bare id and none all parse', () {
      final populated = FuelExpense.fromJson({
        '_id': 'e', 'date': '2026-10-23T00:00:00.000Z', 'totalAmount': 5, 'dayKey': '2026-10-23',
        'bookingId': {'_id': 'b1', 'bookingNumber': 'BK-9', 'customerName': 'Asha'},
      });
      expect((populated.bookingId, populated.workLabel, populated.dayKey), ('b1', 'BK-9 · Asha', '2026-10-23'));
      final bare = FuelExpense.fromJson({'_id': 'e', 'date': '2026-10-23T00:00:00.000Z', 'totalAmount': 5, 'bookingId': 'b2'});
      expect((bare.bookingId, bare.workLabel), ('b2', ''));
      final none = FuelExpense.fromJson({'_id': 'e', 'date': '2026-10-23T00:00:00.000Z', 'totalAmount': 5, 'bookingId': null});
      expect(none.bookingId, isNull);
    });

    test('the request carries the work only when asked to', () async {
      expect((await _sendExpense(bookingId: 'b1'))['bookingId'], 'b1');
      expect((await _sendExpense()).containsKey('bookingId'), isFalse, reason: 'editing must not unlink a work by accident');
      final cleared = await _sendExpense(clearWork: true);
      expect(cleared.containsKey('bookingId'), isTrue);
      expect(cleared['bookingId'], isNull);
    });
  });

  group('driver add-expense screen', () {
    final day = DateTime(2026, 10, 23);
    final tripA = _job('a', day.add(const Duration(hours: 9)));
    final tripB = _job('b', day.add(const Duration(hours: 15)));
    final otherDay = _job('c', day.add(const Duration(days: 1, hours: 9)));

    testWidgets('fuel asks for litres and the odometer; other categories do not', (tester) async {
      await tester.pumpWidget(_expenseApp([tripA]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('litersField')), findsOneWidget);
      expect(find.byKey(const Key('odometerField')), findsOneWidget);

      await tester.tap(find.byKey(const Key('categoryPicker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toll').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('litersField')), findsNothing);
      expect(find.byKey(const Key('odometerField')), findsNothing);
    });

    testWidgets('a day with two works offers "whole day"; a day with one does not', (tester) async {
      await tester.pumpWidget(_expenseApp([tripA, tripB, otherDay]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tripPicker')));
      await tester.pumpAndSettle();
      // only the day with two works offers it (the other day has one)
      expect(find.textContaining('whole day (shared)'), findsOneWidget);
      // No client names anywhere in the labels.
      expect(find.textContaining('Client'), findsNothing);
    });

    Future<void> pickWholeDay(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('tripPicker')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('whole day (shared)'));
      await tester.pumpAndSettle();
    }

    testWidgets('picking whole day files it under the day — the works are NOT shown to the driver', (tester) async {
      await tester.pumpWidget(_expenseApp([tripA, tripB]));
      await tester.pumpAndSettle();
      await pickWholeDay(tester);
      expect(find.textContaining('Filed under the whole day. Accounts will see that day\'s works and share it equally.'), findsOneWidget);
      // no works list, no artists, no split card
      await tester.enterText(find.byType(TextField).first, '3000');
      await tester.pumpAndSettle();
      expect(find.textContaining('Shared equally across'), findsNothing);
      expect(find.textContaining('÷'), findsNothing);
      expect(find.textContaining('Artist'), findsNothing);
      expect(find.textContaining('BK-b'), findsNothing); // the 2nd trip's number is not listed anywhere but the picker
    });

    testWidgets('a single work picked: no split card, just the hint', (tester) async {
      await tester.pumpWidget(_expenseApp([tripA, tripB]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tripPicker')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('BK-a').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Shared equally'), findsNothing);
      expect(find.textContaining('Charged to this work only'), findsOneWidget);
    });

    testWidgets('opened from inside a trip with two works that day: a "whole day" switch is offered', (tester) async {
      await tester.pumpWidget(_expenseApp([tripA, tripB], jobId: 'a'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wholeDaySwitch')), findsOneWidget);
    });

    testWidgets('the whole-day switch just says it is filed under the day', (tester) async {
      await tester.pumpWidget(_expenseApp([tripA, tripB], jobId: 'a'));
      await tester.pumpAndSettle();
      expect(find.text('Charged to this work only.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wholeDaySwitch')));
      await tester.pumpAndSettle();
      expect(find.text('Filed under the whole day — Accounts shares it equally.'), findsOneWidget);
      expect(find.textContaining('Artist'), findsNothing);
    });

    testWidgets('a lone trip has no whole-day switch', (tester) async {
      await tester.pumpWidget(_expenseApp([tripA, otherDay], jobId: 'a'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wholeDaySwitch')), findsNothing);
    });
  });

  group('vehicle capacity hint', () {
    Widget host(Widget child) => MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child));
    final innova = Vehicle.fromJson({'_id': 'v', 'name': 'Innova', 'category': 'xl', 'seats': 6});

    testWidgets('no vehicle yet → suggests the category', (tester) async {
      await tester.pumpWidget(host(const VehicleCapacityHint(people: 5, vehicle: null)));
      expect(find.textContaining('Suits a XL'), findsOneWidget);
    });

    testWidgets('fits / does not fit / seats not recorded', (tester) async {
      await tester.pumpWidget(host(VehicleCapacityHint(people: 5, vehicle: innova)));
      expect(find.textContaining('fits'), findsOneWidget);
      await tester.pumpWidget(host(VehicleCapacityHint(people: 7, vehicle: innova)));
      expect(find.textContaining('won\'t fit'), findsOneWidget);
      expect(find.textContaining('MPV'), findsOneWidget);
      await tester.pumpWidget(host(VehicleCapacityHint(people: 3, vehicle: Vehicle.fromJson({'_id': 'v', 'name': 'Swift'}))));
      expect(find.textContaining('seat count isn\'t recorded'), findsOneWidget);
    });

    testWidgets('an empty team shows nothing', (tester) async {
      await tester.pumpWidget(host(VehicleCapacityHint(people: 0, vehicle: innova)));
      expect(find.byType(Text), findsNothing);
    });

    test('team size counts each person once and skips the driver', () {
      BookingAssignment s(String id, String roleType) =>
          BookingAssignment(employeeId: id, artistName: id, role: '', type: '', roleType: roleType);
      expect(teamSizeOf([s('a', 'lead'), s('b', 'assistant'), s('b', 'assistant'), s('d', 'driver'), s('', 'assistant')]), 2);
    });
  });

  group('fits a phone screen (360 px wide) with no overflow', () {
    // 360 px wide (a small phone), but tall enough that every row of a long
    // list is built and laid out, so a hidden overflow can't slip through.
    void phone(WidgetTester t) {
      t.view.physicalSize = const Size(1080, 9000);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
    }

    final innova = Vehicle.fromJson({
      '_id': 'v1', 'name': 'Innova', 'registrationNumber': 'KL 11 AB 1234', 'brand': 'Toyota', 'category': 'xl',
      'seats': 6, 'fuelType': 'diesel', 'ratedMileage': 12, 'tankCapacity': 55,
    });

    Map<String, dynamic> effJson({bool figure = true, bool suspect = true}) => {
          'vehicleId': 'v1', 'name': 'Innova', 'registrationNumber': 'KL 11 AB 1234', 'unit': 'km/l',
          'fuelType': 'diesel', 'category': 'xl', 'seats': 6,
          'rated': 12, 'actual': figure ? 10.8 : null, 'vsRatedPercent': figure ? 90 : null,
          'status': figure ? 'good' : 'unknown', 'method': figure ? 'fill_ups' : 'none', 'confidence': figure ? 'medium' : 'none',
          'fillUpsUsed': figure ? 3 : 0, 'intervalsUsed': figure ? 2 : 0, 'suspectIntervals': suspect ? 1 : 0,
          'kmTracked': 600, 'litresUsed': 55.5, 'costPerKm': 8.25, 'avgPricePerUnit': 92.4, 'fuelSpend': 18450, 'fillCount': 4,
          'lastFillDate': '2026-10-20T03:30:00.000Z', 'tankCapacity': 55, 'ratedRangeKm': 660, 'actualRangeKm': 594,
          'monthly': [
            {'month': '2026-10', 'liters': 120.5, 'spend': 11000, 'km': 800.5, 'efficiency': 10.8},
            {'month': '2026-09', 'liters': 70, 'spend': 7450, 'km': 600, 'efficiency': 9.1},
          ],
          'intervals': [
            {'date': '2026-10-20T03:30:00.000Z', 'fromKm': 12300, 'toKm': 12650, 'km': 350, 'liters': 32.4, 'efficiency': 10.8, 'suspect': false},
            if (suspect)
              {'date': '2026-10-10T03:30:00.000Z', 'fromKm': 12300, 'toKm': 19999, 'km': 7699, 'liters': 30, 'efficiency': 256.6, 'suspect': true},
          ],
        };

    Future<void> openSheet(WidgetTester t, Map<String, dynamic> json) async {
      await t.pumpWidget(ProviderScope(
        overrides: [
          vehicleEfficiencyProvider.overrideWith((ref, id) async => VehicleEfficiency.fromJson(json)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => showVehicleEfficiencySheet(context, innova), child: const Text('open')),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets('efficiency sheet with a measured figure, trend and a suspect reading', (tester) async {
      phone(tester);
      await openSheet(tester, effJson());
      expect(find.text('10.8'), findsOneWidget);
      expect(find.text('GOOD'), findsOneWidget);
      expect(find.textContaining('90% of rated'), findsOneWidget);
      expect(find.textContaining('Measured from 3 fill-ups'), findsOneWidget);
      expect(find.textContaining('left out of the average'), findsOneWidget);
      expect(find.text('Oct 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('efficiency sheet with no figure explains what to do', (tester) async {
      phone(tester);
      await openSheet(tester, effJson(figure: false, suspect: false));
      expect(find.textContaining('Not enough to work out mileage yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('efficiency sheet for a vehicle with no rated mileage says how to add it', (tester) async {
      phone(tester);
      final json = effJson(suspect: false)..['rated'] = null..['vsRatedPercent'] = null..['status'] = 'unknown';
      await openSheet(tester, json);
      expect(find.textContaining('No rated mileage is set'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('vehicle form fields inside a dialog', (tester) async {
      phone(tester);
      final form = VehicleProfileForm(innova);
      addTearDown(form.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AlertDialog(
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: VehicleProfileFields(form: form, fuelType: 'diesel', onChanged: () {}),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vehicleSeats')), findsOneWidget);
      expect(find.text('Rated mileage (km/l)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the category fills in its usual seats, unless the user typed their own', (tester) async {
      phone(tester);
      final form = VehicleProfileForm(null);
      addTearDown(form.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => VehicleProfileFields(form: form, fuelType: 'petrol', onChanged: () => setState(() {})),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('vehicleCategory')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('MPV').last);
      await tester.pumpAndSettle();
      expect(form.category, 'mpv');
      expect(form.seats.text, '7');

      // the user sets their own seat count; a later category change leaves it alone
      form.seats.text = '9';
      await tester.tap(find.byKey(const Key('vehicleCategory')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Sedan').last);
      await tester.pumpAndSettle();
      expect(form.category, 'sedan');
      expect(form.seats.text, '9');
    });

    testWidgets('driver add-expense with the fuel fields', (tester) async {
      phone(tester);
      final day = DateTime(2026, 10, 23);
      await tester.pumpWidget(_expenseApp([_job('a', day.add(const Duration(hours: 9))), _job('b', day.add(const Duration(hours: 15)))]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('litersField')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('day sheet — driver view and manager view', (tester) async {
      phone(tester);
      await tester.pumpWidget(_daySheetApp(_sheetJson()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(_daySheetApp(_sheetJson(), driverMode: false));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('day sheet', () {
    test('parses what the server sends', () {
      final s = DaySheet.fromJson(_sheetJson());
      expect(s.driverName, 'Ravi Driver');
      expect(s.plan.rule, 'multi_stop');
      expect(s.plan.legs.map((l) => l.kind), ['out', 'between', 'return']);
      expect(s.plan.legs.map((l) => l.km), [10, 20, 30]);
      expect(s.distance.returnKm, 30);
      expect(s.distance.variance!.percent, 0);
      expect(s.works.last.team.fits, isFalse);
      expect(s.workById('w2')!.costs.shared, 150, reason: 'equal shares, however far each work is');

      expect(s.expenses.map((e) => e.mode), ['direct', 'shared', 'unallocated']);
      expect(s.expenses[1].allocations.map((a) => a.amount), [150, 150]);
      expect(s.totals.unallocated, 90);
      expect(s.fuelEstimate!.units, 5);
    });

    testWidgets('shows the route HQ → works → HQ, the odometer comparison and the expenses', (tester) async {
      await tester.pumpWidget(_daySheetApp(_sheetJson()));
      await tester.pumpAndSettle();

      expect(find.text('My day'), findsOneWidget);
      // each leg of the route with its distance (the arrow between the names is an icon)
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNWidgets(3));
      expect(find.text('10 km'), findsOneWidget);
      expect(find.text('20 km'), findsOneWidget);
      expect(find.text('30 km'), findsOneWidget);
      expect(find.text('60 km  ·  2 h 0 min'), findsOneWidget);
      // the way home isn't on the odometer — said plainly
      expect(find.textContaining('the way back to'), findsOneWidget);
      expect(find.textContaining('Odometer 30 km matches the plan (30 km)'), findsOneWidget);
      // expenses under the works
      expect(find.textContaining('Under BK-1 · Asha'), findsOneWidget);
      expect(find.textContaining('Whole day · shared equally: ₹150 to each of 2 works'), findsOneWidget);
      // artists are an ACCOUNTS detail: nothing about them on the fleet day sheet
      expect(find.textContaining('Artist'), findsNothing);
      expect(find.textContaining('artist'), findsNothing);
      expect(find.textContaining('no longer on this day'), findsWidgets);
      // vehicle too small for the second team
      expect(find.textContaining('this vehicle has 6 seats'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single work reads as there-and-back', (tester) async {
      final json = _sheetJson(variance: false);
      json['works'] = [(json['works'] as List).first];
      (json['plan'] as Map)['rule'] = 'round_trip';
      (json['plan'] as Map)['legs'] = [
        {'kind': 'out', 'from': 'HQ', 'to': 'BK-1 · Asha', 'km': 10, 'durationMin': 20, 'mirrored': false, 'note': ''},
        {'kind': 'return', 'from': 'BK-1 · Asha', 'to': 'HQ', 'km': 10, 'durationMin': 20, 'mirrored': true, 'note': ''},
      ];
      (json['plan'] as Map)['plannedKm'] = 20;
      await tester.pumpWidget(_daySheetApp(json));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 × the one-way distance'), findsOneWidget);
      expect(find.text('same as the way out'), findsOneWidget);
    });

    testWidgets('a day with nothing on it says so', (tester) async {
      final json = _sheetJson();
      json['works'] = <Map<String, dynamic>>[];
      json['expenses'] = <Map<String, dynamic>>[];
      (json['plan'] as Map)['legs'] = <Map<String, dynamic>>[];
      await tester.pumpWidget(_daySheetApp(json));
      await tester.pumpAndSettle();
      expect(find.text('No works on this day.'), findsOneWidget);
    });

    testWidgets('a route that could not be calculated shows why, not a wrong number', (tester) async {
      final json = _sheetJson(variance: false);
      (json['plan'] as Map)
        ..['planError'] = 'Distance is not set up on the server (ORS_API_KEY is missing).'
        ..['legs'] = <Map<String, dynamic>>[]
        ..['plannedKm'] = 0;
      await tester.pumpWidget(_daySheetApp(json));
      await tester.pumpAndSettle();
      expect(find.textContaining('ORS_API_KEY'), findsOneWidget);
      expect(find.text('Planned km'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('manager must choose a driver first', (tester) async {
      await tester.pumpWidget(_daySheetApp(_sheetJson(), driverMode: false));
      await tester.pumpAndSettle();
      expect(find.text('Choose a driver to see their day.'), findsOneWidget);
      expect(find.byKey(const Key('daySheetDriver')), findsOneWidget);
    });
  });
}
