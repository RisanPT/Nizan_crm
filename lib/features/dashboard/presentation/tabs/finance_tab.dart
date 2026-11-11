import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/dashboard/controllers/dashboard_analytics_provider.dart';
import 'package:nizan_crm/features/dashboard/data/dashboard_analytics.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_period_bar.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart';

/// Roles allowed to see the dashboard's Finance tab (mirrors the server).
const kFinanceDashboardRoles = {'admin', 'manager', 'accounts', 'finance_head', 'ceo'}; // the CEO reads it; the server refuses their writes

const _kAdvance = Color(0xFF1BAF7A); // kSeries slot 3 (aqua)
const _kDue = Color(0xFFEDA100); // kSeries slot 4 (yellow)

/// Dashboard → Finance: billed vs cash in, expenses, net, receivables aging,
/// payment modes, pending approvals and a 12-month income/expense picture.
///
/// "Billed" = bookings whose EVENT date falls in the period (cancelled /
/// rejected / lost / draft / pending and excluded-user bookings left out),
/// valued at price minus discount. Cash in can be shown with or without
/// booking advances.
class FinanceTab extends ConsumerStatefulWidget {
  const FinanceTab({super.key});

  @override
  ConsumerState<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends ConsumerState<FinanceTab> {
  DashboardQuery _q = DashboardQuery.thisMonth();
  bool _withAdvances = true;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(financeDashboardProvider(_q));
    return RefreshIndicator(
      color: kBrand,
      onRefresh: () => ref.refresh(financeDashboardProvider(_q).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DashboardPeriodBar(query: _q, onChanged: (q) => setState(() => _q = q)),
              _AdvanceToggle(value: _withAdvances, onChanged: (v) => setState(() => _withAdvances = v)),
            ],
          ),
          const SizedBox(height: 18),
          dashAsync(async, _body, () => ref.invalidate(financeDashboardProvider(_q))),
        ],
      ),
    );
  }

  List<Widget> _body(FinanceDashboard d) {
    final vs = 'vs ${_q.prevShort}';
    final adv = _withAdvances;
    final cashIn = adv ? d.k('cashIn') : d.k('collections');
    final cashInPrev = adv ? d.k('cashInPrev') : d.k('collectionsPrev');
    final net = cashIn - d.k('expenses');
    final netPrev = cashInPrev - d.k('expensesPrev');
    final cashLabel = adv ? 'Cash in' : 'Cash in (excl. advances)';
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
            delta: deltaPct(d.k('billed'), d.k('billedPrev')), deltaLabel: vs, spark: d.trend.map((t) => t.billed).toList(),
            hint: '${d.k('orders').toInt()} bookings with event date in period, after discount'),
        KpiTile(label: cashLabel, value: inr(cashIn), icon: Icons.south_west_rounded,
            delta: deltaPct(cashIn, cashInPrev), deltaLabel: vs, spark: d.trend.map((t) => t.cashIn(adv)).toList(),
            hint: adv ? 'advances + verified collections' : 'verified collections only'),
        KpiTile(label: 'Expenses', value: inr(d.k('expenses')), icon: Icons.north_east_rounded,
            delta: deltaPct(d.k('expenses'), d.k('expensesPrev')), deltaLabel: vs, lowerIsBetter: true,
            spark: d.trend.map((t) => t.expense).toList()),
        KpiTile(label: 'Net cash flow', value: inr(net), icon: Icons.account_balance_outlined,
            delta: deltaPct(net, netPrev), deltaLabel: vs, spark: d.trend.map((t) => t.netCash(adv)).toList()),
        KpiTile(label: 'Receivables', value: inr(d.k('receivables')), icon: Icons.hourglass_bottom_rounded,
            delta: deltaPct(d.k('receivables'), d.k('receivablesPrev')), deltaLabel: vs, lowerIsBetter: true,
            hint: 'still due on this period\'s billed bookings'),
        KpiTile(
            label: 'Collection rate',
            value: pct(adv ? d.k('collectionRate') : d.k('collectionRateExAdvance')),
            icon: Icons.percent_rounded,
            hint: adv ? 'received ÷ billed, this period' : 'collections ÷ billed (no advances)'),
        KpiTile(label: 'Advances', value: inr(d.k('advances')), icon: Icons.savings_outlined,
            delta: deltaPct(d.k('advances'), d.k('advancesPrev')), deltaLabel: vs,
            spark: d.trend.map((t) => t.advances).toList(), hint: 'booking advances in, by booked-on date'),
        KpiTile(label: 'Collections to verify', value: inr(d.k('collectionsPending')), icon: Icons.fact_check_outlined,
            hint: '${d.collectionsPendingCount} entries waiting'),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(flex: const [3, 2], minHeight: 376, children: [
        DashCard(
          title: 'Billed vs ${adv ? 'cash in' : 'collections'}',
          subtitle: 'Last 12 months',
          child: GroupedBarChart(
            labels: months,
            series: [
              BarSeries('Billed', kBrand, d.trend.map((t) => t.billed).toList()),
              BarSeries(adv ? 'Cash in' : 'Collections', kIncome, d.trend.map((t) => t.cashIn(adv)).toList()),
            ],
          ),
        ),
        DashCard(
          title: 'Where this period\'s billing stands',
          subtitle: 'Billed ${inr(d.k('billed'))} — paid on any date',
          child: DonutChart(
            slices: [
              // Always all three, so the parts add up to Billed.
              Slice('Paid as advance', d.k('billedAdvance')),
              Slice('Paid via collections', d.k('billedCollected')),
              Slice('Still due', d.k('receivables')),
            ],
            centerLabel: 'Billed',
          ),
        ),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(flex: const [3, 2], minHeight: 376, children: [
        DashCard(
          title: '$cashLabel vs expenses',
          subtitle: 'Last 12 months',
          child: GroupedBarChart(
            labels: months,
            series: [
              BarSeries(adv ? 'Cash in' : 'Collections', kIncome, d.trend.map((t) => t.cashIn(adv)).toList()),
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
          subtitle: '${adv ? 'Cash in' : 'Collections'} minus expenses, last 12 months',
          child: TrendLineChart(labels: months, values: d.trend.map((t) => t.netCash(adv)).toList(), height: 220),
        ),
        DashCard(
          title: 'Cash in mix',
          subtitle: 'Advances vs collections, this period',
          child: DonutChart(
            slices: [
              Slice('Advances', d.k('advances')),
              Slice('Collections', d.k('collections')),
            ],
            centerLabel: 'Cash in',
          ),
        ),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(flex: const [3, 2], minHeight: 338, children: [
        DashCard(
          title: 'Advances vs collections',
          subtitle: 'Last 12 months',
          child: GroupedBarChart(
            labels: months,
            series: [
              BarSeries('Advances', _kAdvance, d.trend.map((t) => t.advances).toList()),
              BarSeries('Collections', kIncome, d.trend.map((t) => t.collections).toList()),
            ],
            height: 220,
          ),
        ),
        DashCard(
          title: 'Collections by payment mode',
          subtitle: 'Verified collections (advances have no mode)',
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
          subtitle: 'All open bookings, any date — ${inr(d.k('receivablesAll'))} due',
          child: GroupedBarChart(
            labels: aging.map((a) => a.$1).toList(),
            series: [BarSeries('Balance due', _kDue, aging.map((a) => a.$2).toList())],
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
        subtitle: adv ? null : 'Cash in and net exclude booking advances',
        child: DashTable(
          columns: const ['Month', 'Billed', 'Advances', 'Collections', 'Cash in', 'Expenses', 'Net'],
          numericColumns: const {1, 2, 3, 4, 5, 6},
          rows: [
            for (final t in d.trend.reversed)
              [
                Text(bucketLabel(t.key, 'month'), style: dashText(13, weight: FontWeight.w600)),
                Text(inr(t.billed)),
                Text(inr(t.advances), style: adv ? null : dashText(13, color: kDashMuted)),
                Text(inr(t.collections)),
                Text(inr(t.cashIn(adv))),
                Text(inr(t.expense)),
                Text(inr(t.netCash(adv)),
                    style: dashText(13, weight: FontWeight.w700, color: t.netCash(adv) >= 0 ? kDashGood : kDashBad)),
              ],
          ],
        ),
      ),
    ];
  }
}

/// Include / exclude booking advances from cash-in figures.
class _AdvanceToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AdvanceToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: true, label: Text('Incl. advances'), icon: Icon(Icons.savings_outlined, size: 16)),
        ButtonSegment(value: false, label: Text('Excl. advances')),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(dashText(12.5, weight: FontWeight.w600)),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : kDashText),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kBrand : Colors.white),
        side: const WidgetStatePropertyAll(BorderSide(color: kDashBorder)),
      ),
    );
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
