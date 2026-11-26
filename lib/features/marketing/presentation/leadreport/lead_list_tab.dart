import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_detail_sheet.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_leads_screen.dart' show showAddLeadDialog;

/// Opens the CRM's own Add Lead form (the Leads screen's — same fields and checks). A provider so a test can see it was asked for.
final leadAddFormOpenerProvider = Provider<Future<void> Function(BuildContext context)>((ref) => showAddLeadDialog);

const _kSorts = [('created', 'Newest first'), ('name', 'Name A–Z'), ('status', 'Status'), ('source', 'Source'), ('assigned', 'Assigned to')];
const _kStageChips = [('all', 'All Leads'), ('new', 'New'), ('in_progress', 'In Progress'), ('converted', 'Converted'), ('not_converted', 'Not Converted')];

/// Lead Report → All Leads: every lead of the range and brand — the CRM's own — with search, stage chips, source / assigned to / campaign
/// filters (applied on the server), sorting and paging. A row opens the lead read-only, with its follow-up history; "Add Lead" opens the
/// CRM's own lead form. Contact numbers are shown only to a Marketing Manager (everyone else sees them masked, and cannot search by them).
class LeadListTab extends ConsumerWidget {
  const LeadListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(leadListQueryProvider);
    final async = ref.watch(leadListProvider(q));
    void set(LeadListQuery next) => ref.read(leadListQueryProvider.notifier).state = next;
    final counts = async.asData?.value.counts;
    final filters = async.asData?.value.filters ?? const LeadFilterOptions();
    // the choices: the people / campaigns of the range's leads — and the one chosen, even if the new range has none of its leads
    List<(String, String)> withChosen(List<(String, String)> opts, String chosen, String fallback) => opts.any((o) => o.$1 == chosen) ? opts : [...opts, (chosen, fallback)];
    final assigneeOptions = withChosen([
      ('all', 'Anyone'),
      if (filters.unassigned > 0 || q.assignee == 'unassigned') ('unassigned', 'Unassigned (${filters.unassigned})'),
      for (final a in filters.assignees) (a.id, '${a.label} (${a.count})'),
    ], q.assignee, 'Chosen person (0)');
    final campaignOptions = withChosen([
      ('all', 'All campaigns'),
      if (filters.untagged > 0 || q.campaign == 'none') ('none', 'No campaign (${filters.untagged})'),
      for (final c in filters.campaigns) (c.id, '${c.label} (${c.count})'),
    ], q.campaign, 'Chosen campaign (0)');
    // a new date range or brand is a new list: back to its first page
    ref.listen(teamFilterProvider, (_, _) {
      final cur = ref.read(leadListQueryProvider);
      if (cur.page != 1) set(cur.copyWith(page: 1));
    });

    return RefreshIndicator(
      onRefresh: () async => refreshLeadReport(ref),
      child: ListView(
        key: const Key('lr_leads_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 280, child: LeadSearchField(key: const Key('lr_search'), initial: q.q, hint: 'Search name, campaign, assignee…', onChanged: (v) => set(q.copyWith(q: v)))),
            KeyedSubtree(
              key: const Key('lr_source_filter'),
              child: MktDropdownPill<String>(value: q.source, icon: Icons.hub_outlined, options: [('all', 'All sources'), ...kLeadSourceGroups], onChanged: (v) => set(q.copyWith(source: v))),
            ),
            KeyedSubtree(
              key: const Key('lr_assignee_filter'),
              child: MktDropdownPill<String>(value: q.assignee, icon: Icons.person_outline_rounded, options: assigneeOptions, onChanged: (v) => set(q.copyWith(assignee: v))),
            ),
            KeyedSubtree(
              key: const Key('lr_campaign_filter'),
              child: MktDropdownPill<String>(value: q.campaign, icon: Icons.campaign_outlined, options: campaignOptions, onChanged: (v) => set(q.copyWith(campaign: v))),
            ),
            KeyedSubtree(
              key: const Key('lr_sort'),
              child: MktDropdownPill<String>(value: q.sort, icon: Icons.sort_rounded, options: _kSorts, onChanged: (v) => set(q.copyWith(sort: v))),
            ),
            FilledButton.icon(
              key: const Key('lr_add_lead'),
              style: FilledButton.styleFrom(backgroundColor: Mkt.primary, minimumSize: const Size(0, 38)),
              onPressed: () async {
                await ref.read(leadAddFormOpenerProvider)(context);
                // a lead saved in the CRM's form shows here at once
                refreshLeadReport(ref);
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add Lead'),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _kStageChips) MktFilterChip(key: Key('lr_stage_${c.$1}'), label: c.$2, count: counts?.of(c.$1), selected: q.stage == c.$1, onTap: () => set(q.copyWith(stage: c.$1))),
          ]),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 90), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, onRetry: () => refreshLeadReport(ref)),
            data: (d) => MktCard(
              title: 'All Leads',
              subtitle: 'The leads are the CRM\'s own — Add Lead opens the CRM\'s lead form',
              icon: Icons.people_alt_outlined,
              child: Column(children: [
                if (d.items.isEmpty)
                  const MktEmpty('No leads match these filters in this date range.', icon: Icons.search_off_rounded, height: 140)
                else
                  MktTable(
                    key: const Key('lr_leads_table'),
                    minWidth: 900,
                    columns: const [
                      MktCol('LEAD ID', width: 84),
                      MktCol('NAME', flex: 3),
                      MktCol('CONTACT', flex: 3),
                      MktCol('SOURCE', flex: 3),
                      MktCol('CAMPAIGN', flex: 3),
                      MktCol('ASSIGNED TO', flex: 3),
                      MktCol('STATUS', flex: 3),
                      MktCol('CREATED', width: 84),
                    ],
                    rowKeys: [for (final l in d.items) Key('lr_lead_${l.id}')],
                    onRowTap: (i) => showLeadDetail(context, d.items[i].id),
                    rows: [
                      for (final l in d.items)
                        [
                          lrCell(l.shortId, color: Mkt.inkSoft),
                          lrCell(l.name, bold: true),
                          Row(children: [
                            if (!d.canContact) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.lock_outline_rounded, size: 12, color: Mkt.inkSoft)),
                            Flexible(child: lrCell(l.contactFor(d.canContact).isEmpty ? '—' : l.contactFor(d.canContact))),
                          ]),
                          lrCell(l.sourceLabel),
                          lrCell(l.campaign.isEmpty ? '—' : l.campaign, color: l.campaign.isEmpty ? Mkt.inkSoft : Mkt.ink),
                          l.assignedTo.isEmpty
                              ? lrCell('Unassigned', color: Mkt.inkSoft)
                              : Row(children: [MktAvatar(l.assignedTo, size: 22), const SizedBox(width: 6), Flexible(child: lrCell(l.assignedTo))]),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: MktChip(l.status, color: leadStageColor(l.stage))),
                          lrCell(dayLabel(l.createdDay), color: Mkt.inkSoft),
                        ],
                    ],
                  ),
                if (!d.canContact && d.items.isNotEmpty) const LrNote('Contact numbers are hidden — only a Marketing Manager can see them.', icon: Icons.lock_outline_rounded),
                const SizedBox(height: 6),
                LeadPager(page: d.page, pageSize: d.pageSize, total: d.total, keyPrefix: 'lr_leads', onPage: (p) => set(q.copyWith(page: p))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
