import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/approval_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';

/// Coordinations → Approvals: raise an approval with an amount and impact; only the Marketing Manager approves, rejects (with a reason),
/// escalates or marks one in review. Tabs: Pending, In Review (escalated ones too), Approved, Rejected. Under the table, the posts and
/// assets that are waiting for review in Socials and the Creative Portfolio — read from those records, with a way to where they are decided.
class CoordApprovalsTab extends ConsumerWidget {
  const CoordApprovalsTab({super.key});

  void _set(WidgetRef ref, ApprovalQuery q) => ref.read(coordApprovalQueryProvider.notifier).state = q;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coordApprovalsProvider);
    final q = ref.watch(coordApprovalQueryProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCoordinations(ref),
      child: async.when(
        loading: coordLoading,
        error: (e, _) => coordError(e, ref),
        data: (d) {
          final k = d.kpis;
          void tab(String t) => _set(ref, q.copyWith(status: t, page: 1));
          return ListView(
            key: const Key('coord_approvals_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 165, children: [
                coordKpi(keyName: 'co_ap_kpi_total', icon: Icons.description_outlined, value: '${k.total}', label: 'Total Requests', tint: Mkt.primary, note: k.awaitingAmount > 0 ? '${inr(k.awaitingAmount)} still waiting' : null),
                coordKpi(keyName: 'co_ap_kpi_pending', icon: Icons.hourglass_empty_rounded, value: '${k.pending}', label: 'Pending Approval', tint: Mkt.warn, onTap: () => tab('pending')),
                coordKpi(keyName: 'co_ap_kpi_review', icon: Icons.search_rounded, value: '${k.inReview}', label: 'In Review', tint: Mkt.blue, onTap: () => tab('in_review')),
                coordKpi(keyName: 'co_ap_kpi_escalated', icon: Icons.warning_amber_rounded, value: '${k.escalated}', label: 'Escalated', tint: Mkt.bad, onTap: () => tab('in_review')),
                coordKpi(keyName: 'co_ap_kpi_approved', icon: Icons.check_rounded, value: '${k.approved}', label: 'Approved', tint: Mkt.good, onTap: () => tab('approved')),
              ]),
              const SizedBox(height: 12),
              MktCard(
                title: 'Approvals',
                icon: Icons.verified_outlined,
                trailing: const ExportButton(type: 'approvals'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    for (final t in const [('pending', 'Pending'), ('in_review', 'In Review'), ('approved', 'Approved'), ('rejected', 'Rejected')]) MktFilterChip(key: Key('co_ap_tab_${t.$1}'), label: t.$2, count: d.tabCounts[t.$1] ?? 0, selected: q.status == t.$1, onTap: () => tab(t.$1)),
                    MktPrimaryButton(key: const Key('co_ap_new'), label: 'New Approval', onPressed: () => showApprovalEditor(context, ref)),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(width: 260, child: CoordSearchField(fieldKey: const Key('co_ap_search'), initial: q.q, hint: 'Search approvals…', onChanged: (v) => _set(ref, ref.read(coordApprovalQueryProvider).copyWith(q: v, page: 1)))),
                  const SizedBox(height: 8),
                  if (d.items.isEmpty)
                    MktEmpty(k.total == 0 ? 'No approvals in this period. Use New Approval to ask for one.' : 'No approval in this tab.', icon: Icons.verified_outlined, height: 130)
                  else
                    MktTable(
                      minWidth: 860,
                      columns: const [MktCol('Approval Request', flex: 5), MktCol('Request By', flex: 3), MktCol('Category', flex: 2), MktCol('Amount / Impact', flex: 3), MktCol('Requested On', flex: 2), MktCol('Status', flex: 2), MktCol('Action', width: 140)],
                      rowKeys: [for (final a in d.items) Key('co_ap_row_${a.id}')],
                      onRowTap: (i) => d.items[i].canEdit ? showApprovalEditor(context, ref, approval: d.items[i]) : showApprovalDetail(context, d.items[i]),
                      rows: [for (final a in d.items) _cells(context, ref, a)],
                    ),
                  const SizedBox(height: 6),
                  CoordPager(keyPrefix: 'co_ap', total: d.total, page: d.page, pageSize: d.pageSize, shown: d.items.length, onPage: (p) => _set(ref, q.copyWith(page: p))),
                ]),
              ),
              const SizedBox(height: 12),
              _ReviewCard(queue: d.review),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _cells(BuildContext context, WidgetRef ref, ApprovalRow a) => [
        Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w600)),
        PersonCell(a.requestedBy),
        MktChip(a.category, color: deptColor(a.category)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(inr(a.amount), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w800)),
          if (a.impact.isNotEmpty) Text(a.impact, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
        ]),
        Text(coordDay(a.requestedOn), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          MktChip(approvalStatusLabel(a.status), color: approvalStatusColor(a.status)),
          if (a.status == 'escalated' && a.escalatedToLabel.isNotEmpty)
            Tooltip(message: '${a.escalatedToLabel}${a.escalatedBy.isEmpty ? '' : ' by ${a.escalatedBy}'}', child: Text(a.escalatedToLabel, key: Key('co_ap_escalated_${a.id}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, color: Mkt.bad))),
        ]),
        _Actions(approval: a),
      ];
}

