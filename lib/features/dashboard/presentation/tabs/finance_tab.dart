import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/dashboard/controllers/dashboard_analytics_provider.dart';
import 'package:nizan_crm/features/dashboard/data/dashboard_analytics.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_period_bar.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart';

/// Roles allowed to see the dashboard's Finance tab (mirrors the server).
const kFinanceDashboardRoles = {'admin', 'manager', 'accounts', 'finance_head'};

/// Dashboard → Finance: billed vs cash in, expenses, net, receivables aging,
/// payment modes, pending approvals and a 12-month income/expense picture.
class FinanceTab extends ConsumerStatefulWidget {
  const FinanceTab({super.key});

  @override
  ConsumerState<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends ConsumerState<FinanceTab> {
  DashboardQuery _q = DashboardQuery.thisMonth();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(financeDashboardProvider(_q));
    return RefreshIndicator(
      color: kBrand,
      onRefresh: () => ref.refresh(financeDashboardProvider(_q).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          DashboardPeriodBar(query: _q, onChanged: (q) => setState(() => _q = q)),
          const SizedBox(height: 18),
          dashAsync(async, _body, () => ref.invalidate(financeDashboardProvider(_q))),
        ],
      ),
    );
  }

  List<Widget> _body(FinanceDashboard d) {
    final vs = 'vs ${_q.prevShort}';
    final net = d.k('net');
    final months = d.trend.map((t) => bucketLabel(t.key, 'month')).toList();
    final aging = [
      ('Upcoming', d.aging['upcoming'] ?? 0),
      ('0–30 days', d.aging['d0_30'] ?? 0),
      ('31–90 days', d.aging['d31_90'] ?? 0),
      ('90+ days', d.aging['d90plus'] ?? 0),
    ];
    return [
      TileGrid(children: [
        KpiTile(label: 'Billed (net sales)', value: inr(d.k('billed')), icon: Icons.receipt_long_outlined,
            delta: deltaPct(d.k('billed'), d.k('billedPrev')), deltaLabel: vs, spark: d.trend.map((t) => t.billed).toList()),
        KpiTile(label: 'Cash in', value: inr(d.k('cashIn')), icon: Icons.south_west_rounded,
            delta: deltaPct(d.k('cashIn'), d.k('cashInPrev')), deltaLabel: vs, spark: d.trend.map((t) => t.income).toList()),
        KpiTile(label: 'Expenses', value: inr(d.k('expenses')), icon: Icons.north_east_rounded,
            delta: deltaPct(d.k('expenses'), d.k('expensesPrev')), deltaLabel: vs, lowerIsBetter: true,
            spark: d.trend.map((t) => t.expense).toList()),
        KpiTile(label: 'Net cash flow', value: inr(net), icon: Icons.account_balance_outlined,
            delta: deltaPct(net, d.k('netPrev')), deltaLabel: vs),
        KpiTile(label: 'Receivables', value: inr(d.k('receivables')), icon: Icons.hourglass_bottom_rounded,
            hint: 'balance due on all open bookings'),
        KpiTile(label: 'Collection rate', value: pct(d.k('collectionRate')), icon: Icons.percent_rounded,
            hint: 'received ÷ billed, this period'),
        KpiTile(label: 'Advances', value: inr(d.k('advances')), icon: Icons.savings_outlined, hint: 'booking advances in'),
        KpiTile(label: 'Collections to verify', value: inr(d.k('collectionsPending')), icon: Icons.fact_check_outlined,
            hint: '${d.collectionsPendingCount} entries waiting'),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(flex: const [3, 2], minHeight: 376, children: [
        DashCard(
          title: 'Cash in vs expenses',
          subtitle: 'Last 12 months',
          child: GroupedBarChart(
            labels: months,
            series: [
              BarSeries('Cash in', kIncome, d.trend.map((t) => t.income).toList()),
              BarSeries('Expenses', kExpense, d.trend.map((t) => t.expense).toList()),
            ],
          ),
        ),
        DashCard(
          title: 'Where the money went',
          subtitle: 'Expenses this period',
          child: DonutChart(
            slices: [for (final e in d.expenses) Slice(e.label, e.amount)],
            centerLabel: 'Expenses',
          ),
        ),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(flex: const [3, 2], minHeight: 312, children: [
        DashCard(
          title: 'Net cash flow',
          subtitle: 'Cash in minus expenses, last 12 months',
          child: TrendLineChart(labels: months, values: d.trend.map((t) => t.net).toList(), height: 220),
        ),
        DashCard(
          title: 'Collections by payment mode',
          child: DonutChart(
            slices: [for (final m in d.paymentModes) Slice(m.label, m.amount)],
            centerLabel: 'Collected',
          ),
        ),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(minHeight: 338, children: [
        DashCard(
          title: 'Receivables aging',
          subtitle: 'Balance due by days since the event',
          child: GroupedBarChart(
            labels: aging.map((a) => a.$1).toList(),
            series: [BarSeries('Balance due', kBrand, aging.map((a) => a.$2).toList())],
            height: 220,
          ),
        ),
        DashCard(
          title: 'Expenses vs last period',
          subtitle: 'By type',
          child: GroupedBarChart(
            labels: d.expenses.map((e) => _shortExpense(e.label)).toList(),
            series: [
              BarSeries('This period', kExpense, d.expenses.map((e) => e.amount).toList()),
              BarSeries(_q.prevLabel, kPrev, d.expenses.map((e) => e.prevAmount).toList()),
            ],
            height: 220,
          ),
        ),
        DashCard(
          title: 'Waiting for approval',
          subtitle: 'All dates',
          child: Column(children: [
            for (final p in d.pendingApprovals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(p.label, style: dashText(13, weight: FontWeight.w600))),
                  Text('${p.count}', style: dashText(12, color: kDashMuted)),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 100,
                    child: Text(inr(p.amount), textAlign: TextAlign.right, style: dashText(13, weight: FontWeight.w700)),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      DashCard(
        title: 'Monthly summary',
        child: DashTable(
          columns: const ['Month', 'Billed', 'Cash in', 'Expenses', 'Net'],
          numericColumns: const {1, 2, 3, 4},
          rows: [
            for (final t in d.trend.reversed)
              [
                Text(bucketLabel(t.key, 'month'), style: dashText(13, weight: FontWeight.w600)),
                Text(inr(t.billed)),
                Text(inr(t.income)),
                Text(inr(t.expense)),
                Text(inr(t.net), style: dashText(13, weight: FontWeight.w700, color: t.net >= 0 ? kDashGood : kDashBad)),
              ],
          ],
        ),
      ),
    ];
  }
}

/// Short axis names for expense types.
String _shortExpense(String label) => const {
      'Admin expenses': 'Admin',
      'Artist expenses': 'Artist exp.',
      'Fuel & vehicle': 'Fuel',
      'Artist payouts': 'Payouts',
      'Salaries': 'Salaries',
      'Sales returns': 'Returns',
    }[label] ??
    label;
