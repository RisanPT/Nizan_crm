import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/fleet/controllers/vehicle_controller.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/features/fleet/data/vehicle_categories.dart';
import 'package:nizan_crm/features/fleet/data/vehicle_efficiency.dart';

final _inr = NumberFormat.decimalPattern('en_IN');
String _rupees(num v, {int digits = 0}) =>
    '₹${NumberFormat.decimalPatternDigits(locale: 'en_IN', decimalDigits: digits).format(v)}';

String _n(double v, {int digits = 1}) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(digits);

Color efficiencyColor(CrmTheme c, String status) => switch (status) {
      'good' => c.success,
      'watch' => c.warning,
      'poor' => c.destructive,
      _ => c.textSecondary,
    };

String efficiencyStatusLabel(String status) => switch (status) {
      'good' => 'Good',
      'watch' => 'Watch',
      'poor' => 'Poor',
      _ => 'Not rated',
    };

/// Small "14.2 km/l" pill for a vehicle card. Nothing when there is no figure yet.
class VehicleEfficiencyChip extends StatelessWidget {
  final VehicleEfficiency? efficiency;
  const VehicleEfficiencyChip({super.key, required this.efficiency});

  @override
  Widget build(BuildContext context) {
    final e = efficiency;
    if (e == null || e.actual == null) return const SizedBox.shrink();
    final color = efficiencyColor(context.crmColors, e.status);
    return Tooltip(
      message: e.rated != null
          ? 'Actual ${_n(e.actual!)} ${e.unit} · rated ${_n(e.rated!)}'
          : 'Actual ${_n(e.actual!)} ${e.unit}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${_n(e.actual!)} ${e.unit}',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}

/// Opens the "Fuel efficiency" panel for [vehicle].
Future<void> showVehicleEfficiencySheet(BuildContext context, Vehicle vehicle) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => _EfficiencySheet(vehicle: vehicle, controller: scroll),
    ),
  );
}

class _EfficiencySheet extends ConsumerWidget {
  final Vehicle vehicle;
  final ScrollController controller;
  const _EfficiencySheet({required this.vehicle, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vehicleEfficiencyProvider(vehicle.id));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        children: [
          AppErrorView(error: e, onRetry: () => ref.invalidate(vehicleEfficiencyProvider(vehicle.id))),
        ],
      ),
      data: (eff) => _Body(vehicle: vehicle, eff: eff, controller: controller),
    );
  }
}

class _Body extends StatelessWidget {
  final Vehicle vehicle;
  final VehicleEfficiency eff;
  final ScrollController controller;
  const _Body({required this.vehicle, required this.eff, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final color = efficiencyColor(c, eff.status);
    final qty = fuelQuantityUnit(vehicle.fuelType);
    final cat = vehicleCategoryLabel(vehicle.category);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        // ── who ──
        Text(vehicle.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          [vehicle.registrationNumber, if (vehicle.brand.isNotEmpty) vehicle.brand].join(' • '),
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (cat.isNotEmpty) _Pill(cat, c.primary),
          if (vehicle.seats > 0) _Pill('${vehicle.seats} seats', c.textSecondary),
          _Pill(vehicle.fuelType.toUpperCase(), c.textSecondary),
          if (vehicle.tankCapacity > 0) _Pill('Tank ${_n(vehicle.tankCapacity)} $qty', c.textSecondary),
        ]),
        const SizedBox(height: 18),

        // ── headline ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: eff.actual == null ? _NoFigure(eff: eff) : _Headline(eff: eff, color: color),
        ),
        if (eff.rated == null) ...[
          const SizedBox(height: 10),
          _Note(
            icon: Icons.info_outline,
            color: c.warning,
            text: 'No rated mileage is set for this vehicle, so it can\'t be compared yet. '
                'Add it with Edit vehicle.',
          ),
        ],
        if (eff.suspectIntervals > 0) ...[
          const SizedBox(height: 10),
          _Note(
            icon: Icons.warning_amber_rounded,
            color: c.warning,
            text: '${eff.suspectIntervals} fuel entr${eff.suspectIntervals == 1 ? 'y looks' : 'ies look'} wrong '
                '(odometer typo or a missed fill-up) and ${eff.suspectIntervals == 1 ? 'was' : 'were'} left out of the average.',
          ),
        ],
        const SizedBox(height: 18),

