import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/responsive_builder.dart';
import '../../data/marketing_models.dart';
import '../../services/marketing_service.dart';
import '../widgets/marketing_widgets.dart';

/// Marketing → Weekly Growth Score board. Competitors ranked 1-25 for the week,
/// with movement vs the previous week.
class GrowthScoresScreen extends ConsumerWidget {
  const GrowthScoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(rankingsProvider(null));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load rankings:\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: crm.textSecondary)),
        ),
      ),
      data: (board) {
        final ranks = board.rankings;
        return ListView(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 28),
          children: [
            Text('Weekly Growth Score',
                style: TextStyle(
                    fontSize: isMobile ? 21 : 27,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary)),
            4.h,
            Text('Week of ${_weekLabel(board.weekOf)} · ranked by score (max 25)',
                style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            16.h,
            if (ranks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.leaderboard_outlined,
                        size: 42, color: crm.textSecondary),
                    10.h,
                    Text('No weekly data yet for this week',
                        style: TextStyle(color: crm.textSecondary)),
                    6.h,
                    Text('Add weekly data on the Competitors screen to populate.',
                        style:
                            TextStyle(color: crm.textSecondary, fontSize: 12)),
                  ]),
                ),
              )
            else
              ...ranks.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _rankRow(crm, r),
                  )),
          ],
        );
      },
    );
  }

  Widget _rankRow(CrmTheme crm, CompetitorRanking r) {
    final medal = r.rank <= 3;
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal
                  ? crm.primary.withValues(alpha: 0.12)
                  : crm.input,
              shape: BoxShape.circle,
              border: Border.all(
                  color: medal ? crm.primary : crm.border,
                  width: medal ? 1.4 : 1),
            ),
            child: Text('${r.rank}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: medal ? crm.primary : crm.textSecondary)),
          ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: crm.textPrimary)),
                if (r.city.isNotEmpty || r.category.isNotEmpty) ...[
                  2.h,
                  Text(
                    [
                      if (r.city.isNotEmpty) r.city,
                      if (r.category.isNotEmpty) r.category,
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          8.w,
          MovementChip(movement: r.movement),
          12.w,
          ScoreBadge(score: r.score),
        ],
      ),
    );
  }

  static String _weekLabel(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }
}
