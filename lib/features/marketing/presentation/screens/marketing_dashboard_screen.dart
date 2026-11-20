import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/workspace.dart';
import '../../../../core/error/errors.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import '../../data/marketing_models.dart';
import '../../services/campaign_service.dart';
import '../../services/content_service.dart';
import '../../services/marketing_insights_service.dart';
import '../../services/marketing_service.dart';
import '../kit/mkt_kit.dart';
import '../widgets/marketing_widgets.dart';

/// Marketing → Overview. The module landing page: a live KPI snapshot
/// (leads, bookings YoY, campaign ROI, NPS, content, re-engagement) pulled from
/// features already built, quick-jump cards to every marketing sub-feature the
/// user can access, and the competitor watch. Every number comes from an
/// existing endpoint — no backend changes.
class MarketingDashboardScreen extends ConsumerWidget {
  const MarketingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(effectiveAccessProvider);
    final now = DateTime.now();

    // ── KPI providers (each degrades independently to "—") ──
    final leadsAsync = ref.watch(leadsProvider);
    final calAsync = ref.watch(bookingCalendarProvider);
    final campAsync = ref.watch(campaignsProvider);
    final insAsync = ref.watch(marketingInsightsProvider);
    final contentAsync = ref.watch(contentStatsProvider);
    final reEngAsync = ref.watch(reEngagementProvider);
    final leads = leadsAsync.value;
    final cal = calAsync.value;
    final camp = campAsync.value;
    final ins = insAsync.value;
    final content = contentAsync.value;
    final reEng = reEngAsync.value;

    // ── Competitor watch (existing logic) ──
    final competitorsAsync = ref.watch(competitorsProvider);
    final boardAsync = ref.watch(rankingsProvider(null));
    final competitors = competitorsAsync.value ?? const <Competitor>[];
    final board = boardAsync.value;

    // A KPI that failed to load shows a dash; surface why (e.g. offline)
    // instead of leaving the user guessing.
    final loadError = <AsyncValue<Object?>>[
      leadsAsync, calAsync, campAsync, insAsync, contentAsync, reEngAsync, competitorsAsync, boardAsync,
    ].where((a) => a.hasError).map((a) => a.error).firstOrNull;
    void reloadAll() {
      ref.invalidate(leadsProvider);
      ref.invalidate(bookingCalendarProvider);
      ref.invalidate(campaignsProvider);
      ref.invalidate(marketingInsightsProvider);
      ref.invalidate(contentStatsProvider);
      ref.invalidate(reEngagementProvider);
      ref.invalidate(competitorsProvider);
      ref.invalidate(rankingsProvider(null));
    }
    final ranks = board?.rankings ?? const <CompetitorRanking>[];
    final scored = competitors.where((c) => c.score > 0).toList();
    final avg = scored.isEmpty ? 0 : (scored.fold<int>(0, (s, c) => s + c.score) / scored.length).round();
    final top = competitors.isEmpty ? 0 : competitors.map((c) => c.score).fold<int>(0, (a, b) => a > b ? a : b);
    final movers = ranks.where((r) => (r.movement ?? 0) > 0).toList()..sort((a, b) => (b.movement ?? 0).compareTo(a.movement ?? 0));
    final biggestMover = movers.isNotEmpty ? movers.first : null;

    // ── Leads KPI ──
    const leadsLabel = 'Leads this month';
    String leadsVal = '—';
    String? leadsNote;
    if (leads != null) {
      final mtd = leads.where((l) => l.createdAt.year == now.year && l.createdAt.month == now.month).length;
      final converted = leads.where((l) => l.status == 'Converted' || (l.bookingId != null && l.bookingId!.isNotEmpty)).length;
      final pct = leads.isEmpty ? 0 : (converted / leads.length * 100).round();
      leadsVal = '$mtd';
      leadsNote = '$pct% converted';
    }

