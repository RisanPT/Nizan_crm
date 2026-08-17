import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/journal_entry.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_chrome.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_search_field.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/core/error/errors.dart';

String _money(num v) => v == 0
    ? ''
    : NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(v);

/// Finance → Trial Balance. Every account's closing debit/credit; the two
/// columns must be equal for the books to be in balance.
class TrialBalanceScreen extends ConsumerStatefulWidget {
  const TrialBalanceScreen({super.key});

  @override
  ConsumerState<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends ConsumerState<TrialBalanceScreen> {
  DateTime? _asOf;
  DateRangePreset _preset = DateRangePreset.allTime;
  String _search = '';
  TrialBalance? _last;

  bool _matches(TrialBalanceRow r) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${r.code} ${r.name} ${r.group} ${r.nature}'.toLowerCase().contains(q);
  }

  String get _asOfIso =>
      _asOf == null ? '' : DateTime(_asOf!.year, _asOf!.month, _asOf!.day).toIso8601String();

  Future<void> _applyPreset(DateRangePreset p) async {
    if (p == DateRangePreset.custom) {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: _asOf ?? now,
        firstDate: DateTime(2015),
        lastDate: DateTime(now.year + 1),
      );
      if (picked != null) {
        setState(() {
          _preset = p;
          _asOf = picked;
        });
      }
      return;
    }
    final r = rangeForPreset(p, DateTime.now());
    setState(() {
      _preset = p;
      _asOf = r.to;
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(trialBalanceProvider(_asOfIso));

    return Scaffold(
      backgroundColor: crm.background,
      body: ReportChrome(
        category: 'Business Overview',
        title: 'Trial Balance',
        asOf: true,
        preset: _preset,
        to: _asOf,
        onPreset: _applyPreset,
        onExport: _last == null ? null : () => _exportCsv(context, _last!),
        onRefresh: () async => ref.invalidate(trialBalanceProvider(_asOfIso)),
        child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(trialBalanceProvider(_asOfIso)),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive)))),
              ]),
              data: (tb) {
                _last = tb;
                if (tb.rows.isEmpty) {
                  return ListView(children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.balance_outlined, size: 56, color: crm.border),
                          12.h,
                          Text('Nothing to show yet', style: TextStyle(color: crm.textSecondary)),
                          6.h,
                          Text('Post a journal voucher and it appears here.',
                              style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                        ]),
                      ),
                    ),
                  ]);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
                    ReportTitleBlock(title: 'Trial Balance', asOf: true, to: _asOf),
                    ReportSearchField(
                      hint: 'Search an account…',
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    12.h,
                    _statusBar(crm, tb),
                    14.h,
                    _table(context, crm, tb),
                  ],
                );
              },
            ),
          ),
        ),
    );
  }

  Future<void> _exportCsv(BuildContext context, TrialBalance tb) async {
    final rows = <List<Object?>>[
      ['Trial Balance'],
      ['Code', 'Account', 'Group', 'Nature', 'Debit', 'Credit'],
      for (final r in tb.rows)
        [r.code, r.name, r.group, r.nature, csvNum(r.closingDebit), csvNum(r.closingCredit)],
      ['', 'TOTAL', '', '', csvNum(tb.totalDebit), csvNum(tb.totalCredit)],
    ];
    try {
      await downloadCsv('trial_balance.csv', rows);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Trial balance exported')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  Widget _statusBar(CrmTheme crm, TrialBalance tb) {
    final color = tb.balanced ? crm.success : crm.destructive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(tb.balanced ? Icons.verified_outlined : Icons.error_outline, size: 18, color: color),
        10.w,
        Text(tb.balanced ? 'Books are balanced' : 'Out of balance',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        const Spacer(),
        Text('${tb.rows.length} accounts', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
      ]),
    );
  }

  Widget _table(BuildContext context, CrmTheme crm, TrialBalance tb) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      ),
      child: Column(children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: crm.background.withValues(alpha: 0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Expanded(child: Text('ACCOUNT', style: _hdr(crm))),
            SizedBox(width: 110, child: Text('DEBIT', textAlign: TextAlign.right, style: _hdr(crm))),
            SizedBox(width: 110, child: Text('CREDIT', textAlign: TextAlign.right, style: _hdr(crm))),
          ]),
        ),
        for (final r in tb.rows.where(_matches))
          InkWell(
            onTap: r.accountId.isEmpty
                ? null
                : () => context.go('/company-finance/ledger?account=${r.accountId}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: crm.border.withValues(alpha: 0.4))),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.code} · ${r.name}',
                        style: TextStyle(fontSize: 13, color: crm.textPrimary, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (r.group.isNotEmpty)
                      Text(r.group, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                  ]),
                ),
                SizedBox(
                  width: 110,
                  child: Text(_money(r.closingDebit),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFB44A2C))),
                ),
                SizedBox(
                  width: 110,
                  child: Text(_money(r.closingCredit),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.success)),
                ),
              ]),
            ),
          ),
        // totals
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: crm.background.withValues(alpha: 0.5),
            border: Border(top: BorderSide(color: crm.border, width: 1.4)),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
          ),
          child: Row(children: [
            Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            SizedBox(
              width: 110,
              child: Text(NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(tb.totalDebit),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB44A2C))),
            ),
            SizedBox(
              width: 110,
              child: Text(NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(tb.totalCredit),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.success)),
            ),
          ]),
        ),
      ]),
    );
  }

  TextStyle _hdr(CrmTheme crm) => TextStyle(
      fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: crm.textSecondary);
}
