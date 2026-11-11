import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

import '../../data/stylist_client.dart';

// ── Company ──────────────────────────────────────────────────────────────────
/// Team N = rose, Nizan = violet: the same colours everywhere a client shows.
Color companyColor(String company) =>
    company == 'Nizan' ? const Color(0xFF534AB7) : const Color(0xFF993556);

class CompanyTag extends StatelessWidget {
  const CompanyTag(this.company, {super.key});

  final String company;

  @override
  Widget build(BuildContext context) {
    if (company.isEmpty) return const SizedBox.shrink();
    final color = companyColor(company);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(company, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

Color clientStatusTone(CrmTheme crm, String status) => switch (status) {
      'Completed' => crm.success,
      'Cancelled' => crm.destructive,
      _ => crm.primary,
    };

// ── Call progress ────────────────────────────────────────────────────────────
/// One dot per required call (filled = completed, tinted = booked), plus
/// "+N" for extra calls.
class CallProgressDots extends StatelessWidget {
  const CallProgressDots({super.key, required this.done, required this.required, this.booked = 0, this.size = 10});

  final int done;
  final int required;

  /// Calls booked but not yet done, shown after the completed ones.
  final int booked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final extra = done > required ? done - required : 0;
    return Semantics(
      label: '$done of $required calls done',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < required; i++)
            Container(
              width: size,
              height: size,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < done
                    ? crm.success
                    : i < done + booked
                        ? crm.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                border: Border.all(
                    color: i < done
                        ? crm.success
                        : i < done + booked
                            ? crm.primary
                            : crm.textSecondary.withValues(alpha: 0.5)),
              ),
            ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text('+$extra', style: TextStyle(fontSize: 11, color: crm.success, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── Dates ────────────────────────────────────────────────────────────────────
/// "14 Dec 2026", "14–15 Dec 2026", "30 Dec 2026 – 2 Jan 2027" or
/// "14, 16 and 20 Dec 2026" for a client's event days.
String fmtEventDays(List<DateTime> days) {
  if (days.isEmpty) return '';
  final full = DateFormat('d MMM yyyy');
  if (days.length == 1) return full.format(days.first);
  final first = days.first;
  final last = days.last;
  final consecutive = last.difference(first).inDays == days.length - 1;
  final sameMonth = first.year == last.year && first.month == last.month;
  if (consecutive) {
    return sameMonth
        ? '${first.day}–${full.format(last)}'
        : '${full.format(first)} – ${full.format(last)}';
  }
  if (sameMonth && days.length <= 4) {
    final heads = days.sublist(0, days.length - 1).map((d) => '${d.day}').join(', ');
    return '$heads and ${full.format(last)}';
  }
  return '${full.format(first)} + ${days.length - 1} more';
}

/// "Today", "Tomorrow", "In 5 days" or "In 3 weeks" until the event.
String fmtDaysToEvent(int days) {
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days < 14) return 'In $days days';
  if (days < 60) return 'In ${(days / 7).round()} weeks';
  return 'In ${(days / 30).round()} months';
}

/// A short line of who and when for a client row.
String clientEventLine(StylistClient c) => [
      if (c.eventType.isNotEmpty) c.eventType,
      if (c.eventDays.isNotEmpty) fmtEventDays(c.eventDays),
      if (c.venue.isNotEmpty) c.venue.split(',').first.trim(),
      if (c.bookingNumber.isNotEmpty) c.bookingNumber,
    ].join('  ·  ');
