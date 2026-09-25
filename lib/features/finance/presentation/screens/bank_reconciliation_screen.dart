import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/bank_recon.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/utils/bank_statement_import.dart';

const _moneyIn = Color(0xFF0D9488);
const _moneyOut = Color(0xFFB44A2C);

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v.abs());
String _signed(num v) => '${v < 0 ? '−' : '+'}${_money(v)}';
String _date(DateTime? d) => d == null ? '' : DateFormat('d MMM yy').format(d);
Color _amtColor(num v) => v < 0 ? _moneyOut : _moneyIn;

/// Finance → Bank Reconciliation. Import a bank statement and match it against
/// the account's ledger; the summary shows a classic bank-reconciliation
/// statement (book balance ↔ bank balance, with the reconciling items).
class BankReconciliationScreen extends ConsumerStatefulWidget {
  const BankReconciliationScreen({super.key});

  @override
  ConsumerState<BankReconciliationScreen> createState() =>
      _BankReconciliationScreenState();
}

class _BankReconciliationScreenState
    extends ConsumerState<BankReconciliationScreen> {
  String? _accountId;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final accountsAsync = ref.watch(bankAccountsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: accountsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => AppErrorView(error: e, compact: true, onRetry: () => ref.invalidate(bankAccountsProvider)),
            data: (accounts) {
              if (accounts.isEmpty) {
                return Text('No bank or cash accounts found. Mark an account as bank/cash in the Chart of Accounts.',
                    style: TextStyle(color: crm.textSecondary));
              }
              // Fall back to the first account if the selected one was
              // deleted / un-flagged as bank elsewhere.
              if (_accountId == null || !accounts.any((a) => a.id == _accountId)) {
                _accountId = accounts.first.id;
              }
              return Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Bank / cash account',
                        prefixIcon: Icon(Icons.account_balance_outlined, size: 18)),
                    items: [
                      for (final a in accounts)
                        DropdownMenuItem(value: a.id, child: Text(a.label, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _accountId = v),
                  ),
                ),
              ]);
            },
          ),
        ),
        if (_accountId != null) _toolbar(crm),
        Expanded(
          child: _accountId == null
              ? Center(child: Text('Pick an account', style: TextStyle(color: crm.textSecondary)))
              : _body(crm, _accountId!),
        ),
      ]),
    );
  }

  Widget _toolbar(CrmTheme crm) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Row(children: [
          TextButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Import statement'),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _autoMatch,
            icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
            label: const Text('Auto-match'),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (v) {
              if (v == 'clear') _clear();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear imported statement')),
            ],
            icon: const Icon(Icons.more_vert, size: 20),
          ),
        ]),
      );

  Widget _body(CrmTheme crm, String accountId) {
    final async = ref.watch(reconciliationProvider(accountId));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(reconciliationProvider(accountId)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          AppErrorView(error: e, onRetry: () => ref.invalidate(reconciliationProvider(accountId))),
        ]),
        data: (r) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            _summaryCard(crm, r),
            if (r.statementCount == 0) ...[
              20.h,
              _emptyHint(crm),
            ] else ...[
              16.h,
              _unmatchedStatementSection(crm, r),
              14.h,
              _unmatchedLedgerSection(crm, r),
              14.h,
              _matchedSection(crm, r),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(CrmTheme crm) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border.faded(0.8)),
        ),
        child: Column(children: [
          Icon(Icons.upload_file_outlined, size: 40, color: crm.border),
          10.h,
          Text('No statement imported yet',
              style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
          6.h,
          Text('Download your bank statement as CSV or Excel and tap “Import statement”. '
              'Columns like Date, Description, Debit/Credit (or a single Amount) and Balance are picked up automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        ]),
      );

  // ── Summary (bank-reconciliation statement) ──
  Widget _summaryCard(CrmTheme crm, Reconciliation r) {
    final reconciled = r.difference != null && r.difference!.abs() < 0.01;
    final diffColor = r.difference == null
        ? crm.textSecondary
        : (reconciled ? crm.success : crm.destructive);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.faded(0.8)),
      ),
      child: Column(children: [
        _sumRow(crm, 'Balance as per books (ledger)', '${_money(r.bookClosing)} ${r.bookClosing < 0 ? 'Cr' : 'Dr'}', strong: true),
        const Divider(height: 20),
        _sumRow(crm, 'Add: in books, not yet on statement', _signed(-r.unmatchedLedgerNet),
            hint: '${r.unmatchedLedger.length} item${r.unmatchedLedger.length == 1 ? '' : 's'}',
            valueColor: _amtColor(-r.unmatchedLedgerNet)),
        6.h,
        _sumRow(crm, 'Add: on statement, not yet in books', _signed(r.unmatchedStatementNet),
            hint: '${r.unmatchedStatement.length} item${r.unmatchedStatement.length == 1 ? '' : 's'}',
            valueColor: _amtColor(r.unmatchedStatementNet)),
        const Divider(height: 20),
        _sumRow(crm, 'Expected bank balance', _money(r.expectedStatementClosing), strong: true),
        6.h,
        _sumRow(crm, 'Statement closing balance',
            r.statementClosing == null ? 'not in file' : _money(r.statementClosing!),
            valueColor: r.statementClosing == null ? crm.textSecondary : crm.textPrimary),
        10.h,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: diffColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: diffColor.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(
                r.difference == null
                    ? Icons.info_outline
                    : (reconciled ? Icons.verified_outlined : Icons.error_outline),
                size: 18,
                color: diffColor),
            10.w,
            Expanded(
              child: Text(
                r.difference == null
                    ? 'Add a Balance column to your statement to auto-check the difference'
                    : (reconciled ? 'Reconciled — difference is ₹0' : 'Unreconciled difference'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: diffColor),
              ),
            ),
            if (r.difference != null)
              Text(_money(r.difference!),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: diffColor)),
          ]),
        ),
      ]),
    );
  }

  Widget _sumRow(CrmTheme crm, String label, String value,
      {bool strong = false, String? hint, Color? valueColor}) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                  color: crm.textPrimary)),
          if (hint != null) Text(hint, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        ]),
      ),
      Text(value,
          style: TextStyle(
              fontSize: strong ? 15 : 13.5,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? crm.textPrimary)),
    ]);
  }

  // ── Unmatched on statement (bank-only / to record) ──
  Widget _unmatchedStatementSection(CrmTheme crm, Reconciliation r) {
    return _sectionCard(
      crm,
      title: 'On statement, not in books',
      subtitle: 'Usually bank charges/interest to record, or a match to confirm',
      count: r.unmatchedStatement.length,
      color: _moneyOut,
      children: [
        if (r.unmatchedStatement.isEmpty)
          _allClear(crm, 'Every statement line is in your books')
        else
          for (final s in r.unmatchedStatement)
            InkWell(
              onTap: _busy ? null : () => _openMatchDialog(r, s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.description.isEmpty ? '(no description)' : s.description,
                          style: TextStyle(fontSize: 13, color: crm.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${_date(s.txnDate)}${s.refNo.isEmpty ? '' : ' · ${s.refNo}'}',
                          style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                    ]),
                  ),
                  8.w,
                  Text(_signed(s.amount),
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _amtColor(s.amount))),
                  Icon(Icons.link_outlined, size: 16, color: crm.textSecondary),
                ]),
              ),
            ),
      ],
    );
  }

  // ── Unmatched in books (in-transit) ──
  Widget _unmatchedLedgerSection(CrmTheme crm, Reconciliation r) {
    return _sectionCard(
      crm,
      title: 'In books, not on statement',
      subtitle: 'Deposits in transit / payments not yet cleared',
      count: r.unmatchedLedger.length,
      color: _moneyIn,
      children: [
        if (r.unmatchedLedger.isEmpty)
          _allClear(crm, 'Every ledger entry is on the statement')
        else
          for (final m in r.unmatchedLedger)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.narration.isEmpty ? m.voucherNo : m.narration,
                        style: TextStyle(fontSize: 13, color: crm.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${m.voucherNo}${m.date != null ? ' · ${_date(m.date)}' : ''}',
                        style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                  ]),
                ),
                8.w,
                Text(_signed(m.amount),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _amtColor(m.amount))),
              ]),
            ),
      ],
    );
  }

  // ── Matched pairs ──
  Widget _matchedSection(CrmTheme crm, Reconciliation r) {
    return _sectionCard(
      crm,
      title: 'Matched',
      subtitle: 'Statement lines reconciled to ledger vouchers',
      count: r.matched.length,
      color: crm.success,
      initiallyExpanded: false,
      collapsible: true,
      children: [
        if (r.matched.isEmpty)
          _allClear(crm, 'Nothing matched yet — try Auto-match')
        else
          for (final p in r.matched)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(Icons.check_circle_outline, size: 16, color: crm.success),
                10.w,
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.description.isEmpty ? p.voucherNo : p.description,
                        style: TextStyle(fontSize: 13, color: crm.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${_date(p.txnDate)} · ${p.voucherNo}',
                        style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                  ]),
                ),
                8.w,
                Text(_signed(p.amount),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _amtColor(p.amount))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Unmatch',
                  onPressed: _busy ? null : () => _unmatch(p.statementLineId),
                  icon: Icon(Icons.link_off_outlined, size: 16, color: crm.textSecondary),
                ),
              ]),
            ),
      ],
    );
  }

  Widget _sectionCard(
    CrmTheme crm, {
    required String title,
    required String subtitle,
    required int count,
    required Color color,
    required List<Widget> children,
    bool collapsible = false,
    bool initiallyExpanded = true,
  }) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        10.w,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: crm.textPrimary)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      ]),
    );
    final box = BoxDecoration(
      color: crm.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: crm.border.faded(0.8)),
    );
    if (collapsible) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: box,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            title: header,
            children: children,
          ),
        ),
      );
    }
    return Container(
      decoration: box,
      child: Column(children: [header, const Divider(height: 1), ...children]),
    );
  }

  Widget _allClear(CrmTheme crm, String msg) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        child: Row(children: [
          Icon(Icons.check_circle_outline, size: 16, color: crm.success),
          8.w,
          Expanded(child: Text(msg, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
        ]),
      );

  // ── Manual match dialog ──
  Future<void> _openMatchDialog(Reconciliation r, StatementLine s) async {
    final crm = context.crmColors;
    // Exact-amount candidates first, then the rest by nearest date.
    final exact = r.unmatchedLedger.where((m) => (m.amount - s.amount).abs() < 0.01).toList();
    final others = r.unmatchedLedger.where((m) => (m.amount - s.amount).abs() >= 0.01).toList()
      ..sort((a, b) {
        final da = a.date, db = b.date, st = s.txnDate;
        if (da == null || db == null || st == null) return 0;
        return (da.difference(st).abs()).compareTo(db.difference(st).abs());
      });
    final ordered = [...exact, ...others];

    final entryId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Match to a ledger voucher'),
        content: SizedBox(
          width: 420,
          child: ordered.isEmpty
              ? Text('No unmatched ledger entries to match against. '
                  'If this is a bank charge or interest, record it as a journal voucher first.',
                  style: TextStyle(color: crm.textSecondary))
              : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s.description.isEmpty ? '(no description)' : s.description} · ${_signed(s.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  8.h,
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: ordered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = ordered[i];
                        final isExact = (m.amount - s.amount).abs() < 0.01;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.narration.isEmpty ? m.voucherNo : m.narration,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${m.voucherNo} · ${_date(m.date)}'),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(_signed(m.amount),
                                style: TextStyle(fontWeight: FontWeight.w700, color: _amtColor(m.amount))),
                            if (isExact)
                              Text('exact', style: TextStyle(fontSize: 10, color: crm.success)),
                          ]),
                          onTap: () => Navigator.pop(ctx, m.entryId),
                        );
                      },
                    ),
                  ),
                ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );

    if (entryId == null || !mounted) return;
    await _run(() async {
      await ref.read(accountingServiceProvider).matchManual(s.id, entryId);
      ref.invalidate(reconciliationProvider(_accountId!));
      return null;
    }, 'Matched');
  }

  // ── Actions ──
  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        withData: true,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(friendlyErrorMessage(e, fallback: 'Could not open the file picker.'))));
      return;
    }
    if (picked == null || !mounted) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not read the selected file.')));
      return;
    }

    final result = parseBankStatement(bytes, file.name);
    if (!mounted) return;
    final confirmed = await _showImportPreview(file.name, result);
    if (confirmed != true || !mounted) return;

    await _run(() async {
      final res = await ref.read(accountingServiceProvider).importStatement(
            _accountId!,
            file.name,
            result.lines.map((l) => l.toJson()).toList(),
          );
      ref.invalidate(reconciliationProvider(_accountId!));
      return 'Imported ${res.imported} line${res.imported == 1 ? '' : 's'}'
          '${res.duplicates > 0 ? ', skipped ${res.duplicates} already there' : ''}';
    }, null);
  }

  Future<bool?> _showImportPreview(String fileName, StatementImportResult r) {
    final crm = context.crmColors;
    final sample = r.lines.take(6).toList();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Import $fileName'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.lines.length} line${r.lines.length == 1 ? '' : 's'} found'
                '${r.skipped > 0 ? ' · ${r.skipped} skipped' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final w in r.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $w', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              ),
            if (sample.isNotEmpty) ...[
              12.h,
              Text('Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.textSecondary)),
              6.h,
              for (final l in sample)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(width: 64, child: Text(_date(l.date), style: const TextStyle(fontSize: 12))),
                    Expanded(
                        child: Text(l.description.isEmpty ? '(no description)' : l.description,
                            style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(_signed(l.amount),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _amtColor(l.amount))),
                  ]),
                ),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: r.hasLines ? () => Navigator.pop(ctx, true) : null,
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _autoMatch() async {
    await _run(() async {
      final n = await ref.read(accountingServiceProvider).autoMatch(_accountId!);
      ref.invalidate(reconciliationProvider(_accountId!));
      return n == 0 ? 'No new matches found' : 'Matched $n line${n == 1 ? '' : 's'}';
    }, null);
  }

  Future<void> _unmatch(String statementLineId) async {
    await _run(() async {
      await ref.read(accountingServiceProvider).unmatch(statementLineId);
      ref.invalidate(reconciliationProvider(_accountId!));
      return null;
    }, 'Unmatched');
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear imported statement?'),
        content: const Text('This removes all imported statement lines for this account '
            '(matched and unmatched). Your ledger is not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final n = await ref.read(accountingServiceProvider).clearStatement(_accountId!);
      ref.invalidate(reconciliationProvider(_accountId!));
      return 'Cleared $n line${n == 1 ? '' : 's'}';
    }, null);
  }

  /// Run [action] with a busy guard, showing [okMsg] (or the action's returned
  /// message) on success and the error on failure.
  Future<void> _run(Future<Object?> Function() action, String? okMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await action();
      final msg = okMsg ?? (result is String ? result : null);
      if (mounted && msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
