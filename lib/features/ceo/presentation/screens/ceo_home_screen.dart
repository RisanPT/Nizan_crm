import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/work_profit_controller.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/data/work_profit.dart';
import 'package:nizan_crm/features/ceo/presentation/widgets/ceo_cards.dart';
import 'package:nizan_crm/features/ceo/services/ceo_service.dart';
import 'package:nizan_crm/features/dashboard/controllers/dashboard_analytics_provider.dart';
import 'package:nizan_crm/features/dashboard/data/dashboard_analytics.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart' show deltaPct, kDashBad, kDashGood;
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';
import 'package:nizan_crm/features/hr/analytics/service/hr_analytics_service.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';

/// The CEO's home: what needs a decision, what is stuck with the team, and how the company is doing — money, sales and
/// capacity, people and customers, strategy and risks. Every figure comes from an endpoint that already exists (or the two
/// small /ceo ones); each card loads and fails on its own, so one broken source never blanks the page.
class CeoHomeScreen extends ConsumerStatefulWidget {
  const CeoHomeScreen({super.key});

  @override
  ConsumerState<CeoHomeScreen> createState() => _CeoHomeScreenState();
}

class _CeoHomeScreenState extends ConsumerState<CeoHomeScreen> {
  // Built once: a query made inside build() would re-key the (auto-dispose) providers when the day rolls over.
  late final DashboardQuery _dash = DashboardQuery.thisMonth();
  late final ({int month, int year}) _period = (month: DateTime.now().month, year: DateTime.now().year);
  late final ({String from, String to}) _range = _monthRange();
  late final WorkProfitQuery _loss = _lossQuery();

  ({String from, String to}) _monthRange() {
    final (from, to) = FinanceQuery.monthBounds(DateTime.now());
    return (from: from, to: to);
  }

  WorkProfitQuery _lossQuery() {
    final (from, to) = FinanceQuery.monthBounds(DateTime.now());
    return WorkProfitQuery(from: from, to: to, flag: 'loss', sort: 'profit_asc', limit: 3);
  }

  Future<void> _refresh() async {
    ref.invalidate(ceoInboxProvider);
    ref.invalidate(ceoSignalsProvider);
    ref.invalidate(accountsDashboardSummaryProvider(_range));
    ref.invalidate(monthEndReviewProvider(_period));
    ref.invalidate(workProfitPageProvider(_loss));
    ref.invalidate(salesDashboardProvider(_dash));
    ref.invalidate(marketingInsightsProvider);
    ref.invalidate(hrAnalyticsSummaryProvider);
    ref.invalidate(companyProjectsProvider(null));
    ref.invalidate(planningOkrsProvider);
    // let the spinner run until the first (most important) card has answered, whatever the answer
    await ref.read(ceoInboxProvider.future).then<void>((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final inbox = ref.watch(ceoInboxProvider);
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 980;
        const gap = 14.0;
        final pad = box.maxWidth >= 600 ? 24.0 : 16.0;
        final colWidth = wide ? (box.maxWidth - pad * 2 - gap) / 2 : box.maxWidth - pad * 2;

        final inboxBody = CeoAsync(
          value: inbox,
          onRetry: () => ref.invalidate(ceoInboxProvider),
          builder: (data) => CeoInboxCards(inbox: data),
        );

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 18, pad, 32),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Overview', key: const Key('ceo_title'), style: TextStyle(fontSize: wide ? 26 : 22, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.4)),
                  Text(today, style: TextStyle(fontSize: 13, color: crm.textSecondary)),
                ]),
              ),
              IconButton(key: const Key('ceo_refresh'), tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
            ]),
            const SizedBox(height: 16),
            // The decisions come first, on any screen.
            inboxBody,
            const SizedBox(height: gap),
            Wrap(spacing: gap, runSpacing: gap, children: [
              SizedBox(width: colWidth, child: _MoneyCard(range: _range, period: _period, loss: _loss)),
              SizedBox(width: colWidth, child: _SalesCard(query: _dash)),
              SizedBox(width: colWidth, child: const _PeopleCard()),
              SizedBox(width: colWidth, child: const _StrategyCard()),
            ]),
          ],
        );
      }),
    );
  }
}

// ── small helpers ────────────────────────────────────────────────────────────

String _signedPct(double? v) => v == null ? '' : '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(0)}%';

/// A change worth showing in green/red: [higherIsBetter] says which way is good.
({String text, bool? good}) _change(num now, num prev, {bool higherIsBetter = true, String vs = 'last month'}) {
  final d = deltaPct(now, prev);
  if (d == null) return (text: '', good: null);
  if (d.abs() < 0.5) return (text: 'flat vs $vs', good: null);
  return (text: '${_signedPct(d)} vs $vs', good: (d > 0) == higherIsBetter);
}

