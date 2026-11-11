import 'package:flutter/material.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense_page.dart';

// The controls around Accounts → Fleet Expenses: the month / period bar, the
// advanced-filters form, the chips for what is switched on, the breakdown, and the
// bulk-action bar.

const kExpenseCategoryLabels = <String, String>{
  'fuel': 'Fuel',
  'food': 'Food',
  'toll': 'Toll',
  'parking': 'Parking',
  'service': 'Service / repair',
  'other': 'Other',
  'outsource_salary': 'Outsourced driver',
};

const kExpensePaymentLabels = <String, String>{
  'cash': 'Cash',
  'upi': 'UPI',
  'card': 'Card',
  'credit': 'Credit',
  'other': 'Other',
};

String categoryLabel(String key) => kExpenseCategoryLabels[key] ?? key;

String _rupees(double v) => rupeesWhole(v);

// ── advanced filters ─────────────────────────────────────────────────────────

/// Opens the advanced-filters form (a dialog on wide screens, a bottom sheet on a
/// phone). Returns the query with the chosen filters applied (page 1), or null.
Future<FuelExpenseQuery?> showExpenseFilters(
  BuildContext context, {
  required FuelExpenseQuery current,
  required List<NameOption> drivers,
  required List<NameOption> vehicles,
}) {
  final form = _FilterForm(current: current, drivers: drivers, vehicles: vehicles);
  if (ResponsiveBuilder.isMobile(context)) {
    return showModalBottomSheet<FuelExpenseQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => form,
    );
  }
  return showDialog<FuelExpenseQuery>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720), child: form),
    ),
  );
}

class _FilterForm extends StatefulWidget {
  final FuelExpenseQuery current;
  final List<NameOption> drivers;
  final List<NameOption> vehicles;
  const _FilterForm({required this.current, required this.drivers, required this.vehicles});

  @override
  State<_FilterForm> createState() => _FilterFormState();
}

class _FilterFormState extends State<_FilterForm> {
  late String? _driverId = widget.current.driverId;
  late String? _vehicleId = widget.current.vehicleId;
  late Set<String> _categories = {...widget.current.categories};
  late Set<String> _payments = {...widget.current.paymentModes};
  late String? _bill = widget.current.bill;
  late String? _work = widget.current.work;
  late final _min = TextEditingController(text: _fmt(widget.current.minAmount));
  late final _max = TextEditingController(text: _fmt(widget.current.maxAmount));
  String? _error;

  static String _fmt(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _driverId = null;
        _vehicleId = null;
        _categories = {};
        _payments = {};
        _bill = null;
        _work = null;
        _min.clear();
        _max.clear();
        _error = null;
      });

  void _apply() {
    double? parse(String t) => t.trim().isEmpty ? null : double.tryParse(t.trim().replaceAll(',', ''));
    final min = parse(_min.text);
    final max = parse(_max.text);
    if ((_min.text.trim().isNotEmpty && (min == null || min < 0)) ||
        (_max.text.trim().isNotEmpty && (max == null || max < 0))) {
      setState(() => _error = 'Amounts must be numbers, 0 or more.');
      return;
    }
    if (min != null && max != null && min > max) {
      setState(() => _error = 'The minimum is more than the maximum.');
      return;
    }
    Navigator.of(context).pop(widget.current.refiltered(
      driverId: _driverId,
      vehicleId: _vehicleId,
      categories: _categories,
      paymentModes: _payments,
      bill: _bill,
      work: _work,
      minAmount: min,
      maxAmount: max,
    ));
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: context.crmColors.textSecondary)),
      );

  Widget _dropdown(String label, String? value, List<NameOption> options, ValueChanged<String?> onChanged, String allLabel) {
    // A driver / vehicle that is no longer in the list must not crash the dropdown.
    final safe = options.any((o) => o.id == value) ? value : null;
    return DropdownButtonFormField<String?>(
      initialValue: safe,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
        for (final o in options) DropdownMenuItem<String?>(value: o.id, child: Text(o.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }

  Widget _segmented(String? value, Map<String?, String> options, ValueChanged<String?> onChanged) => SegmentedButton<String?>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [for (final e in options.entries) ButtonSegment<String?>(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 12.5)))],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      );

  Widget _multi(Map<String, String> labels, Set<String> selected) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in labels.entries)
            FilterChip(
              label: Text(e.value),
              selected: selected.contains(e.key),
              visualDensity: VisualDensity.compact,
              onSelected: (on) => setState(() => on ? selected.add(e.key) : selected.remove(e.key)),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              TextButton(onPressed: _reset, child: const Text('Reset')),
            ]),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Driver and vehicle'),
                    _dropdown('Driver', _driverId, widget.drivers, (v) => setState(() => _driverId = v), 'All drivers'),
                    const SizedBox(height: 12),
                    _dropdown('Vehicle', _vehicleId, widget.vehicles, (v) => setState(() => _vehicleId = v), 'All vehicles'),
                    _label('Category'),
                    _multi(kExpenseCategoryLabels, _categories),
                    _label('Payment mode'),
                    _multi(kExpensePaymentLabels, _payments),
                    _label('Bill'),
                    _segmented(_bill, const {null: 'Any', 'with': 'With bill', 'without': 'No bill'}, (v) => setState(() => _bill = v)),
                    _label('Tied to'),
                    _segmented(_work, const {null: 'Any', 'linked': 'One work', 'whole_day': 'Whole day'}, (v) => setState(() => _work = v)),
                    _label('Amount (₹)'),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          key: const Key('filterMin'),
                          controller: _min,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'From', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('filterMax'),
                          controller: _max,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'To', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ]),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error!, style: TextStyle(color: c.destructive, fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(key: const Key('applyFilters'), onPressed: _apply, child: const Text('Apply'))),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── what is switched on ──────────────────────────────────────────────────────

