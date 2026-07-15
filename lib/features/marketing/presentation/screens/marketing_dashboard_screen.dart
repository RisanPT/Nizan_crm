import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/responsive_builder.dart';
import '../../../../presentation/screens/inventory/inventory_widgets.dart';
import '../../data/marketing_models.dart';
import '../../services/marketing_service.dart';
import '../widgets/marketing_widgets.dart';

/// Marketing → Executive dashboard. Strategic overview: tracking scale, average
/// and top scores, biggest movers, and quick access to the working screens.
class MarketingDashboardScreen extends ConsumerWidget {
  const MarketingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final competitorsAsync = ref.watch(competitorsProvider);
    final boardAsync = ref.watch(rankingsProvider(null));

    final competitors = competitorsAsync.value ?? const <Competitor>[];
    final board = boardAsync.value;
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

    return ListView(
      padding:
          EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 28),
      children: [
        Text('Marketing Intelligence',
            style: TextStyle(
                fontSize: isMobile ? 22 : 28,
                fontWeight: FontWeight.w800,
                color: crm.textPrimary)),
        4.h,
        Text('Competitor tracking · creative & strategy overview.',
            style: TextStyle(fontSize: 13, color: crm.textSecondary)),
        16.h,
        InvStatGrid(
          isMobile: isMobile,
          stats: [
            InvStat('${competitors.length}', 'Competitors tracked',
                Icons.groups_2_outlined, crm.primary),
            InvStat('$avg', 'Avg weekly score', Icons.speed_outlined,
                marketingScoreColor(avg)),
            InvStat('$top', 'Top score', Icons.emoji_events_outlined,
                marketingScoreColor(top)),
            InvStat(
                biggestMover == null ? '—' : '+${biggestMover.movement}',
                biggestMover == null
                    ? 'Biggest mover'
                    : 'Biggest mover · ${biggestMover.name}',
                Icons.trending_up,
                const Color(0xFF2E7D32)),
          ],
        ),
        20.h,
        Row(
          children: [
            Expanded(
              child: _navCard(context, crm, 'Competitor Database',
                  'Track competitors, enter weekly data, import CSV',
                  Icons.dataset_outlined, '/marketing/competitors'),
            ),
            12.w,
            Expanded(
              child: _navCard(context, crm, 'Weekly Growth Score',
                  'Ranked leaderboard for the current week',
                  Icons.leaderboard_outlined, '/marketing/scores'),
            ),
          ],
        ),
        24.h,
        Text('Top competitors this week',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: crm.textPrimary)),
        12.h,
        if (ranks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36),
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
    );
  }

  Widget _navCard(BuildContext context, CrmTheme crm, String title,
      String subtitle, IconData icon, String route) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            10.h,
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: crm.textPrimary)),
            4.h,
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: crm.textSecondary)),
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
}
