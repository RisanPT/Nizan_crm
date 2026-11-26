import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';

/// Lead Report → Overview: the range's leads by stage with the conversion rate, the funnel, where the leads came from, the follow-ups, how
/// the leads and bookings moved over the range, the campaigns that brought the most leads and the leads by campaign type. Every figure is
/// the CRM's own lead data, counted once on the server (the campaign figures are the Campaigns hub's); the change is against the period of
/// the same length right before. "Converted" is the CRM stage; the conversion rate counts BOOKINGS (leads linked to a live booking).
class LeadOverviewTab extends ConsumerWidget {
  const LeadOverviewTab({super.key, required this.onGo});

  /// Opens another tab of the Lead Report (the cards' "View All" links).
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LrAsync<LeadOverview>(
        value: ref.watch(leadOverviewProvider),
        listKey: const Key('lr_overview_list'),
        builder: (context, o) {
          final k = o.kpis;
          return [
            MktKpiRow(minWidth: 168, children: [
              leadKpi(key: 'lr_kpi_total', icon: Icons.groups_2_outlined, label: 'Total Leads', value: '${k.total}', change: k.change['total']),
              leadKpi(key: 'lr_kpi_new', icon: Icons.fiber_new_rounded, label: 'New Leads', value: '${k.newLeads}', change: k.change['new'], tint: Mkt.blue),
              leadKpi(key: 'lr_kpi_progress', icon: Icons.timelapse_rounded, label: 'In Progress', value: '${k.inProgress}', change: k.change['inProgress'], tint: Mkt.warn),
              leadKpi(key: 'lr_kpi_lost', icon: Icons.person_off_outlined, label: 'Not Converted', value: '${k.notConverted}', change: k.change['notConverted'], lowerIsBetter: true, tint: Mkt.bad),
              leadKpi(key: 'lr_kpi_converted', icon: Icons.check_circle_outline_rounded, label: 'Converted (stage)', value: '${k.converted}', change: k.change['converted'], tint: Mkt.good),
              leadKpi(key: 'lr_kpi_bookings', icon: Icons.event_available_outlined, label: 'Bookings', value: '${k.bookings}', change: k.change['bookings'], tint: Mkt.teal),
              leadKpi(key: 'lr_kpi_rate', icon: Icons.percent_rounded, label: 'Conversion Rate', value: pctText(k.conversionRate), change: k.change['conversionRate'], points: true, tint: Mkt.pink),
            ]),
            if (k.converted != k.bookings)
              LrNote('Conversion rate = bookings ÷ leads. A booking is a lead linked to a live CRM booking; "Converted" is the CRM stage — ${k.converted > k.bookings ? '${k.converted - k.bookings} Converted lead${k.converted - k.bookings == 1 ? ' has' : 's have'} no live booking (cancelled or still pending)' : '${k.bookings - k.converted} booked lead${k.bookings - k.converted == 1 ? ' is' : 's are'} not in the Converted stage'}.', key: const Key('lr_kpi_booking_note')),
            ?cappedNote(o.capped),
            const SizedBox(height: 12),
            MktGrid(breakpoint: 980, rows: [
              [(5, _FunnelCard(o: o)), (3, _SourcesCard(o: o, onGo: onGo)), (4, _FollowUpsCard(o: o, onGo: onGo))],
              [(6, _TrendCard(o: o)), (6, _CampaignsCard(o: o, onGo: onGo))],
              [(12, LeadCampaignTypesCard(rows: o.campaignTypes))],
            ]),
          ];
        },
      );
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.o});
  final LeadOverview o;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Lead Funnel',
        subtitle: 'Total → qualified → hot → bookings',
        icon: Icons.filter_alt_outlined,
        child: LeadFunnelView(funnel: o.funnel, keyPrefix: 'lr_ov_funnel'),
      );
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.o, required this.onGo});
  final LeadOverview o;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context) {
    final groups = o.sources.groups.where((g) => g.count > 0).toList();
    return MktCard(
      title: 'Lead Sources',
      icon: Icons.hub_outlined,
      link: 'View Details',
      linkKey: const Key('lr_ov_sources_link'),
      onLink: () => onGo('sources'),
      child: groups.isEmpty
          ? const MktEmpty('No leads in this range.', icon: Icons.hub_outlined, height: 150)
          : MktDonut(
              key: const Key('lr_ov_sources_donut'),
              centerKey: const Key('lr_ov_sources_total'),
              size: 120,
              sideBySideFrom: 400,
              centerValue: '${o.sources.total}',
              centerLabel: 'Total Leads',
              colors: [for (final g in groups) sourceGroupColor(g.key)],
              slices: [for (final g in groups) (label: g.label, value: g.count.toDouble(), trailing: pctText(g.pct))],
            ),
    );
  }
}

