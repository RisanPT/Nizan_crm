import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/inventory_product.dart';
import '../../../core/theme/crm_theme.dart';

// ── Formatting helpers ──────────────────────────────────────────────────────

final _inr = NumberFormat('#,##0', 'en_IN');
String fmtINR(num v) => '₹${_inr.format(v)}';

int? daysLeft(DateTime? e) => e?.difference(DateTime.now()).inDays;

String fmtExp(DateTime? e) => e == null ? '—' : DateFormat('MMM yyyy').format(e);

/// Maroon→rose palette from the source design, indexed by category.
const _shades = [
  Color(0xFF4A0D18), Color(0xFF5C1120), Color(0xFF6E1423), Color(0xFF800020),
  Color(0xFF8F1D33), Color(0xFF9E2B43), Color(0xFFAD3A53), Color(0xFFBC4E64),
  Color(0xFFC96578), Color(0xFFD57F8E), Color(0xFFE19AA6), Color(0xFFEDB7C0),
];

Color categoryColor(String category) {
  final i = InventoryProduct.categories.indexOf(category);
  return _shades[(i < 0 ? InventoryProduct.categories.length - 1 : i) % _shades.length];
}

IconData productIcon(String category) {
  switch (category) {
    case 'Base':
      return Icons.opacity_rounded;
    case 'Eye':
      return Icons.remove_red_eye_outlined;
    case 'Lip':
      return Icons.favorite_border_rounded;
    case 'Setting':
    case 'Fixing':
    case 'Prep':
      return Icons.blur_on_rounded;
    case 'Hair':
      return Icons.content_cut_rounded;
    case 'Cheek':
    case 'Highlighting':
    case 'Contour':
      return Icons.brush_outlined;
    case 'Application':
    case 'Cleaner':
      return Icons.cleaning_services_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class InvHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  /// Optional secondary control shown left of the primary action (e.g. a scan
  /// button).
  final Widget? trailing;

  const InvHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.actionIcon = Icons.add,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                      letterSpacing: -0.4)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          trailing!,
        ],
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon, size: 18),
            label: Text(actionLabel!,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Stat cards ──────────────────────────────────────────────────────────────

class InvStat {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const InvStat(this.value, this.label, this.icon, this.color);
}

class InvStatGrid extends StatelessWidget {
  final List<InvStat> stats;
  final bool isMobile;
  const InvStatGrid({super.key, required this.stats, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.55 : 1.9,
      children: [for (final s in stats) _InvStatCard(stat: s)],
    );
  }
}

class _InvStatCard extends StatelessWidget {
  final InvStat stat;
  const _InvStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(stat.icon, color: stat.color, size: 18),
          ),
          const Spacer(),
          Text(stat.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: stat.color,
                  height: 1.0)),
          const SizedBox(height: 3),
          Text(stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: crm.textSecondary)),
        ],
      ),
    );
  }
}

// ── Status pill ─────────────────────────────────────────────────────────────

class StockPill extends StatelessWidget {
  final InventoryProduct product;
  const StockPill({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final out = product.isOut;
    final low = product.isLow;
    final color = out ? crm.destructive : (low ? const Color(0xFFB76E79) : crm.success);
    final label = out ? 'STOCK OUT' : (low ? 'LOW' : 'STOCK IN');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: out ? crm.destructive : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: out ? crm.destructive : color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: out ? Colors.white : color)),
    );
  }
}

// ── Tube gauge ──────────────────────────────────────────────────────────────

/// Horizontal "tube" showing the open tube's remaining fill (0–100%), with an
/// optional label row: "{spare full tubes} + {open %}". Works for both studio
/// products and per-artist kit allocations (pass quantity + fillLevel).
class TubeGauge extends StatelessWidget {
  final int quantity; // total tubes on hand (incl. the open one)
  final int fillLevel; // 0..100 of the open tube
  final double height;
  final bool showLabel;
  const TubeGauge({
    super.key,
    required this.quantity,
    required this.fillLevel,
    this.height = 10,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final out = quantity <= 0;
    final low = !out && fillLevel <= 20;
    final spares = quantity > 0 ? quantity - 1 : 0; // full, unopened tubes
    final frac = fillLevel.clamp(0, 100) / 100.0;
    final color =
        out ? crm.destructive : (low ? const Color(0xFFB76E79) : crm.success);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            children: [
              Text(out ? 'EMPTY' : '$fillLevel% open',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: color)),
              const Spacer(),
              Text(
                  out
                      ? 'no tubes'
                      : spares > 0
                          ? '+ $spares full tube${spares == 1 ? '' : 's'}'
                          : 'last tube',
                  style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Stack(
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                    color: crm.input,
                    borderRadius: BorderRadius.circular(height)),
              ),
              FractionallySizedBox(
                widthFactor: out ? 0.0 : frac.clamp(0.02, 1.0),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.65), color]),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section card + empty state ──────────────────────────────────────────────

class InvCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const InvCard(
      {super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: child,
    );
  }
}

class InvEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const InvEmpty(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: crm.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: crm.textSecondary)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  color: crm.textSecondary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

/// Shared loading/error wrapper for the inventory screens.
class InvBody extends StatelessWidget {
  final bool isMobile;
  final Widget child;
  const InvBody({super.key, required this.isMobile, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 0, isMobile ? 12 : 0, isMobile ? 16 : 0, 0),
      child: child,
    );
  }
}
