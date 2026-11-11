import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/fleet/data/expense_km_check.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/expense_work_split.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/map_link.dart';

export 'package:nizan_crm/features/fleet/presentation/widgets/map_link.dart' show mapLaunchUri;
import 'package:url_launcher/url_launcher.dart';

String _km(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
final _grouped = NumberFormat.decimalPattern('en_IN');

/// How the km check is worded and coloured: (text, colour, icon).
({String text, Color color, IconData icon}) kmCheckSummary(CrmTheme c, ExpenseKmCheck k) {
  switch (k.status) {
    case 'ok':
      return (
        text: 'Km check OK — odometer ${_km(k.trackedKm)} km vs planned ${_km(k.plannedTrackedKm ?? 0)} km'
            '${k.variancePercent == null ? '' : ' (${k.variancePercent! > 0 ? '+' : k.variancePercent! < 0 ? '−' : ''}${k.variancePercent!.abs()}%)'}.',
        color: c.success,
        icon: Icons.check_circle_outline,
      );
    case 'over':
    case 'under':
      final pct = k.variancePercent?.abs() ?? 0;
      return (
        text: 'Check the km — odometer ${_km(k.trackedKm)} km is $pct% '
            '${k.status == 'over' ? 'more' : 'less'} than the planned ${_km(k.plannedTrackedKm ?? 0)} km.',
        color: pct > 25 ? c.destructive : c.warning,
        icon: Icons.warning_amber_rounded,
      );
    case 'in_progress':
      return (
        text: 'The day\'s trips aren\'t all finished yet — km check pending.',
        color: c.textSecondary,
        icon: Icons.hourglass_empty,
      );
    case 'no_works':
      return (
        text: 'No work found for this driver on ${_dayText(k.dayKey)} — check this expense.',
        color: c.warning,
        icon: Icons.help_outline,
      );
    default:
      return (
        text: switch (k.routeState) {
          'missing' => 'Route for that day not calculated yet.',
          'stale' => 'A work on that day changed after the route was calculated.',
          _ => 'The route for that day couldn\'t be measured.',
        },
        color: c.textSecondary,
        icon: Icons.route_outlined,
      );
  }
}

String _dayText(String dayKey) {
  final d = DateTime.tryParse(dayKey);
  return d == null ? dayKey : DateFormat('d MMM').format(d);
}

/// Under an expense in Accounts: which work it was for and where, the fuel
/// detail, and the km check (route planned from HQ vs what the odometer says).
class ExpenseWorkCheck extends StatelessWidget {
  final FuelExpense expense;

  /// Show "Open day sheet" (only for roles that can load it).
  final bool canOpenDaySheet;
  final VoidCallback? onOpenDaySheet;

  const ExpenseWorkCheck({
    super.key,
    required this.expense,
    this.canOpenDaySheet = false,
    this.onOpenDaySheet,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final e = expense;
    final k = e.kmCheck;
    final split = e.split;
    // An outsourced driver's salary isn't a trip cost — nothing to check.
    if (e.category == 'outsource_salary') return const SizedBox.shrink();

    final place = [e.workAddress, e.workPincode].where((s) => s.isNotEmpty).join(' · ');
    final map = mapLaunchUri(e.workMapUrl);
    final fuel = e.category == 'fuel' && (e.liters > 0 || e.odometerKm > 0)
        ? [
            if (e.liters > 0) '${_km(e.liters)} L',
            if (e.odometerKm > 0) 'odometer ${_grouped.format(e.odometerKm.round())} km',
          ].join(' · ')
        : '';

    Widget line(IconData icon, Widget child, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 14, color: color ?? c.textSecondary),
              ),
              const SizedBox(width: 6),
              Expanded(child: child),
            ],
          ),
        );

    TextStyle small([Color? color, FontWeight? w]) =>
        TextStyle(fontSize: 12.5, color: color ?? c.textSecondary, fontWeight: w, height: 1.3);

    final summary = k == null ? null : kmCheckSummary(c, k);

    // Nothing real to show (an older server, and no work, place, fuel or km check):
    // no empty box.
    if (split == null && e.bookingId == null && place.isEmpty && map == null && fuel.isEmpty && summary == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      decoration: BoxDecoration(
        color: c.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // which work(s), who the artist is on each, and the share of each
          if (split != null)
            ExpenseWorkSplit(split: split)
          else ...[
            // an older server that doesn't send the split: just the linked work, if any
            // (never "whole day": without the server's answer that would be a guess)
            if (e.bookingId != null)
              line(
                Icons.work_outline,
                Text(
                  e.workLabel.isNotEmpty ? 'Work ${e.workLabel}' : 'Linked work',
                  style: small(c.textPrimary, FontWeight.w600),
                ),
              ),
            if (k != null && k.workMissing)
              line(
                Icons.warning_amber_rounded,
                Text('The work it was for is no longer on that day.', style: small(c.warning, FontWeight.w600)),
                color: c.warning,
              ),
          ],
          // where (each work row shows its own venue once the split is there)
          if (split == null && (place.isNotEmpty || map != null))
            line(
              Icons.place_outlined,
              Row(
                children: [
                  Expanded(child: Text(place.isEmpty ? 'Location on the map' : place, style: small())),
                  if (map != null)
                    InkWell(
                      onTap: () => launchUrl(map, mode: LaunchMode.externalApplication),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.map_outlined, size: 15, color: c.primary),
                          const SizedBox(width: 3),
                          Text('Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.primary)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          if (fuel.isNotEmpty) line(Icons.local_gas_station_outlined, Text(fuel, style: small())),
          // the km check
          if (summary != null) ...[
            line(summary.icon, Text(summary.text, style: small(summary.color, FontWeight.w600)), color: summary.color),
            if (k!.routeState == 'ok' && k.plannedKm != null && k.works > 0)
              line(
                Icons.route_outlined,
                Text(
                  'Day route ${_km(k.plannedKm!)} km from HQ and back'
                  '${(k.returnKm ?? 0) > 0 ? ' (${_km(k.returnKm!)} km of it the way home, not on the odometer)' : ''}'
                  '${k.workPlannedKm != null ? '. This work: planned ${_km(k.workPlannedKm!)} km'
                      '${k.workTrackedKm != null ? ', odometer ${_km(k.workTrackedKm!)} km' : ''}' : ''}.',
                  style: small(),
                ),
              ),
          ],
          if (canOpenDaySheet && k != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenDaySheet,
                icon: const Icon(Icons.route_outlined, size: 16),
                label: const Text('Open day sheet'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
              ),
            ),
        ],
      ),
    );
  }
}
