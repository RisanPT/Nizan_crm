import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

enum _Part { summary, content, growth }

/// Socials → Reports & Insights: the period's summary with growth, what the numbers say (insights), content analysis by platform and
/// format, and the month-by-month growth. Export downloads the platform table and insights as a CSV. (Audience demographics are not in
/// the posts' numbers, so there is no Audience view — it needs the platforms' own audience reports.)
class SocialsReportsTab extends ConsumerStatefulWidget {
  const SocialsReportsTab({super.key});

  @override
  ConsumerState<SocialsReportsTab> createState() => _SocialsReportsTabState();
}

class _SocialsReportsTabState extends ConsumerState<SocialsReportsTab> {
  _Part _part = _Part.summary;

  static const _labels = {_Part.summary: 'Summary', _Part.content: 'Content Analysis', _Part.growth: 'Growth'};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(socialsReportsProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshSocials(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshSocials(ref))]),
        data: (r) => ListView(
          key: const Key('socials_reports_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final p in _Part.values) MktFilterChip(key: Key('soc_report_${p.name}'), label: _labels[p]!, selected: _part == p, onTap: () => setState(() => _part = p)),
              OutlinedButton.icon(key: const Key('soc_report_export'), onPressed: () => _export(r), icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Export Report')),
            ]),
            const SizedBox(height: 12),
            switch (_part) {
              _Part.summary => _Summary(r: r),
              _Part.content => _Content(r: r),
              _Part.growth => _Growth(r: r),
            },
          ],
        ),
      ),
    );
  }

  void _export(SocialsReports r) => downloadCsv('socials-report.csv', [
        ['Platform', 'Posts', 'Reach', 'Impressions', 'Engagements', 'Engagement rate %'],
        for (final p in r.platforms) [p.label, p.posts, p.reach, p.impressions, p.engagements, p.er ?? ''],
        [],
        ['Month', 'Posts', 'Reach', 'Impressions', 'Engagements'],
        for (final m in r.growthTrend) [m.month, m.posts, m.reach, m.impressions, m.engagements],
        [],
        ['Insights'],
        for (final i in r.insights) [i],
      ]);
}

class _Summary extends StatelessWidget {
  const _Summary({required this.r});
  final SocialsReports r;

  @override
  Widget build(BuildContext context) {
    String change(int? c) => c == null ? '—' : '${c >= 0 ? '↑ ' : '↓ '}${c.abs()}%';
    Color tone(int? c) => c == null ? Mkt.inkSoft : (c >= 0 ? Mkt.good : Mkt.bad);
    Widget row(String key, Color dot, String label, SummaryFigure f) => Padding(
          key: Key(key),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: mktText(12.5))),
            Text(groupedCount(f.value), style: mktText(12.5, weight: FontWeight.w800)),
            const SizedBox(width: 10),
            SizedBox(width: 56, child: Text(change(f.change), textAlign: TextAlign.right, style: mktText(11.5, weight: FontWeight.w700, color: tone(f.change)))),
          ]),
        );
    final g = r.overallGrowth;
    return MktGrid(rows: [
      [
        (5, MktCard(
          title: 'Summary',
          subtitle: r.from.isEmpty ? null : '${DateFormat('d MMM').format(DateTime.parse(r.from))} – ${DateFormat('d MMM yyyy').format(DateTime.parse(r.to))}',
          icon: Icons.summarize_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: g == null ? Mkt.border : tone(g), width: 7)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(g == null ? '—' : '${g >= 0 ? '+' : '−'}${g.abs()}%', key: const Key('soc_report_growth_pct'), style: mktText(19, weight: FontWeight.w800, color: tone(g))),
                  Text('Overall Growth', style: mktText(9.5, color: Mkt.inkSoft)),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(children: [
                  row('soc_report_reach', Mkt.violet2, 'Reach', r.reach),
                  row('soc_report_impr', Mkt.blue, 'Impressions', r.impressions),
                  row('soc_report_eng', Mkt.pink, 'Engagements', r.engagements),
                  row('soc_report_followers', Mkt.good, 'Followers', r.followers),
                ]),
              ),
            ]),
            if (g == null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Growth needs numbers typed on posts in this period and the one before it.', style: mktText(11.5, color: Mkt.inkSoft))),
          ]),
        )),
        (7, MktCard(
          title: 'Growth Trend',
          subtitle: 'Reach by month',
          icon: Icons.bar_chart_rounded,
          child: r.growthTrend.every((m) => m.reach == 0)
              ? const MktEmpty('No reach has been typed on posts in the last six months.', icon: Icons.bar_chart_rounded, height: 160)
              : SizedBox(
                  key: const Key('soc_growth_chart'),
                  height: 170,
                  child: BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    gridData: const FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: _grid),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, m) => v == m.max ? const SizedBox.shrink() : Text(compactCount(v), style: mktText(9.5, color: Mkt.inkSoft)))),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('MMM').format(DateTime.parse('${r.growthTrend[v.toInt()].month}-01')), style: mktText(10, color: Mkt.inkSoft))))),
                    ),
                    barGroups: [for (var i = 0; i < r.growthTrend.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: r.growthTrend[i].reach.toDouble(), color: Mkt.violet2, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(5)))])],
                  )),
                ),
        )),
      ],
      [
        (12, MktCard(
          title: 'Key Insights',
          icon: Icons.lightbulb_outline_rounded,
          child: r.insights.isEmpty
              ? const MktEmpty('Insights appear once posts have numbers typed on them.', icon: Icons.lightbulb_outline_rounded, height: 90)
              : Column(key: const Key('soc_report_insights'), children: [
                  for (final line in r.insights)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: Mkt.tint(Mkt.violet, 0.06), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [const Icon(Icons.auto_awesome_rounded, size: 15, color: Mkt.violet), const SizedBox(width: 8), Expanded(child: Text(line, style: mktText(12.5)))]),
                    ),
                ]),
        )),
      ],
    ]);
  }
}

