import 'package:flutter/material.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
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

enum PnlCompare { none, previousPeriod, previousYear }

String _compareLabel(PnlCompare c) => switch (c) {
      PnlCompare.none => 'None',
      PnlCompare.previousPeriod => 'Previous Period',
      PnlCompare.previousYear => 'Previous Year',
    };

/// Finance → Profit & Loss. Income − expense, derived from the ledger.
class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  ConsumerState<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends ConsumerState<ProfitLossScreen> {
  DateTime? _from;
  DateTime? _to;
  DateRangePreset _preset = DateRangePreset.allTime;
  PnlCompare _compare = PnlCompare.none;
  PnlReport? _last;

  String _iso(DateTime? d) => d == null ? '' : DateTime(d.year, d.month, d.day).toIso8601String();
  ({String from, String to}) get _range => (from: _iso(_from), to: _iso(_to));

  // The comparison window: same length immediately before, or the same dates a
  // year earlier. Requires a bounded current period.
  ({DateTime? from, DateTime? to}) get _compareDates {
    if (_from == null || _to == null) return (from: null, to: null);
    if (_compare == PnlCompare.previousYear) {
      return (
        from: DateTime(_from!.year - 1, _from!.month, _from!.day),
        to: DateTime(_to!.year - 1, _to!.month, _to!.day),
      );
    }
    final len = _to!.difference(_from!).inDays;
    final prevTo = _from!.subtract(const Duration(days: 1));
    return (from: prevTo.subtract(Duration(days: len)), to: prevTo);
  }

  ({String from, String to}) get _compareRange =>
      (from: _iso(_compareDates.from), to: _iso(_compareDates.to));

  bool get _comparing => _compare != PnlCompare.none && _from != null && _to != null;

  /// A "▲ 12%" / "▼ 5%" delta string for cur vs prev.
  String _delta(double cur, double prev) {
    if (prev == 0) return cur == 0 ? '—' : (cur > 0 ? '▲ new' : '▼ new');
    final pct = (cur - prev) / prev.abs() * 100;
    return '${pct >= 0 ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}%';
  }

