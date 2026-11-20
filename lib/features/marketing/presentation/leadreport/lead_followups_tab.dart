import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_detail_sheet.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Lead Report → Follow-ups: the follow-ups due in the range (and brand), from the CRM — the follow-ups logged on a lead, and the date on
/// a lead in the Follow-up stage. Due = still pending; Overdue = pending and due before today; Today = pending and due today; Completed =
/// marked Completed. A short range hides older overdue follow-ups, so they are counted under the table.
class LeadFollowUpsTab extends ConsumerWidget {
  const LeadFollowUpsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(leadFollowUpQueryProvider);
    final async = ref.watch(leadFollowUpsProvider(q));
    void set(FollowUpQuery next) => ref.read(leadFollowUpQueryProvider.notifier).state = next;
    final counts = async.asData?.value.counts;
    // a new date range or brand is a new list: back to its first page
    ref.listen(teamFilterProvider, (_, _) {
      final cur = ref.read(leadFollowUpQueryProvider);
      if (cur.page != 1) set(FollowUpQuery(filter: cur.filter));
    });
    int? chipCount(String f) => counts == null
        ? null
        : switch (f) { 'today' => counts.today, 'overdue' => counts.overdue, 'upcoming' => counts.upcoming, 'completed' => counts.completed, _ => counts.total };

    return RefreshIndicator(
      onRefresh: () async => refreshLeadReport(ref),
      child: ListView(
        key: const Key('lr_followups_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          MktKpiRow(minWidth: 168, children: [
            leadKpi(key: 'lr_fu_kpi_due', icon: Icons.notifications_active_outlined, label: 'Follow-ups Due', value: counts == null ? '—' : '${counts.due}', note: counts == null ? null : 'Pending in this range', tint: Mkt.primary),
            leadKpi(key: 'lr_fu_kpi_today', icon: Icons.today_outlined, label: 'Today', value: counts == null ? '—' : '${counts.today}', note: counts == null ? null : 'Due today', tint: Mkt.warn),
            leadKpi(key: 'lr_fu_kpi_overdue', icon: Icons.error_outline_rounded, label: 'Overdue', value: counts == null ? '—' : '${counts.overdue}', note: counts == null ? null : 'Pending, due before today', tint: Mkt.bad),
            leadKpi(key: 'lr_fu_kpi_completed', icon: Icons.check_circle_outline_rounded, label: 'Completed', value: counts == null ? '—' : '${counts.completed}', change: counts?.change['completed'], tint: Mkt.good),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in kFollowUpFilters) MktFilterChip(key: Key('lr_fu_${f.$1}'), label: f.$1 == 'all' ? 'All Follow-ups' : f.$2, count: chipCount(f.$1), selected: q.filter == f.$1, onTap: () => set(FollowUpQuery(filter: f.$1))),
          ]),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 90), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, onRetry: () => refreshLeadReport(ref)),
            data: (d) => MktCard(
              title: 'Follow-ups',
              subtitle: 'Due in the chosen date range',
              icon: Icons.notifications_active_outlined,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (d.items.isEmpty)
                  const MktEmpty('No follow-ups in this chip and date range.', icon: Icons.notifications_off_outlined, height: 140)
                else
                  MktTable(
                    key: const Key('lr_fu_table'),
                    minWidth: 900,
                    columns: const [
                      MktCol('LEAD', flex: 3),
                      MktCol('CAMPAIGN', flex: 3),
                      MktCol('ASSIGNED TO', flex: 3),
                      MktCol('TYPE', flex: 3),
                      MktCol('DUE DATE', flex: 3),
                      MktCol('STATUS', flex: 2),
                      MktCol('ACTIONS', width: 96),
                    ],
                    rowKeys: [for (final f in d.items) Key('lr_fu_${f.id}')],
                    onRowTap: (i) => showLeadDetail(context, d.items[i].leadId),
                    rows: [
                      for (final f in d.items)
                        [
                          lrCell(f.name, bold: true),
                          lrCell(f.campaign.isEmpty ? '—' : f.campaign, color: f.campaign.isEmpty ? Mkt.inkSoft : Mkt.ink),
                          f.assignedTo.isEmpty ? lrCell('Unassigned', color: Mkt.inkSoft) : Row(children: [MktAvatar(f.assignedTo, size: 22), const SizedBox(width: 6), Flexible(child: lrCell(f.assignedTo))]),
                          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            KeyedSubtree(key: Key('lr_fu_type_${f.id}'), child: lrCell(f.channelLabel, color: f.channel.isEmpty ? Mkt.inkSoft : Mkt.ink)),
                            if (f.remark.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6, left: 2), child: Text(f.remark, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft))),
                          ]),
                          lrCell(f.due == null ? dayLabel(f.dueDay) : DateFormat('d MMM, h:mm a').format(f.due!)),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: MktChip(followUpLabel(f.state), color: followUpColor(f.state))),
                          d.canContact && f.phone.isNotEmpty ? ContactButtons(phone: f.phone, idKey: f.id) : const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.lock_outline_rounded, size: 14, color: Mkt.inkSoft)),
                        ],
                    ],
                  ),
                if (!d.canContact && d.items.isNotEmpty) const LrNote('Call and WhatsApp are available to a Marketing Manager — numbers are hidden for everyone else.', icon: Icons.lock_outline_rounded),
                const SizedBox(height: 6),
                LeadPager(page: d.page, pageSize: d.pageSize, total: d.total, keyPrefix: 'lr_fu', noun: 'follow-ups', onPage: (p) => set(FollowUpQuery(filter: q.filter, page: p))),
              ]),
            ),
          ),
          if (counts != null && counts.overdueBefore > 0)
            LrNote('${counts.overdueBefore} older follow-up${counts.overdueBefore == 1 ? ' is' : 's are'} still overdue from before this date range — widen the range to see ${counts.overdueBefore == 1 ? 'it' : 'them'}.', icon: Icons.warning_amber_rounded, color: Mkt.bad),
          const LrNote('Follow-ups are the ones logged on a lead plus the date on a lead in the Follow-up stage. The type (call, WhatsApp, visit, meeting) is the one chosen when the follow-up was logged in the CRM; "Follow-up" means none was chosen. The CRM\'s own "Completed" counter has no dates, so it is not used here.'),
        ],
      ),
    );
  }
}
