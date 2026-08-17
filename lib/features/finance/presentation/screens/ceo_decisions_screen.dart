import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/month_year_picker.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';

const _monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

/// Finance → CEO Decisions & Action Items: the governance log. Approvals
/// (cost/hiring/CapEx/investment), strategic calls, and assigned action items
/// with an owner, deadline and status — the accountability layer of the review.
class CeoDecisionsScreen extends ConsumerStatefulWidget {
  const CeoDecisionsScreen({super.key});

  @override
  ConsumerState<CeoDecisionsScreen> createState() => _CeoDecisionsScreenState();
}

class _CeoDecisionsScreenState extends ConsumerState<CeoDecisionsScreen> {
  late int _month;
  late int _year;
  bool _openOnly = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
  }

  Period get _key => (month: _month, year: _year);

  void _shift(int delta) {
    setState(() {
      var m = _month + delta, y = _year;
      if (m < 1) { m = 12; y--; }
      if (m > 12) { m = 1; y++; }
      _month = m;
      _year = y;
    });
  }

  Color _statusColor(CrmTheme crm, String s) => switch (s) {
        'approved' || 'done' => crm.success,
        'rejected' => crm.destructive,
        'deferred' => crm.warning,
        _ => crm.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = _openOnly ? ref.watch(openDecisionsProvider) : ref.watch(decisionsProvider(_key));

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(children: [
        _header(crm),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(openDecisionsProvider);
              ref.invalidate(decisionsProvider(_key));
            },
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorView(error: e, onRetry: () {
                ref.invalidate(openDecisionsProvider);
                ref.invalidate(decisionsProvider(_key));
              }),
              data: (items) => items.isEmpty
                  ? ListView(children: [
                      80.h,
                      Icon(Icons.gavel_outlined, size: 52, color: crm.border),
                      12.h,
                      Center(child: Text(_openOnly ? 'No open decisions' : 'No decisions this month',
                          style: TextStyle(color: crm.textSecondary))),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _card(crm, items[i]),
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _header(CrmTheme crm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 0),
      child: Row(children: [
        if (!_openOnly) ...[
          IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
          InkWell(
            onTap: () async {
              final picked = await showMonthYearPicker(context, month: _month, year: _year);
              if (picked != null) setState(() { _month = picked.month; _year = picked.year; });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${_monthNames[_month]} $_year',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                Icon(Icons.arrow_drop_down, color: crm.textSecondary),
              ]),
            ),
          ),
          IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
        ] else
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text('All open decisions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          ),
        const Spacer(),
        FilterChip(
          label: const Text('Open only'),
          selected: _openOnly,
          onSelected: (v) => setState(() => _openOnly = v),
        ),
      ]),
    );
  }

  Widget _card(CrmTheme crm, CeoDecision d) {
    final overdue = d.dueDate != null && d.isOpen && d.dueDate!.isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _edit(d),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (overdue ? crm.destructive : crm.border).withValues(alpha: overdue ? 0.4 : 0.6)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _chip(crm, decisionTypeLabel(d.type), crm.primary),
                8.w,
                Expanded(child: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5), maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (d.amount > 0) Text(_money(d.amount), style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
              ]),
              if (d.description.isNotEmpty) ...[
                6.h,
                Text(d.description, style: TextStyle(fontSize: 12.5, color: crm.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              8.h,
              Row(children: [
                InkWell(
                  onTap: () => _cycleStatus(d),
                  borderRadius: BorderRadius.circular(20),
                  child: _chip(crm, decisionStatusLabel(d.status), _statusColor(crm, d.status)),
                ),
                8.w,
                if (d.owner.isNotEmpty) ...[
                  Icon(Icons.person_outline, size: 14, color: crm.textSecondary),
                  2.w,
                  Text(d.owner, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  8.w,
                ],
                if (d.dueDate != null) ...[
                  Icon(Icons.event_outlined, size: 14, color: overdue ? crm.destructive : crm.textSecondary),
                  2.w,
                  Text(DateFormat('d MMM').format(d.dueDate!),
                      style: TextStyle(fontSize: 12, fontWeight: overdue ? FontWeight.w700 : FontWeight.w400, color: overdue ? crm.destructive : crm.textSecondary)),
                ],
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline, size: 18, color: crm.textSecondary),
                  onPressed: () => _delete(d),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(CrmTheme crm, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );

  Future<void> _cycleStatus(CeoDecision d) async {
    const order = ['pending', 'approved', 'done', 'deferred', 'rejected'];
    final next = order[(order.indexOf(d.status) + 1) % order.length];
    await _persist(CeoDecision(
      id: d.id, month: d.month, year: d.year, type: d.type, title: d.title,
      description: d.description, amount: d.amount, owner: d.owner, dueDate: d.dueDate, status: next,
    ));
  }

  Future<void> _delete(CeoDecision d) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete decision?'),
        content: Text('"${d.title}" will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(monthEndServiceProvider).deleteDecision(d.id);
      _invalidate();
      if (mounted) showSuccessSnackBar(context, 'Deleted');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _persist(CeoDecision d) async {
    try {
      await ref.read(monthEndServiceProvider).saveDecision(d);
      _invalidate();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  void _invalidate() {
    ref.invalidate(openDecisionsProvider);
    ref.invalidate(decisionsProvider(_key));
    ref.invalidate(monthEndReviewProvider(_key));
  }

  Future<void> _edit(CeoDecision? existing) async {
    final result = await showModalBottomSheet<CeoDecision>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DecisionForm(existing: existing, month: _month, year: _year),
    );
    if (result != null) await _persist(result);
  }
}

class _DecisionForm extends StatefulWidget {
  const _DecisionForm({this.existing, required this.month, required this.year});
  final CeoDecision? existing;
  final int month, year;

  @override
  State<_DecisionForm> createState() => _DecisionFormState();
}

class _DecisionFormState extends State<_DecisionForm> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _amount;
  late final TextEditingController _owner;
  late String _type;
  late String _status;
  DateTime? _due;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _amount = TextEditingController(text: (e?.amount ?? 0) == 0 ? '' : e!.amount.toStringAsFixed(0));
    _owner = TextEditingController(text: e?.owner ?? '');
    _type = e?.type ?? 'action_item';
    _status = e?.status ?? 'pending';
    _due = e?.dueDate;
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _amount, _owner]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: crm.border, borderRadius: BorderRadius.circular(2)))),
          Text(widget.existing == null ? 'New decision / action item' : 'Edit decision',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          14.h,
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder(), isDense: true),
            items: [for (final t in kDecisionTypes) DropdownMenuItem(value: t, child: Text(decisionTypeLabel(t)))],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          12.h,
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder(), isDense: true)),
          12.h,
          TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Details', border: OutlineInputBorder(), isDense: true)),
          12.h,
          Row(children: [
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            10.w,
            Expanded(child: TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder(), isDense: true))),
          ]),
          12.h,
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                items: [for (final s in kDecisionStatuses) DropdownMenuItem(value: s, child: Text(decisionStatusLabel(s)))],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ),
            10.w,
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _due ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _due = picked);
                },
                icon: const Icon(Icons.event, size: 18),
                label: Text(_due == null ? 'Due date' : DateFormat('d MMM yy').format(_due!)),
              ),
            ),
          ]),
          16.h,
          SizedBox(
            height: 46,
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_title.text.trim().isEmpty) {
                  showErrorSnackBar(context, Exception('A title is required'));
                  return;
                }
                Navigator.pop(
                  context,
                  CeoDecision(
                    id: widget.existing?.id ?? '',
                    month: widget.existing?.month ?? widget.month,
                    year: widget.existing?.year ?? widget.year,
                    type: _type,
                    title: _title.text.trim(),
                    description: _desc.text.trim(),
                    amount: double.tryParse(_amount.text.trim()) ?? 0,
                    owner: _owner.text.trim(),
                    status: _status,
                    dueDate: _due,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ),
        ]),
      ),
    );
  }
}