  Future<void> _applyPreset(DateRangePreset p) async {
    if (p == DateRangePreset.custom) {
      final now = DateTime.now();
      final picked = await showBrandedDateRangePicker(
        context,
        firstDate: DateTime(2015),
        lastDate: DateTime(now.year + 1),
        initialDateRange: (_from != null && _to != null)
            ? DateTimeRange(start: _from!, end: _to!)
            : null,
      );
      if (picked != null) {
        setState(() {
          _preset = p;
          _from = picked.start;
          _to = picked.end;
        });
      }
      return;
    }
    final r = rangeForPreset(p, DateTime.now());
    setState(() {
      _preset = p;
      _from = r.from;
      _to = r.to;
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(profitLossProvider(_range));
    final compareAsync = _comparing ? ref.watch(profitLossProvider(_compareRange)) : null;

    return Scaffold(
      backgroundColor: crm.background,
      body: ReportChrome(
        category: 'Business Overview',
        title: 'Profit and Loss',
        preset: _preset,
        from: _from,
        to: _to,
        onPreset: _applyPreset,
        onExport: _last == null ? null : () => _exportCsv(context, _last!),
        onRefresh: () async => ref.invalidate(profitLossProvider(_range)),
        child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(profitLossProvider(_range)),
            child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive)))),
          ]),
          data: (r) {
            _last = r;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _compareBar(crm),
                ReportTitleBlock(title: 'Profit and Loss', from: _from, to: _to),
                if (_compare != PnlCompare.none && !_comparing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Pick a specific date range to compare periods.',
                        style: TextStyle(fontSize: 12.5, color: crm.warning)),
                  ),
                if (!_comparing)
                  ..._singleSections(crm, r)
                else
                  compareAsync!.when(
                    loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Padding(padding: const EdgeInsets.all(20), child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive))),
                    data: (prev) => Column(children: _comparedSections(crm, r, prev)),
                  ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _compareBar(CrmTheme crm) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          const Spacer(),
          Text('Compare with:', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
          8.w,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crm.border.withValues(alpha: 0.8)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PnlCompare>(
                value: _compare,
                isDense: true,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
                items: [
                  for (final c in PnlCompare.values)
                    DropdownMenuItem(value: c, child: Text(_compareLabel(c))),
                ],
                onChanged: (c) => setState(() => _compare = c ?? PnlCompare.none),
              ),
            ),
          ),
        ]),
      );

  List<Widget> _singleSections(CrmTheme crm, PnlReport r) {
    final loss = r.netProfit < 0;
    final resultColor = loss ? crm.destructive : crm.success;
    return [
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
    ];
  }

  List<Widget> _comparedSections(CrmTheme crm, PnlReport cur, PnlReport prev) {
    final netImproved = cur.netProfit >= prev.netProfit;
    final netColor = netImproved ? crm.success : crm.destructive;
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: netColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: netColor.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NET PROFIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
            4.h,
            Text(_money(cur.netProfit), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: netColor)),
            2.h,
            Text('was ${_money(prev.netProfit)}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ]),
          const Spacer(),
          Text(_delta(cur.netProfit, prev.netProfit),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: netColor)),
        ]),
      ),
      16.h,
      _comparedSection(crm, 'Income', cur.income, prev.income, cur.totalIncome, prev.totalIncome, crm.success),
      14.h,
      _comparedSection(crm, 'Expenses', cur.expense, prev.expense, cur.totalExpense, prev.totalExpense, const Color(0xFFB44A2C)),
    ];
  }

  Widget _comparedSection(CrmTheme crm, String title, List<ReportLine> curLines,
      List<ReportLine> prevLines, double curTotal, double prevTotal, Color color) {
    // Merge current + previous lines by account code.
    final merged = <String, ({String name, double cur, double prev})>{};
    for (final l in curLines) {
      merged[l.code] = (name: l.name, cur: l.amount, prev: 0);
    }
    for (final l in prevLines) {
      final e = merged[l.code];
      merged[l.code] = (name: e?.name ?? l.name, cur: e?.cur ?? 0, prev: l.amount);
    }
    final rows = merged.entries.toList()..sort((a, b) => b.value.cur.compareTo(a.value.cur));

    TextStyle hdr() => TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: crm.textSecondary);
    Widget cell(String t, {Color? c, bool bold = false}) => Text(t,
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: c ?? crm.textPrimary));

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            8.w,
            Expanded(child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textPrimary))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(children: [
            Expanded(flex: 5, child: Text('ACCOUNT', style: hdr())),
            Expanded(flex: 3, child: Text('CURRENT', textAlign: TextAlign.right, style: hdr())),
            Expanded(flex: 3, child: Text('PREVIOUS', textAlign: TextAlign.right, style: hdr())),
            Expanded(flex: 2, child: Text('CHANGE', textAlign: TextAlign.right, style: hdr())),
          ]),
        ),
        for (final e in rows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(children: [
              Expanded(flex: 5, child: Text(e.value.name, style: TextStyle(fontSize: 12.5, color: crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Expanded(flex: 3, child: cell(_money(e.value.cur))),
              Expanded(flex: 3, child: cell(_money(e.value.prev), c: crm.textSecondary)),
              Expanded(flex: 2, child: cell(_delta(e.value.cur, e.value.prev), c: crm.textSecondary)),
            ]),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: crm.background.withValues(alpha: 0.4),
            border: Border(top: BorderSide(color: crm.border)),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
          ),
          child: Row(children: [
            Expanded(flex: 5, child: Text('Total $title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            Expanded(flex: 3, child: cell(_money(curTotal), c: color, bold: true)),
            Expanded(flex: 3, child: cell(_money(prevTotal), c: crm.textSecondary, bold: true)),
            Expanded(flex: 2, child: cell(_delta(curTotal, prevTotal), c: crm.textSecondary, bold: true)),
          ]),
        ),
      ]),
    );
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
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  /// Drill into an account's transactions (the Zoho "Account Transactions"
  /// view), carrying the current date window.
  void _openLedger(ReportLine l) {
    final q = <String, String>{'account': l.accountId};
    if (_from != null) q['from'] = _iso(_from);
    if (_to != null) q['to'] = _iso(_to);
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
            child: Align(alignment: Alignment.centerLeft, child: Text('Nothing recorded', style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          )
        else
          for (final l in lines)
            InkWell(
              onTap: l.accountId.isEmpty ? null : () => _openLedger(l),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Text('${l.code} · ${l.name}',
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
