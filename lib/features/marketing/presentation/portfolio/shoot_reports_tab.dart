import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_widgets.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';

/// Creative Portfolio → Shoot Reports: planned outputs (from the Shoot Planner) against delivered ones (assets attached to the shoot
/// that are Approved or Final), turnaround, footage, and a report for each shoot.
class ShootReportsTab extends ConsumerWidget {
  const ShootReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shootReportsProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshPortfolio(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshPortfolio(ref))]),
        data: (r) {
          final k = r.kpis;
          Widget kpi(String key, IconData icon, String label, String value, String changeKey, Color tint, {bool lowerIsBetter = false}) {
            final ch = k.change[changeKey];
            final d = deltaOfChange(ch, lowerIsBetter: lowerIsBetter);
            return MktKpiCard(key: Key(key), icon: icon, value: value, label: label, note: d?.text, good: d?.good, tint: tint);
          }

          final selected = ref.watch(selectedReportShootProvider);
          final openId = r.rows.any((s) => s.id == selected) ? selected : (r.rows.isEmpty ? null : r.rows.first.id);
          return ListView(
            key: const Key('portfolio_reports_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 180, children: [
                kpi('sr_kpi_shoots', Icons.photo_camera_outlined, 'Total Shoots', '${k.shoots}', 'shoots', Mkt.violet),
                kpi('sr_kpi_completed', Icons.check_circle_outline_rounded, 'Completed', '${k.completed}', 'completed', Mkt.good),
                kpi('sr_kpi_outputs', Icons.play_circle_outline_rounded, 'Total Outputs', '${k.outputs}', 'outputs', Mkt.warn),
                kpi('sr_kpi_footage', Icons.storage_rounded, 'Footage Captured', k.footageGb == null ? '—' : '${k.footageGb} GB', 'footageGb', Mkt.blue),
                kpi('sr_kpi_turnaround', Icons.timer_outlined, 'Avg. Turnaround', k.turnaround == null ? '—' : '${k.turnaround} Days', 'turnaround', Mkt.pink, lowerIsBetter: true),
              ]),
              const SizedBox(height: 12),
              MktGrid(breakpoint: 980, rows: [
                [(5, _Completion(r: r)), (3, _Distribution(r: r)), (4, _Efficiency(r: r))],
                [(7, _ReportList(r: r, openId: openId)), (5, openId == null ? const MktCard(title: 'Shoot Report', icon: Icons.description_outlined, child: MktEmpty('Pick a shoot to read its report.', icon: Icons.description_outlined, height: 160)) : ShootReportCard(key: ValueKey('report_$openId'), id: openId))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

/// "↑ +12% vs last month" with the colour the direction deserves (for turnaround a fall is good).
({String text, bool? good})? deltaOfChange(int? change, {bool lowerIsBetter = false, String tail = 'vs last period'}) {
  if (change == null) return null;
  if (change == 0) return (text: 'No change', good: null);
  final up = change > 0;
  return (text: '${up ? '↑ +' : '↓ −'}${change.abs()}% $tail', good: lowerIsBetter ? !up : up);
}

class _Completion extends StatelessWidget {
  const _Completion({required this.r});
  final ShootReports r;

  @override
  Widget build(BuildContext context) {
    final max = r.monthly.fold<int>(0, (m, e) => [m, e.planned, e.delivered].reduce((a, b) => a > b ? a : b));
    return MktCard(
      title: 'Shoot Completion Overview',
      subtitle: 'Planned and delivered outputs by month',
      icon: Icons.bar_chart_rounded,
      child: max == 0
          ? const MktEmpty('No outputs are planned in these months.', icon: Icons.bar_chart_rounded, height: 150)
          : Column(children: [
              SizedBox(
                key: const Key('sr_completion_chart'),
                height: 150,
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (max * 1.15).ceilToDouble(),
                  gridData: const FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: _grid),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) => v == m.max ? const SizedBox.shrink() : Text('${v.toInt()}', style: mktText(9.5, color: Mkt.inkSoft)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('MMM').format(DateTime.parse('${r.monthly[v.toInt()].month}-01')), style: mktText(10, color: Mkt.inkSoft))))),
                  ),
                  barGroups: [for (var i = 0; i < r.monthly.length; i++) BarChartGroupData(x: i, barsSpace: 3, barRods: [BarChartRodData(toY: r.monthly[i].planned.toDouble(), color: Mkt.tint(Mkt.violet, 0.35), width: 11, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))), BarChartRodData(toY: r.monthly[i].delivered.toDouble(), color: Mkt.violet, width: 11, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))])],
                )),
              ),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final l in [('Planned', Mkt.tint(Mkt.violet, 0.35)), ('Delivered', Mkt.violet)]) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: l.$2, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 5), Text(l.$1, style: mktText(11, color: Mkt.inkSoft))]))]),
            ]),
    );
  }
}

