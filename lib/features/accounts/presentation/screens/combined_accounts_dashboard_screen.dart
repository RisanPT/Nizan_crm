import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/export_utils.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/data/accounts_dashboard_summary.dart';
import 'package:nizan_crm/features/accounts/data/dashboard_series.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/dashboard_charts.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';

final _iso = DateFormat('yyyy-MM-dd');

enum _Period { thisMonth, lastMonth, thisFy, custom }

enum _View { overview, dues }

/// Accounts → Combined Dashboard. One company-wide view of a period: income against expense (only approved /
/// verified money) with the trend, where it came from and where it went — and, on the second view, the dues
/// (receivables, payables) and what is still awaiting approval.
///
/// Overview: three headline figures with the change against the earlier period, receivables / payables / cash &
/// bank, the income-vs-expense trend and ring, and the income / expense / net breakdown.
/// Dues & approvals: who owes us, whom we owe, and what is waiting for a decision.
///
/// All figures come from GET /accounting/dashboard-summary.
class CombinedAccountsDashboardScreen extends ConsumerStatefulWidget {
  const CombinedAccountsDashboardScreen({super.key});

  @override
  ConsumerState<CombinedAccountsDashboardScreen> createState() => _CombinedAccountsDashboardScreenState();
}

class _CombinedAccountsDashboardScreenState extends ConsumerState<CombinedAccountsDashboardScreen> {
  _Period _period = _Period.thisMonth;
  DateTimeRange? _custom;
  _View _view = _View.overview;
  bool _amount = true; // trend chart: money (true) or number of entries (false)