Widget _subTitle(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: context.crmColors.textSecondary)),
    );

// ── Money ────────────────────────────────────────────────────────────────────

class _MoneyCard extends ConsumerWidget {
  const _MoneyCard({required this.range, required this.period, required this.loss});
  final ({String from, String to}) range;
  final ({int month, int year}) period;
  final WorkProfitQuery loss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final summary = ref.watch(accountsDashboardSummaryProvider(range));
    final review = ref.watch(monthEndReviewProvider(period));
    final work = ref.watch(workProfitPageProvider(loss));

    return CeoCard(
      title: 'Money',
      subtitle: DateFormat('MMMM yyyy').format(DateTime.now()),
      icon: Icons.account_balance_wallet_outlined,
      openRoute: '/accounts/dashboard',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CeoAsync(
          value: review,
          onRetry: () => ref.invalidate(monthEndReviewProvider(period)),
          builder: (r) {
            final rev = _change(r.revenue, r.revenuePrev);
            final hasTarget = r.revenueTarget != null && r.revenueTarget! > 0;
            final profitTarget = r.profitTarget != null && r.profitTarget! > 0;
            return CeoStatGrid(stats: [
              CeoStat(
                label: 'Revenue',
                value: rupeesShort(r.revenue),
                change: hasTarget ? '${(r.revenueTargetPct ?? 0).toStringAsFixed(0)}% of ${rupeesShort(r.revenueTarget!)} target' : rev.text,
                // part-way through the month a figure under target is not a failure: neutral until it is reached
                good: hasTarget ? ((r.revenueTargetPct ?? 0) >= 100 ? true : null) : rev.good,
                hint: hasTarget ? rev.text : null,
              ),
              CeoStat(
                label: 'Profit',
                value: rupeesShort(r.netProfit),
                change: profitTarget ? '${(r.profitTargetPct ?? 0).toStringAsFixed(0)}% of ${rupeesShort(r.profitTarget!)} target' : '${r.netMarginPct.toStringAsFixed(0)}% margin',
                good: r.netProfit < 0 ? false : (profitTarget ? ((r.profitTargetPct ?? 0) >= 100 ? true : null) : true),
                hint: profitTarget ? '${r.netMarginPct.toStringAsFixed(0)}% margin' : null,
              ),
              CeoStat(
                label: 'Runway',
                value: r.cashRunwayMonths == null ? '—' : '${r.cashRunwayMonths!.toStringAsFixed(1)} mo',
                hint: 'burn ${rupeesShort(r.burnRate)}/mo',
                good: r.cashRunwayMonths == null ? null : r.cashRunwayMonths! >= 6,
              ),
            ]);
          },
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: crm.border.faded(1.5)),
        const SizedBox(height: 12),
        _subTitle(context, 'Cash and dues, today'),
        CeoAsync(
          value: summary,
          onRetry: () => ref.invalidate(accountsDashboardSummaryProvider(range)),
          builder: (s) => CeoStatGrid(stats: [
            CeoStat(label: 'Cash + bank', value: rupeesShort(s.cashBankTotal)),
            CeoStat(label: 'Clients owe', value: rupeesShort(s.receivables.totalOutstanding), hint: '${rupeesShort(s.receivables.totalOverdue)} overdue'),
            CeoStat(
              label: 'Over 90 days',
              value: rupeesShort(s.receivables.days90),
              good: s.receivables.days90 <= 0 ? null : false,
              change: s.receivables.days90 > 0 ? 'chase these first' : null,
            ),
            CeoStat(label: 'We owe', value: rupeesShort(s.payables.totalOutstanding), hint: '${rupeesShort(s.payables.totalOverdue)} overdue'),
          ]),
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: crm.border.faded(1.5)),
        const SizedBox(height: 12),
        _subTitle(context, 'Works losing money this month'),
        CeoAsync(
          value: work,
          onRetry: () => ref.invalidate(workProfitPageProvider(loss)),
          builder: (p) {
            if (p.items.isEmpty) {
              return Row(children: [
                const Icon(Icons.check_circle_outline_rounded, color: kDashGood, size: 18),
                const SizedBox(width: 8),
                Text('No work is making a loss.', key: const Key('ceo_no_losses'), style: TextStyle(color: crm.textSecondary, fontSize: 13)),
              ]);
            }
            return Column(children: [
              for (final w in p.items)
                InkWell(
                  onTap: () => context.go('/accounts/work-profit'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(w.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                          Text('${w.bookingNumber} · ${w.service}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                        ]),
                      ),
                      Text(rupeesShort(w.profit), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kDashBad)),
                    ]),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${p.totals.loss} work${p.totals.loss == 1 ? '' : 's'} at a loss · ${p.totals.thin} on a thin margin · overall margin ${p.totals.marginPct?.toStringAsFixed(0) ?? '—'}%',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

// ── Sales & capacity ─────────────────────────────────────────────────────────

class _SalesCard extends ConsumerWidget {
  const _SalesCard({required this.query});
  final DashboardQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final sales = ref.watch(salesDashboardProvider(query));
    final insights = ref.watch(marketingInsightsProvider);

    return CeoCard(
      title: 'Sales & capacity',
      subtitle: 'This month so far, against ${query.prevLabel}',
      icon: Icons.trending_up_rounded,
      openRoute: '/',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CeoAsync(
          value: sales,
          onRetry: () => ref.invalidate(salesDashboardProvider(query)),
          builder: (d) {
            final rev = _change(d.kpis.revenue, d.previous.revenue, vs: query.prevShort);
            final ord = _change(d.kpis.orders, d.previous.orders, vs: query.prevShort);
            final enq = _change(d.kpis.enquiries, d.previous.enquiries, vs: query.prevShort);
            final topDistrict = d.byDistrict.isEmpty ? null : d.byDistrict.first;
            final topPerson = d.bySalesperson.isEmpty ? null : d.bySalesperson.first;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CeoStatGrid(stats: [
                CeoStat(label: 'Revenue', value: rupeesShort(d.kpis.revenue), change: rev.text, good: rev.good),
                CeoStat(label: 'Bookings', value: '${d.kpis.orders}', change: ord.text, good: ord.good),
                CeoStat(label: 'Enquiries', value: '${d.kpis.enquiries}', change: enq.text, good: enq.good),
                CeoStat(label: 'Conversion', value: '${d.kpis.conversion.toStringAsFixed(0)}%', hint: 'of enquiries'),
                CeoStat(label: 'Still to collect', value: rupeesShort(d.kpis.outstanding)),
                CeoStat(label: 'Cancelled', value: '${d.kpis.cancelled}', good: d.kpis.cancelled > d.previous.cancelled ? false : null),
              ]),
              if (topDistrict != null || topPerson != null) ...[
                const SizedBox(height: 14),
                if (topDistrict != null) _leader(context, Icons.place_outlined, 'Top district', '${topDistrict.label} · ${rupeesShort(topDistrict.amount)}'),
                if (topPerson != null) _leader(context, Icons.emoji_events_outlined, 'Top salesperson', '${topPerson.label} · ${rupeesShort(topPerson.amount)}'),
              ],
            ]);
          },
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: crm.border.faded(1.5)),
        const SizedBox(height: 12),
        _subTitle(context, 'Capacity, this financial year'),
        CeoAsync(
          value: insights,
          onRetry: () => ref.invalidate(marketingInsightsProvider),
          builder: (ins) => CeoStatGrid(stats: [
            CeoStat(
              label: 'Slots booked',
              value: '${ins.slot.pct}%',
              hint: '${ins.slot.totalBooked} of ${ins.slot.totalCapacity}',
              good: ins.slot.pct >= 85 ? true : null,
            ),
            CeoStat(label: 'Artists working', value: '${ins.artistUtilPct}%', hint: '${ins.artistBusy} of ${ins.artistTotal}'),
          ]),
        ),
      ]),
    );
  }

  Widget _leader(BuildContext context, IconData icon, String label, String value) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 16, color: crm.textSecondary),
        const SizedBox(width: 8),
        Text('$label  ', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary))),
      ]),
    );
  }
}

