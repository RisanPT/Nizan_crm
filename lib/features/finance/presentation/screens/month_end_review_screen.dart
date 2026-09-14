import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/month_year_picker.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
String _pctS(num v) => '${v.toStringAsFixed(1)}%';

/// Finance → Month-End Review: the 90-minute CEO finance review in one screen.
/// Ten sections, each measuring the closed month against the plan, with
/// drill-downs into the detailed reports.
class MonthEndReviewScreen extends ConsumerStatefulWidget {
  const MonthEndReviewScreen({super.key});

  @override
  ConsumerState<MonthEndReviewScreen> createState() => _MonthEndReviewScreenState();
}

class _MonthEndReviewScreenState extends ConsumerState<MonthEndReviewScreen> {
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
  }

  Period get _key => (month: _month, year: _year);

  void _shift(int delta) {
    setState(() {
      var m = _month + delta;
      var y = _year;
      if (m < 1) { m = 12; y--; }
      if (m > 12) { m = 1; y++; }
      _month = m;
      _year = y;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthYearPicker(context, month: _month, year: _year);
    if (picked != null) setState(() { _month = picked.month; _year = picked.year; });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(monthEndReviewProvider(_key));
    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(monthEndReviewProvider(_key)),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            _monthBar(crm, null),
            AppErrorView(error: e, onRetry: () => ref.invalidate(monthEndReviewProvider(_key))),
          ]),
          data: (r) => ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
            children: [
              _monthBar(crm, r),
              12.h,
              _kpiStrip(crm, r),
              14.h,
              _revenue(crm, r),
              _profitability(crm, r),
              _cashFlow(crm, r),
              _receivables(crm, r),
              _payables(crm, r),
              _budget(crm, r),
              _workingCapital(crm, r),
              _risk(crm, r),
              _decisions(crm, r),
              12.h,
              _planningLink(crm),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header: month navigator + export ──────────────────────────────────────
  Widget _monthBar(CrmTheme crm, MonthEndReview? r) {
    final label = r?.periodLabel ??
        '${const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_month]} $_year';
    return Row(children: [
      IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
      Expanded(
        child: InkWell(
          onTap: _pickMonth,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              Text('Month-End Review',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                4.w,
                Icon(Icons.arrow_drop_down, color: crm.textSecondary),
              ]),
            ]),
          ),
        ),
      ),
      IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
      if (r != null)
        IconButton(
          tooltip: 'Export',
          onPressed: () => _export(r),
          icon: const Icon(Icons.download_outlined),
        ),
    ]);
  }

  // ── KPI strip ─────────────────────────────────────────────────────────────
  Widget _kpiStrip(CrmTheme crm, MonthEndReview r) {
    final tiles = <Widget>[
      _kpiTile(crm, 'Revenue', _money(r.revenue),
          sub: r.revenueGrowthPct >= 0 ? '▲ ${_pctS(r.revenueGrowthPct)}' : '▼ ${_pctS(r.revenueGrowthPct.abs())}',
          subColor: r.revenueGrowthPct >= 0 ? crm.success : crm.destructive),
      _kpiTile(crm, 'Net Profit', _money(r.netProfit), sub: '${_pctS(r.netMarginPct)} margin'),
      _kpiTile(crm, 'EBITDA', _money(r.ebitda), sub: '${_pctS(r.ebitdaMarginPct)} margin'),
      _kpiTile(crm, 'Liquid Cash', _money(r.totalLiquid),
          sub: r.cashRunwayMonths != null ? '${r.cashRunwayMonths!.toStringAsFixed(1)} mo runway' : 'positive'),
      _kpiTile(crm, 'Receivables', _money(r.arOutstanding), sub: '${_money(r.arOverdue)} overdue', subColor: crm.destructive),
      _kpiTile(crm, 'Rev / Employee', _money(r.revenuePerEmployee), sub: '${r.employeeCount} staff'),
      _kpiTile(crm, 'CAC', _money(r.cac), sub: '${r.newCustomers} new customers'),
      _kpiTile(crm, 'LTV', _money(r.ltv), sub: 'per customer'),
    ];
    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, _) => 10.w,
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }

  Widget _kpiTile(CrmTheme crm, String label, String value, {String? sub, Color? subColor}) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary)),
        6.h,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary)),
        ),
        if (sub != null) ...[
          2.h,
          Text(sub, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subColor ?? crm.textSecondary)),
        ],
      ]),
    );
  }

  // ── Section scaffold ──────────────────────────────────────────────────────
  Widget _section(CrmTheme crm, int n, String title, IconData icon, List<Widget> children,
      {String? detailRoute, String? detailLabel}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border.withValues(alpha: 0.6)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            leading: CircleAvatar(
              radius: 15,
              backgroundColor: crm.primary.withValues(alpha: 0.12),
              child: Icon(icon, size: 17, color: crm.primary),
            ),
            title: Text('$n. $title',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            children: [
              ...children,
              if (detailRoute != null) ...[
                8.h,
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.push(detailRoute),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(detailLabel ?? 'View details'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricRow(CrmTheme crm, String label, String value, {Color? valueColor, String? badge, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: crm.textSecondary))),
        if (badge != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: (badgeColor ?? crm.primary).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badgeColor ?? crm.primary)),
          ),
          8.w,
        ],
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor ?? crm.textPrimary)),
      ]),
    );
  }

  // Traffic-light badge for actual vs target.
  ({String text, Color color})? _target(CrmTheme crm, double? achievedPct) {
    if (achievedPct == null) return null;
    final c = achievedPct >= 100 ? crm.success : achievedPct >= 80 ? crm.warning : crm.destructive;
    return (text: '${achievedPct.toStringAsFixed(0)}% of target', color: c);
  }

  // ── 1. Revenue ────────────────────────────────────────────────────────────
  Widget _revenue(CrmTheme crm, MonthEndReview r) {
    final t = _target(crm, r.revenueTargetPct);
    return _section(crm, 1, 'Revenue Review', Icons.trending_up_rounded, [
      _metricRow(crm, 'Revenue this month', _money(r.revenue),
          badge: t?.text, badgeColor: t?.color),
      _metricRow(crm, 'Previous month', _money(r.revenuePrev)),
      _metricRow(crm, 'Growth vs last month', _pctS(r.revenueGrowthPct),
          valueColor: r.revenueGrowthPct >= 0 ? crm.success : crm.destructive),
      _metricRow(crm, 'Orders', '${r.orders}'),
      _metricRow(crm, 'Average order value', _money(r.avgOrderValue)),
      if (r.revenueByUnit.isNotEmpty) ...[
        10.h,
        Text('BY BRANCH / REGION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
        6.h,
        for (final u in r.revenueByUnit.take(6)) _metricRow(crm, u.label, _money(u.amount)),
      ],
    ], detailRoute: '/company-finance/sales/by-customer', detailLabel: 'Sales reports');
  }

  // ── 2. Profitability ──────────────────────────────────────────────────────
  Widget _profitability(CrmTheme crm, MonthEndReview r) {
    final t = _target(crm, r.profitTargetPct);
    return _section(crm, 2, 'Profitability', Icons.savings_outlined, [
      _metricRow(crm, 'Gross Profit', '${_money(r.grossProfit)}  (${_pctS(r.grossMarginPct)})'),
      _metricRow(crm, 'EBITDA', '${_money(r.ebitda)}  (${_pctS(r.ebitdaMarginPct)})'),
      _metricRow(crm, 'Net Profit (PAT)', '${_money(r.netProfit)}  (${_pctS(r.netMarginPct)})',
          valueColor: r.netProfit >= 0 ? crm.success : crm.destructive, badge: t?.text, badgeColor: t?.color),
      _metricRow(crm, 'Depreciation', _money(r.depreciation)),
      _metricRow(crm, 'Total expenses', _money(r.totalExpense)),
      if (r.profitNote.isNotEmpty) ...[
        8.h,
        Text(r.profitNote, style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: crm.textSecondary)),
      ],
    ], detailRoute: '/company-finance/profit-loss', detailLabel: 'Profit & Loss');
  }

  // ── 3. Cash flow ──────────────────────────────────────────────────────────
  Widget _cashFlow(CrmTheme crm, MonthEndReview r) {
    return _section(crm, 3, 'Cash Flow', Icons.account_balance_wallet_outlined, [
      _metricRow(crm, 'Cash received', _money(r.cashReceived), valueColor: crm.success),
      _metricRow(crm, 'Cash paid', _money(r.cashPaid), valueColor: crm.destructive),
      _metricRow(crm, 'Net cash flow', _money(r.cashNet), valueColor: r.cashNet >= 0 ? crm.success : crm.destructive),
      _metricRow(crm, 'CapEx (asset purchases)', _money(r.capex), valueColor: crm.destructive),
      _metricRow(crm, 'Free cash flow', _money(r.freeCashFlow),
          valueColor: r.freeCashFlow >= 0 ? crm.success : crm.destructive),
      const Divider(height: 20),
      _metricRow(crm, 'Bank balance', _money(r.bankBalance)),
      _metricRow(crm, 'Cash balance', _money(r.cashBalance)),
      _metricRow(crm, 'Total liquid', _money(r.totalLiquid), valueColor: crm.primary),
      if (r.forecast.isNotEmpty) ...[
        10.h,
        Text('FORECAST — NEXT 60–90 DAYS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
        6.h,
        for (final f in r.forecast)
          _metricRow(crm, '${f.label}  (in ${_money(f.inflow)} · out ${_money(f.outflow)})',
              _money(f.closingCash),
              valueColor: f.closingCash >= 0 ? crm.textPrimary : crm.destructive,
              badge: f.net >= 0 ? '+${_money(f.net)}' : _money(f.net),
              badgeColor: f.net >= 0 ? crm.success : crm.destructive),
        4.h,
        Text('Projection: receivables coming due vs current expense run-rate + subscription renewals.',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: crm.textSecondary)),
      ],
    ], detailRoute: '/company-finance/ledger', detailLabel: 'General ledger');
  }

  // ── 4. Receivables ────────────────────────────────────────────────────────
  Widget _receivables(CrmTheme crm, MonthEndReview r) {
    return _section(crm, 4, 'Accounts Receivable', Icons.call_received_rounded, [
      _metricRow(crm, 'Outstanding', _money(r.arOutstanding)),
      _metricRow(crm, 'Overdue', _money(r.arOverdue), valueColor: crm.destructive),
      _metricRow(crm, 'Not yet due', _money(r.arNotYetDue)),
      _metricRow(crm, 'Collection efficiency', _pctS(r.collectionEfficiencyPct),
          valueColor: r.collectionEfficiencyPct >= 60 ? crm.success : crm.warning),
      _metricRow(crm, 'Days sales outstanding (DSO)',
          r.dso != null ? '${r.dso!.toStringAsFixed(0)} days' : '—'),
      8.h,
      _bucketBar(crm, r.arBuckets),
      if (r.highRisk.isNotEmpty) ...[
        10.h,
        Text('HIGH-RISK DEBTORS (90+ DAYS)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.destructive)),
        6.h,
        for (final d in r.highRisk.take(5))
          _metricRow(crm, d.name, _money(d.amount), badge: '${d.daysOverdue}d', badgeColor: crm.destructive),
      ],
    ], detailRoute: '/company-finance/aging', detailLabel: 'Aging report');
  }

  Widget _bucketBar(CrmTheme crm, AgingBuckets b) {
    final items = [
      ('0–30', b.current, crm.success),
      ('31–60', b.days30, const Color(0xFFB45309)),
      ('61–90', b.days60, const Color(0xFFC2410C)),
      ('90+', b.days90, crm.destructive),
    ];
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) 8.w,
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: items[i].$3.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(items[i].$1, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: items[i].$3)),
              4.h,
              FittedBox(fit: BoxFit.scaleDown, child: Text(_money(items[i].$2), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            ]),
          ),
        ),
      ],
    ]);
  }

  // ── 5. Payables ───────────────────────────────────────────────────────────
  Widget _payables(CrmTheme crm, MonthEndReview r) {
    return _section(crm, 5, 'Accounts Payable', Icons.call_made_rounded, [
      _metricRow(crm, 'Vendor dues outstanding', _money(r.apOutstanding)),
      _metricRow(crm, 'Overdue', _money(r.apOverdue), valueColor: crm.destructive),
      _metricRow(crm, 'Days payable outstanding (DPO)',
          r.dpo != null ? '${r.dpo!.toStringAsFixed(0)} days' : '—'),
      if (r.upcoming.isNotEmpty) ...[
        10.h,
        Text('UPCOMING COMMITMENTS (NEXT 30 DAYS)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
        6.h,
        for (final u in r.upcoming.take(6))
          _metricRow(crm, u.label, _money(u.amount),
              badge: u.dueDate != null ? DateFormat('d MMM').format(u.dueDate!) : null),
      ] else
        Padding(padding: const EdgeInsets.only(top: 6), child: Text('No unpaid vendor bills.', style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
    ]);
  }

  // ── 6. Budget vs actual ───────────────────────────────────────────────────
  Widget _budget(CrmTheme crm, MonthEndReview r) {
    return _section(crm, 6, 'Budget vs Actual', Icons.balance_outlined, [
      if (r.budgetRows.isEmpty)
        Text('No budgets set for this month. Set them in Monthly Planning.',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary))
      else ...[
        _metricRow(crm, 'Total budget', _money(r.totalBudget)),
        _metricRow(crm, 'Total actual', _money(r.totalActual)),
        _metricRow(crm, 'Variance', _money(r.totalVariance),
            valueColor: r.totalVariance >= 0 ? crm.success : crm.destructive),
        const Divider(height: 20),
        for (final row in r.budgetRows.take(8))
          _metricRow(crm, row.category, '${_money(row.actual)} / ${_money(row.budget)}',
              badge: row.budget > 0 ? (row.variance >= 0 ? 'under' : 'over') : null,
              badgeColor: row.variance >= 0 ? crm.success : crm.destructive),
      ],
    ], detailRoute: '/company-finance/reports', detailLabel: 'Reports Center');
  }

  // ── 7. Working capital ────────────────────────────────────────────────────
  Widget _workingCapital(CrmTheme crm, MonthEndReview r) {
    return _section(crm, 7, 'Working Capital', Icons.sync_alt_rounded, [
      _metricRow(crm, 'Inventory value', _money(r.inventoryValue)),
      _metricRow(crm, 'Receivables', _money(r.arOutstanding)),
      _metricRow(crm, 'Payables', _money(r.apOutstanding)),
      const Divider(height: 20),
      _metricRow(crm, 'Current assets', _money(r.currentAssets)),
      _metricRow(crm, 'Current liabilities', _money(r.currentLiabilities)),
      _metricRow(crm, 'Working capital', _money(r.workingCapital), valueColor: crm.primary),
      _metricRow(crm, 'Current ratio', r.currentRatio != null ? r.currentRatio!.toStringAsFixed(2) : '—',
          valueColor: (r.currentRatio ?? 0) >= 1 ? crm.success : crm.destructive),
      const Divider(height: 20),
      _metricRow(crm, 'Inventory turnover (annualized)',
          r.inventoryTurnover != null ? '${r.inventoryTurnover!.toStringAsFixed(1)}×' : '—'),
      _metricRow(crm, 'Days of inventory',
          r.daysInventory != null ? '${r.daysInventory!.toStringAsFixed(0)} days' : '—'),
      _metricRow(crm, 'Debt-to-equity',
          r.debtToEquity != null ? r.debtToEquity!.toStringAsFixed(2) : '—',
          valueColor: (r.debtToEquity ?? 0) <= 1 ? crm.success : crm.warning),
    ]);
  }

  // ── 9. Risk review ────────────────────────────────────────────────────────
  Widget _risk(CrmTheme crm, MonthEndReview r) {
    return _section(crm, 8, 'Risk & Compliance', Icons.gpp_maybe_outlined, [
      _metricRow(crm, 'GST net payable', _money(r.gstNetPayable),
          valueColor: r.gstNetPayable > 0 ? crm.destructive : crm.success),
      _metricRow(crm, 'GST output tax', _money(r.gstOutput)),
      _metricRow(crm, 'Input tax credit', _money(r.gstInputCredit)),
      if (r.filings.isNotEmpty) ...[
        10.h,
        Row(children: [
          Text('STATUTORY FILINGS (GST / TDS)',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
          if (r.filingsOverdue > 0) ...[
            6.w,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: crm.destructive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100)),
              child: Text('${r.filingsOverdue} overdue',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: crm.destructive)),
            ),
          ],
        ]),
        6.h,
        for (final f in r.filings)
          _metricRow(crm, f.label,
              f.dueDate != null ? 'due ${DateFormat('d MMM').format(f.dueDate!)}' : '—',
              badge: f.status == 'filed' ? 'Filed' : (f.status == 'overdue' ? 'Overdue' : 'Pending'),
              badgeColor: f.status == 'filed' ? crm.success : (f.status == 'overdue' ? crm.destructive : crm.warning)),
      ],
      if (r.unusualTransactions.isNotEmpty) ...[
        10.h,
        Text('TRANSACTIONS TO REVIEW', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.warning)),
        6.h,
        for (final u in r.unusualTransactions.take(6))
          _metricRow(crm, '${u.voucherNo} · ${u.reason}', _money(u.amount)),
      ],
    ], detailRoute: '/company-finance/tax-filings', detailLabel: 'Filing tracker');
  }

  Widget _decisions(CrmTheme crm, MonthEndReview r) {
    return _section(crm, 9, 'CEO Decisions & Action Items', Icons.gavel_rounded, [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (r.openDecisions > 0 ? crm.warning : crm.success).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('${r.openDecisions} open',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: r.openDecisions > 0 ? crm.warning : crm.success)),
        ),
        10.w,
        Expanded(
          child: Text(
            r.openDecisions > 0
                ? 'Approvals, hiring, CapEx and action items awaiting a decision.'
                : 'No open decisions — everything actioned.',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
        ),
      ]),
    ], detailRoute: '/company-finance/decisions', detailLabel: 'Open the decision log');
  }

  Widget _planningLink(CrmTheme crm) {
    return Material(
      color: crm.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/company-finance/planning'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Icons.flag_outlined, color: crm.primary),
            12.w,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Monthly Planning', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                Text('Set next month’s targets, budgets & expense limits', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              ]),
            ),
            Icon(Icons.chevron_right, color: crm.textSecondary),
          ]),
        ),
      ),
    );
  }

  Future<void> _export(MonthEndReview r) async {
    final rows = <List<Object?>>[
      ['Month-End Review', r.periodLabel],
      [],
      ['Revenue', csvNum(r.revenue)],
      ['Revenue (previous)', csvNum(r.revenuePrev)],
      ['Growth %', r.revenueGrowthPct],
      ['Orders', r.orders],
      ['Avg order value', csvNum(r.avgOrderValue)],
      ['Gross Profit', csvNum(r.grossProfit)],
      ['EBITDA', csvNum(r.ebitda)],
      ['Net Profit', csvNum(r.netProfit)],
      ['Cash received', csvNum(r.cashReceived)],
      ['Cash paid', csvNum(r.cashPaid)],
      ['Bank + cash', csvNum(r.totalLiquid)],
      ['Receivables outstanding', csvNum(r.arOutstanding)],
      ['Receivables overdue', csvNum(r.arOverdue)],
      ['Collection efficiency %', r.collectionEfficiencyPct],
      ['Payables outstanding', csvNum(r.apOutstanding)],
      ['Working capital', csvNum(r.workingCapital)],
      ['Current ratio', r.currentRatio ?? ''],
      ['Revenue / employee', csvNum(r.revenuePerEmployee)],
      ['GST net payable', csvNum(r.gstNetPayable)],
    ];
    try {
      await downloadCsv('month_end_${r.year}_${r.month}.csv', rows);
      if (mounted) showSuccessSnackBar(context, 'Month-end review exported');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }
}
