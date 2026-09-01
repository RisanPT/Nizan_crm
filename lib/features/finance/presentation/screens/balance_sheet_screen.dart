import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/report_models.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_chrome.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/core/error/errors.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

/// Finance → Balance Sheet. Assets = Liabilities + Equity (incl. earnings).
class BalanceSheetScreen extends ConsumerStatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  ConsumerState<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends ConsumerState<BalanceSheetScreen> {
  DateTime? _asOf;
  DateRangePreset _preset = DateRangePreset.allTime;
  BalanceSheetReport? _last;

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
      _asOf = r.to; // balance sheet is "as of" the end of the range
    });
  }

  List<ReportLine> _equityLines(BalanceSheetReport r) => [
        ...r.equity,
        if (r.retainedEarnings != 0)
          ReportLine(code: '—', name: 'Retained Earnings (current)', amount: r.retainedEarnings),
      ];

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(balanceSheetProvider(_asOfIso));

    return Scaffold(
      backgroundColor: crm.background,
      body: ReportChrome(
        category: 'Business Overview',
        title: 'Balance Sheet',
        asOf: true,
        preset: _preset,
        to: _asOf,
        onPreset: _applyPreset,
        onExport: _last == null ? null : () => _exportCsv(context, _last!, _equityLines(_last!)),
        onRefresh: () async => ref.invalidate(balanceSheetProvider(_asOfIso)),
        child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(balanceSheetProvider(_asOfIso)),
            child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive)))),
          ]),
          data: (r) {
            _last = r;
            final color = r.balanced ? crm.success : crm.destructive;
            final equityLines = _equityLines(r);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                ReportTitleBlock(title: 'Balance Sheet', asOf: true, to: _asOf),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(r.balanced ? Icons.verified_outlined : Icons.error_outline, size: 18, color: color),
                    10.w,
                    Text(r.balanced ? 'Balance sheet is balanced' : 'Out of balance',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                    const Spacer(),
                    Text(_money(r.totalAssets), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textSecondary)),
                  ]),
                ),
                16.h,
                _section(crm, 'Assets', r.assets, r.totalAssets, const Color(0xFF0D9488)),
                14.h,
                _section(crm, 'Liabilities', r.liabilities, r.totalLiabilities, const Color(0xFFB44A2C)),
                14.h,
                _section(crm, 'Equity', equityLines, r.totalEquity, const Color(0xFF7C3AED)),
                14.h,
                // Accounting equation footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: crm.border.withValues(alpha: 0.8)),
                  ),
                  child: Column(children: [
                    _footRow(crm, 'Total Assets', r.totalAssets, false),
                    8.h,
                    _footRow(crm, 'Total Liabilities + Equity', r.liabilitiesAndEquity, true),
                  ]),
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(
      BuildContext context, BalanceSheetReport r, List<ReportLine> equityLines) async {
    final rows = <List<Object?>>[
      ['Balance Sheet'],
      ['Section', 'Code', 'Account', 'Amount'],
      for (final l in r.assets) ['Asset', l.code, l.name, csvNum(l.amount)],
      ['', '', 'Total Assets', csvNum(r.totalAssets)],
      for (final l in r.liabilities) ['Liability', l.code, l.name, csvNum(l.amount)],
      ['', '', 'Total Liabilities', csvNum(r.totalLiabilities)],
      for (final l in equityLines) ['Equity', l.code, l.name, csvNum(l.amount)],
      ['', '', 'Total Equity', csvNum(r.totalEquity)],
      ['', '', 'Total Liabilities + Equity', csvNum(r.liabilitiesAndEquity)],
    ];
    try {
      await downloadCsv('balance_sheet.csv', rows);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Balance sheet exported')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  Widget _footRow(CrmTheme crm, String label, double v, bool strong) {
    return Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w600, color: crm.textPrimary))),
      Text(_money(v), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: crm.textPrimary)),
    ]);
  }

  /// Drill into an account's transactions up to the as-of date.
  void _openLedger(ReportLine l) {
    final q = <String, String>{'account': l.accountId};
    if (_asOf != null) {
      q['to'] = DateTime(_asOf!.year, _asOf!.month, _asOf!.day).toIso8601String();
    }
    final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    context.push('/company-finance/ledger?$qs');
  }

  Widget _section(CrmTheme crm, String title, List<ReportLine> lines, double total, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            8.w,
            Text(title.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textPrimary)),
          ]),
        ),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Align(alignment: Alignment.centerLeft, child: Text('None', style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          )
        else
          for (final l in lines)
            InkWell(
              onTap: l.accountId.isEmpty ? null : () => _openLedger(l),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(l.code == '—' ? l.name : '${l.code} · ${l.name}',
                        style: TextStyle(
                            fontSize: 13,
                            color: l.accountId.isEmpty ? crm.textPrimary : crm.primary,
                            fontWeight: l.accountId.isEmpty ? FontWeight.w400 : FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(_money(l.amount),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  if (l.accountId.isNotEmpty)
                    Icon(Icons.chevron_right, size: 16, color: crm.textSecondary),
                ]),
              ),
            ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: crm.background.withValues(alpha: 0.4),
            border: Border(top: BorderSide(color: crm.border)),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
          ),
          child: Row(children: [
            Expanded(child: Text('Total $title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            Text(_money(total), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          ]),
        ),
      ]),
    );
  }
}
