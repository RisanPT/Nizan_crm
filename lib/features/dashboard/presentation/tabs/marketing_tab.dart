import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/dashboard/controllers/dashboard_analytics_provider.dart';
import 'package:nizan_crm/features/dashboard/data/dashboard_analytics.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_period_bar.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart';

/// Dashboard → Marketing: enquiry volume and trend, where enquiries come from
/// and how well each source converts, the pipeline, campaign spend vs return,
/// content output and client ratings. Only filter: month / custom range.
class MarketingTab extends ConsumerStatefulWidget {
  const MarketingTab({super.key});

  @override
  ConsumerState<MarketingTab> createState() => _MarketingTabState();
}

class _MarketingTabState extends ConsumerState<MarketingTab> {
  DashboardQuery _q = DashboardQuery.thisMonth();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(marketingDashboardProvider(_q));
    return RefreshIndicator(
      color: kBrand,
      onRefresh: () => ref.refresh(marketingDashboardProvider(_q).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          DashboardPeriodBar(query: _q, onChanged: (q) => setState(() => _q = q)),
          const SizedBox(height: 18),
          dashAsync(async, _body, () => ref.invalidate(marketingDashboardProvider(_q))),
        ],
      ),
    );
  }

  List<Widget> _body(MarketingDashboard d) {
    final vs = 'vs ${_q.prevShort}';
    final labels = d.trend.map((t) => bucketLabel(t.key, d.unit)).toList();
    final per = d.unit == 'day' ? 'day' : d.unit;
    final topSources = d.sources.take(8).toList();
    return [
      TileGrid(children: [
        KpiTile(label: 'Enquiries', value: countLabel(d.enquiries), icon: Icons.person_add_alt_rounded,
            delta: deltaPct(d.enquiries, d.prevEnquiries), deltaLabel: vs, spark: d.trend.map((t) => t.value).toList()),
        KpiTile(label: 'Converted', value: countLabel(d.converted), icon: Icons.check_circle_outline_rounded,
            delta: deltaPct(d.converted, d.prevConverted), deltaLabel: vs, spark: d.trend.map((t) => t.count.toDouble()).toList()),
        KpiTile(label: 'Conversion rate', value: pct(d.conversion), icon: Icons.trending_up_rounded,
            delta: deltaPct(d.conversion, d.prevConversion), deltaLabel: vs),
        KpiTile(label: 'Open pipeline', value: countLabel(d.open), icon: Icons.filter_alt_outlined,
            hint: '${d.lost} lost in the period'),
        KpiTile(label: 'Sales from enquiries', value: inr(d.revenue), icon: Icons.currency_rupee_rounded,
            hint: 'bookings from this period’s enquiries'),
        KpiTile(label: 'Campaign spend', value: inr(d.spend), icon: Icons.campaign_outlined,
            delta: deltaPct(d.spend, d.prevSpend), deltaLabel: vs, lowerIsBetter: true),
        KpiTile(label: 'Cost per enquiry', value: d.costPerEnquiry == null ? '—' : inr(d.costPerEnquiry!),
            icon: Icons.price_change_outlined, hint: d.costPerEnquiry == null ? 'no campaign spend recorded' : 'spend ÷ enquiries'),
        KpiTile(label: 'Client rating', value: d.avgRating == null ? '—' : '${d.avgRating!.toStringAsFixed(1)} / 5',
            icon: Icons.star_outline_rounded, hint: '${d.reviews} review${d.reviews == 1 ? '' : 's'}'),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(flex: const [3, 2], minHeight: 376, children: [
        DashCard(
          title: 'Enquiries over time',
          subtitle: 'New enquiries per $per',
          child: TrendLineChart(
            labels: labels,
            values: d.trend.map((t) => t.value).toList(),
            previous: d.trend.map((t) => t.prevValue).toList(),
            previousLabel: _q.prevLabel,
            format: countLabel,
          ),
        ),
        DashCard(
          title: 'Where enquiries come from',
          subtitle: 'Share by source',
          child: DonutChart(
            slices: [for (final s in d.sources) Slice(s.label, s.count.toDouble())],
            format: countLabel,
            centerLabel: 'Enquiries',
          ),
        ),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(flex: const [3, 2], minHeight: 380, children: [
        DashCard(
          title: 'Source performance',
          subtitle: 'Enquiries vs converted, by source',
          child: GroupedBarChart(
            labels: topSources.map((s) => s.label).toList(),
            series: [
              BarSeries('Enquiries', kSeries[0], topSources.map((s) => s.count.toDouble()).toList()),
              BarSeries('Converted', kSeries[1], topSources.map((s) => s.converted.toDouble()).toList()),
            ],
            format: countLabel,
          ),
        ),
        DashCard(
          title: 'Conversion rate by source',
          subtitle: 'Converted ÷ enquiries',
          child: BarList(
            items: [
              for (final s in d.sources.where((s) => s.count > 0))
                BarItem(s.label, s.conversion, pct(s.conversion), sub: '${s.converted}/${s.count}'),
            ]..sort((a, b) => b.value.compareTo(a.value)),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      ResponsiveRow(minHeight: 406, children: [
        DashCard(
          title: 'Pipeline',
          subtitle: 'Where this period’s enquiries are now',
          child: BarList(
            maxItems: 7,
            items: [for (final b in d.pipeline) BarItem(b.label, b.count.toDouble(), countLabel(b.count))],
          ),
        ),
        DashCard(
          title: 'Enquiry priority',
          child: DonutChart(
            slices: [for (final b in d.priority) Slice(b.label, b.count.toDouble())],
            format: countLabel,
            centerLabel: 'Enquiries',
          ),
        ),
        DashCard(
          title: 'Top locations',
          subtitle: 'Enquiries by district',
          child: BarList(
            maxItems: 6,
            items: [for (final b in d.districts) BarItem(b.label, b.count.toDouble(), countLabel(b.count))],
          ),
        ),
      ]),
      const SizedBox(height: 16),
      DashCard(
          title: 'Campaigns',
          subtitle: 'Running in the period · sales from enquiries tagged to each',
          child: DashTable(
            columns: const ['Campaign', 'Channel', 'Spend', 'Enquiries', 'Converted', 'Sales', 'Return'],
            numericColumns: const {2, 3, 4, 5, 6},
            rows: [
              for (final c in d.campaigns)
                [
                  Text(c.label, style: dashText(13, weight: FontWeight.w600)),
                  Text(c.channel.isEmpty ? '—' : c.channel),
                  Text(inr(c.spend)),
                  Text(countLabel(c.leads)),
                  Text(countLabel(c.converted)),
                  Text(inr(c.revenue)),
                  Text(c.spend > 0 ? '${(c.revenue / c.spend).toStringAsFixed(1)}×' : '—',
                      style: dashText(13, weight: FontWeight.w700)),
                ],
            ],
          ),
        ),
      const SizedBox(height: 16),
      ResponsiveRow(minHeight: 300, children: [
        DashCard(
          title: 'Content',
          subtitle: 'Scheduled in the period, by platform',
          child: GroupedBarChart(
            labels: d.content.map((c) => c.label).toList(),
            series: [
              BarSeries('Published', kSeries[0], d.content.map((c) => c.published.toDouble()).toList()),
              BarSeries('Planned', kSeries[1], d.content.map((c) => c.planned.toDouble()).toList()),
            ],
            format: countLabel,
            height: 220,
          ),
        ),
        DashCard(
          title: 'Client ratings',
          subtitle: d.reviews == 0
              ? 'No reviews submitted in the period'
              : 'Overall rating · ${d.reviews} submitted review${d.reviews == 1 ? '' : 's'}',
          child: BarList(
            emptyText: 'No reviews submitted in the period',
            items: d.reviews == 0
                ? const []
                : [
                    for (final r in d.ratings.reversed)
                      BarItem(r.label, r.count.toDouble(), countLabel(r.count),
                          sub: '${(r.count / d.reviews * 100).toStringAsFixed(0)}%'),
                  ],
          ),
        ),
      ]),
    ];
  }
}
