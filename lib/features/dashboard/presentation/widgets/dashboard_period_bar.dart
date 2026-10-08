import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
import 'package:nizan_crm/features/dashboard/data/dashboard_analytics.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart';

/// The one filter row on the analytics tabs: a month picker, a custom range,
/// and (Sales only) a salesperson picker listing sales roles only.
class DashboardPeriodBar extends StatelessWidget {
  final DashboardQuery query;
  final ValueChanged<DashboardQuery> onChanged;

  /// Salesperson options; null hides the picker.
  final List<Salesperson>? salespeople;

  const DashboardPeriodBar({super.key, required this.query, required this.onChanged, this.salespeople});

  static List<DateTime> _months() {
    final n = DateTime.now();
    return List.generate(24, (i) => DateTime(n.year, n.month - i, 1));
  }

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showBrandedDateRangePicker(
      context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDateRange: DateTimeRange(start: query.from, end: query.to),
      helpText: 'Custom range',
    );
    if (picked != null) {
      onChanged(DashboardQuery.range(picked.start, picked.end, basis: query.basis, salesPersonId: query.salesPersonId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMonth = query.isMonth;
    final monthLabel = DateFormat('MMMM yyyy').format(query.from);
    final rangeLabel = '${DateFormat('d MMM yy').format(query.from)} – ${DateFormat('d MMM yy').format(query.to)}';
    final sp = salespeople;
    final selected = sp?.where((p) => p.id == query.salesPersonId).firstOrNull;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MenuChip<DateTime>(
          icon: Icons.calendar_month_rounded,
          label: isMonth ? monthLabel : 'Month',
          active: isMonth,
          items: [for (final m in _months()) (m, DateFormat('MMMM yyyy').format(m))],
          onSelected: (m) => onChanged(DashboardQuery.month(m, basis: query.basis, salesPersonId: query.salesPersonId)),
        ),
        _Chip(
          icon: Icons.date_range_rounded,
          label: isMonth ? 'Custom range' : rangeLabel,
          active: !isMonth,
          onTap: () => _pickRange(context),
        ),
        if (sp != null && sp.isNotEmpty)
          _MenuChip<String>(
            icon: Icons.person_outline_rounded,
            label: selected?.name ?? 'All salespeople',
            active: selected != null,
            items: [('', 'All salespeople'), for (final p in sp) (p.id, p.name)],
            onSelected: (id) => onChanged(query.withSalesperson(id)),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Compared with ${query.prevLabel}', style: dashText(12, color: kDashMuted)),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: _pill(icon, label, active, trailing: null),
      );
}

Widget _pill(IconData icon, String label, bool active, {IconData? trailing}) => Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: active ? kBrand.withValues(alpha: 0.07) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? kBrand : const Color(0xFFD8D3CE), width: 1.2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: active ? kBrand : kDashMuted),
        const SizedBox(width: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: dashText(12.5, weight: FontWeight.w600, color: active ? kBrand : const Color(0xFF4B5563))),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          Icon(trailing, size: 17, color: active ? kBrand : kDashMuted),
        ],
      ]),
    );

/// Pill that opens a menu of (value, label) options.
class _MenuChip<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final List<(T, String)> items;
  final ValueChanged<T> onSelected;

  const _MenuChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
        tooltip: '',
        onSelected: onSelected,
        constraints: const BoxConstraints(maxHeight: 420, minWidth: 200),
        itemBuilder: (_) => [
          for (final it in items) PopupMenuItem<T>(value: it.$1, child: Text(it.$2, style: dashText(13))),
        ],
        child: _pill(icon, label, active, trailing: Icons.keyboard_arrow_down_rounded),
      );
}
