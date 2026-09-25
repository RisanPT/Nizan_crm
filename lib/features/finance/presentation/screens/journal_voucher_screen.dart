import 'package:flutter/material.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/chart_account.dart';
import 'package:nizan_crm/features/finance/data/journal_entry.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/date_filter_chip.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/show_more_button.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(v);
String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

/// Finance → Journal. Post and review double-entry vouchers.
class JournalVoucherScreen extends ConsumerStatefulWidget {
  const JournalVoucherScreen({super.key, this.initialSearch});

  /// Pre-fill the search box (e.g. a voucher no. drilled in from the Ledger).
  final String? initialSearch;

  @override
  ConsumerState<JournalVoucherScreen> createState() => _JournalVoucherScreenState();
}

class _JournalVoucherScreenState extends ConsumerState<JournalVoucherScreen> {
  String _type = 'all';
  String _status = 'posted'; // hide void by default
  DateTime? _from;
  DateTime? _to;
  final _searchCtrl = TextEditingController();
  String _search = '';
  int _visible = kFinancePageSize;

  String _iso(DateTime? d) => d == null ? '' : DateTime(d.year, d.month, d.day).toIso8601String();
  ({String type, String status, String from, String to}) get _filter =>
      (type: _type, status: _status, from: _iso(_from), to: _iso(_to));

