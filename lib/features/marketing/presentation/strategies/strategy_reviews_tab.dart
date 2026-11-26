import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/strategy_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_editors.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_exports.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_widgets.dart';
import 'package:nizan_crm/features/marketing/services/strategy_service.dart';

/// Strategies & Developments → Reviews: how a strategy, project, campaign or quarter went. The score (Achieved / Partially / Not achieved)
/// is counted from the review's outcomes; the action items are the next steps, ticked off by their owners. Managers write the reviews.
class StrategyReviewsTab extends ConsumerWidget {
  const StrategyReviewsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(strategyReviewsProvider);
    final setup = strategySetupOf(ref);
    final q = ref.watch(reviewQueryProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshStrategies(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshStrategies(ref))]),
        data: (d) {
          final selectedId = ref.watch(selectedReviewProvider);
          final open = d.items.where((r) => r.id == selectedId).firstOrNull ?? d.items.firstOrNull;
          return ListView(
            key: const Key('strategies_reviews_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final t in kReviewTypes)
                  MktFilterChip(
                    key: Key('rv_tab_${t.$1}'),
                    label: t.$2,
                    count: d.counts[t.$1] ?? 0,
                    selected: q.type == t.$1,
                    onTap: () {
                      ref.read(selectedReviewProvider.notifier).state = null;
                      ref.read(reviewQueryProvider.notifier).state = ReviewQuery(type: t.$1);
                    },
                  ),
                if (d.items.length > 1)
                  KeyedSubtree(
                    key: const Key('rv_picker'),
                    child: MktDropdownPill<String>(
                      value: open?.id ?? '',
                      icon: Icons.history_rounded,
                      options: [for (final r in d.items) (r.id, '${r.periodLabel} · ${strategyDay(r.reviewDate, pattern: 'd MMM yyyy')}')],
                      onChanged: (id) => ref.read(selectedReviewProvider.notifier).state = id,
                    ),
                  ),
                if (setup.canManage) MktPrimaryButton(key: const Key('rv_new'), label: 'New Review', onPressed: () => showReviewEditor(context, ref, type: q.type)),
              ]),
              const SizedBox(height: 12),
              if (open == null)
                MktCard(title: reviewTypeLabel(q.type), icon: Icons.fact_check_outlined, child: MktEmpty(setup.canManage ? 'No ${reviewTypeLabel(q.type).toLowerCase()} in this period. Use New Review.' : 'No ${reviewTypeLabel(q.type).toLowerCase()} in this period. A Marketing Manager adds them.', icon: Icons.fact_check_outlined, height: 150))
              else
                MktGrid(breakpoint: 900, rows: [
                  [(5, _Summary(r: open, setup: setup)), (7, _Outcomes(r: open))],
                  [(12, _Actions(r: open, setup: setup))],
                ]),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.r, required this.setup});
  final StrategyReview r;
  final StrategySetup setup;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final yes = await confirmStrategyDelete(context, title: 'Delete this review?', body: '"${r.periodLabel}" and its action items are removed.');
    if (!yes) return;
    try {
      await ref.read(marketingStrategyServiceProvider).deleteReview(r.id);
      ref.read(selectedReviewProvider.notifier).state = null;
      refreshStrategies(ref);
    } on TeamRefusal catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = r.scores;
    final slices = [('Achieved', s.achieved, s.achievedPct, 'achieved'), ('Partially Achieved', s.partial, s.partialPct, 'partial'), ('Not Achieved', s.missed, s.missedPct, 'missed')];
    return MktCard(
      title: 'Review Summary – ${r.periodLabel}',
      subtitle: '${reviewTypeLabel(r.type)} · ${strategyDay(r.reviewDate)}${r.createdBy.isEmpty ? '' : ' · ${r.createdBy}'}',
      icon: Icons.fact_check_outlined,
      trailing: setup.canManage
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(key: const Key('rv_edit'), tooltip: 'Edit review', visualDensity: VisualDensity.compact, onPressed: () => showReviewEditor(context, ref, review: r), icon: const Icon(Icons.edit_outlined, size: 18)),
              IconButton(key: const Key('rv_delete'), tooltip: 'Delete review', visualDensity: VisualDensity.compact, onPressed: () => _delete(context, ref), icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Mkt.bad)),
            ])
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (r.linked != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: ReviewLinkPanel(link: r.linked!)),
        s.total == 0
          ? const MktEmpty('This review has no outcomes to score.', icon: Icons.donut_large_rounded, height: 150)
          : MktDonut(
              centerKey: const Key('rv_overall'),
              centerValue: s.overall == null ? '—' : '${s.overall}%',
              centerLabel: 'Overall Score',
              size: 124,
              sideBySideFrom: 330,
              colors: [for (final x in slices) outcomeColor(x.$4)],
              slices: [for (final x in slices) (label: x.$1, value: x.$2.toDouble(), trailing: '${x.$3 ?? 0}% · ${x.$2}')],
            ),
      ]),
    );
  }
}

