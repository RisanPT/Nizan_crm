import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_approvals_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_followups_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_interdept_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_meetings_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_overview_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_requests_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/request_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';

/// The six screens of Coordinations, in the order the marketing team's document draws them (the ids are `?tab=` and the sidebar's sub-items).
const kCoordinationTabs = [
  ('overview', 'Overview', Icons.home_outlined),
  ('requests', 'Requests & Tasks', Icons.assignment_outlined),
  ('interdepartment', 'Inter-Department', Icons.swap_horiz_rounded),
  ('approvals', 'Approvals', Icons.verified_outlined),
  ('meetings', 'Meetings', Icons.event_outlined),
  ('followups', 'Follow-ups', Icons.notifications_active_outlined),
];

/// Marketing → Coordinations. A request or approval is logged once; the overview, the tables, the board, the meetings and the follow-ups
/// all read the same records. The date range, the Departments pill and the brand are the filters every tab shares.
class CoordinationsScreen extends ConsumerStatefulWidget {
  const CoordinationsScreen({super.key, this.initialTab = 'overview'});

  /// The `?tab=` of /marketing/coordinations.
  final String initialTab;

  @override
  ConsumerState<CoordinationsScreen> createState() => _CoordinationsScreenState();
}

class _CoordinationsScreenState extends ConsumerState<CoordinationsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: kCoordinationTabs.length, vsync: this, initialIndex: _indexOf(widget.initialTab));

  static int _indexOf(String tab) {
    final i = kCoordinationTabs.indexWhere((t) => t.$1 == tab);
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
    final want = kCoordinationTabs[_tabs.index].$1;
    if (GoRouterState.of(context).uri.queryParameters['tab'] != want) router.go('/marketing/coordinations?tab=$want');
  }

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) _syncUrl();
    });
  }

  @override
  void didUpdateWidget(covariant CoordinationsScreen old) {
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
              icon: Icons.hub_outlined,
              title: 'Coordinations',
              subtitle: 'Track requests, manage cross-team work, approvals and follow-ups in one place.',
              actions: [
                ...coordFilterActions(context, ref),
                MktPrimaryButton(key: const Key('co_new_request'), label: 'New Request', onPressed: () => showRequestEditor(context, ref)),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(animation: _tabs, builder: (context, _) => MktTabPills(keyPrefix: 'co_tab', tabs: [for (final t in kCoordinationTabs) MktTabSpec(t.$1, t.$2, t.$3)], selected: kCoordinationTabs[_tabs.index].$1, onSelect: _go)),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            CoordOverviewTab(onOpenTab: _go),
            const CoordRequestsTab(),
            const CoordInterDeptTab(),
            const CoordApprovalsTab(),
            const CoordMeetingsTab(),
            const CoordFollowUpsTab(),
          ]),
        ),
      ]),
    );
  }
}
