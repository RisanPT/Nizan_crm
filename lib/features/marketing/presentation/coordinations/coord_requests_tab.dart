import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/request_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Coordinations → Requests & Tasks: My Tasks, Team Tasks and All as a table (request, who asked, teams, priority, due, status), with the
/// same strip the Overview counts from. Create, change, move or delete a request here. The Team Dashboard's tasks are in the table too
/// (one task record, read by both screens): marked "Team task", moved through their own statuses, and edited on the Team Dashboard.
class CoordRequestsTab extends ConsumerWidget {
  const CoordRequestsTab({super.key});

  void _set(WidgetRef ref, RequestQuery q) => ref.read(coordRequestQueryProvider.notifier).state = q;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coordRequestsProvider);
    final q = ref.watch(coordRequestQueryProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCoordinations(ref),
      child: async.when(
        loading: coordLoading,
        error: (e, _) => coordError(e, ref),
        data: (d) {
          final k = d.kpis;
          void filter(String status) => _set(ref, q.copyWith(status: status, page: 1));
          return ListView(
            key: const Key('coord_requests_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 165, children: [
                coordKpi(keyName: 'co_rq_kpi_total', icon: Icons.assignment_outlined, value: '${k.total}', label: 'Total Requests', tint: Mkt.primary, onTap: () => filter('all')),
                coordKpi(keyName: 'co_rq_kpi_progress', icon: Icons.sync_rounded, value: '${k.inProgress}', label: 'In Progress', tint: Mkt.blue, onTap: () => filter('in_progress')),
                coordKpi(keyName: 'co_rq_kpi_pending', icon: Icons.hourglass_empty_rounded, value: '${k.pending}', label: 'Pending', tint: Mkt.warn, onTap: () => filter('pending')),
                coordKpi(keyName: 'co_rq_kpi_overdue', icon: Icons.error_outline_rounded, value: '${k.overdue}', label: 'Overdue', tint: Mkt.bad, onTap: () => filter('overdue')),
                coordKpi(keyName: 'co_rq_kpi_completed', icon: Icons.check_circle_outline_rounded, value: '${k.completed}', label: 'Completed', tint: Mkt.good, onTap: () => filter('completed')),
              ]),
              const SizedBox(height: 12),
              MktCard(
                title: 'Requests & Tasks',
                subtitle: d.teamTasks > 0 ? 'With ${d.teamTasks} Team Dashboard task${d.teamTasks == 1 ? '' : 's'} (the strip above counts requests only)' : null,
                icon: Icons.assignment_outlined,
                trailing: const ExportButton(type: 'requests'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final t in [('my', 'My Tasks'), ('team', 'Team Tasks'), ('all', 'All')])
                        Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('co_rq_scope_${t.$1}'), label: t.$2, count: d.tabCounts.of(t.$1), selected: q.scope == t.$1, onTap: () => _set(ref, q.copyWith(scope: t.$1, page: 1)))),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SizedBox(width: 240, child: CoordSearchField(fieldKey: const Key('co_rq_search'), initial: q.q, hint: 'Search requests, people, teams…', onChanged: (v) => _set(ref, ref.read(coordRequestQueryProvider).copyWith(q: v, page: 1)))),
                    KeyedSubtree(key: const Key('co_rq_priority_pill'), child: MktDropdownPill<String>(value: q.priority, icon: Icons.flag_outlined, options: [('all', 'All priorities'), for (final p in kPriorities) (p.$1, p.$2)], onChanged: (v) => _set(ref, q.copyWith(priority: v, page: 1)))),
                    KeyedSubtree(key: const Key('co_rq_status_pill'), child: MktDropdownPill<String>(value: q.status, icon: Icons.filter_alt_outlined, options: [('all', 'All statuses'), ('pending', 'Pending (not started or waiting)'), ('overdue', 'Overdue'), for (final s in kRequestStatuses) (s.$1, s.$2)], onChanged: (v) => _set(ref, q.copyWith(status: v, page: 1)))),
                  ]),
                  const SizedBox(height: 8),
                  if (d.items.isEmpty)
                    MktEmpty(d.tabCounts.all == 0 ? 'No requests in this period. Use New Request to log one.' : 'No request matches these filters.', icon: Icons.assignment_outlined, height: 140)
                  else
                    MktTable(
                      minWidth: 820,
                      columns: const [MktCol('Request / Task', flex: 5), MktCol('Requested By', flex: 3), MktCol('Department', flex: 3), MktCol('Priority', flex: 2), MktCol('Due Date', flex: 2), MktCol('Status', flex: 3), MktCol('', width: 36)],
                      rowKeys: [for (final r in d.items) Key('co_row_${r.id}')],
                      onRowTap: (i) => openRequest(context, ref, d.items[i]),
                      rows: [for (final r in d.items) _cells(context, ref, r)],
                    ),
                  const SizedBox(height: 6),
                  CoordPager(keyPrefix: 'co_rq', total: d.total, page: d.page, pageSize: d.pageSize, shown: d.items.length, onPage: (p) => _set(ref, q.copyWith(page: p))),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _cells(BuildContext context, WidgetRef ref, CoordRequestRow r) => [
        Row(children: [
          Flexible(child: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w600))),
          if (r.isHandover) const Padding(padding: EdgeInsets.only(left: 6), child: MktChip('Handover', color: Mkt.primaryLight)),
          if (r.isTask) const Padding(padding: EdgeInsets.only(left: 6), child: kTeamTaskChip),
        ]),
        PersonCell(r.requestedBy),
        FromTo(r.fromDept, r.toDept),
        MktChip(priorityLabel(r.priority), color: priorityColor(r.priority)),
        DueText(r.dueDate, overdue: r.overdue),
        MktChip(rowStatusLabel(r), color: requestStatusColor(r.status)),
        RequestMenu(request: r),
      ];
}

