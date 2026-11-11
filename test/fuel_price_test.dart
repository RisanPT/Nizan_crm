import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_expense_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_price_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/features/fleet/data/fuel_price.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/driver_add_expense_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/bill_attachment_field.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fuel_price_manager.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fuel_rate_widgets.dart';
import 'package:nizan_crm/features/fleet/services/fuel_expense_service.dart';
import 'package:nizan_crm/features/fleet/services/fuel_price_service.dart';

// Fuel prices kept by hand, the amount filled in from litres × price, and the bill (rate) check.
// The arithmetic is the same as the server's (backend tests/fuelPrice.test.js), case for case.

const _today = '2026-10-23';

Map<String, dynamic> _row(
  String id,
  String fuel,
  num price,
  String from, {
  String note = '',
}) => {
  '_id': id,
  'fuelType': fuel,
  'unit': fuelUnit(fuel),
  'pricePerUnit': price,
  'effectiveFrom': from,
  'note': note,
};

FuelPrices _prices(List<Map<String, dynamic>> items, {String today = _today}) {
  Map<String, dynamic>? latest(String fuel) {
    final started =
        items
            .where(
              (r) =>
                  r['fuelType'] == fuel &&
                  (r['effectiveFrom'] as String).compareTo(today) <= 0,
            )
            .toList()
          ..sort(
            (a, b) => (b['effectiveFrom'] as String).compareTo(
              a['effectiveFrom'] as String,
            ),
          );
    return started.firstOrNull;
  }

  return FuelPrices.fromJson({
    'items': items,
    'current': {
      for (final f in ['petrol', 'diesel', 'cng', 'electric']) f: latest(f),
    },
    'today': today,
    'tolerancePct': 10,
  });
}

class _Capture implements HttpClientAdapter {
  RequestOptions? last;
  final Object body;
  final int status;
  _Capture(this.body, {this.status = 200});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// An in-memory price table: what the screens asked it to do, and the answers.
class _FakePriceService extends FuelPriceService {
  _FakePriceService(List<Map<String, dynamic>> rows)
    : rows = [for (final r in rows) FuelPriceRow.fromJson(r)],
      super(Dio());

  List<FuelPriceRow> rows;
  final calls = <String>[];
  Map<String, dynamic>? lastBody;
  Object? failWith;
  int _next = 100;

  List<Map<String, dynamic>> get _json => [
    for (final r in rows)
      _row(r.id, r.fuelType, r.pricePerUnit, r.effectiveFrom, note: r.note),
  ];

  @override
  Future<FuelPrices> list() async => _prices(_json);

  @override
  Future<FuelPriceRow> create(FuelPriceRow row) async {
    calls.add('create');
    lastBody = row.toBody();
    if (failWith != null) throw failWith!;
    final made = FuelPriceRow(
      id: 'n${_next++}',
      fuelType: row.fuelType,
      pricePerUnit: row.pricePerUnit,
      effectiveFrom: row.effectiveFrom,
      note: row.note,
    );
    rows = [...rows, made];
    return made;
  }

