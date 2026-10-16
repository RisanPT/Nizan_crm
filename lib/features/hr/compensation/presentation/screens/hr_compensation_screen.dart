import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/features/hr/shared/hr_person_picker.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr/compensation/data/compensation_models.dart';
import 'package:nizan_crm/features/hr/compensation/service/compensation_service.dart';

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

Color _statusColor(String s, CrmTheme crm) {
  switch (s) {
    case 'approved':
      return crm.success;
    case 'rejected':
      return crm.destructive;
    case 'cancelled':
      return crm.textSecondary;
    default:
      return crm.warning;
  }
}

/// HR Compensation — salary grade bands plus salary revisions that route through
/// the approval engine (an approved revision applies the new base salary).
class HrCompensationScreen extends ConsumerWidget {
  const HrCompensationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: crm.background,
        body: Column(
          children: [
            Material(
              color: crm.surface,
              child: TabBar(
                labelColor: crm.primary,
                unselectedLabelColor: crm.textSecondary,
                indicatorColor: crm.primary,
                tabs: const [Tab(text: 'Salary Bands'), Tab(text: 'Revisions')],
              ),
            ),
            Expanded(child: TabBarView(children: [_BandsTab(crm: crm), _RevisionsTab(crm: crm)])),
          ],
        ),
      ),
    );
  }
}

class _BandsTab extends ConsumerWidget {
  const _BandsTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bands = ref.watch(salaryBandsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Band'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(salaryBandsProvider),
        child: bands.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(salaryBandsProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No salary bands yet.', style: TextStyle(color: crm.textSecondary))))])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: list.map((b) => _row(context, ref, b)).toList()),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, SalaryBand b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: crm.primary.withValues(alpha: 0.12), child: Text('L${b.level}', style: TextStyle(color: crm.primary, fontWeight: FontWeight.w800, fontSize: 11))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text('₹${b.minSalary.toStringAsFixed(0)} – ₹${b.maxSalary.toStringAsFixed(0)} ${b.currency}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: crm.textSecondary), onPressed: () => _edit(context, ref, b)),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: crm.textSecondary),
            onPressed: () async {
              try {
                await ref.read(compensationServiceProvider).deleteBand(b.id);
                ref.invalidate(salaryBandsProvider);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, SalaryBand? existing) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _BandEditor(existing: existing));
    if (ok == true) ref.invalidate(salaryBandsProvider);
  }
}

class _BandEditor extends ConsumerStatefulWidget {
  const _BandEditor({this.existing});
  final SalaryBand? existing;
  @override
  ConsumerState<_BandEditor> createState() => _BandEditorState();
}

class _BandEditorState extends ConsumerState<_BandEditor> {
  late final TextEditingController _name;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late int _level;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _min = TextEditingController(text: e == null ? '' : e.minSalary.toStringAsFixed(0));
    _max = TextEditingController(text: e == null ? '' : e.maxSalary.toStringAsFixed(0));
    _level = e?.level ?? 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(compensationServiceProvider).saveBand({
        'name': _name.text.trim(),
        'level': _level,
        'minSalary': double.tryParse(_min.text.trim()) ?? 0,
        'maxSalary': double.tryParse(_max.text.trim()) ?? 0,
      }, id: widget.existing?.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New band' : 'Edit band'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Band name')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min (₹)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max (₹)'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text('Level', style: TextStyle(color: context.crmColors.textSecondary)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: _level > 1 ? () => setState(() => _level -= 1) : null),
              Text('$_level', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _level < 20 ? () => setState(() => _level += 1) : null),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}

class _RevisionsTab extends ConsumerWidget {
  const _RevisionsTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revs = ref.watch(revisionsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _propose(context, ref),
        icon: const Icon(Icons.trending_up),
        label: const Text('Propose'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(revisionsProvider),
        child: revs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(revisionsProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No revisions yet.', style: TextStyle(color: crm.textSecondary))))])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: list.map((r) => _row(context, ref, r)).toList()),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, CompensationRevision r) {
    final c = _statusColor(r.status, crm);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.employeeName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text('₹${r.currentSalary.toStringAsFixed(0)} → ₹${r.proposedSalary.toStringAsFixed(0)}${r.effectiveDate != null ? ' · from ${_fmt(r.effectiveDate)}' : ''}',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          hrStatusChip(r.status[0].toUpperCase() + r.status.substring(1), c),
          if (r.status == 'pending')
            IconButton(
              icon: Icon(Icons.close, size: 18, color: crm.textSecondary),
              onPressed: () async {
                try {
                  await ref.read(compensationServiceProvider).cancelRevision(r.id);
                  ref.invalidate(revisionsProvider);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _propose(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _ProposeDialog());
    if (ok == true) {
      ref.invalidate(revisionsProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revision proposed')));
    }
  }
}

class _ProposeDialog extends ConsumerStatefulWidget {
  const _ProposeDialog();
  @override
  ConsumerState<_ProposeDialog> createState() => _ProposeDialogState();
}

class _ProposeDialogState extends ConsumerState<_ProposeDialog> {
  String? _employeeId;
  final _salary = TextEditingController();
  final _reason = TextEditingController();
  DateTime? _effective;
  bool _busy = false;

  @override
  void dispose() {
    _salary.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_salary.text.trim()) ?? 0;
    if (_employeeId == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an employee and a valid salary')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(compensationServiceProvider).proposeRevision(
            employeeId: _employeeId!,
            proposedSalary: amt,
            effectiveDate: _effective,
            reason: _reason.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    return AlertDialog(
      title: const Text('Propose revision'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            employees.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyErrorMessage(e)),
              data: (list) {
                final active = list.where((e) => e.status == 'active').toList();
                return PersonPickerField(
                  label: 'Employee',
                  icon: Icons.person_outline,
                  selectedId: _employeeId,
                  items: active.map((e) => PickerItem(id: e.id, name: e.name, department: e.department ?? '')).toList(),
                  onChanged: (v) => setState(() => _employeeId = v),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _salary,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Proposed monthly salary (₹)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(context: context, initialDate: _effective ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2));
                if (d != null) setState(() => _effective = d);
              },
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_effective == null ? 'Effective date (optional)' : 'Effective ${_fmt(_effective)}'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _reason, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Propose'),
        ),
      ],
    );
  }
}
