import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/bank_transactions_view.dart' show bankDate, bankInr, exportBankStatement;
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';

// The dialogs of a bank / cash account — add or edit it, link its ledger, enter a new balance, see the
// balances entered before, delete it. Shared by the Bank & Cash Balance screen and the account's
// Transactions screen.

String _date(DateTime? d) => bankDate(d);
String _inr(double v) => bankInr(v);

/// Sentinel dropdown value: create a new ledger for the account.
const _newLedger = '__new__';

// ── Ledger picker (shared by Add account and Link) ───────────────────────
List<DropdownMenuItem<String>> _ledgerItems(List<LedgerOption> options, String kind, {String? currentId}) {
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
Future<void> openBankAccountForm(BuildContext context, WidgetRef ref, {BankAccount? existing}) async {
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
Future<void> linkBankLedger(BuildContext context, WidgetRef ref, BankAccount a) async {
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
Future<void> updateBankBalance(BuildContext context, WidgetRef ref, BankAccount a) async {
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

// ── History ─────────────────────────────────────────────────────────────
void showBankBalanceHistory(BuildContext context, BankAccount a) {
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

Future<bool> confirmDeleteBankAccount(BuildContext context, WidgetRef ref, BankAccount a) async {
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
  if (ok != true) return false;
  try {
    await ref.read(bankAccountServiceProvider).delete(a.id);
    ref.refreshData.bankAccounts();
    messenger.showSnackBar(const SnackBar(content: Text('Account deleted')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    return false;
  }
}

/// The "⋯" menu of an account: enter a new balance, see the ones entered before, change the ledger
/// it is linked to, edit its details, delete it.
class BankAccountMenuButton extends ConsumerWidget {
  final BankAccount account;

  /// Called after the account was deleted (the screen showing it has nothing left to show).
  final VoidCallback? onDeleted;
  const BankAccountMenuButton({super.key, required this.account, this.onDeleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final a = account;
    return PopupMenuButton<String>(
      key: Key('bankAccountMenu_${a.id}'),
      tooltip: 'Account options',
      onSelected: (v) async {
        switch (v) {
          case 'balance':
            await updateBankBalance(context, ref, a);
          case 'history':
            showBankBalanceHistory(context, a);
          case 'link':
            await linkBankLedger(context, ref, a);
          case 'edit':
            await openBankAccountForm(context, ref, existing: a);
          case 'delete':
            if (await confirmDeleteBankAccount(context, ref, a)) onDeleted?.call();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'balance', child: Text('Update balance')),
        const PopupMenuItem(value: 'history', child: Text('Balance history')),
        PopupMenuItem(value: 'link', child: Text(a.isLinked ? 'Change ledger link' : 'Link to ledger')),
        const PopupMenuItem(value: 'edit', child: Text('Edit details')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
        child: Icon(Icons.more_horiz, size: 20, color: crm.textPrimary),
      ),
    );
  }
}

/// The Export button of a statement: CSV or PDF of everything that matches what is on screen.
class BankExportButton extends ConsumerWidget {
  final BankAccount? account;
  final BankTxnQuery? query;
  const BankExportButton({super.key, required this.account, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final ready = account != null && account!.isLinked && query != null;
    return PopupMenuButton<bool>(
      key: const Key('bankExport'),
      enabled: ready,
      tooltip: ready ? 'Export these transactions' : 'Choose an account that is linked to a ledger',
      onSelected: (pdf) => exportBankStatement(context, ref, account!, query!, pdf: pdf),
      itemBuilder: (_) => const [
        PopupMenuItem(value: false, child: Text('Export CSV (Excel)')),
        PopupMenuItem(value: true, child: Text('Export PDF')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(color: ready ? crm.primary : crm.primary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.file_download_outlined, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text('Export', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
