import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/strategy_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_editors.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_exports.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_work_tab.dart';
import 'package:nizan_crm/features/marketing/services/strategy_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart' show teamFilterProvider;

/// Strategies & Developments → Roadmap: the year's strategy two ways. Quarterly: the four quarters with the milestones members TICK OFF.
/// Timeline: a bar for every initiative and development project from its start to its end day, with its progress (counted from its tasks)
/// on the bar.
class StrategyRoadmapTab extends ConsumerWidget {
  const StrategyRoadmapTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(strategyRoadmapProvider);
    final view = ref.watch(roadmapViewProvider);
    final setup = strategySetupOf(ref);
    // choosing another date range or brand goes back to the year of the range (the year stepper is only a detour from it)
    ref.listen(teamFilterProvider, (_, _) => ref.read(roadmapYearProvider.notifier).state = null);
    return RefreshIndicator(
      onRefresh: () async => refreshStrategies(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshStrategies(ref))]),
        data: (d) => ListView(
          key: const Key('strategies_roadmap_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _Toolbar(d: d, view: view, setup: setup),
            const SizedBox(height: 12),
            if (view == 'timeline') _Timeline(d: d) else _Quarters(d: d, setup: setup),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.d, required this.view, required this.setup});
  final RoadmapData d;
  final String view;
  final StrategySetup setup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void year(int y) => ref.read(roadmapYearProvider.notifier).state = y;
    return MktCard(
      title: 'Roadmap ${d.year}',
      subtitle: d.items == 0 ? 'No milestones planned yet' : '${d.done} of ${d.items} milestones done${d.pct == null ? '' : ' (${d.pct}%)'}',
      icon: Icons.alt_route_rounded,
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        MktFilterChip(key: const Key('st_rm_view_timeline'), label: 'Timeline', selected: view == 'timeline', onTap: () => ref.read(roadmapViewProvider.notifier).state = 'timeline'),
        MktFilterChip(key: const Key('st_rm_view_quarterly'), label: 'Quarterly', selected: view == 'quarterly', onTap: () => ref.read(roadmapViewProvider.notifier).state = 'quarterly'),
        const SizedBox(width: 8),
        IconButton(key: const Key('st_rm_prev'), tooltip: 'Earlier year', visualDensity: VisualDensity.compact, onPressed: () => year(d.year - 1), icon: const Icon(Icons.chevron_left_rounded)),
        Text('${d.year}', key: const Key('st_rm_year'), style: mktText(14, weight: FontWeight.w800)),
        IconButton(key: const Key('st_rm_next'), tooltip: 'Later year', visualDensity: VisualDensity.compact, onPressed: () => year(d.year + 1), icon: const Icon(Icons.chevron_right_rounded)),
        TextButton.icon(
          key: const Key('st_rm_export'),
          onPressed: () => downloadCsv('roadmap-${d.year}.csv', roadmapCsv(d)),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Export'),
        ),
        if (setup.canManage) TextButton.icon(key: const Key('st_rm_add'), onPressed: () => showRoadmapEditor(context, ref, year: d.year), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add milestone')),
      ]),
    );
  }
}

// ── timeline ─────────────────────────────────────────────────────────────────

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.d});
  final RoadmapData d;

  static const _labelW = 170.0;
  static const _minChart = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = [for (var m = 1; m <= 12; m++) DateFormat('MMM').format(DateTime(2000, m))];
    final now = DateTime.now();
    final todayFrac = now.year == d.year ? (DateTime(now.year, now.month, now.day).difference(DateTime(now.year)).inDays + 0.5) / (DateTime(now.year + 1).difference(DateTime(now.year)).inDays) : null;
    return MktCard(
      title: 'Timeline',
      subtitle: 'Each bar runs from the start day to the end day; the % is counted from its tasks',
      icon: Icons.timeline_rounded,
      child: d.bars.isEmpty && d.undated.isEmpty
          ? const MktEmpty('No initiative or development project runs in this year yet.', icon: Icons.timeline_rounded, height: 160)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (d.bars.isNotEmpty)
                LayoutBuilder(builder: (context, box) {
                  final chartW = math.max(box.maxWidth - _labelW, _minChart);
                  final total = _labelW + chartW;
                  Widget row(TimelineBar b) => SizedBox(
                        height: 42,
                        child: Row(children: [
                          SizedBox(
                            width: _labelW,
                            child: InkWell(
                              key: Key('st_tl_label_${b.id}'),
                              onTap: () => showWorkDetail(context, ref, kind: b.kind, id: b.id),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Row(children: [
                                  Icon(b.kind == 'project' ? Icons.layers_outlined : Icons.flag_outlined, size: 15, color: Mkt.primary),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11.5, weight: FontWeight.w700))),
                                ]),
                              ),
                            ),
                          ),
                          SizedBox(width: chartW, child: _BarCell(bar: b, width: chartW, todayFrac: todayFrac)),
                        ]),
                      );
                  final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const SizedBox(width: _labelW),
                      for (final m in months) SizedBox(width: chartW / 12, child: Text(m, textAlign: TextAlign.center, style: mktText(10.5, weight: FontWeight.w700, color: Mkt.inkSoft))),
                    ]),
                    const SizedBox(height: 4),
                    for (final b in d.bars) row(b),
                  ]);
                  return box.maxWidth >= total ? body : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: total, child: body));
                }),
              if (d.undated.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('No end date yet — not drawn', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.inkSoft)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final u in d.undated) ActionChip(key: Key('st_tl_undated_${u.id}'), label: Text(u.title, style: mktText(11)), visualDensity: VisualDensity.compact, onPressed: () => showWorkDetail(context, ref, kind: u.kind, id: u.id))]),
              ],
            ]),
    );
  }
}

