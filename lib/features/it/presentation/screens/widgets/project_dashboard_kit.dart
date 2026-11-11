import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/project_dashboard_stats.dart';

// The small pieces the project dashboard cards are built from, so every card looks like one family.

/// What each kind of project is drawn in, on every chart of the dashboard.
Color bucketColor(ProjectBucket b) => switch (b) {
  ProjectBucket.completed => const Color(0xFF22A06B),
  ProjectBucket.inProgress => const Color(0xFF3B82F6),
  ProjectBucket.onHold => const Color(0xFFF5A524),
  ProjectBucket.notStarted => const Color(0xFF9AA0A6),
  ProjectBucket.cancelled => const Color(0xFFDC4C4C),
};

const _deptPalette = <Color>[
  Color(0xFF3B82F6),
  Color(0xFF22A06B),
  Color(0xFF8B5CF6),
  Color(0xFFF08A24),
  Color(0xFFE5484D),
  Color(0xFF14B8A6),
  Color(0xFFD6409F),
  Color(0xFF9AA0A6),
];

/// A department's colour by its place in the list, so the donut and its legend agree.
Color deptColor(int index) => _deptPalette[index % _deptPalette.length];

/// A coloured status word (or number) in a rounded pill.
class DashPill extends StatelessWidget {
  const DashPill(this.text, this.color, {super.key, this.icon, this.solid = false});
  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: solid ? color : color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: fg), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card: a tinted icon, a title (and what it is about), anything on the right, then the content.
class DashCard extends StatelessWidget {
  const DashCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final tint = iconColor ?? crm.primary;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 15, color: tint),
                ),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.2),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// "View All →" at the corner of a card.
class DashLink extends StatelessWidget {
  const DashLink(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.primary),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_forward_rounded, size: 13, color: crm.primary),
          ],
        ),
      ),
    );
  }
}

/// A row of options of which one is chosen — the chosen one filled with the brand colour.
class DashSegmented<T> extends StatelessWidget {
  const DashSegmented({super.key, required this.options, required this.value, required this.onChanged, this.keyPrefix, this.dense = false});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Gives each option the key `<keyPrefix>_<index>` (for tests).
  final String? keyPrefix;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            InkWell(
              key: keyPrefix == null ? null : Key('${keyPrefix}_$i'),
              borderRadius: BorderRadius.circular(17),
              onTap: () => onChanged(options[i].$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.symmetric(horizontal: dense ? 11 : 14, vertical: dense ? 5 : 7),
                decoration: BoxDecoration(color: options[i].$1 == value ? crm.primary : Colors.transparent, borderRadius: BorderRadius.circular(17)),
                child: Text(
                  options[i].$2,
                  style: TextStyle(
                    fontSize: dense ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: options[i].$1 == value ? Colors.white : crm.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A centred line saying there is nothing to show (and why).
class DashEmpty extends StatelessWidget {
  const DashEmpty(this.text, {super.key, this.icon = Icons.inbox_outlined, this.height = 110});
  final String text;
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: crm.textSecondary.withValues(alpha: 0.55)),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card's content while it loads, or when it could not.
class DashStatus extends StatelessWidget {
  const DashStatus.loading({super.key, this.height = 110}) : error = false, onRetry = null;
  const DashStatus.failed({super.key, this.height = 110, this.onRetry}) : error = true;

  final bool error;
  final double height;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (!error) {
      return SizedBox(
        height: height,
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 22, color: crm.textSecondary),
            const SizedBox(height: 6),
            Text('Could not load this.', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// "3 Nov" / "3 Nov 2027" — the year only when it is not this one.
String shortDate(DateTime d, DateTime now) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return d.year == now.year ? '${d.day} ${m[d.month - 1]}' : '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// "Jan 2026" for the date-range button.
String monthYear(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.year}';
}
