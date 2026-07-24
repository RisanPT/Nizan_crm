import 'package:flutter/material.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

/// A single stat rendered inside [FleetStatStrip].
///
/// When [onTap] is provided the pill becomes an interactive filter chip and
/// [selected] controls its highlighted state.
class FleetStat {
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool selected;

  const FleetStat({
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
    this.selected = false,
  });
}

/// A row of evenly-sized KPI pills used at the top of every mobile fleet
/// screen. Gives an at-a-glance summary (and, on Assignments, doubles as the
/// filter control).
class FleetStatStrip extends StatelessWidget {
  final List<FleetStat> stats;
  const FleetStatStrip({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _StatPill(stat: stats[i])),
        ],
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final FleetStat stat;
  const _StatPill({required this.stat});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final selected = stat.selected;
    final valueColor = selected ? Colors.white : stat.color;
    final labelColor =
        selected ? Colors.white.withValues(alpha: 0.85) : crmColors.textSecondary;

    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 11),
      decoration: BoxDecoration(
        color: selected ? stat.color : stat.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? stat.color : stat.color.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: labelColor,
              height: 1.05,
            ),
          ),
        ],
      ),
    );

    if (stat.onTap == null) return pill;
    return GestureDetector(
      onTap: stat.onTap,
      behavior: HitTestBehavior.opaque,
      child: pill,
    );
  }
}

/// Standard header for the top of a mobile fleet screen: a bold title (with
/// optional subtitle) plus an optional primary action, followed by a strip of
/// [FleetStat] KPI pills.
class FleetMobileHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final List<FleetStat> stats;

  /// Optional secondary control shown to the left of the primary action
  /// (e.g. an Export button).
  final Widget? trailing;

  const FleetMobileHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.stats = const [],
    this.actionLabel,
    this.actionIcon = Icons.add,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: crmColors.textPrimary,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: crmColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 14),
          FleetStatStrip(stats: stats),
        ],
      ],
    );
  }
}

/// Centered empty-state used by the mobile fleet lists.
class FleetEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FleetEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: crmColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: crmColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: crmColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
