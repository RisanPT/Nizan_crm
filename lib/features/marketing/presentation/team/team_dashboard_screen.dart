import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/team/log_activity_sheet.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_activity_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_filter_bar.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_overview_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_reports_tabs.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_tasks_tab.dart';

/// The tabs, in the order the document draws them (the keys are what `?tab=` and the "View all" links use).
const kTeamTabs = [
  ('overview', 'Overview', Icons.home_outlined),
  ('activity', 'Team Activity', Icons.bolt_outlined),
  ('tasks', 'Tasks & Deliverables', Icons.checklist_rtl_rounded),
  ('timesheet', 'Logs & Timesheet', Icons.schedule_rounded),
  ('performance', 'Performance', Icons.leaderboard_outlined),
  ('attendance', 'Attendance', Icons.event_available_outlined),
  ('reports', 'Reports', Icons.description_outlined),
];

/// Marketing → Team Dashboard. Who did what: the team's activity, tasks, timesheets and attendance — all read from the one Log Activity
/// record, so a piece of work is logged once (the **Log Activity** button) and every tab reflects it. Filters (date range, brand, and for
/// a manager the member) apply to every tab.
class TeamDashboardScreen extends ConsumerStatefulWidget {
  const TeamDashboardScreen({super.key, this.initialTab = 'overview'});

  final String initialTab;

  @override
  ConsumerState<TeamDashboardScreen> createState() => _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends ConsumerState<TeamDashboardScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: kTeamTabs.length, vsync: this, initialIndex: _indexOf(widget.initialTab));

  static int _indexOf(String tab) {
    final i = kTeamTabs.indexWhere((t) => t.$1 == tab);
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
    final want = kTeamTabs[_tabs.index].$1;
    if (GoRouterState.of(context).uri.queryParameters['tab'] != want) router.go('/marketing/team?tab=$want');
  }

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) _syncUrl();
    });
  }

  @override
  void didUpdateWidget(covariant TeamDashboardScreen old) {
    super.didUpdateWidget(old);
    // the sidebar's sub-items open this same screen with another ?tab=
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
              icon: Icons.groups_2_outlined,
              title: 'Team Dashboard',
              subtitle: 'Marketing team activity, tasks, progress and daily logs',
              actions: [
                ...teamFilterActions(context, ref),
                MktPrimaryButton(key: const Key('team_log_button'), label: 'Log Activity', onPressed: () => showLogActivity(context)),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) => MktTabPills(
                keyPrefix: 'team_tab',
                tabs: [for (final t in kTeamTabs) MktTabSpec(t.$1, t.$2, t.$3)],
                selected: kTeamTabs[_tabs.index].$1,
                onSelect: _go,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              TeamOverviewTab(onSeeAll: _go),
              const TeamActivityTab(),
              const TeamTasksTab(),
              const TeamTimesheetTab(),
              const TeamPerformanceTab(),
              const TeamAttendanceTab(),
              const TeamReportsTab(),
            ],
          ),
        ),
      ]),
    );
  }
}
