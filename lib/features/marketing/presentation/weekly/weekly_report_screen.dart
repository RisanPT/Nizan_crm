import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/weekly_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart' show LrNote, cappedNote, leadDelta, lrCell, numText, pctText, rupees;
import 'package:nizan_crm/features/marketing/presentation/team/team_filter_bar.dart';
import 'package:nizan_crm/features/marketing/presentation/weekly/weekly_widgets.dart';
import 'package:nizan_crm/features/marketing/services/weekly_service.dart';

/// Marketing → Weekly Report: ONE page rolling up the chosen range (a week by default) — leads, bookings, revenue, ad spend and conversion,
/// the day-by-day performance against the period before, lead quality and sources, each member's key result from their logs, campaign and
/// paid performance, the newest activity, shoots done against planned, revenue and collection, and plain-language insights. It adds no
/// number of its own: every figure is the Lead Report's, the Campaigns module's, the Creative Portfolio's or a member's logs, counted once
/// on the server. Export downloads the whole page as a CSV. `initialTab` is unused (the page has no tabs) — the router passes it anyway.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key, this.initialTab = 'overview'});
  final String initialTab;

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  bool _exporting = false;

  Future<void> _export(WeeklyReport r) async {
    setState(() => _exporting = true);
    try {
      await ref.read(weeklyCsvSaverProvider)(weeklyCsvFileName(r), weeklyCsvRows(r));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(weeklyReportProvider);
    final data = report.asData?.value;
    return MktPage(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: MktHeader(
            icon: Icons.trending_up_rounded,
            title: 'Marketing Weekly Report',
            subtitle: 'Track your marketing performance and activities at a glance',
            actions: [
              ...teamFilterActions(context, ref, showMember: false),
              KeyedSubtree(
                key: const Key('wk_export'),
                child: MktPrimaryButton(label: _exporting ? 'Building…' : 'Export', icon: Icons.download_rounded, onPressed: data == null || _exporting ? null : () => _export(data)),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => refreshWeekly(ref),
            child: report.when(
              loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
              error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshWeekly(ref))]),
              data: (r) => ListView(key: const Key('wk_list'), physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: _body(r)),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _body(WeeklyReport r) => [
        _KpiStrip(r: r),
        if (!r.status.adSpendRecorded && r.status.adSpendNote != null) LrNote(r.status.adSpendNote!, icon: Icons.info_outline_rounded),
        ?cappedNote(r.status.leadsCapped),
        const SizedBox(height: 12),
        MktGrid(breakpoint: 1000, rows: [
          [(6, _PerformanceCard(r: r)), (3, _QualityCard(r: r)), (3, _SourcesCard(r: r))],
          [(4, _MembersCard(r: r)), (4, _CampaignsCard(r: r)), (4, _RecentCard(r: r))],
          [(4, _ProductionCard(r: r)), (4, _RevenueCard(r: r)), (4, _InsightsCard(r: r))],
        ]),
      ];
}

// ── KPI strip ────────────────────────────────────────────────────────────────────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.r});
  final WeeklyReport r;

  Widget _card({required String key, required IconData icon, required String label, required String value, required WeeklyFigure? fig, List<double>? spark, Color tint = Mkt.primary, bool points = false, bool neutral = false, String? note}) {
    final d = fig == null ? null : leadDelta(fig.change, points: points, tail: r.against);
    // neutral: more spend is neither good nor bad on its own (it depends on what it brought), so its change is shown in grey
    return MktKpiCard(key: Key(key), icon: icon, value: value, label: label, note: note ?? d?.text, good: note != null || neutral ? null : d?.good, tint: tint, spark: spark);
  }

  @override
  Widget build(BuildContext context) {
    final h = r.headline;
    return MktKpiRow(minWidth: 190, children: [
      _card(key: 'wk_kpi_leads', icon: Icons.groups_2_outlined, label: 'Total Leads', value: count(h.leads.now), fig: h.leads, spark: r.sparks['leads']),
      _card(key: 'wk_kpi_bookings', icon: Icons.event_available_outlined, label: 'Bookings', value: count(h.bookings.now), fig: h.bookings, spark: r.sparks['bookings'], tint: Mkt.good),
      _card(key: 'wk_kpi_revenue', icon: Icons.currency_rupee_rounded, label: 'Revenue (ex-GST)', value: rupees(h.revenue.now), fig: h.revenue, spark: r.sparks['revenue'], tint: Mkt.pink),
      // ad spend only when a daily record exists — otherwise it says so (a made-up ₹0 would read as "we spent nothing")
      _card(key: 'wk_kpi_adspend', icon: Icons.campaign_outlined, label: 'Ad Spend', value: h.adSpend == null ? '—' : rupees(h.adSpend!.now), fig: h.adSpend, spark: r.sparks['adSpend'], tint: Mkt.blue, neutral: true, note: h.adSpend == null ? 'Not recorded' : null),
      _card(key: 'wk_kpi_rate', icon: Icons.percent_rounded, label: 'Conversion Rate', value: h.conversionKnown ? pctText(h.conversionRate.now) : '—', fig: h.conversionRate, spark: r.sparks['conversionRate'], tint: Mkt.warn, points: true),
    ]);
  }
}

// ── Weekly Performance Overview ──────────────────────────────────────────────────────────────────────────────────────────

class _PerformanceCard extends StatefulWidget {
  const _PerformanceCard({required this.r});
  final WeeklyReport r;

  @override
  State<_PerformanceCard> createState() => _PerformanceCardState();
}

class _PerformanceCardState extends State<_PerformanceCard> {
  String _metric = 'leads';

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    // on a phone the toggle sits above the chart instead of squeezing the title
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final toggle = WeeklyToggle(keyPrefix: 'wk_chart_tab', value: _metric, onChanged: (v) => setState(() => _metric = v), options: const [('leads', 'Leads'), ('bookings', 'Bookings'), ('revenue', 'Revenue')]);
    final chart = WeeklyCompareChart(key: Key('wk_chart_$_metric'), days: r.trend, metric: _metric, nowLabel: r.isWeek ? 'This week' : 'This period', beforeLabel: r.isWeek ? 'Last week' : 'Previous period');
    return MktCard(
      title: 'Weekly Performance Overview',
      subtitle: 'Each day against the same day of the period before',
      icon: Icons.show_chart_rounded,
      trailing: narrow ? null : toggle,
      child: narrow ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [toggle, const SizedBox(height: 10), chart]) : chart,
    );
  }
}

