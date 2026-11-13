import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Design tokens matching the Artist Finance reference design.
class AfTheme {
  static const Color maroon = Color(0xFF7B1E3B);
  static const Color maroonDark = Color(0xFF63142C);
  static const Color maroonLight = Color(0xFFFFF0F4);

  static const Color green = Color(0xFF059669);
  static const Color greenLight = Color(0xFFE8F5E9);

  static const Color yellow = Color(0xFFD97706);
  static const Color yellowLight = Color(0xFFFFF8E1);

  static const Color red = Color(0xFFDC2626);
  static const Color redLight = Color(0xFFFEE2E2);

  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFFEDE9FE);

  static const Color coral = Color(0xFFE05A6F);
  static const Color coralLight = Color(0xFFFCE4EC);

  static const Color background = Color(0xFFF7F5F6);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFEDE7E9);
  static const Color textPrimary = Color(0xFF1E1B1D);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static final currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String formatCurrency(double amount) {
    return currencyFormat.format(amount);
  }
}

/// 5-item or 4-item KPI card matching reference designs.
class AfKpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String value;
  final String? subtext;
  final Color? subtextColor;

  const AfKpiCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.value,
    this.subtext,
    this.subtextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AfTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AfTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AfTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AfTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          if (subtext != null && subtext!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtext!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: subtextColor ?? AfTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status Pill Badge (Approved / Verified, Pending, Rejected)
class AfStatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const AfStatusBadge({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final isApproved = s == 'approved' || s == 'verified';
    final isPending = s == 'pending';
    final isRejected = s == 'rejected';

    final text = label ??
        (isApproved
            ? 'Approved'
            : isPending
                ? 'Pending'
                : isRejected
                    ? 'Rejected'
                    : status);

    final bg = isApproved
        ? AfTheme.greenLight
        : isPending
            ? AfTheme.yellowLight
            : AfTheme.redLight;

    final fg = isApproved
        ? AfTheme.green
        : isPending
            ? AfTheme.yellow
            : AfTheme.red;

    final icon = isApproved
        ? Icons.check
        : isPending
            ? Icons.access_time
            : Icons.close;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Category Pill (e.g. 🍴 Food, ✈ Travel, 🏨 Stay, ⛽ Fuel, 🛒 Shopping, ••• Others)
class AfCategoryBadge extends StatelessWidget {
  final String category;

  const AfCategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final cat = category.toLowerCase().trim();
    final (icon, label, color, bg) = switch (cat) {
      'food' => (Icons.restaurant_outlined, 'Food', const Color(0xFFC2185B), const Color(0xFFFFF0F4)),
      'travel' => (Icons.flight_outlined, 'Travel', const Color(0xFF1976D2), const Color(0xFFE3F2FD)),
      'stay' => (Icons.hotel_outlined, 'Stay', const Color(0xFF673AB7), const Color(0xFFEDE7F6)),
      'fuel' => (Icons.local_gas_station_outlined, 'Fuel', const Color(0xFFE65100), const Color(0xFFFFF3E0)),
      'shopping' || 'materials' => (Icons.shopping_bag_outlined, 'Shopping', const Color(0xFFC2185B), const Color(0xFFFCE4EC)),
      'bridal' || 'bridal work' => (Icons.diamond_outlined, 'Bridal Work', AfTheme.maroon, AfTheme.maroonLight),
      'event' => (Icons.event_outlined, 'Event', const Color(0xFF00897B), const Color(0xFFE0F2F1)),
      'model shoot' || 'model_shoot' => (Icons.camera_alt_outlined, 'Model Shoot', const Color(0xFF5E35B1), const Color(0xFFEDE7F6)),
      _ => (Icons.more_horiz, category.isEmpty ? 'Others' : category, const Color(0xFF616161), const Color(0xFFF5F5F5)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar circle with 2-letter initials (e.g. [FN], [AK], [AN])
class AfInitialsAvatar extends StatelessWidget {
  final String name;
  final double size;

  const AfInitialsAvatar({super.key, required this.name, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty
        ? 'A'
        : parts.length == 1
            ? parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase()
            : '${parts[0][0]}${parts[1][0]}'.toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AfTheme.coralLight,
        shape: BoxShape.circle,
        border: Border.all(color: AfTheme.coral.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: AfTheme.maroon,
        ),
      ),
    );
  }
}

/// Section Container Card with white background, rounded corners and light border.
class AfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AfTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AfTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

