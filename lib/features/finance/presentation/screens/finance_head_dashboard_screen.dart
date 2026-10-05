import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/data/tax_filing.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/month_year_picker.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';
import 'package:nizan_crm/features/finance/services/tax_filing_service.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

String _compact(num value) {
  final v = value.abs();
  final sign = value < 0 ? '-' : '';
  if (v >= 10000000) return '$sign₹${(v / 10000000).toStringAsFixed(2)}Cr';
  if (v >= 100000) return '$sign₹${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '$sign₹${(v / 1000).toStringAsFixed(1)}k';
  return '$sign₹${v.toStringAsFixed(0)}';
}

String _pct(num v) => '${v.toStringAsFixed(1)}%';

const _amber = Color(0xFFB45309);
const _orange = Color(0xFFC2410C);

/// Finance Head → Dashboard. One screen for the head of finance: the month's
/// revenue and profit against target, liquidity, money owed in and out, what
/// is waiting for approval, statutory deadlines, and shortcuts into every
/// finance report. Built on the Month-End Review numbers, so it always agrees
/// with that report.
class FinanceHeadDashboardScreen extends ConsumerStatefulWidget {
  const FinanceHeadDashboardScreen({super.key});

  @override
  ConsumerState<FinanceHeadDashboardScreen> createState() =>
      _FinanceHeadDashboardScreenState();
}

