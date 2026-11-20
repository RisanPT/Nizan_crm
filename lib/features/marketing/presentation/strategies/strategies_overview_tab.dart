import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/strategy_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_exports.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_work_tab.dart';
import 'package:nizan_crm/features/marketing/services/strategy_service.dart';

/// Strategies & Developments → Overview: what the other six screens count, on one page — KPIs, the plans' focus areas, the quarterly
/// roadmap, the key initiatives and development projects (progress counted from their tasks), how each focus area is performing, the
/// recent changes, the latest research and the outcomes of the latest review.
class StrategiesOverviewTab extends ConsumerWidget {
  const StrategiesOverviewTab({super.key, required this.onOpenTab});

  /// Opens another tab of the screen ("View All →").
  final ValueChanged<String> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(strategyOverviewProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshStrategies(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshStrategies(ref))]),
        data: (o) {
          final k = o.kpis;
          return ListView(
            key: const Key('strategies_overview_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: const Key('st_overview_export'),
                  onPressed: () async {
                    try {
                      await downloadCsv('strategies-overview.csv', overviewCsv(o));
                    } catch (e) {
                      if (context.mounted) showErrorSnackBar(context, e);
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export CSV'),
                ),
              ),
              const SizedBox(height: 8),
              MktKpiRow(minWidth: 168, children: [
                MktKpiCard(key: const Key('st_kpi_active'), icon: Icons.track_changes_rounded, value: '${k.activeStrategies}', label: 'Active Strategies', tint: Mkt.primary),
                MktKpiCard(key: const Key('st_kpi_projects'), icon: Icons.layers_outlined, value: '${k.developmentProjects}', label: 'Development Projects', tint: Mkt.good),
                MktKpiCard(key: const Key('st_kpi_initiatives'), icon: Icons.flag_outlined, value: '${k.totalInitiatives}', label: 'Total Initiatives', tint: Mkt.warn),
                MktKpiCard(key: const Key('st_kpi_on_track'), icon: Icons.check_circle_outline_rounded, value: '${k.onTrack}', label: 'On Track', tint: Mkt.blue),
                MktKpiCard(key: const Key('st_kpi_at_risk'), icon: Icons.hourglass_bottom_rounded, value: '${k.atRisk}', label: 'At Risk', tint: Mkt.bad),
                MktKpiCard(key: const Key('st_kpi_new'), icon: Icons.rocket_launch_outlined, value: '${k.newThisWeek}', label: 'New This Week', tint: Mkt.pink),
              ]),
              const SizedBox(height: 12),
              MktGrid(rows: [
                [(4, _FocusAreas(o: o, onOpen: onOpenTab)), (8, _RoadmapCard(o: o, onOpen: onOpenTab))],
                [(5, _KeyInitiatives(o: o, onOpen: onOpenTab)), (3, _ProjectCards(o: o, onOpen: onOpenTab)), (4, _Performance(o: o))],
                [(4, _RecentUpdates(o: o)), (4, _ResearchCards(o: o, onOpen: onOpenTab)), (4, _KeyOutcomesCard(o: o, onOpen: onOpenTab))],
              ]),
              if (o.strategyWork.tracked) ...[
                const SizedBox(height: 12),
                MktCard(
                  key: const Key('st_strategy_work'),
                  title: 'Strategy Work Logged',
                  subtitle: '${o.strategyWork.logs} log${o.strategyWork.logs == 1 ? '' : 's'} in this period counted a strategy step (Log Activity → Strategies)',
                  icon: Icons.edit_note_rounded,
                  child: StrategyWorkChips(work: o.strategyWork, showAllTypes: true, emptyText: 'No strategy step was logged in this period.'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FocusAreas extends StatelessWidget {
  const _FocusAreas({required this.o, required this.onOpen});
  final StrategyOverview o;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Strategic Focus Areas (${o.year == 0 ? DateTime.now().year : o.year})',
        icon: Icons.donut_large_rounded,
        link: 'View All',
        linkKey: const Key('st_link_plans'),
        onLink: () => onOpen('plans'),
        child: o.focus.isEmpty
            ? const MktEmpty('No active strategic plan in this period. Add one in Strategic Plans.', icon: Icons.donut_large_rounded, height: 170)
            : MktDonut(centerKey: const Key('st_focus_total'), centerValue: '${o.focusTotal}', centerLabel: 'Strategies', size: 120, sideBySideFrom: 360, slices: [for (final f in o.focus) (label: f.focusArea, value: f.count.toDouble(), trailing: '${f.count}')]),
      );
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({required this.o, required this.onOpen});
  final StrategyOverview o;
  final ValueChanged<String> onOpen;

  static const _tints = [Mkt.primaryLight, Mkt.good, Mkt.warn, Mkt.pink];

  @override
  Widget build(BuildContext context) {
    final quarters = o.quarters.isEmpty ? [for (var q = 1; q <= 4; q++) RoadmapQuarter(quarter: q, label: 'Q$q')] : o.quarters;
    final empty = quarters.every((q) => q.total == 0);
    return MktCard(
      title: 'Quarterly Strategic Roadmap',
      icon: Icons.alt_route_rounded,
      link: 'View Roadmap',
      linkKey: const Key('st_link_roadmap'),
      onLink: () => onOpen('roadmap'),
      child: empty
          ? const MktEmpty('Nothing is planned on the roadmap for this year yet.', icon: Icons.alt_route_rounded, height: 150)
          : LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth >= 560;
              Widget col(RoadmapQuarter q) => Container(
                    key: Key('st_ov_q${q.quarter}'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Mkt.tint(_tints[(q.quarter - 1) % 4], 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Mkt.tint(_tints[(q.quarter - 1) % 4], 0.25))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${q.label} (${q.months})', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, weight: FontWeight.w800)),
                      Text(q.theme.isEmpty ? '—' : q.theme, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
                      const SizedBox(height: 8),
                      if (q.items.isEmpty) Text('Nothing planned', style: mktText(11, color: Mkt.inkSoft)),
                      for (final it in q.items.take(4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(children: [
                            Icon(it.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 14, color: it.done ? Mkt.good : Mkt.inkSoft),
                            const SizedBox(width: 6),
                            Expanded(child: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: it.done ? Mkt.ink : Mkt.inkSoft))),
                          ]),
                        ),
                      if (q.items.length > 4) Text('+${q.items.length - 4} more', style: mktText(10.5, color: Mkt.inkSoft)),
                    ]),
                  );
              if (wide) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 0; i < quarters.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: col(quarters[i]))]]);
              }
              return Column(children: [for (final q in quarters) Padding(padding: const EdgeInsets.only(bottom: 8), child: col(q))]);
            }),
    );
  }
}

