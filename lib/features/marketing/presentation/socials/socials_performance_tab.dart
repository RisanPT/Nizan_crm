import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

/// Socials → Performance: reach, impressions, engagement, video views and link clicks for the posts that went out in the range —
/// the numbers typed on each post — with the reach trend, a row per platform, and the best posts.
class SocialsPerformanceTab extends ConsumerStatefulWidget {
  const SocialsPerformanceTab({super.key});

  @override
  ConsumerState<SocialsPerformanceTab> createState() => _SocialsPerformanceTabState();
}

class _SocialsPerformanceTabState extends ConsumerState<SocialsPerformanceTab> {
  String _platform = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(socialsPerformanceProvider(_platform));
    return RefreshIndicator(
      onRefresh: () async => refreshSocials(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshSocials(ref))]),
        data: (p) {
          final t = p.totals;
          Widget kpi(String key, IconData icon, String label, String value, String changeKey, Color tint, {int? change}) {
            final d = deltaOf(change ?? t.change[changeKey]);
            return MktKpiCard(key: Key(key), icon: icon, value: value, label: label, note: d?.text, good: d?.good, tint: tint);
          }

          return ListView(
            key: const Key('socials_performance_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: KeyedSubtree(key: const Key('soc_perf_platform'), child: MktDropdownPill<String>(value: _platform, icon: Icons.public_rounded, options: [('all', 'All Platforms'), for (final pl in kPlatforms) (pl.$1, pl.$2)], onChanged: (v) => setState(() => _platform = v))),
              ),
              const SizedBox(height: 10),
              MktKpiRow(children: [
                kpi('soc_perf_reach', Icons.groups_outlined, 'Reach', groupedCount(t.reach), 'reach', Mkt.violet),
                kpi('soc_perf_impr', Icons.visibility_outlined, 'Impressions', groupedCount(t.impressions), 'impressions', Mkt.blue),
                kpi('soc_perf_eng', Icons.favorite_border_rounded, 'Engagements', groupedCount(t.engagements), 'engagements', Mkt.pink),
                MktKpiCard(key: const Key('soc_perf_er'), icon: Icons.percent_rounded, value: t.engagementRate == null ? '—' : '${t.engagementRate}%', label: 'Engagement Rate', tint: Mkt.warn),
                kpi('soc_perf_views', Icons.play_circle_outline_rounded, 'Video Views', groupedCount(t.videoViews), 'videoViews', Mkt.good),
                kpi('soc_perf_clicks', Icons.link_rounded, 'Link Clicks', groupedCount(t.linkClicks), 'linkClicks', Mkt.teal),
              ]),
              const SizedBox(height: 12),
              MktGrid(rows: [
                [(8, _TrendCard(p: p)), (4, _StatusCard(p: p))],
                [(7, _PlatformCard(p: p)), (5, _TopCard(p: p))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.p});
  final SocialsPerformance p;

  @override
  Widget build(BuildContext context) {
    final t = p.trend;
    final max = t.fold<int>(0, (m, e) => e.reach > m ? e.reach : m);
    return MktCard(
      title: 'Reach Trend',
      icon: Icons.show_chart_rounded,
      child: t.isEmpty || max == 0
          ? const MktEmpty('No reach has been typed on this period\'s posts yet.', icon: Icons.show_chart_rounded, height: 170)
          : SizedBox(
              key: const Key('soc_reach_trend'),
              height: 190,
              child: LineChart(LineChartData(
                minY: 0,
                gridData: const FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: _grid),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, m) => v == m.max || v == m.min ? const SizedBox.shrink() : Text(compactCount(v), style: mktText(9.5, color: Mkt.inkSoft)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: t.length > 10 ? (t.length / 7).ceilToDouble() : 1, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat(t.length <= 8 ? 'd MMM' : 'd').format(DateTime.parse(t[v.toInt().clamp(0, t.length - 1)].day)), style: mktText(9.5, color: Mkt.inkSoft))))),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < t.length; i++) FlSpot(i.toDouble(), t[i].reach.toDouble())],
                    isCurved: true,
                    color: Mkt.violet2,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: Mkt.violet2.withValues(alpha: 0.12)),
                  ),
                ],
              )),
            ),
    );
  }
}

FlLine _grid(double v) => const FlLine(color: Mkt.border, strokeWidth: 1);

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.p});
  final SocialsPerformance p;

  @override
  Widget build(BuildContext context) {
    final order = ['published', 'scheduled', 'in_review', 'producing', 'planned'];
    final stages = [for (final k in order) p.contentStatus.stages.firstWhere((s) => s.key == k, orElse: () => StageCount(key: k, label: k))];
    return MktCard(
      title: 'Content Status',
      icon: Icons.donut_large_rounded,
      child: p.contentStatus.total == 0
          ? const MktEmpty('Nothing planned in this period.', icon: Icons.donut_large_rounded, height: 170)
          : MktDonut(centerKey: const Key('soc_perf_status_total'), centerValue: '${p.contentStatus.total}', centerLabel: 'Total Content', size: 104, sideBySideFrom: 400, colors: [for (final s in stages) stageColor(s.key)], slices: [for (final s in stages) (label: s.label, value: s.count.toDouble(), trailing: '${s.count}')]),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.p});
  final SocialsPerformance p;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Platform Performance',
      icon: Icons.bar_chart_rounded,
      child: p.platforms.isEmpty
          ? const MktEmpty('No post went out in this period.', icon: Icons.bar_chart_rounded, height: 120)
          : MktTable(
              minWidth: 420,
              rowHeight: 42,
              rowKeys: [for (final r in p.platforms) Key('soc_perf_row_${r.platform}')],
              columns: const [MktCol('Platform', flex: 3), MktCol('Posts', width: 48, align: Alignment.center), MktCol('Reach', flex: 2), MktCol('Impressions', flex: 2), MktCol('Engagements', flex: 2), MktCol('ER', width: 52, align: Alignment.centerRight)],
              rows: [
                for (final r in p.platforms)
                  [
                    Row(children: [Icon(platformIcon(r.platform), size: 15, color: Mkt.violet), const SizedBox(width: 6), Text(r.label, style: mktText(12, weight: FontWeight.w700))]),
                    Text('${r.posts}', style: mktText(12)),
                    Text(groupedCount(r.reach), style: mktText(12)),
                    Text(groupedCount(r.impressions), style: mktText(12)),
                    Text(groupedCount(r.engagements), style: mktText(12)),
                    Text(r.er == null ? '—' : '${r.er}%', style: mktText(12, weight: FontWeight.w700)),
                  ],
              ],
            ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.p});
  final SocialsPerformance p;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Top Performing Content',
      icon: Icons.emoji_events_outlined,
      child: p.top.isEmpty
          ? const MktEmpty('Type the numbers on a post once it is out, and the best ones rank here.', icon: Icons.emoji_events_outlined, height: 120)
          : Column(children: [
              for (final t in p.top)
                InkWell(
                  key: Key('soc_top_${t.id}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: t.permalink.isEmpty ? null : () => launchUrl(Uri.parse(t.permalink), mode: LaunchMode.externalApplication),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      PostThumb(url: t.thumbUrl, contentType: t.contentType, width: 44, height: 44, radius: 9),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                          Text('${postFormatLabel(t.contentType)} · ${platformName(t.platform)}', style: mktText(10.5, color: Mkt.inkSoft)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(compactCount(t.views), style: mktText(13, weight: FontWeight.w800)),
                        Text('views', style: mktText(10, color: Mkt.inkSoft)),
                      ]),
                    ]),
                  ),
                ),
            ]),
    );
  }
}
