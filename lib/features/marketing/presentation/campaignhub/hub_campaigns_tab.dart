import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/campaign_detail.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/campaign_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_export.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Campaigns → All Campaigns: how many campaigns are in each status, and the table of every campaign (searchable, filterable by status,
/// platform and objective) with its spend and leads for the range, its budget, and the team hours logged against it. Tap a row for the
/// campaign's own page (edit, delete, daily figures, ads, logged work).
class HubCampaignsTab extends ConsumerStatefulWidget {
  const HubCampaignsTab({super.key});

  @override
  ConsumerState<HubCampaignsTab> createState() => _HubCampaignsTabState();
}

class _HubCampaignsTabState extends ConsumerState<HubCampaignsTab> {
  late final _search = TextEditingController(text: ref.read(hubCampaignQueryProvider).q);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(HubCampaignQuery q) => ref.read(hubCampaignQueryProvider.notifier).state = q;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(hubCampaignsProvider);
    final q = ref.watch(hubCampaignQueryProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCampaignHub(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshCampaignHub(ref))]),
        data: (p) {
          final c = p.counts;
          return ListView(
            key: const Key('hub_campaigns_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const HubExportBar(type: 'campaign'),
              MktKpiRow(minWidth: 176, children: [
                MktKpiCard(key: const Key('cp_kpi_total'), icon: Icons.campaign_outlined, value: '${c.total}', label: 'Total Campaigns', note: c.planned > 0 ? '${c.planned} planned' : null, tint: Mkt.primary),
                MktKpiCard(key: const Key('cp_kpi_active'), icon: Icons.play_circle_outline_rounded, value: '${c.active}', label: 'Active', tint: Mkt.good),
                MktKpiCard(key: const Key('cp_kpi_paused'), icon: Icons.pause_circle_outline_rounded, value: '${c.paused}', label: 'Paused', tint: Mkt.warn),
                MktKpiCard(key: const Key('cp_kpi_completed'), icon: Icons.check_circle_outline_rounded, value: '${c.completed}', label: 'Completed', tint: Mkt.blue),
              ]),
              const SizedBox(height: 12),
              MktCard(
                title: 'Campaigns',
                icon: Icons.list_alt_rounded,
                subtitle: 'View, manage and track all campaigns · figures for the selected dates',
                trailing: TextButton(key: const Key('cp_new_inline'), onPressed: () => _newCampaign(context), child: Text('+ New Campaign', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.primary))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(key: const Key('cp_search'), controller: _search, onChanged: (v) => _set(q.copyWith(q: v, page: 1)), style: mktText(13), decoration: hubSearchDecoration('Search campaign, objective or Meta ID…')),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    KeyedSubtree(key: const Key('cp_status'), child: MktDropdownPill<String>(value: q.status, icon: Icons.flag_outlined, options: [('all', 'All Status'), for (final s in kHubStatuses) (s.$1, s.$2)], onChanged: (v) => _set(q.copyWith(status: v, page: 1)))),
                    KeyedSubtree(key: const Key('cp_platform'), child: MktDropdownPill<String>(value: q.platform, icon: Icons.public_rounded, options: [('all', 'All Platforms'), for (final s in kHubPlatforms) (s.$1, s.$2)], onChanged: (v) => _set(q.copyWith(platform: v, page: 1)))),
                    KeyedSubtree(key: const Key('cp_objective'), child: MktDropdownPill<String>(value: q.objective, icon: Icons.track_changes_rounded, options: [('all', 'All Objectives'), for (final s in kHubObjectives) (s.$1, s.$2)], onChanged: (v) => _set(q.copyWith(objective: v, page: 1)))),
                  ]),
                  const SizedBox(height: 10),
                  if (p.items.isEmpty)
                    MktEmpty(c.total == 0 ? 'No campaigns yet. Use New Campaign to add the first.' : 'No campaign matches these filters.', icon: Icons.campaign_outlined, height: 130)
                  else
                    MktTable(
                      key: const Key('cp_table'),
                      minWidth: 900,
                      columns: const [
                        MktCol('Campaign', flex: 5),
                        MktCol('Platform', flex: 3),
                        MktCol('Objective', flex: 3),
                        MktCol('Status', flex: 3),
                        MktCol('Spend', flex: 2, align: Alignment.centerRight),
                        MktCol('Leads', flex: 2, align: Alignment.centerRight),
                        MktCol('CPL', flex: 2, align: Alignment.centerRight),
                        MktCol('Budget', flex: 3, align: Alignment.centerRight),
                        MktCol('Team hours', flex: 2, align: Alignment.centerRight),
                      ],
                      onRowTap: (i) => showCampaignDetail(context, ref, p.items[i].id),
                      rowKeys: [for (final r in p.items) Key('cp_row_${r.id}')],
                      rows: [for (final r in p.items) _row(r)],
                    ),
                  const SizedBox(height: 6),
                  HubPager(prefix: 'cp', page: p.page, pageSize: p.pageSize, total: p.total, shown: p.items.length, onPage: (n) => _set(q.copyWith(page: n))),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _row(HubCampaignRow r) => [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
            Text([r.brand == 'kerala' ? 'Kerala' : 'Main', if (r.metaCampaignId.isNotEmpty) 'Meta ${r.metaCampaignId}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
          ]),
        ),
        r.platform.isEmpty
            ? Text('—', style: mktText(12, color: Mkt.inkSoft))
            : Row(children: [Icon(hubPlatformIcon(r.platform), size: 14, color: Mkt.inkSoft), const SizedBox(width: 5), Flexible(child: Text(hubPlatformLabel(r.platform), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12)))]),
        Padding(padding: const EdgeInsets.only(right: 6), child: Text(r.objective.isEmpty ? '—' : hubObjectiveLabel(r.objective), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12))),
        HubStatusChip(key: Key('cp_status_${r.id}'), status: r.status, metaStatus: r.metaStatus),
        Text(hubInr(r.spend, compact: true), style: mktText(12)),
        Text('${r.leads}', style: mktText(12)),
        Text(hubInr(r.cpl), style: mktText(12)),
        r.hasBudget ? Text(hubInr(r.budget, compact: true), style: mktText(12)) : Text('No budget set', key: Key('cp_no_budget_${r.id}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
        Text(r.workMinutes == 0 ? '—' : hubHours(r.workMinutes), style: mktText(12)),
      ];

  void _newCampaign(BuildContext context) => showCampaignEditor(context, ref, defaultBrand: defaultBrandFor(ref.read(teamFilterProvider).brand.wire));
}

/// A new campaign starts as Kerala — the ads run only on the Kerala account — unless Main is the brand being looked at.
String defaultBrandFor(String filterBrand) => filterBrand == 'main' ? 'main' : 'kerala';