FlLine _grid(double v) => const FlLine(color: Mkt.border, strokeWidth: 1);

class _Content extends StatelessWidget {
  const _Content({required this.r});
  final SocialsReports r;

  @override
  Widget build(BuildContext context) {
    final k = r.kpis;
    return MktGrid(rows: [
      [
        (5, MktCard(
          title: 'Posts by Format',
          icon: Icons.layers_outlined,
          child: Column(children: [
            for (final row in [('Reels', k.reels, Mkt.pink), ('Trial Reels', k.trialReels, Mkt.warn), ('Stories', k.stories, Mkt.violet2), ('Feed / Carousel', k.feed, Mkt.blue), ('Collab Posts', k.collab, Mkt.teal)])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(width: 110, child: Text(row.$1, style: mktText(12.5))),
                  Expanded(child: MktProgress(pct: k.total == 0 ? 0 : (row.$2 * 100 / k.total).round(), color: row.$3, labelWidth: 78)),
                  const SizedBox(width: 8),
                  Text('${row.$2}', style: mktText(12.5, weight: FontWeight.w800)),
                ]),
              ),
          ]),
        )),
        (7, MktCard(
          title: 'Platform Analysis',
          icon: Icons.bar_chart_rounded,
          child: r.platforms.isEmpty
              ? const MktEmpty('No post went out in this period.', icon: Icons.bar_chart_rounded, height: 110)
              : MktTable(
                  minWidth: 420,
                  rowHeight: 40,
                  columns: const [MktCol('Platform', flex: 3), MktCol('Posts', width: 48, align: Alignment.center), MktCol('Reach', flex: 2), MktCol('Engagements', flex: 2), MktCol('ER', width: 52, align: Alignment.centerRight)],
                  rows: [for (final p in r.platforms) [Text(p.label, style: mktText(12, weight: FontWeight.w700)), Text('${p.posts}', style: mktText(12)), Text(groupedCount(p.reach), style: mktText(12)), Text(groupedCount(p.engagements), style: mktText(12)), Text(p.er == null ? '—' : '${p.er}%', style: mktText(12, weight: FontWeight.w700))]],
                ),
        )),
      ],
      [
        (12, MktCard(
          title: 'Top Performing Posts',
          icon: Icons.emoji_events_outlined,
          child: r.top.isEmpty
              ? const MktEmpty('Nothing to rank yet.', icon: Icons.emoji_events_outlined, height: 90)
              : Column(children: [
                  for (final t in r.top)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        PostThumb(url: t.thumbUrl, contentType: t.contentType, width: 40, height: 40, radius: 8),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700))),
                        Text('${compactCount(t.views)} views · ${compactCount(t.engagements)} engagements', style: mktText(11.5, color: Mkt.inkSoft)),
                      ]),
                    ),
                ]),
        )),
      ],
    ]);
  }
}

class _Growth extends StatelessWidget {
  const _Growth({required this.r});
  final SocialsReports r;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Month by Month',
      subtitle: 'Posts that went out, and the numbers typed on them',
      icon: Icons.trending_up_rounded,
      child: MktTable(
        key: const Key('soc_growth_table'),
        minWidth: 420,
        rowHeight: 40,
        columns: const [MktCol('Month', flex: 2), MktCol('Posts', width: 56, align: Alignment.center), MktCol('Reach', flex: 2), MktCol('Impressions', flex: 2), MktCol('Engagements', flex: 2)],
        rows: [for (final m in r.growthTrend) [Text(DateFormat('MMM yyyy').format(DateTime.parse('${m.month}-01')), style: mktText(12, weight: FontWeight.w700)), Text('${m.posts}', style: mktText(12)), Text(groupedCount(m.reach), style: mktText(12)), Text(groupedCount(m.impressions), style: mktText(12)), Text(groupedCount(m.engagements), style: mktText(12))]],
      ),
    );
  }
}
