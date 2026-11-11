import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/day_sheet.dart';
import 'package:nizan_crm/services/employee_service.dart';

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final _money = NumberFormat.decimalPattern('en_IN');
String _rupees(double v) => '₹${_money.format(v == v.roundToDouble() ? v.round() : double.parse(v.toStringAsFixed(2)))}';
String _km(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
String _mins(int m) => m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60} min';

const _categoryNames = {
  'fuel': 'Fuel',
  'toll': 'Toll',
  'parking': 'Parking',
  'food': 'Food',
  'service': 'Service / repair',
  'other': 'Other',
  'outsource_salary': 'Outsourced driver',
};

const _categoryIcons = {
  'fuel': Icons.local_gas_station_outlined,
  'toll': Icons.toll_outlined,
  'parking': Icons.local_parking_outlined,
  'food': Icons.restaurant_outlined,
  'service': Icons.build_outlined,
};

/// One driver's day: where the vehicle goes (HQ → works → HQ), how far, how that
/// compares with the odometer, and the day's expenses under the works.
///
/// [driverMode] shows the signed-in driver's own day; otherwise a fleet manager
/// picks the driver.
class FleetDaySheetScreen extends HookConsumerWidget {
  final bool driverMode;

  /// Open on this driver / day (the link from Accounts' fleet expenses).
  final String? initialDriverId;
  final DateTime? initialDay;
  const FleetDaySheetScreen({super.key, this.driverMode = false, this.initialDriverId, this.initialDay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.crmColors;
    final date = useState(DateUtils.dateOnly(initialDay ?? DateTime.now()));
    final driverId = useState<String?>(driverMode ? null : initialDriverId);
    final refreshTick = useState(0);

    final drivers = driverMode
        ? const <Employee>[]
        : (ref.watch(employeesProvider).value ?? const <Employee>[])
            .where((e) => e.isDriver && (e.isActive || e.id == driverId.value))
            .toList();

    final query = (
      driverId: driverMode ? null : driverId.value,
      day: _day(date.value),
      refresh: refreshTick.value,
    );
    final ready = driverMode || driverId.value != null;
    final async = ready ? ref.watch(daySheetProvider(query)) : null;

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date.value,
        firstDate: DateTime(2024),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked != null) date.value = DateUtils.dateOnly(picked);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                driverMode ? 'My day' : 'Day sheet',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Route, distance and expenses for a driver\'s day. The vehicle starts at the '
                'headquarters and goes back there at the end.',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!driverMode)
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        key: const Key('daySheetDriver'),
                        isExpanded: true,
                        initialValue: driverId.value,
                        decoration: const InputDecoration(
                          labelText: 'Driver',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final d in drivers) DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => driverId.value = v,
                      ),
                    ),
                  IconButton.outlined(
                    tooltip: 'Previous day',
                    onPressed: () => date.value = date.value.subtract(const Duration(days: 1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  OutlinedButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(DateFormat('EEE, d MMM yyyy').format(date.value)),
                  ),
                  IconButton.outlined(
                    tooltip: 'Next day',
                    onPressed: () => date.value = date.value.add(const Duration(days: 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  if (!driverMode && ready)
                    IconButton.outlined(
                      tooltip: 'Recalculate the route',
                      onPressed: () => refreshTick.value += 1,
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (!ready)
                const _Empty(icon: Icons.person_search_outlined, text: 'Choose a driver to see their day.')
              else
                async!.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(daySheetProvider(query))),
                  data: (sheet) => _SheetBody(sheet: sheet, driverMode: driverMode),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  final DaySheet sheet;
  final bool driverMode;
  const _SheetBody({required this.sheet, required this.driverMode});

  @override
  Widget build(BuildContext context) {
    if (sheet.works.isEmpty && sheet.expenses.isEmpty) {
      return const _Empty(icon: Icons.event_available_outlined, text: 'No works on this day.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Summary(sheet: sheet),
        if (sheet.plan.planError.isNotEmpty || sheet.plan.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Warnings(plan: sheet.plan),
        ],
        if (sheet.works.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _Heading('Route'),
          _RouteCard(sheet: sheet),
          const SizedBox(height: 22),
          _Heading('Works (${sheet.works.length})'),
          for (final w in sheet.works) _WorkCard(work: w, multi: sheet.works.length > 1),
        ],
        const SizedBox(height: 22),
        _Heading('Expenses · ${_rupees(sheet.totals.amount)}'),
        if (sheet.expenses.isEmpty)
          const _Empty(icon: Icons.receipt_long_outlined, text: 'No expenses recorded for this day.', compact: true)
        else ...[
          for (final e in sheet.expenses) _ExpenseRow(expense: e, sheet: sheet),
          if (sheet.totals.unallocated > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _Note(
                icon: Icons.help_outline,
                color: context.crmColors.warning,
                text: '${_rupees(sheet.totals.unallocated)} isn\'t under any work: the work it was for has '
                    'moved to another day or been cancelled, or no work is left on this day.',
              ),
            ),
        ],
      ],
    );
  }
}

// ── summary ─────────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  final DaySheet sheet;
  const _Summary({required this.sheet});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final d = sheet.distance;
    final plan = sheet.plan;
    final hasPlan = plan.planError.isEmpty && sheet.works.isNotEmpty;
    final v = d.variance;
    final vColor = v == null
        ? c.textSecondary
        : v.percent.abs() <= 10
            ? c.success
            : (v.percent.abs() <= 25 ? c.warning : c.destructive);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth > 560 ? 4 : 2;
          final gap = 10.0;
          final w = (box.maxWidth - gap * (cols - 1)) / cols;
          Widget tile(String label, String value, {String? sub, Color? color}) => SizedBox(
                width: w,
                child: _Tile(label: label, value: value, sub: sub, color: color),
              );
          return Wrap(spacing: gap, runSpacing: gap, children: [
            tile('Planned km', hasPlan ? '${plan.approximate ? '≈ ' : ''}${_km(plan.plannedKm)}' : '—',
                sub: hasPlan && plan.plannedMin > 0 ? 'about ${_mins(plan.plannedMin)} driving' : null),
            tile('Odometer km', d.trackedKm > 0 ? _km(d.trackedKm) : '—', sub: 'from the trips'),
            tile('Expenses', _rupees(sheet.totals.amount),
                sub: '${sheet.expenses.length} entr${sheet.expenses.length == 1 ? 'y' : 'ies'}'),
            tile('Works', '${sheet.works.length}',
                sub: sheet.works.length > 1 ? 'in start order' : (sheet.works.isEmpty ? '' : 'there and back')),
          ]);
        }),
        if (hasPlan && d.returnKm > 0) ...[
          const SizedBox(height: 10),
          _Note(
            icon: Icons.info_outline,
            color: c.textSecondary,
            text: 'The trips\' odometer readings cover the way into each work; the way back to '
                '${sheet.hq.isEmpty ? 'the headquarters' : sheet.hq} (${_km(d.returnKm)} km) isn\'t on any trip. '
                'So compare the odometer with ${_km(d.plannedTrackedKm)} km, the plan without the way home.',
          ),
        ],
        if (v != null) ...[
          const SizedBox(height: 8),
          _Note(
            icon: v.percent.abs() <= 10 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: vColor,
            text: (v.km.abs() < 0.05
                    ? 'Odometer ${_km(d.trackedKm)} km matches the plan (${_km(d.plannedTrackedKm)} km).'
                    : 'Odometer ${_km(d.trackedKm)} km vs planned ${_km(d.plannedTrackedKm)} km: '
                        '${v.km >= 0 ? '+' : '−'}${_km(v.km.abs())} km (${v.percent >= 0 ? '+' : '−'}${v.percent.abs()}%).') +
                (d.estimatedDayKm != null ? ' Whole day about ${_km(d.estimatedDayKm!)} km with the way home.' : ''),
          ),
        ],
        if (sheet.fuelEstimate != null) ...[
          const SizedBox(height: 8),
          _Note(
            icon: Icons.local_gas_station_outlined,
            color: c.textSecondary,
            text: 'Expected fuel for the planned ${_km(plan.plannedKm)} km: about '
                '${_km(sheet.fuelEstimate!.units)} ${sheet.fuelEstimate!.unit == 'km/kWh' ? 'kWh' : (sheet.fuelEstimate!.unit == 'km/kg' ? 'kg' : 'L')} '
                '(at the rated ${_km(sheet.fuelEstimate!.ratedMileage)} ${sheet.fuelEstimate!.unit}).',
          ),
        ],
      ],
    );
  }
}

