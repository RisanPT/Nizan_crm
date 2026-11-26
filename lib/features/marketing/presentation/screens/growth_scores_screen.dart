import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../data/marketing_models.dart';
import '../../services/marketing_service.dart';
import '../kit/mkt_kit.dart';
import '../widgets/marketing_widgets.dart';
import '../marketing_snapshot_editor.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

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
  String? _formCompetitorId;

  static const _tabs = [
    MktTabSpec('0', 'Overall', Icons.leaderboard_outlined),
    MktTabSpec('1', 'Top Reels', Icons.play_circle_outline_rounded),
    MktTabSpec('2', 'Top Websites', Icons.language_outlined),
    MktTabSpec('3', 'Top Collabs', Icons.handshake_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rankingsProvider(null));

    return MktPage(
      child: Material(
        type: MaterialType.transparency,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(rankingsProvider(null))),
          data: (board) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                MktHeader(
                  icon: Icons.speed_outlined,
                  title: 'Weekly Score',
                  subtitle: 'Week of ${_weekLabel(board.weekOf)} · score 1–25',
                  actions: [
                    MktPill(label: 'Weights', icon: Icons.tune, trailing: false, onTap: _editWeights),
                  ],
                ),
                const SizedBox(height: 14),
                _scoreForm(),
                const SizedBox(height: 14),
                // Tab selector
                MktTabPills(
                  keyPrefix: 'gs_tab',
                  tabs: _tabs,
                  selected: '$_tab',
                  onSelect: (id) => setState(() => _tab = int.parse(id)),
                ),
                const SizedBox(height: 12),
                _content(board),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content(RankingBoard board) {
    if (_tab == 0) {
      if (board.rankings.isEmpty) return _empty();
      return MktCard(
        title: 'Overall ranking',
        icon: Icons.leaderboard_outlined,
        subtitle: 'Tap a competitor to see the signals behind its score',
        child: MktTable(
          rowHeight: 54,
          columns: const [
            MktCol('#', width: 44),
            MktCol('Competitor', flex: 3),
            MktCol('Move', width: 56, align: Alignment.center),
            MktCol('Score', width: 84, align: Alignment.centerRight),
          ],
          onRowTap: (i) => _showSignals(board.rankings[i]),
          rows: [
            for (final r in board.rankings)
              [
                _rankBadge(r.rank, r.rank <= 3),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13.5, weight: FontWeight.w800)),
                    2.h,
                    Text(
                      [
                        if (r.city.isNotEmpty) r.city,
                        if (r.category.isNotEmpty) r.category,
                        '${r.signals.length} signal${r.signals.length == 1 ? '' : 's'}',
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mktText(11.5, color: Mkt.inkSoft),
                    ),
                  ],
                ),
                MovementChip(movement: r.movement),
                ScoreBadge(score: r.score),
              ],
          ],
        ),
      );
    }
    final list = _tab == 1
        ? board.reels
        : _tab == 2
            ? board.websites
            : board.collaborations;
    final unit = _tab == 1 ? '% eng.' : (_tab == 2 ? 'SEO' : 'collabs');
    if (list.isEmpty) return _empty();
    return MktCard(
      title: _tab == 1 ? 'Top reels' : (_tab == 2 ? 'Top websites' : 'Top collaborations'),
      icon: _tabs[_tab].icon,
      child: MktTable(
        rowHeight: 50,
        columns: const [
          MktCol('#', width: 44),
          MktCol('Name', flex: 3),
          MktCol('Value', flex: 2, align: Alignment.centerRight),
          MktCol('Score', width: 84, align: Alignment.centerRight),
        ],
        rows: [
          for (final e in list)
            [
              _rankBadge(e.rank, e.rank <= 3),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w700)),
                  if (e.city.isNotEmpty) Text(e.city, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft)),
                ],
              ),
              Text(
                '${e.metric % 1 == 0 ? e.metric.toStringAsFixed(0) : e.metric.toStringAsFixed(1)} $unit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mktText(12.5, weight: FontWeight.w800),
              ),
              ScoreBadge(score: e.score),
            ],
        ],
      ),
    );
  }

  Widget _empty() => const MktCard(
        title: 'Nothing to rank yet',
        icon: Icons.leaderboard_outlined,
        child: MktEmpty(
          'No weekly data yet for this week\nAdd weekly data on the Competitors screen to populate.',
          icon: Icons.leaderboard_outlined,
          height: 130,
        ),
      );

  Widget _rankBadge(int rank, bool medal) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: medal ? Mkt.primarySoft : Mkt.bg,
          shape: BoxShape.circle,
          border: Border.all(color: medal ? Mkt.primary : Mkt.border, width: medal ? 1.4 : 1),
        ),
        child: Text('$rank', style: mktText(12.5, weight: FontWeight.w800, color: medal ? Mkt.primary : Mkt.inkSoft)),
      );

  // ── Signal evidence breakdown (FR-2.2) ──────────────────────────────────
  void _showSignals(CompetitorRanking r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Mkt.card,
      // A competitor with many signals overflows a fixed-height sheet, so allow
      // it to grow and scroll instead of clipping.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.8),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('${r.name} · score ${r.score}/25',
                    style: mktText(17, weight: FontWeight.w800)),
              ),
              ScoreBadge(score: r.score, large: true),
            ]),
            12.h,
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            if (r.signals.isEmpty)
              Text('No signals triggered — base score 1.',
                  style: mktText(13, color: Mkt.inkSoft))
            else
              ...r.signals.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Mkt.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Mkt.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MktChip('+${s.points}', solid: true),
                        10.w,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.label, style: mktText(13.5, weight: FontWeight.w700)),
                              2.h,
                              Text(
                                  s.evidence.isEmpty
                                      ? 'No evidence recorded'
                                      : s.evidence,
                                  style: mktText(12.5,
                                      color: s.evidence.isEmpty ? Mkt.bad : Mkt.inkSoft)
                                      .copyWith(fontStyle: s.evidence.isEmpty ? FontStyle.italic : FontStyle.normal)),
                              // The manually-scored reel / post, opened in the
                              // browser or the Instagram app.
                              if (s.link.trim().isNotEmpty) ...[
                                6.h,
                                InkWell(
                                  onTap: () async {
                                    final uri = Uri.tryParse(s.link.trim());
                                    var opened = false;
                                    try {
                                      if (uri != null &&
                                          await canLaunchUrl(uri)) {
                                        opened = await launchUrl(uri,
                                            mode: LaunchMode
                                                .externalApplication);
                                      }
                                    } catch (_) {
                                      opened = false; // reported below
                                    }
                                    if (!opened && mounted) {
                                      showWarningSnackBar(context, "Couldn't open this link.");
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.play_circle_outline,
                                          size: 15, color: Mkt.primary),
                                      6.w,
                                      Flexible(
                                        child: Text('Open reel / post',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: mktText(12.5, weight: FontWeight.w700, color: Mkt.primary)
                                                .copyWith(decoration: TextDecoration.underline)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // ── Weights editor (FR-2.3) ─────────────────────────────────────────────
  /// Inline "score a competitor this week" form: pick an existing competitor
  /// and open the shared scoring editor (metrics, signals, reel/post links).
  Widget _scoreForm() {
    final async = ref.watch(competitorsProvider);
    final competitors = async.value ?? const <Competitor>[];

    return MktCard(
      title: 'Score a competitor this week',
      icon: Icons.add_chart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Pick a competitor, enter this week's metrics and signals, and paste the reel / post you scored.",
              style: mktText(11.5, color: Mkt.inkSoft)),
          12.h,
          if (async.isLoading)
            const LinearProgressIndicator(color: Mkt.primary)
          else if (competitors.isEmpty)
            Text('No competitors yet — add one on the Competitors screen first.',
                style: mktText(12.5, color: Mkt.inkSoft))
          else
            LayoutBuilder(builder: (context, c) {
                  final stack = c.maxWidth < 520;
                  final dropdown = DropdownButtonFormField<String>(
                    initialValue: _formCompetitorId,
                    isExpanded: true,
                    style: mktText(13),
                    decoration: InputDecoration(
                      labelText: 'Competitor',
                      isDense: true,
                      filled: true,
                      fillColor: Mkt.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.primary)),
                      prefixIcon: const Icon(Icons.storefront_outlined, size: 18),
                    ),
                    items: [
                      for (final comp in competitors)
                        DropdownMenuItem(
                          value: comp.id,
                          child: Text(
                            comp.city.trim().isEmpty
                                ? comp.name
                                : '${comp.name} · ${comp.city}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _formCompetitorId = v),
                  );
                  final button = MktPrimaryButton(
                    label: 'Enter score',
                    icon: Icons.edit_note,
                    onPressed: _formCompetitorId == null
                        ? null
                        : () async {
                            final comp = competitors.firstWhere(
                                (x) => x.id == _formCompetitorId,
                                orElse: () => competitors.first);
                            await showSnapshotEditor(context, ref, comp);
                          },
                  );
                  return stack
                      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [dropdown, 10.h, button])
                      : Row(children: [
                          Expanded(child: dropdown),
                          12.w,
                          button,
                        ]);
            }),
        ],
      ),
    );
  }

  Future<void> _editWeights() async {
    final ScoringConfig cfg;
    try {
      cfg = await ref.read(scoringConfigProvider.future);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
      return;
    }
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
            ref.refreshData.competitors();
            if (dctx.mounted) Navigator.pop(dctx);
            messenger.showSnackBar(const SnackBar(
                content: Text(
                    'Weights saved — new version applies to future entries')));
          } catch (e) {
            setLocal(() => saving = false);
            messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
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
                      style: mktText(12, color: Mkt.inkSoft)),
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
                              ? Mkt.good
                              : Mkt.warn)),
                  if (total() != 25)
                    Text('SRS §4.2 expects the weights to sum to 25.',
                        style:
                            mktText(11, color: Mkt.inkSoft)),
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
