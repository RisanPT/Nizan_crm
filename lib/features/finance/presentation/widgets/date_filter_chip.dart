import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';

/// A compact tappable chip for a report date filter. Shows [label] and the
/// picked [date] (or "All"); tapping opens a picker via [onTap], and a small ✕
/// clears it via [onClear] when a date is set.
class DateFilterChip extends StatelessWidget {
  const DateFilterChip({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final set = date != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 7, set && onClear != null ? 4 : 12, 7),
          decoration: BoxDecoration(
            color: set ? crm.primary.withValues(alpha: 0.10) : crm.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: set ? crm.primary.withValues(alpha: 0.5) : crm.border.faded(0.8)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_outlined, size: 15, color: set ? crm.primary : crm.textSecondary),
            const SizedBox(width: 6),
            Text(
              '$label: ${set ? DateFormat('d MMM yy').format(date!) : 'All'}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: set ? crm.primary : crm.textSecondary),
            ),
            if (set && onClear != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onClear,
                icon: Icon(Icons.close, size: 14, color: crm.primary),
              ),
          ]),
        ),
      ),
    );
  }
}
