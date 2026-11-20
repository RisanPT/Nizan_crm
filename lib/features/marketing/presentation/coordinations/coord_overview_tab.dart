import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/request_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';

/// Coordinations → Overview: the six headline numbers, the task table, the request split by team, recent requests, inter-department
/// coordination, what is waiting for approval and review, what is coming up, and plain key updates — all read from the records people log.
class CoordOverviewTab extends ConsumerStatefulWidget {
  const CoordOverviewTab({super.key, required this.onOpenTab});

  /// Go to another Coordinations tab (the cards' "View All").
  final ValueChanged<String> onOpenTab;

  @override
  ConsumerState<CoordOverviewTab> createState() => _CoordOverviewTabState();
}

class _CoordOverviewTabState extends ConsumerState<CoordOverviewTab> {
  String _scope = 'my';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coordOverviewProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCoordinations(ref),
      child: async.when(
        loading: coordLoading,
        error: (e, _) => coordError(e, ref),
        data: (o) => ListView(
          key: const Key('coord_overview_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const Align(alignment: Alignment.centerRight, child: ExportButton(type: 'overview')),
            const SizedBox(height: 8),
            _Strip(o: o),
            const SizedBox(height: 12),
            MktGrid(breakpoint: 980, rows: [
              [(7, _tasksCard(o)), (5, _DepartmentCard(o: o))],
              [(6, _recentCard(o)), (6, _interCard(o))],
              [(6, _ApprovalsPendingCard(o: o, onOpenTab: widget.onOpenTab)), (3, _UpcomingCard(o: o)), (3, _KeyUpdatesCard(o: o))],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _tasksCard(CoordOverview o) {
    final rows = o.tasks[_scope] ?? const <CoordRequestRow>[];
    return MktCard(
      title: 'Coordination Tasks',
      icon: Icons.checklist_rtl_rounded,
      link: 'View All',
      linkKey: const Key('co_tasks_all_link'),
      onLink: () {
        ref.read(coordRequestQueryProvider.notifier).state = ref.read(coordRequestQueryProvider).copyWith(scope: _scope, page: 1);
        widget.onOpenTab('requests');
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final t in [('my', 'My Tasks'), ('all', 'All Tasks'), ('team', 'Team Tasks')])
              Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('co_tasks_${t.$1}'), label: t.$2, count: o.tabCounts.of(t.$1), selected: _scope == t.$1, onTap: () => setState(() => _scope = t.$1))),
          ]),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const MktEmpty('Nothing here yet. Use New Request to log one.', icon: Icons.assignment_outlined, height: 110)
        else
          MktTable(
            minWidth: 560,
            columns: const [MktCol('Task / Request', flex: 4), MktCol('Department', flex: 3), MktCol('Assignee', flex: 3), MktCol('Due Date', flex: 2), MktCol('Status', flex: 3)],
            rowKeys: [for (final r in rows) Key('co_task_${r.id}')],
            onRowTap: (i) => openRequest(context, ref, rows[i]),
            rows: [
              for (final r in rows)
                [
                  Row(children: [
                    Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: priorityColor(r.priority), shape: BoxShape.circle)),
                    Flexible(child: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w600))),
                    if (r.isTask) const Padding(padding: EdgeInsets.only(left: 6), child: MktChip('Team task', color: Mkt.teal)),
                  ]),
                  FromTo(r.fromDept, r.toDept),
                  PersonCell(r.assignee),
                  DueText(r.dueDate, overdue: r.overdue),
                  MktChip(rowStatusLabel(r), color: requestStatusColor(r.status)),
                ],
            ],
          ),
      ]),
    );
  }

  Widget _recentCard(CoordOverview o) => MktCard(
        title: 'Recent Coordination Requests',
        icon: Icons.send_outlined,
        link: 'View All',
        linkKey: const Key('co_recent_all_link'),
        onLink: () {
          ref.read(coordRequestQueryProvider.notifier).state = ref.read(coordRequestQueryProvider).copyWith(scope: 'all', page: 1);
          widget.onOpenTab('requests');
        },
        child: o.recent.isEmpty
            ? const MktEmpty('No requests in this period.', icon: Icons.send_outlined, height: 110)
            : Column(children: [
                for (final r in o.recent)
                  InkWell(
                    key: Key('co_recent_${r.id}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => openRequest(context, ref, r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        Container(width: 34, height: 34, decoration: BoxDecoration(color: Mkt.tint(requestStatusColor(r.status)), borderRadius: BorderRadius.circular(10)), child: Icon(r.isHandover ? Icons.swap_horiz_rounded : Icons.assignment_outlined, size: 18, color: requestStatusColor(r.status))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                            Row(children: [Flexible(child: FromTo(r.fromDept, r.toDept)), if (coordAgo(r.createdAt).isNotEmpty) Flexible(child: Text('  ·  ${coordAgo(r.createdAt)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)))]),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        MktChip(requestStatusLabel(r.status), color: requestStatusColor(r.status)),
                      ]),
                    ),
                  ),
              ]),
      );

  Widget _interCard(CoordOverview o) => MktCard(
        title: 'Inter-Department Coordinations',
        icon: Icons.account_tree_outlined,
        link: 'View All',
        linkKey: const Key('co_inter_all_link'),
        onLink: () => widget.onOpenTab('interdepartment'),
        child: o.interDepartment.isEmpty
            ? const MktEmpty('No handovers between teams yet. Use the Inter-Department tab.', icon: Icons.swap_horiz_rounded, height: 110)
            : Column(children: [
                for (final r in o.interDepartment)
                  InkWell(
                    key: Key('co_inter_${r.id}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => openRequest(context, ref, r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(flex: 3, child: FromTo(r.fromDept, r.toDept)),
                          const SizedBox(width: 8),
                          Flexible(flex: 4, child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 5),
                        MktProgress(pct: r.progress, color: r.status == 'completed' ? Mkt.good : Mkt.primaryLight),
                      ]),
                    ),
                  ),
              ]),
      );
}

