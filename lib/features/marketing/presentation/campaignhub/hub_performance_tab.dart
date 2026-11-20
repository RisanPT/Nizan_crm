import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_audiences.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_export.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';

/// Campaigns → Performance: reach, impressions, clicks, CRM leads and cost per lead for the range (each with its change on the period
/// before), the trend, the objective-wise results, and the audiences & placements (top segments by age, gender and placement, from Ads
/// Manager breakdown exports). Reach is the sum of each day's reach, so a person reached on two days counts twice.
class HubPerformanceTab extends ConsumerWidget {
  const HubPerformanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hubPerformanceProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCampaignHub(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshCampaignHub(ref))]),
        data: (p) {
          final k = p.kpis;
          Widget kpi(String key, IconData icon, String label, String value, String changeKey, Color tint, {bool lowerIsBetter = false}) {
            final d = hubDelta(k.changeOf(changeKey), lowerIsBetter: lowerIsBetter);
            return MktKpiCard(key: Key(key), icon: icon, value: value, label: label, note: d?.text, good: d?.good, tint: tint);
          }

          return ListView(
            key: const Key('hub_performance_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const HubExportBar(type: 'performance'),
              MktKpiRow(minWidth: 176, children: [
                kpi('hp_kpi_reach', Icons.groups_outlined, 'Reach', hubCount(k.now.reach), 'reach', Mkt.primary),
                kpi('hp_kpi_impr', Icons.visibility_outlined, 'Impressions', hubCount(k.now.impressions), 'impressions', Mkt.blue),
                kpi('hp_kpi_clicks', Icons.ads_click_rounded, 'Clicks', hubCount(k.now.clicks), 'clicks', Mkt.teal),
                kpi('hp_kpi_leads', Icons.filter_alt_outlined, 'Leads', hubCount(k.now.leads), 'leads', Mkt.pink),
                kpi('hp_kpi_cpl', Icons.sell_outlined, 'Cost per Lead', hubInr(k.now.cpl), 'cpl', Mkt.warn, lowerIsBetter: true),
              ]),
              const SizedBox(height: 12),
              MktGrid(rows: [
                [(7, _TrendCard(trend: p.trend)), (5, _ObjectiveCard(p: p))],
                [(12, const AudiencesSection())],
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _TrendCard extends StatefulWidget {
  const _TrendCard({required this.trend});
  final List<HubTrendPoint> trend;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  String _mode = 'reach';

  static const _options = [('reach', 'Reach'), ('impressions', 'Impressions'), ('clicks', 'Clicks'), ('leads', 'Leads')];

  @override
  Widget build(BuildContext context) {
    final t = widget.trend;
    final (label, color, values) = switch (_mode) {
      'impressions' => ('Impressions', Mkt.blue, [for (final p in t) p.impressions.toDouble()]),
      'clicks' => ('Clicks', Mkt.teal, [for (final p in t) p.clicks.toDouble()]),
      'leads' => ('Leads', Mkt.pink, [for (final p in t) p.leads.toDouble()]),
      _ => ('Reach', Mkt.primaryLight, [for (final p in t) p.reach.toDouble()]),
    };
    final empty = values.every((v) => v == 0);
    return MktCard(
      title: 'Performance Trend',
      icon: Icons.show_chart_rounded,
      subtitle: _mode == 'reach' ? 'Reach adds up each day\'s reach' : (_mode == 'leads' ? 'Leads are the CRM\'s, by the day they arrived' : null),
      trailing: Flexible(child: SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: HubToggle(keyPrefix: 'hp_trend', value: _mode, options: _options, onChanged: (v) => setState(() => _mode = v)))),
      child: empty
          ? MktEmpty('No ${label.toLowerCase()} in this period.', icon: Icons.show_chart_rounded, height: 200)
          : KeyedSubtree(key: Key('hp_trend_chart_$_mode'), child: HubChart(days: [for (final p in t) p.day], series: [HubSeries(label, color, values)], height: 200)),
    );
  }
}

class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({required this.p});
  final HubPerformance p;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Objective-wise Results',
        icon: Icons.track_changes_rounded,
        subtitle: 'Campaigns that ran in this period',
        child: p.objectives.isEmpty
            ? const MktEmpty('No campaign had spend or leads in this period.', icon: Icons.track_changes_rounded, height: 160)
            : MktTable(
                key: const Key('hp_objectives'),
                minWidth: 420,
                columns: const [MktCol('Objective', flex: 4), MktCol('Campaigns', flex: 3, align: Alignment.centerRight), MktCol('Spend', flex: 3, align: Alignment.centerRight), MktCol('Leads', flex: 2, align: Alignment.centerRight), MktCol('CPL', flex: 3, align: Alignment.centerRight)],
                rowKeys: [for (final o in p.objectives) Key('hp_objective_${o.key}')],
                rows: [
                  for (final o in p.objectives)
                    [
                      Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700)),
                      Text('${o.campaigns}', style: mktText(12)),
                      Text(hubInr(o.spend, compact: true), style: mktText(12)),
                      Text('${o.leads}', style: mktText(12)),
                      Text(hubInr(o.cpl), style: mktText(12)),
                    ],
                ],
              ),
      );
}