  DateTimeRange get _range {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0));
      case _Period.lastMonth:
        return DateTimeRange(start: DateTime(now.year, now.month - 1, 1), end: DateTime(now.year, now.month, 0));
      case _Period.thisFy:
        // Indian financial year: April → March.
        final startYear = now.month >= 4 ? now.year : now.year - 1;
        return DateTimeRange(start: DateTime(startYear, 4, 1), end: now);
      case _Period.custom:
        return _custom ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    }
  }

  ({String from, String to}) get _key => (from: _iso.format(_range.start), to: _iso.format(_range.end));

  bool _isWholeMonth(DateTimeRange r) =>
      r.start.day == 1 && r.end.year == r.start.year && r.end.month == r.start.month && r.end.day == DateTime(r.start.year, r.start.month + 1, 0).day;

  /// "November 2026", "FY 2026-27", "3 Nov – 9 Nov 2026": what the page and the month menu say.
  String get _periodLabel {
    final r = _range;
    if (_period == _Period.thisFy) return 'FY ${r.start.year}-${(r.start.year + 1) % 100}';
    if (_isWholeMonth(r)) return DateFormat('MMMM yyyy').format(r.start);
    final f = r.start.year == r.end.year ? DateFormat('d MMM') : DateFormat('d MMM yyyy');
    return '${f.format(r.start)} – ${DateFormat('d MMM yyyy').format(r.end)}';
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom ?? _range,
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _period = _Period.custom;
    });
  }

  /// Picking a month in the menu: this month and last month are the usual presets; any other month is a range.
  void _pickMonth(DateTime first) {
    final now = DateTime.now();
    setState(() {
      if (first == DateTime(now.year, now.month, 1)) {
        _period = _Period.thisMonth;
      } else if (first == DateTime(now.year, now.month - 1, 1)) {
        _period = _Period.lastMonth;
      } else {
        _custom = DateTimeRange(start: first, end: DateTime(first.year, first.month + 1, 0));
        _period = _Period.custom;
      }
    });
  }

  Future<void> _download(AccountsDashboardSummary s, {required bool pdf}) async {
    final report = buildDashboardReport(s, _periodLabel);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (pdf) {
        await ExportUtils.exportPdf('${report.fileBase}_$stamp.pdf', report.title, report.headers, report.rows);
      } else {
        await ExportUtils.exportCsv('${report.fileBase}_$stamp.csv', [report.headers, ...report.rows]);
      }
      messenger.showSnackBar(SnackBar(content: Text('Report downloaded as ${pdf ? 'PDF' : 'CSV'}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, fallback: "Couldn't create the report. Please try again."))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final crm = context.crmColors;
    final key = _key;
    final async = ref.watch(accountsDashboardSummaryProvider(key));
    final summary = async.value;

    // ── header controls ──
    final now = DateTime.now();
    final monthMenu = PopupMenuButton<DateTime>(
      key: const Key('month_menu'),
      tooltip: 'Pick a month',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _pickMonth,
      itemBuilder: (_) => [
        for (var i = 0; i < 12; i++)
          PopupMenuItem<DateTime>(
            value: DateTime(now.year, now.month - i, 1),
            height: 38,
            child: Row(children: [
              SizedBox(
                width: 22,
                child: _isWholeMonth(_range) && _range.start == DateTime(now.year, now.month - i, 1) ? Icon(Icons.check_rounded, size: 17, color: crm.primary) : null,
              ),
              Text(DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - i, 1))),
            ]),
          ),
      ],
      child: _HeaderButton(icon: Icons.calendar_month_outlined, label: _periodLabel, trailing: Icons.keyboard_arrow_down_rounded),
    );
    final downloadMenu = PopupMenuButton<bool>(
      key: const Key('download_report'),
      tooltip: 'Download report',
      enabled: summary != null,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (pdf) => _download(summary!, pdf: pdf),
      itemBuilder: (_) => const [
        PopupMenuItem(value: true, child: Row(children: [Icon(Icons.picture_as_pdf_outlined, size: 18), SizedBox(width: 10), Text('Download as PDF')])),
        PopupMenuItem(value: false, child: Row(children: [Icon(Icons.table_chart_outlined, size: 18), SizedBox(width: 10), Text('Download as CSV')])),
      ],
      child: _HeaderButton(icon: Icons.file_download_outlined, label: 'Download Report', dimmed: summary == null),
    );

    final crumbs = Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      InkWell(
        key: const Key('crumb_home'),
        onTap: () => context.go('/'),
        borderRadius: BorderRadius.circular(6),
        child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.home_outlined, size: 16, color: crm.textSecondary)),
      ),
      Icon(Icons.chevron_right_rounded, size: 16, color: crm.textSecondary),
      Text('Accounts', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
      Icon(Icons.chevron_right_rounded, size: 16, color: crm.textSecondary),
      Text('Combined Dashboard', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.primary)),
    ]);
    final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      crumbs,
      const SizedBox(height: 8),
      Text(
        'Combined Accounts Dashboard',
        style: TextStyle(fontSize: isMobile ? 22 : 30, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.6),
      ),
      const SizedBox(height: 4),
      Text('Company income, expenses and dues · $_periodLabel', style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
    ]);

    Widget periodPill(String keyName, _Period p, String label) => _Pill(
          key: Key(keyName),
          label: label,
          selected: _period == p,
          onTap: () => setState(() => _period = p),
        );

    final pills = Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      periodPill('period_this_month', _Period.thisMonth, 'This month'),
      periodPill('period_last_month', _Period.lastMonth, 'Last month'),
      periodPill('period_fy', _Period.thisFy, 'This FY'),
      _Pill(
        key: const Key('period_custom'),
        label: 'Custom range',
        selected: _period == _Period.custom,
        trailing: Icons.keyboard_arrow_down_rounded,
        onTap: _pickCustom,
      ),
    ]);
    final viewSwitch = _ViewSwitch(
      view: _view,
      expand: isMobile,
      onChanged: (v) => setState(() => _view = v),
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountsDashboardSummaryProvider(key)),
        child: ListView(
          padding: EdgeInsets.fromLTRB(isMobile ? 16 : 28, 18, isMobile ? 16 : 28, 40),
          children: [
            if (isMobile) ...[
              titleBlock,
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [monthMenu, downloadMenu]),
            ] else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 16),
                monthMenu,
                const SizedBox(width: 10),
                downloadMenu,
              ]),
            const SizedBox(height: 18),
            if (isMobile) ...[
              pills,
              const SizedBox(height: 12),
              viewSwitch,
            ] else
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(child: pills),
                const SizedBox(width: 12),
                viewSwitch,
              ]),
            const SizedBox(height: 20),
            async.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 90), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(accountsDashboardSummaryProvider(key))),
              data: (s) => _view == _View.overview
                  ? _Overview(
                      summary: s,
                      amount: _amount,
                      onAmount: (v) => setState(() => _amount = v),
                      onOpenDues: () => setState(() => _view = _View.dues),
                    )
                  : _Dues(summary: s),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════ small pieces ═══════════════════════════