class _BarCell extends ConsumerWidget {
  const _BarCell({required this.bar, required this.width, required this.todayFrac});
  final TimelineBar bar;
  final double width;
  final double? todayFrac;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = workStatusColor(bar.status);
    final w = math.max((bar.to - bar.from) * width, 30.0);
    final left = math.min(bar.from * width, width - w);
    final tip = '${bar.title}\n${strategyDay(bar.start, pattern: 'd MMM yyyy')} → ${strategyDay(bar.end, pattern: 'd MMM yyyy')}${bar.owner.isEmpty ? '' : '\n${bar.owner}'}';
    return Stack(children: [
      Row(children: [for (var m = 0; m < 12; m++) Expanded(child: Container(decoration: const BoxDecoration(border: Border(left: BorderSide(color: Mkt.border)))))]),
      if (todayFrac != null) Positioned(left: todayFrac! * width, top: 0, bottom: 0, child: Container(key: const Key('st_tl_today'), width: 1.5, color: Mkt.bad.withValues(alpha: 0.6))),
      Positioned(
        left: left,
        width: w,
        top: 8,
        height: 26,
        child: Tooltip(
          message: tip,
          child: GestureDetector(
            key: Key('st_tl_bar_${bar.id}'),
            onTap: () => showWorkDetail(context, ref, kind: bar.kind, id: bar.id),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Container(
                color: Mkt.tint(color, 0.18),
                child: Stack(children: [
                  if (bar.progressSource != 'none') FractionallySizedBox(widthFactor: (bar.progress.clamp(0, 100)) / 100, child: Container(color: Mkt.tint(color, 0.4))),
                  Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(bar.progressSource == 'none' ? '—' : '${bar.progress}%', key: Key('st_tl_pct_${bar.id}'), maxLines: 1, style: mktText(10.5, weight: FontWeight.w800, color: color)))),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── quarterly ────────────────────────────────────────────────────────────────

class _Quarters extends StatelessWidget {
  const _Quarters({required this.d, required this.setup});
  final RoadmapData d;
  final StrategySetup setup;

  @override
  Widget build(BuildContext context) {
    final quarters = d.quarters.isEmpty ? [for (var q = 1; q <= 4; q++) RoadmapQuarter(quarter: q, label: 'Q$q')] : d.quarters;
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 1000 ? 4 : (box.maxWidth >= 640 ? 2 : 1);
      const gap = 12.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final q in quarters) SizedBox(width: w, child: _QuarterCard(q: q, year: d.year, setup: setup))]);
    });
  }
}

class _QuarterCard extends ConsumerWidget {
  const _QuarterCard({required this.q, required this.year, required this.setup});
  final RoadmapQuarter q;
  final int year;
  final StrategySetup setup;

  Future<void> _tick(BuildContext context, WidgetRef ref, RoadmapLine it, bool done) async {
    try {
      await ref.read(marketingStrategyServiceProvider).tickRoadmapLine(it.id, done: done);
      refreshStrategies(ref);
    } on TeamRefusal catch (r) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, RoadmapLine it) async {
    final yes = await confirmStrategyDelete(context, title: 'Delete this roadmap line?', body: '"${it.title}" is removed from Q${it.quarter} ${it.year}.');
    if (!yes) return;
    try {
      await ref.read(marketingStrategyServiceProvider).deleteRoadmapLine(it.id);
      refreshStrategies(ref);
    } on TeamRefusal catch (r) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canTick = setup.canManage || setup.meId != null;
    return MktCard(
      key: Key('st_rm_q${q.quarter}'),
      title: '${q.label}${q.theme.isEmpty ? '' : ' · ${q.theme}'}',
      subtitle: q.months,
      icon: Icons.flag_circle_outlined,
      iconColor: Mkt.series(q.quarter - 1),
      trailing: setup.canManage ? IconButton(key: Key('st_rm_add_q${q.quarter}'), tooltip: 'Add a milestone to ${q.label}', visualDensity: VisualDensity.compact, onPressed: () => showRoadmapEditor(context, ref, year: year, quarter: q.quarter, theme: q.theme), icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Mkt.primary)) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MktProgress(pct: q.pct ?? 0, color: Mkt.series(q.quarter - 1), labelWidth: 40),
        Text(q.total == 0 ? 'Nothing planned' : '${q.done} of ${q.total} done', key: Key('st_rm_count_q${q.quarter}'), style: mktText(10.5, color: Mkt.inkSoft)),
        const SizedBox(height: 6),
        for (final it in q.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 30, height: 30, child: Checkbox(key: Key('st_rm_tick_${it.id}'), value: it.done, visualDensity: VisualDensity.compact, onChanged: canTick ? (v) => _tick(context, ref, it, v ?? false) : null)),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w600, color: it.done ? Mkt.inkSoft : Mkt.ink).copyWith(decoration: it.done ? TextDecoration.lineThrough : null)),
                    if (it.link.isNotEmpty || it.done)
                      Text([if (it.link.isNotEmpty) it.link, if (it.done) 'Done${it.doneBy.isEmpty ? '' : ' by ${it.doneBy}'}${it.doneAt == null ? '' : ' · ${DateFormat('d MMM').format(it.doneAt!)}'}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, color: Mkt.inkSoft)),
                  ]),
                ),
              ),
              if (setup.canManage)
                PopupMenuButton<String>(
                  key: Key('st_rm_menu_${it.id}'),
                  tooltip: '',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Mkt.inkSoft),
                  onSelected: (v) => v == 'edit' ? showRoadmapEditor(context, ref, line: it) : _delete(context, ref, it),
                  itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                ),
            ]),
          ),
      ]),
    );
  }
}
