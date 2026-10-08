import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/dashboard/controllers/dashboard_analytics_provider.dart';
import 'package:nizan_crm/features/dashboard/data/dashboard_analytics.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_period_bar.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart';

/// Dashboard → Sales. Sales are counted on the date the booking was made
/// (like sales targets). One filter row — month / custom range and a
/// salesperson — and everything else is in the charts.
class SalesAnalyticsTab extends ConsumerStatefulWidget {
  /// Sales / sales-executive users only ever see their own numbers (the
  /// server enforces it); the salesperson picker is hidden for them.
  final bool selfScoped;
  const SalesAnalyticsTab({super.key, this.selfScoped = false});

  @override
  ConsumerState<SalesAnalyticsTab> createState() => _SalesAnalyticsTabState();
}

class _SalesAnalyticsTabState extends ConsumerState<SalesAnalyticsTab> {
  DashboardQuery _q = DashboardQuery.thisMonth();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(salesDashboardProvider(_q));
    return RefreshIndicator(
      color: kBrand,
      onRefresh: () => ref.refresh(salesDashboardProvider(_q).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          DashboardPeriodBar(
            query: _q,
            onChanged: (q) => setState(() => _q = q),
            salespeople: widget.selfScoped ? null : async.value?.salespeople,
          ),
          const SizedBox(height: 18),
          dashAsync(async, _body, () => ref.invalidate(salesDashboardProvider(_q))),
        ],
      ),
    );
  }

  List<Widget> _body(SalesDashboard d) {
    final k = d.kpis;
    final p = d.previous;
    final vs = 'vs ${_q.prevShort}';
    final labels = d.trend.map((t) => bucketLabel(t.key, d.unit)).toList();
    final per = d.unit == 'day' ? 'day' : d.unit;
    return [
      TileGrid(children: [
        KpiTile(label: 'Sales (net)', value: inr(k.revenue), icon: Icons.currency_rupee_rounded,
            delta: deltaPct(k.revenue, p.revenue), deltaLabel: vs, spark: d.trend.map((t) => t.value).toList()),
        KpiTile(label: 'Orders', value: countLabel(k.orders), icon: Icons.shopping_bag_outlined,
            delta: deltaPct(k.orders, p.orders), deltaLabel: vs, spark: d.trend.map((t) => t.count.toDouble()).toList()),
        KpiTile(label: 'Avg. order value', value: inr(k.avgOrder), icon: Icons.analytics_outlined,
            delta: deltaPct(k.avgOrder, p.avgOrder), deltaLabel: vs),
        KpiTile(label: 'Enquiries', value: countLabel(k.enquiries), icon: Icons.person_add_alt_rounded,
            delta: deltaPct(k.enquiries, p.enquiries), deltaLabel: vs),
        KpiTile(label: 'Conversion', value: pct(k.conversion), icon: Icons.trending_up_rounded,
            delta: deltaPct(k.conversion, p.conversion), deltaLabel: vs, hint: 'orders ÷ enquiries'),
        KpiTile(label: 'Received', value: inr(k.received), icon: Icons.account_balance_wallet_outlined,
            delta: deltaPct(k.received, p.received), deltaLabel: vs),
        KpiTile(label: 'Outstanding', value: inr(k.outstanding), icon: Icons.hourglass_bottom_rounded,
            delta: deltaPct(k.outstanding, p.outstanding), deltaLabel: vs, lowerIsBetter: true),
        KpiTile(label: 'Discounts given', value: inr(k.discount), icon: Icons.local_offer_outlined,
            delta: deltaPct(k.discount, p.discount), deltaLabel: vs, lowerIsBetter: true),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(flex: const [3, 2], minHeight: 376, children: [
        DashCard(
          title: 'Sales trend',
          subtitle: 'Net sales per $per',
          child: TrendLineChart(
            labels: labels,
            values: d.trend.map((t) => t.value).toList(),
            previous: d.trend.map((t) => t.prevValue).toList(),
            seriesLabel: 'This period',
            previousLabel: _q.prevLabel,
          ),
        ),
        DashCard(
          title: 'Sales by package',
          subtitle: 'Share of net sales',
          child: DonutChart(slices: _fixedOrder(d.byPackage, kPackageFamilies, (b) => b.amount)),
        ),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(flex: const [3, 2], minHeight: 350, children: [
        DashCard(
          title: 'Orders',
          subtitle: 'Bookings made per $per',
          child: GroupedBarChart(
            labels: labels,
            series: [BarSeries('Orders', kBrand, d.trend.map((t) => t.count.toDouble()).toList())],
            format: countLabel,
          ),
        ),
        DashCard(
          title: 'Sales by salesperson',
          subtitle: 'Sales team only · everyone else is “Direct / Others”',
          child: BarList(
            items: [
              for (final b in d.bySalesperson)
                BarItem(b.label, b.amount, inrShort(b.amount), sub: '${b.count} order${b.count == 1 ? '' : 's'}'),
            ],
          ),
        ),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(minHeight: 272, children: [
        DashCard(
          title: 'Enquiry sources',
          subtitle: 'Enquiries received',
          child: DonutChart(
            slices: [for (final b in d.leadSources) Slice(b.label, b.count.toDouble())],
            format: countLabel,
            centerLabel: 'Enquiries',
          ),
        ),
        DashCard(
          title: 'Booking status',
          subtitle: 'All bookings made in the period',
          child: DonutChart(
            slices: [
              for (final s in _fixedOrder(d.byStatus, kStatusOrder, (b) => b.count.toDouble())) Slice(_cap(s.label), s.value),
            ],
            format: countLabel,
            centerLabel: 'Bookings',
          ),
        ),
        DashCard(
          title: 'Top districts',
          subtitle: 'Net sales',
          child: BarList(
            maxItems: 6,
            items: [for (final b in d.byDistrict) BarItem(b.label, b.amount, inrShort(b.amount), sub: '${b.count}')],
          ),
        ),
      ]),
    ];
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Booking statuses in a fixed order, so each keeps its colour.
const kStatusOrder = ['confirmed', 'completed', 'pending', 'postponed', 'cancelled', 'rejected'];

/// Buckets as slices in [order] first (stable colours), then any others.
List<Slice> _fixedOrder(List<Bucket> buckets, List<String> order, double Function(Bucket) value) {
  final byLabel = {for (final b in buckets) b.label: b};
  return [
    for (final o in order)
      if (byLabel[o] != null) Slice(o, value(byLabel[o]!)),
    for (final b in buckets)
      if (!order.contains(b.label)) Slice(b.label, value(b)),
  ];
}
