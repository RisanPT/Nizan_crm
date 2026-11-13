import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/routing/app_router.dart' show isRouteAllowed;
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';

/// One entry of the Marketing menu: where it goes, and which route decides whether this login may see it.
class MktNavItem {
  const MktNavItem(this.id, this.label, this.icon, this.route, {this.matches = const [], this.children = const [], this.built = true});
  final String id;
  final String label;
  final IconData icon;
  final String route;

  /// Other path prefixes that keep this item lit (a detail screen under it).
  final List<String> matches;

  /// Sub-items (Team Dashboard → its tabs), each a [MktNavItem] whose [route] carries `?tab=`.
  final List<MktNavItem> children;

  /// False while the module's screens are not built yet: it stays out of the menu (no dead links) and comes in when its phase ships.
  final bool built;
}

/// The modules, in the order the marketing team's document draws its sidebar. Each section's own screens are tabs inside it.
const kMarketingNav = <MktNavItem>[
  MktNavItem('overview', 'Overview', Icons.space_dashboard_outlined, '/marketing/dashboard'),
  MktNavItem('portfolio', 'Creative Portfolio', Icons.videocam_outlined, '/marketing/portfolio', children: [
    MktNavItem('portfolio.planner', 'Shoot Planner', Icons.video_camera_back_outlined, '/marketing/portfolio?tab=planner'),
    MktNavItem('portfolio.calendar', 'Production Calendar', Icons.calendar_month_outlined, '/marketing/portfolio?tab=calendar'),
    MktNavItem('portfolio.reports', 'Shoot Reports', Icons.bar_chart_rounded, '/marketing/portfolio?tab=reports'),
    MktNavItem('portfolio.gallery', 'Gallery', Icons.photo_library_outlined, '/marketing/portfolio?tab=gallery'),
  ]),
  MktNavItem('socials', 'Socials', Icons.share_outlined, '/marketing/socials', children: [
    MktNavItem('socials.overview', 'Overview', Icons.home_outlined, '/marketing/socials?tab=overview'),
    MktNavItem('socials.calendar', 'Content Calendar', Icons.calendar_month_outlined, '/marketing/socials?tab=calendar'),
    MktNavItem('socials.assets', 'Content & Assets', Icons.photo_library_outlined, '/marketing/socials?tab=assets'),
    MktNavItem('socials.publishing', 'Publishing & Accounts', Icons.send_outlined, '/marketing/socials?tab=publishing'),
    MktNavItem('socials.performance', 'Performance', Icons.bar_chart_rounded, '/marketing/socials?tab=performance'),
    MktNavItem('socials.reports', 'Reports & Insights', Icons.insights_outlined, '/marketing/socials?tab=reports'),
  ]),
  MktNavItem('coordinations', 'Coordinations', Icons.hub_outlined, '/marketing/coordinations', built: false),
  MktNavItem('strategies', 'Strategies & Developments', Icons.flag_outlined, '/marketing/strategies', built: false),
  MktNavItem('campaigns', 'Campaigns', Icons.campaign_outlined, '/marketing/campaigns'),
  MktNavItem('leads', 'Lead Report', Icons.person_search_outlined, '/marketing/leads-report', matches: ['/marketing/re-engagement']),
  MktNavItem('team', 'Team Dashboard', Icons.groups_2_outlined, '/marketing/team', matches: ['/marketing/eod'], children: [
    MktNavItem('team.overview', 'Overview', Icons.home_outlined, '/marketing/team?tab=overview'),
    MktNavItem('team.activity', 'Team Activity', Icons.bolt_outlined, '/marketing/team?tab=activity'),
    MktNavItem('team.tasks', 'Task & Deliverables', Icons.checklist_rtl_rounded, '/marketing/team?tab=tasks'),
    MktNavItem('team.timesheet', 'Logs & Timesheet', Icons.schedule_rounded, '/marketing/team?tab=timesheet'),
    MktNavItem('team.performance', 'Performance', Icons.leaderboard_outlined, '/marketing/team?tab=performance'),
    MktNavItem('team.attendance', 'Attendance', Icons.event_available_outlined, '/marketing/team?tab=attendance'),
    MktNavItem('team.reports', 'Reports', Icons.description_outlined, '/marketing/team?tab=reports'),
  ]),
  MktNavItem('content', 'Content', Icons.photo_library_outlined, '/marketing/content/dashboard', matches: ['/marketing/content']),
  MktNavItem('analytics', 'Analytics', Icons.insights_outlined, '/marketing/analytics'),
  MktNavItem('calendar', 'Sales Calendar', Icons.calendar_month_outlined, '/marketing/calendar'),
  MktNavItem('weekly', 'Weekly Report', Icons.summarize_outlined, '/marketing/weekly', built: false),
  MktNavItem('competitors', 'Competitors', Icons.radar_outlined, '/marketing/competitors'),
  MktNavItem('scores', 'Weekly Score', Icons.speed_outlined, '/marketing/scores'),
  MktNavItem('insights', 'Insights', Icons.lightbulb_outline_rounded, '/marketing/insights'),
];

