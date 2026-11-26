import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/campaign_detail.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_export.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Campaigns → Budget & Spend: the budget set per campaign against the spend that was imported or typed. Two different spend figures, each
/// named for what it is — never two "Total Spend"s:
///  • SPENT TO DATE — the campaigns that HAVE a budget, everything they spent up to the end of the selected dates (what budget, remaining and
///    utilisation compare with);
///  • SPEND IN THIS PERIOD — every campaign, only the days inside the selected dates (the daily bars and the donut add up to it).
/// A campaign with no budget says "No budget set" and its spend is reported on its own.
class HubBudgetTab extends ConsumerWidget {
  const HubBudgetTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hubBudgetProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCampaignHub(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshCampaignHub(ref))]),
        data: (b) {
          final s = b.summary;
          final f = ref.watch(teamFilterProvider);
          final delta = hubDelta(s.utilisationChangePts, points: true);
          final hasBudget = s.totalBudget > 0;
          return ListView(
            key: const Key('hub_budget_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const HubExportBar(type: 'spend'),
              MktKpiRow(minWidth: 176, children: [
                MktKpiCard(key: const Key('bd_kpi_budget'), icon: Icons.account_balance_wallet_outlined, value: hasBudget ? hubInr(s.totalBudget, compact: true) : 'No budget set', label: 'Total Budget', note: hasBudget ? '${s.budgetedCampaigns} campaign${s.budgetedCampaigns == 1 ? '' : 's'}' : null, tint: Mkt.primary),
                MktKpiCard(key: const Key('bd_kpi_spent'), icon: Icons.payments_outlined, value: hasBudget ? hubInr(s.spentToDate, compact: true) : '—', label: 'Spent to Date', note: 'Budgeted campaigns, to ${hubDay(f.toDay, pattern: 'd MMM')}', tint: Mkt.pink),
                MktKpiCard(key: const Key('bd_kpi_period'), icon: Icons.date_range_rounded, value: hubInr(s.spendInPeriod, compact: true), label: 'Spend in This Period', note: 'All campaigns, ${MktDateRangePill.label(f.from, f.to)}', tint: Mkt.blue),
                MktKpiCard(key: const Key('bd_kpi_remaining'), icon: Icons.hourglass_bottom_rounded, value: s.overBy > 0 ? 'Over by ${hubInr(s.overBy, compact: true)}' : hubInr(s.remaining, compact: true), label: 'Remaining', note: s.overBy > 0 || s.remainingPct == null ? null : '${hubPct(s.remainingPct, digits: 1)} left', good: s.overBy > 0 ? false : null, tint: Mkt.warn),
                MktKpiCard(key: const Key('bd_kpi_util'), icon: Icons.speed_rounded, value: hubPct(s.utilisationPct, digits: 1), label: 'Budget Utilization', note: delta?.text, good: null, tint: Mkt.good),
              ]),
              if (s.unbudgetedSpendInPeriod > 0) ...[
                const SizedBox(height: 10),
                Container(
                  key: const Key('bd_unbudgeted_note'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Mkt.tint(Mkt.warn, 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Mkt.warn),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${hubInr(s.unbudgetedSpendInPeriod)} was spent in this period on ${s.unbudgetedCampaigns == 1 ? 'a campaign' : 'campaigns'} with no budget set. It is not part of the totals above.', style: mktText(12, height: 1.3))),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              MktGrid(rows: [
                [(7, _DailyCard(b: b)), (5, _SplitCard(b: b))],
                [(12, _TableCard(b: b))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.b});
  final BudgetData b;

  @override
  Widget build(BuildContext context) {
    final empty = b.daily.every((d) => d.spend == 0);
    return MktCard(
      title: 'Daily Spend Trend',
      icon: Icons.bar_chart_rounded,
      subtitle: 'Spend in this period, day by day',
      child: empty
          ? const MktEmpty('No spend in this period. Import from Meta Ads Manager or type a day\'s figures.', icon: Icons.bar_chart_rounded, height: 200)
          : KeyedSubtree(key: const Key('bd_daily'), child: HubChart(days: [for (final d in b.daily) d.day], series: [HubSeries('Spend (₹)', Mkt.primaryLight, [for (final d in b.daily) d.spend], bars: true)], height: 200, valueLabel: (v) => hubInr(v, compact: true))),
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.b});
  final BudgetData b;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Spend by Campaign',
        icon: Icons.donut_large_rounded,
        subtitle: 'Spend in this period, all campaigns',
        child: b.split.isEmpty
            ? const MktEmpty('No spend to split in this period.', icon: Icons.donut_large_rounded, height: 200)
            : MktDonut(centerKey: const Key('bd_donut_total'), centerValue: hubInr(b.splitTotal, compact: true), centerLabel: 'In this period', size: 120, slices: [for (final s in b.split) (label: s.label, value: s.spend, trailing: hubPct(s.pct, digits: 1))]),
      );
}

class _TableCard extends ConsumerWidget {
  const _TableCard({required this.b});
  final BudgetData b;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MktCard(
        title: 'Budget by Campaign',
        icon: Icons.table_rows_outlined,
        subtitle: 'Campaigns that ran in this period · spent is up to the end of the selected dates',
        child: b.rows.isEmpty
            ? const MktEmpty('No campaign ran in this period.', icon: Icons.table_rows_outlined, height: 110)
            : MktTable(
                key: const Key('bd_table'),
                minWidth: 820,
                columns: const [MktCol('Campaign', flex: 5), MktCol('Budget', flex: 3, align: Alignment.centerRight), MktCol('Spent to date', flex: 3, align: Alignment.centerRight), MktCol('Remaining', flex: 3, align: Alignment.centerRight), MktCol('Used', flex: 4), MktCol('In this period', flex: 3, align: Alignment.centerRight)],
                onRowTap: (i) => showCampaignDetail(context, ref, b.rows[i].id),
                rowKeys: [for (final r in b.rows) Key('bd_row_${r.id}')],
                rows: [
                  for (final r in b.rows)
                    [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                          Text(hubStatusLabel(r.status), style: mktText(10.5, color: hubStatusColor(r.status), weight: FontWeight.w700)),
                        ]),
                      ),
                      r.hasBudget ? Text(hubInr(r.budget, compact: true), style: mktText(12)) : Text('No budget set', key: Key('bd_no_budget_${r.id}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
                      Text(hubInr(r.spentToDate, compact: true), style: mktText(12)),
                      !r.hasBudget ? Text('—', style: mktText(12, color: Mkt.inkSoft)) : (r.overBy > 0 ? Text('Over by ${hubInr(r.overBy, compact: true)}', key: Key('bd_over_${r.id}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, weight: FontWeight.w700, color: Mkt.bad)) : Text(hubInr(r.remaining, compact: true), style: mktText(12))),
                      r.hasBudget ? Padding(padding: const EdgeInsets.only(right: 8), child: MktProgress(pct: (r.utilisationPct ?? 0).round(), color: r.overBy > 0 ? Mkt.bad : ((r.utilisationPct ?? 0) >= 90 ? Mkt.warn : Mkt.good), labelWidth: 40)) : Text('—', style: mktText(12, color: Mkt.inkSoft)),
                      Text(hubInr(r.spendInPeriod, compact: true), style: mktText(12)),
                    ],
                ],
              ),
      );
}
