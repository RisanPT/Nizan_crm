import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';

/// Lead Report → Lead Stages: the pipeline from enquiry to booking. The four stages group the CRM's own statuses (Contacted, Qualified,
/// Follow-up and Pending Lost Approval are all "In Progress"; Lost is "Not Converted"). The CRM keeps no history of when a status
/// changed, so the trend shows the stage the leads that arrived each day are in NOW.
class LeadStagesTab extends ConsumerWidget {
  const LeadStagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => LrAsync<StagesData>(
        value: ref.watch(leadStagesProvider),
        listKey: const Key('lr_stages_list'),
        builder: (context, s) {
          final k = s.kpis;
          StageRow? stage(String key) => s.stages.where((r) => r.key == key).firstOrNull;
          Widget tile(String key, IconData icon, String label, int value, String stageKey, Color tint, {bool lowerIsBetter = false}) {
            final r = stage(stageKey);
            return leadKpi(key: key, icon: icon, label: r?.pct == null ? label : '$label · ${pctText(r!.pct)}', value: '$value', change: r?.change, lowerIsBetter: lowerIsBetter, tint: tint);
          }

          return [
            MktKpiRow(minWidth: 180, children: [
              leadKpi(key: 'lr_st_total', icon: Icons.groups_2_outlined, label: 'Total Leads', value: '${k.total}', change: k.change['total']),
              tile('lr_st_new', Icons.fiber_new_rounded, 'New', k.newLeads, 'new', Mkt.blue),
              tile('lr_st_progress', Icons.timelapse_rounded, 'In Progress', k.inProgress, 'in_progress', Mkt.warn),
              tile('lr_st_lost', Icons.person_off_outlined, 'Not Converted', k.notConverted, 'not_converted', Mkt.bad, lowerIsBetter: true),
              tile('lr_st_converted', Icons.check_circle_outline_rounded, 'Converted', k.converted, 'converted', Mkt.good),
            ]),
            const SizedBox(height: 12),
            MktGrid(breakpoint: 980, rows: [
              [(4, _Pipeline(s: s)), (5, _StageTrend(s: s)), (3, _Distribution(s: s))],
              [(6, _Statuses(s: s)), (6, _Quality(s: s))],
            ]),
          ];
        },
      );
}

class _Pipeline extends StatelessWidget {
  const _Pipeline({required this.s});
  final StagesData s;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Pipeline Overview',
        subtitle: 'Each stage as a share of all leads',
        icon: Icons.filter_alt_outlined,
        child: LeadFunnelView(
          keyPrefix: 'lr_pipe',
          colorOf: leadStageColor,
          funnel: Funnel(total: s.kpis.total, steps: [
            FunnelStep(key: 'leads', label: 'Total Leads', count: s.kpis.total, pct: s.kpis.total == 0 ? null : 100),
            for (final r in s.stages) FunnelStep(key: r.key, label: r.label, count: r.count, pct: r.pct),
          ]),
        ),
      );
}

class _StageTrend extends StatelessWidget {
  const _StageTrend({required this.s});
  final StagesData s;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Stage-wise Trend',
        subtitle: 'Leads by the day they arrived, in the stage they are in now${s.trend.granularity == 'week' ? ' (by week)' : ''}',
        icon: Icons.show_chart_rounded,
        child: KeyedSubtree(
          key: const Key('lr_st_trend'),
          child: LeadLineChart(rows: s.trend.rows, series: [
            (key: 'new', label: 'New', color: leadStageColor('new'), value: (r) => r.newLeads),
            (key: 'in_progress', label: 'In Progress', color: leadStageColor('in_progress'), value: (r) => r.inProgress),
            (key: 'not_converted', label: 'Not Converted', color: leadStageColor('not_converted'), value: (r) => r.notConverted),
            (key: 'converted', label: 'Converted', color: leadStageColor('converted'), value: (r) => r.converted),
          ]),
        ),
      );
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.s});
  final StagesData s;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Stage Distribution',
        icon: Icons.donut_large_rounded,
        child: s.kpis.total == 0
            ? const MktEmpty('No leads in this range.', icon: Icons.donut_large_rounded, height: 150)
            : MktDonut(
                key: const Key('lr_st_donut'),
                centerKey: const Key('lr_st_donut_total'),
                size: 120,
                sideBySideFrom: 400,
                centerValue: '${s.kpis.total}',
                centerLabel: 'Total Leads',
                colors: [for (final r in s.stages) leadStageColor(r.key)],
                slices: [for (final r in s.stages) (label: r.label, value: r.count.toDouble(), trailing: pctText(r.pct))],
              ),
      );
}

class _Statuses extends StatelessWidget {
  const _Statuses({required this.s});
  final StagesData s;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'By CRM Status',
        subtitle: 'The seven statuses the stages are made of',
        icon: Icons.list_alt_rounded,
        child: MktTable(
          key: const Key('lr_st_statuses'),
          columns: const [MktCol('STATUS', flex: 4), MktCol('LEADS', flex: 2, align: Alignment.centerRight), MktCol('SHARE', flex: 2, align: Alignment.centerRight)],
          rows: [
            for (final r in s.statuses) [lrCell(r.status, bold: true), lrCell('${r.count}'), lrCell(pctText(r.pct), color: Mkt.inkSoft)],
          ],
        ),
      );
}

class _Quality extends StatelessWidget {
  const _Quality({required this.s});
  final StagesData s;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Lead Quality',
        subtitle: 'The CRM priority: Hot, Warm, Nurture, Cold — "Not rated" when a lead has none',
        icon: Icons.local_fire_department_outlined,
        child: s.qualityTotal == 0
            ? const MktEmpty('No leads in this range.', icon: Icons.local_fire_department_outlined, height: 120)
            : Column(key: const Key('lr_st_quality'), children: [
                for (final q in s.quality)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      SizedBox(width: 52, child: Text(q.key, style: mktText(12.5, weight: FontWeight.w700))),
                      Expanded(child: MktProgress(pct: (q.pct ?? 0).round(), color: leadQualityColor(q.key), showLabel: false)),
                      const SizedBox(width: 10),
                      SizedBox(width: 78, child: Text('${q.count} · ${pctText(q.pct)}', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft))),
                    ]),
                  ),
              ]),
      );
}