/// A white pill button in the header: calendar + month, or the download.
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? trailing;
  final bool dimmed;
  const _HeaderButton({required this.icon, required this.label, this.trailing, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 19, color: crm.primary),
          const SizedBox(width: 9),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          if (trailing != null) ...[const SizedBox(width: 4), Icon(trailing, size: 20, color: crm.textSecondary)],
        ]),
      ),
    );
  }
}

/// A period chip: filled maroon with a tick when chosen.
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? trailing;
  final VoidCallback onTap;
  const _Pill({super.key, required this.label, required this.selected, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? crm.primary : crm.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: selected ? crm.primary : crm.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (selected) ...[const Icon(Icons.check_rounded, size: 17, color: Colors.white), const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : crm.textPrimary)),
              if (trailing != null) ...[const SizedBox(width: 2), Icon(trailing, size: 19, color: selected ? Colors.white : crm.textSecondary)],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Overview | Dues & approvals.
class _ViewSwitch extends StatelessWidget {
  final _View view;
  final ValueChanged<_View> onChanged;

  /// On a phone: the two halves share the whole width (and the text shortens instead of running off).
  final bool expand;
  const _ViewSwitch({required this.view, required this.onChanged, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget seg(Key k, _View v, IconData icon, String label) {
      final on = view == v;
      return InkWell(
        key: k,
        onTap: () => onChanged(v),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: on ? crm.primary.withValues(alpha: 0.10) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: on ? crm.primary : crm.textSecondary),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? crm.primary : crm.textSecondary)),
            ),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
      child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: [
        if (expand) Expanded(child: seg(const Key('view_overview'), _View.overview, Icons.insights_outlined, 'Overview')) else seg(const Key('view_overview'), _View.overview, Icons.insights_outlined, 'Overview'),
        if (expand) Expanded(child: seg(const Key('view_dues'), _View.dues, Icons.hourglass_empty_rounded, 'Dues & approvals')) else seg(const Key('view_dues'), _View.dues, Icons.hourglass_empty_rounded, 'Dues & approvals'),
      ]),
    );
  }
}

/// The white card the content sits in.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? tint;
  const _Card({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.tint});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: crm.surface,
        gradient: tint == null ? null : LinearGradient(colors: [tint!.withValues(alpha: 0.07), crm.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }
}

/// A round tinted icon, as at the head of each card.
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _IconBadge(this.icon, this.color, {this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(size / 2.6)),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

/// "↑ +12%": green when the move is good news, red when not. Hover for what it is measured against.
class _DeltaChip extends StatelessWidget {
  final double pct;
  final bool goodWhenUp;
  final String tooltip;
  const _DeltaChip({super.key, required this.pct, required this.goodWhenUp, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final up = pct >= 0;
    final good = up == goodWhenUp;
    final color = good ? crm.success : crm.destructive;
    return Tooltip(
      message: 'Compared with $tooltip',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: color),
          const SizedBox(width: 3),
          Text(pctText(pct), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }
}

/// Lays out [kids] in rows of [cols], every card of a row as tall as the tallest.
Widget _grid(List<Widget> kids, {required int cols, double gap = 16}) {
  final rows = <Widget>[];
  for (var i = 0; i < kids.length; i += cols) {
    final chunk = kids.sublist(i, i + cols > kids.length ? kids.length : i + cols);
    if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
    rows.add(IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var k = 0; k < cols; k++) ...[
          if (k > 0) SizedBox(width: gap),
          Expanded(child: k < chunk.length ? chunk[k] : const SizedBox.shrink()),
        ],
      ]),
    ));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
}

// ═══════════════════════════ Overview ═══════════════════════════

