import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart' show rupeesWhole;

String _clock(DateTime? t) => t == null ? '' : DateFormat('h:mm a').format(t.toLocal());

/// On a FOOD expense: the work it was eaten for, and why — "Lunch · 1:30 PM ➜ Beena · 1:00 PM – 4:00 PM".
/// Only drawn when the server sent an allocation (the Accounts screens ask for it).
class ExpenseAllocationLine extends StatelessWidget {
  final ArtistExpense expense;

  /// Opens the artist's day as a timeline; null hides the button.
  final VoidCallback? onDay;

  const ExpenseAllocationLine({super.key, required this.expense, this.onDay});

  @override
  Widget build(BuildContext context) {
    final a = expense.allocation;
    if (a == null || expense.category != 'food') return const SizedBox.shrink();
    final crm = context.crmColors;
    final placed = a.isPlaced;
    final accent = placed ? crm.primary : crm.warning;

    // One meal, or every meal a combined bill covers ("Breakfast + Lunch + Dinner").
    final covered = a.effectiveMeals.isNotEmpty ? a.effectiveMeals : expense.effectiveMeals;
    final meal = covered.isEmpty ? 'Food' : mealsLabel(covered);
    final at = covered.isEmpty ? '' : ' · ${_clock(a.mealAt ?? expense.date)}';
    final badge = switch (a.mode) {
      'pinned' => 'CHOSEN',
      'single' => 'ONLY WORK',
      'time' => 'BY TIME',
      'last' => 'LAST WORK',
      _ => '',
    };

    return Container(
      key: const Key('allocationLine'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(placed ? Icons.link_rounded : Icons.link_off_rounded, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (placed)
                  for (final s in a.shares) ...[
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '$meal$at  ', style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w600)),
                        // an icon, not a "→" character — not every font has that glyph
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.arrow_forward_rounded, size: 14, color: crm.textSecondary)),
                        ),
                        TextSpan(text: s.customerName.isEmpty ? 'Work' : s.customerName, style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w800)),
                        // when in the day the work is, then its hours: "Afternoon · 1:00 PM – 4:00 PM"
                        if (s.period.isNotEmpty)
                          TextSpan(text: '  ·  ${periodLabel(s.period)}', style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w700)),
                        if (s.serviceStart != null) ...[
                          TextSpan(
                            text: '  ·  ${_clock(s.serviceStart)}${s.serviceEnd != null ? ' – ${_clock(s.serviceEnd)}' : ''}',
                            style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          if (s.serviceStart!.toLocal().hour < 8)
                            const TextSpan(
                              text: '  ·  Early start < 8 AM',
                              style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w800),
                            ),
                        ],
                        if (s.bookingNumber.isNotEmpty) TextSpan(text: '  ·  ${s.bookingNumber}', style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w500)),
                      ]),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    // How far the work is — what Accounts checks the amount against before approving.
                    if (s.travelDistanceKm > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.route_outlined, size: 13, color: crm.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              travelDistanceText(s.travelDistanceKm),
                              key: const Key('allocationDistance'),
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
                            ),
                          ],
                        ),
                      ),
                  ]
                else
                  Text('$meal$at  —  not placed under a work', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                if (a.reason.isNotEmpty && a.mode != 'pinned')
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(a.reason, style: TextStyle(fontSize: 11.5, color: crm.textSecondary))),
                // The team's limit for this meal on the work: over it is flagged for Accounts.
                if (a.limit != null && a.limit!.isOver)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Team limit exceeded by ${rupeesWhole(a.limit!.over)} — ${a.limit!.meals.length > 1 ? mealsLabel(a.limit!.meals) : mealLabel(a.limit!.meal)} for the team '
                      '${rupeesWhole(a.limit!.teamTotal)} vs ${rupeesWhole(a.limit!.limit)} (${a.limit!.heads} × ${rupeesWhole(a.limit!.allowancePerHead)})',
                      key: const Key('allocationOverLimit'),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.destructive),
                    ),
                  ),
                if (a.isFar)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('CHECK THE TIME — far from any work', key: const Key('allocationFar'), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: crm.warning)),
                  ),
              ],
            ),
          ),
          if (badge.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 1),
              child: Text(badge, key: const Key('allocationBadge'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
            ),
          if (onDay != null)
            TextButton(
              key: const Key('allocationDay'),
              onPressed: onDay,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Day', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