// ── the strip ─────────────────────────────────────────────────────────────────

class _Strip extends StatelessWidget {
  const _Strip({required this.o});
  final CoordOverview o;

  @override
  Widget build(BuildContext context) {
    final k = o.kpis;
    final done = changeNote(o.changeCompleted);
    return MktKpiRow(minWidth: 165, children: [
      coordKpi(keyName: 'co_kpi_total', icon: Icons.assignment_outlined, value: '${k.total}', label: 'Total Requests', note: k.approvals > 0 ? '${k.requests} requests + ${k.approvals} approvals' : changeNote(o.changeTotal).note, tint: Mkt.primary),
      coordKpi(keyName: 'co_kpi_completed', icon: Icons.check_circle_outline_rounded, value: '${k.completed}', label: 'Completed', note: done.note, good: done.good, tint: Mkt.good),
      coordKpi(keyName: 'co_kpi_progress', icon: Icons.hourglass_bottom_rounded, value: '${k.inProgress}', label: 'In Progress', tint: Mkt.warn),
      coordKpi(keyName: 'co_kpi_approvals', icon: Icons.verified_outlined, value: '${k.pendingApprovals}', label: 'Pending Approvals', tint: Mkt.primaryLight),
      coordKpi(keyName: 'co_kpi_overdue', icon: Icons.error_outline_rounded, value: '${k.overdue}', label: 'Overdue', tint: Mkt.bad, good: k.overdue == 0 ? true : null, note: k.overdue == 0 ? 'Nothing overdue' : null),
      coordKpi(keyName: 'co_kpi_ontime', icon: Icons.bolt_rounded, value: k.onTimeRate == null ? '—' : '${k.onTimeRate}%', label: 'On-time Completion', tint: Mkt.blue, note: k.onTimeRate == null ? 'No due dates finished yet' : 'of ${k.onTimeOf} with a due date'),
    ]);
  }
}

// ── request by department ─────────────────────────────────────────────────────

class _DepartmentCard extends ConsumerWidget {
  const _DepartmentCard({required this.o});
  final CoordOverview o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = o.byDepartment;
    final options = ref.watch(coordOverviewOptionsProvider);
    return MktCard(
      title: 'Request by Department',
      icon: Icons.bar_chart_rounded,
      trailing: KeyedSubtree(
        key: const Key('co_by_pill'),
        child: MktDropdownPill<String>(value: options.by, options: const [('both', 'Both teams'), ('requesting', 'Requesting'), ('receiving', 'Receiving')], onChanged: (v) => ref.read(coordOverviewOptionsProvider.notifier).state = options.copyWith(by: v)),
      ),
      child: d.rows.isEmpty
          ? const MktEmpty('No requests in this period.', icon: Icons.donut_large_rounded, height: 150)
          : MktDonut(
              centerKey: const Key('co_dept_total'),
              centerValue: '${d.total}',
              centerLabel: 'Requests',
              colors: [for (final r in d.rows) deptColor(r.label)],
              slices: [for (final r in d.rows) (label: r.label, value: r.count.toDouble(), trailing: '${r.pct}% (${r.count})')],
            ),
    );
  }
}

// ── approvals pending ─────────────────────────────────────────────────────────