class _FollowUpsCard extends StatelessWidget {
  const _FollowUpsCard({required this.o, required this.onGo});
  final LeadOverview o;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context) {
    final f = o.followUps;
    Widget stat(String key, String label, int n, Color c) => Container(
          key: Key(key),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Mkt.tint(c, 0.08), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('$n', style: mktText(20, weight: FontWeight.w800, color: c))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, weight: FontWeight.w600, color: Mkt.inkSoft)),
          ]),
        );
    return MktCard(
      title: 'Follow-ups',
      icon: Icons.notifications_active_outlined,
      link: 'View All',
      linkKey: const Key('lr_ov_followups_link'),
      onLink: () => onGo('followups'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(width: w, child: stat('lr_ov_fu_due', 'Due', f.due, Mkt.primary)),
            SizedBox(width: w, child: stat('lr_ov_fu_today', 'Today', f.today, Mkt.warn)),
            SizedBox(width: w, child: stat('lr_ov_fu_overdue', 'Overdue', f.overdue, Mkt.bad)),
            SizedBox(width: w, child: stat('lr_ov_fu_completed', 'Completed', f.completed, Mkt.good)),
          ]);
        }),
        if (f.overdueBefore > 0) LrNote('${f.overdueBefore} more ${f.overdueBefore == 1 ? 'follow-up is' : 'follow-ups are'} still overdue from before this range.', icon: Icons.warning_amber_rounded, color: Mkt.bad),
      ]),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.o});
  final LeadOverview o;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Conversion Trend',
        subtitle: 'Leads by the day they arrived, and how many are booked now${o.trend.granularity == 'week' ? ' (by week)' : ''}',
        icon: Icons.show_chart_rounded,
        child: KeyedSubtree(
          key: const Key('lr_ov_trend'),
          child: LeadLineChart(rows: o.trend.rows, series: [
            (key: 'leads', label: 'Leads', color: Mkt.primaryLight, value: (r) => r.leads),
            (key: 'bookings', label: 'Bookings', color: Mkt.good, value: (r) => r.bookings),
          ]),
        ),
      );
}

class _CampaignsCard extends StatelessWidget {
  const _CampaignsCard({required this.o, required this.onGo});
  final LeadOverview o;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context) {
    final c = o.campaigns;
    return MktCard(
      title: 'Top Campaigns (by Leads)',
      subtitle: 'Cost per lead = ad spend of these dates ÷ the campaign\'s leads',
      icon: Icons.campaign_outlined,
      link: 'View All',
      linkKey: const Key('lr_ov_campaigns_link'),
      onLink: () => onGo('sources'),
      child: c.rows.isEmpty
          ? const MktEmpty('No campaign is tagged on the leads in this range.', icon: Icons.campaign_outlined, height: 150)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MktTable(
                key: const Key('lr_ov_campaigns'),
                columns: const [MktCol('Campaign', flex: 4), MktCol('Source', flex: 3), MktCol('Leads', flex: 2, align: Alignment.centerRight), MktCol('CPL', flex: 3, align: Alignment.centerRight)],
                rows: [
                  for (final r in c.rows) [lrCell(r.title, bold: true), lrCell(r.channel.isEmpty ? '—' : r.channel, color: Mkt.inkSoft), lrCell('${r.leads}'), lrCell(costText(r.costPerLead))],
                ],
              ),
              if (c.costs.campaignsWithSpend == 0) const LrNote('No ad spend is recorded for these dates (import a Meta Ads export in Campaigns), so there is no cost per lead to show.'),
              if (c.untagged > 0) LrNote('${c.untagged} lead${c.untagged == 1 ? '' : 's'} in this range ${c.untagged == 1 ? 'has' : 'have'} no campaign.'),
            ]),
    );
  }
}