// ── People & customers ───────────────────────────────────────────────────────

class _PeopleCard extends ConsumerWidget {
  const _PeopleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final hr = ref.watch(hrAnalyticsSummaryProvider);
    final insights = ref.watch(marketingInsightsProvider);

    return CeoCard(
      title: 'People & customers',
      icon: Icons.groups_2_outlined,
      openRoute: '/hr/analytics',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _subTitle(context, 'The team'),
        CeoAsync(
          value: hr,
          onRetry: () => ref.invalidate(hrAnalyticsSummaryProvider),
          builder: (h) => CeoStatGrid(stats: [
            CeoStat(label: 'Active staff', value: '${h.active}', hint: h.newHiresThisMonth > 0 ? '${h.newHiresThisMonth} joined this month' : null),
            CeoStat(label: 'Approvals pending', value: '${h.pendingApprovals}', good: h.pendingApprovals > 5 ? false : null),
            CeoStat(label: 'Leave to decide', value: '${h.pendingLeave}'),
            CeoStat(label: 'Open grievances', value: '${h.openGrievances}', good: h.openGrievances > 0 ? false : null),
            CeoStat(label: 'Joining', value: '${h.onboardingInProgress}', hint: 'onboarding'),
            CeoStat(label: 'Leaving', value: '${h.exitsInProgress}', hint: 'in exit'),
          ]),
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: crm.border.faded(1.5)),
        const SizedBox(height: 12),
        _subTitle(context, 'Clients'),
        CeoAsync(
          value: insights,
          onRetry: () => ref.invalidate(marketingInsightsProvider),
          builder: (ins) {
            // The big figure is the whole financial year; the arrow compares the latest month with the month before it.
            final trend = ins.nps.trend;
            final latest = trend.isEmpty ? null : trend.last;
            final move = trend.length >= 2 ? trend.last.nps - trend[trend.length - 2].nps : null;
            return CeoStatGrid(stats: [
              CeoStat(
                label: 'NPS, this year',
                value: '${ins.nps.nps}',
                change: latest == null
                    ? null
                    : 'Latest month ${latest.nps}${move == null || move == 0 ? '' : ' (${move > 0 ? '+' : '−'}${move.abs()})'}',
                good: move == null || move == 0 ? null : move > 0,
                hint: '${ins.nps.responses} replies',
              ),
              CeoStat(label: 'Bride score', value: ins.avgBrideScore.toStringAsFixed(1), hint: 'out of 5'),
              CeoStat(label: 'Team score', value: ins.avgTeamScore.toStringAsFixed(1), hint: 'out of 5'),
            ]);
          },
        ),
      ]),
    );
  }
}