FlLine _grid(double v) => const FlLine(color: Mkt.border, strokeWidth: 1);

class _Distribution extends StatelessWidget {
  const _Distribution({required this.r});
  final ShootReports r;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Output Distribution',
        icon: Icons.donut_large_rounded,
        child: r.distTotal == 0
            ? const MktEmpty('Nothing has been delivered yet.', icon: Icons.donut_large_rounded, height: 150)
            : MktDonut(centerKey: const Key('sr_dist_total'), centerValue: '${r.distTotal}', centerLabel: 'Outputs', size: 100, sideBySideFrom: 420, slices: [for (final d in r.distribution) (label: d.label, value: d.count.toDouble(), trailing: '${d.pct}% · ${d.count}')]),
      );
}

class _Efficiency extends StatelessWidget {
  const _Efficiency({required this.r});
  final ShootReports r;

  @override
  Widget build(BuildContext context) {
    final pts = [for (var i = 0; i < r.monthly.length; i++) if (r.monthly[i].turnaround != null) FlSpot(i.toDouble(), r.monthly[i].turnaround!)];
    final last = r.monthly.reversed.where((m) => m.turnaround != null).take(2).toList();
    final faster = last.length == 2 && last[1].turnaround! > 0 ? ((last[1].turnaround! - last[0].turnaround!) * 100 / last[1].turnaround!).round() : null;
    return MktCard(
      title: 'Production Efficiency',
      subtitle: 'Average turnaround (days)',
      icon: Icons.speed_rounded,
      trailing: faster == null ? null : MktChip('${faster.abs()}% ${faster >= 0 ? 'faster' : 'slower'}', color: faster >= 0 ? Mkt.good : Mkt.bad),
      child: pts.isEmpty
          ? const MktEmpty('Turnaround shows once a shoot has all its planned outputs delivered.', icon: Icons.speed_rounded, height: 150)
          : SizedBox(
              key: const Key('sr_efficiency_chart'),
              height: 150,
              child: LineChart(LineChartData(
                minY: 0,
                gridData: const FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: _grid),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => v == m.max ? const SizedBox.shrink() : Text(v.toStringAsFixed(0), style: mktText(9.5, color: Mkt.inkSoft)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (v, _) => v == v.roundToDouble() && v.toInt() < r.monthly.length ? Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('MMM').format(DateTime.parse('${r.monthly[v.toInt()].month}-01')), style: mktText(10, color: Mkt.inkSoft))) : const SizedBox.shrink())),
                ),
                lineBarsData: [LineChartBarData(spots: pts, isCurved: true, color: Mkt.violet2, barWidth: 2.5, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: Mkt.violet2.withValues(alpha: 0.12)))],
              )),
            ),
    );
  }
}

class _ReportList extends ConsumerStatefulWidget {
  const _ReportList({required this.r, required this.openId});
  final ShootReports r;
  final String? openId;

  @override
  ConsumerState<_ReportList> createState() => _ReportListState();
}