class _Overview extends ConsumerWidget {
  final AccountsDashboardSummary summary;
  final bool amount;
  final ValueChanged<bool> onAmount;
  final VoidCallback onOpenDues;
  const _Overview({required this.summary, required this.amount, required this.onAmount, required this.onOpenDues});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final s = summary;
    final p = s.previous;
    final canOpenBank = ref.watch(effectiveAccessProvider).canSeeSub('company_finance.bank_balance');
    final incomeColor = crm.success;
    final expenseColor = crm.primary;
    final netColor = s.net >= 0 ? crm.success : crm.destructive;
    final buckets = bucketSeries(s.series);

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final wide = w >= 1000;
      final kpiCols = w >= 780 ? 3 : (w >= 520 ? 2 : 1);
      final breakdownCols = w >= 1000 ? 3 : (w >= 680 ? 2 : 1);
      final vs = p == null ? '' : comparisonText(p);

      double? change(double now, double before) => p == null ? null : pctChange(now, before);

      Widget big(Key k, String label, double value, IconData icon, Color color, List<double> spark, {double? pct, bool goodWhenUp = true, Key? chipKey}) => _BigKpi(
            key: k,
            label: label,
            value: inrCompact(value),
            icon: icon,
            color: color,
            spark: spark,
            chip: pct == null ? null : _DeltaChip(key: chipKey, pct: pct, goodWhenUp: goodWhenUp, tooltip: vs),
          );

      final kpisA = <Widget>[
        big(const Key('kpi_income'), 'Total Income', s.income.total, Icons.account_balance_wallet_outlined, incomeColor, [for (final d in s.series) d.income],
            pct: change(p?.currentIncome ?? 0, p?.income ?? 0), chipKey: const Key('delta_income')),
        big(const Key('kpi_expense'), 'Total Expense', s.expense.total, Icons.credit_card_outlined, expenseColor, [for (final d in s.series) d.expense],
            pct: change(p?.currentExpense ?? 0, p?.expense ?? 0), goodWhenUp: false, chipKey: const Key('delta_expense')),
        big(const Key('kpi_net'), 'Net Profit / Loss', s.net, s.net >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, netColor,
            [for (final d in s.series) d.income - d.expense],
            pct: change(p?.currentNet ?? 0, p?.net ?? 0), chipKey: const Key('delta_net')),
      ];
      final kpisB = <Widget>[
        _LinkKpi(
          key: const Key('kpi_receivables'),
          icon: Icons.receipt_long_outlined,
          color: crm.warning,
          label: 'Receivables',
          value: inrCompact(s.receivables.totalOutstanding),
          onTap: onOpenDues,
        ),
        _LinkKpi(
          key: const Key('kpi_payables'),
          icon: Icons.layers_outlined,
          color: crm.accent,
          label: 'Payables',
          value: inrCompact(s.payables.totalOutstanding),
          onTap: onOpenDues,
        ),
        _LinkKpi(
          key: const Key('kpi_cash'),
          icon: Icons.account_balance_outlined,
          color: crm.primary,
          label: 'Cash & Bank Balance',
          value: inrCompact(s.cashBankTotal),
          caption: 'Bank ${inrCompact(s.bankTotal)} · Cash ${inrCompact(s.cashTotal)}',
          onTap: canOpenBank ? () => context.go('/company-finance/bank-balance') : null,
        ),
      ];

