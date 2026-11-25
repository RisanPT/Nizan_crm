import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/ad_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/campaign_detail.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/day_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_audiences.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_export.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/meta_import.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';

/// Campaigns → Overview: the headline figures with their change on the period before, the performance trend, leads by campaign type (lead
/// gen / WhatsApp / website form / calls / others — the Lead Report shows the same split), the honest Meta card (import, last import), the
/// active campaigns, the best creatives, the top audiences & placements (from Ads Manager breakdown exports) and what the numbers say.
/// Spend, reach, impressions and clicks are what was imported or typed; leads are the CRM's.
class HubOverviewTab extends ConsumerWidget {
  const HubOverviewTab({super.key, required this.onGo});
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hubOverviewProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCampaignHub(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshCampaignHub(ref))]),
        data: (o) => ListView(
          key: const Key('hub_overview_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const HubExportBar(type: 'overview'),
            _Kpis(o: o),
            const SizedBox(height: 12),
            MktGrid(rows: [
              [(6, _TrendCard(trend: o.trend)), (3, _TypeCard(o: o)), (3, MetaCard(meta: o.meta, onImport: () => startMetaImport(context, ref), onTypeDay: () => showDayEditor(context, ref)))],
              [(7, _ActiveCampaigns(o: o, onGo: onGo)), (5, _CreativesCard(o: o, onGo: onGo))],
              [(7, TopAudiencesCard(audiences: o.audiences, onMore: () => onGo('performance'))), (5, _InsightsCard(o: o))],
            ]),
          ],
        ),
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.o});
  final OverviewData o;

  @override
  Widget build(BuildContext context) {
    final k = o.kpis;
    final t = o.trend;
    List<double> spark(double Function(HubTrendPoint) f) => [for (final p in t) f(p)];
    Widget kpi(String key, IconData icon, String label, String value, String changeKey, Color tint, {bool lowerIsBetter = false, bool neutral = false, List<double>? sp}) {
      final d = hubDelta(k.changeOf(changeKey), lowerIsBetter: lowerIsBetter);
      return MktKpiCard(key: Key(key), icon: icon, value: value, label: label, note: d?.text, good: neutral ? null : d?.good, tint: tint, spark: sp);
    }

    return MktKpiRow(minWidth: 176, children: [
      kpi('ov_kpi_spend', Icons.account_balance_wallet_outlined, 'Total Ad Spend', hubInr(k.now.spend, compact: true), 'spend', Mkt.primary, neutral: true, sp: spark((p) => p.spend)),
      kpi('ov_kpi_reach', Icons.groups_outlined, 'People Reached', hubCount(k.now.reach), 'reach', Mkt.good, sp: spark((p) => p.reach.toDouble())),
      kpi('ov_kpi_impr', Icons.visibility_outlined, 'Total Impressions', hubCount(k.now.impressions), 'impressions', Mkt.blue, sp: spark((p) => p.impressions.toDouble())),
      kpi('ov_kpi_leads', Icons.filter_alt_outlined, 'Total Leads', hubCount(k.now.leads), 'leads', Mkt.pink, sp: spark((p) => p.leads.toDouble())),
      kpi('ov_kpi_cpl', Icons.sell_outlined, 'Cost per Lead (CPL)', hubInr(k.now.cpl), 'cpl', Mkt.teal, lowerIsBetter: true, sp: [for (final p in t) ?p.cpl]),
      kpi('ov_kpi_ctr', Icons.ads_click_rounded, 'Avg. Click-Through Rate', hubPct(k.now.ctr), 'ctr', Mkt.warn, sp: spark((p) => p.impressions == 0 ? 0 : p.clicks * 100 / p.impressions)),
    ]);
  }
}

class _TrendCard extends StatefulWidget {
  const _TrendCard({required this.trend});
  final List<HubTrendPoint> trend;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  String _mode = 'spend';

  @override
  Widget build(BuildContext context) {
    final t = widget.trend;
    final HubSeries series = switch (_mode) {
      'leads' => HubSeries('Leads', Mkt.blue, [for (final p in t) p.leads.toDouble()], bars: true),
      'cpl' => HubSeries('Cost per lead (₹)', Mkt.pink, [for (final p in t) p.cpl]),
      _ => HubSeries('Spend (₹)', Mkt.primaryLight, [for (final p in t) p.spend], bars: true),
    };
    final empty = series.values.every((v) => v == null || v == 0);
    return MktCard(
      title: 'Campaign Performance Trend',
      icon: Icons.show_chart_rounded,
      trailing: HubToggle(keyPrefix: 'ov_trend', value: _mode, options: const [('spend', 'Spend'), ('leads', 'Leads'), ('cpl', 'CPL')], onChanged: (v) => setState(() => _mode = v)),
      child: empty
          ? MktEmpty(_mode == 'spend' ? 'No ad spend in this period. Import from Meta Ads Manager or type a day\'s figures.' : (_mode == 'leads' ? 'No leads are tagged to a campaign in this period.' : 'Cost per lead needs both spend and leads.'), icon: Icons.show_chart_rounded, height: 190)
          : KeyedSubtree(key: Key('ov_trend_chart_$_mode'), child: HubChart(days: [for (final p in t) p.day], series: [series], valueLabel: _mode == 'leads' ? null : (v) => hubInr(v, compact: true))),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.o});
  final OverviewData o;

  @override
  Widget build(BuildContext context) {
    final total = o.leadsByType.fold<int>(0, (s, e) => s + e.leads);
    return MktCard(
      title: 'Leads by Campaign Type',
      icon: Icons.donut_large_rounded,
      child: total == 0
          ? const MktEmpty('No campaign leads in this period.', icon: Icons.donut_large_rounded, height: 190)
          : MktDonut(
              centerKey: const Key('ov_type_total'),
              centerValue: hubCount(total),
              centerLabel: 'Total Leads',
              size: 112,
              slices: [for (final s in o.leadsByType) (label: s.label, value: s.leads.toDouble(), trailing: '${s.pct}% (${s.leads})')],
            ),
    );
  }
}

