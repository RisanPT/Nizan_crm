import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/strategy_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_editors.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_exports.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_widgets.dart';
import 'package:nizan_crm/features/marketing/services/strategy_service.dart';

/// Strategies & Developments → Strategic Plans: define, manage and track business and marketing strategies. A plan is a strategy for a
/// focus area and a year with its goals; plans are counted by status (managers keep them). The work that serves a plan — its initiatives
/// and projects — has its progress counted from its tasks.
class StrategicPlansTab extends ConsumerWidget {
  const StrategicPlansTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(strategyPlansProvider);
    final setup = strategySetupOf(ref);
    return RefreshIndicator(
      onRefresh: () async => refreshStrategies(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshStrategies(ref))]),
        data: (d) {
          final c = d.counts;
          return ListView(
            key: const Key('strategies_plans_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 180, children: [
                MktKpiCard(key: const Key('pl_kpi_active'), icon: Icons.groups_2_outlined, value: '${c.active}', label: 'Active Plans', tint: Mkt.primary),
                MktKpiCard(key: const Key('pl_kpi_progress'), icon: Icons.sync_rounded, value: '${c.inProgress}', label: 'In Progress', tint: Mkt.warn),
                MktKpiCard(key: const Key('pl_kpi_hold'), icon: Icons.pause_circle_outline_rounded, value: '${c.onHold}', label: 'On Hold', tint: Mkt.bad),
                MktKpiCard(key: const Key('pl_kpi_completed'), icon: Icons.check_circle_outline_rounded, value: '${c.completed}', label: 'Completed', tint: Mkt.good),
              ]),
              const SizedBox(height: 12),
              MktGrid(breakpoint: 980, rows: [
                [(4, _FocusList(d: d)), (4, _PlanProgress(d: d)), (4, _Goals(d: d))],
                [(12, _PlanTable(d: d, setup: setup))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _FocusList extends StatelessWidget {
  const _FocusList({required this.d});
  final PlansData d;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Strategic Focus Areas',
        subtitle: 'Live plans (active or in progress) per focus area',
        icon: Icons.donut_large_rounded,
        child: d.focus.isEmpty
            ? const MktEmpty('No live plan yet. A manager adds one with New Plan.', icon: Icons.donut_large_rounded, height: 170)
            : Column(children: [
                for (final (i, f) in d.focus.indexed)
                  Container(
                    key: Key('pl_focus_${f.focusArea}'),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(color: Mkt.tint(Mkt.series(i), 0.08), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: Mkt.series(i), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f.focusArea, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700))),
                      Text('${f.count}', style: mktText(12.5, weight: FontWeight.w800)),
                    ]),
                  ),
              ]),
      );
}

class _PlanProgress extends StatelessWidget {
  const _PlanProgress({required this.d});
  final PlansData d;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Plan Progress',
        subtitle: 'All plans by status',
        icon: Icons.pie_chart_outline_rounded,
        child: d.progressTotal == 0
            ? const MktEmpty('No plan in this period.', icon: Icons.pie_chart_outline_rounded, height: 170)
            : MktDonut(
                centerKey: const Key('pl_total'),
                centerValue: '${d.progressTotal}',
                centerLabel: 'Total Plans',
                size: 120,
                sideBySideFrom: 300,
                colors: [for (final s in d.slices) planStatusColor(s.key)],
                slices: [for (final s in d.slices) (label: s.label, value: s.count.toDouble(), trailing: '${s.count} · ${s.pct}%')],
              ),
      );
}

class _Goals extends StatelessWidget {
  const _Goals({required this.d});
  final PlansData d;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Key Strategic Goals',
        subtitle: 'The goals of the live plans',
        icon: Icons.emoji_events_outlined,
        child: d.goals.isEmpty
            ? const MktEmpty('Goals show here once a live plan lists them.', icon: Icons.emoji_events_outlined, height: 170)
            : Column(children: [
                for (final (i, g) in d.goals.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.flag_circle_outlined, size: 17, color: Mkt.good),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(g.text, key: Key('pl_goal_$i'), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w600)),
                          Text(g.plan, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
      );
}

class _PlanTable extends ConsumerWidget {
  const _PlanTable({required this.d, required this.setup});
  final PlansData d;
  final StrategySetup setup;

  Future<void> _delete(BuildContext context, WidgetRef ref, PlanItem p) async {
    final yes = await confirmStrategyDelete(context, title: 'Delete this plan?', body: '"${p.title}" is removed. Its initiatives, projects and roadmap lines stay, no longer linked to a plan.');
    if (!yes) return;
    try {
      await ref.read(marketingStrategyServiceProvider).deletePlan(p.id);
      refreshStrategies(ref);
    } on TeamRefusal catch (r) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => MktCard(
        title: 'Strategic Plans',
        icon: Icons.layers_outlined,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              TextButton.icon(
                key: const Key('pl_export'),
                onPressed: () => downloadCsv('strategic-plans.csv', plansCsv(d.items)),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export'),
              ),
              if (setup.canManage) TextButton(key: const Key('pl_new'), onPressed: () => showPlanEditor(context, ref), child: Text('+ New Strategic Plan', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.primary))),
            ]),
          ),
          if (d.items.isEmpty)
            MktEmpty(setup.canManage ? 'No strategic plan in this period. Use New Strategic Plan.' : 'No strategic plan in this period. A Marketing Manager adds them.', icon: Icons.layers_outlined, height: 130)
          else
            MktTable(
                minWidth: 760,
                rowHeight: 54,
                columns: [const MktCol('Plan', flex: 5), const MktCol('Focus Area', flex: 3), const MktCol('Year', flex: 1), const MktCol('Owner', flex: 3), const MktCol('Linked work', flex: 3), const MktCol('Status', flex: 3), if (setup.canManage) const MktCol('', width: 84)],
                rowKeys: [for (final p in d.items) Key('pl_row_${p.id}')],
                rows: [
                  for (final p in d.items)
                    [
                      Padding(padding: const EdgeInsets.only(right: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700)), if (p.goals.isNotEmpty) Text('${p.goals.length} ${p.goals.length == 1 ? 'goal' : 'goals'}', style: mktText(10, color: Mkt.inkSoft))])),
                      Padding(padding: const EdgeInsets.only(right: 6), child: MktChip(p.focusArea, color: Mkt.primaryLight)),
                      Text('${p.year}', style: mktText(11.5)),
                      Padding(padding: const EdgeInsets.only(right: 6), child: p.ownerName.isEmpty ? Text('—', style: mktText(12, color: Mkt.inkSoft)) : Row(mainAxisSize: MainAxisSize.min, children: [MktAvatar(p.ownerName, size: 22), const SizedBox(width: 6), Flexible(child: Text(p.ownerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12)))])),
                      Text('${p.initiativeCount} init. · ${p.projectCount} proj.', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5)),
                      MktChip(planStatusLabel(p.status), color: planStatusColor(p.status)),
                      if (setup.canManage)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(key: Key('pl_edit_${p.id}'), tooltip: 'Edit', visualDensity: VisualDensity.compact, onPressed: () => showPlanEditor(context, ref, plan: p), icon: const Icon(Icons.edit_outlined, size: 18)),
                          IconButton(key: Key('pl_delete_${p.id}'), tooltip: 'Delete', visualDensity: VisualDensity.compact, onPressed: () => _delete(context, ref, p), icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Mkt.bad)),
                        ]),
                    ],
                ],
              ),
        ]),
      );
}