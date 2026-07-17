import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/responsive_builder.dart';
import '../../data/marketing_models.dart';
import '../../services/marketing_service.dart';
import '../widgets/marketing_widgets.dart';

/// Marketing → Weekly Growth Score board. Overall ranking (with signal evidence)
/// plus the Top-25 Reels / Websites / Collaborations leaderboards (FR-2.4), and
/// an editor for the versioned scoring weights (FR-2.3).
class GrowthScoresScreen extends ConsumerStatefulWidget {
  const GrowthScoresScreen({super.key});

  @override
  ConsumerState<GrowthScoresScreen> createState() => _GrowthScoresScreenState();
}

class _GrowthScoresScreenState extends ConsumerState<GrowthScoresScreen> {
  int _tab = 0; // 0 overall · 1 reels · 2 websites · 3 collaborations

  static const _tabs = ['Overall', 'Top Reels', 'Top Websites', 'Top Collabs'];

  @override
  Widget build(BuildContext context) {
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
        return ListView(
          padding:
              EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly Growth Score',
                          style: TextStyle(
                              fontSize: isMobile ? 21 : 27,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      4.h,
                      Text(
                          'Week of ${_weekLabel(board.weekOf)} · score 1–25',
                          style: TextStyle(
                              fontSize: 13, color: crm.textSecondary)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _editWeights,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Weights'),
                ),
              ],
            ),
            16.h,
            // Tab selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _tab == i,
                        label: Text(_tabs[i]),
                        onSelected: (_) => setState(() => _tab = i),
                      ),
                    ),
                ],
              ),
            ),
            14.h,
            ..._content(crm, board),
          ],
        );
      },
    );
  }

  List<Widget> _content(CrmTheme crm, RankingBoard board) {
    if (_tab == 0) {
      if (board.rankings.isEmpty) return [_empty(crm)];
      return board.rankings
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _rankRow(crm, r),
              ))
          .toList();
    }
    final list = _tab == 1
        ? board.reels
        : _tab == 2
            ? board.websites
            : board.collaborations;
    final unit = _tab == 1 ? '% eng.' : (_tab == 2 ? 'SEO' : 'collabs');
    if (list.isEmpty) return [_empty(crm)];
    return list
        .map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _leaderboardRow(crm, e, unit),
            ))
        .toList();
  }

  Widget _empty(CrmTheme crm) => Padding(
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
                style: TextStyle(color: crm.textSecondary, fontSize: 12)),
          ]),
        ),
      );

  Widget _rankRow(CrmTheme crm, CompetitorRanking r) {
    final medal = r.rank <= 3;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showSignals(r),
      child: Container(
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _rankBadge(crm, r.rank, medal),
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
                  2.h,
                  Text(
                    [
                      if (r.city.isNotEmpty) r.city,
                      if (r.category.isNotEmpty) r.category,
                      '${r.signals.length} signal${r.signals.length == 1 ? '' : 's'}',
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ],
              ),
            ),
            8.w,
            MovementChip(movement: r.movement),
            12.w,
            ScoreBadge(score: r.score),
          ],
        ),
      ),
    );
  }

  Widget _leaderboardRow(CrmTheme crm, LeaderboardEntry e, String unit) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          _rankBadge(crm, e.rank, e.rank <= 3),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: crm.textPrimary)),
                if (e.city.isNotEmpty) ...[
                  2.h,
                  Text(e.city,
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
              ],
            ),
          ),
          Text('${e.metric % 1 == 0 ? e.metric.toStringAsFixed(0) : e.metric.toStringAsFixed(1)} $unit',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: crm.textPrimary)),
          12.w,
          ScoreBadge(score: e.score),
        ],
      ),
    );
  }

  Widget _rankBadge(CrmTheme crm, int rank, bool medal) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: medal ? crm.primary.withValues(alpha: 0.12) : crm.input,
          shape: BoxShape.circle,
          border: Border.all(
              color: medal ? crm.primary : crm.border, width: medal ? 1.4 : 1),
        ),
        child: Text('$rank',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: medal ? crm.primary : crm.textSecondary)),
      );

  // ── Signal evidence breakdown (FR-2.2) ──────────────────────────────────
  void _showSignals(CompetitorRanking r) {
    final crm = context.crmColors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: crm.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('${r.name} · score ${r.score}/25',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary)),
              ),
              ScoreBadge(score: r.score, large: true),
            ]),
            12.h,
            if (r.signals.isEmpty)
              Text('No signals triggered — base score 1.',
                  style: TextStyle(color: crm.textSecondary))
            else
              ...r.signals.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: crm.input,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: crm.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: crm.primary,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('+${s.points}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                        10.w,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.label,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: crm.textPrimary)),
                              2.h,
                              Text(
                                  s.evidence.isEmpty
                                      ? 'No evidence recorded'
                                      : s.evidence,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontStyle: s.evidence.isEmpty
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                      color: s.evidence.isEmpty
                                          ? crm.destructive
                                          : crm.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  // ── Weights editor (FR-2.3) ─────────────────────────────────────────────
  Future<void> _editWeights() async {
    final crm = context.crmColors;
    final cfg = await ref.read(scoringConfigProvider.future);
    final keys = cfg.labels.keys.isNotEmpty
        ? cfg.labels.keys.toList()
        : cfg.weights.keys.toList();
    final ctrls = {
      for (final k in keys)
        k: TextEditingController(text: '${cfg.weights[k] ?? cfg.defaults[k] ?? 0}'),
    };
    if (!mounted) return;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setLocal) {
        int total() => ctrls.values
            .fold<int>(0, (s, c) => s + (int.tryParse(c.text.trim()) ?? 0));
        Future<void> save() async {
          setLocal(() => saving = true);
          final messenger = ScaffoldMessenger.of(context);
          final weights = {
            for (final e in ctrls.entries)
              e.key: int.tryParse(e.value.text.trim()) ?? 0,
          };
          try {
            await ref
                .read(marketingServiceProvider)
                .updateScoringConfig(weights);
            ref.invalidate(scoringConfigProvider);
            ref.invalidate(rankingsProvider);
            if (dctx.mounted) Navigator.pop(dctx);
            messenger.showSnackBar(const SnackBar(
                content: Text(
                    'Weights saved — new version applies to future entries')));
          } catch (e) {
            setLocal(() => saving = false);
            messenger.showSnackBar(SnackBar(content: Text('$e')));
          }
        }

        return AlertDialog(
          title: Text('Scoring weights · v${cfg.version}'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Points per signal. Score is clamped 1–25.',
                      style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                  12.h,
                  for (final k in keys)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(cfg.labels[k] ?? k,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: ctrls[k],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              onChanged: (_) => setLocal(() {}),
                              decoration: const InputDecoration(
                                  isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  8.h,
                  Text('Max possible: ${total()}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: total() == 25
                              ? crm.success
                              : crm.warning)),
                  if (total() != 25)
                    Text('SRS §4.2 expects the weights to sum to 25.',
                        style:
                            TextStyle(fontSize: 11, color: crm.textSecondary)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(dctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save version'),
            ),
          ],
        );
      }),
    );
    for (final c in ctrls.values) {
      c.dispose();
    }
  }

  static String _weekLabel(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }
}
