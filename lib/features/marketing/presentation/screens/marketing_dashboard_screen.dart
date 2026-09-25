import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/workspace.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../../../core/error/errors.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import '../../data/marketing_models.dart';
import '../../services/campaign_service.dart';
import '../../services/content_service.dart';
import '../../services/marketing_insights_service.dart';
import '../../services/marketing_service.dart';
import '../widgets/marketing_widgets.dart';

/// Marketing → Command Center. The module landing page: a live KPI snapshot
/// (leads, bookings YoY, campaign ROI, NPS, content, re-engagement) pulled from
/// features already built, quick-jump cards to every marketing sub-feature the
/// user can access, and the competitor watch. Every number comes from an
/// existing endpoint — no backend changes.
class MarketingDashboardScreen extends ConsumerWidget {
  const MarketingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
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
    final avg = scored.isEmpty
        ? 0
        : (scored.fold<int>(0, (s, c) => s + c.score) / scored.length).round();
    final top = competitors.isEmpty
        ? 0
        : competitors.map((c) => c.score).fold<int>(0, (a, b) => a > b ? a : b);
    final movers = ranks.where((r) => (r.movement ?? 0) > 0).toList()
      ..sort((a, b) => (b.movement ?? 0).compareTo(a.movement ?? 0));
    final biggestMover = movers.isNotEmpty ? movers.first : null;

    // ── Leads KPI ──
    String leadsVal = '—', leadsLabel = 'Leads this month';
    if (leads != null) {
      final mtd = leads
          .where((l) => l.createdAt.year == now.year && l.createdAt.month == now.month)
          .length;
      final converted = leads
          .where((l) =>
              l.status == 'Converted' ||
              (l.bookingId != null && l.bookingId!.isNotEmpty))
          .length;
      final pct = leads.isEmpty ? 0 : (converted / leads.length * 100).round();
      leadsVal = '$mtd';
      leadsLabel = 'Leads this month · $pct% converted';
    }

