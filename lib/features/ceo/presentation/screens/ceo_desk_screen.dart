import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/ceo/data/decision_models.dart';
import 'package:nizan_crm/features/ceo/presentation/widgets/decision_actions.dart';
import 'package:nizan_crm/features/ceo/presentation/widgets/decision_card.dart';
import 'package:nizan_crm/features/ceo/services/decision_service.dart';
import 'package:nizan_crm/features/finance/presentation/screens/ceo_decisions_screen.dart';

/// The leaders' Decisions screen: **Waiting** (what the team has checked and needs a decision), **Decided** (the record of what
/// was approved or rejected, by whom and why) and **Log** (the meeting notes and action items kept by hand).
class CeoDeskScreen extends ConsumerStatefulWidget {
  const CeoDeskScreen({super.key, this.initialTab = 0, this.focusId});

  /// 0 Waiting · 1 Decided · 2 Log.
  final int initialTab;

  /// A request to open at once (from a notification's link).
  final String? focusId;

  @override
  ConsumerState<CeoDeskScreen> createState() => _CeoDeskScreenState();
}

class _CeoDeskScreenState extends ConsumerState<CeoDeskScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));

  @override
  void initState() {
    super.initState();
    final id = widget.focusId;
    if (id != null && id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showDecisionDetail(context, ref, id);
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final access = ref.watch(effectiveAccessProvider);
    final waiting = ref.watch(decisionQueueProvider(const DecisionFilter())).maybeWhen(data: (q) => q.counts.pending, orElse: () => 0);
    return Column(children: [
      Material(
        color: crm.surface,
        child: TabBar(
          key: const Key('ceo_desk_tabs'),
          controller: _tabs,
          labelColor: crm.primary,
          unselectedLabelColor: crm.textSecondary,
          indicatorColor: crm.primary,
          tabs: [
            Tab(key: const Key('ceo_tab_waiting'), child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Waiting'),
              if (waiting > 0) ...[
                const SizedBox(width: 6),
                Container(
                  key: const Key('ceo_tab_waiting_count'),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: crm.destructive, borderRadius: BorderRadius.circular(10)),
                  child: Text('$waiting', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ]))),
            const Tab(key: Key('ceo_tab_decided'), text: 'Decided'),
            const Tab(key: Key('ceo_tab_log'), text: 'Log'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [
            const _WaitingTab(),
            const _DecidedTab(),
            CeoDecisionsScreen(initialOpenOnly: true, canSettle: access.canSettleDecisionLog),
          ],
        ),
      ),
    ]);
  }
}

/// Cards in one column on a phone and two on a laptop.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.items});
  final List<DecisionRequest> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 900 ? 2 : 1;
        const gap = 12.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final r in items) SizedBox(width: w, child: DecisionCard(request: r)),
        ]);
      });
}

class _WaitingTab extends ConsumerStatefulWidget {
  const _WaitingTab();

  @override
  ConsumerState<_WaitingTab> createState() => _WaitingTabState();
}

class _WaitingTabState extends ConsumerState<_WaitingTab> {
  DecisionKind? _kind;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final all = ref.watch(decisionQueueProvider(const DecisionFilter()));
    final filter = DecisionFilter(kind: _kind);
    final shown = ref.watch(decisionQueueProvider(filter));
    return RefreshIndicator(
      onRefresh: () async => refreshDesk(ref),
      child: shown.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => refreshDesk(ref)),
        data: (q) {
          final counts = all.maybeWhen(data: (a) => a.counts.byKind, orElse: () => const <String, int>{});
          return ListView(
            key: const Key('ceo_waiting_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ChoiceChip(key: const Key('ceo_kind_all'), label: const Text('All'), selected: _kind == null, onSelected: (_) => setState(() => _kind = null)),
                  for (final k in DecisionKind.values)
                    if ((counts[k.wire] ?? 0) > 0 || _kind == k)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          key: Key('ceo_kind_${k.wire}'),
                          label: Text('${k.label} · ${counts[k.wire] ?? 0}'),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = _kind == k ? null : k),
                        ),
                      ),
                ]),
              ),
              const SizedBox(height: 12),
              if (q.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 56),
                  child: Column(children: [
                    Icon(Icons.verified_outlined, size: 52, color: crm.border),
                    const SizedBox(height: 10),
                    Text('Nothing is waiting for you.', key: const Key('ceo_desk_empty'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                    const SizedBox(height: 4),
                    Text('What the team has checked and needs you for will appear here.', textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
                  ]),
                )
              else
                _CardGrid(items: q.items),
            ],
          );
        },
      ),
    );
  }
}

class _DecidedTab extends ConsumerStatefulWidget {
  const _DecidedTab();

  @override
  ConsumerState<_DecidedTab> createState() => _DecidedTabState();
}

class _DecidedTabState extends ConsumerState<_DecidedTab> {
  DecisionStatus? _status;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final shown = ref.watch(decisionQueueProvider(DecisionFilter(decided: true, status: _status)));
    return RefreshIndicator(
      onRefresh: () async => refreshDesk(ref),
      child: shown.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => refreshDesk(ref)),
        data: (q) => ListView(
          key: const Key('ceo_decided_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(children: [
              ChoiceChip(key: const Key('ceo_decided_all'), label: const Text('All'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
              const SizedBox(width: 8),
              ChoiceChip(key: const Key('ceo_decided_approved'), label: const Text('Approved'), selected: _status == DecisionStatus.approved, onSelected: (_) => setState(() => _status = DecisionStatus.approved)),
              const SizedBox(width: 8),
              ChoiceChip(key: const Key('ceo_decided_rejected'), label: const Text('Rejected'), selected: _status == DecisionStatus.rejected, onSelected: (_) => setState(() => _status = DecisionStatus.rejected)),
            ]),
            const SizedBox(height: 12),
            if (q.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 56),
                child: Center(child: Text('Nothing has been decided yet.', key: const Key('ceo_decided_empty'), style: TextStyle(color: crm.textSecondary))),
              )
            else
              _CardGrid(items: q.items),
          ],
        ),
      ),
    );
  }
}

/// The link from a notification: `/ceo/decisions?focus=<id>&tab=…`.
CeoDeskScreen deskFromUri(Uri uri) {
  final tab = switch (uri.queryParameters['tab']) {
    'decided' => 1,
    'log' => 2,
    _ => 0,
  };
  return CeoDeskScreen(initialTab: tab, focusId: uri.queryParameters['focus']);
}

/// Go to the Decisions screen from anywhere ([decided]: the Decided tab).
void openDesk(BuildContext context, {bool decided = false}) => context.go(decided ? '/ceo/decisions?tab=decided' : '/ceo/decisions');