      final totalIE = s.income.total + s.expense.total;
      final trend = _Card(
        key: const Key('card_trend'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Income vs Expense Trend', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            _Toggle(
              leftKey: const Key('trend_amount'),
              rightKey: const Key('trend_count'),
              left: 'Amount',
              right: 'Count',
              leftOn: amount,
              onChanged: onAmount,
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(child: TrendChart(key: const Key('trend_chart'), buckets: buckets, amount: amount, incomeColor: incomeColor, expenseColor: expenseColor)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _LegendDot(incomeColor, 'Income'),
            const SizedBox(width: 22),
            _LegendDot(expenseColor, 'Expense'),
          ]),
        ]),
      );
      final donut = _Card(
        key: const Key('card_donut'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Income vs Expense (Total)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(builder: (ctx, box) {
              final stacked = box.maxWidth < 380;
              final ring = SizedBox(
                width: stacked ? 150 : 170,
                height: stacked ? 150 : 170,
                child: IncomeExpenseDonut(key: const Key('donut'), income: s.income.total, expense: s.expense.total, incomeColor: incomeColor, expenseColor: expenseColor),
              );
              String share(double v) => totalIE <= 0 ? '0%' : '${(v / totalIE * 100).toStringAsFixed(1)}%';
              final legend = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _ShareRow(incomeColor, 'Income', inrFull(s.income.total), share(s.income.total)),
                const SizedBox(height: 12),
                _ShareRow(expenseColor, 'Expense', inrFull(s.expense.total), share(s.expense.total)),
              ]);
              return !stacked
                  ? Row(children: [ring, const SizedBox(width: 18), Expanded(child: legend)])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [ring, const SizedBox(height: 12), legend]);
            }),
          ),
        ]),
      );

      final incomeCard = _BreakdownCard(
        key: const Key('card_income_breakdown'),
        title: 'Income Breakdown',
        icon: Icons.north_east_rounded,
        color: incomeColor,
        lines: incomeBreakdown(s.income),
        totalLabel: 'Total Income',
        total: inrFull(s.income.total),
      );
      final expenseCard = _BreakdownCard(
        key: const Key('card_expense_breakdown'),
        title: 'Expense Breakdown',
        icon: Icons.south_east_rounded,
        color: expenseColor,
        lines: expenseBreakdown(s.expense),
        totalLabel: 'Total Expense',
        total: inrFull(s.expense.total),
      );
      final netPct = change(p?.currentNet ?? 0, p?.net ?? 0);
      final netCard = _NetSummaryCard(
        key: const Key('card_net_summary'),
        income: s.income.total,
        expense: s.expense.total,
        net: s.net,
        chip: netPct == null ? null : _DeltaChip(pct: netPct, goodWhenUp: true, tooltip: vs),
      );

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _grid(kpisA, cols: kpiCols, gap: 16),
        const SizedBox(height: 16),
        _grid(kpisB, cols: kpiCols, gap: 16),
        const SizedBox(height: 18),
        if (wide)
          SizedBox(
            height: 370,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 13, child: trend),
              const SizedBox(width: 16),
              Expanded(flex: 8, child: donut),
            ]),
          )
        else ...[
          SizedBox(height: 370, child: trend),
          const SizedBox(height: 16),
          SizedBox(height: 370, child: donut),
        ],
        const SizedBox(height: 18),
        _grid([incomeCard, expenseCard, netCard], cols: breakdownCols, gap: 16),
      ]);
    });
  }
}

/// A headline figure: icon, label, big number, the change against the earlier period, and a sparkline.
class _BigKpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final List<double> spark;
  final Widget? chip;
  const _BigKpi({super.key, required this.label, required this.value, required this.icon, required this.color, required this.spark, this.chip});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return _Card(
      tint: color,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 104,
        child: Stack(children: [
          Positioned(right: 0, bottom: 0, width: 150, height: 52, child: Sparkline(values: spark, color: color)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _IconBadge(icon, color, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: crm.textSecondary, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.5)),
                  ),
                ]),
              ),
              ?chip,
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Receivables / Payables / Cash & Bank: label, value, and a chevron when there is somewhere to go.
class _LinkKpi extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? caption;
  final VoidCallback? onTap;
  const _LinkKpi({super.key, required this.icon, required this.color, required this.label, required this.value, this.caption, this.onTap});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final body = Row(children: [
      _IconBadge(icon, color, size: 44),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 13.5, color: crm.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          ),
          if (caption != null) Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        ]),
      ),
      if (onTap != null) Icon(Icons.chevron_right_rounded, color: crm.textSecondary, size: 24),
    ]);
    final card = _Card(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), child: body);
    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: card);
  }
}