// ── Lead quality / sources ───────────────────────────────────────────────────────────────────────────────────────────────

/// A lead-quality bucket's colour. The buckets are whatever the Lead Report defines and the server sends (Hot / Warm / Nurture / Cold, and
/// "Not rated" when some lead has none) — a bucket this list does not know yet still gets a colour of its own, never a missing slice.
Color qualityColor(String key, [int index = 0]) => switch (key.toLowerCase()) {
      'hot' => Mkt.bad,
      'warm' => Mkt.warn,
      'nurture' => Mkt.teal,
      'cold' => Mkt.blue,
      'not rated' || 'not_rated' || 'unrated' => Mkt.grey,
      _ => Mkt.series(index + 4),
    };

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.r});
  final WeeklyReport r;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Lead Quality Distribution',
        icon: Icons.local_fire_department_outlined,
        child: r.quality.total == 0
            ? const MktEmpty('No leads in this range.', icon: Icons.donut_large_rounded)
            : MktDonut(
                centerKey: const Key('wk_quality_total'),
                centerValue: count(r.quality.total),
                centerLabel: 'Total Leads',
                colors: [for (final (i, q) in r.quality.rows.indexed) qualityColor(q.key, i)],
                slices: [for (final q in r.quality.rows) (label: q.label, value: q.count.toDouble(), trailing: '${count(q.count)}${q.pct == null ? '' : ' · ${numText(q.pct!)}%'}')],
              ),
      );
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.r});
  final WeeklyReport r;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Lead Sources',
        icon: Icons.hub_outlined,
        child: r.sources.total == 0
            ? const MktEmpty('No leads in this range.', icon: Icons.donut_large_rounded)
            : MktDonut(
                centerKey: const Key('wk_sources_total'),
                centerValue: count(r.sources.total),
                centerLabel: 'Total Leads',
                slices: [for (final s in r.sources.rows) (label: s.label, value: s.count.toDouble(), trailing: s.pct == null ? count(s.count) : '${numText(s.pct!)}%')],
              ),
      );
}