/// What a review is about, as it stands now: its kind and title, its status and its progress (worked out by the server on every read).
class ReviewLinkPanel extends StatelessWidget {
  const ReviewLinkPanel({super.key, required this.link});
  final ReviewLink link;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('rv_linked'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Mkt.primarySoft, borderRadius: BorderRadius.circular(10)),
        child: link.missing
            ? Text('${link.kindLabel}: no longer there (it was deleted).', style: mktText(12, color: Mkt.inkSoft))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('REVIEWS · ${link.kindLabel.toUpperCase()} · NOW', style: mktText(9.5, weight: FontWeight.w800, color: Mkt.inkSoft, spacing: 0.6)),
                const SizedBox(height: 2),
                Row(children: [
                  Expanded(child: Text(link.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w800))),
                  if (link.statusLabel.isNotEmpty) MktChip(link.statusLabel, key: const Key('rv_linked_status'), color: Mkt.primaryLight),
                ]),
                if (link.kind != 'plan') ...[
                  const SizedBox(height: 6),
                  link.hasProgress ? MktProgress(key: const Key('rv_linked_progress'), pct: link.progress!, color: Mkt.primaryLight) : Text('No progress yet (no task tied)', style: mktText(11.5, color: Mkt.inkSoft)),
                ],
              ]),
      );
}

class _Outcomes extends StatelessWidget {
  const _Outcomes({required this.r});
  final StrategyReview r;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Key Outcomes',
        icon: Icons.verified_outlined,
        child: r.outcomes.isEmpty
            ? const MktEmpty('No outcomes in this review.', icon: Icons.verified_outlined, height: 120)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (r.summary.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(r.summary, style: mktText(12, color: Mkt.inkSoft))),
                for (final (i, o) in r.outcomes.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(outcomeIcon(o.state), key: Key('rv_outcome_$i'), size: 17, color: outcomeColor(o.state)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(o.text, style: mktText(12.5))),
                    ]),
                  ),
              ]),
      );
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.r, required this.setup});
  final StrategyReview r;
  final StrategySetup setup;

  bool _canTick(ActionItem a) => setup.canManage || (setup.meId != null && a.ownerId == setup.meId);

  Future<void> _toggle(BuildContext context, WidgetRef ref, ActionItem a, bool done) async {
    try {
      await ref.read(marketingStrategyServiceProvider).setActionStatus(r.id, a.id, done ? 'done' : 'open');
      refreshStrategies(ref);
    } on TeamRefusal catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => MktCard(
        title: 'Action Items & Next Steps',
        icon: Icons.checklist_rounded,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        trailing: TextButton.icon(
          key: const Key('rv_export'),
          onPressed: () => downloadCsv('review-action-items.csv', actionItemsCsv(r)),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Export'),
        ),
        child: r.actionItems.isEmpty
            ? const MktEmpty('No next steps were set in this review.', icon: Icons.checklist_rounded, height: 110)
            : MktTable(
                minWidth: 640,
                rowHeight: 50,
                columns: const [MktCol('', width: 40), MktCol('Action Item', flex: 6), MktCol('Owner', flex: 3), MktCol('Priority', flex: 2), MktCol('Target Date', flex: 3), MktCol('Status', flex: 3)],
                rowKeys: [for (final a in r.actionItems) Key('rv_action_${a.id}')],
                rows: [
                  for (final a in r.actionItems)
                    [
                      Checkbox(key: Key('rv_action_tick_${a.id}'), value: a.status == 'done', visualDensity: VisualDensity.compact, onChanged: _canTick(a) ? (v) => _toggle(context, ref, a, v ?? false) : null),
                      Padding(padding: const EdgeInsets.only(right: 6), child: Text(a.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w600).copyWith(decoration: a.status == 'done' ? TextDecoration.lineThrough : null))),
                      Padding(padding: const EdgeInsets.only(right: 6), child: a.ownerName.isEmpty ? Text('—', style: mktText(12, color: Mkt.inkSoft)) : Row(mainAxisSize: MainAxisSize.min, children: [MktAvatar(a.ownerName, size: 22), const SizedBox(width: 6), Flexible(child: Text(a.ownerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12)))])),
                      MktChip(actionPriorityLabel(a.priority), color: priorityColor(a.priority)),
                      Text(strategyDay(a.targetDate), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: a.overdue ? Mkt.bad : Mkt.ink, weight: a.overdue ? FontWeight.w700 : FontWeight.w500)),
                      MktChip(actionStatusLabel(a.status), color: actionStatusColor(a.status)),
                    ],
                ],
              ),
      );
}