class _KeyInitiatives extends ConsumerWidget {
  const _KeyInitiatives({required this.o, required this.onOpen});
  final StrategyOverview o;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MktCard(
        title: 'Key Strategic Initiatives',
        icon: Icons.flag_outlined,
        link: 'View All',
        linkKey: const Key('st_link_initiatives'),
        onLink: () => onOpen('initiatives'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: o.initiatives.isEmpty
            ? const MktEmpty('No initiative in this period. Use New Initiative.', icon: Icons.flag_outlined, height: 150)
            : MktTable(
                minWidth: 430,
                rowHeight: 50,
                onRowTap: (i) => openWork(context, ref, o.initiatives[i]),
                columns: const [MktCol('Initiative', flex: 5), MktCol('Owner', flex: 3), MktCol('Progress', flex: 4), MktCol('Due Date', flex: 3), MktCol('Status', flex: 3)],
                rowKeys: [for (final i in o.initiatives) Key('st_ov_init_${i.id}')],
                rows: [
                  for (final i in o.initiatives)
                    [
                      Padding(padding: const EdgeInsets.only(right: 6), child: Text(i.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700))),
                      Padding(padding: const EdgeInsets.only(right: 6), child: OwnerCell(owner: i.owner)),
                      Padding(padding: const EdgeInsets.only(right: 8), child: WorkProgressCell(item: i)),
                      Text(strategyDay(i.due, pattern: 'd MMM'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5)),
                      WorkStatusChip(i.status),
                    ],
                ],
              ),
      );
}

class _ProjectCards extends ConsumerWidget {
  const _ProjectCards({required this.o, required this.onOpen});
  final StrategyOverview o;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MktCard(
        title: 'Development Projects',
        icon: Icons.layers_outlined,
        link: 'View All',
        linkKey: const Key('st_link_projects'),
        onLink: () => onOpen('projects'),
        child: o.projects.isEmpty
            ? const MktEmpty('No development project in this period.', icon: Icons.layers_outlined, height: 150)
            : Column(children: [
                for (final p in o.projects)
                  InkWell(
                    key: Key('st_ov_proj_${p.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openWork(context, ref, p),
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Mkt.border)),
                    child: Row(children: [
                      Container(width: 38, height: 38, decoration: BoxDecoration(color: Mkt.tint(Mkt.primary, 0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.layers_outlined, size: 20, color: Mkt.primary)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w800)),
                          Text(p.description.isNotEmpty ? p.description : p.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
                          const SizedBox(height: 4),
                          WorkProgressCell(item: p, showNote: false),
                        ]),
                      ),
                    ]),
                  )),
              ]),
      );
}

class _Performance extends StatelessWidget {
  const _Performance({required this.o});
  final StrategyOverview o;