  @override
  Future<FuelPriceRow> update(String id, FuelPriceRow row) async {
    calls.add('update $id');
    lastBody = row.toBody();
    if (failWith != null) throw failWith!;
    final next = FuelPriceRow(
      id: id,
      fuelType: row.fuelType,
      pricePerUnit: row.pricePerUnit,
      effectiveFrom: row.effectiveFrom,
      note: row.note,
    );
    rows = [for (final r in rows) r.id == id ? next : r];
    return next;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    if (failWith != null) throw failWith!;
    rows = [
      for (final r in rows)
        if (r.id != id) r,
    ];
  }
}

Widget _host(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester t, Widget w, {double width = 1100}) async {
  t.view.physicalSize = Size(width, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  // a fresh tree each time, so nothing (a provider's last answer, a box's text) carries over
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(w);
  await t.pumpAndSettle();
}

final _defaults = [
  _row('p1', 'petrol', 100, '2026-01-01'),
  _row('p2', 'petrol', 105.45, '2026-10-01', note: 'Kerala'),
  _row('p3', 'petrol', 112, '2026-12-01'),
  _row('d1', 'diesel', 96.5, '2026-01-01'),
];

void main() {
  group('the prices', () {
    test('parse: rows, today\'s price per fuel, the day and the tolerance', () {
      final p = _prices(_defaults);
      expect(p.items, hasLength(4));
      expect((p.today, p.tolerancePct), (_today, 10.0));
      expect(p.current['petrol']!.pricePerUnit, 105.45);
      expect(p.current['diesel']!.pricePerUnit, 96.5);
      expect((p.current['cng'], p.current['electric']), (null, null));
      expect(p.items.first.unit, 'litre');
      expect(p.isEmpty, isFalse);
      expect(FuelPrices.fromJson({}).isEmpty, isTrue);
    });

    test('the price in force on a day is the latest that has started', () {
      final p = _prices(_defaults);
      expect(p.priceOn('petrol', '2026-03-10')!.pricePerUnit, 100);
      expect(
        p.priceOn('petrol', '2026-10-01')!.pricePerUnit,
        105.45,
        reason: 'the start day itself counts',
      );
      expect(p.priceOn('petrol', '2026-09-30')!.pricePerUnit, 100);
      expect(
        p.priceOn('petrol', '2026-10-23')!.pricePerUnit,
        105.45,
        reason: 'a December price has not started',
      );
      expect(p.priceOn('petrol', '2027-01-01')!.pricePerUnit, 112);
    });

    test(
      'before the first price, or for a fuel with none: no price, nothing guessed',
      () {
        final p = _prices(_defaults);
        expect(p.priceOn('petrol', '2025-12-31'), isNull);
        expect(p.priceOn('cng', '2026-10-23'), isNull);
      },
    );

    test('litres × price is the amount to fill in, to the paisa', () {
      final p = _prices(_defaults);
      expect(p.suggestAmount('petrol', _today, 40), 4218.0);
      expect(p.suggestAmount('petrol', _today, 40.35), 4254.91);
      expect(p.suggestAmount('diesel', _today, 10), 965.0);
    });

    test('nothing to fill in without litres or a price', () {
      final p = _prices(_defaults);
      expect(p.suggestAmount('petrol', _today, 0), isNull);
      expect(p.suggestAmount('petrol', _today, -2), isNull);
      expect(p.suggestAmount('cng', _today, 10), isNull);
      expect(p.suggestAmount('petrol', '2025-01-01', 10), isNull);
    });

    test(
      'a vehicle\'s fuel finds its price: a hybrid runs on petrol, "other" has none',
      () {
        for (final t in ['petrol', 'diesel', 'cng', 'electric']) {
          expect(fuelPriceTypeOf(t), t);
        }
        expect(fuelPriceTypeOf('hybrid'), 'petrol');
        expect(fuelPriceTypeOf('Diesel'), 'diesel');
        for (final none in ['other', '', null, 'hydrogen']) {
          expect(fuelPriceTypeOf(none), isNull, reason: '$none');
        }
      },
    );

    test('a price as written in a box', () {
      expect(priceText(105), '105');
      expect(priceText(105.45), '105.45');
      expect(priceText(104.5), '104.50');
    });
  });

  group('the bill check (same numbers as the server)', () {
    RateCheck check(double qty, double amt, double? price, {double tol = 10}) =>
        RateCheck.compute(
          fuelType: 'petrol',
          quantity: qty,
          amount: amt,
          price: price,
          tolerancePct: tol,
        );

    test('a rate close to the price is fine', () {
      final r = check(40, 4218, 105.45);
      expect(
        (r.status, r.rate, r.price, r.expected, r.diff, r.diffPct, r.isFlagged),
        ('ok', 105.45, 105.45, 4218.0, 0.0, 0.0, false),
      );
      expect(check(40, 4218 * 1.05, 105.45).status, 'ok');
      expect(check(40, 4218 * 0.95, 105.45).status, 'ok');
    });

    test('well above the price → high, with how far', () {
      final r = check(40, 5200, 105.45);
      expect(
        (
          r.status,
          r.rate,
          r.expected,
          r.diff,
          r.diffPct,
          r.isHigh,
          r.isFlagged,
        ),
        ('high', 130.0, 4218.0, 982.0, 23.3, true, true),
      );
    });

    test('well below the price → low', () {
      final r = check(40, 3000, 105.45);
      expect(
        (r.status, r.rate, r.diff, r.diffPct, r.isLow),
        ('low', 75.0, -1218.0, -28.9, true),
      );
    });

    test('exactly at the tolerance is fine; just past it is flagged', () {
      expect(check(100, 11000, 100).status, 'ok');
      expect(check(100, 11010, 100).status, 'high');
      expect(check(100, 9000, 100).status, 'ok');
      expect(check(100, 8990, 100).status, 'low');
      expect(check(100, 12000, 100, tol: 25).status, 'ok');
    });

    test(
      'no price: the bill\'s own rate is still worked out, nothing is judged',
      () {
        final r = check(40, 4000, null);
        expect(
          (r.status, r.rate, r.price, r.isFlagged),
          ('no_price', 100.0, null, false),
        );
      },
    );

    test('no litres, a tiny fill or no amount: too little to judge', () {
      for (final (q, a) in [
        (0.0, 4000.0),
        (0.5, 60.0),
        (0.99, 100.0),
        (40.0, 0.0),
      ]) {
        expect(check(q, a, 100).status, 'no_quantity', reason: '$q / $a');
      }
      expect(check(1, 100, 100).status, 'ok', reason: 'one litre is judged');
    });

    test('the server\'s answer on an expense is read', () {
      final e = FuelExpense.fromJson({
        '_id': 'x',
        'category': 'fuel',
        'date': '2026-10-23T05:00:00.000Z',
        'liters': 40,
        'totalAmount': 5200,
        'rateCheck': {
          'status': 'high',
          'fuelType': 'petrol',
          'unit': 'litre',
          'rate': 130,
          'price': 110,
          'expected': 4400,
          'diff': 800,
          'diffPct': 18.2,
          'tolerancePct': 10,
        },
      });
      expect(
        (
          e.rateCheck!.status,
          e.rateCheck!.rate,
          e.rateCheck!.diff,
          e.rateCheck!.diffPct,
          e.rateCheck!.unit,
        ),
        ('high', 130.0, 800.0, 18.2, 'litre'),
      );
      expect(
        FuelExpense.fromJson({
          '_id': 'y',
          'date': '2026-10-23T05:00:00.000Z',
        }).rateCheck,
        isNull,
        reason: 'an older server, or not a fill-up',
      );
      expect(
        FuelExpense.fromJson({
          '_id': 'z',
          'date': '2026-10-23T05:00:00.000Z',
          'rateCheck': null,
        }).rateCheck,
        isNull,
      );
    });

    test('in words', () {
      expect(
        rateCheckText(check(40, 5200, 110)),
        'Rate ₹130/L · 18.2% above the ₹110/L price · ₹800 over',
      );
      expect(
        rateCheckText(check(40, 3000, 105.45)),
        'Rate ₹75/L · 28.9% below the ₹105.45/L price · ₹1,218 under',
      );
      expect(
        rateCheckText(check(40, 4400, 110)),
        'Rate ₹110/L · matches the ₹110/L price',
      );
      expect(
        rateFlagNote(check(40, 5200, 110)),
        'Saved. This works out at ₹130/L — 18.2% above the fuel price, so Accounts will check the bill.',
      );
    });
  });

  group('filling in the amount', () {
    test(
      'fills an empty box, and follows the litres while it is still the app\'s own number',
      () {
        final amount = TextEditingController();
        final fill = AmountFillIn();
        expect(fill.apply(amount, 4218), isTrue);
        expect(amount.text, '4218');
        expect(fill.apply(amount, 2109), isTrue);
        expect(amount.text, '2109');
        expect(
          fill.apply(amount, null),
          isTrue,
          reason: 'litres cleared → the box it filled is cleared',
        );
        expect(amount.text, '');
      },
    );

    test('never overwrites what a person typed', () {
      final amount = TextEditingController(text: '3900');
      final fill = AmountFillIn();
      expect(fill.apply(amount, 4218), isFalse);
      expect(amount.text, '3900');
      final other = TextEditingController();
      final fill2 = AmountFillIn()..apply(other, 4218);
      other.text = '4300'; // they correct it to the bill
      expect(fill2.apply(other, 5000), isFalse);
      expect(other.text, '4300');
      expect(
        fill2.apply(other, null),
        isFalse,
        reason: 'and their number is not cleared either',
      );
      expect(other.text, '4300');
    });

    test('if they clear the box themselves, it may fill in again', () {
      final amount = TextEditingController();
      final fill = AmountFillIn()..apply(amount, 4218);
      amount.clear();
      expect(fill.apply(amount, 4300), isTrue);
      expect(amount.text, '4300');
    });

    test('the same number again changes nothing', () {
      final amount = TextEditingController();
      final fill = AmountFillIn();
      fill.apply(amount, 4254.91);
      expect(amount.text, '4254.91');
      expect(fill.apply(amount, 4254.91), isFalse);
    });
  });

  group('service', () {
    FuelPriceService svc(_Capture c) =>
        FuelPriceService(Dio()..httpClientAdapter = c);

    test('list reads GET /fuel-prices', () async {
      final cap = _Capture({
        'items': _defaults,
        'current': {'petrol': _defaults[1]},
        'today': _today,
        'tolerancePct': 10,
      });
      final p = await svc(cap).list();
      expect((cap.last!.method, cap.last!.path), ('GET', '/fuel-prices'));
      expect(p.items, hasLength(4));
      expect(p.current['petrol']!.pricePerUnit, 105.45);
    });

    test('create / edit / delete go to /fuel-prices', () async {
      final cap = _Capture(_row('n1', 'diesel', 97, '2026-10-23'));
      final made = await svc(cap).create(
        const FuelPriceRow(
          id: '',
          fuelType: 'diesel',
          pricePerUnit: 97,
          effectiveFrom: '2026-10-23',
          note: 'x',
        ),
      );
      expect((cap.last!.method, cap.last!.path), ('POST', '/fuel-prices'));
      expect(cap.last!.data, {
        'fuelType': 'diesel',
        'pricePerUnit': 97.0,
        'effectiveFrom': '2026-10-23',
        'note': 'x',
      });
      expect(made.id, 'n1');
      await svc(cap).update(
        'n1',
        const FuelPriceRow(
          id: 'n1',
          fuelType: 'diesel',
          pricePerUnit: 98,
          effectiveFrom: '2026-10-23',
        ),
      );
      expect((cap.last!.method, cap.last!.path), ('PUT', '/fuel-prices/n1'));
      await svc(cap).delete('n1');
      expect((cap.last!.method, cap.last!.path), ('DELETE', '/fuel-prices/n1'));
    });

    test('a refusal is a friendly AppException', () async {
      final cap = _Capture({
        'message':
            'Only Accounts, the fleet manager or an admin can change the fuel prices.',
      }, status: 403);
      await expectLater(
        svc(cap).create(
          const FuelPriceRow(
            id: '',
            fuelType: 'petrol',
            pricePerUnit: 1,
            effectiveFrom: _today,
          ),
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(svc(cap).list(), throwsA(isA<AppException>()));
      await expectLater(svc(cap).delete('x'), throwsA(isA<AppException>()));
    });

    test('who may edit the prices (the server decides too)', () {
      for (final r in ['accounts', 'finance_head', 'fleet_manager', 'admin']) {
        expect(canEditFuelPrices(r), isTrue, reason: r);
      }
      for (final r in ['driver', 'sales', 'artist', '', null]) {
        expect(canEditFuelPrices(r), isFalse, reason: '$r');
      }
    });
  });

  group('the price manager', () {
    Widget manager(_FakePriceService s) => _host(
      const FuelPriceManager(),
      overrides: [fuelPriceServiceProvider.overrideWithValue(s)],
    );

    testWidgets('no price yet: says so and offers to add one', (t) async {
      await _open(t, manager(_FakePriceService([])));
      expect(find.byKey(const Key('fuelPriceEmpty')), findsOneWidget);
      expect(find.byKey(const Key('fuelPriceAdd')), findsOneWidget);
    });

    testWidgets(
      'lists each fuel with its prices; today\'s is marked, a future one is "Upcoming", an older one "Earlier"',
      (t) async {
        await _open(t, manager(_FakePriceService(_defaults)));
        expect(find.text('Petrol'), findsOneWidget);
        expect(find.text('Diesel'), findsOneWidget);
        expect(
          find.text('CNG'),
          findsNothing,
          reason: 'a fuel with no price is not listed',
        );
        expect(find.text('₹105.45 per litre'), findsOneWidget);
        expect(find.text('₹96.50 per litre'), findsOneWidget);
        String status(String id) => t
            .widget<Text>(
              find.descendant(
                of: find.byKey(Key('fuelPriceStatus_$id')),
                matching: find.byType(Text),
              ),
            )
            .data!;
        expect(status('p2'), 'In force today');
        expect(status('p3'), 'Upcoming');
        expect(status('p1'), 'Earlier');
        expect(status('d1'), 'In force today');
        expect(
          find.textContaining('From 1 Oct 2026  ·  Kerala'),
          findsOneWidget,
        );
        expect(
          find.textContaining('more than 10% above or below'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'add: the price is saved with its fuel and start day, and shows in the list',
      (t) async {
        final svc = _FakePriceService(_defaults);
        await _open(t, manager(svc));
        await t.tap(find.byKey(const Key('fuelPriceAdd')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('fuelPriceForm')), findsOneWidget);
        await t.tap(find.byKey(const Key('fuelPriceFuel')));
        await t.pumpAndSettle();
        await t.tap(find.text('CNG  (per kg)').last);
        await t.pumpAndSettle();
        expect(
          find.text('Price per kg (₹)'),
          findsOneWidget,
          reason: 'the unit follows the fuel',
        );
        await t.enterText(find.byKey(const Key('fuelPriceAmount')), '88.5');
        await t.enterText(find.byKey(const Key('fuelPriceNote')), 'Kochi');
        await t.tap(find.byKey(const Key('fuelPriceSave')));
        await t.pumpAndSettle();
        expect(svc.calls, ['create']);
        expect(
          (
            svc.lastBody!['fuelType'],
            svc.lastBody!['pricePerUnit'],
            svc.lastBody!['note'],
          ),
          ('cng', 88.5, 'Kochi'),
        );
        expect(
          RegExp(
            r'^\d{4}-\d{2}-\d{2}$',
          ).hasMatch(svc.lastBody!['effectiveFrom'] as String),
          isTrue,
          reason: 'it starts on a chosen day (today by default)',
        );
        expect(find.byKey(const Key('fuelPriceForm')), findsNothing);
      },
    );

    testWidgets(
      'add: a missing price is refused in the form, which stays open',
      (t) async {
        final svc = _FakePriceService(_defaults);
        await _open(t, manager(svc));
        await t.tap(find.byKey(const Key('fuelPriceAdd')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('fuelPriceSave')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('fuelPriceError')), findsOneWidget);
        expect(
          find.text('Enter the price per litre (more than 0).'),
          findsOneWidget,
        );
        expect(svc.calls, isEmpty);
      },
    );

    testWidgets(
      'add: the server\'s refusal (a price already set for that day) is shown in the form',
      (t) async {
        final svc = _FakePriceService(_defaults)
          ..failWith = Exception(
            'There is already a petrol price from that date (₹105.45). Edit that one instead.',
          );
        await _open(t, manager(svc));
        await t.tap(find.byKey(const Key('fuelPriceAdd')));
        await t.pumpAndSettle();
        await t.enterText(find.byKey(const Key('fuelPriceAmount')), '106');
        await t.tap(find.byKey(const Key('fuelPriceSave')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const Key('fuelPriceForm')),
          findsOneWidget,
          reason: 'stays open to fix',
        );
        expect(
          find.textContaining('There is already a petrol price from that date'),
          findsOneWidget,
        );
      },
    );

    testWidgets('edit: the form opens with the price, and saves the change', (
      t,
    ) async {
      final svc = _FakePriceService(_defaults);
      await _open(t, manager(svc));
      await t.tap(find.byKey(const Key('fuelPriceEdit_p2')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(find.byKey(const Key('fuelPriceAmount')))
            .controller!
            .text,
        '105.45',
      );
      expect(
        t
            .widget<TextField>(find.byKey(const Key('fuelPriceNote')))
            .controller!
            .text,
        'Kerala',
      );
      await t.enterText(find.byKey(const Key('fuelPriceAmount')), '107');
      await t.tap(find.byKey(const Key('fuelPriceSave')));
      await t.pumpAndSettle();
      expect(svc.calls, ['update p2']);
      expect(
        (svc.lastBody!['pricePerUnit'], svc.lastBody!['effectiveFrom']),
        (107.0, '2026-10-01'),
      );
      expect(find.text('₹107 per litre'), findsOneWidget);
    });

    testWidgets('delete asks first; Cancel keeps it, Delete removes it', (
      t,
    ) async {
      final svc = _FakePriceService(_defaults);
      await _open(t, manager(svc));
      await t.tap(find.byKey(const Key('fuelPriceDelete_p1')));
      await t.pumpAndSettle();
      expect(find.text('Delete this price?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(svc.calls, isEmpty);
      await t.tap(find.byKey(const Key('fuelPriceDelete_p1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('fuelPriceConfirmDelete')));
      await t.pumpAndSettle();
      expect(svc.calls, ['delete p1']);
      expect(find.byKey(const Key('fuelPriceRow_p1')), findsNothing);
    });

    testWidgets('on a phone it fits', (t) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) =>
          errors.add(d.toDiagnosticsNode().toStringDeep());
      try {
        await _open(t, manager(_FakePriceService(_defaults)), width: 360);
        await t.ensureVisible(find.byKey(const Key('fuelPriceAdd')));
        await t.tap(find.byKey(const Key('fuelPriceAdd')));
        await t.pumpAndSettle();
      } finally {
        FlutterError.onError = previous;
      }
      expect(find.byKey(const Key('fuelPriceForm')), findsOneWidget);
      expect(
        errors.where((e) => e.contains('fuel_price_manager.dart')),
        isEmpty,
      );
    });
  });

  group('the rate on a list', () {
    RateCheck check(double amt, {double qty = 40, double price = 110}) =>
        RateCheck.compute(
          fuelType: 'petrol',
          quantity: qty,
          amount: amt,
          price: price,
        );

    Widget line(RateCheck? c, {bool flaggedOnly = false}) =>
        _host(RateCheckLine(check: c, flaggedOnly: flaggedOnly));

    testWidgets('a rate that is off is called out, with how far', (t) async {
      await _open(t, line(check(5200)));
      expect(find.byKey(const Key('rateCheckFlag')), findsOneWidget);
      expect(
        find.text('Rate ₹130/L · 18.2% above the ₹110/L price · ₹800 over'),
        findsOneWidget,
      );
    });

    testWidgets('a low rate too', (t) async {
      await _open(t, line(check(3000)));
      expect(find.textContaining('below the ₹110/L price'), findsOneWidget);
    });

    testWidgets(
      'a rate that matches says so quietly — unless only flags are wanted',
      (t) async {
        await _open(t, line(check(4400)));
        expect(find.byKey(const Key('rateCheckOk')), findsOneWidget);
        expect(
          find.text('Rate ₹110/L · matches the ₹110/L price'),
          findsOneWidget,
        );
        await _open(t, line(check(4400), flaggedOnly: true));
        expect(find.byKey(const Key('rateCheckOk')), findsNothing);
      },
    );

    testWidgets(
      'says nothing when there is nothing to say: no check, no price set, no litres',
      (t) async {
        for (final c in [
          null,
          RateCheck.compute(
            fuelType: 'petrol',
            quantity: 40,
            amount: 4000,
            price: null,
          ),
          RateCheck.compute(
            fuelType: 'petrol',
            quantity: 0,
            amount: 4000,
            price: 110,
          ),
        ]) {
          await _open(t, line(c));
          expect(find.byKey(const Key('rateCheckFlag')), findsNothing);
          expect(find.byKey(const Key('rateCheckOk')), findsNothing);
          expect(find.byType(Text), findsNothing);
        }
      },
    );
  });

  group('the hint while entering a fill-up', () {
    Widget hint(
      TextEditingController litres,
      TextEditingController amount, {
      String? fuel = 'petrol',
      String day = _today,
      FuelPrices? prices,
      bool fillsIn = false,
      bool fail = false,
    }) => _host(
      FuelRateHint(
        vehicleFuelType: fuel,
        day: day,
        liters: litres,
        amount: amount,
        fillsIn: fillsIn,
      ),
      overrides: [
        fuelPricesProvider.overrideWith((ref) async {
          if (fail) throw Exception('server down');
          return prices ?? _prices(_defaults);
        }),
      ],
    );

    testWidgets('names today\'s price for the vehicle\'s fuel', (t) async {
      await _open(t, hint(TextEditingController(), TextEditingController()));
      expect(find.byKey(const Key('fuelPriceLine')), findsOneWidget);
      expect(find.text("Today's petrol price: ₹105.45/litre"), findsOneWidget);
      expect(find.byKey(const Key('fuelRateWarning')), findsNothing);
    });

    testWidgets('a hybrid is shown the petrol price; diesel its own', (
      t,
    ) async {
      await _open(
        t,
        hint(TextEditingController(), TextEditingController(), fuel: 'hybrid'),
      );
      expect(find.text("Today's petrol price: ₹105.45/litre"), findsOneWidget);
      await _open(
        t,
        hint(TextEditingController(), TextEditingController(), fuel: 'diesel'),
      );
      expect(find.text("Today's diesel price: ₹96.50/litre"), findsOneWidget);
    });

    testWidgets(
      'another day is named by its date, and uses that day\'s price',
      (t) async {
        await _open(
          t,
          hint(
            TextEditingController(),
            TextEditingController(),
            day: '2026-03-10',
          ),
        );
        expect(find.text('10 Mar petrol price: ₹100/litre'), findsOneWidget);
      },
    );

    testWidgets('where the amount is filled in from the litres, it says so', (
      t,
    ) async {
      await _open(
        t,
        hint(TextEditingController(), TextEditingController(), fillsIn: true),
      );
      expect(
        find.textContaining('the amount fills in from the litres'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a rate that is off is warned about as the litres and amount are typed — and stops when fixed',
      (t) async {
        final litres = TextEditingController();
        final amount = TextEditingController();
        await _open(t, hint(litres, amount));
        litres.text = '40';
        amount.text = '5200';
        await t.pump();
        expect(find.byKey(const Key('fuelRateWarning')), findsOneWidget);
        expect(
          find.textContaining(
            'This works out at ₹130/L — 23.3% above the price. Check the litres and the amount against the bill.',
          ),
          findsOneWidget,
        );
        amount.text = '4218';
        await t.pump();
        expect(find.byKey(const Key('fuelRateWarning')), findsNothing);
      },
    );

    testWidgets('a low rate is warned about too', (t) async {
      final litres = TextEditingController(text: '40');
      final amount = TextEditingController(text: '3000');
      await _open(t, hint(litres, amount));
      expect(find.textContaining('28.9% below the price'), findsOneWidget);
    });

    testWidgets(
      'shows nothing without a price for that fuel and day, for an unknown fuel, or when the prices cannot be loaded',
      (t) async {
        for (final w in [
          hint(TextEditingController(), TextEditingController(), fuel: 'cng'),
          hint(
            TextEditingController(),
            TextEditingController(),
            day: '2025-01-01',
          ),
          hint(TextEditingController(), TextEditingController(), fuel: 'other'),
          hint(TextEditingController(), TextEditingController(), fuel: null),
          hint(TextEditingController(), TextEditingController(), fail: true),
          hint(
            TextEditingController(),
            TextEditingController(),
            prices: FuelPrices.empty,
          ),
        ]) {
          await _open(t, w);
          expect(find.byKey(const Key('fuelRateHint')), findsNothing);
        }
      },
    );
  });

  group('the driver\'s fuel entry', () {
    FleetJob job({String fuel = 'petrol', DateTime? start}) => FleetJob(
      id: 'j1',
      bookingNumber: 'BK-1',
      vehicleId: {
        '_id': 'v1',
        'registrationNumber': 'KL 11 AB 1234',
        'fuelType': fuel,
      },
      customerName: 'Asha',
      service: 'Bridal',
      serviceStart: start ?? DateTime(2026, 10, 23, 9),
      serviceEnd: (start ?? DateTime(2026, 10, 23, 9)).add(
        const Duration(hours: 8),
      ),
    );

    Widget screen(
      _FakeSaver saver, {
      FleetJob? j,
      List<Map<String, dynamic>>? rows,
      bool pricesFail = false,
    }) => ProviderScope(
      overrides: <Override>[
        driverJobsProvider.overrideWith((ref) async => [j ?? job()]),
        fuelExpenseServiceProvider.overrideWithValue(saver),
        fuelPricesProvider.overrideWith((ref) async {
          if (pricesFail) throw Exception('server down');
          return _prices(rows ?? _defaults);
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DriverAddExpenseScreen(),
      ),
    );

    final amountBox = find.widgetWithText(TextField, 'Amount (₹)');
    String amountText(WidgetTester t) =>
        t.widget<TextField>(amountBox).controller!.text;
    Future<void> litres(WidgetTester t, String v) async {
      await t.enterText(find.byKey(const Key('litersField')), v);
      await t.pump();
      await t.pump();
    }

    testWidgets('typing the litres fills in the amount from today\'s price', (
      t,
    ) async {
      await _open(t, screen(_FakeSaver()));
      expect(amountText(t), '');
      await litres(t, '40');
      expect(amountText(t), '4218');
      expect(
        find.text(
          "Today's petrol price: ₹105.45/litre — the amount fills in from the litres",
        ),
        findsOneWidget,
      );
    });

    testWidgets('it follows the litres while the amount is still its own', (
      t,
    ) async {
      await _open(t, screen(_FakeSaver()));
      await litres(t, '40');
      await litres(t, '20');
      expect(amountText(t), '2109');
      await litres(t, '');
      expect(
        amountText(t),
        '',
        reason: 'litres removed → what it filled in goes too',
      );
    });

    testWidgets(
      'a number the driver typed is never overwritten — and the hint checks it',
      (t) async {
        await _open(t, screen(_FakeSaver()));
        await t.enterText(amountBox, '5200');
        await litres(t, '40');
        expect(amountText(t), '5200');
        expect(
          find.byKey(const Key('fuelRateWarning')),
          findsOneWidget,
          reason: '₹130/L against ₹105.45',
        );
      },
    );

    testWidgets(
      'correcting the filled-in amount to the bill is kept, and no warning when it is close',
      (t) async {
        await _open(t, screen(_FakeSaver()));
        await litres(t, '40');
        await t.enterText(amountBox, '4300');
        await litres(t, '41');
        expect(amountText(t), '4300');
        expect(find.byKey(const Key('fuelRateWarning')), findsNothing);
      },
    );

    testWidgets('diesel uses the diesel price', (t) async {
      await _open(t, screen(_FakeSaver(), j: job(fuel: 'diesel')));
      await litres(t, '10');
      expect(amountText(t), '965');
    });

    testWidgets(
      'a day with no price yet, a fuel with none, or prices that cannot be loaded: nothing is filled in and nothing breaks',
      (t) async {
        await _open(
          t,
          screen(_FakeSaver(), rows: [_row('c1', 'cng', 88, '2026-01-01')]),
        );
        await litres(t, '40');
        expect(amountText(t), '');
        expect(find.byKey(const Key('fuelRateHint')), findsNothing);
        await _open(t, screen(_FakeSaver(), pricesFail: true));
        await litres(t, '40');
        expect(amountText(t), '');
        expect(find.byKey(const Key('fuelRateHint')), findsNothing);
      },
    );

    testWidgets('a non-fuel expense (a toll) is not filled in', (t) async {
      await _open(t, screen(_FakeSaver()));
      await t.tap(find.byKey(const Key('categoryPicker')));
      await t.pumpAndSettle();
      await t.tap(find.text('Toll').last);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('litersField')), findsNothing);
      expect(amountText(t), '');
    });

    /// The screen inside a router (saving pops it), over a "home" page where the snack bar can be read.
    Future<_FakeSaver> saveFlow(
      WidgetTester t, {
      Map<String, dynamic>? answer,
    }) async {
      final saver = _FakeSaver(answer: answer);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/add',
            builder: (_, _) => const DriverAddExpenseScreen(),
          ),
        ],
      );
      t.view.physicalSize = const Size(1100, 2200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            driverJobsProvider.overrideWith((ref) async => [job()]),
            fuelExpenseServiceProvider.overrideWithValue(saver),
            fuelPricesProvider.overrideWith((ref) async => _prices(_defaults)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await t.pumpAndSettle();
      unawaited(router.push('/add'));
      await t.pumpAndSettle();
      return saver;
    }

    Future<void> fillAndSubmit(WidgetTester t, {String? amount}) async {
      await litres(t, '40');
      await t.enterText(find.byKey(const Key('odometerField')), '12000');
      if (amount != null) await t.enterText(amountBox, amount);
      await t.pump();
      // the bill is mandatory: attach one the way the field would
      t
          .widget<BillAttachmentField>(find.byType(BillAttachmentField))
          .onChanged('https://bills.example/b.jpg');
      await t.pump();
      await t.ensureVisible(find.byType(ElevatedButton));
      await t.tap(find.byType(ElevatedButton));
      await t.pumpAndSettle();
    }

    testWidgets(
      'the filled-in amount is what is saved, and an ordinary save says so plainly',
      (t) async {
        final saver = await saveFlow(t);
        await fillAndSubmit(t);
        expect(saver.saved, hasLength(1));
        expect(
          (
            saver.saved.single['liters'],
            saver.saved.single['totalAmount'],
            saver.saved.single['category'],
          ),
          (40.0, 4218.0, 'fuel'),
        );
        expect(
          find.text('home'),
          findsOneWidget,
          reason: 'saved, so the screen closed',
        );
        expect(find.text('Expense added successfully'), findsOneWidget);
      },
    );

    testWidgets(
      'a rate that is off still saves — and the driver is told Accounts will check the bill',
      (t) async {
        final saver = await saveFlow(
          t,
          answer: {
            'status': 'high',
            'fuelType': 'petrol',
            'unit': 'litre',
            'rate': 130,
            'price': 105.45,
            'expected': 4218,
            'diff': 982,
            'diffPct': 23.3,
            'tolerancePct': 10,
          },
        );
        await fillAndSubmit(t, amount: '5200');
        expect(
          saver.saved.single['totalAmount'],
          5200.0,
          reason: 'what they typed, not the fill-in',
        );
        expect(find.text('home'), findsOneWidget);
        expect(
          find.text(
            'Saved. This works out at ₹130/L — 23.3% above the fuel price, so Accounts will check the bill.',
          ),
          findsOneWidget,
        );
        expect(find.text('Expense added successfully'), findsNothing);
      },
    );

    testWidgets('without the bill nothing is saved', (t) async {
      final saver = await saveFlow(t);
      await litres(t, '40');
      await t.enterText(find.byKey(const Key('odometerField')), '12000');
      await t.ensureVisible(find.byType(ElevatedButton));
      await t.tap(find.byType(ElevatedButton));
      await t.pumpAndSettle();
      expect(saver.saved, isEmpty);
      expect(find.text('Attach the bill / screenshot first'), findsOneWidget);
    });
  });
}

/// Records what the driver's screen saves; answers with a fuel expense carrying [answer] as its rateCheck.
class _FakeSaver extends FuelExpenseService {
  _FakeSaver({this.answer}) : super(Dio());
  final Map<String, dynamic>? answer;
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
      'liters': liters,
      'totalAmount': totalAmount,
      'category': category,
    });
    return FuelExpense.fromJson({
      '_id': 'n1',
      'category': category,
      'date': date.toIso8601String(),
      'liters': liters,
      'totalAmount': totalAmount,
      'rateCheck': answer,
    });
  }
}