class _Toggle extends StatelessWidget {
  final Key leftKey;
  final Key rightKey;
  final String left;
  final String right;
  final bool leftOn;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.leftKey, required this.rightKey, required this.left, required this.right, required this.leftOn, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget seg(Key k, String t, bool on, VoidCallback tap) => InkWell(
          key: k,
          onTap: tap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(color: on ? crm.primary : Colors.transparent, borderRadius: BorderRadius.circular(18)),
            child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : crm.textSecondary)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(22), border: Border.all(color: crm.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg(leftKey, left, leftOn, () => onChanged(true)),
        seg(rightKey, right, !leftOn, () => onChanged(false)),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 12.5, color: context.crmColors.textPrimary, fontWeight: FontWeight.w600)),
      ]);
}

class _ShareRow extends StatelessWidget {
  final Color color;
  final String label;
  final String amount;
  final String share;
  const _ShareRow(this.color, this.label, this.amount, this.share);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2.5))),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: crm.textPrimary))),
      Text(amount, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
      const SizedBox(width: 10),
      SizedBox(width: 48, child: Text(share, textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
    ]);
  }
}

/// A list of lines (label · count · amount) with the total in a tinted bar.
class _BreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<BreakdownLine> lines;
  final String totalLabel;
  final String total;
  const _BreakdownCard({super.key, required this.title, required this.icon, required this.color, required this.lines, required this.totalLabel, required this.total});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _IconBadge(icon, color, size: 36),
          const SizedBox(width: 12),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: crm.textPrimary))),
        ]),
        const SizedBox(height: 10),
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) Divider(height: 1, color: crm.border.withValues(alpha: 0.6)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(text: lines[i].label, style: TextStyle(fontSize: 14, color: crm.textSecondary), children: [
                    if (lines[i].count > 0 && lines[i].label != 'Others') TextSpan(text: ' (${lines[i].count})'),
                    if (lines[i].estimated && lines[i].label != 'Others') TextSpan(text: '  est.', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                  ]),
                ),
              ),
              if (lines[i].detail.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(message: lines[i].detail, child: Icon(Icons.info_outline_rounded, size: 15, color: crm.textSecondary)),
                ),
              Text(
                inrFull(lines[i].amount),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: lines[i].amount == 0 ? crm.textSecondary : crm.textPrimary),
              ),
            ]),
          ),
        ],
        const Spacer(),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: Text(totalLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color))),
            Text(total, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      ]),
    );
  }
}

class _NetSummaryCard extends StatelessWidget {
  final double income;
  final double expense;
  final double net;
  final Widget? chip;
  const _NetSummaryCard({super.key, required this.income, required this.expense, required this.net, this.chip});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = net >= 0 ? crm.success : crm.destructive;
    Widget row(String label, double v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, color: crm.textSecondary))),
            Text(inrFull(v), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          ]),
        );
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _IconBadge(Icons.bar_chart_rounded, crm.textSecondary, size: 36),
          const SizedBox(width: 12),
          Expanded(child: Text('Net Summary', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: crm.textPrimary))),
        ]),
        const SizedBox(height: 10),
        row('Total Income', income),
        Divider(height: 1, color: crm.border.withValues(alpha: 0.6)),
        row('Total Expense', expense),
        const Spacer(),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: Text(net >= 0 ? 'Net Profit / Loss' : 'Net Loss', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            Text(inrFull(net), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            if (chip != null) ...[const SizedBox(width: 10), chip!],
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════ Dues & approvals ═══════════════════════════

class _Dues extends ConsumerWidget {
  final AccountsDashboardSummary summary;
  const _Dues({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final s = summary;
    final canOpenAging = ref.watch(effectiveAccessProvider).canSeeSub('company_finance.aging');

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final kpiCols = w >= 1000 ? 4 : (w >= 560 ? 2 : 1);
      final twoCols = w >= 1000;

      final kpis = <Widget>[
        _PlainKpi(key: const Key('dues_kpi_receivables'), icon: Icons.account_balance_wallet_outlined, color: crm.warning, label: 'Total Receivables', value: inrFull(s.receivables.totalOutstanding)),
        _PlainKpi(key: const Key('dues_kpi_overdue'), icon: Icons.warning_amber_rounded, color: crm.destructive, label: 'Total Overdue', value: inrFull(s.receivables.totalOverdue), valueColor: crm.destructive),
        _PlainKpi(key: const Key('dues_kpi_not_due'), icon: Icons.schedule_rounded, color: crm.textSecondary, label: 'Not Yet Due', value: inrFull(s.receivables.totalNotYetDue)),
        _PlainKpi(key: const Key('dues_kpi_pending'), icon: Icons.check_circle_outline_rounded, color: crm.success, label: 'Total Pending Approval', value: inrFull(s.pending.total)),
      ];
      final receivables = _DuesCard(
        key: const Key('card_receivables'),
        title: 'Receivables',
        subtitle: 'Customers who owe us',
        icon: Icons.layers_outlined,
        color: crm.primary,
        data: s.receivables,
        emptyText: 'Nothing outstanding.',
        onViewAll: canOpenAging ? () => context.go('/company-finance/aging?kind=receivables') : null,
      );
      final top = _TopOverdueCard(
        key: const Key('card_top_overdue'),
        parties: s.receivables.top.where((p) => p.overdue > 0).take(5).toList(),
        onViewAll: canOpenAging ? () => context.go('/company-finance/aging?kind=receivables') : null,
      );
      final payables = _DuesCard(
        key: const Key('card_payables'),
        title: 'Payables',
        subtitle: 'Vendors we owe',
        icon: Icons.layers_outlined,
        color: crm.primary,
        data: s.payables,
        emptyText: 'Nothing outstanding.',
        onViewAll: canOpenAging ? () => context.go('/company-finance/aging?kind=payables') : null,
      );
      final awaiting = _AwaitingCard(key: const Key('card_awaiting'), group: s.pending);

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _grid(kpis, cols: kpiCols, gap: 16),
        const SizedBox(height: 18),
        if (twoCols) ...[
          _grid([receivables, top], cols: 2, gap: 16),
          const SizedBox(height: 16),
          _grid([payables, awaiting], cols: 2, gap: 16),
        ] else ...[
          receivables,
          const SizedBox(height: 16),
          top,
          const SizedBox(height: 16),
          payables,
          const SizedBox(height: 16),
          awaiting,
        ],
      ]);
    });
  }
}