  @override
  Widget build(BuildContext context) {
    final rows = o.performance;
    final measured = rows.where((r) => r.progress != null).toList();
    return MktCard(
      title: 'Strategy Performance',
      subtitle: 'Mean progress of the initiatives in each focus area',
      icon: Icons.bar_chart_rounded,
      child: measured.isEmpty
          ? const MktEmpty('Progress shows once initiatives have tasks tied to them.', icon: Icons.bar_chart_rounded, height: 170)
          : SizedBox(
              key: const Key('st_perf_chart'),
              height: 190,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                minY: 0,
                gridData: const FlGridData(drawVerticalLine: false, horizontalInterval: 25, getDrawingHorizontalLine: _grid),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, _) {
                      final r = rows[group.x];
                      return BarTooltipItem('${r.focusArea}\n${r.progress}% · ${r.measured} of ${r.initiatives} measured', mktText(11, weight: FontWeight.w700, color: Colors.white));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: 25, getTitlesWidget: (v, m) => Text('${v.toInt()}%', style: mktText(9.5, color: Mkt.inkSoft)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) => v.toInt() < rows.length ? Padding(padding: const EdgeInsets.only(top: 6), child: Text(shortFocus(rows[v.toInt()].focusArea), maxLines: 1, style: mktText(9.5, color: Mkt.inkSoft))) : const SizedBox.shrink())),
                ),
                barGroups: [
                  for (var i = 0; i < rows.length; i++)
                    BarChartGroupData(x: i, barRods: [BarChartRodData(toY: (rows[i].progress ?? 0).toDouble(), color: rows[i].progress == null ? Colors.transparent : Mkt.primaryLight, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(5)))]),
                ],
              )),
            ),
    );
  }
}

FlLine _grid(double v) => const FlLine(color: Mkt.border, strokeWidth: 1);

Color _updateColor(String kind) => switch (kind) {
      'task_done' => Mkt.good,
      'roadmap_done' => Mkt.primary,
      'review' => Mkt.warn,
      'finding' => Mkt.blue,
      _ => Mkt.primaryLight,
    };

class _RecentUpdates extends StatelessWidget {
  const _RecentUpdates({required this.o});
  final StrategyOverview o;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String when(DateTime? d) {
      if (d == null) return '';
      final today = d.year == now.year && d.month == now.month && d.day == now.day;
      return today ? DateFormat('h:mm a').format(d) : DateFormat('d MMM').format(d);
    }

    return MktCard(
      title: 'Recent Updates',
      icon: Icons.history_rounded,
      child: o.updates.isEmpty
          ? const MktEmpty('Nothing has changed in this period.', icon: Icons.history_rounded, height: 150)
          : MktTimeline(items: [
              for (final (i, u) in o.updates.take(6).indexed)
                MktTimelineItem(key: Key('st_update_$i'), time: when(u.at), title: u.text, subtitle: [if (u.subtitle.isNotEmpty) u.subtitle, if (u.by.isNotEmpty) u.by].join(' · '), color: _updateColor(u.kind)),
            ]),
    );
  }
}

class _ResearchCards extends StatelessWidget {
  const _ResearchCards({required this.o, required this.onOpen});
  final StrategyOverview o;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Research & Insights',
        icon: Icons.insights_rounded,
        link: 'View All',
        linkKey: const Key('st_link_research'),
        onLink: () => onOpen('research'),
        child: o.research.isEmpty
            ? const MktEmpty('No findings in this period. Members add them in Research & Insights.', icon: Icons.insights_rounded, height: 150)
            : Column(children: [
                for (final f in o.research)
                  InkWell(
                    key: Key('st_ov_find_${f.id}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: f.link.isEmpty ? () => onOpen('research') : () => launchUrl(Uri.parse(f.link), mode: LaunchMode.externalApplication),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: Mkt.tint(findingColor(f.kind), 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(findingIcon(f.kind), size: 20, color: findingColor(f.kind))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700)),
                            Text('${findingKindLabel(f.kind)} · ${strategyDay(f.date, pattern: 'd MMM')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ]),
      );
}

class _KeyOutcomesCard extends StatelessWidget {
  const _KeyOutcomesCard({required this.o, required this.onOpen});
  final StrategyOverview o;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final k = o.keyOutcomes;
    return MktCard(
      title: 'Key Outcomes',
      subtitle: k == null ? null : '${reviewTypeLabel(k.type)} · ${k.periodLabel}',
      icon: Icons.verified_outlined,
      link: 'View All',
      linkKey: const Key('st_link_reviews'),
      onLink: () => onOpen('reviews'),
      child: k == null || k.outcomes.isEmpty
          ? const MktEmpty('No review yet. Add one in Reviews and its outcomes show here.', icon: Icons.verified_outlined, height: 150)
          : Column(children: [
              for (final (i, out) in k.outcomes.take(6).indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(outcomeIcon(out.state), key: Key('st_outcome_$i'), size: 16, color: outcomeColor(out.state)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(out.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12))),
                  ]),
                ),
            ]),
    );
  }
}

/// Used by the Overview's table rows and the Initiatives / Projects tabs to open one record.
void openWork(BuildContext context, WidgetRef ref, WorkItem item) => showWorkDetail(context, ref, kind: item.kind, id: item.id);