class _ReportListState extends ConsumerState<_ReportList> {
  late final _search = TextEditingController(text: ref.read(reportQueryProvider).q);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(ReportQuery q) => ref.read(reportQueryProvider.notifier).state = q;

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final q = ref.watch(reportQueryProvider);
    final from = r.total == 0 ? 0 : (r.page - 1) * r.pageSize + 1;
    final to = (r.page - 1) * r.pageSize + r.rows.length;
    final pages = (r.total / r.pageSize).ceil().clamp(1, 999);
    Widget count(String label, String key) => MktFilterChip(key: Key('sr_filter_$key'), label: label, count: r.filters[key] ?? 0, selected: q.filter == key, onTap: () => _set(ReportQuery(filter: key, q: q.q)));
    return MktCard(
      title: 'Recent Shoot Reports',
      icon: Icons.description_outlined,
      trailing: TextButton.icon(key: const Key('sr_export'), onPressed: () => downloadCsv('shoot-reports.csv', [['Shoot', 'Brand', 'Date', 'Status', 'Planned outputs', 'Delivered outputs', 'Turnaround (days)'], for (final s in r.rows) [s.title, s.brand, s.shootDate, shootStatusLabel(s.status), s.plannedTotal, s.deliveredTotal, s.turnaround ?? '']]), icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Export')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          count('All', 'all'),
          count('Completed', 'completed'),
          count('In Production', 'in_production'),
          count('Delayed', 'delayed'),
          SizedBox(
            width: 220,
            child: TextField(key: const Key('sr_search'), controller: _search, onChanged: (v) => _set(ReportQuery(filter: q.filter, q: v)), style: mktText(13), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded, size: 18), hintText: 'Search shoot, brand or campaign…', isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.violet)))),
          ),
        ]),
        const SizedBox(height: 10),
        if (r.rows.isEmpty) const MktEmpty('No shoot matches.', icon: Icons.description_outlined, height: 110) else
          MktTable(
            minWidth: 560,
            rowHeight: 52,
            rowKeys: [for (final s in r.rows) Key('sr_row_${s.id}')],
            onRowTap: (i) => ref.read(selectedReportShootProvider.notifier).state = r.rows[i].id,
            columns: const [MktCol('Shoot / Campaign', flex: 5), MktCol('Shoot Date', width: 82), MktCol('Outputs', flex: 3), MktCol('Status', width: 132), MktCol('Turnaround', width: 86, align: Alignment.centerRight)],
            rows: [
              for (final s in r.rows)
                [
                  Row(children: [ShootCover(url: s.coverUrl, size: 34, radius: 8), const SizedBox(width: 8), Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w800)), Text([if (s.category.isNotEmpty) s.category, s.brand == 'kerala' ? 'Kerala' : 'Main'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, color: Mkt.inkSoft))]))]),
                  Text(shootDay(s.shootDate, pattern: 'd MMM yyyy'), style: mktText(11)),
                  Text('${s.deliveredTotal} of ${s.plannedTotal}', style: mktText(12, weight: FontWeight.w700, color: s.plannedTotal > 0 && s.deliveredTotal >= s.plannedTotal ? Mkt.good : Mkt.ink)),
                  Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: MktChip(shootStatusLabel(s.status), color: shootStatusColor(s.status))), if (s.delayed) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.warning_amber_rounded, size: 14, color: Mkt.bad))]),
                  Text(s.turnaround == null ? '—' : '${s.turnaround} ${s.turnaround == 1 ? 'Day' : 'Days'}', style: mktText(12, weight: FontWeight.w700)),
                ],
            ],
          ),
        const SizedBox(height: 6),
        Row(children: [
          Flexible(child: Text(r.total == 0 ? 'No shoots' : 'Showing $from–$to of ${r.total}', key: const Key('sr_showing'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft))),
          const Spacer(),
          IconButton(key: const Key('sr_prev'), visualDensity: VisualDensity.compact, onPressed: r.page > 1 ? () => _set(ReportQuery(filter: q.filter, q: q.q, page: r.page - 1)) : null, icon: const Icon(Icons.chevron_left_rounded, size: 20)),
          Text('${r.page} / $pages', style: mktText(11.5, weight: FontWeight.w700)),
          IconButton(key: const Key('sr_next'), visualDensity: VisualDensity.compact, onPressed: r.page < pages ? () => _set(ReportQuery(filter: q.filter, q: q.q, page: r.page + 1)) : null, icon: const Icon(Icons.chevron_right_rounded, size: 20)),
        ]),
      ]),
    );
  }
}

enum _RPart { overview, assets, checklist, team }

