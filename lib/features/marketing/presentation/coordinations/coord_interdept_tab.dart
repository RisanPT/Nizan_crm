import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/request_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';

/// Coordinations → Inter-Department: the handover board by stage (Requested, In Progress, In Review, Completed) with a move-stage action
/// on every card, and the strip of active, awaiting-action, in-review, overdue and completed handovers.
class CoordInterDeptTab extends ConsumerWidget {
  const CoordInterDeptTab({super.key});

  static const _tints = {'requested': Mkt.blue, 'in_progress': Mkt.primaryLight, 'in_review': Mkt.warn, 'completed': Mkt.good};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coordBoardProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCoordinations(ref),
      child: async.when(
        loading: coordLoading,
        error: (e, _) => coordError(e, ref),
        data: (b) {
          final k = b.kpis;
          return ListView(
            key: const Key('coord_board_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 165, children: [
                coordKpi(keyName: 'co_ib_kpi_active', icon: Icons.arrow_forward_rounded, value: '${k.active}', label: 'Active Handover', tint: Mkt.primary),
                coordKpi(keyName: 'co_ib_kpi_awaiting', icon: Icons.schedule_rounded, value: '${k.awaitingAction}', label: 'Awaiting Action', tint: Mkt.warn),
                coordKpi(keyName: 'co_ib_kpi_review', icon: Icons.search_rounded, value: '${k.inReview}', label: 'In Review', tint: Mkt.blue),
                coordKpi(keyName: 'co_ib_kpi_overdue', icon: Icons.error_outline_rounded, value: '${k.overdue}', label: 'Overdue', tint: Mkt.bad),
                coordKpi(keyName: 'co_ib_kpi_completed', icon: Icons.check_rounded, value: '${k.completed}', label: 'Completed', tint: Mkt.good),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
                const ExportButton(type: 'requests', extra: {'kind': 'handover'}),
                MktPrimaryButton(key: const Key('co_ib_new'), label: 'New Handover', onPressed: () => showRequestEditor(context, ref, kind: 'handover')),
              ]),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, box) {
                final cols = [for (final s in b.stages) _Column(stage: s, tint: _tints[s.key] ?? Mkt.grey)];
                if (cols.isEmpty) return const MktCard(title: 'Handovers', icon: Icons.swap_horiz_rounded, child: MktEmpty('No handovers between teams in this period. Use New Handover.', icon: Icons.swap_horiz_rounded, height: 140));
                if (box.maxWidth >= 900) {
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 0; i < cols.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: cols[i])]]);
                }
                return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final c in cols) Padding(padding: const EdgeInsets.only(right: 10), child: SizedBox(width: 270, child: c))]));
              }),
            ],
          );
        },
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.stage, required this.tint});
  final BoardStage stage;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        key: Key('co_stage_${stage.key}'),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Mkt.tint(tint, 0.10), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 2, 4, 8), child: Text('${stage.label} (${stage.count})', key: Key('co_stage_title_${stage.key}'), style: mktText(13, weight: FontWeight.w800))),
          if (stage.items.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('Nothing here', style: mktText(11.5, color: Mkt.inkSoft)))),
          for (final r in stage.items) HandoverCard(request: r, stage: stage.key),
        ]),
      );
}

/// One handover on the board: title, the two teams, due (or completed) day, progress, and the menu to move it on.
class HandoverCard extends ConsumerWidget {
  const HandoverCard({super.key, required this.request, required this.stage});
  final CoordRequestRow request;
  final String stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final done = stage == 'completed';
    final due = done ? 'Completed: ${coordDay(r.closedAt == null ? null : todayDay(r.closedAt!), pattern: 'd MMM')}' : 'Due: ${dueLabel(r.dueDate)}';
    final hot = !done && (r.overdue || dueLabel(r.dueDate) == 'Today');
    return Container(
      key: Key('co_card_${r.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Mkt.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openRequest(context, ref, r),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w800))),
              if (r.moveTo.isNotEmpty || r.canEdit) _MoveMenu(request: r),
            ]),
            const SizedBox(height: 3),
            FromTo(r.fromDept, r.toDept),
            const SizedBox(height: 4),
            Row(children: [
              Icon(done ? Icons.check_circle_rounded : Icons.event_outlined, size: 12, color: done ? Mkt.good : (hot ? Mkt.bad : Mkt.inkSoft)),
              const SizedBox(width: 4),
              Flexible(child: Text(due, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, weight: hot || done ? FontWeight.w700 : FontWeight.w500, color: done ? Mkt.good : (hot ? Mkt.bad : Mkt.inkSoft)))),
            ]),
            if (!done) Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: MktProgress(pct: r.progress, color: Mkt.primaryLight, height: 5, labelWidth: 34)),
            if (r.assignee.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: PersonCell(r.assignee)),
          ]),
        ),
      ),
    );
  }
}

class _MoveMenu extends ConsumerWidget {
  const _MoveMenu({required this.request});
  final CoordRequestRow request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    return PopupMenuButton<String>(
      key: Key('co_move_${r.id}'),
      tooltip: 'Move to another stage',
      padding: EdgeInsets.zero,
      iconSize: 18,
      onSelected: (v) async {
        if (v == 'edit') {
          await showRequestEditor(context, ref, request: r);
        } else if (v.startsWith('move:')) {
          await coordQuickWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).moveRequest(r.id, v.substring(5)));
        }
      },
      itemBuilder: (_) => [
        for (final s in r.moveTo) PopupMenuItem(value: 'move:$s', child: Text('Move to ${stageLabel(s)}')),
        if (r.canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
      ],
    );
  }
}
