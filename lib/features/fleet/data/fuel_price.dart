import 'package:flutter/material.dart';

/// The fuels that have a price, in the order they are listed: (key, label, unit, icon).
const kFuelPriceTypes = <(String, String, String, IconData)>[
  ('petrol', 'Petrol', 'litre', Icons.local_gas_station_outlined),
  ('diesel', 'Diesel', 'litre', Icons.local_gas_station),
  ('cng', 'CNG', 'kg', Icons.propane_tank_outlined),
  ('electric', 'Electric', 'kWh', Icons.bolt_outlined),
];

String fuelLabel(String fuelType) =>
    kFuelPriceTypes
        .where((f) => f.$1 == fuelType)
        .map((f) => f.$2)
        .firstOrNull ??
    fuelType;
String fuelUnit(String fuelType) =>
    kFuelPriceTypes
        .where((f) => f.$1 == fuelType)
        .map((f) => f.$3)
        .firstOrNull ??
    'litre';

/// The price-table fuel for a vehicle's fuel type — a hybrid runs on petrol; "other" (or unknown) has
/// no price to hold a bill against. Same rule as the server (utils/fuelPrice.js priceTypeOf).
String? fuelPriceTypeOf(String? vehicleFuelType) {
  final t = (vehicleFuelType ?? '').toLowerCase();
  if (t == 'hybrid') return 'petrol';
  return kFuelPriceTypes.any((f) => f.$1 == t) ? t : null;
}

double _round2(double v) => (v * 100).round() / 100;

/// "105" / "105.45" — a price as written in a box.
String priceText(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// One price: [pricePerUnit] ₹ per litre (kg / kWh) from the day [effectiveFrom] ('YYYY-MM-DD').
class FuelPriceRow {
  final String id;
  final String fuelType;
  final double pricePerUnit;
  final String effectiveFrom;
  final String note;

  const FuelPriceRow({
    required this.id,
    required this.fuelType,
    required this.pricePerUnit,
    required this.effectiveFrom,
    this.note = '',
  });

  String get unit => fuelUnit(fuelType);

  factory FuelPriceRow.fromJson(Map<String, dynamic> j) => FuelPriceRow(
    id: '${j['_id'] ?? j['id'] ?? ''}',
    fuelType: '${j['fuelType'] ?? ''}',
    pricePerUnit: (j['pricePerUnit'] as num?)?.toDouble() ?? 0,
    effectiveFrom: '${j['effectiveFrom'] ?? ''}',
    note: '${j['note'] ?? ''}',
  );

  Map<String, dynamic> toBody() => {
    'fuelType': fuelType,
    'pricePerUnit': pricePerUnit,
    'effectiveFrom': effectiveFrom,
    'note': note,
  };
}

/// Every fuel price, and the arithmetic the forms use: which price applies on a day, and what a quantity comes to.
class FuelPrices {
  final List<FuelPriceRow> items;

  /// The price in force today per fuel (null where none is set).
  final Map<String, FuelPriceRow?> current;
  final String today;

  /// How far a bill's rate may sit from the price before it is flagged, in percent.
  final double tolerancePct;

  const FuelPrices({
    this.items = const [],
    this.current = const {},
    this.today = '',
    this.tolerancePct = 10,
  });

  static const empty = FuelPrices();

  bool get isEmpty => items.isEmpty;

  factory FuelPrices.fromJson(Map<String, dynamic> j) => FuelPrices(
    items: [
      for (final r in (j['items'] as List? ?? const []))
        FuelPriceRow.fromJson((r as Map).cast<String, dynamic>()),
    ],
    current: {
      for (final e in ((j['current'] as Map?) ?? const {}).entries)
        '${e.key}': e.value is Map
            ? FuelPriceRow.fromJson((e.value as Map).cast<String, dynamic>())
            : null,
    },
    today: '${j['today'] ?? ''}',
    tolerancePct: (j['tolerancePct'] as num?)?.toDouble() ?? 10,
  );

  /// The price in force for [fuelType] on [day] ('YYYY-MM-DD'): the latest that started on or before it.
  /// Null when none had started — a bill from before the first price is never held against a later one.
  FuelPriceRow? priceOn(String fuelType, String day) {
    FuelPriceRow? best;
    for (final p in items) {
      if (p.fuelType != fuelType || p.effectiveFrom.compareTo(day) > 0) {
        continue;
      }
      if (best == null || p.effectiveFrom.compareTo(best.effectiveFrom) > 0) {
        best = p;
      }
    }
    return best;
  }

  /// [quantity] at the price in force on [day], to the paisa — what the fill-in puts in the amount box.
  double? suggestAmount(String fuelType, String day, double quantity) {
    final p = priceOn(fuelType, day);
    if (p == null || !(quantity > 0)) return null;
    return _round2(quantity * p.pricePerUnit);
  }
}

/// A fuel bill's rate held against the price of its day (same arithmetic as the server's
/// utils/fuelPrice.js, so the form can follow the typing and the server says the same when saved).
///   ok / high / low   the rate is within / above / below the tolerance of the price
///   no_price          no price in force for that fuel and day
///   no_quantity       no litres, too few to judge, or no amount
class RateCheck {
  static const minQuantity = 1.0;

  final String status;
  final String fuelType;
  final double? rate;
  final double? price;
  final double? expected;
  final double diff;
  final double diffPct;
  final double tolerancePct;

  const RateCheck({
    required this.status,
    this.fuelType = '',
    this.rate,
    this.price,
    this.expected,
    this.diff = 0,
    this.diffPct = 0,
    this.tolerancePct = 10,
  });

  bool get isHigh => status == 'high';
  bool get isLow => status == 'low';
  bool get isOk => status == 'ok';

  /// Worth Accounts' attention.
  bool get isFlagged => isHigh || isLow;
  String get unit => fuelUnit(fuelType);

  factory RateCheck.fromJson(Map<String, dynamic> j) => RateCheck(
    status: '${j['status'] ?? ''}',
    fuelType: '${j['fuelType'] ?? ''}',
    rate: (j['rate'] as num?)?.toDouble(),
    price: (j['price'] as num?)?.toDouble(),
    expected: (j['expected'] as num?)?.toDouble(),
    diff: (j['diff'] as num?)?.toDouble() ?? 0,
    diffPct: (j['diffPct'] as num?)?.toDouble() ?? 0,
    tolerancePct: (j['tolerancePct'] as num?)?.toDouble() ?? 10,
  );

  factory RateCheck.compute({
    required String fuelType,
    required double quantity,
    required double amount,
    required double? price,
    double tolerancePct = 10,
  }) {
    if (!(quantity >= minQuantity) || !(amount > 0)) {
      return RateCheck(
        status: 'no_quantity',
        fuelType: fuelType,
        tolerancePct: tolerancePct,
      );
    }
    final rate = _round2(amount / quantity);
    if (price == null || !(price > 0)) {
      return RateCheck(
        status: 'no_price',
        fuelType: fuelType,
        rate: rate,
        tolerancePct: tolerancePct,
      );
    }
    final expected = _round2(quantity * price);
    final diffPct = (((amount / quantity / price) - 1) * 1000).round() / 10;
    final status = diffPct > tolerancePct
        ? 'high'
        : (diffPct < -tolerancePct ? 'low' : 'ok');
    return RateCheck(
      status: status,
      fuelType: fuelType,
      rate: rate,
      price: price,
      expected: expected,
      diff: _round2(amount - expected),
      diffPct: diffPct,
      tolerancePct: tolerancePct,
    );
  }
}