    // ── Bookings YoY (to-date, fair comparison) ──
    String bkVal = '—', bkLabel = 'Bookings this year';
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
      bkLabel = 'Bookings ${cal.year}${delta.isEmpty ? '' : ' · $delta YoY'}';
    }

    // ── Campaign ROI ──
    String roiVal = '—', roiLabel = 'Campaign ROI';
    if (camp != null) {
      roiVal = camp.blendedRoiPct == null ? '—' : '${camp.blendedRoiPct!.round()}%';
      roiLabel = 'Campaign ROI · ${_money(camp.totalAdSpend)} spend';
    }

    // ── NPS / CSAT ──
    String npsVal = '—', npsLabel = 'NPS (promoter score)';
    if (ins != null) {
      npsVal = '${ins.nps.nps}';
      npsLabel = 'NPS · CSAT ${ins.avgBrideScore.toStringAsFixed(1)}/5';
    }

    // ── Content ──
    String cVal = '—', cLabel = 'Content due this week';
    if (content != null) {
      cVal = '${content.dueThisWeek}';
      cLabel = content.overdue > 0
          ? 'Content due · ${content.overdue} overdue'
          : 'Content due this week';
    }

    // ── Re-engagement ──
    final reVal = reEng == null ? '—' : '${reEng.count}';

    final kpis = <InvStat>[
      InvStat(leadsVal, leadsLabel, Icons.people_alt_outlined, crm.primary),
      InvStat(bkVal, bkLabel, Icons.event_available_outlined,
          const Color(0xFF2563EB)),
      InvStat(roiVal, roiLabel, Icons.trending_up, const Color(0xFF2E7D32)),
      InvStat(npsVal, npsLabel, Icons.sentiment_satisfied_alt_outlined,
          const Color(0xFF7C3AED)),
      InvStat(cVal, cLabel, Icons.article_outlined, const Color(0xFFF59E0B)),
      InvStat(reVal, 'Brides to re-engage', Icons.favorite_border,
          const Color(0xFFDB2777)),
    ];

    // ── Attention chips ──
    final chips = <Widget>[];
    if (content != null && content.overdue > 0) {
      chips.add(_attnChip(context, crm, '${content.overdue} content overdue',
          Icons.warning_amber_rounded, '/marketing/content/dashboard'));
    }
    if (reEng != null && reEng.count > 0) {
      chips.add(_attnChip(context, crm, '${reEng.count} brides to re-engage',
          Icons.favorite_border, '/marketing/re-engagement'));
    }

    // ── Jump-to nav cards (gated exactly like the sidebar) ──
    final cards = <Widget>[
      if (access.canSeeSub('marketing.insights'))
        _navCard(context, crm, 'Insights', 'NPS, CSAT & utilization',
            Icons.insights_outlined, '/marketing/insights'),
      if (access.canSeeSub('marketing.analytics'))
        _navCard(context, crm, 'Analytics', 'Timeline · culture · location',
            Icons.analytics_outlined, '/marketing/analytics'),
      if (access.canSeeSub('marketing.calendar'))
        _navCard(context, crm, 'Sales Calendar', 'Year-over-year bookings',
            Icons.calendar_month_outlined, '/marketing/calendar'),
      if (access.canSeeSub('marketing.campaigns'))
        _navCard(context, crm, 'Campaigns & ROI', 'Ad spend, ROI & attribution',
            Icons.campaign_outlined, '/marketing/campaigns'),
      if (access.canSeeSub('marketing.competitors'))
        _navCard(context, crm, 'Competitors', 'Track & benchmark rivals',
            Icons.dataset_outlined, '/marketing/competitors'),
      if (access.canSeeSub('marketing.scores'))
        _navCard(context, crm, 'Weekly Score', 'Growth-score leaderboard',
            Icons.leaderboard_outlined, '/marketing/scores'),
      if (access.canSeeSub('marketing.insights'))
        _navCard(context, crm, 'Re-engagement', 'Past brides to contact',
            Icons.forum_outlined, '/marketing/re-engagement'),
      _navCard(context, crm, 'Content Planner', 'Plan & schedule posts',
          Icons.event_note_outlined, '/marketing/content/dashboard'),
    ];

    return RefreshIndicator(
      onRefresh: () async => reloadAll(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 28),
        children: [
          Text('Marketing Command Center',
              style: TextStyle(
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary)),
          4.h,
          Text('Leads, campaigns, reviews & content — at a glance.',
              style: TextStyle(fontSize: 13, color: crm.textSecondary)),
          if (loadError != null) ...[
            12.h,
            AppErrorView(
              error: loadError,
              compact: true,
              title: "Some figures couldn't load",
              onRetry: reloadAll,
            ),
          ],
          16.h,
          InvStatGrid(isMobile: isMobile, stats: kpis),
          if (chips.isNotEmpty) ...[
            14.h,
            Wrap(spacing: 10, runSpacing: 10, children: chips),
          ],
          24.h,
          _sectionLabel(crm, 'Explore marketing'),
          12.h,
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 118,
            ),
            children: cards,
          ),
          24.h,
          _sectionLabel(crm, 'Competitor watch'),
          4.h,
          Text(
            competitors.isEmpty
                ? 'No competitors tracked yet.'
                : '${competitors.length} tracked · avg score $avg · top $top'
                    '${biggestMover == null ? '' : ' · ▲ ${biggestMover.name}'}',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
          12.h,
          if (ranks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              child: Text('No scored competitors yet this week.',
                  style: TextStyle(color: crm.textSecondary)),
            )
          else
            ...ranks.take(5).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _topRow(crm, r),
                )),
        ],
      ),
    );
  }

  Widget _sectionLabel(CrmTheme crm, String text) => Text(text,
      style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary));

  Widget _attnChip(BuildContext context, CrmTheme crm, String label,
      IconData icon, String route) {
    const c = Color(0xFFB45309);
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: c),
            6.w,
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: c)),
            4.w,
            const Icon(Icons.chevron_right, size: 16, color: c),
          ],
        ),
      ),
    );
  }

  Widget _navCard(BuildContext context, CrmTheme crm, String title,
      String subtitle, IconData icon, String route) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: crm.primary, size: 20),
            ),
            const Spacer(),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: crm.textPrimary)),
            2.h,
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _topRow(CrmTheme crm, CompetitorRanking r) => Container(
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text('${r.rank}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: crm.textSecondary)),
            ),
            Expanded(
              child: Text(r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: crm.textPrimary)),
            ),
            MovementChip(movement: r.movement),
            10.w,
            ScoreBadge(score: r.score),
          ],
        ),
      );

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
