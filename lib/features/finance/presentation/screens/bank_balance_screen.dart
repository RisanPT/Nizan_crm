import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';

const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day} ${_mon[l.month]} ${l.year}';
}

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

/// Sentinel dropdown value: create a new ledger for the account.
const _newLedger = '__new__';

/// Finance → Bank Balance. Bank accounts and cash in hand. Each account is
/// linked to a Cash / Bank ledger; its live balance is the latest manually
/// entered closing balance plus the ledger's receipts and payments since.
class BankBalanceScreen extends ConsumerWidget {
  const BankBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(bankAccountsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        title: const Text('Bank & Cash Balance'),
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
          final banks = accounts.where((a) => !a.isCash).toList();
          final cash = accounts.where((a) => a.isCash).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bankAccountsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _totalCard(context, result),
                const SizedBox(height: 16),
                if (accounts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.account_balance_outlined, size: 48, color: crm.textSecondary),
                        const SizedBox(height: 10),
                        Text('No accounts yet.', style: TextStyle(color: crm.textSecondary)),
                        const SizedBox(height: 2),
                        Text('Add your bank accounts and cash in hand.',
                            style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                      ]),
                    ),
                  )
                else ...[
                  if (banks.isNotEmpty) ...[
                    _sectionLabel(context, 'BANK ACCOUNTS', result.bankTotal),
                    for (final a in banks) _accountCard(context, ref, a),
                  ],
                  if (cash.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _sectionLabel(context, 'CASH IN HAND', result.cashTotal),
                    for (final a in cash) _accountCard(context, ref, a),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label, double total) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(children: [
        Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: crm.textSecondary)),
        const Spacer(),
        Text(_inr(total), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary)),
      ]),
    );
  }

  Widget _totalCard(BuildContext context, BankAccountsResult r) {
    final crm = context.crmColors;
    final count = r.accounts.where((a) => a.active).length;
    final unlinked = r.accounts.where((a) => a.active && !a.isLinked).length;
    final faded = Colors.white.withValues(alpha: 0.85);
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
          Text('TOTAL CASH & BANK',
              style: TextStyle(color: faded, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_inr(r.totalBalance),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 8),
          Text('Bank ${_inr(r.bankTotal)}  ·  Cash ${_inr(r.cashTotal)}',
              style: TextStyle(color: faded, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            unlinked == 0
                ? 'across $count account${count == 1 ? '' : 's'} · live from the ledger'
                : 'across $count account${count == 1 ? '' : 's'} · $unlinked not linked to a ledger (manual balance)',
            style: TextStyle(color: faded, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _accountCard(BuildContext context, WidgetRef ref, BankAccount a) {
    final crm = context.crmColors;
    final m = a.movement;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            leading: CircleAvatar(
              backgroundColor: crm.primary.withValues(alpha: 0.12),
              child: Icon(a.isCash ? Icons.payments_outlined : Icons.account_balance, color: crm.primary, size: 20),
            ),
            title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              [
                if (a.isCash) 'Cash in hand',
                if (a.bankName.isNotEmpty) a.bankName,
                if (a.accountNumber.isNotEmpty) a.maskedAccount,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'txns') _showTransactions(context, a);
                if (v == 'link') _linkLedger(context, ref, a);
                if (v == 'edit') _openAccountForm(context, ref, existing: a);
                if (v == 'history') _showHistory(context, a);
                if (v == 'delete') _confirmDelete(context, ref, a);
              },
              itemBuilder: (_) => [
                if (a.isLinked) const PopupMenuItem(value: 'txns', child: Text('Transactions')),
                PopupMenuItem(value: 'link', child: Text(a.isLinked ? 'Change ledger link' : 'Link to ledger')),
                const PopupMenuItem(value: 'history', child: Text('Balance history')),
                const PopupMenuItem(value: 'edit', child: Text('Edit details')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_inr(a.currentBalance),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                      Text(
                        a.isLinked ? 'current balance' : 'as of ${_date(a.asOf)} (manual)',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary),
                      ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: a.isLinked
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // How the live balance is built: checkpoint + in − out.
                    Text(
                      'Balance on ${_date(a.asOf)}: ${_inr(a.balance)}'
                      '   + In ${_inr(m?.moneyIn ?? 0)}   − Out ${_inr(m?.moneyOut ?? 0)}',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.link, size: 14, color: crm.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('Ledger ${a.ledger!.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                      ),
                      if ((m?.count ?? 0) > 0) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showTransactions(context, a),
                          child: Text('${m!.count} transaction${m.count == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.primary)),
                        ),
                      ],
                    ]),
                  ])
                : Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                    decoration: BoxDecoration(
                      color: crm.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.link_off, size: 16, color: crm.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Not linked to a ledger — this balance does not move with transactions.',
                            style: TextStyle(fontSize: 12, color: crm.textPrimary)),
                      ),
                      TextButton(onPressed: () => _linkLedger(context, ref, a), child: const Text('Link')),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Ledger picker (shared by Add account and Link) ───────────────────────
  static List<DropdownMenuItem<String>> _ledgerItems(List<LedgerOption> options, String kind, {String? currentId}) {
    final usable = options.where((o) => o.linkedTo.isEmpty || o.id == currentId).toList()
      // Same kind first (bank ledgers for a bank account, cash for cash).
      ..sort((x, y) => (x.accountType == kind ? 0 : 1).compareTo(y.accountType == kind ? 0 : 1));
    return [
      const DropdownMenuItem(value: _newLedger, child: Text('Create a new ledger account')),
      for (final o in usable)
        DropdownMenuItem(
          value: o.id,
          child: Text('Use ${o.label} (${o.accountType == 'cash' ? 'Cash' : 'Bank'})',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
    ];
  }

  // ── Add / edit account ──────────────────────────────────────────────────
  Future<void> _openAccountForm(BuildContext context, WidgetRef ref, {BankAccount? existing}) async {
    final editing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final bankCtrl = TextEditingController(text: existing?.bankName ?? '');
    final acctCtrl = TextEditingController(text: existing?.accountNumber ?? '');
    final balanceCtrl = TextEditingController();
    var asOf = DateTime.now();
    var kind = existing?.kind ?? 'bank';
    var ledgerChoice = _newLedger;
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var busy = false;
        return Consumer(
          builder: (ctx, ref, _) {
            final options = editing
                ? const <LedgerOption>[]
                : (ref.watch(bankLedgerOptionsProvider).value ?? const <LedgerOption>[]);
            return StatefulBuilder(
              builder: (ctx, setSheet) => Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(editing ? 'Edit account' : 'Add account',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 14),
                      if (!editing) ...[
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'bank', icon: Icon(Icons.account_balance, size: 16), label: Text('Bank account')),
                            ButtonSegment(value: 'cash', icon: Icon(Icons.payments_outlined, size: 16), label: Text('Cash in hand')),
                          ],
                          selected: {kind},
                          onSelectionChanged: (s) => setSheet(() => kind = s.first),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Account name *',
                          hintText: kind == 'cash' ? 'e.g. Office Cash, Petty Cash' : 'e.g. HDFC Current',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      if (kind == 'bank') ...[
                        const SizedBox(height: 10),
                        TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'Bank name', border: OutlineInputBorder(), isDense: true)),
                        const SizedBox(height: 10),
                        TextField(controller: acctCtrl, decoration: const InputDecoration(labelText: 'Account number', border: OutlineInputBorder(), isDense: true)),
                      ],
                      if (!editing) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: balanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: const InputDecoration(labelText: 'Opening balance *', prefixText: '₹ ', border: OutlineInputBorder(), isDense: true),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(context: ctx, initialDate: asOf, firstDate: DateTime(2020), lastDate: DateTime(2035));
                            if (d != null) setSheet(() => asOf = d);
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('Closing balance on ${_date(asOf)}'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: ledgerChoice,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ledger account',
                            helperText: 'Receipts and payments on this ledger move the balance.',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _ledgerItems(options, kind),
                          onChanged: (v) => setSheet(() => ledgerChoice = v ?? _newLedger),
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
                                        kind: kind,
                                        ledgerId: ledgerChoice == _newLedger ? null : ledgerChoice,
                                        bankName: kind == 'bank' ? bankCtrl.text.trim() : '',
                                        accountNumber: kind == 'bank' ? acctCtrl.text.trim() : '',
                                        balance: double.tryParse(balanceCtrl.text.trim()) ?? 0,
                                        asOf: asOf,
                                      );
                                    }
                                    ref.refreshData.bankAccounts();
                                    ref.refreshData.chartOfAccounts();
                                    if (ctx.mounted) Navigator.pop(ctx, true);
                                  } catch (e) {
                                    setSheet(() => busy = false);
                                    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                                  }
                                },
                          child: Text(busy ? 'Saving…' : (editing ? 'Save' : 'Add account')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (saved == true) {
      messenger.showSnackBar(SnackBar(content: Text(editing ? 'Account updated' : 'Account added')));
    }
  }

  // ── Link / change the ledger ────────────────────────────────────────────
  Future<void> _linkLedger(BuildContext context, WidgetRef ref, BankAccount a) async {
    final messenger = ScaffoldMessenger.of(context);
    var choice = a.ledger?.id ?? '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var busy = false;
        return Consumer(builder: (ctx, ref, _) {
          final async = ref.watch(bankLedgerOptionsProvider);
          return StatefulBuilder(builder: (ctx, setDlg) {
            final crm = ctx.crmColors;
            final options = async.value ?? const <LedgerOption>[];
            final items = _ledgerItems(options, a.kind, currentId: a.ledger?.id);
            if (choice.isEmpty || !items.any((i) => i.value == choice)) {
              // Default: the first free ledger of the same kind, else a new one.
              choice = items.length > 1 ? items[1].value! : _newLedger;
            }
            return AlertDialog(
              title: Text('Link "${a.name}" to a ledger'),
              content: SizedBox(
                width: 420,
                child: async.isLoading && options.isEmpty
                    ? const LinearProgressIndicator()
                    : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          'Receipts and payments posted to this ledger after '
                          '${_date(a.asOf)} will be added to the ${_inr(a.balance)} balance you entered.',
                          style: TextStyle(fontSize: 13, color: crm.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: choice,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Ledger account', border: OutlineInputBorder(), isDense: true),
                          items: items,
                          onChanged: (v) => setDlg(() => choice = v ?? choice),
                        ),
                        if (a.isLinked) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () async {
                                    setDlg(() => busy = true);
                                    try {
                                      await ref.read(bankAccountServiceProvider).linkLedger(a.id);
                                      ref.refreshData.bankAccounts();
                                      if (ctx.mounted) Navigator.pop(ctx, true);
                                    } catch (e) {
                                      setDlg(() => busy = false);
                                      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                                    }
                                  },
                            icon: const Icon(Icons.link_off, size: 16),
                            label: const Text('Unlink (back to manual balance)'),
                          ),
                        ],
                      ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setDlg(() => busy = true);
                          try {
                            await ref.read(bankAccountServiceProvider).linkLedger(
                                  a.id,
                                  create: choice == _newLedger,
                                  ledgerId: choice == _newLedger ? null : choice,
                                );
                            ref.refreshData.bankAccounts();
                            ref.refreshData.chartOfAccounts();
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setDlg(() => busy = false);
                            messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                          }
                        },
                  child: Text(busy ? 'Saving…' : 'Save'),
                ),
              ],
            );
          });
        });
      },
    );
    if (saved == true) {
      ref.invalidate(bankLedgerOptionsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Ledger link updated')));
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
                Text('Current: ${_inr(a.currentBalance)}',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                if (a.isLinked)
                  Text('Enter the closing balance from the bank / cash count. Transactions dated after this day will be added to it.',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: balanceCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Closing balance *', prefixText: '₹ ', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: asOf, firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (d != null) setSheet(() => asOf = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('Closing balance on ${_date(asOf)}'),
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
                              ref.refreshData.bankAccounts();
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheet(() => busy = false);
                              messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
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
      messenger.showSnackBar(const SnackBar(content: Text('Balance updated')));
    }
  }

  // ── Transactions since the last balance ─────────────────────────────────
  void _showTransactions(BuildContext context, BankAccount a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => Consumer(builder: (ctx, ref, _) {
          final crm = ctx.crmColors;
          final async = ref.watch(bankTransactionsProvider(a.id));
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.name} — transactions', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Since the ${_date(a.asOf)} balance · ledger ${a.ledger?.label ?? ''}',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                const SizedBox(height: 10),
                Expanded(
                  child: async.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(bankTransactionsProvider(a.id))),
                    data: (r) => ListView(
                      controller: controller,
                      children: [
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Balance entered', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(_date(r.since)),
                          trailing: Text(_inr(r.opening), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const Divider(height: 1),
                        if (r.rows.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('No transactions since then.', style: TextStyle(color: crm.textSecondary))),
                          ),
                        for (final t in r.rows.reversed) ...[
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(t.narration.isEmpty ? t.voucherNo : t.narration,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${_date(t.date)} · ${t.voucherNo}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  t.moneyIn > 0 ? '+${_inr(t.moneyIn)}' : '−${_inr(t.moneyOut)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: t.moneyIn > 0 ? crm.success : crm.destructive,
                                  ),
                                ),
                                Text(_inr(t.balance), style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Current balance', style: TextStyle(fontWeight: FontWeight.w800)),
                          trailing: Text(_inr(r.closing), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
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
        content: Text('Remove "${a.name}" and its balance history? This cannot be undone. '
            '${a.isLinked ? 'Its ledger (${a.ledger!.label}) and postings stay in the Chart of Accounts.' : ''}'),
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
      ref.refreshData.bankAccounts();
      messenger.showSnackBar(const SnackBar(content: Text('Account deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }
}
