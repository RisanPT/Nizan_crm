import 'package:flutter/material.dart';

/// Lead priority (how likely it is to close), kept separate from the pipeline
/// status so a lead can be "Follow-up" *and* "Hot" at the same time.
class LeadPriority {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String hint;

  const LeadPriority(
      this.value, this.label, this.icon, this.color, this.hint);

  static const hot = LeadPriority('Hot', 'Hot', Icons.local_fire_department,
      Color(0xFFEF4444), 'Ready to book — act today');
  static const warm = LeadPriority('Warm', 'Warm', Icons.wb_sunny_outlined,
      Color(0xFFF59E0B), 'Interested — keep following up');
  static const cold = LeadPriority('Cold', 'Cold', Icons.ac_unit,
      Color(0xFF3B82F6), 'Just enquiring — low intent');

  static const all = [hot, warm, cold];

  static LeadPriority of(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'hot':
        return hot;
      case 'cold':
        return cold;
      default:
        return warm;
    }
  }
}

/// Compact colour-coded chip used in lists and detail headers.
class LeadPriorityChip extends StatelessWidget {
  final String priority;
  final bool dense;

  const LeadPriorityChip(this.priority, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final p = LeadPriority.of(priority);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 9, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: p.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(p.icon, size: dense ? 11 : 13, color: p.color),
          const SizedBox(width: 4),
          Text(
            p.label,
            style: TextStyle(
              fontSize: dense ? 10 : 11.5,
              fontWeight: FontWeight.w800,
              color: p.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented Hot / Warm / Cold selector for forms — one tap, no dropdown.
class LeadPrioritySelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool showHint;

  const LeadPrioritySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.showHint = true,
  });

  @override
  Widget build(BuildContext context) {
    final selected = LeadPriority.of(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in LeadPriority.all)
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onChanged(p.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: p.value == selected.value
                        ? p.color.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: p.value == selected.value
                          ? p.color
                          : Theme.of(context).dividerColor,
                      width: p.value == selected.value ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p.icon,
                          size: 15,
                          color: p.value == selected.value
                              ? p.color
                              : Theme.of(context).hintColor),
                      const SizedBox(width: 6),
                      Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: p.value == selected.value
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: p.value == selected.value
                              ? p.color
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (showHint) ...[
          const SizedBox(height: 6),
          Text(selected.hint,
              style: TextStyle(
                  fontSize: 11, color: Theme.of(context).hintColor)),
        ],
      ],
    );
  }
}
