import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/report_models.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/date_filter_chip.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

/// Finance → Profit & Loss. Income − expense, derived from the ledger.
class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  ConsumerState<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends ConsumerState<ProfitLossScreen> {
  DateTime? _from;
  DateTime? _to;

  String _iso(DateTime? d) => d == null ? '' : DateTime(d.year, d.month, d.day).toIso8601String();
  ({String from, String to}) get _range => (from: _iso(_from), to: _iso(_to));

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(profitLossProvider(_range));

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        _dateBar(crm),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(profitLossProvider(_range)),
            child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('$e', style: TextStyle(color: crm.destructive)))),
          ]),
          data: (r) {
            final loss = r.netProfit < 0;
            final resultColor = loss ? crm.destructive : crm.success;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _exportCsv(context, r),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Export CSV'),
                  ),
                ),
                // Net result banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: resultColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(loss ? Icons.trending_down_rounded : Icons.trending_up_rounded, color: resultColor, size: 26),
                    12.w,
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(loss ? 'Net Loss' : 'Net Profit',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
                      2.h,
                      Text(_money(r.netProfit.abs()),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: resultColor)),
                    ]),
                    const Spacer(),
                    if (r.totalIncome > 0)
                      Text('${((r.netProfit / r.totalIncome) * 100).toStringAsFixed(1)}% margin',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ]),
                ),
                16.h,
                _section(crm, 'Income', r.income, r.totalIncome, crm.success),
                14.h,
                _section(crm, 'Expenses', r.expense, r.totalExpense, const Color(0xFFB44A2C)),
              ],
            );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _dateBar(CrmTheme crm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        DateFilterChip(
          label: 'From',
          date: _from,
          onTap: () => _pick(true),
          onClear: () => setState(() => _from = null),
        ),
        const SizedBox(width: 8),
        DateFilterChip(
          label: 'To',
          date: _to,
          onTap: () => _pick(false),
          onClear: () => setState(() => _to = null),
        ),
      ]),
    );
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

  Future<void> _exportCsv(BuildContext context, PnlReport r) async {
    final rows = <List<Object?>>[
      ['Profit & Loss'],
      ['Section', 'Code', 'Account', 'Amount'],
      for (final l in r.income) ['Income', l.code, l.name, csvNum(l.amount)],
      ['', '', 'Total Income', csvNum(r.totalIncome)],
      for (final l in r.expense) ['Expense', l.code, l.name, csvNum(l.amount)],
      ['', '', 'Total Expense', csvNum(r.totalExpense)],
      [r.netProfit < 0 ? 'Net Loss' : 'Net Profit', '', '', csvNum(r.netProfit)],
    ];
    try {
      await downloadCsv('profit_and_loss.csv', rows);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('P&L exported')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
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
            child: Align(alignment: Alignment.centerLeft, child: Text('Nothing recorded', style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          )
        else
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(children: [
                Expanded(
                  child: Text('${l.code} · ${l.name}',
                      style: TextStyle(fontSize: 13, color: crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text(_money(l.amount),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary)),
              ]),
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
