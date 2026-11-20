import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/ad_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_export.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';

/// Campaigns → Creatives & Ads: every ad with its picture (a link), format, impressions, CTR, CPM, spend, the platform's results and cost per
/// result, the CRM leads that name it as their creative and the cost per CRM lead, and where it stands against the brand's average (Top
/// performing / Underperforming / Needs attention — the legend under the table says how).
///  • An ad imported from Ads Manager's AD-LEVEL export shows the days of the selected dates (an imported ad that did not run then is not
///    listed). An ad typed by hand shows the lifetime figures typed on it, marked "Lifetime"; it has no cost per CRM lead (a lifetime spend
///    over the dates' leads would mean nothing).
///  • "Results" are Meta's own; "CRM leads" are the CRM's.
class HubAdsTab extends ConsumerStatefulWidget {
  const HubAdsTab({super.key});

  @override
  ConsumerState<HubAdsTab> createState() => _HubAdsTabState();
}

class _HubAdsTabState extends ConsumerState<HubAdsTab> {
  late final _search = TextEditingController(text: ref.read(hubAdQueryProvider).q);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(HubAdQuery q) => ref.read(hubAdQueryProvider.notifier).state = q;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(hubAdsProvider);
    final q = ref.watch(hubAdQueryProvider);
    final campaigns = ref.watch(hubSetupProvider).maybeWhen(data: (s) => s.campaigns, orElse: () => const <HubCampaignOption>[]);
    return RefreshIndicator(
      onRefresh: () async => refreshCampaignHub(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshCampaignHub(ref))]),
        data: (a) {
          final k = a.kpis;
          return ListView(
            key: const Key('hub_ads_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const HubExportBar(type: 'creative'),
              MktKpiRow(minWidth: 176, children: [
                MktKpiCard(key: const Key('ad_kpi_total'), icon: Icons.image_outlined, value: '${k.total}', label: 'Total Ads', note: k.lifetimeAds > 0 ? '${k.lifetimeAds} with lifetime figures' : null, tint: Mkt.primary),
                MktKpiCard(key: const Key('ad_kpi_top'), icon: Icons.emoji_events_outlined, value: '${k.top}', label: 'Top Performing', tint: Mkt.good),
                MktKpiCard(key: const Key('ad_kpi_ctr'), icon: Icons.ads_click_rounded, value: hubPct(k.ctr), label: 'Avg. CTR', tint: Mkt.blue),
                MktKpiCard(key: const Key('ad_kpi_cpm'), icon: Icons.visibility_outlined, value: hubInr(k.cpm), label: 'Avg. CPM', tint: Mkt.warn),
                MktKpiCard(key: const Key('ad_kpi_cpr'), icon: Icons.sell_outlined, value: hubInr(k.costPerResult), label: 'Avg. Cost per Result', tint: Mkt.teal),
                MktKpiCard(key: const Key('ad_kpi_leads'), icon: Icons.filter_alt_outlined, value: hubCount(k.leads), label: 'CRM Leads', note: 'CPL ${hubInr(k.cpl)}', tint: Mkt.pink),
              ]),
              const SizedBox(height: 12),
              MktCard(
                title: 'Ads',
                icon: Icons.image_outlined,
                subtitle: 'Imported ads: the selected dates · ads typed by hand: lifetime figures (marked Lifetime)',
                trailing: TextButton(key: const Key('ad_add'), onPressed: () => showAdEditor(context, ref, campaignId: q.campaignId), child: Text('+ Add Ad', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.primary))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final f in const [('all', 'All Ads'), ('top', 'Top Performing'), ('under', 'Underperforming'), ('needs_attention', 'Needs Attention')])
                        Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('ad_chip_${f.$1}'), label: f.$2, count: a.countOf(f.$1), selected: q.filter == f.$1, onTap: () => _set(q.copyWith(filter: f.$1, page: 1)))),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  TextField(key: const Key('ad_search'), controller: _search, onChanged: (v) => _set(q.copyWith(q: v, page: 1)), style: mktText(13), decoration: hubSearchDecoration('Search ad, ad set or campaign…')),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: KeyedSubtree(
                      key: const Key('ad_campaign_filter'),
                      child: MktDropdownPill<String>(
                        value: q.campaignId ?? 'all',
                        icon: Icons.campaign_outlined,
                        options: [('all', 'All Campaigns'), for (final c in campaigns) (c.id, c.title)],
                        onChanged: (v) => _set(v == 'all' ? q.copyWith(clearCampaign: true, page: 1) : q.copyWith(campaignId: v, page: 1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (a.items.isEmpty)
                    MktEmpty(k.total == 0 ? 'No ads yet. Use Add Ad to add the first, with a link to its creative.' : 'No ad matches these filters.', icon: Icons.image_outlined, height: 130)
                  else
                    MktTable(
                      key: const Key('ad_table'),
                      minWidth: 1180,
                      rowHeight: 56,
                      columns: const [
                        MktCol('Ad / Creative', flex: 5),
                        MktCol('Campaign', flex: 3),
                        MktCol('Format', flex: 2),
                        MktCol('Impressions', flex: 2, align: Alignment.centerRight),
                        MktCol('CTR', flex: 2, align: Alignment.centerRight),
                        MktCol('CPM', flex: 2, align: Alignment.centerRight),
                        MktCol('Spend', flex: 2, align: Alignment.centerRight),
                        MktCol('Results', flex: 2, align: Alignment.centerRight),
                        MktCol('Cost / result', flex: 2, align: Alignment.centerRight),
                        MktCol('CRM leads', flex: 2, align: Alignment.centerRight),
                        MktCol('CPL', flex: 2, align: Alignment.centerRight),
                        MktCol('Status', flex: 3),
                      ],
                      onRowTap: (i) => showAdEditor(context, ref, ad: a.items[i]),
                      rowKeys: [for (final r in a.items) Key('ad_row_${r.id}')],
                      rows: [for (final r in a.items) _row(r)],
                    ),
                  const SizedBox(height: 6),
                  HubPager(prefix: 'ad', page: a.page, pageSize: a.pageSize, total: a.total, shown: a.items.length, onPage: (n) => _set(q.copyWith(page: n))),
                  const SizedBox(height: 10),
                  const AdVerdictLegend(),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _row(HubAdRow r) => [
        Row(children: [
          HubThumb(url: r.thumbUrl, format: r.format, size: 38),
          const SizedBox(width: 8),
          Flexible(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700)),
              if (r.adSetName.isNotEmpty) Text(r.adSetName, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
            ]),
          ),
          if (r.isLifetime) ...[const SizedBox(width: 4), HubLifetimeMark(key: Key('ad_lifetime_${r.id}'))],
        ]),
        Padding(padding: const EdgeInsets.only(right: 6), child: Text(r.campaign, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11.5))),
        Text(adFormatLabel(r.format), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5)),
        Text(hubCompact(r.impressions), style: mktText(12)),
        Text(hubPct(r.ctr), style: mktText(12)),
        Text(hubInr(r.cpm), style: mktText(12)),
        Text(hubInr(r.spend, compact: true), style: mktText(12)),
        Text(hubCount(r.results), style: mktText(12)),
        Text(hubInr(r.costPerResult), style: mktText(12)),
        Text(r.leads == null ? '—' : hubCount(r.leads), key: Key('ad_leads_${r.id}'), style: mktText(12)),
        Text(hubInr(r.cpl), key: Key('ad_cpl_${r.id}'), style: mktText(12)),
        MktChip(adVerdictLabel(r.verdict), color: adVerdictColor(r.verdict)),
      ];
}