/// The chip a Team Dashboard task carries in the Coordinations table.
const kTeamTaskChip = MktChip('Team task', color: Mkt.teal, icon: Icons.groups_2_outlined);

/// A row's "⋮": change it, move it to another status, or delete it — only what the person may do.
class RequestMenu extends ConsumerWidget {
  const RequestMenu({super.key, required this.request});
  final CoordRequestRow request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    if (r.isTask) return _TaskRowMenu(row: r);
    if (!r.canEdit && !r.canDelete) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      key: Key('co_menu_${r.id}'),
      tooltip: 'Actions',
      padding: EdgeInsets.zero,
      iconSize: 18,
      onSelected: (v) async {
        if (v == 'edit') {
          await showRequestEditor(context, ref, request: r);
        } else if (v == 'delete') {
          final yes = await confirmCoord(context, title: 'Delete this request?', body: '"${r.title}" is removed. Cancel it instead if you want the record to stay.', confirmLabel: 'Delete', confirmKey: const Key('co_delete_confirm'));
          if (yes && context.mounted) await coordQuickWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).deleteRequest(r.id));
        } else if (v.startsWith('status:')) {
          await coordQuickWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).saveRequest({'status': v.substring(7)}, id: r.id));
        }
      },
      itemBuilder: (_) => [
        if (r.canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (r.canEdit)
          for (final s in r.nextStatuses) PopupMenuItem(value: 'status:$s', child: Text('Mark ${requestStatusLabel(s)}')),
        if (r.canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Mkt.bad))),
      ],
    );
  }
}

/// A Team Dashboard task's "⋮" in the Coordinations table: move it through its own statuses (it is the same record the Team Dashboard
/// counts, so closing it here closes it there), or open it on the Team Dashboard to change anything else.
class _TaskRowMenu extends ConsumerWidget {
  const _TaskRowMenu({required this.row});
  final CoordRequestRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
        key: Key('co_menu_${row.id}'),
        tooltip: 'Actions',
        padding: EdgeInsets.zero,
        iconSize: 18,
        onSelected: (v) async {
          if (v == 'open') {
            GoRouter.maybeOf(context)?.go(row.link ?? '/marketing/team?tab=tasks');
          } else if (v.startsWith('status:')) {
            await setTeamTaskStatus(context, ref, row, v.substring(7));
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'open', child: Text('Open in Team Dashboard')),
          if (row.canEdit)
            for (final s in row.taskStatuses) PopupMenuItem(value: 'status:$s', child: Text('Mark ${kTeamTaskStatusLabels[s] ?? s}')),
        ],
      );
}

/// Move a team task to [status] through the Team Dashboard's own endpoint; both screens are read again.
Future<bool> setTeamTaskStatus(BuildContext context, WidgetRef ref, CoordRequestRow row, String status) async {
  final ok = await coordQuickWrite(context, ref, () => ref.read(marketingTeamServiceProvider).saveTask({'status': status}, id: row.id));
  if (ok) refreshTeam(ref);
  return ok;
}