// ── Strategy & risks ─────────────────────────────────────────────────────────

class _StrategyCard extends ConsumerWidget {
  const _StrategyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final projects = ref.watch(companyProjectsProvider(null));
    final okrs = ref.watch(planningOkrsProvider);
    final signals = ref.watch(ceoSignalsProvider);

    return CeoCard(
      title: 'Strategy & risks',
      icon: Icons.flag_outlined,
      openRoute: '/projects',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _subTitle(context, 'Projects and objectives'),
        CeoAsync(
          value: projects,
          onRetry: () => ref.invalidate(companyProjectsProvider(null)),
          builder: (all) {
            final now = DateTime.now();
            final live = all.where((p) => p.status != 'cancelled' && p.status != 'completed').toList();
            final overdue = live.where((p) => p.endDate != null && p.endDate!.isBefore(now)).length;
            final proposals = all.where((p) => p.isProposed).length;
            final active = all.where((p) => p.status == 'active').length;
            final avg = live.isEmpty ? 0 : (live.fold<int>(0, (s, p) => s + p.progress) / live.length).round();
            return CeoStatGrid(stats: [
              CeoStat(label: 'Active projects', value: '$active', hint: '${live.length} not finished'),
              CeoStat(label: 'Average progress', value: '$avg%'),
              CeoStat(label: 'Past end date', value: '$overdue', good: overdue > 0 ? false : null),
              CeoStat(label: 'Proposals waiting', value: '$proposals', good: proposals > 0 ? false : null),
            ]);
          },
        ),
        const SizedBox(height: 12),
        CeoAsync(
          value: okrs,
          onRetry: () => ref.invalidate(planningOkrsProvider),
          builder: (all) {
            final company = all.where((o) => o.effectiveLevel == 'company').toList();
            if (company.isEmpty) return Text('No company objectives are set.', style: TextStyle(color: crm.textSecondary, fontSize: 13));
            final health = okrHealthCounts(company, DateTime.now());
            final progress = (company.fold<int>(0, (s, o) => s + o.progress) / company.length).round();
            final trouble = (health[OkrHealth.atRisk] ?? 0) + (health[OkrHealth.offTrack] ?? 0) + (health[OkrHealth.blocked] ?? 0);
            return CeoStatGrid(stats: [
              CeoStat(label: 'Company objectives', value: '$progress%', hint: '${company.length} set · average progress'),
              CeoStat(label: 'Need attention', value: '$trouble', good: trouble > 0 ? false : null, hint: 'at risk, off track or blocked'),
            ]);
          },
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: crm.border.faded(1.5)),
        const SizedBox(height: 12),
        _subTitle(context, 'Watch list'),
        CeoAsync(
          value: signals,
          onRetry: () => ref.invalidate(ceoSignalsProvider),
          builder: (s) => CeoWatchList(signals: s),
        ),
      ]),
    );
  }
}