    // ── Bookings YoY (to-date, fair comparison) ──
    String bkVal = '—', bkLabel = 'Bookings this year';
    String? bkNote;
    bool? bkGood;
    if (cal != null) {
      var prevCmp = 0;
      cal.previous.forEach((k, v) {
        final p = k.split('-');
        if (p.length < 3) return;
        final mm = int.tryParse(p[1]) ?? 13;
        final dd = int.tryParse(p[2]) ?? 32;
        if (mm < now.month || (mm == now.month && dd <= now.day)) {
          prevCmp += v.bookings;
        }
      });
      bkVal = '${cal.curTotalBookings}';
      final delta = _pctDelta(cal.curTotalBookings.toDouble(), prevCmp.toDouble());
      bkLabel = 'Bookings ${cal.year}';
      if (delta.isNotEmpty) {
        bkNote = '$delta YoY';
        bkGood = delta.startsWith('▲') ? true : (delta.startsWith('▼') ? false : null);
      }
    }

    // ── Campaign ROI ──
    String roiVal = '—';
    String? roiNote;
    if (camp != null) {
      roiVal = camp.blendedRoiPct == null ? '—' : '${camp.blendedRoiPct!.round()}%';
      roiNote = '${_money(camp.totalAdSpend)} spend';
    }

    // ── NPS / CSAT ──
    String npsVal = '—';
    String? npsNote;
    if (ins != null) {
      npsVal = '${ins.nps.nps}';
      npsNote = 'CSAT ${ins.avgBrideScore.toStringAsFixed(1)}/5';
    }

    // ── Content ──
    String cVal = '—';
    String? cNote;
    bool? cGood;
    if (content != null) {
      cVal = '${content.dueThisWeek}';
      if (content.overdue > 0) {
        cNote = '${content.overdue} overdue';
        cGood = false;
      }
    }

    // ── Re-engagement ──
    final reVal = reEng == null ? '—' : '${reEng.count}';

    // ── Attention chips ──
    final chips = <Widget>[];
    if (content != null && content.overdue > 0) {
      chips.add(_attnChip(context, '${content.overdue} content overdue', Icons.warning_amber_rounded, '/marketing/content/dashboard'));
    }
    if (reEng != null && reEng.count > 0) {
      chips.add(_attnChip(context, '${reEng.count} brides to re-engage', Icons.favorite_border, '/marketing/re-engagement'));
    }

    // ── Jump-to nav cards (gated exactly like the sidebar) ──
    final cards = <Widget>[
      if (access.canSeeSub('marketing.insights'))
        _navTile(context, 'Insights', 'NPS, CSAT & utilization', Icons.insights_outlined, '/marketing/insights'),
      if (access.canSeeSub('marketing.analytics'))
        _navTile(context, 'Analytics', 'Timeline · culture · location', Icons.analytics_outlined, '/marketing/analytics'),
      if (access.canSeeSub('marketing.calendar'))
        _navTile(context, 'Sales Calendar', 'Year-over-year bookings', Icons.calendar_month_outlined, '/marketing/calendar'),
      if (access.canSeeSub('marketing.campaigns'))
        _navTile(context, 'Campaigns & ROI', 'Ad spend, ROI & attribution', Icons.campaign_outlined, '/marketing/campaigns'),
      if (access.canSeeSub('marketing.competitors'))
        _navTile(context, 'Competitors', 'Track & benchmark rivals', Icons.dataset_outlined, '/marketing/competitors'),
      if (access.canSeeSub('marketing.scores'))
        _navTile(context, 'Weekly Score', 'Growth-score leaderboard', Icons.leaderboard_outlined, '/marketing/scores'),
      if (access.canSeeSub('marketing.insights'))
        _navTile(context, 'Re-engagement', 'Past brides to contact', Icons.forum_outlined, '/marketing/re-engagement'),
      _navTile(context, 'Content Planner', 'Plan & schedule posts', Icons.event_note_outlined, '/marketing/content/dashboard'),
    ];