class _PlainKpi extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color? valueColor;
  const _PlainKpi({super.key, required this.icon, required this.color, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return _Card(
      tint: color,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(children: [
        _IconBadge(icon, color, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontSize: 13.5, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: valueColor ?? crm.textPrimary, letterSpacing: -0.3)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onViewAll;
  const _CardTitle({required this.title, required this.subtitle, required this.icon, required this.color, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Row(children: [
      _IconBadge(icon, color, size: 44),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          Text(subtitle, style: TextStyle(fontSize: 13, color: crm.textSecondary)),
        ]),
      ),
      if (onViewAll != null)
        TextButton.icon(
          onPressed: onViewAll,
          style: TextButton.styleFrom(foregroundColor: crm.primary, visualDensity: VisualDensity.compact),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('View all', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}

/// Receivables or Payables: outstanding / overdue / not yet due, and how the overdue part is spread over time.
class _DuesCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final OutstandingSummary data;
  final String emptyText;
  final VoidCallback? onViewAll;
  const _DuesCard({super.key, required this.title, required this.subtitle, required this.icon, required this.color, required this.data, required this.emptyText, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final d = data;
    final buckets = <(String, double)>[
      ('0 – 30 days', d.current),
      ('31 – 60 days', d.days30),
      ('61 – 90 days', d.days60),
      ('90+ days', d.days90),
    ];
    final maxBucket = buckets.fold<double>(0, (m, b) => b.$2 > m ? b.$2 : m);

    Widget stat(String label, double v, Color c) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(inrFull(v), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c, letterSpacing: -0.4)),
            ),
          ]),
        );

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _CardTitle(title: title, subtitle: subtitle, icon: icon, color: color, onViewAll: onViewAll),
        const SizedBox(height: 18),
        if (d.totalOutstanding <= 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.10), shape: BoxShape.circle),
                child: Icon(Icons.description_outlined, size: 32, color: color.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),
              Text(emptyText, style: TextStyle(fontSize: 18, color: crm.textSecondary, fontWeight: FontWeight.w500)),
            ]),
          )
        else ...[
          Row(children: [
            stat('Outstanding', d.totalOutstanding, crm.textPrimary),
            stat('Overdue', d.totalOverdue, crm.destructive),
            stat('Not yet due', d.totalNotYetDue, crm.textSecondary),
          ]),
          const SizedBox(height: 18),
          Text('Overdue by', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          const SizedBox(height: 10),
          for (final b in buckets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(width: 92, child: Text(b.$1, style: TextStyle(fontSize: 13, color: crm.textSecondary))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: maxBucket == 0 ? 0 : b.$2 / maxBucket,
                      minHeight: 9,
                      backgroundColor: color.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 100, child: Text(inrFull(b.$2), textAlign: TextAlign.right, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary))),
              ]),
            ),
        ],
      ]),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '—';
  if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// The customers who are furthest behind: how long overdue, and how much.
