import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/post_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_assets_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_calendar_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_overview_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_performance_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_publishing_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_reports_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_filter_bar.dart';

/// The six screens of the Socials module, in the order the marketing team's document draws them (the keys are `?tab=` and the sidebar's
/// sub-items).
const kSocialsTabs = [
  ('overview', 'Overview', Icons.home_outlined),
  ('calendar', 'Content Calendar', Icons.calendar_month_outlined),
  ('assets', 'Content & Assets', Icons.photo_library_outlined),
  ('publishing', 'Publishing & Accounts', Icons.send_outlined),
  ('performance', 'Performance', Icons.bar_chart_rounded),
  ('reports', 'Reports & Insights', Icons.insights_outlined),
];

/// Marketing → Socials. Posts are planned on the calendar, move through the pipeline, and once they are out the numbers are typed on
/// them; the activity tracker counts what members logged; leads are the CRM's. The date range and brand filters are shared with the rest
/// of Marketing.
class SocialsScreen extends ConsumerStatefulWidget {
  const SocialsScreen({super.key, this.initialTab = 'overview'});

  final String initialTab;

  @override
  ConsumerState<SocialsScreen> createState() => _SocialsScreenState();
}

class _SocialsScreenState extends ConsumerState<SocialsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: kSocialsTabs.length, vsync: this, initialIndex: _indexOf(widget.initialTab));

  static int _indexOf(String tab) {
    final i = kSocialsTabs.indexWhere((t) => t.$1 == tab);
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
    final want = kSocialsTabs[_tabs.index].$1;
    if (GoRouterState.of(context).uri.queryParameters['tab'] != want) router.go('/marketing/socials?tab=$want');
  }

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) _syncUrl();
    });
  }

  @override
  void didUpdateWidget(covariant SocialsScreen old) {
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
            AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) => MktHeader(
                icon: Icons.share_outlined,
                breadcrumb: 'Socials',
                title: kSocialsTabs[_tabs.index].$2,
                subtitle: 'A complete view of social media activities, content, publishing and performance',
                actions: [
                  ...teamFilterActions(context, ref, showMember: false),
                  MktPrimaryButton(key: const Key('soc_create_content'), label: 'Create Content', onPressed: () => showPostEditor(context, ref)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) => MktTabPills(keyPrefix: 'soc_tab', tabs: [for (final t in kSocialsTabs) MktTabSpec(t.$1, t.$2, t.$3)], selected: kSocialsTabs[_tabs.index].$1, onSelect: _go),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              SocialsOverviewTab(onGo: _go),
              const SocialsCalendarTab(),
              const SocialsAssetsTab(),
              const SocialsPublishingTab(),
              const SocialsPerformanceTab(),
              const SocialsReportsTab(),
            ],
          ),
        ),
      ]),
    );
  }
}