    final exploreCard = MktCard(
      title: 'Explore marketing',
      icon: Icons.explore_outlined,
      child: LayoutBuilder(
        builder: (context, box) {
          final cols = (box.maxWidth / 190).floor().clamp(2, 4);
          return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 120),
            children: cards,
          );
        },
      ),
    );

    final watchCard = MktCard(
      title: 'Competitor watch',
      icon: Icons.radar_outlined,
      subtitle: competitors.isEmpty
          ? 'No competitors tracked yet.'
          : '${competitors.length} tracked · avg score $avg · top $top${biggestMover == null ? '' : ' · ▲ ${biggestMover.name}'}',
      link: access.canSeeSub('marketing.competitors') ? 'View All' : null,
      onLink: () => context.go('/marketing/competitors'),
      child: ranks.isEmpty
          ? const MktEmpty('No scored competitors yet this week.', icon: Icons.radar_outlined)
          : MktTable(
              columns: const [
                MktCol('#', width: 30),
                MktCol('Competitor'),
                MktCol('Move', width: 56, align: Alignment.center),
                MktCol('Score', width: 78, align: Alignment.centerRight),
              ],
              rows: [
                for (final r in ranks.take(5))
                  [
                    Text('${r.rank}', style: mktText(12.5, weight: FontWeight.w800, color: Mkt.inkSoft)),
                    Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                    MovementChip(movement: r.movement),
                    ScoreBadge(score: r.score),
                  ],
              ],
            ),
    );

    return MktPage(
      child: Material(
        type: MaterialType.transparency,
        child: RefreshIndicator(
          onRefresh: () async => reloadAll(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const MktHeader(
                icon: Icons.space_dashboard_outlined,
                title: 'Overview',
                subtitle: 'Leads, campaigns, reviews & content — at a glance.',
              ),
              if (loadError != null) ...[
                const SizedBox(height: 12),
                AppErrorView(
                  error: loadError,
                  compact: true,
                  title: "Some figures couldn't load",
                  onRetry: reloadAll,
                ),
              ],
              const SizedBox(height: 14),
              MktKpiRow(
                children: [
                  MktKpiCard(icon: Icons.people_alt_outlined, value: leadsVal, label: leadsLabel, note: leadsNote, tint: Mkt.primary),
                  MktKpiCard(icon: Icons.event_available_outlined, value: bkVal, label: bkLabel, note: bkNote, good: bkGood, tint: Mkt.blue),
                  MktKpiCard(icon: Icons.trending_up, value: roiVal, label: 'Campaign ROI', note: roiNote, tint: Mkt.good),
                  MktKpiCard(icon: Icons.sentiment_satisfied_alt_outlined, value: npsVal, label: 'NPS (promoter score)', note: npsNote, tint: Mkt.teal),
                  MktKpiCard(icon: Icons.article_outlined, value: cVal, label: 'Content due this week', note: cNote, good: cGood, tint: Mkt.warn),
                  MktKpiCard(icon: Icons.favorite_border, value: reVal, label: 'Brides to re-engage', tint: Mkt.pink),
                ],
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: chips),
              ],
              const SizedBox(height: 14),
              MktGrid(
                breakpoint: 900,
                rows: [
                  [(7, exploreCard), (5, watchCard)],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attnChip(BuildContext context, String label, IconData icon, String route) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Mkt.tint(Mkt.warn),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Mkt.tint(Mkt.warn, 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Mkt.warn),
            const SizedBox(width: 6),
            Text(label, style: mktText(12, weight: FontWeight.w700)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, size: 16, color: Mkt.inkSoft),
          ],
        ),
      ),
    );
  }

  Widget _navTile(BuildContext context, String title, String subtitle, IconData icon, String route) {
    return Material(
      color: Mkt.bg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Mkt.border)),
      child: InkWell(
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: Mkt.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: Mkt.primary),
              ),
              const Spacer(),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }

  // ── formatting helpers ──
  static String _pctDelta(double cur, double prev) {
    if (prev == 0) return cur == 0 ? '' : '▲100%';
    final pct = ((cur - prev) / prev) * 100;
    if (pct == 0) return '0%';
    return '${pct >= 0 ? '▲' : '▼'}${pct.abs().toStringAsFixed(0)}%';
  }

  static String _money(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}k';
    return '₹${v.toStringAsFixed(0)}';
  }
}
