import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_gallery_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/production_calendar_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_planner_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_reports_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_filter_bar.dart';

/// The four screens of the Creative Portfolio, in the order the marketing team's document draws them (the keys are `?tab=` and the
/// sidebar's sub-items).
const kPortfolioTabs = [
  ('planner', 'Shoot Planner', Icons.video_camera_back_outlined),
  ('calendar', 'Production Calendar', Icons.calendar_month_outlined),
  ('reports', 'Shoot Reports', Icons.bar_chart_rounded),
  ('gallery', 'Gallery', Icons.photo_library_outlined),
];

/// Marketing → Creative Portfolio. Plan a shoot once; the calendar, the reports and the gallery read it. A shoot's progress moves when
/// members log pre-production, production and post-production work against it (Log Activity → Shoot). Date range and brand are the
/// filters shared with the rest of Marketing.
class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key, this.initialTab = 'planner'});

  final String initialTab;

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: kPortfolioTabs.length, vsync: this, initialIndex: _indexOf(widget.initialTab));

  static int _indexOf(String tab) {
    final i = kPortfolioTabs.indexWhere((t) => t.$1 == tab);
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
    final want = kPortfolioTabs[_tabs.index].$1;
    if (GoRouterState.of(context).uri.queryParameters['tab'] != want) router.go('/marketing/portfolio?tab=$want');
  }

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) _syncUrl();
    });
  }

  @override
  void didUpdateWidget(covariant PortfolioScreen old) {
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
    return MktPage(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MktHeader(
              icon: Icons.palette_outlined,
              title: 'Creative Portfolio',
              subtitle: 'Plan, produce, track and manage all your creative shoots in one place',
              actions: [
                ...teamFilterActions(context, ref, showMember: false),
                MktPrimaryButton(key: const Key('pf_new_shoot'), label: 'New Shoot Plan', onPressed: () => showShootEditor(context, ref)),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(animation: _tabs, builder: (context, _) => MktTabPills(keyPrefix: 'pf_tab', tabs: [for (final t in kPortfolioTabs) MktTabSpec(t.$1, t.$2, t.$3)], selected: kPortfolioTabs[_tabs.index].$1, onSelect: _go)),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(child: TabBarView(controller: _tabs, children: const [ShootPlannerTab(), ProductionCalendarTab(), ShootReportsTab(), PortfolioGalleryTab()])),
      ]),
    );
  }
}