/// The action cell: a manager approves or rejects with one tap (a note is asked for); everyone else reads, and changes what is theirs.
class _Actions extends ConsumerWidget {
  const _Actions({required this.approval});
  final ApprovalRow approval;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = approval;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (a.canDecide) ...[
        IconButton(key: Key('co_ap_approve_${a.id}'), tooltip: 'Approve', visualDensity: VisualDensity.compact, onPressed: () => showDecisionDialog(context, ref, a, 'approve'), icon: const Icon(Icons.check_rounded, color: Mkt.good, size: 20)),
        IconButton(key: Key('co_ap_reject_${a.id}'), tooltip: 'Reject', visualDensity: VisualDensity.compact, onPressed: () => showDecisionDialog(context, ref, a, 'reject'), icon: const Icon(Icons.close_rounded, color: Mkt.bad, size: 20)),
      ] else if (!a.canEdit)
        IconButton(key: Key('co_ap_view_${a.id}'), tooltip: 'View', visualDensity: VisualDensity.compact, onPressed: () => showApprovalDetail(context, a), icon: const Icon(Icons.visibility_outlined, size: 18, color: Mkt.primary)),
      if (a.canDecide || a.canEdit || a.canDelete)
        PopupMenuButton<String>(
          key: Key('co_ap_menu_${a.id}'),
          tooltip: 'More',
          padding: EdgeInsets.zero,
          iconSize: 18,
          onSelected: (v) async {
            if (v == 'edit') {
              await showApprovalEditor(context, ref, approval: a);
            } else if (v == 'delete') {
              final yes = await confirmCoord(context, title: 'Delete this approval?', body: '"${a.title}" is removed.', confirmLabel: 'Delete', confirmKey: const Key('co_ap_delete_confirm'));
              if (yes && context.mounted) await coordQuickWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).deleteApproval(a.id));
            } else {
              await showDecisionDialog(context, ref, a, v);
            }
          },
          itemBuilder: (_) => [
            if (a.canDecide && a.status == 'pending') const PopupMenuItem(value: 'review', child: Text('Mark in review')),
            if (a.canDecide && a.status != 'escalated') const PopupMenuItem(value: 'escalate', child: Text('Escalate')),
            if (a.canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (a.canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Mkt.bad))),
          ],
        ),
    ]);
  }
}

/// Posts in review (Socials) and assets in review (Creative Portfolio): the same records those screens hold, with a Review button that goes there.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.queue});
  final ReviewQueue queue;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Content awaiting review',
        subtitle: '${queue.content} posts in Socials · ${queue.assets} assets in the Creative Portfolio',
        icon: Icons.rate_review_outlined,
        child: queue.items.isEmpty
            ? const MktEmpty('Nothing is waiting for review in Socials or the Creative Portfolio.', icon: Icons.task_alt_rounded, height: 100)
            : Column(key: const Key('co_ap_review_list'), children: [
                for (final r in queue.items)
                  Padding(
                    key: Key('co_ap_review_${r.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: r.thumbUrl.isEmpty
                              ? Container(color: Mkt.tint(Mkt.primary), child: Icon(r.type == 'asset' ? Icons.perm_media_outlined : Icons.article_outlined, color: Mkt.primary, size: 20))
                              : Image.network(r.thumbUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Mkt.tint(Mkt.primary))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                          Text([r.type == 'asset' ? 'Creative Portfolio' : 'Socials', r.label, if (r.brand == 'kerala') 'Kerala', if (r.day != null) coordDay(r.day, pattern: 'd MMM')].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(key: Key('co_ap_review_go_${r.id}'), style: FilledButton.styleFrom(backgroundColor: Mkt.primary, minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 12)), onPressed: () => GoRouter.maybeOf(context)?.go(r.link), child: const Text('Review')),
                    ]),
                  ),
              ]),
      );
}
