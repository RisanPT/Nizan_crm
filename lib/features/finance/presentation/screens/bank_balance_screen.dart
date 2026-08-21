import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';

const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime? d) => d == null ? '—' : '${d.day} ${_mon[d.month]} ${d.year}';

// Indian-grouped rupee formatting (₹1,23,45,678).
String _inr(double v) {
  final neg = v < 0;
  var s = v.abs().toStringAsFixed(0);
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    rest = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (_) => ',');
    s = '$rest,$last3';
  }
  return '${neg ? '-' : ''}₹$s';
}

/// Finance → Bank Balance. A manually-maintained register of bank balances
/// (this app does not auto-sync with banks), with a per-account update history.
class BankBalanceScreen extends ConsumerWidget {
  const BankBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(bankAccountsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        title: const Text('Bank Balance'),
        backgroundColor: crm.surface,
        foregroundColor: crm.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAccountForm(context, ref),
        backgroundColor: crm.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(bankAccountsProvider)),
        data: (result) {
          final accounts = result.accounts;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bankAccountsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _totalCard(context, result.totalBalance, accounts.where((a) => a.active).length),
                const SizedBox(height: 16),
                if (accounts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.account_balance_outlined, size: 48, color: crm.textSecondary),
                        const SizedBox(height: 10),
                        Text('No bank accounts yet.', style: TextStyle(color: crm.textSecondary)),
                        const SizedBox(height: 2),
                        Text('Add one to start tracking its balance.',
                            style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                      ]),
                    ),
                  )
                else
                  for (final a in accounts) _accountCard(context, ref, a),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _totalCard(BuildContext context, double total, int count) {
    final crm = context.crmColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [crm.primary, crm.primary.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL BANK BALANCE',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_inr(total),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 6),
          Text('across $count account${count == 1 ? '' : 's'} · manually maintained',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _accountCard(BuildContext context, WidgetRef ref, BankAccount a) {
    final crm = context.crmColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            leading: CircleAvatar(
              backgroundColor: crm.primary.withValues(alpha: 0.12),
              child: Icon(Icons.account_balance, color: crm.primary, size: 20),
            ),
            title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              [if (a.bankName.isNotEmpty) a.bankName, if (a.accountNumber.isNotEmpty) a.maskedAccount].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _openAccountForm(context, ref, existing: a);
                if (v == 'history') _showHistory(context, a);
                if (v == 'delete') _confirmDelete(context, ref, a);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'history', child: Text('View history')),
                PopupMenuItem(value: 'edit', child: Text('Edit details')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_inr(a.balance),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                      Text('as of ${_date(a.asOf)}',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _updateBalance(context, ref, a),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Update balance'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Add / edit account ──────────────────────────────────────────────────
  Future<void> _openAccountForm(BuildContext context, WidgetRef ref, {BankAccount? existing}) async {
    final editing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final bankCtrl = TextEditingController(text: existing?.bankName ?? '');
    final acctCtrl = TextEditingController(text: existing?.accountNumber ?? '');
    final balanceCtrl = TextEditingController(text: editing ? '' : '');
    var asOf = DateTime.now();
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editing ? 'Edit account' : 'Add bank account',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Account name *', hintText: 'e.g. HDFC Current', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'Bank name', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: acctCtrl, decoration: const InputDecoration(labelText: 'Account number', border: OutlineInputBorder(), isDense: true)),
                if (!editing) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: balanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: const InputDecoration(labelText: 'Opening balance *', prefixText: '₹ ', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 10),
                  StatefulBuilder(
                    builder: (ctx, _) => OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(context: ctx, initialDate: asOf, firstDate: DateTime(2020), lastDate: DateTime(2035));
                        if (d != null) setSheet(() => asOf = d);
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('As of ${_date(asOf)}'),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              messenger.showSnackBar(const SnackBar(content: Text('Enter an account name')));
                              return;
                            }
                            setSheet(() => busy = true);
                            try {
                              final svc = ref.read(bankAccountServiceProvider);
                              if (editing) {
                                await svc.updateDetails(existing.id, name: name, bankName: bankCtrl.text.trim(), accountNumber: acctCtrl.text.trim());
                              } else {
                                await svc.create(
                                  name: name,
                                  bankName: bankCtrl.text.trim(),
                                  accountNumber: acctCtrl.text.trim(),
                                  balance: double.tryParse(balanceCtrl.text.trim()) ?? 0,
                                  asOf: asOf,
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheet(() => busy = false);
                              messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                            }
                          },
                    child: Text(busy ? 'Saving…' : (editing ? 'Save' : 'Add account')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (saved == true) {
      ref.invalidate(bankAccountsProvider);
      messenger.showSnackBar(SnackBar(content: Text(editing ? 'Account updated' : 'Account added')));
    }
  }

  // ── Record a new balance ────────────────────────────────────────────────
  Future<void> _updateBalance(BuildContext context, WidgetRef ref, BankAccount a) async {
    final balanceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var asOf = DateTime.now();
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final crm = ctx.crmColors;
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Update balance — ${a.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Current: ${_inr(a.balance)} (as of ${_date(a.asOf)})',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: balanceCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'New balance *', prefixText: '₹ ', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: asOf, firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (d != null) setSheet(() => asOf = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('As of ${_date(asOf)}'),
                ),
                const SizedBox(height: 10),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final val = double.tryParse(balanceCtrl.text.trim());
                            if (val == null) {
                              messenger.showSnackBar(const SnackBar(content: Text('Enter a balance amount')));
                              return;
                            }
                            setSheet(() => busy = true);
                            try {
                              await ref.read(bankAccountServiceProvider)
                                  .recordBalance(a.id, balance: val, asOf: asOf, note: noteCtrl.text.trim());
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheet(() => busy = false);
                              messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                            }
                          },
                    child: Text(busy ? 'Saving…' : 'Save balance'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (saved == true) {
      ref.invalidate(bankAccountsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Balance updated')));
    }
  }

  // ── History ─────────────────────────────────────────────────────────────
  void _showHistory(BuildContext context, BankAccount a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final crm = ctx.crmColors;
        final entries = a.history.reversed.toList();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.name} — balance history', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Expanded(
                  child: entries.isEmpty
                      ? Center(child: Text('No updates yet.', style: TextStyle(color: crm.textSecondary)))
                      : ListView.separated(
                          controller: controller,
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final e = entries[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(_inr(e.balance), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text([
                                'as of ${_date(e.asOf)}',
                                if (e.note.isNotEmpty) e.note,
                                if (e.byName.isNotEmpty) 'by ${e.byName}',
                              ].join(' · ')),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, BankAccount a) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Remove "${a.name}" and its balance history? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.crmColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(bankAccountServiceProvider).delete(a.id);
      ref.invalidate(bankAccountsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Account deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }
}