/// The route a menu entry is gated by (a few go through a different permission than their own path).
@visibleForTesting
String? marketingNavTab(String route) => Uri.tryParse(route)?.queryParameters['tab'];

/// The sidebar for the Marketing ERP: deep maroon, the modules from the document, then **My Department** and the account strip.
/// Shown for the Marketing role everywhere and for anyone else while they are inside `/marketing` (with a way back to their own menu).
class MarketingSidebar extends ConsumerStatefulWidget {
  const MarketingSidebar({super.key});

  @override
  ConsumerState<MarketingSidebar> createState() => _MarketingSidebarState();
}

class _MarketingSidebarState extends ConsumerState<MarketingSidebar> {
  // which parents the person has opened or closed by hand; a parent not in here follows the route (open while you are inside it)
  final Map<String, bool> _open = {};

  static const _active = Color(0xFF86315A);

  bool _selected(MktNavItem item, String path, String? tab) {
    if (item.children.isNotEmpty) return path == item.route || item.matches.any(path.startsWith);
    final base = Uri.parse(item.route).path;
    if (path == base || item.matches.any(path.startsWith)) return true;
    return false;
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.redAccent), child: const Text('Logout')),
        ],
      ),
    );
    if (ok == true && mounted) await ref.read(authControllerProvider).logout();
  }

  void _go(BuildContext context, String route) {
    context.go(route);
    final s = Scaffold.maybeOf(context);
    if (s?.isDrawerOpen ?? false) s!.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    final path = state.uri.path;
    final tab = state.uri.queryParameters['tab'];
    final access = ref.watch(effectiveAccessProvider);
    final role = ref.watch(effectiveRoleProvider);
    final isMobile = ResponsiveBuilder.isMobile(context);
    final collapsed = ResponsiveBuilder.isTablet(context) && !isMobile && !ResponsiveBuilder.isTwoPane(context);
    final width = collapsed ? 76.0 : 250.0;

    bool allowed(String route) => isRouteAllowed(Uri.parse(route).path, access);

    bool insideParent(MktNavItem it) => path == Uri.parse(it.route).path || it.matches.any(path.startsWith);
    bool isOpen(MktNavItem it) => !collapsed && (_open[it.id] ?? insideParent(it));

    Widget item(MktNavItem it, {MktNavItem? parent}) {
      final child = parent != null;
      // a sub-item is the current one when its ?tab= is the open tab of its parent's screen (the first tab when none is given)
      final sel = child ? (insideParent(parent) && (tab ?? Uri.parse(parent.children.first.route).queryParameters['tab']) == marketingNavTab(it.route)) : _selected(it, path, tab);
      final hasKids = it.children.isNotEmpty;
      final open = hasKids && isOpen(it);
      return _NavTile(
        key: Key('mkt_nav_${it.id}'),
        icon: it.icon,
        label: it.label,
        selected: sel && (!hasKids || !open || (path == '/marketing/eod')),
        lit: sel,
        collapsed: collapsed,
        child: child,
        trailing: hasKids && !collapsed ? Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white70) : null,
        onTap: () {
          if (hasKids && !collapsed) {
            if (!insideParent(it)) _go(context, it.route);
            setState(() => _open[it.id] = insideParent(it) ? !open : true);
          } else {
            _go(context, it.route);
          }
        },
      );
    }

    final visible = [for (final it in kMarketingNav) if (it.built && allowed(it.route)) it];
    final hasDepartment = access.canManageTeam && !access.isFullAccess;

    return Container(
      width: width,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Mkt.maroon, Mkt.maroonDeep])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 18),
        _Logo(collapsed: collapsed),
        const SizedBox(height: 14),
        // anyone who is not on the Marketing login gets a way back to their own menu
        if (role != AppRole.marketingAdmin) Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 4), child: _NavTile(key: const Key('mkt_nav_back'), icon: Icons.arrow_back_rounded, label: 'Main menu', selected: false, lit: false, collapsed: collapsed, onTap: () => _go(context, '/'))),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), children: [
            for (final it in visible) ...[
              item(it),
              if (it.children.isNotEmpty && isOpen(it)) for (final c in it.children) item(c, parent: it),
            ],
            if (hasDepartment) ...[
              const SizedBox(height: 18),
              if (!collapsed) Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 6), child: Text('MY DEPARTMENT', style: mktText(10.5, weight: FontWeight.w800, color: Colors.white54, spacing: 1.2))),
              _NavTile(key: const Key('mkt_nav_my_team'), icon: Icons.group_outlined, label: 'My Team', selected: path.startsWith('/team'), lit: path.startsWith('/team'), collapsed: collapsed, onTap: () => _go(context, '/team/manage')),
              _NavTile(key: const Key('mkt_nav_dept_expenses'), icon: Icons.receipt_long_outlined, label: 'Department Expenses', selected: path == '/accounts/admin-expenses', lit: path == '/accounts/admin-expenses', collapsed: collapsed, onTap: () => _go(context, '/accounts/admin-expenses')),
            ],
          ]),
        ),
        Container(height: 1, color: Colors.white12),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
            child: collapsed
                ? Column(children: [
                    _FooterAction(icon: Icons.account_circle_outlined, label: 'Profile', selected: path == '/profile', onTap: () => _go(context, '/profile')),
                    _FooterAction(icon: Icons.logout_rounded, label: 'Logout', selected: false, onTap: () => _logout(context)),
                  ])
                : Row(children: [
                    _FooterAction(icon: Icons.bug_report_outlined, label: 'Support', selected: path.startsWith('/helpdesk'), onTap: () => _go(context, '/helpdesk')),
                    _FooterAction(icon: Icons.cloud_download_outlined, label: 'Backup', selected: path.startsWith('/backup'), onTap: () => _go(context, '/backup')),
                    _FooterAction(icon: Icons.account_circle_outlined, label: 'Profile', selected: path == '/profile', onTap: () => _go(context, '/profile')),
                    _FooterAction(icon: Icons.logout_rounded, label: 'Logout', selected: false, onTap: () => _logout(context)),
                  ]),
          ),
        ),
      ]),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.collapsed});
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFC9A66B).withValues(alpha: 0.55))),
      child: Text('N', style: mktText(19, weight: FontWeight.w900, color: const Color(0xFFF5E6CA))),
    );
    if (collapsed) return Center(child: mark);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        mark,
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Team N', style: mktText(17, weight: FontWeight.w800, color: Colors.white, spacing: -0.2)),
          Text('ERP SUITE', style: mktText(9.5, weight: FontWeight.w700, color: Colors.white60, spacing: 1.6)),
        ]),
      ]),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({super.key, required this.icon, required this.label, required this.selected, required this.lit, required this.collapsed, required this.onTap, this.child = false, this.trailing});
  final IconData icon;
  final String label;
  final bool selected;

  /// Section is the current one even when its sub-item carries the highlight (icon/text stay bright).
  final bool lit;
  final bool collapsed;
  final bool child;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected || lit ? Colors.white : Colors.white.withValues(alpha: 0.74);
    return Padding(
      padding: EdgeInsets.only(left: child && !collapsed ? 14 : 0, top: 1.5, bottom: 1.5),
      child: Material(
        color: selected ? _MarketingSidebarState._active : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          onTap: onTap,
          child: Tooltip(
            message: collapsed ? label : '',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 11, vertical: child ? 7 : 9),
              child: Row(mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                Icon(icon, size: child ? 17 : 20, color: fg),
                if (!collapsed) ...[
                  const SizedBox(width: 11),
                  Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(child ? 12.5 : 13.5, weight: selected ? FontWeight.w700 : FontWeight.w500, color: fg))),
                  ?trailing,
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.72);
    final body = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: 0.10) : null, borderRadius: BorderRadius.circular(10)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(9.5, weight: selected ? FontWeight.w700 : FontWeight.w500, color: color)),
        ]),
      ),
    );
    return Expanded(child: Tooltip(message: label, child: body));
  }
}