class _TopOverdueCard extends StatelessWidget {
  final List<OutstandingParty> parties;
  final VoidCallback? onViewAll;
  const _TopOverdueCard({super.key, required this.parties, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _IconBadge(Icons.groups_outlined, crm.primary, size: 44),
          const SizedBox(width: 14),
          Expanded(child: Text('Top ${parties.isEmpty ? '' : '${parties.length} '}Overdue Customers', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: crm.textPrimary))),
          if (onViewAll != null)
            TextButton.icon(
              onPressed: onViewAll,
              style: TextButton.styleFrom(foregroundColor: crm.primary, visualDensity: VisualDensity.compact),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('View all', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 14),
        if (parties.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(child: Text('No overdue customers.', style: TextStyle(fontSize: 16, color: crm.textSecondary))),
          )
        else
          for (var i = 0; i < parties.length; i++) ...[
            if (i > 0) Divider(height: 1, color: crm.border.withValues(alpha: 0.6)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              // (decided from the screen's width: a LayoutBuilder here cannot sit inside the equal-height rows)
              child: Builder(builder: (context) {
                final narrow = MediaQuery.sizeOf(context).width < 520;
                final tag = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: crm.destructive.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
                  child: Text('${parties[i].oldestDays}d overdue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.destructive)),
                );
                final name = Text(parties[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: crm.textPrimary));
                return Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
                    child: Text(_initials(parties[i].name), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.primary)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: narrow
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [name, const SizedBox(height: 4), tag])
                        : name,
                  ),
                  if (!narrow) ...[const SizedBox(width: 8), tag],
                  const SizedBox(width: 12),
                  Text(inrFull(parties[i].overdue), textAlign: TextAlign.right, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                ]);
              }),
            ),
          ],
      ]),
    );
  }
}

/// Money not counted in income or expense until someone approves it.
class _AwaitingCard extends StatelessWidget {
  final SummaryGroup group;
  const _AwaitingCard({super.key, required this.group});

  static IconData _iconFor(String key) => switch (key) {
        'collections' => Icons.account_balance_wallet_outlined,
        'artist_expenses' => Icons.receipt_long_outlined,
        'fleet' => Icons.local_shipping_outlined,
        _ => Icons.business_center_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final lines = group.items.where((l) => l.amount != 0).toList();
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _CardTitle(title: 'Awaiting Approval', subtitle: 'Not counted in income or expense until approved', icon: Icons.hourglass_top_rounded, color: crm.primary),
        const SizedBox(height: 14),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Center(child: Text('Nothing is waiting for approval.', style: TextStyle(fontSize: 16, color: crm.textSecondary))),
          )
        else
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) Divider(height: 1, color: crm.border.withValues(alpha: 0.6)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(children: [
                Icon(_iconFor(lines[i].key), size: 20, color: crm.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text.rich(TextSpan(text: lines[i].label, style: TextStyle(fontSize: 14.5, color: crm.textPrimary, fontWeight: FontWeight.w500), children: [
                    if (lines[i].count > 0) TextSpan(text: '  · ${lines[i].count}', style: TextStyle(color: crm.textSecondary, fontSize: 13)),
                  ])),
                ),
                Text(inrFull(lines[i].amount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              ]),
            ),
          ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: Text('Total Pending', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            Text(inrFull(group.total), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: crm.primary)),
          ]),
        ),
      ]),
    );
  }
}
