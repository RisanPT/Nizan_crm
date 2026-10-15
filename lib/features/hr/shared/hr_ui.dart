import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';

/// Shared HR design kit — matches the approved HRMS design file (warm ground,
/// white cards with soft maroon-tinted shadows, the gold/maroon brand, and the
/// Plus Jakarta Sans display face for titles).

const _shadowBase = Color(0xFF320D15); // design shadow tint (rgba(50,13,21,…))

List<BoxShadow> hrCardShadow({bool elevated = false}) => [
      BoxShadow(
        color: _shadowBase.withValues(alpha: elevated ? 0.08 : 0.05),
        blurRadius: elevated ? 20 : 8,
        offset: Offset(0, elevated ? 8 : 2),
      ),
    ];

BoxDecoration hrCardDecoration(CrmTheme crm, {bool elevated = false, Color? borderColor}) => BoxDecoration(
      color: crm.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? crm.border),
      boxShadow: hrCardShadow(elevated: elevated),
    );

/// A surface card with the design's radius + soft shadow. Tappable when [onTap].
class HrCard extends StatelessWidget {
  const HrCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.elevated = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final card = Container(padding: padding, decoration: hrCardDecoration(crm, elevated: elevated), child: child);
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: card),
    );
  }
}

/// Section title in the design's display face.
class HrTitle extends StatelessWidget {
  const HrTitle(this.text, {super.key, this.size = 20});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: context.crmColors.textPrimary,
        height: 1.1,
      ),
    );
  }
}

/// Uppercase muted section label.
class HrSectionLabel extends StatelessWidget {
  const HrSectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w700,
          color: context.crmColors.textSecondary,
        ),
      ),
    );
  }
}

/// KPI stat card: tinted icon chip, big number, label.
class HrStatCard extends StatelessWidget {
  const HrStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
    this.width = 150,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = color ?? crm.primary;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: hrCardDecoration(crm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: c, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ],
      ),
    );
  }
}

/// Tinted status pill.
Widget hrStatusChip(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
