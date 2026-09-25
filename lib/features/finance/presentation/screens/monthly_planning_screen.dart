import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/month_year_picker.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';

const _monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

/// Finance → Monthly Planning: the first-working-day planning meeting. Set the
/// month's revenue/profit/collection targets, an expense limit, and a
/// department budget allocation. The Month-End Review measures actuals vs these.
class MonthlyPlanningScreen extends ConsumerStatefulWidget {
  const MonthlyPlanningScreen({super.key});

  @override
  ConsumerState<MonthlyPlanningScreen> createState() => _MonthlyPlanningScreenState();
}

class _MonthlyPlanningScreenState extends ConsumerState<MonthlyPlanningScreen> {
  late int _month;
  late int _year;

  final _revenue = TextEditingController();
  final _profit = TextEditingController();
  final _collection = TextEditingController();
  final _expenseLimit = TextEditingController();
  final _notes = TextEditingController();
  List<({TextEditingController name, TextEditingController amount})> _alloc = [];

  int? _loadedFor; // month*100+year currently populated into the fields
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Plan the NEXT month by default (planning meeting is for the month ahead).
    final now = DateTime.now();
    var m = now.month + 1, y = now.year;
    if (m > 12) { m = 1; y++; }
    _month = m;
    _year = y;
  }

  @override
  void dispose() {
    for (final c in [_revenue, _profit, _collection, _expenseLimit, _notes]) {
      c.dispose();
    }
    for (final a in _alloc) { a.name.dispose(); a.amount.dispose(); }
    super.dispose();
  }

  Period get _key => (month: _month, year: _year);
  int get _stamp => _month * 100 + _year;

  void _shift(int delta) {
    setState(() {
      var m = _month + delta, y = _year;
      if (m < 1) { m = 12; y--; }
      if (m > 12) { m = 1; y++; }
      _month = m;
      _year = y;
      _loadedFor = null; // repopulate for the new month
    });
  }

  double _val(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  void _populate(MonthlyTarget t) {
    _revenue.text = t.revenueTarget == 0 ? '' : t.revenueTarget.toStringAsFixed(0);
    _profit.text = t.profitTarget == 0 ? '' : t.profitTarget.toStringAsFixed(0);
    _collection.text = t.collectionTarget == 0 ? '' : t.collectionTarget.toStringAsFixed(0);
    _expenseLimit.text = t.expenseLimit == 0 ? '' : t.expenseLimit.toStringAsFixed(0);
    _notes.text = t.notes;
    for (final a in _alloc) { a.name.dispose(); a.amount.dispose(); }
    _alloc = t.allocations
        .map((a) => (
              name: TextEditingController(text: a.name),
              amount: TextEditingController(text: a.amount == 0 ? '' : a.amount.toStringAsFixed(0)),
            ))
        .toList();
    if (_alloc.isEmpty) _addAllocation();
    _loadedFor = _stamp;
  }

  void _addAllocation() {
    _alloc.add((name: TextEditingController(), amount: TextEditingController()));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final target = MonthlyTarget(
      month: _month,
      year: _year,
      revenueTarget: _val(_revenue),
      profitTarget: _val(_profit),
      collectionTarget: _val(_collection),
      expenseLimit: _val(_expenseLimit),
      notes: _notes.text.trim(),
      allocations: _alloc
          .where((a) => a.name.text.trim().isNotEmpty)
          .map((a) => TargetAllocation(a.name.text.trim(), _val(a.amount)))
          .toList(),
    );
    try {
      await ref.read(monthEndServiceProvider).saveTarget(target);
      ref.refreshData.monthEnd();
      if (mounted) showSuccessSnackBar(context, 'Targets saved for ${_monthNames[_month]} $_year');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(monthlyTargetProvider(_key));
    // Populate fields once per month load.
    async.whenData((t) {
      if (_loadedFor != _stamp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _loadedFor != _stamp) setState(() => _populate(t));
        });
      }
    });

    return Scaffold(
      backgroundColor: crm.background,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(monthlyTargetProvider(_key))),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            _monthBar(crm),
            14.h,
            _card(crm, 'Monthly Targets', Icons.flag_outlined, [
              _field(crm, _revenue, 'Revenue target', prefix: '₹'),
              _field(crm, _profit, 'Profit target', prefix: '₹'),
              _field(crm, _collection, 'Cash collection target', prefix: '₹'),
              _field(crm, _expenseLimit, 'Expense limit', prefix: '₹'),
            ]),
            14.h,
            _allocationCard(crm),
            14.h,
            _card(crm, 'Notes', Icons.sticky_note_2_outlined, [
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Strategic priorities, decisions, context for the month…',
                  border: OutlineInputBorder(),
                ),
              ),
            ]),
            18.h,
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Save plan for ${_monthNames[_month]} $_year'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthYearPicker(context, month: _month, year: _year);
    if (picked != null) {
      setState(() {
        _month = picked.month;
        _year = picked.year;
        _loadedFor = null;
      });
    }
  }

  Widget _monthBar(CrmTheme crm) {
    return Row(children: [
      IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
      Expanded(
        child: InkWell(
          onTap: _pickMonth,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              Text('Monthly Planning', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${_monthNames[_month]} $_year', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                4.w,
                Icon(Icons.arrow_drop_down, color: crm.textSecondary),
              ]),
            ]),
          ),
        ),
      ),
      IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
    ]);
  }

  Widget _card(CrmTheme crm, String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.faded(0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 18, color: crm.primary), 8.w, Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary))]),
        12.h,
        ...children,
      ]),
    );
  }

  Widget _field(CrmTheme crm, TextEditingController c, String label, {String? prefix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _allocationCard(CrmTheme crm) {
    final total = _alloc.fold<double>(0, (s, a) => s + _val(a.amount));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.faded(0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.pie_chart_outline, size: 18, color: crm.primary),
          8.w,
          Text('Budget Allocation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const Spacer(),
          Text(_money(total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.primary)),
        ]),
        4.h,
        Text('Marketing, HR, IT, Operations, Research…', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        12.h,
        for (var i = 0; i < _alloc.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _alloc[i].name,
                  decoration: const InputDecoration(hintText: 'Department', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              8.w,
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _alloc[i].amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixText: '₹', hintText: 'Amount', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: crm.textSecondary),
                onPressed: () => setState(() {
                  _alloc[i].name.dispose();
                  _alloc[i].amount.dispose();
                  _alloc.removeAt(i);
                }),
              ),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(_addAllocation),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add department'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          ),
        ),
      ]),
    );
  }
}