class _Warnings extends StatelessWidget {
  final DayPlan plan;
  const _Warnings({required this.plan});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    if (plan.planError.isNotEmpty) {
      return _Note(icon: Icons.error_outline, color: c.destructive, text: plan.planError);
    }
    return _Note(
      icon: Icons.warning_amber_rounded,
      color: c.warning,
      text: 'Some distances are approximate:\n${plan.warnings.map((w) => '• $w').join('\n')}',
    );
  }
}

// ── route ───────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final DaySheet sheet;
  const _RouteCard({required this.sheet});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final plan = sheet.plan;
    if (plan.legs.isEmpty) {
      return _Note(
        icon: Icons.route_outlined,
        color: c.textSecondary,
        text: plan.planError.isNotEmpty
            ? 'The route could not be calculated yet.'
            : 'No route yet — the works have no location (add a map link, address or pincode).',
      );
    }
    final title = plan.rule == 'round_trip'
        ? 'One work: there and back — the way back is the same as the way out, so the total is 2 × the one-way distance.'
        : 'Several works, in the order they start: from HQ to the first work, between the works, then back to HQ from the last.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4)),
          const SizedBox(height: 10),
          for (var i = 0; i < plan.legs.length; i++) _LegRow(leg: plan.legs[i], last: i == plan.legs.length - 1),
          const Divider(height: 22),
          Row(
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${plan.approximate ? '≈ ' : ''}${_km(plan.plannedKm)} km'
                  '${plan.plannedMin > 0 ? '  ·  ${_mins(plan.plannedMin)}' : ''}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  final DayLeg leg;
  final bool last;
  const _LegRow({required this.leg, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final icon = switch (leg.kind) {
      'out' => Icons.trip_origin,
      'return' => Icons.flag_outlined,
      'estimate' => Icons.straighten,
      _ => Icons.arrow_downward,
    };
    final measured = leg.km != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: leg.from),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 14, color: c.textSecondary),
                      ),
                    ),
                    TextSpan(text: leg.to),
                  ]),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (leg.mirrored)
                  Text('same as the way out', style: TextStyle(fontSize: 11.5, color: c.textSecondary))
                else if (leg.note.isNotEmpty)
                  Text(leg.note, style: TextStyle(fontSize: 11.5, color: c.warning)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            measured ? '${_km(leg.km!)} km' : 'unknown',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: measured ? null : c.warning),
          ),
        ],
      ),
    );
  }
}