        // ── numbers ──
        // Two columns of content-sized tiles (a fixed aspect ratio clips the text on a phone).
        LayoutBuilder(builder: (context, box) {
          const gap = 10.0;
          final w = (box.maxWidth - gap) / 2;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final tile in [
              _Stat('Cost per km', eff.costPerKm == null ? '—' : _rupees(eff.costPerKm!, digits: 2)),
              _Stat('Fuel price', eff.avgPricePerUnit == null ? '—' : '${_rupees(eff.avgPricePerUnit!, digits: 2)} / $qty'),
              _Stat('Full-tank range',
                  eff.ratedRangeKm == null && eff.actualRangeKm == null
                      ? (vehicle.tankCapacity > 0 ? '—' : 'Add tank size')
                      : '${eff.actualRangeKm ?? '—'} km',
                  sub: eff.ratedRangeKm == null ? null : 'rated ${eff.ratedRangeKm} km'),
              _Stat('Fuel spent', _rupees(eff.fuelSpend), sub: 'last ${eff.fillCount} entr${eff.fillCount == 1 ? 'y' : 'ies'}'),
              _Stat('Distance measured', '${_inr.format(eff.kmTracked.round())} km'),
              _Stat('Fuel used', '${_n(eff.litresUsed)} $qty'),
            ])
              SizedBox(width: w, child: tile),
          ]);
        }),
        const SizedBox(height: 10),
        Text(_basis(eff), style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4)),

        // ── monthly ──
        if (eff.monthly.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _Heading('Month by month'),
          for (final m in eff.monthly) _MonthRow(m: m, unit: eff.unit, rated: eff.rated, qty: qty),
        ],

        // ── fill-ups ──
        if (eff.intervals.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _Heading('Recent fill-ups'),
          for (final i in eff.intervals) _IntervalRow(i: i, unit: eff.unit, qty: qty),
        ],

        const SizedBox(height: 22),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('How this is worked out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            children: [
              Text(
                'Every fuel entry records the odometer and the $qty put in. Between two fill-ups, '
                'the km driven divided by the $qty in the later fill-up is the mileage. The first '
                'fill-up only sets the starting odometer. It is exact when every fill-up tops the '
                'tank up; part-fills average out over several fill-ups, so the more entries, the '
                'more reliable the figure.\n\n'
                '90% or more of the rated figure is Good, 75–90% is Watch, below 75% is Poor. '
                'Entries rejected by the manager are ignored.',
                style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _basis(VehicleEfficiency e) {
    switch (e.method) {
      case 'fill_ups':
        final conf = e.confidence == 'high' ? 'high' : 'medium';
        return 'Measured from ${e.fillUpsUsed} fill-ups ($conf confidence'
            '${e.confidence == 'medium' ? ' — it gets firmer with more entries' : ''}).';
      case 'trips':
        return 'Rough estimate: completed-trip km ÷ fuel bought. Add the odometer reading to fuel '
            'entries for an exact figure.';
      default:
        return 'Not enough fuel entries yet.';
    }
  }
}

class _Headline extends StatelessWidget {
  final VehicleEfficiency eff;
  final Color color;
  const _Headline({required this.eff, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final pct = eff.vsRatedPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_n(eff.actual!), style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: color, height: 1)),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(eff.unit, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textSecondary)),
            ),
            const Spacer(),
            if (eff.status != 'unknown') _Pill(efficiencyStatusLabel(eff.status).toUpperCase(), color, big: true),
          ],
        ),
        const SizedBox(height: 4),
        Text('actual', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        if (eff.rated != null) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ((eff.actual! / eff.rated!)).clamp(0.0, 1.0),
              backgroundColor: c.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text('Rated ${_n(eff.rated!)} ${eff.unit}', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
              ),
              if (pct != null) ...[
                const SizedBox(width: 12),
                Text('$pct% of rated', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _NoFigure extends StatelessWidget {
  final VehicleEfficiency eff;
  const _NoFigure({required this.eff});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.local_gas_station_outlined, color: c.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            eff.fillCount == 0
                ? 'No fuel entries yet. Once drivers log fuel with the litres and the odometer reading '
                    '(Add Expense, category Fuel), the real mileage appears here.'
                : 'Not enough to work out mileage yet. It needs at least two fuel entries that each '
                    'have the litres and the odometer reading.',
            style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _MonthRow extends StatelessWidget {
  final EfficiencyMonth m;
  final String unit;
  final double? rated;
  final String qty;
  const _MonthRow({required this.m, required this.unit, required this.rated, required this.qty});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final parsed = DateTime.tryParse('${m.month}-01');
    final label = parsed == null ? m.month : DateFormat('MMM yyyy').format(parsed);
    Color eColor = c.textSecondary;
    if (m.efficiency != null && rated != null && rated! > 0) {
      final pct = m.efficiency! / rated! * 100;
      eColor = pct >= 90 ? c.success : (pct >= 75 ? c.warning : c.destructive);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 74, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(
            child: Text(
              '${_n(m.km)} km · ${_n(m.liters)} $qty · ${_rupees(m.spend)}',
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            m.efficiency == null ? '—' : '${_n(m.efficiency!)} $unit',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: eColor),
          ),
        ],
      ),
    );
  }
}

class _IntervalRow extends StatelessWidget {
  final EfficiencyInterval i;
  final String unit;
  final String qty;
  const _IntervalRow({required this.i, required this.unit, required this.qty});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final date = i.date == null ? '' : DateFormat('d MMM').format(i.date!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 58, child: Text(date, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(
            child: Text(
              '${_inr.format(i.fromKm.round())} – ${_inr.format(i.toKm.round())} km · ${_n(i.liters)} $qty',
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (i.suspect)
            Tooltip(
              message: 'Looks wrong — left out of the average',
              child: Icon(Icons.warning_amber_rounded, size: 16, color: c.warning),
            ),
          const SizedBox(width: 6),
          Text(
            '${_n(i.efficiency)} $unit',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: i.suspect ? c.warning : c.textPrimary,
              decoration: i.suspect ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: context.crmColors.textSecondary,
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const _Stat(this.label, this.value, {this.sub});
  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          if (sub != null) Text(sub!, style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Note({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.4))),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final bool big;
  const _Pill(this.label, this.color, {this.big = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: big ? 10 : 8, vertical: big ? 5 : 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(big ? 8 : 6),
        ),
        child: Text(label, style: TextStyle(fontSize: big ? 12 : 11, fontWeight: FontWeight.w700, color: color)),
      );
}