class _ActiveCampaigns extends ConsumerStatefulWidget {
  const _ActiveCampaigns({required this.o, required this.onGo});
  final OverviewData o;
  final ValueChanged<String> onGo;

  @override
  ConsumerState<_ActiveCampaigns> createState() => _ActiveCampaignsState();
}

class _ActiveCampaignsState extends ConsumerState<_ActiveCampaigns> {
  String _status = 'active';

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final rows = o.rowsFor(_status);
    final counts = {'active': o.counts.active, 'paused': o.counts.paused, 'completed': o.counts.completed};
    return MktCard(
      title: 'Active Campaigns (${o.counts.active})',
      icon: Icons.campaign_outlined,
      link: 'View All',
      onLink: () => widget.onGo('campaigns'),
      linkKey: const Key('ov_view_all_campaigns'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final s in const [('active', 'Active'), ('paused', 'Paused'), ('completed', 'Completed')])
              Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('ov_status_${s.$1}'), label: s.$2, count: counts[s.$1], selected: _status == s.$1, onTap: () => setState(() => _status = s.$1))),
          ]),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          MktEmpty(counts[_status] == 0 ? 'No ${_status == 'active' ? 'active' : _status} campaigns. Use New Campaign to add one.' : 'Nothing to show.', icon: Icons.campaign_outlined, height: 120)
        else
          MktTable(
            key: const Key('ov_campaign_table'),
            minWidth: 640,
            columns: const [MktCol('Campaign', flex: 4), MktCol('Objective', flex: 3), MktCol('Spend', flex: 2, align: Alignment.centerRight), MktCol('Leads', flex: 2, align: Alignment.centerRight), MktCol('CPL', flex: 2, align: Alignment.centerRight), MktCol('CTR', flex: 2, align: Alignment.centerRight), MktCol('Status', flex: 3)],
            onRowTap: (i) => showCampaignDetail(context, ref, rows[i].id),
            rowKeys: [for (final r in rows) Key('ov_row_${r.id}')],
            rows: [
              for (final r in rows)
                [
                  Row(children: [
                    HubThumb(url: r.thumbUrl, size: 30, radius: 8),
                    const SizedBox(width: 8),
                    Flexible(child: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700))),
                  ]),
                  Padding(padding: const EdgeInsets.only(right: 6), child: Text(hubObjectiveLabel(r.objective), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft))),
                  Text(hubInr(r.spend, compact: true), style: mktText(12)),
                  Text('${r.leads}', style: mktText(12)),
                  Text(hubInr(r.cpl), style: mktText(12)),
                  Text(hubPct(r.ctr), style: mktText(12)),
                  HubStatusChip(status: r.status, metaStatus: r.metaStatus),
                ],
            ],
          ),
      ]),
    );
  }
}

class _CreativesCard extends ConsumerWidget {
  const _CreativesCard({required this.o, required this.onGo});
  final OverviewData o;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MktCard(
        title: 'Creative Performance',
        icon: Icons.image_outlined,
        link: 'View All',
        onLink: () => onGo('creatives'),
        linkKey: const Key('ov_view_all_ads'),
        child: o.topAds.isEmpty
            ? Column(children: [
                const MktEmpty('No ads yet. Add the ads of a campaign (with a link to the creative) to see the best ones here.', icon: Icons.image_outlined, height: 110),
                TextButton(key: const Key('ov_add_ad'), onPressed: () => showAdEditor(context, ref), child: const Text('+ Add an ad')),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Top Performing Creatives', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.inkSoft)),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, box) {
                  final cols = box.maxWidth >= 420 ? 3 : (box.maxWidth >= 280 ? 2 : 1);
                  final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                  return Wrap(spacing: 10, runSpacing: 10, children: [for (final a in o.topAds) SizedBox(width: w, child: _AdTile(ad: a))]);
                }),
              ]),
      );
}

class _AdTile extends ConsumerWidget {
  const _AdTile({required this.ad});
  final HubAdRow ad;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
        key: Key('ov_ad_${ad.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => ad.creativeUrl.isNotEmpty ? hubOpenLink(ad.creativeUrl) : showAdEditor(context, ref, ad: ad),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Mkt.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(builder: (context, box) => HubThumb(url: ad.thumbUrl, format: ad.format, size: box.maxWidth, radius: 9)),
            const SizedBox(height: 6),
            Text(ad.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, weight: FontWeight.w700)),
            Text(ad.campaign, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, color: Mkt.inkSoft)),
            if (adMetaNote(ad.metaStatus).isNotEmpty) Text(adMetaNote(ad.metaStatus), key: Key('ov_ad_meta_${ad.id}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, weight: FontWeight.w700, color: Mkt.warn)),
            const SizedBox(height: 4),
            Text('${hubCount(ad.results)} results · CTR ${hubPct(ad.ctr)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            MktChip('Cost/result ${hubInr(ad.costPerResult)}', color: adVerdictColor(ad.verdict)),
          ]),
        ),
      );
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.o});
  final OverviewData o;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Campaign Insights & Actions',
        icon: Icons.lightbulb_outline_rounded,
        child: o.insights.isEmpty
            ? const MktEmpty('Nothing to point out for this period.', icon: Icons.lightbulb_outline_rounded, height: 70)
            : Column(key: const Key('ov_insights'), crossAxisAlignment: CrossAxisAlignment.start, children: [for (final i in o.insights) InsightLine(insight: i)]),
      );
}