  @override
  void initState() {
    super.initState();
    final q = widget.initialSearch?.trim() ?? '';
    if (q.isNotEmpty) {
      _search = q;
      _searchCtrl.text = q;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Client-side text match over voucher no, narration, type and the accounts
  /// on each line — instant, within the current type/status/date selection.
  bool _matchesSearch(JournalEntry e) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = StringBuffer()
      ..write(e.voucherNo)
      ..write(' ')
      ..write(e.narration)
      ..write(' ')
      ..write(voucherTypeLabel(e.voucherType));
    for (final l in e.lines) {
      hay
        ..write(' ')
        ..write(l.accountCode)
        ..write(' ')
        ..write(l.accountName);
    }
    return hay.toString().toLowerCase().contains(q);
  }

  Future<void> _pick(bool from) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => from ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(journalEntriesProvider(_filter));

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'ledger-sync',
            backgroundColor: crm.surface,
            foregroundColor: crm.primary,
            tooltip: 'Post bookings, collections, expenses & payroll into the ledger',
            onPressed: () => _sync(context, ref),
            child: const Icon(Icons.sync),
          ),
          12.h,
          FloatingActionButton.extended(
            heroTag: 'ledger-new',
            backgroundColor: crm.primary,
            icon: const Icon(Icons.post_add, color: Colors.white),
            label: const Text('New Voucher', style: TextStyle(color: Colors.white)),
            onPressed: () => showDialog(context: context, builder: (_) => const _VoucherDialog()),
          ),
        ],
      ),
      body: Column(children: [
        _lockBanner(context, ref, crm),
        _filterBar(crm),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(journalEntriesProvider(_filter)),
            child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            AppErrorView(error: e, onRetry: () => ref.invalidate(journalEntriesProvider(_filter))),
          ]),
          data: (all) {
            final entries = all.where(_matchesSearch).toList();
            if (entries.isEmpty) {
              final searchingOrFiltering =
                  _search.isNotEmpty || _type != 'all' || _status != 'posted' || _from != null || _to != null;
              return ListView(children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(searchingOrFiltering ? Icons.search_off : Icons.receipt_long_outlined, size: 56, color: crm.border),
                      12.h,
                      Text(searchingOrFiltering ? 'No vouchers match your filters' : 'No vouchers posted yet',
                          style: TextStyle(color: crm.textSecondary)),
                      6.h,
                      Text(
                          searchingOrFiltering
                              ? 'Try clearing the search or widening the date range.'
                              : 'Tap "New Voucher" to post your first journal entry.',
                          style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                    ]),
                  ),
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final e in entries.take(_visible)) _entryCard(context, ref, crm, e),
                ShowMoreButton(
                  remaining: entries.length - _visible,
                  onPressed: () => setState(() => _visible += kFinancePageSize),
                ),
              ],
            );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _filterBar(CrmTheme crm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search voucher no, narration, account…',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                  ),
          ),
        ),
        10.h,
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type', isDense: true),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All types')),
                for (final t in kVoucherTypes)
                  DropdownMenuItem(value: t, child: Text(voucherTypeLabel(t))),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'all'),
            ),
          ),
          10.w,
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status', isDense: true),
              items: const [
                DropdownMenuItem(value: 'posted', child: Text('Posted')),
                DropdownMenuItem(value: 'all', child: Text('All (incl. void)')),
                DropdownMenuItem(value: 'void', child: Text('Void')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'posted'),
            ),
          ),
        ]),
        8.h,
        Row(children: [
          DateFilterChip(label: 'From', date: _from, onTap: () => _pick(true), onClear: () => setState(() => _from = null)),
          8.w,
          DateFilterChip(label: 'To', date: _to, onTap: () => _pick(false), onClear: () => setState(() => _to = null)),
        ]),
      ]),
    );
  }

  /// Period-lock status + close/reopen control.
  Widget _lockBanner(BuildContext context, WidgetRef ref, CrmTheme crm) {
    final async = ref.watch(accountingSettingsProvider);
    return async.maybeWhen(
      data: (s) {
        if (!s.isLocked) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _closeBooks(context, ref),
                icon: const Icon(Icons.lock_outline, size: 15),
                label: const Text('Close books through…'),
                style: TextButton.styleFrom(foregroundColor: crm.textSecondary),
              ),
            ),
          );
        }
        final d = DateFormat('d MMM yyyy').format(s.lockDate!);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: crm.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: crm.warning.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Icon(Icons.lock_rounded, size: 16, color: crm.warning),
            8.w,
            Expanded(
              child: Text('Books closed through $d — no posting on or before this date.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary)),
            ),
            TextButton(onPressed: () => _reopenBooks(context, ref), child: const Text('Reopen')),
          ]),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Future<void> _closeBooks(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Close the books through this date',
    );
    if (picked == null || !context.mounted) return;
    try {
      await ref.read(accountingServiceProvider).setLockDate(picked);
      ref.refreshData.accountingSettings();
      messenger.showSnackBar(SnackBar(content: Text('Books closed through ${DateFormat('d MMM yyyy').format(picked)}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _reopenBooks(BuildContext context, WidgetRef ref) async {
    final crm = context.crmColors;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: crm.surface,
        title: const Text('Reopen the books?'),
        content: Text('This removes the period lock so entries can be posted into earlier dates again.',
            style: TextStyle(color: crm.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
            child: const Text('Reopen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(accountingServiceProvider).setLockDate(null);
      ref.refreshData.accountingSettings();
      messenger.showSnackBar(const SnackBar(content: Text('Books reopened')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Widget _entryCard(BuildContext context, WidgetRef ref, CrmTheme crm, JournalEntry e) {
    final isVoid = e.status == 'void';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.faded(0.8)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(e.voucherNo.isEmpty ? voucherTypeLabel(e.voucherType) : e.voucherNo,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.primary)),
            ),
            8.w,
            Text(voucherTypeLabel(e.voucherType), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            const Spacer(),
            Text(_fmtDate(e.date), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            if (!isVoid)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: crm.textSecondary),
                onSelected: (v) { if (v == 'void') _void(context, ref, e); },
                itemBuilder: (_) => const [PopupMenuItem(value: 'void', child: Text('Void entry'))],
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _pill(crm, 'VOID', crm.destructive),
              ),
          ]),
        ),
        Divider(height: 1, color: crm.border.faded(0.6)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(children: [
            for (final l in e.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      l.credit > 0 ? '        ${l.accountCode} · ${l.accountName}' : '${l.accountCode} · ${l.accountName}',
                      style: TextStyle(fontSize: 13, color: crm.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  8.w,
                  SizedBox(
                    width: 96,
                    child: Text(l.debit > 0 ? _money(l.debit) : '',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12.5, fontFeatures: const [], color: const Color(0xFFB44A2C), fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: 96,
                    child: Text(l.credit > 0 ? _money(l.credit) : '',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12.5, color: crm.success, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            if (e.narration.isNotEmpty) ...[
              6.h,
              Align(alignment: Alignment.centerLeft, child: Text('Narration: ${e.narration}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontStyle: FontStyle.italic))),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _pill(CrmTheme crm, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
      );

  /// Post existing operations into the ledger (idempotent backfill).
  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final crm = context.crmColors;
    final messenger = ScaffoldMessenger.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: crm.surface,
        title: const Text('Sync from operations'),
        content: Text(
          'Post your bookings, collections, expenses, payroll and returns into '
          'the ledger as journal vouchers. Safe to run again — it replaces the '
          'auto-generated entries, and never touches vouchers you keyed by hand.',
          style: TextStyle(color: crm.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
            child: const Text('Sync now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final posted = await ref.read(accountingServiceProvider).backfill();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      ref.refreshData.financeReports();
      messenger.showSnackBar(SnackBar(content: Text('Posted $posted voucher${posted == 1 ? '' : 's'} from operations')));
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _void(BuildContext context, WidgetRef ref, JournalEntry e) async {
    final crm = context.crmColors;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: crm.surface,
        title: const Text('Void this voucher?'),
        content: Text('${e.voucherNo} will be marked void and excluded from the ledger. This keeps the audit trail.',
            style: TextStyle(color: crm.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Void', style: TextStyle(color: crm.destructive))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(accountingServiceProvider).voidJournal(e.id);
      ref.refreshData.financeReports();
      messenger.showSnackBar(const SnackBar(content: Text('Voucher voided')));
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(err))));
    }
  }
}

class _LineDraft {
  String? accountId;
  final TextEditingController debit = TextEditingController();
  final TextEditingController credit = TextEditingController();
  void dispose() {
    debit.dispose();
    credit.dispose();
  }
}

class _VoucherDialog extends ConsumerStatefulWidget {
  const _VoucherDialog();
  @override
  ConsumerState<_VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends ConsumerState<_VoucherDialog> {
  DateTime _date = DateTime.now();
  String _type = 'journal';
  final _narration = TextEditingController();
  final List<_LineDraft> _lines = [_LineDraft(), _LineDraft()];
  bool _saving = false;

  @override
  void dispose() {
    _narration.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _totalDr => _lines.fold(0, (a, l) => a + (double.tryParse(l.debit.text.trim()) ?? 0));
  double get _totalCr => _lines.fold(0, (a, l) => a + (double.tryParse(l.credit.text.trim()) ?? 0));
  bool get _balanced {
    final dr = (_totalDr * 100).round();
    final cr = (_totalCr * 100).round();
    return dr == cr && dr > 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final lines = _lines
        .where((l) => l.accountId != null &&
            ((double.tryParse(l.debit.text.trim()) ?? 0) > 0 ||
                (double.tryParse(l.credit.text.trim()) ?? 0) > 0))
        .map((l) => {
              'account': l.accountId,
              'debit': double.tryParse(l.debit.text.trim()) ?? 0,
              'credit': double.tryParse(l.credit.text.trim()) ?? 0,
            })
        .toList();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(accountingServiceProvider).createJournal({
        'date': _date.toIso8601String(),
        'voucherType': _type,
        'narration': _narration.text.trim(),
        'lines': lines,
      });
      ref.refreshData.financeReports();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Voucher posted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final accountsAsync = ref.watch(chartAccountsProvider('all'));
    final diff = ((_totalDr - _totalCr) * 100).round() / 100;

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New Journal Voucher', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          14.h,
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today, size: 16)),
                  child: Text(_fmtDate(_date)),
                ),
              ),
            ),
            12.w,
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Voucher type'),
                items: [for (final t in kVoucherTypes) DropdownMenuItem(value: t, child: Text(voucherTypeLabel(t)))],
                onChanged: (v) => setState(() => _type = v ?? 'journal'),
              ),
            ),
          ]),
          14.h,
          accountsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, compact: true, onRetry: () => ref.invalidate(chartAccountsProvider('all'))),
            data: (accounts) {
              if (accounts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('No accounts yet — seed the Chart of Accounts first.',
                      style: TextStyle(color: crm.destructive)),
                );
              }
              return Flexible(
                child: SingleChildScrollView(
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: Text('Account', style: _hdr(crm))),
                      SizedBox(width: 110, child: Text('Debit', textAlign: TextAlign.right, style: _hdr(crm))),
                      SizedBox(width: 110, child: Text('Credit', textAlign: TextAlign.right, style: _hdr(crm))),
                      const SizedBox(width: 34),
                    ]),
                    6.h,
                    for (var i = 0; i < _lines.length; i++) _lineRow(crm, accounts, i),
                    8.h,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _lines.add(_LineDraft())),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add line'),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
          10.h,
          TextField(
            controller: _narration,
            decoration: const InputDecoration(labelText: 'Narration', isDense: true),
          ),
          12.h,
          _balanceBar(crm, diff),
          14.h,
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            8.w,
            ElevatedButton(
              onPressed: (_saving || !_balanced) ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Post voucher', style: TextStyle(color: Colors.white)),
            ),
          ]),
        ]),
      ),
    );
  }

  TextStyle _hdr(CrmTheme crm) => TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: crm.textSecondary);

  Widget _lineRow(CrmTheme crm, List<ChartAccount> accounts, int i) {
    final l = _lines[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: l.accountId,
            isExpanded: true,
            isDense: true,
            decoration: const InputDecoration(isDense: true, hintText: 'Select account'),
            items: [
              for (final a in accounts)
                DropdownMenuItem(value: a.id, child: Text('${a.code} · ${a.name}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => l.accountId = v),
          ),
        ),
        8.w,
        SizedBox(
          width: 110,
          child: TextField(
            controller: l.debit,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(isDense: true, hintText: '0'),
            onChanged: (v) {
              if (v.trim().isNotEmpty && l.credit.text.isNotEmpty) l.credit.clear();
              setState(() {});
            },
          ),
        ),
        8.w,
        SizedBox(
          width: 110,
          child: TextField(
            controller: l.credit,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(isDense: true, hintText: '0'),
            onChanged: (v) {
              if (v.trim().isNotEmpty && l.debit.text.isNotEmpty) l.debit.clear();
              setState(() {});
            },
          ),
        ),
        SizedBox(
          width: 34,
          child: _lines.length > 2
              ? IconButton(
                  icon: Icon(Icons.close, size: 16, color: crm.textSecondary),
                  onPressed: () => setState(() {
                    _lines.removeAt(i).dispose();
                  }),
                )
              : null,
        ),
      ]),
    );
  }

  Widget _balanceBar(CrmTheme crm, double diff) {
    final ok = _balanced;
    final color = ok ? crm.success : crm.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.balance, size: 16, color: color),
        8.w,
        Text(ok ? 'Balanced' : 'Out of balance', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        const Spacer(),
        Text('Dr ${_money(_totalDr)}   Cr ${_money(_totalCr)}',
            style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        if (!ok && diff != 0) ...[
          8.w,
          Text('Δ ${_money(diff.abs())}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ]),
    );
  }
}
