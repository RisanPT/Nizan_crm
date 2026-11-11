import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';

// The controls around the Accounts lists of artist COLLECTIONS and artist EXPENSES
// (Artist Finance, Finance & Invoices): search, sort and page size, status chips with
// counts, the advanced-filters form, the chips for what is switched on, and the
// breakdown. The month / period bar is in list_common.dart.

enum FinanceKind { collection, expense }

const kCollectionModeLabels = <String, String>{
  'cash': 'Cash',
  'upi': 'UPI',
  'bank_transfer': 'Bank transfer',
  'other': 'Other',
};

const kArtistExpenseCategoryLabels = <String, String>{
  'food': 'Food',
  'travel': 'Travel',
  'stay': 'Stay',
  'materials': 'Materials',
  'fuel': 'Fuel',
  'other': 'Other',
};

const kWorkTypeLabels = <String, String>{
  'bridal': 'Bridal work',
  'model_shoot': 'Model shoot',
};

/// The screenshot / receipt check the app runs on the amount.
const kOcrLabels = <String, String>{
  'match': 'Matches',
  'mismatch': 'Mismatch',
  'skipped': 'Not checked',
  'pending': 'Check pending',
};

const kFinanceStatusLabels = <String, String>{
  'pending': 'Pending',
  'verified': 'Verified',
  'rejected': 'Rejected',
};

String _label(Map<String, String> labels, String key) => labels[key] ?? key;

String _rupees(double v) => rupeesWhole(v);

// ── search / filters / sort / page size ──────────────────────────────────────

class FinanceToolbar extends StatefulWidget {
  final String search;
  final ValueChanged<String> onSearch;
  final String hint;
  final int advancedCount;
  final VoidCallback onFilters;
  final String sort;
  final ValueChanged<String> onSort;
  final int limit;
  final ValueChanged<int> onLimit;

  /// The sort choices (key → label); the default is newest / oldest / highest / lowest amount.
  final Map<String, String> sortLabels;

  const FinanceToolbar({
    super.key,
    required this.search,
    required this.onSearch,
    required this.hint,
    required this.advancedCount,
    required this.onFilters,
    required this.sort,
    required this.onSort,
    required this.limit,
    required this.onLimit,
    this.sortLabels = kListSortLabels,
  });

  @override
  State<FinanceToolbar> createState() => _FinanceToolbarState();
}

class _FinanceToolbarState extends State<FinanceToolbar> {
  late final _ctrl = TextEditingController(text: widget.search);
  Timer? _debounce;

  @override
  void didUpdateWidget(FinanceToolbar old) {
    super.didUpdateWidget(old);
    // "Clear all", or a chip's ✕, empties the search from outside.
    if (widget.search != old.search && widget.search.trim() != _ctrl.text.trim()) {
      _ctrl.text = widget.search;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && text.trim() != widget.search.trim()) widget.onSearch(text.trim());
    });
    setState(() {}); // the clear button
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBuilder.isMobile(context);

    final search = TextField(
      key: const Key('searchField'),
      controller: _ctrl,
      onChanged: _changed,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _ctrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _ctrl.clear();
                  setState(() {});
                  widget.onSearch('');
                },
              ),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final filters = Badge(
      isLabelVisible: widget.advancedCount > 0,
      label: Text('${widget.advancedCount}'),
      child: OutlinedButton.icon(
        key: const Key('filtersButton'),
        onPressed: widget.onFilters,
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: const Text('Filters'),
      ),
    );

    final sort = PopupMenuButton<String>(
      key: const Key('sortMenu'),
      tooltip: 'Sort',
      initialValue: widget.sort,
      onSelected: widget.onSort,
      itemBuilder: (_) => [
        for (final e in widget.sortLabels.entries) CheckedPopupMenuItem(value: e.key, checked: widget.sort == e.key, child: Text(e.value)),
      ],
      child: Chip(
        avatar: const Icon(Icons.sort_rounded, size: 18),
        label: Text(widget.sortLabels[widget.sort] ?? 'Sort', style: const TextStyle(fontSize: 12.5)),
        visualDensity: VisualDensity.compact,
      ),
    );

    final size = PopupMenuButton<int>(
      key: const Key('pageSizeMenu'),
      tooltip: 'Rows per page',
      initialValue: widget.limit,
      onSelected: widget.onLimit,
      itemBuilder: (_) => [
        for (final n in const [10, 20, 50, 100]) CheckedPopupMenuItem(value: n, checked: widget.limit == n, child: Text('$n per page')),
      ],
      child: Chip(
        label: Text('${widget.limit} / page', style: const TextStyle(fontSize: 12.5)),
        visualDensity: VisualDensity.compact,
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          search,
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [filters, sort, size]),
        ],
      );
    }
    return Row(children: [Expanded(child: search), const SizedBox(width: 10), filters, const SizedBox(width: 10), sort, const SizedBox(width: 6), size]);
  }
}