class _FinanceHeadDashboardScreenState
    extends ConsumerState<FinanceHeadDashboardScreen> {
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;

  Period get _key => (month: _month, year: _year);

  void _shift(int delta) {
    setState(() {
      var m = _month + delta;
      var y = _year;
      if (m < 1) {
        m = 12;
        y--;
      }
      if (m > 12) {
        m = 1;
        y++;
      }
      _month = m;
      _year = y;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthYearPicker(context, month: _month, year: _year);
    if (picked != null) {
      setState(() {
        _month = picked.month;
        _year = picked.year;
      });
    }
  }

  void _refresh() {
    ref.invalidate(monthEndReviewProvider(_key));
    ref.invalidate(taxFilingBoardProvider(_key));
    ref.invalidate(bankAccountsProvider);
    ref.invalidate(openDecisionsProvider);
    ref.invalidate(adminExpenseStatsProvider);
    ref.invalidate(collectionsProvider);
    ref.invalidate(expensesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final review = ref.watch(monthEndReviewProvider(_key));

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 1000;
          final pad = c.maxWidth < 600 ? 16.0 : 24.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(pad, 20, pad, 40),
            children: [
              _header(crm),
              const SizedBox(height: 20),
              review.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => AppErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(monthEndReviewProvider(_key)),
                ),
                data: (r) => _body(r, wide, c.maxWidth),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _header(CrmTheme crm) {
    final label = DateFormat('MMMM yyyy').format(DateTime(_year, _month));
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Finance Head Dashboard',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            const SizedBox(height: 2),
            Text('Company finances at a glance',
                style: TextStyle(fontSize: 13, color: crm.textSecondary)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            OutlinedButton.icon(
              onPressed: _pickMonth,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(label),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _body(MonthEndReview r, bool wide, double width) {
    final crm = context.crmColors;
    Widget pair(Widget a, Widget b) => wide
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)],
            ),
          )
        : Column(children: [a, const SizedBox(height: 16), b]);

    final revenueSub = r.revenueTargetPct != null
        ? '${_pct(r.revenueTargetPct!)} of ${_compact(r.revenueTarget!)} target'
        : '${r.revenueGrowthPct >= 0 ? '▲' : '▼'} ${_pct(r.revenueGrowthPct.abs())} vs last month';
    final profitSub = r.profitTargetPct != null
        ? '${_pct(r.profitTargetPct!)} of target · margin ${_pct(r.netMarginPct)}'
        : 'Net margin ${_pct(r.netMarginPct)}';

    final kpis = [
      _Kpi('Revenue', _compact(r.revenue), revenueSub, Icons.trending_up_rounded,
          r.revenueGrowthPct >= 0 ? crm.success : crm.destructive,
          route: '/company-finance/profit-loss'),
      _Kpi('Net profit', _compact(r.netProfit), profitSub, Icons.account_balance_wallet_outlined,
          r.netProfit >= 0 ? crm.success : crm.destructive,
          route: '/company-finance/profit-loss'),
      _Kpi('Cash & bank', _compact(r.totalLiquid),
          'Bank ${_compact(r.bankBalance)} · Cash ${_compact(r.cashBalance)}',
          Icons.savings_outlined, crm.primary,
          route: '/company-finance/bank-balance'),
      _Kpi('To collect', _compact(r.arOutstanding), 'Overdue ${_compact(r.arOverdue)}',
          Icons.call_received_rounded, r.arOverdue > 0 ? _amber : crm.success,
          route: '/company-finance/aging'),
      _Kpi('To pay', _compact(r.apOutstanding), 'Overdue ${_compact(r.apOverdue)}',
          Icons.call_made_rounded, r.apOverdue > 0 ? _orange : crm.success,
          route: '/accounts/bills'),
      _Kpi(
          'Cash runway',
          r.cashRunwayMonths == null ? '—' : '${r.cashRunwayMonths!.toStringAsFixed(1)} mo',
          'Burn ${_compact(r.burnRate)} / month',
          Icons.hourglass_bottom_rounded,
          (r.cashRunwayMonths ?? 99) < 3 ? crm.destructive : crm.primary,
          route: '/company-finance/cash-flow'),
    ];
    final cols = width >= 1200 ? 6 : width >= 760 ? 3 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(kpis: kpis, columns: cols),
        const SizedBox(height: 16),
        _attention(),
        const SizedBox(height: 16),
        pair(_upcoming(r), _banks()),
        const SizedBox(height: 16),
        pair(_receivables(r), _budget(r)),
        const SizedBox(height: 16),
        pair(_taxFilings(), _decisions()),
        const SizedBox(height: 16),
        _quickLinks(width),
      ],
    );
  }

  // ── Needs your attention ─────────────────────────────────────────────────
  Widget _attention() {
    final crm = context.crmColors;
    final collections = ref.watch(collectionsProvider).value ?? const [];
    final expenses = ref.watch(expensesProvider).value ?? const [];
    final adminStats = ref.watch(adminExpenseStatsProvider).value;
    final tax = ref.watch(taxFilingBoardProvider(_key)).value;
    final decisions = ref.watch(openDecisionsProvider).value ?? const <CeoDecision>[];

    final pendingCol = collections.where((x) => x.status == 'pending').toList();
    final pendingExp = expenses.where((x) => x.status == 'pending').toList();

    final items = [
      _Todo('Collections to verify', pendingCol.length,
          _money(pendingCol.fold<double>(0, (s, x) => s + x.amount)),
          Icons.fact_check_outlined, '/accounts/artist-collections'),
      _Todo('Artist expenses to verify', pendingExp.length,
          _money(pendingExp.fold<double>(0, (s, x) => s + x.amount)),
          Icons.receipt_outlined, '/finance'),
      _Todo('Admin expenses to approve', adminStats?.pendingCount ?? 0,
          _money(adminStats?.pendingAmount ?? 0), Icons.approval_outlined,
          '/accounts/admin-expenses'),
      _Todo('Tax filings overdue', tax?.summaryOverdue ?? 0,
          '${tax?.summaryPending ?? 0} pending this month', Icons.gavel_rounded,
          '/company-finance/tax-filings', urgent: true),
      _Todo('Open CEO decisions', decisions.length, 'Awaiting action',
          Icons.flag_outlined, '/company-finance/decisions'),
    ];

    return _Card(
      title: 'Needs your attention',
      icon: Icons.notifications_active_outlined,
      child: LayoutBuilder(builder: (context, c) {
        final perRow = c.maxWidth >= 1000 ? 5 : c.maxWidth >= 640 ? 3 : 1;
        final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in items)
              SizedBox(
                width: w,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go(t.route),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.count > 0
                          ? (t.urgent ? crm.destructive : crm.primary).withValues(alpha: 0.06)
                          : crm.input,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: t.count > 0
                            ? (t.urgent ? crm.destructive : crm.primary).withValues(alpha: 0.35)
                            : crm.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(t.icon, color: t.count > 0 ? (t.urgent ? crm.destructive : crm.primary) : crm.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.label,
                                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                              Text(t.count == 0 ? 'All clear' : '${t.count}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: t.count == 0 ? crm.success : crm.textPrimary,
                                  )),
                              if (t.count > 0)
                                Text(t.detail,
                                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                                    overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: crm.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  // ── Payments due ─────────────────────────────────────────────────────────
  Widget _upcoming(MonthEndReview r) {
    final crm = context.crmColors;
    final rows = [...r.upcoming]
      ..sort((a, b) => (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100)));
    return _Card(
      title: 'Payments due',
      icon: Icons.event_note_outlined,
      action: ('Bills', '/accounts/bills'),
      child: rows.isEmpty
          ? _Empty('No upcoming payments.')
          : Column(
              children: [
                for (final p in rows.take(7))
                  _Row(
                    left: p.label,
                    sub: p.dueDate == null ? null : 'Due ${DateFormat('d MMM').format(p.dueDate!)}',
                    right: _money(p.amount),
                    rightColor: p.dueDate != null && p.dueDate!.isBefore(DateTime.now())
                        ? crm.destructive
                        : null,
                  ),
              ],
            ),
    );
  }

  // ── Bank accounts ────────────────────────────────────────────────────────
  Widget _banks() {
    final banks = ref.watch(bankAccountsProvider);
    return _Card(
      title: 'Bank balances',
      icon: Icons.account_balance_outlined,
      action: ('Manage', '/company-finance/bank-balance'),
      child: banks.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => AppErrorView(error: e, compact: true, onRetry: () => ref.invalidate(bankAccountsProvider)),
        data: (b) {
          final active = b.accounts.where((a) => a.active).toList();
          if (active.isEmpty) return _Empty('No bank accounts added yet.');
          return Column(
            children: [
              for (final a in active)
                _Row(
                  left: a.name,
                  sub: [
                    if (a.bankName.isNotEmpty) a.bankName,
                    if (a.asOf != null) 'as of ${DateFormat('d MMM').format(a.asOf!)}',
                  ].join(' · '),
                  right: _money(a.balance),
                ),
              _Row(left: 'Total', right: _money(b.totalBalance), bold: true),
            ],
          );
        },
      ),
    );
  }

  // ── Receivables aging ────────────────────────────────────────────────────
  Widget _receivables(MonthEndReview r) {
    final crm = context.crmColors;
    final b = r.arBuckets;
    final buckets = [
      ('Not due', b.notYetDue, crm.textSecondary),
      ('0–30', b.current, crm.success),
      ('31–60', b.days30, _amber),
      ('61–90', b.days60, _orange),
      ('90+', b.days90, crm.destructive),
    ];
    final total = buckets.fold<double>(0, (s, x) => s + x.$2);
    return _Card(
      title: 'Money owed to us',
      icon: Icons.hourglass_top_rounded,
      action: ('Aging', '/company-finance/aging'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  for (final x in buckets)
                    if (x.$2 > 0)
                      Expanded(
                        flex: (x.$2 / total * 1000).round().clamp(1, 1000),
                        child: Container(height: 12, color: x.$3),
                      ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final x in buckets)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: x.$3, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('${x.$1}  ${_compact(x.$2)}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ]),
            ],
          ),
          const SizedBox(height: 8),
          _Row(left: 'Collection efficiency', right: _pct(r.collectionEfficiencyPct)),
          if (r.highRisk.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('HIGH-RISK DEBTORS',
                style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: crm.textSecondary)),
            for (final d in r.highRisk.take(4))
              _Row(left: d.name, sub: '${d.daysOverdue} days overdue', right: _money(d.amount), rightColor: crm.destructive),
          ],
        ],
      ),
    );
  }

  // ── Budget vs actual ─────────────────────────────────────────────────────
  Widget _budget(MonthEndReview r) {
    final crm = context.crmColors;
    final rows = [...r.budgetRows]..sort((a, b) => b.variance.compareTo(a.variance));
    return _Card(
      title: 'Budget vs actual',
      icon: Icons.donut_large_outlined,
      action: ('Budget', '/accounts/budget'),
      child: rows.isEmpty
          ? _Empty('No budget set for this month.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Row(
                  left: 'Total spent',
                  sub: 'of ${_money(r.totalBudget)} budget',
                  right: _money(r.totalActual),
                  rightColor: r.totalActual > r.totalBudget ? crm.destructive : crm.success,
                  bold: true,
                ),
                for (final row in rows.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(child: Text(row.category, style: TextStyle(fontSize: 13, color: crm.textPrimary))),
                          Text('${_compact(row.actual)} / ${_compact(row.budget)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: row.actual > row.budget ? crm.destructive : crm.textSecondary,
                              )),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: row.budget <= 0 ? 1 : (row.actual / row.budget).clamp(0, 1).toDouble(),
                            backgroundColor: crm.input,
                            color: row.actual > row.budget ? crm.destructive : crm.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  // ── Statutory filings ────────────────────────────────────────────────────
  Widget _taxFilings() {
    final crm = context.crmColors;
    final board = ref.watch(taxFilingBoardProvider(_key));
    return _Card(
      title: 'GST & TDS filings',
      icon: Icons.gavel_rounded,
      action: ('Tax filings', '/company-finance/tax-filings'),
      child: board.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => AppErrorView(error: e, compact: true, onRetry: () => ref.invalidate(taxFilingBoardProvider(_key))),
        data: (b) {
          final list = <TaxFiling>[...b.overdue, ...b.filings.where((f) => !b.overdue.any((o) => o.id == f.id))];
          if (list.isEmpty) return _Empty('No filings for this month.');
          return Column(
            children: [
              for (final f in list.take(7))
                _Row(
                  left: f.label,
                  sub: f.dueDate == null ? null : 'Due ${DateFormat('d MMM yyyy').format(f.dueDate!)}',
                  trailing: _Chip(
                    f.isFiled ? 'Filed' : f.isOverdue ? 'Overdue' : 'Pending',
                    f.isFiled ? crm.success : f.isOverdue ? crm.destructive : _amber,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── CEO decisions ────────────────────────────────────────────────────────
  Widget _decisions() {
    final crm = context.crmColors;
    final asyncDecisions = ref.watch(openDecisionsProvider);
    return _Card(
      title: 'Open decisions',
      icon: Icons.flag_outlined,
      action: ('All decisions', '/company-finance/decisions'),
      child: asyncDecisions.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => AppErrorView(error: e, compact: true, onRetry: () => ref.invalidate(openDecisionsProvider)),
        data: (list) {
          if (list.isEmpty) return _Empty('No open decisions.');
          final sorted = [...list]
            ..sort((a, b) => (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100)));
          return Column(
            children: [
              for (final d in sorted.take(6))
                _Row(
                  left: d.title,
                  sub: [
                    if (d.owner.isNotEmpty) d.owner,
                    if (d.dueDate != null) 'due ${DateFormat('d MMM').format(d.dueDate!)}',
                  ].join(' · '),
                  right: d.amount > 0 ? _money(d.amount) : null,
                  rightColor: d.dueDate != null && d.dueDate!.isBefore(DateTime.now()) ? crm.destructive : null,
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Shortcuts ────────────────────────────────────────────────────────────
  Widget _quickLinks(double width) {
    final crm = context.crmColors;
    const links = [
      ('Month-End Review', Icons.fact_check_outlined, '/company-finance/month-end'),
      ('Profit & Loss', Icons.stacked_line_chart_rounded, '/company-finance/profit-loss'),
      ('Balance Sheet', Icons.account_balance_outlined, '/company-finance/balance-sheet'),
      ('Cash Flow', Icons.waterfall_chart_rounded, '/company-finance/cash-flow'),
      ('Trial Balance', Icons.balance_rounded, '/company-finance/trial-balance'),
      ('Journal', Icons.edit_note_rounded, '/company-finance/journal'),
      ('Ledger', Icons.menu_book_outlined, '/company-finance/ledger'),
      ('Bank Reconciliation', Icons.compare_arrows_rounded, '/company-finance/reconciliation'),
      ('GST', Icons.percent_rounded, '/company-finance/gst'),
      ('TDS', Icons.request_quote_outlined, '/company-finance/tds'),
      ('Accounts Dashboard', Icons.dashboard_outlined, '/accounts/dashboard'),
      ('Finance Reports', Icons.summarize_outlined, '/company-finance/reports'),
    ];
    return _Card(
      title: 'Shortcuts',
      icon: Icons.bolt_rounded,
      child: LayoutBuilder(builder: (context, c) {
        final perRow = c.maxWidth >= 1000 ? 6 : c.maxWidth >= 640 ? 4 : 2;
        final w = (c.maxWidth - 10 * (perRow - 1)) / perRow;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, icon, route) in links)
              SizedBox(
                width: w,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => context.go(route),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: crm.input,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: crm.border),
                    ),
                    child: Row(children: [
                      Icon(icon, size: 18, color: crm.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Building blocks
// ─────────────────────────────────────────────────────────────────────────
class _Kpi {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final String route;
  const _Kpi(this.label, this.value, this.sub, this.icon, this.color, {required this.route});
}

class _Todo {
  final String label, detail, route;
  final int count;
  final IconData icon;
  final bool urgent;
  const _Todo(this.label, this.count, this.detail, this.icon, this.route, {this.urgent = false});
}

class _KpiGrid extends StatelessWidget {
  final List<_Kpi> kpis;
  final int columns;
  const _KpiGrid({required this.kpis, required this.columns});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final k in kpis)
            SizedBox(
              width: w,
              child: Material(
                color: crm.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: crm.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.go(k.route),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: k.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(k.icon, size: 16, color: k.color),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(k.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(k.value,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                        ),
                        const SizedBox(height: 2),
                        Text(k.sub,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: k.color)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final (String, String)? action;
  final Widget child;
  const _Card({required this.title, required this.icon, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Row(children: [
              Icon(icon, size: 18, color: crm.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              ),
              if (action != null)
                TextButton(
                  onPressed: () => context.go(action!.$2),
                  child: Text('${action!.$1} →'),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String left;
  final String? sub, right;
  final Color? rightColor;
  final bool bold;
  final Widget? trailing;
  const _Row({required this.left, this.sub, this.right, this.rightColor, this.bold = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(left,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                      color: crm.textPrimary,
                    )),
                if (sub != null && sub!.isNotEmpty)
                  Text(sub!, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              ],
            ),
          ),
          if (right != null)
            Text(right!,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                  color: rightColor ?? crm.textPrimary,
                )),
          ?trailing,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty(this.message);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: context.crmColors.textSecondary)),
      );
}
