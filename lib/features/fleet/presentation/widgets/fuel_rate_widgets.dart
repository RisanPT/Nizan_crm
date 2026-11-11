import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_price_controller.dart';
import 'package:nizan_crm/features/fleet/data/fuel_price.dart';

String _short(String unit) => unit == 'litre' ? 'L' : unit;
String _rupees(double v) => '₹${priceText(v)}';
String _whole(double v) =>
    '₹${NumberFormat.decimalPattern('en_IN').format(v.abs().round())}';
String _pct(double v) {
  final a = v.abs();
  return a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(1);
}

String _dayText(String iso) =>
    iso.isEmpty ? '' : DateFormat('d MMM').format(DateTime.parse(iso));

/// "Rate ₹130/L · 18.2% above the ₹110/L price · ₹800 over" — a fill-up's rate against the price.
String rateCheckText(RateCheck c) {
  final u = _short(c.unit);
  final head = 'Rate ${_rupees(c.rate ?? 0)}/$u';
  if (c.isHigh) {
    return '$head · ${_pct(c.diffPct)}% above the ${_rupees(c.price ?? 0)}/$u price · ${_whole(c.diff)} over';
  }
  if (c.isLow) {
    return '$head · ${_pct(c.diffPct)}% below the ${_rupees(c.price ?? 0)}/$u price · ${_whole(c.diff)} under';
  }
  return '$head · matches the ${_rupees(c.price ?? 0)}/$u price';
}

/// A fill-up's rate against the fuel price of its day, for the lists Accounts / the fleet manager read.
/// Says nothing when there is nothing to say (no check, no price set yet, no litres); with
/// [flaggedOnly] it speaks only when the rate is off.
class RateCheckLine extends StatelessWidget {
  final RateCheck? check;
  final bool flaggedOnly;
  const RateCheckLine({
    super.key,
    required this.check,
    this.flaggedOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = check;
    if (c == null ||
        !(c.isFlagged || c.isOk) ||
        (flaggedOnly && !c.isFlagged)) {
      return const SizedBox.shrink();
    }
    final crm = context.crmColors;
    final color = c.isHigh
        ? crm.destructive
        : (c.isLow ? crm.warning : crm.success);
    final icon = c.isFlagged
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        key: Key(c.isFlagged ? 'rateCheckFlag' : 'rateCheckOk'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              rateCheckText(c),
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: c.isFlagged ? FontWeight.w700 : FontWeight.w500,
                color: c.isFlagged ? color : crm.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// While a fill-up is being entered: today's price for the vehicle's fuel, and — once litres and
/// amount are in — how the bill's rate compares. Only ever informs: it never blocks saving, and
/// shows nothing at all when the prices can't be loaded or none is set.
class FuelRateHint extends ConsumerWidget {
  /// The vehicle's fuel type as the vehicle stores it (petrol / diesel / hybrid / …); null = unknown.
  final String? vehicleFuelType;

  /// The IST day the fill-up is for, 'YYYY-MM-DD'.
  final String day;
  final TextEditingController liters;
  final TextEditingController amount;

  /// The amount box is filled in from the litres on this form: say so.
  final bool fillsIn;

  const FuelRateHint({
    super.key,
    required this.vehicleFuelType,
    required this.day,
    required this.liters,
    required this.amount,
    this.fillsIn = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuel = fuelPriceTypeOf(vehicleFuelType);
    final prices = ref.watch(fuelPricesProvider).value;
    if (fuel == null || prices == null) return const SizedBox.shrink();
    final price = prices.priceOn(fuel, day);
    if (price == null) return const SizedBox.shrink();

    final crm = context.crmColors;
    final u = _short(price.unit);
    final when = day == prices.today ? "Today's" : _dayText(day);
    return ListenableBuilder(
      listenable: Listenable.merge([liters, amount]),
      builder: (context, _) {
        final check = RateCheck.compute(
          fuelType: fuel,
          quantity: double.tryParse(liters.text.trim()) ?? 0,
          amount: double.tryParse(amount.text.trim().replaceAll(',', '')) ?? 0,
          price: price.pricePerUnit,
          tolerancePct: prices.tolerancePct,
        );
        return Padding(
          key: const Key('fuelRateHint'),
          padding: const EdgeInsets.only(top: 8, left: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sell_outlined, size: 14, color: crm.textSecondary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '$when ${fuelLabel(fuel).toLowerCase()} price: ${_rupees(price.pricePerUnit)}/${price.unit}${fillsIn ? ' — the amount fills in from the litres' : ''}',
                      key: const Key('fuelPriceLine'),
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    ),
                  ),
                ],
              ),
              if (check.isFlagged)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    key: const Key('fuelRateWarning'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: check.isHigh ? crm.destructive : crm.warning,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'This works out at ${_rupees(check.rate ?? 0)}/$u — ${_pct(check.diffPct)}% ${check.isHigh ? 'above' : 'below'} the price. Check the litres and the amount against the bill.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: check.isHigh ? crm.destructive : crm.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Keeps an amount box filled in from litres × price without ever overwriting what a person typed:
/// the box is only touched while it is empty or still holds exactly what this last put there.
class AmountFillIn {
  String _last = '';

  /// Puts [suggested] in [amount] (or clears what we put there when there is none). True if the box changed.
  bool apply(TextEditingController amount, double? suggested) {
    final cur = amount.text.trim();
    if (cur.isNotEmpty && cur != _last) return false; // their own number
    final text = suggested == null ? '' : priceText(suggested);
    if (text == cur) {
      _last = text;
      return false;
    }
    amount.text = text;
    _last = text;
    return true;
  }
}

/// What a driver is told right after saving a fill-up whose rate is off (it is saved either way).
String rateFlagNote(RateCheck c) =>
    'Saved. This works out at ${_rupees(c.rate ?? 0)}/${_short(c.unit)} — ${_pct(c.diffPct)}% ${c.isHigh ? 'above' : 'below'} the fuel price, so Accounts will check the bill.';