// ── works ───────────────────────────────────────────────────────────────────

class _WorkCard extends StatelessWidget {
  final DayWork work;
  final bool multi;
  const _WorkCard({required this.work, required this.multi});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final time = work.start == null
        ? ''
        : DateFormat('h:mm a').format(work.start!) + (work.end == null ? '' : ' – ${DateFormat('h:mm a').format(work.end!)}');
    final done = work.tripStatus == 'completed';

    // Team vs vehicle.
    Widget? teamLine;
    if (work.team.count > 0) {
      final fits = work.team.fits;
      final suggestion = work.team.needsMultiple
          ? 'needs more than one vehicle'
          : 'suits ${work.team.suggestedLabel}';
      final text = fits == false
          ? '${work.team.count} people — this vehicle has ${work.vehicle!.seats} seats; $suggestion'
          : (fits == true ? '${work.team.count} people — fits this vehicle' : '${work.team.count} people — $suggestion');
      teamLine = Row(
        children: [
          Icon(
            fits == false ? Icons.warning_amber_rounded : Icons.groups_outlined,
            size: 15,
            color: fits == false ? c.destructive : c.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: fits == false ? c.destructive : c.textSecondary),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  work.label,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Chip(
                done ? 'Done' : (work.tripStatus == 'in_progress' ? 'On the way' : 'Not started'),
                done ? c.success : (work.tripStatus == 'in_progress' ? c.warning : c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [time, work.service, work.eventSlot].where((s) => s.isNotEmpty).join('  ·  '),
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 18, runSpacing: 6, children: [
            _Fact(Icons.route_outlined, work.located
                ? '${work.approximate ? '≈ ' : ''}${_km(work.plannedKm)} km planned${multi ? ' (its share)' : ''}'
                : 'location not found'),
            if (work.trackedKm != null) _Fact(Icons.speed_outlined, '${_km(work.trackedKm!)} km on the odometer'),
            if (work.vehicle != null)
              _Fact(Icons.directions_car_outlined,
                  [work.vehicle!.label, if (work.vehicle!.category.isNotEmpty) work.vehicle!.category.toUpperCase()].join(' · ')),
          ]),
          if (teamLine != null) ...[const SizedBox(height: 8), teamLine],
          if (work.costs.total > 0) ...[
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text('Expenses under this work', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                ),
                const SizedBox(width: 12),
                Text(_rupees(work.costs.total), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in work.costs.byCategory.entries)
                _Chip('${_categoryNames[e.key] ?? e.key} ${_rupees(e.value)}', c.textSecondary),
            ]),
            if (work.costs.shared > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_rupees(work.costs.direct)} charged to it directly + ${_rupees(work.costs.shared)} as its equal share of whole-day expenses',
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── expenses ────────────────────────────────────────────────────────────────

class _ExpenseRow extends StatelessWidget {
  final DayExpense expense;
  final DaySheet sheet;
  const _ExpenseRow({required this.expense, required this.sheet});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final e = expense;
    String where;
    Color whereColor = c.textSecondary;
    switch (e.mode) {
      case 'direct':
        where = 'Under ${sheet.workById(e.bookingId ?? '')?.label ?? 'a work'}';
      case 'shared':
        final amounts = e.allocations.map((a) => a.amount).toList();
        final equal = amounts.isNotEmpty && amounts.every((a) => (a - amounts.first).abs() < 0.005);
        where = equal
            ? 'Whole day · shared equally: ${_rupees(amounts.first)} to each of ${amounts.length} work${amounts.length == 1 ? '' : 's'}'
            : 'Whole day · shared equally: ${e.allocations.map((a) => '${_rupees(a.amount)} to ${sheet.workById(a.bookingId)?.bookingNumber ?? 'a work'}').join(', ')}';
      case 'rejected':
        where = 'Rejected — not counted';
        whereColor = c.destructive;
      default:
        where = e.reason.isNotEmpty ? e.reason : 'Not under any work';
        whereColor = c.warning;
    }
    final detail = [
      if (e.category == 'fuel' && e.liters > 0) '${_km(e.liters)} L',
      if (e.category == 'fuel' && e.odometerKm > 0) 'odometer ${_km(e.odometerKm)} km',
      if (e.station.isNotEmpty) e.station,
      if (e.notes.isNotEmpty) e.notes,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_categoryIcons[e.category] ?? Icons.receipt_long_outlined, size: 20, color: c.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_categoryNames[e.category] ?? e.category, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (detail.isNotEmpty) Text(detail, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                Text(where, style: TextStyle(fontSize: 12, color: whereColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _rupees(e.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  decoration: e.mode == 'rejected' ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                e.status == 'approved' ? 'Approved' : (e.status == 'rejected' ? 'Rejected' : 'Pending'),
                style: TextStyle(
                  fontSize: 11,
                  color: e.status == 'approved' ? c.success : (e.status == 'rejected' ? c.destructive : c.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── small pieces ────────────────────────────────────────────────────────────

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: context.crmColors.textSecondary),
        ),
      );
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? color;
  const _Tile({required this.label, required this.value, this.sub, this.color});
  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          if (sub != null) Text(sub!, style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Fact(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.crmColors.textSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: context.crmColors.textSecondary)),
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class _Note extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Note({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(10)),
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

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool compact;
  const _Empty({required this.icon, required this.text, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 50),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 28 : 48, color: c.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}
