import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/campaign_detail.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_export.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';

/// Campaigns → Leads & Conversions: the CRM's leads that came through campaigns, joined to their bookings — counted exactly as the Lead
/// Report counts them. A booking is a lead linked to a live booking (one per lead); a lead is qualified when it reached Qualified or beyond
/// (or has booked); the conversion rate is bookings ÷ leads; bookings are counted on the day their lead arrived; booking value is after
/// discount with GST backed out. Cost per lead and ROAS use the spend imported or typed for the same campaigns, inside the dates.
class HubLeadsTab extends ConsumerWidget {
  const HubLeadsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hubLeadsProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCampaignHub(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshCampaignHub(ref))]),
        data: (d) {
          final k = d.kpis;
          Widget kpi(String key, IconData icon, String label, String value, Color tint, {String? changeKey, String? note, bool points = false}) {
            final dl = changeKey == null ? null : hubDelta(k.changeOf(changeKey), points: points);
            return MktKpiCard(key: Key(key), icon: icon, value: value, label: label, note: dl?.text ?? note, good: dl?.good, tint: tint);
          }

          return ListView(
            key: const Key('hub_leads_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const HubExportBar(type: 'lead'),
              MktKpiRow(minWidth: 176, children: [
                kpi('ld_kpi_leads', Icons.filter_alt_outlined, 'Total Leads', hubCount(k.now.leads), Mkt.primary, changeKey: 'leads'),
                kpi('ld_kpi_qualified', Icons.verified_outlined, 'Qualified Leads', hubCount(k.now.qualified), Mkt.blue, changeKey: 'qualified', note: k.now.leads == 0 ? null : '${(k.now.qualified * 100 / k.now.leads).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}% of leads'),
                kpi('ld_kpi_bookings', Icons.event_available_outlined, 'Bookings', hubCount(k.now.bookings), Mkt.good, changeKey: 'bookings'),
                kpi('ld_kpi_conversion', Icons.trending_up_rounded, 'Conversion Rate', hubPct(k.now.conversionRate, digits: 1), Mkt.warn, changeKey: 'conversionRate', points: true),
                kpi('ld_kpi_value', Icons.currency_rupee_rounded, 'Booking Value (ex-GST)', hubInr(k.now.revenue, compact: true), Mkt.pink, changeKey: 'revenue'),
              ]),
              const SizedBox(height: 12),
              MktGrid(rows: [
                [(5, _FunnelCard(d: d)), (7, _TrendCard(d: d))],
                [(12, _TableCard(d: d))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.d});
  final LeadsData d;

  @override
  Widget build(BuildContext context) {
    final top = d.funnel.isEmpty ? 0 : d.funnel.first.count;
    const colors = [Mkt.primary, Mkt.primaryLight, Mkt.pink];
    return MktCard(
      title: 'Lead Funnel',
      icon: Icons.filter_alt_outlined,
      child: top == 0
          ? const MktEmpty('No leads are tagged to a campaign in this period.', icon: Icons.filter_alt_outlined, height: 190)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < d.funnel.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FractionallySizedBox(
                    widthFactor: (d.funnel[i].count / top).clamp(0.28, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      key: Key('ld_funnel_${d.funnel[i].key}'),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Expanded(child: Text('${d.funnel[i].label}  ${d.funnel[i].count}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w800, color: Colors.white))),
                        Text(d.funnel[i].pct == null ? '' : hubPct(d.funnel[i].pct, digits: 1), style: mktText(11.5, weight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text('Lead quality', style: mktText(11, weight: FontWeight.w700, color: Mkt.inkSoft)),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final q in [...kHubQualities, if ((d.quality[kHubNotRated] ?? 0) > 0) kHubNotRated]) MktChip('$q ${d.quality[q] ?? 0}', key: Key('ld_quality_${q.replaceAll(' ', '_')}'), color: _qualityColor(q)),
              ]),
            ]),
    );
  }
}

Color _qualityColor(String q) => switch (q) {
      'Hot' => Mkt.bad,
      'Warm' => Mkt.warn,
      'Nurture' => Mkt.teal,
      'Cold' => Mkt.blue,
      _ => Mkt.grey,
    };

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.d});
  final LeadsData d;

  @override
  Widget build(BuildContext context) {
    final series = [HubSeries('Leads', Mkt.primaryLight, [for (final p in d.trend) p.leads.toDouble()]), HubSeries('Bookings', Mkt.good, [for (final p in d.trend) p.bookings.toDouble()])];
    final empty = d.trend.every((p) => p.leads == 0 && p.bookings == 0);
    return MktCard(
      title: 'Conversion Trend',
      icon: Icons.show_chart_rounded,
      subtitle: 'Bookings are placed on the day their lead arrived',
      child: empty
          ? const MktEmpty('No leads in this period.', icon: Icons.show_chart_rounded, height: 190)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              HubLegend(series: series),
              const SizedBox(height: 8),
              KeyedSubtree(key: const Key('ld_trend'), child: HubChart(days: [for (final p in d.trend) p.day], series: series, height: 190)),
            ]),
    );
  }
}

class _TableCard extends ConsumerWidget {
  const _TableCard({required this.d});
  final LeadsData d;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MktCard(
        title: 'Campaign-wise Leads & Conversions',
        icon: Icons.table_rows_outlined,
        subtitle: 'Leads → bookings → booking value (after discount, GST backed out)',
        child: d.rows.isEmpty
            ? const MktEmpty('No campaign has leads or spend in this period.', icon: Icons.table_rows_outlined, height: 110)
            : MktTable(
                key: const Key('ld_table'),
                minWidth: 860,
                columns: const [MktCol('Campaign', flex: 5), MktCol('Leads', flex: 2, align: Alignment.centerRight), MktCol('Qualified', flex: 2, align: Alignment.centerRight), MktCol('Bookings', flex: 2, align: Alignment.centerRight), MktCol('Conv.', flex: 2, align: Alignment.centerRight), MktCol('Booking value (ex-GST)', flex: 3, align: Alignment.centerRight), MktCol('Spend', flex: 3, align: Alignment.centerRight), MktCol('ROAS', flex: 2, align: Alignment.centerRight)],
                onRowTap: (i) => showCampaignDetail(context, ref, d.rows[i].id),
                rowKeys: [for (final r in d.rows) Key('ld_row_${r.id}')],
                rows: [
                  for (final r in d.rows)
                    [
                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700))),
                      Text('${r.leads}', style: mktText(12)),
                      Text('${r.qualified}', style: mktText(12)),
                      Text('${r.bookings}', style: mktText(12)),
                      Text(hubPct(r.conversionRate, digits: 1), style: mktText(12)),
                      Text(hubInr(r.revenue, compact: true), style: mktText(12)),
                      Text(hubInr(r.spend, compact: true), style: mktText(12)),
                      Text(hubRatio(r.roas), style: mktText(12)),
                    ],
                ],
              ),
      );
}
