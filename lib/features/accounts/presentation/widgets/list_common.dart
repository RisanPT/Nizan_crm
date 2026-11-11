import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';

// Pieces shared by the Accounts lists (Fleet Expenses, Artist Finance, Finance &
// Invoices): the month / period bar, the sort options, and small helpers.

const kListSortLabels = <String, String>{
  'date_desc': 'Newest first',
  'date_asc': 'Oldest first',
  'amount_desc': 'Highest amount',
  'amount_asc': 'Lowest amount',
};

/// A driver / vehicle / artist for a dropdown.
typedef NameOption = ({String id, String name});

/// ₹1,23,456 — whole rupees, Indian grouping.
String rupeesWhole(double v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

// ── period ───────────────────────────────────────────────────────────────────

enum FinancePeriod { month, range, all }

/// ◀ October 2026 ▶  plus This month / Last month / All time / Custom range.
class FinancePeriodBar extends StatelessWidget {
  final FinancePeriod period;

  /// The month shown (any day in it) when [period] is [FinancePeriod.month].
  final DateTime month;
  final DateTimeRange? range;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTimeRange> onRange;
  final VoidCallback onAll;

  /// Offer "All time" (a report that can only cover a limited period turns it off).
  final bool allowAll;

  const FinancePeriodBar({
    super.key,
    required this.period,
    required this.month,
    required this.range,
    required this.onMonth,
    required this.onRange,
    required this.onAll,
    this.allowAll = true,
  });

  static DateTime thisMonth([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month);
  }

  bool get _isCurrent => period == FinancePeriod.month && _sameMonth(month, thisMonth());
  bool get _isLast =>
      period == FinancePeriod.month && _sameMonth(month, DateTime(thisMonth().year, thisMonth().month - 1));

  static bool _sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  String get _label => switch (period) {
        FinancePeriod.all => 'All time',
        FinancePeriod.range => range == null
            ? 'Custom range'
            : '${DateFormat('d MMM yyyy').format(range!.start)} – ${DateFormat('d MMM yyyy').format(range!.end)}',
        FinancePeriod.month => DateFormat('MMMM yyyy').format(month),
      };

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showMonthPicker(context, initial: month, minYear: 2020, maxYear: DateTime.now().year);
    if (picked != null) onMonth(DateTime(picked.year, picked.month));
  }

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showBrandedDateRangePicker(
      context,
      initialDateRange: range,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Show entries between',
    );
    if (picked != null) onRange(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final canStep = period == FinancePeriod.month;
    final canGoNext = canStep && !_isCurrent && month.isBefore(thisMonth());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.outlined(
                key: const Key('periodPrev'),
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
                onPressed: () => onMonth(DateTime(
                  (canStep ? month : thisMonth()).year,
                  (canStep ? month : thisMonth()).month - 1,
                )),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  key: const Key('periodLabel'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _pickMonth(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 18, color: c.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: c.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                key: const Key('periodNext'),
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
                onPressed: canGoNext ? () => onMonth(DateTime(month.year, month.month + 1)) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('This month'),
                selected: _isCurrent,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onMonth(thisMonth()),
              ),
              ChoiceChip(
                label: const Text('Last month'),
                selected: _isLast,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onMonth(DateTime(thisMonth().year, thisMonth().month - 1)),
              ),
              if (allowAll)
                ChoiceChip(
                  key: const Key('periodAll'),
                  label: const Text('All time'),
                  selected: period == FinancePeriod.all,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onAll(),
                ),
              ChoiceChip(
                key: const Key('periodRange'),
                label: const Text('Custom range…'),
                selected: period == FinancePeriod.range,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => _pickRange(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