/// One shoot's report: its summary and outputs, the assets attached, the milestone checklist, the crew, and the key takeaways.
class ShootReportCard extends ConsumerStatefulWidget {
  const ShootReportCard({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ShootReportCard> createState() => _ShootReportCardState();
}

class _ShootReportCardState extends ConsumerState<ShootReportCard> {
  _RPart _part = _RPart.overview;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shootDetailProvider(widget.id));
    return async.when(
      loading: () => const MktCard(title: 'Shoot Report', icon: Icons.description_outlined, child: SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => MktCard(title: 'Shoot Report', icon: Icons.description_outlined, child: AppErrorView(error: e, onRetry: () => ref.invalidate(shootDetailProvider(widget.id)))),
      data: (d) {
        final s = d.summary;
        return MktCard(
          title: s.title,
          subtitle: '${shootDay(s.shootDate)}${s.location.isEmpty ? '' : ' · ${s.location}'} · ${s.crewCount} crew',
          icon: Icons.description_outlined,
          trailing: MktChip(shootStatusLabel(s.status), color: shootStatusColor(s.status)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final p in _RPart.values) Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('sr_part_${p.name}'), label: p.name[0].toUpperCase() + p.name.substring(1), selected: _part == p, onTap: () => setState(() => _part = p)))])),
            const SizedBox(height: 10),
            switch (_part) {
              _RPart.overview => _overview(d),
              _RPart.assets => _assets(d),
              _RPart.checklist => _checklist(d),
              _RPart.team => _team(d),
            },
          ]),
        );
      },
    );
  }

  Widget _kv(String k, String v, {Key? key}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 118, child: Text(k, style: mktText(11.5, color: Mkt.inkSoft))), Expanded(child: Text(v, key: key, style: mktText(12.5, weight: FontWeight.w600)))]));

  Widget _overview(ShootDetail d) {
    final s = d.summary;
    String of(Map<String, int> m) => [for (final o in kOutputKeys) if ((m[o.$1] ?? 0) > 0) '${m[o.$1]} ${o.$2.toLowerCase()}'].join(', ');
    return Column(key: const Key('sr_overview'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _kv('Objective', d.objective.isEmpty ? '—' : d.objective),
      _kv('Outputs planned', of(s.planned).isEmpty ? 'None' : of(s.planned), key: const Key('sr_planned')),
      _kv('Outputs delivered', of(s.delivered).isEmpty ? 'None yet' : of(s.delivered), key: const Key('sr_delivered')),
      _kv('Turnaround', s.turnaround == null ? 'Not yet — shows when every planned output is delivered' : '${s.turnaround} ${s.turnaround == 1 ? 'day' : 'days'}', key: const Key('sr_turnaround')),
      _kv('Footage', d.footageMb <= 0 ? '—' : '${(d.footageMb / 1024).toStringAsFixed(1)} GB', key: const Key('sr_footage')),
      _kv('Progress', '${s.progress}%'),
      if (d.takeaways.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          key: const Key('sr_takeaways'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Mkt.tint(Mkt.violet, 0.06), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Key Takeaways', style: mktText(12, weight: FontWeight.w800)), const SizedBox(height: 4), for (final t in d.takeaways) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_rounded, size: 14, color: Mkt.good), const SizedBox(width: 6), Expanded(child: Text(t, style: mktText(11.5)))]))]),
        ),
      ],
    ]);
  }

  Widget _assets(ShootDetail d) => d.assets.isEmpty
      ? const MktEmpty('No assets are attached to this shoot yet.', icon: Icons.photo_library_outlined, height: 100)
      : Column(key: const Key('sr_assets'), children: [
          for (final a in d.assets.take(12))
            ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(a.media == 'video' ? Icons.play_circle_outline_rounded : Icons.image_outlined, color: Mkt.violet), title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w600)), subtitle: Text(assetKindLabel(a.kind), style: mktText(10.5, color: Mkt.inkSoft)), trailing: MktChip(assetStageLabel(a.stage), color: a.stage == 'approved' ? Mkt.good : Mkt.grey), onTap: () => launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication)),
        ]);

  Widget _checklist(ShootDetail d) => Column(key: const Key('sr_checklist'), children: [
        for (final m in d.milestones)
          Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Icon(m.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18, color: m.done ? Mkt.good : Mkt.inkSoft), const SizedBox(width: 8), Expanded(child: Text(m.label, style: mktText(12.5, weight: FontWeight.w600))), Text(m.doneAt != null ? 'Done ${DateFormat('d MMM').format(m.doneAt!)}' : (m.date == null ? '' : 'Planned ${shootDay(m.date!, pattern: 'd MMM')}'), style: mktText(11, color: Mkt.inkSoft))])),
      ]);

  Widget _team(ShootDetail d) => d.crew.isEmpty
      ? const MktEmpty('No crew was assigned.', icon: Icons.groups_2_outlined, height: 90)
      : Column(key: const Key('sr_team'), children: [for (final c in d.crew) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [MktAvatar(c.name, size: 26), const SizedBox(width: 8), Expanded(child: Text(c.name, style: mktText(12.5, weight: FontWeight.w700))), if (c.role.isNotEmpty) MktChip(c.role, color: Mkt.violet)]))]);
}