// ── Individual Insights ──────────────────────────────────────────────────────────────────────────────────────────────────

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.r});
  final WeeklyReport r;

  @override
  Widget build(BuildContext context) {
    final m = r.members;
    return MktCard(
      title: 'Individual Insights',
      subtitle: m.viewer ? 'Each member’s key result from their logs' : 'Your key result from your logs',
      icon: Icons.person_outline_rounded,
      child: m.rows.isEmpty
          ? MktEmpty(!m.viewer ? 'You have not logged any work in this range.' : (m.silent > 0 ? 'Nobody logged work in this range.' : 'No logs in this range.'), icon: Icons.assignment_outlined)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MktTable(
                columns: const [MktCol('Team Member', flex: 3), MktCol('Role', flex: 2), MktCol('Key Performance', flex: 4)],
                rowKeys: [for (final row in m.rows) Key('wk_member_${row.memberId}')],
                rows: [
                  for (final row in m.rows)
                    [
                      Row(children: [
                        MktAvatar(row.name, size: 22),
                        const SizedBox(width: 6),
                        Flexible(child: lrCell(row.name, bold: true)),
                      ]),
                      lrCell(row.role.isEmpty ? '—' : row.role, color: Mkt.inkSoft),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: memberResult(row), style: mktText(12, weight: FontWeight.w600)),
                            if (row.change != null) TextSpan(text: '  ${changeArrow(row.change)}', style: mktText(11.5, weight: FontWeight.w700, color: changeColor(row.change))),
                          ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                ],
              ),
              if (m.viewer && m.silent > 0) LrNote('${m.silent} ${m.silent == 1 ? 'member' : 'members'} logged nothing in this range.', icon: Icons.hourglass_empty_rounded),
            ]),
    );
  }
}

// ── Campaign & Paid Performance ──────────────────────────────────────────────────────────────────────────────────────────

class _CampaignsCard extends StatefulWidget {
  const _CampaignsCard({required this.r});
  final WeeklyReport r;

  @override
  State<_CampaignsCard> createState() => _CampaignsCardState();
}

class _CampaignsCardState extends State<_CampaignsCard> {
  String _tab = 'campaigns';

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final toggle = WeeklyToggle(keyPrefix: 'wk_camp_tab', value: _tab, onChanged: (v) => setState(() => _tab = v), options: const [('campaigns', 'Campaigns'), ('ads', 'Ads')]);
    final body = _tab == 'campaigns' ? _campaigns(r) : _ads(r);
    return MktCard(
      title: 'Campaign & Paid Performance',
      icon: Icons.campaign_outlined,
      trailing: narrow ? null : toggle,
      child: narrow ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [toggle, const SizedBox(height: 10), body]) : body,
    );
  }

  Widget _campaigns(WeeklyReport r) {
    if (r.campaigns.isEmpty) return const MktEmpty('No campaign had spend or leads in this range.', icon: Icons.campaign_outlined);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MktTable(
        columns: const [MktCol('Campaign', flex: 4), MktCol('Leads', flex: 2, align: Alignment.centerRight), MktCol('Bookings', flex: 2, align: Alignment.centerRight), MktCol('Revenue', flex: 3, align: Alignment.centerRight)],
        rowKeys: [for (final c in r.campaigns) Key('wk_campaign_${c.id}')],
        rows: [
          for (final c in r.campaigns)
            [
              lrCell(c.title, bold: true),
              Align(alignment: Alignment.centerRight, child: lrCell(count(c.leads))),
              Align(alignment: Alignment.centerRight, child: lrCell(count(c.bookings))),
              Align(alignment: Alignment.centerRight, child: lrCell(rupees(c.revenue))),
            ],
        ],
      ),
      if (r.campaignTotal > r.campaigns.length) LrNote('Showing ${r.campaigns.length} of ${r.campaignTotal} campaigns — the Campaigns screen has them all.'),
    ]);
  }

  Widget _ads(WeeklyReport r) {
    if (r.ads.isEmpty) return const MktEmpty('No ads recorded yet — add them in Campaigns.', icon: Icons.ads_click_rounded);
    return MktTable(
      columns: const [MktCol('Ad', flex: 4), MktCol('Results', flex: 2, align: Alignment.centerRight), MktCol('CTR', flex: 2, align: Alignment.centerRight), MktCol('Spend', flex: 3, align: Alignment.centerRight)],
      rowKeys: [for (final a in r.ads) Key('wk_ad_${a.id}')],
      rows: [
        for (final a in r.ads)
          [
            lrCell(a.name, bold: true),
            Align(alignment: Alignment.centerRight, child: lrCell(count(a.results))),
            Align(alignment: Alignment.centerRight, child: lrCell(a.ctr == null ? '—' : '${numText(a.ctr!)}%')),
            Align(alignment: Alignment.centerRight, child: lrCell(rupees(a.spend))),
          ],
      ],
    );
  }
}