// ── a page that would not load ───────────────────────────────────────────────

/// A strip above the list for a page that failed to load, with "Try again". The last
/// page that did load stays on screen below it, so nothing is silently out of date.
class FinanceLoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const FinanceLoadError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: c.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.destructive.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: c.destructive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              friendlyErrorMessage(error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: c.textPrimary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

// ── status chips ─────────────────────────────────────────────────────────────

/// All / Pending / Verified / Rejected, each with its count (when the server sent totals).
class FinanceStatusChips extends StatelessWidget {
  final FinanceSummary? summary;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const FinanceStatusChips({super.key, required this.summary, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    String text(String s) {
      final name = s == 'all' ? 'All' : kFinanceStatusLabels[s]!;
      if (summary == null) return name;
      return '$name (${s == 'all' ? summary!.allCount : summary!.status(s).count})';
    }

    final current = selected.length == 1 ? selected.first : 'all';
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final s in const ['all', 'pending', 'verified', 'rejected'])
          ChoiceChip(
            key: Key('status_$s'),
            selected: current == s,
            label: Text(text(s)),
            onSelected: (_) => onChanged(s == 'all' ? <String>{} : {s}),
          ),
      ],
    );
  }
}

// ── what is switched on ──────────────────────────────────────────────────────

/// A removable chip for each (label, remove) pair, and "Clear all". Nothing when empty.
class ActiveChipsWrap extends StatelessWidget {
  final List<(String, VoidCallback)> chips;
  final VoidCallback onClearAll;
  const ActiveChipsWrap({super.key, required this.chips, required this.onClearAll});

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (text, remove) in chips)
          InputChip(
            label: Text(text, style: const TextStyle(fontSize: 12)),
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

/// A removable chip for each filter that is on, and "Clear all".
class FinanceActiveChips extends StatelessWidget {
  final FinanceQuery query;
  final FinanceKind kind;
  final String? artistName;
  final ValueChanged<FinanceQuery> onChanged;

  /// Clears every filter and the search (the period stays).
  final VoidCallback onClearAll;

  const FinanceActiveChips({
    super.key,
    required this.query,
    required this.kind,
    required this.artistName,
    required this.onChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final q = query;
    String names(Set<String> keys, Map<String, String> labels) => (keys.toList()..sort()).map((k) => _label(labels, k)).join(', ');
    final chips = <(String, VoidCallback)>[
      if (q.search.trim().isNotEmpty) ('Search: "${q.search.trim()}"', () => onChanged(q.refiltered(search: ''))),
      if (q.statuses.isNotEmpty) ('Status: ${names(q.statuses, kFinanceStatusLabels)}', () => onChanged(q.refiltered(statuses: <String>{}))),
      if (q.employeeId != null) ('Artist: ${artistName ?? 'selected'}', () => onChanged(q.refiltered(employeeId: null))),
      if (q.paymentModes.isNotEmpty) ('Payment: ${names(q.paymentModes, kCollectionModeLabels)}', () => onChanged(q.refiltered(paymentModes: <String>{}))),
      if (q.categories.isNotEmpty) ('Category: ${names(q.categories, kArtistExpenseCategoryLabels)}', () => onChanged(q.refiltered(categories: <String>{}))),
      if (q.workType != null) (_label(kWorkTypeLabels, q.workType!), () => onChanged(q.refiltered(workType: null))),
      if (q.bill != null)
        (
          q.bill == 'with'
              ? (kind == FinanceKind.collection ? 'With screenshot' : 'With receipt')
              : (kind == FinanceKind.collection ? 'No screenshot' : 'No receipt'),
          () => onChanged(q.refiltered(bill: null)),
        ),
      if (q.link != null)
        (
          switch (q.link) {
            'booking' => 'Tied to a booking',
            'trial' => 'Tied to a trial',
            _ => 'Not tied to anything',
          },
          () => onChanged(q.refiltered(link: null)),
        ),
      if (q.ocr.isNotEmpty) ('Check: ${names(q.ocr, kOcrLabels)}', () => onChanged(q.refiltered(ocr: <String>{}))),
      if (q.minAmount != null || q.maxAmount != null)
        (
          'Amount: ${q.minAmount != null ? _rupees(q.minAmount!) : '0'} – ${q.maxAmount != null ? _rupees(q.maxAmount!) : 'any'}',
          () => onChanged(q.refiltered(minAmount: null, maxAmount: null)),
        ),
    ];
    return ActiveChipsWrap(chips: chips, onClearAll: onClearAll);
  }
}

// ── breakdown ────────────────────────────────────────────────────────────────

class BreakdownGroup {
  final String title;
  final List<LabelTotal> rows;

  /// Key prefix for the chips (tests / automation): `${prefix}_${row.key}`.
  final String keyPrefix;
  final Map<String, String>? labels; // null = use the row's own name
  final bool Function(LabelTotal row) isOn;
  final ValueChanged<LabelTotal> onTap;

  const BreakdownGroup({
    required this.title,
    required this.rows,
    required this.keyPrefix,
    this.labels,
    required this.isOn,
    required this.onTap,
  });
}

/// Where the money went across the whole filtered set; tapping a chip filters to it.
class FinanceBreakdown extends StatelessWidget {
  final List<BreakdownGroup> groups;
  const FinanceBreakdown({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final shown = groups.where((g) => g.rows.isNotEmpty).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Text(shown[i].title.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: c.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in shown[i].rows)
                ActionChip(
                  key: Key('${shown[i].keyPrefix}_${r.key}'),
                  label: Text('${shown[i].labels == null ? r.name : _label(shown[i].labels!, r.key)}  ${_rupees(r.amount)}', style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: shown[i].isOn(r) ? c.primary.withValues(alpha: 0.15) : null,
                  onPressed: () => shown[i].onTap(r),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// "134 collections · ₹1,23,456" — how much the filtered list adds up to (the paging
/// footer says where in it you are), or "No collections".
String financeTotalText({required int total, double? amount, required String noun}) {
  if (total == 0) return 'No $noun';
  final name = total == 1 && noun.endsWith('s') ? noun.substring(0, noun.length - 1) : noun;
  return '$total $name${amount == null ? '' : '  ·  ${_rupees(amount)}'}';
}

// ── advanced filters ─────────────────────────────────────────────────────────

/// Opens the advanced-filters form (a dialog on wide screens, a bottom sheet on a
/// phone). Returns the query with the chosen filters applied (page 1), or null.
/// [artists] null / empty hides the artist picker (an artist sees only their own).
Future<FinanceQuery?> showFinanceFilters(
  BuildContext context, {
  required FinanceKind kind,
  required FinanceQuery current,
  List<NameOption>? artists,
}) {
  final form = _FinanceFilterForm(kind: kind, current: current, artists: artists ?? const []);
  if (ResponsiveBuilder.isMobile(context)) {
    return showModalBottomSheet<FinanceQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => form,
    );
  }
  return showDialog<FinanceQuery>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 740), child: form),
    ),
  );
}

class _FinanceFilterForm extends StatefulWidget {
  final FinanceKind kind;
  final FinanceQuery current;
  final List<NameOption> artists;
  const _FinanceFilterForm({required this.kind, required this.current, required this.artists});

  @override
  State<_FinanceFilterForm> createState() => _FinanceFilterFormState();
}

class _FinanceFilterFormState extends State<_FinanceFilterForm> {
  late String? _employeeId = widget.current.employeeId;
  late Set<String> _modes = {...widget.current.paymentModes};
  late Set<String> _categories = {...widget.current.categories};
  late String? _workType = widget.current.workType;
  late String? _bill = widget.current.bill;
  late String? _link = widget.current.link;
  late Set<String> _ocr = {...widget.current.ocr};
  late final _min = TextEditingController(text: _fmt(widget.current.minAmount));
  late final _max = TextEditingController(text: _fmt(widget.current.maxAmount));
  String? _error;

  bool get _isCollection => widget.kind == FinanceKind.collection;

  static String _fmt(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _employeeId = null;
        _modes = {};
        _categories = {};
        _workType = null;
        _bill = null;
        _link = null;
        _ocr = {};
        _min.clear();
        _max.clear();
        _error = null;
      });

  void _apply() {
    double? parse(String t) => t.trim().isEmpty ? null : double.tryParse(t.trim().replaceAll(',', ''));
    final min = parse(_min.text);
    final max = parse(_max.text);
    if ((_min.text.trim().isNotEmpty && (min == null || min < 0)) || (_max.text.trim().isNotEmpty && (max == null || max < 0))) {
      setState(() => _error = 'Amounts must be numbers, 0 or more.');
      return;
    }
    if (min != null && max != null && min > max) {
      setState(() => _error = 'The minimum is more than the maximum.');
      return;
    }
    Navigator.of(context).pop(widget.current.refiltered(
      employeeId: _employeeId,
      paymentModes: _modes,
      categories: _categories,
      workType: _workType,
      bill: _bill,
      link: _link,
      ocr: _ocr,
      minAmount: min,
      maxAmount: max,
    ));
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: context.crmColors.textSecondary)),
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

  Widget _segmented(String? value, Map<String?, String> options, ValueChanged<String?> onChanged) => SegmentedButton<String?>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [for (final e in options.entries) ButtonSegment<String?>(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 12.5)))],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.crmColors;
    final artistSafe = widget.artists.any((a) => a.id == _employeeId) ? _employeeId : null;
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
                    if (widget.artists.isNotEmpty) ...[
                      _title('Artist'),
                      DropdownButtonFormField<String?>(
                        initialValue: artistSafe,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Artist', border: OutlineInputBorder(), isDense: true),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All artists')),
                          for (final a in widget.artists) DropdownMenuItem<String?>(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _employeeId = v),
                      ),
                    ],
                    if (_isCollection) ...[
                      _title('Payment mode'),
                      _multi(kCollectionModeLabels, _modes),
                    ] else ...[
                      _title('Category'),
                      _multi(kArtistExpenseCategoryLabels, _categories),
                      _title('Work type'),
                      _segmented(_workType, {null: 'Any', ...kWorkTypeLabels}, (v) => setState(() => _workType = v)),
                    ],
                    _title(_isCollection ? 'Screenshot' : 'Receipt'),
                    _segmented(
                      _bill,
                      {null: 'Any', 'with': _isCollection ? 'With screenshot' : 'With receipt', 'without': _isCollection ? 'No screenshot' : 'No receipt'},
                      (v) => setState(() => _bill = v),
                    ),
                    _title('Tied to'),
                    _segmented(
                      _link,
                      _isCollection ? {null: 'Any', 'booking': 'Booking', 'trial': 'Trial', 'none': 'Neither'} : {null: 'Any', 'booking': 'A booking', 'none': 'Nothing'},
                      (v) => setState(() => _link = v),
                    ),
                    _title('Amount check'),
                    _multi(kOcrLabels, _ocr),
                    _title('Amount (₹)'),
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
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: c.destructive, fontSize: 12.5))),
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
