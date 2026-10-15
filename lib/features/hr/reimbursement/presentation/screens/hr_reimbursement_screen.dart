import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/hr/reimbursement/data/claim_models.dart';
import 'package:nizan_crm/features/hr/reimbursement/service/reimbursement_service.dart';

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

Color _statusColor(String s, CrmTheme crm) {
  switch (s) {
    case 'paid':
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

Widget _chip(String s, CrmTheme crm) =>
    hrStatusChip(s[0].toUpperCase() + s.substring(1), _statusColor(s, crm));

/// HR Reimbursements — employees submit expense claims for approval; HR reviews
/// and marks approved claims paid (which posts to the ledger).
class HrReimbursementScreen extends ConsumerWidget {
  const HrReimbursementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);
    final hasEmployee = (session?.employeeId ?? '').isNotEmpty;
    final isManager = access.isFullAccess || access.isDepartmentHead || access.has('reimbursement', false) || access.has('staff', false);

    final tabs = <Tab>[
      if (hasEmployee) const Tab(text: 'My Claims'),
      if (isManager) const Tab(text: 'All Claims'),
    ];
    final views = <Widget>[
      if (hasEmployee) _MineTab(crm: crm),
      if (isManager) _RequestsTab(crm: crm),
    ];
    if (tabs.isEmpty) {
      return Scaffold(backgroundColor: crm.background, body: Center(child: Text('No employee record is linked to your account.', style: TextStyle(color: crm.textSecondary))));
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: crm.background,
        body: Column(
          children: [
            Material(
              color: crm.surface,
              child: TabBar(labelColor: crm.primary, unselectedLabelColor: crm.textSecondary, indicatorColor: crm.primary, tabs: tabs),
            ),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
      ),
    );
  }
}

class _MineTab extends ConsumerWidget {
  const _MineTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myClaimsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Claim'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myClaimsProvider),
        child: mine.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(myClaimsProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No claims yet.', style: TextStyle(color: crm.textSecondary))))])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: list.map((c) => _row(context, ref, c, mine: true)).toList()),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, ExpenseClaim c, {required bool mine}) {
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
                Text('${c.title} · ₹${c.amount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text('${claimCategoryLabel(c.category)} · ${_fmt(c.date)}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                if (c.status == 'rejected' && c.decisionNote.isNotEmpty)
                  Text('Note: ${c.decisionNote}', style: TextStyle(fontSize: 11, color: crm.destructive)),
              ],
            ),
          ),
          _chip(c.status, crm),
          if (mine && c.status == 'pending')
            IconButton(
              icon: Icon(Icons.close, size: 18, color: crm.textSecondary),
              onPressed: () async {
                try {
                  await ref.read(reimbursementServiceProvider).cancel(c.id);
                  ref.invalidate(myClaimsProvider);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _ClaimDialog());
    if (ok == true) {
      ref.invalidate(myClaimsProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim submitted')));
    }
  }
}

class _ClaimDialog extends ConsumerStatefulWidget {
  const _ClaimDialog();
  @override
  ConsumerState<_ClaimDialog> createState() => _ClaimDialogState();
}

class _ClaimDialogState extends ConsumerState<_ClaimDialog> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final _receipt = TextEditingController();
  String _category = 'other';
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _desc.dispose();
    _receipt.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (_title.text.trim().isEmpty || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and a valid amount are required')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(reimbursementServiceProvider).submit(
            title: _title.text.trim(),
            amount: amt,
            category: _category,
            date: _date,
            description: _desc.text.trim(),
            receiptUrl: _receipt.text.trim(),
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
    return AlertDialog(
      title: const Text('New expense claim'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: kClaimCategories.map((c) => DropdownMenuItem(value: c, child: Text(claimCategoryLabel(c)))).toList(),
                onChanged: (v) => setState(() => _category = v ?? 'other'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(now.year - 1), lastDate: now);
                  if (d != null) setState(() => _date = d);
                },
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text('Date: ${_fmt(_date)}'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _receipt, decoration: const InputDecoration(labelText: 'Receipt URL (optional)')),
              const SizedBox(height: 10),
              TextField(controller: _desc, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'),
        ),
      ],
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(claimRequestsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(claimRequestsProvider),
      child: reqs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(claimRequestsProvider))]),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('All claims', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            Text('Approve/decline from the Approvals inbox; pay approved claims here', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No claims.', style: TextStyle(color: crm.textSecondary))))
            else
              ...list.map((c) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: hrCardDecoration(crm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: c.employeeId.isNotEmpty
                                        ? () => context.push('/staff/${c.employeeId}')
                                        : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Text(
                                      c.employeeName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: crm.primary,
                                        decoration: TextDecoration.underline,
                                        decorationColor: crm.primary.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                  Text(' · ${c.title}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                                ],
                              ),
                              Text('₹${c.amount.toStringAsFixed(0)} · ${claimCategoryLabel(c.category)}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                            ],
                          ),
                        ),
                        _chip(c.status, crm),
                        if (c.status == 'approved')
                          TextButton(
                            onPressed: () async {
                              try {
                                await ref.read(reimbursementServiceProvider).pay(c.id);
                                ref.invalidate(claimRequestsProvider);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked paid')));
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                              }
                            },
                            child: const Text('Pay'),
                          ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