class _ApprovalsPendingCard extends ConsumerWidget {
  const _ApprovalsPendingCard({required this.o, required this.onOpenTab});
  final CoordOverview o;
  final ValueChanged<String> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = o.approvalsPending;
    final cards = <Widget>[
      for (final a in p.approvals.take(3))
        _PendingCard(
          key: Key('co_pending_${a.id}'),
          title: a.title,
          subtitle: '${a.category} · ${inr(a.amount)}',
          footer: a.requestedBy.isEmpty ? 'Approval' : 'Raised by ${a.requestedBy}',
          chip: MktChip(approvalStatusLabel(a.status), color: approvalStatusColor(a.status)),
          buttonKey: Key('co_pending_review_${a.id}'),
          onReview: () => onOpenTab('approvals'),
        ),
      for (final r in p.review.items.take(3))
        _PendingCard(
          key: Key('co_review_${r.id}'),
          title: r.title,
          subtitle: [r.label, if (r.brand == 'kerala') 'Kerala'].where((x) => x.isNotEmpty).join(' · '),
          footer: r.type == 'asset' ? 'Creative Portfolio' : 'Socials',
          thumbUrl: r.thumbUrl,
          chip: MktChip(r.type == 'asset' ? 'Asset in review' : 'Post in review', color: Mkt.primaryLight),
          buttonKey: Key('co_review_go_${r.id}'),
          onReview: () => GoRouter.maybeOf(context)?.go(r.link),
        ),
    ];
    return MktCard(
      title: 'Approvals Pending',
      icon: Icons.verified_outlined,
      link: 'View All',
      linkKey: const Key('co_approvals_all_link'),
      onLink: () => onOpenTab('approvals'),
      child: cards.isEmpty
          ? const MktEmpty('Nothing is waiting for a decision or a review.', icon: Icons.verified_outlined, height: 110)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final c in cards) Padding(padding: const EdgeInsets.only(right: 10), child: c)])),
              const SizedBox(height: 8),
              Text('${p.approvalCount} waiting for a decision · ${p.review.total} posts and assets in review', key: const Key('co_pending_note'), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
            ]),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({super.key, required this.title, required this.subtitle, required this.footer, required this.chip, required this.buttonKey, required this.onReview, this.thumbUrl = ''});
  final String title, subtitle, footer, thumbUrl;
  final Widget chip;
  final Key buttonKey;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(height: 64, color: Mkt.tint(Mkt.primary), alignment: Alignment.center, child: const Icon(Icons.image_outlined, color: Mkt.primary));
    return Container(
      width: 170,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Mkt.border), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (thumbUrl.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: 64, width: double.infinity, child: Image.network(thumbUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback, loadingBuilder: (_, child, p) => p == null ? child : fallback))),
        if (thumbUrl.isNotEmpty) const SizedBox(height: 6),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700)),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
        const SizedBox(height: 4),
        chip,
        const SizedBox(height: 2),
        Text(footer, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, color: Mkt.inkSoft)),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity, child: FilledButton(key: buttonKey, style: FilledButton.styleFrom(backgroundColor: Mkt.primary, minimumSize: const Size(0, 30), padding: EdgeInsets.zero), onPressed: onReview, child: const Text('Review'))),
      ]),
    );
  }
}

// ── upcoming ──────────────────────────────────────────────────────────────────

class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard({required this.o});
  final CoordOverview o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(coordOverviewOptionsProvider);
    return MktCard(
      title: 'Upcoming Coordinations',
      icon: Icons.schedule_rounded,
      trailing: KeyedSubtree(
        key: const Key('co_upcoming_pill'),
        child: MktDropdownPill<String>(value: options.upcoming, options: const [('today', 'Today'), ('week', 'This Week'), ('month', 'This Month')], onChanged: (v) => ref.read(coordOverviewOptionsProvider.notifier).state = options.copyWith(upcoming: v)),
      ),
      child: o.upcoming.isEmpty
          ? const MktEmpty('Nothing is scheduled or due in this period.', icon: Icons.event_available_outlined, height: 110)
          : MktTimeline(items: [
              for (final u in o.upcoming)
                MktTimelineItem(
                  key: Key('co_upcoming_${u.type}_${u.id}'),
                  time: coordDay(u.day, pattern: 'd MMM'),
                  title: u.title,
                  subtitle: u.isMeeting ? [u.time.isEmpty ? '' : (u.endTime.isEmpty ? u.time : '${u.time}–${u.endTime}'), u.subtitle].where((x) => x.isNotEmpty).join(' · ') : 'Due · ${u.subtitle}',
                  color: u.isMeeting ? Mkt.primary : Mkt.warn,
                ),
            ]),
    );
  }
}

// ── key updates ───────────────────────────────────────────────────────────────

class _KeyUpdatesCard extends StatelessWidget {
  const _KeyUpdatesCard({required this.o});
  final CoordOverview o;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Key Updates',
        icon: Icons.campaign_outlined,
        child: o.keyUpdates.isEmpty
            ? const MktEmpty('No updates yet.', icon: Icons.campaign_outlined, height: 110)
            : Column(key: const Key('co_key_updates'), children: [
                for (final u in o.keyUpdates)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(switch (u.tone) { 'good' => Icons.check_circle_rounded, 'bad' => Icons.error_rounded, 'warn' => Icons.warning_amber_rounded, _ => Icons.info_rounded }, size: 16, color: toneColor(u.tone)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(u.text, style: mktText(12))),
                    ]),
                  ),
              ]),
      );
}