// ── Recent Activities ────────────────────────────────────────────────────────────────────────────────────────────────────

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.r});
  final WeeklyReport r;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Recent Activities',
        icon: Icons.history_rounded,
        child: r.recent.isEmpty
            ? const MktEmpty('Nothing happened in this range yet.', icon: Icons.history_toggle_off_rounded)
            : MktTimeline(items: [
                for (var i = 0; i < r.recent.length; i++) MktTimelineItem(key: Key('wk_recent_$i'), time: eventTime(r.recent[i].at), title: r.recent[i].text, color: eventColor(r.recent[i].kind)),
              ]),
      );
}

// ── Production Activities of the Week ────────────────────────────────────────────────────────────────────────────────────

class _ProductionCard extends StatelessWidget {
  const _ProductionCard({required this.r});
  final WeeklyReport r;

  @override
  Widget build(BuildContext context) {
    final p = r.production;
    final colors = [Mkt.primaryLight, Mkt.good, Mkt.warn];
    return MktCard(
      title: r.isWeek ? 'Production Activities of the Week' : 'Production Activities',
      subtitle: p.planned == 0 ? null : '${p.done} of ${p.planned} planned shoots done',
      icon: Icons.videocam_outlined,
      child: p.planned == 0
          ? const MktEmpty('No shoots were planned in this range.', icon: Icons.videocam_off_outlined)
          : Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 10, runSpacing: 12, children: [
              for (var i = 0; i < p.categories.length; i++)
                WeeklyRing(key: Key('wk_ring_$i'), done: p.categories[i].done, planned: p.categories[i].planned, caption: '${p.categories[i].category} Shoots Done', color: colors[i % colors.length]),
            ]),
    );
  }
}

// ── Revenue & Collection ─────────────────────────────────────────────────────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.r});
  final WeeklyReport r;

  Widget _tile(String key, IconData icon, String label, String value, Color tint) => Container(
        key: Key(key),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Mkt.tint(tint, 0.09), borderRadius: BorderRadius.circular(11)),
        child: Row(children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(10.5, weight: FontWeight.w600, color: Mkt.inkSoft, height: 1.15)),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: mktText(15, weight: FontWeight.w800))),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final v = r.revenue;
    return MktCard(
      title: 'Revenue & Collection',
      subtitle: v.bookings == 0 ? null : '${v.bookings} ${v.bookings == 1 ? 'booking' : 'bookings'} counted',
      icon: Icons.account_balance_wallet_outlined,
      child: v.bookings == 0
          ? const MktEmpty('No bookings were counted in this range.', icon: Icons.receipt_long_outlined)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(builder: (context, box) {
                final w = (box.maxWidth - 8) / 2;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  SizedBox(width: w, child: _tile('wk_rev_order', Icons.receipt_long_outlined, 'Total Order Value (incl. GST)', rupees(v.orderValue), Mkt.primary)),
                  SizedBox(width: w, child: _tile('wk_rev_advance', Icons.verified_outlined, 'Advance Collected', rupees(v.advance), Mkt.good)),
                  SizedBox(width: w, child: _tile('wk_rev_balance', Icons.hourglass_bottom_rounded, 'Balance Due', rupees(v.balanceDue), Mkt.bad)),
                  SizedBox(width: w, child: _tile('wk_rev_average', Icons.person_outline_rounded, 'Avg Order Value', v.averageOrder == null ? '—' : rupees(v.averageOrder!), Mkt.pink)),
                ]);
              }),
              const SizedBox(height: 12),
              Text('Advance Collection Progress', style: mktText(11.5, weight: FontWeight.w600, color: Mkt.inkSoft)),
              const SizedBox(height: 4),
              KeyedSubtree(key: const Key('wk_rev_progress'), child: MktProgress(pct: (v.advanceProgress ?? 0).round().clamp(0, 100))),
              if (v.collectedLater > 0) LrNote('${rupees(v.collectedLater)} collected after the advance.', icon: Icons.check_circle_outline_rounded),
            ]),
    );
  }
}

// ── Key Insights ─────────────────────────────────────────────────────────────────────────────────────────────────────────

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.r});
  final WeeklyReport r;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Key Insights',
        icon: Icons.lightbulb_outline_rounded,
        child: r.insights.isEmpty
            ? const MktEmpty('Insights appear once there are leads to compare.', icon: Icons.lightbulb_outline_rounded)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < r.insights.length; i++)
                  Padding(
                    key: Key('wk_insight_$i'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: Mkt.good),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.insights[i], style: mktText(12.5, height: 1.3))),
                    ]),
                  ),
              ]),
      );
}
