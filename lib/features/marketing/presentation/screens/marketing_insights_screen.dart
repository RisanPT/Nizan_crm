import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';

/// Marketing Intelligence — customer promoter score (NPS) + trend, satisfaction,
/// artist utilization, financial-year slot utilization, and Pincode/Timeline/
/// Culture segmentation. All from one backend insights call.
class MarketingInsightsScreen extends ConsumerWidget {
  const MarketingInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketingInsightsProvider);
    final selectedFy = ref.watch(marketingFyProvider);

    final nowFy = _currentFyStartYear();

    return MktPage(
      child: Material(
        type: MaterialType.transparency,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(marketingInsightsProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              MktHeader(
                icon: Icons.insights_outlined,
                title: 'Marketing Insights',
                subtitle: 'Promoter score · utilization · segments',
                actions: [_fyDropdown(ref, selectedFy ?? nowFy, nowFy)],
              ),
              const SizedBox(height: 14),
              async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: AppErrorView(error: e, onRetry: () => ref.invalidate(marketingInsightsProvider)),
                ),
                data: (d) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI row
                    MktKpiRow(
                      children: [
                        MktKpiCard(
                          icon: Icons.sentiment_very_satisfied_outlined,
                          value: '${d.nps.nps}',
                          label: 'Promoter Score (NPS)',
                          note: '${d.nps.responses} responses',
                          tint: _npsColor(d.nps.nps),
                        ),
                        MktKpiCard(
                          icon: Icons.star_border_rounded,
                          value: d.avgBrideScore.toStringAsFixed(1),
                          label: 'Client Satisfaction',
                          note: 'avg /5 · ${d.csatSubmitted} reviews',
                          tint: Mkt.warn,
                        ),
                        MktKpiCard(
                          icon: Icons.groups_2_outlined,
                          value: '${d.artistUtilPct}%',
                          label: 'Artist Utilization',
                          note: '${d.artistBusy}/${d.artistTotal} on jobs',
                          tint: Mkt.primaryLight,
                        ),
                        MktKpiCard(
                          icon: Icons.event_seat_outlined,
                          value: '${d.slot.pct}%',
                          label: 'Slot Utilization (FY)',
                          note: '${d.slot.totalBooked}/${d.slot.totalCapacity} slots',
                          tint: Mkt.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // NPS + utilization gauges
                    MktGrid(
                      breakpoint: 760,
                      rows: [
                        [
                          (1, MktCard(title: 'Net Promoter Score', icon: Icons.sentiment_satisfied_alt_outlined, child: _npsBody(d.nps))),
                          (1, MktCard(title: 'Utilization', icon: Icons.speed_outlined, child: _utilBody(d.artistUtilPct, d.slot))),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Timeline (seasonality)
                    MktCard(
                      title: 'Booking Timeline (seasonality)',
                      icon: Icons.show_chart_rounded,
                      child: _timeline(d.byMonth),
                    ),
                    const SizedBox(height: 12),

                    // Pincode / area + culture
                    MktGrid(
                      breakpoint: 760,
                      rows: [
                        [
                          (1, MktCard(title: 'Top Areas (District)', icon: Icons.place_outlined, child: _ranked(d.byDistrict, 'bookings'))),
                          (1, MktCard(title: 'By Region', icon: Icons.public, child: _ranked(d.byRegion, 'bookings'))),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    MktCard(title: 'By Culture / Community', icon: Icons.diversity_3_outlined, child: _culture(d.byCulture)),
                    const SizedBox(height: 12),

                    // Re-engagement entry
                    _reEngagementCard(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FY selector ──
  Widget _fyDropdown(WidgetRef ref, int value, int nowFy) {
    final years = [nowFy, nowFy - 1, nowFy - 2, nowFy - 3];
    return MktDropdownPill<int>(
      value: value,
      icon: Icons.calendar_today_outlined,
      options: [for (final y in years) (y, 'FY ${_fyLabel(y)}')],
      onChanged: (v) {
        ref.read(marketingFyProvider.notifier).state = v;
        ref.invalidate(marketingInsightsProvider);
      },
    );
  }

  // ── NPS body: split bar + monthly trend ──
  Widget _npsBody(NpsSummary n) {
    final total =
        (n.promoters + n.passives + n.detractors).clamp(1, 1 << 30).toDouble();
    Widget seg(int v, Color c) => v == 0
        ? const SizedBox.shrink()
        : Expanded(flex: v, child: Container(height: 12, color: c));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${n.nps}', style: mktText(40, weight: FontWeight.w900, color: _npsColor(n.nps))),
            8.wg,
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${n.responses} responses', style: mktText(12, color: Mkt.inkSoft)),
            ),
          ],
        ),
        10.hg,
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Row(children: [
              seg(n.promoters, Mkt.good),
              seg(n.passives, Mkt.warn),
              seg(n.detractors, Mkt.bad),
            ]),
          ),
        8.hg,
        Row(
          children: [
            _legend('Promoters', n.promoters, Mkt.good),
            _legend('Passives', n.passives, Mkt.warn),
            _legend('Detractors', n.detractors, Mkt.bad),
          ],
        ),
        if (n.trend.length >= 2) ...[
          16.hg,
          Text('NPS trend', style: mktText(11.5, color: Mkt.inkSoft)),
          8.hg,
          SizedBox(height: 90, child: _npsTrendChart(n.trend)),
        ],
      ],
    );
  }

  Widget _npsTrendChart(List<NpsPoint> trend) {
    final pts = trend.length > 12 ? trend.sublist(trend.length - 12) : trend;
    return LineChart(LineChartData(
      minY: -100,
      maxY: 100,
      gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 50,
          getDrawingHorizontalLine: (v) =>
              const FlLine(color: Mkt.border, strokeWidth: 0.6)),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 50,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: mktText(9, color: Mkt.inkSoft)))),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= pts.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_mLabel(pts[i].month),
                        style: mktText(8, color: Mkt.inkSoft)),
                  );
                })),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < pts.length; i++)
              FlSpot(i.toDouble(), pts[i].nps.toDouble())
          ],
          isCurved: true,
          color: Mkt.primaryLight,
          barWidth: 2.5,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: Mkt.tint(Mkt.primaryLight)),
        ),
      ],
    ));
  }

  // ── Utilization: two gauges ──
  Widget _utilBody(int artistPct, SlotUtil slot) {
    return Row(
      children: [
        Expanded(child: _gauge(artistPct, 'Artists', 'on live jobs')),
        Expanded(
            child: _gauge(slot.pct, 'FY Slots',
                '${slot.totalBooked}/${slot.totalCapacity}')),
      ],
    );
  }

  Widget _gauge(int pct, String title, String sub) {
    final color = pct >= 70 ? Mkt.good : (pct >= 40 ? Mkt.warn : Mkt.primaryLight);
    return Column(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 0,
                centerSpaceRadius: 38,
                sections: [
                  PieChartSectionData(
                      value: pct.toDouble(),
                      color: color,
                      radius: 12,
                      showTitle: false),
                  PieChartSectionData(
                      value: (100 - pct).toDouble().clamp(0, 100),
                      color: Mkt.border,
                      radius: 12,
                      showTitle: false),
                ],
              )),
              Text('$pct%', style: mktText(20, weight: FontWeight.w900)),
            ],
          ),
        ),
        6.hg,
        Text(title, style: mktText(13, weight: FontWeight.w700)),
        Text(sub, style: mktText(10.5, color: Mkt.inkSoft)),
      ],
    );
  }

  // ── Timeline / seasonality bars ──
  Widget _timeline(List<SegmentRow> months) {
    if (months.isEmpty) return const MktEmpty('No bookings in this period.', icon: Icons.show_chart_rounded);
    final max = months.fold<int>(1, (m, r) => r.bookings > m ? r.bookings : m);
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in months)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${m.bookings}', style: mktText(9, weight: FontWeight.w700, color: Mkt.inkSoft)),
                        3.hg,
                        Container(
                          height: (90 * (m.bookings / max)).clamp(2, 90),
                          decoration: BoxDecoration(
                            color: Mkt.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        4.hg,
                        Text(_mLabel(m.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mktText(8.5, color: Mkt.inkSoft)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Ranked segment bars (district / region) ──
  Widget _ranked(List<SegmentRow> rows, String unit) {
    if (rows.isEmpty) return const MktEmpty('No data yet.', icon: Icons.bar_chart_rounded);
    final max = rows.fold<int>(1, (m, r) => r.bookings > m ? r.bookings : m);
    return Column(
      children: [
        for (final r in rows.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12)),
                ),
                Expanded(
                  child: MktProgress(
                    pct: (r.bookings / max * 100).round(),
                    color: Mkt.primaryLight,
                    height: 9,
                    showLabel: false,
                  ),
                ),
                8.wg,
                Text('${r.bookings}', style: mktText(12, weight: FontWeight.w800)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _culture(List<SegmentRow> rows) {
    final meaningful =
        rows.where((r) => r.name != 'Not specified' && r.bookings > 0).toList();
    if (meaningful.isEmpty) {
      return const MktEmpty(
        'No community data yet. Set "Community / Culture" on the Manage Booking screen to build this segment.',
        icon: Icons.diversity_3_outlined,
        height: 130,
      );
    }
    return _ranked(rows, 'bookings');
  }

  // ── Re-engagement entry card ──
  Widget _reEngagementCard(BuildContext context) => MktCard(
        title: 'Client Re-engagement',
        icon: Icons.campaign_outlined,
        link: 'Open',
        onLink: () => context.push('/marketing/re-engagement'),
        child: InkWell(
          onTap: () => context.push('/marketing/re-engagement'),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                    'Past brides due for a re-touch — one-tap WhatsApp outreach.',
                    style: mktText(12, color: Mkt.inkSoft)),
              ),
              const Icon(Icons.chevron_right, color: Mkt.inkSoft),
            ],
          ),
        ),
      );

  // ── shared layout helpers ──
  Widget _legend(String label, int v, Color c) => Expanded(
        child: Row(
          children: [
            Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            5.wg,
            Flexible(
              child: Text('$label ($v)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mktText(11, color: Mkt.inkSoft)),
            ),
          ],
        ),
      );

  static Color _npsColor(int nps) {
    if (nps >= 50) return Mkt.good;
    if (nps >= 0) return Mkt.warn;
    return Mkt.bad;
  }

  static int _currentFyStartYear() {
    final n = DateTime.now();
    return n.month >= 4 ? n.year : n.year - 1;
  }

  static String _fyLabel(int startYear) =>
      '$startYear-${((startYear + 1) % 100).toString().padLeft(2, '0')}';

  static const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
      'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _mLabel(String ym) {
    // 'YYYY-MM' → 'Mon'
    final parts = ym.split('-');
    if (parts.length < 2) return ym;
    final m = int.tryParse(parts[1]) ?? 0;
    return (m >= 1 && m <= 12) ? _mon[m] : ym;
  }
}

extension _Gap on num {
  Widget get hg => SizedBox(height: toDouble());
  Widget get wg => SizedBox(width: toDouble());
}
