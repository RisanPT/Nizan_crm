import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart'
    show FleetDateRange;

// Shared building blocks for the fleet report screens (Km Report, Expenses).

final _inr = NumberFormat.decimalPattern('en_IN');

/// ₹12,34,567 (Indian grouping, no decimals).
String fleetInr(num v) => '₹${_inr.format(v.round())}';

/// ₹1.2Cr / ₹3.4L / ₹56.1k / ₹900 — for tight KPI tiles.
String fleetInrCompact(num v) {
  if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
  return '₹${v.round()}';
}

final _dayFmt = DateFormat('d MMM yyyy');
String fleetDay(DateTime d) => _dayFmt.format(d);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

enum FleetRangePreset { today, last7, thisMonth, lastMonth, last30, thisYear, custom }

const _presetLabels = {
  FleetRangePreset.today: 'Today',
  FleetRangePreset.last7: 'Last 7 days',
  FleetRangePreset.thisMonth: 'This month',
  FleetRangePreset.lastMonth: 'Last month',
  FleetRangePreset.last30: 'Last 30 days',
  FleetRangePreset.thisYear: 'This year',
};

/// The date range a preset stands for, as of today.
FleetDateRange fleetRangeFor(FleetRangePreset p) {
  final now = _day(DateTime.now());
  switch (p) {
    case FleetRangePreset.today:
      return (from: now, to: now);
    case FleetRangePreset.last7:
      return (from: now.subtract(const Duration(days: 6)), to: now);
    case FleetRangePreset.thisMonth:
      return (from: DateTime(now.year, now.month), to: now);
    case FleetRangePreset.lastMonth:
      return (
        from: DateTime(now.year, now.month - 1),
        to: DateTime(now.year, now.month, 0),
      );
    case FleetRangePreset.last30:
    case FleetRangePreset.custom:
      return (from: now.subtract(const Duration(days: 29)), to: now);
    case FleetRangePreset.thisYear:
      return (from: DateTime(now.year), to: now);
  }
}

/// Preset chips + a "Custom" date-range picker, with the active range shown.
class FleetDateRangeBar extends StatelessWidget {
  final FleetRangePreset preset;
  final FleetDateRange range;
  final void Function(FleetRangePreset preset, FleetDateRange range) onChanged;

  const FleetDateRangeBar({
    super.key,
    required this.preset,
    required this.range,
    required this.onChanged,
  });

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _day(DateTime.now()),
      initialDateRange: DateTimeRange(start: range.from, end: range.to),
      helpText: 'Select report dates',
    );
    if (picked != null) {
      onChanged(FleetRangePreset.custom,
          (from: _day(picked.start), to: _day(picked.end)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final days = range.to.difference(range.from).inDays + 1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range_rounded, size: 18, color: crm.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  range.from == range.to
                      ? fleetDay(range.from)
                      : '${fleetDay(range.from)}  →  ${fleetDay(range.to)}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: crm.textPrimary),
                ),
              ),
              Text('$days day${days == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in _presetLabels.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: preset == e.key,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onChanged(e.key, fleetRangeFor(e.key)),
                ),
              ChoiceChip(
                avatar: Icon(Icons.edit_calendar_outlined,
                    size: 16,
                    color: preset == FleetRangePreset.custom
                        ? null
                        : crm.primary),
                label: const Text('Custom…'),
                selected: preset == FleetRangePreset.custom,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => _pickCustom(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One KPI tile: big value, label, small caption.
class FleetKpi {
  final String value;
  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  const FleetKpi(this.value, this.label, this.caption, this.icon, this.color);
}

/// KPI tiles that wrap to 2 / 4 per row by width.
class FleetKpiGrid extends StatelessWidget {
  final List<FleetKpi> kpis;
  const FleetKpiGrid({super.key, required this.kpis});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth < 560 ? 2 : (box.maxWidth < 1000 ? 3 : 4);
      const gap = 10.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final k in kpis) SizedBox(width: w, child: _KpiTile(k: k)),
        ],
      );
    });
  }
}

class _KpiTile extends StatelessWidget {
  final FleetKpi k;
  const _KpiTile({required this.k});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: k.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(k.icon, size: 19, color: k.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(k.value,
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary)),
                ),
                Text(k.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: crm.textSecondary)),
                if (k.caption.isNotEmpty)
                  Text(k.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: crm.textSecondary.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded section card with a title row.
class FleetSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const FleetSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: crm.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: crm.textPrimary)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
