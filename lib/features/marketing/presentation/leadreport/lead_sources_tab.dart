import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';

/// Lead Report → Sources: where the leads came from. Sources are the CRM's own lead sources (Instagram's two pages, Meta Ads, WhatsApp,
/// YouTube, Website, and Reference / Walk-in / Other under "Others"). A campaign's spend and cost per lead are the Campaigns hub's for the
/// same dates and brand: the ad spend of the days in the range ÷ the campaign's leads of the range; no spend recorded shows "—".
class LeadSourcesTab extends ConsumerWidget {
  const LeadSourcesTab({super.key});

  static const _icons = {'instagram': Icons.camera_alt_outlined, 'meta_ads': Icons.campaign_outlined, 'whatsapp': Icons.chat_outlined, 'youtube': Icons.smart_display_outlined, 'website': Icons.language_rounded, 'others': Icons.more_horiz_rounded};

  @override
  Widget build(BuildContext context, WidgetRef ref) => LrAsync<SourcesData>(
        value: ref.watch(leadSourcesProvider),
        listKey: const Key('lr_sources_list'),
        builder: (context, s) {
          final shown = s.groups.where((g) => g.count > 0).toList();
          final c = s.campaigns;
          return [
            MktKpiRow(minWidth: 168, children: [
              for (final g in s.groups) leadKpi(key: 'lr_src_${g.key}', icon: _icons[g.key] ?? Icons.hub_outlined, label: '${g.label} Leads', value: '${g.count}', change: g.change?.toDouble(), tint: sourceGroupColor(g.key)),
            ]),
            const SizedBox(height: 12),
            MktGrid(breakpoint: 980, rows: [
              [
                (5, MktCard(
                  title: 'Lead Sources Distribution',
                  icon: Icons.donut_large_rounded,
                  child: shown.isEmpty
                      ? const MktEmpty('No leads in this range.', icon: Icons.donut_large_rounded, height: 150)
                      : MktDonut(
                          key: const Key('lr_src_donut'),
                          centerKey: const Key('lr_src_donut_total'),
                          size: 130,
                          sideBySideFrom: 400,
                          centerValue: '${s.total}',
                          centerLabel: 'Total Leads',
                          colors: [for (final g in shown) sourceGroupColor(g.key)],
                          slices: [for (final g in shown) (label: g.label, value: g.count.toDouble(), trailing: pctText(g.pct))],
                        ),
                )),
                (7, MktCard(
                  title: 'Top Campaigns (by Leads)',
                  subtitle: 'Spend and cost per lead for these dates — the Campaigns hub\'s figures',
                  icon: Icons.campaign_outlined,
                  child: c.rows.isEmpty
                      ? const MktEmpty('No campaign is tagged on the leads in this range.', icon: Icons.campaign_outlined, height: 150)
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          MktTable(
                            key: const Key('lr_src_campaigns'),
                            minWidth: 600,
                            columns: const [MktCol('CAMPAIGN', flex: 4), MktCol('SOURCE', flex: 3), MktCol('LEADS', flex: 2, align: Alignment.centerRight), MktCol('BOOKINGS', flex: 2, align: Alignment.centerRight), MktCol('SPEND', flex: 3, align: Alignment.centerRight), MktCol('CPL', flex: 3, align: Alignment.centerRight)],
                            rows: [for (final r in c.rows) [lrCell(r.title, bold: true), lrCell(r.channel.isEmpty ? '—' : r.channel, color: Mkt.inkSoft), lrCell('${r.leads}'), lrCell('${r.bookings}'), lrCell(costText(r.spend)), lrCell(costText(r.costPerLead))]],
                          ),
                          if (c.costs.campaignsWithSpend == 0) const LrNote('No ad spend is recorded for these dates (import a Meta Ads export in Campaigns), so there is no cost per lead to show.'),
                          if (c.untagged > 0) LrNote('${c.untagged} lead${c.untagged == 1 ? '' : 's'} in this range ${c.untagged == 1 ? 'has' : 'have'} no campaign.'),
                        ]),
                )),
              ],
              [(12, LeadCampaignTypesCard(rows: s.campaignTypes))],
              [
                (12, MktCard(
                  title: 'Source Breakdown',
                  subtitle: 'Every lead source in the CRM',
                  icon: Icons.table_rows_outlined,
                  child: s.sources.isEmpty
                      ? const MktEmpty('No leads in this range.', icon: Icons.table_rows_outlined, height: 100)
                      : MktTable(
                          key: const Key('lr_src_table'),
                          minWidth: 640,
                          columns: const [MktCol('SOURCE', flex: 4), MktCol('LEADS', flex: 2, align: Alignment.centerRight), MktCol('SHARE', flex: 2, align: Alignment.centerRight), MktCol('QUALIFIED', flex: 2, align: Alignment.centerRight), MktCol('HOT', flex: 2, align: Alignment.centerRight), MktCol('BOOKINGS', flex: 2, align: Alignment.centerRight), MktCol('RATE', flex: 2, align: Alignment.centerRight)],
                          rows: [for (final r in s.sources) [lrCell(r.label, bold: true), lrCell('${r.leads}'), lrCell(pctText(r.share), color: Mkt.inkSoft), lrCell('${r.qualified}'), lrCell('${r.hot}'), lrCell('${r.bookings}'), lrCell(pctText(r.rate))]],
                        ),
                )),
              ],
            ]),
          ];
        },
      );
}
