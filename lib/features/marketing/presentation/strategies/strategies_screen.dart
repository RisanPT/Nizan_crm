import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategic_plans_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategies_overview_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_editors.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_research_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_reviews_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_roadmap_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_work_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_filter_bar.dart';

/// The seven screens of Strategies & Developments, in the order the marketing team's document draws them (the ids are `?tab=` and the
/// sidebar's sub-items).
const kStrategyTabs = [
  ('overview', 'Overview', Icons.home_outlined),
  ('plans', 'Strategic Plans', Icons.layers_outlined),
  ('projects', 'Development Projects', Icons.construction_outlined),
  ('roadmap', 'Roadmap', Icons.alt_route_rounded),
  ('initiatives', 'Initiatives', Icons.flag_outlined),
  ('research', 'Research & Insights', Icons.insights_rounded),
  ('reviews', 'Reviews', Icons.history_rounded),
];

/// Marketing → Strategies & Developments. Plan, build and track strategic initiatives, new developments and growth. An initiative's or a
/// development project's progress is counted from the tasks tied to it (and its hours from the logs tied to it); the roadmap is ticked
/// off by members; research is entered by members; reviews are counted from their outcomes. Date range and brand are the filters shared
/// with the rest of Marketing.
class StrategiesScreen extends ConsumerStatefulWidget {
  const StrategiesScreen({super.key, this.initialTab = 'overview'});

  /// The `?tab=` of /marketing/strategies.
  final String initialTab;

  @override
  ConsumerState<StrategiesScreen> createState() => _StrategiesScreenState();
}

class _StrategiesScreenState extends ConsumerState<StrategiesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: kStrategyTabs.length, vsync: this, initialIndex: _indexOf(widget.initialTab));

  static int _indexOf(String tab) {
    final i = kStrategyTabs.indexWhere((t) => t.$1 == tab);
    return i < 0 ? 0 : i;
  }

  /// Open a tab — and put it in the address (`?tab=`), so the sidebar's sub-item, a refresh and a shared link all agree with the page.
  void _go(String tab) {
    _tabs.animateTo(_indexOf(tab));
    _syncUrl();
  }

  void _syncUrl() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return; // not inside the app's router (a test)
    final want = kStrategyTabs[_tabs.index].$1;
    if (GoRouterState.of(context).uri.queryParameters['tab'] != want) router.go('/marketing/strategies?tab=$want');
  }

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) _syncUrl();
    });
  }

  @override
  void didUpdateWidget(covariant StrategiesScreen old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab) _go(widget.initialTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    strategySetupOf(ref); // read once up front (who may manage, the team list), so every form and button already knows
    return MktPage(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MktHeader(
              icon: Icons.track_changes_rounded,
              title: 'Strategies & Developments',
              subtitle: 'Plan, build and track strategic initiatives, new developments and business growth',
              actions: [
                ...teamFilterActions(context, ref, showMember: false),
                MktPrimaryButton(key: const Key('st_new_initiative'), label: 'New Initiative', onPressed: () => showWorkEditor(context, ref, kind: 'initiative')),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(animation: _tabs, builder: (context, _) => MktTabPills(keyPrefix: 'st_tab', tabs: [for (final t in kStrategyTabs) MktTabSpec(t.$1, t.$2, t.$3)], selected: kStrategyTabs[_tabs.index].$1, onSelect: _go)),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            StrategiesOverviewTab(onOpenTab: _go),
            const StrategicPlansTab(),
            const DevProjectsTab(),
            const StrategyRoadmapTab(),
            const InitiativesTab(),
            const StrategyResearchTab(),
            const StrategyReviewsTab(),
          ]),
        ),
      ]),
    );
  }
}