/// A removable chip for each filter that is on, and "Clear all".
class ActiveFilterChips extends StatelessWidget {
  final FuelExpenseQuery query;
  final String? driverName;
  final String? vehicleName;
  final ValueChanged<FuelExpenseQuery> onChanged;

  /// Clears every filter and the search (the period stays).
  final VoidCallback onClearAll;

  const ActiveFilterChips({
    super.key,
    required this.query,
    required this.driverName,
    required this.vehicleName,
    required this.onChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final q = query;
    String money(double v) => _rupees(v);
    final chips = <(String, VoidCallback)>[
      if (q.search.trim().isNotEmpty) ('Search: "${q.search.trim()}"', () => onChanged(q.refiltered(search: ''))),
      if (q.statuses.isNotEmpty)
        ('Status: ${(q.statuses.toList()..sort()).join(', ')}', () => onChanged(q.refiltered(statuses: <String>{}))),
      if (q.driverId != null) ('Driver: ${driverName ?? 'selected'}', () => onChanged(q.refiltered(driverId: null))),
      if (q.vehicleId != null) ('Vehicle: ${vehicleName ?? 'selected'}', () => onChanged(q.refiltered(vehicleId: null))),
      if (q.categories.isNotEmpty)
        ('Category: ${(q.categories.toList()..sort()).map(categoryLabel).join(', ')}', () => onChanged(q.refiltered(categories: <String>{}))),
      if (q.paymentModes.isNotEmpty)
        ('Payment: ${(q.paymentModes.toList()..sort()).map((p) => kExpensePaymentLabels[p] ?? p).join(', ')}',
            () => onChanged(q.refiltered(paymentModes: <String>{}))),
      if (q.bill != null) (q.bill == 'with' ? 'With bill' : 'No bill', () => onChanged(q.refiltered(bill: null))),
      if (q.work != null) (q.work == 'linked' ? 'Tied to one work' : 'Whole day', () => onChanged(q.refiltered(work: null))),
      if (q.minAmount != null || q.maxAmount != null)
        (
          'Amount: ${q.minAmount != null ? money(q.minAmount!) : '0'} – ${q.maxAmount != null ? money(q.maxAmount!) : 'any'}',
          () => onChanged(q.refiltered(minAmount: null, maxAmount: null)),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (label, remove) in chips)
          InputChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            onDeleted: remove,
            visualDensity: VisualDensity.compact,
            deleteIconColor: context.crmColors.textSecondary,
          ),
        TextButton(
          key: const Key('clearAll'),
          onPressed: onClearAll,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          child: const Text('Clear all'),
        ),
      ],
    );
  }
}

// ── breakdown ────────────────────────────────────────────────────────────────

/// Where the money went (by category and by driver) across the whole filtered set;
/// tapping a chip filters to it.
class ExpenseBreakdown extends StatelessWidget {
  final ExpenseSummary summary;
  final FuelExpenseQuery query;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onDriver;

  const ExpenseBreakdown({
    super.key,
    required this.summary,
    required this.query,
    required this.onCategory,
    required this.onDriver,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    if (summary.byCategory.isEmpty && summary.byDriver.isEmpty) return const SizedBox.shrink();

    Widget group(String title, List<Widget> chips) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: c.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        );

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
          if (summary.byCategory.isNotEmpty)
            group('By category', [
              for (final cat in summary.byCategory)
                ActionChip(
                  key: Key('cat_${cat.category}'),
                  label: Text('${categoryLabel(cat.category)}  ${_rupees(cat.amount)}', style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: query.categories.contains(cat.category) ? c.primary.withValues(alpha: 0.15) : null,
                  onPressed: () => onCategory(cat.category),
                ),
            ]),
          if (summary.byCategory.isNotEmpty && summary.byDriver.isNotEmpty) const SizedBox(height: 12),
          if (summary.byDriver.isNotEmpty)
            group('By driver', [
              for (final d in summary.byDriver)
                ActionChip(
                  key: Key('drv_${d.driverId}'),
                  label: Text('${d.name}  ${_rupees(d.amount)}', style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: query.driverId == d.driverId ? c.primary.withValues(alpha: 0.15) : null,
                  onPressed: () => onDriver(d.driverId),
                ),
            ]),
        ],
      ),
    );
  }
}

// ── bulk actions ─────────────────────────────────────────────────────────────

class BulkActionBar extends StatelessWidget {
  final int count;
  final double amount;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onClear;

  const BulkActionBar({
    super.key,
    required this.count,
    required this.amount,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withValues(alpha: 0.35)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$count selected · ${_rupees(amount)}', style: TextStyle(fontWeight: FontWeight.w800, color: c.primary)),
          if (busy)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            FilledButton.icon(
              key: const Key('bulkApprove'),
              onPressed: onApprove,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approve'),
              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, backgroundColor: c.success),
            ),
            OutlinedButton.icon(
              key: const Key('bulkReject'),
              onPressed: onReject,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: c.destructive),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ],
      ),
    );
  }
}
