import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/account_ledger.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
String _date(DateTime? d) => d == null ? '' : DateFormat('d MMM yy').format(d);
String _isoDate(DateTime? d) => d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

/// Finance → General Ledger. Any account's statement with a running balance —
/// use it as the cash book, bank book, or a party/expense ledger.
class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key, this.initialAccountId});
  final String? initialAccountId;

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _accountId = widget.initialAccountId;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final accountsAsync = ref.watch(chartAccountsProvider('all'));

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        // Account picker
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: accountsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e', style: TextStyle(color: crm.destructive)),
            data: (accounts) {
              final sorted = [...accounts]..sort((a, b) => a.code.compareTo(b.code));
              _accountId ??= sorted.isNotEmpty ? sorted.first.id : null;
              return DropdownButtonFormField<String>(
                initialValue: sorted.any((a) => a.id == _accountId) ? _accountId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Account', prefixIcon: Icon(Icons.account_tree_outlined, size: 18)),
                items: [
                  for (final a in sorted)
                    DropdownMenuItem(value: a.id, child: Text('${a.code} · ${a.name}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              );
            },
          ),
        ),
        Expanded(
          child: _accountId == null
              ? Center(child: Text('Pick an account', style: TextStyle(color: crm.textSecondary)))
              : _statement(crm, _accountId!),
        ),
      ]),
    );
  }

  Widget _statement(CrmTheme crm, String accountId) {
    final async = ref.watch(ledgerProvider(accountId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ledgerProvider(accountId)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('$e', style: TextStyle(color: crm.destructive))))]),
        data: (l) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _exportCsv(l),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export CSV'),
              ),
            ),
            // Closing summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: crm.border.withValues(alpha: 0.8)),
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CLOSING BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
                  4.h,
                  Text('${_money(l.closingBalance)} ${l.closingSide.toUpperCase()}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                ]),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${l.rows.length} entries', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  4.h,
                  Text('Dr ${_money(l.totalDebit)}', style: TextStyle(fontSize: 12, color: const Color(0xFFB44A2C))),
                  Text('Cr ${_money(l.totalCredit)}', style: TextStyle(fontSize: 12, color: crm.success)),
                ]),
              ]),
            ),
            12.h,
            Container(
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border.withValues(alpha: 0.8)),
              ),
              child: Column(children: [
                // header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: crm.background.withValues(alpha: 0.4), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(children: [
                    Expanded(flex: 4, child: Text('PARTICULARS', style: _hdr(crm))),
                    Expanded(flex: 2, child: Text('DEBIT', textAlign: TextAlign.right, style: _hdr(crm))),
                    Expanded(flex: 2, child: Text('CREDIT', textAlign: TextAlign.right, style: _hdr(crm))),
                    Expanded(flex: 3, child: Text('BALANCE', textAlign: TextAlign.right, style: _hdr(crm))),
                  ]),
                ),
                // opening
                _openingRow(crm, l),
                for (final r in l.rows) _entryRow(crm, r),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(AccountLedger l) async {
    final rows = <List<Object?>>[
      ['Ledger: ${l.code} · ${l.name}'],
      ['Date', 'Voucher', 'Type', 'Particulars', 'Debit', 'Credit', 'Balance', 'Side'],
      ['', '', '', 'Opening balance', '', '', csvNum(l.openingBalance), l.openingSide.toUpperCase()],
      for (final r in l.rows)
        [
          _isoDate(r.date),
          r.voucherNo,
          r.voucherType,
          r.narration,
          r.debit > 0 ? csvNum(r.debit) : '',
          r.credit > 0 ? csvNum(r.credit) : '',
          csvNum(r.balance),
          r.balanceSide.toUpperCase(),
        ],
      ['', '', '', 'TOTAL', csvNum(l.totalDebit), csvNum(l.totalCredit), '', ''],
      ['', '', '', 'Closing balance', '', '', csvNum(l.closingBalance), l.closingSide.toUpperCase()],
    ];
    final safeName = l.code.isEmpty ? 'ledger' : 'ledger_${l.code}';
    try {
      await downloadCsv('$safeName.csv', rows);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ledger exported')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Widget _openingRow(CrmTheme crm, AccountLedger l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border.withValues(alpha: 0.4)))),
        child: Row(children: [
          Expanded(flex: 4, child: Text('Opening balance', style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: crm.textSecondary))),
          const Expanded(flex: 2, child: SizedBox()),
          const Expanded(flex: 2, child: SizedBox()),
          Expanded(flex: 3, child: Text('${_money(l.openingBalance)} ${l.openingSide.toUpperCase()}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
        ]),
      );

  Widget _entryRow(CrmTheme crm, LedgerRow r) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border.withValues(alpha: 0.4)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.narration.isEmpty ? r.voucherNo : r.narration,
                  style: TextStyle(fontSize: 12.5, color: crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${r.voucherNo}${r.date != null ? ' · ${_date(r.date)}' : ''}',
                  style: TextStyle(fontSize: 10.5, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Expanded(flex: 2, child: Text(r.debit > 0 ? _money(r.debit) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB44A2C)))),
          Expanded(flex: 2, child: Text(r.credit > 0 ? _money(r.credit) : '', textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: crm.success))),
          Expanded(flex: 3, child: Text('${_money(r.balance)} ${r.balanceSide.toUpperCase()}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary))),
        ]),
      );

  TextStyle _hdr(CrmTheme crm) => TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: crm.textSecondary);
}
