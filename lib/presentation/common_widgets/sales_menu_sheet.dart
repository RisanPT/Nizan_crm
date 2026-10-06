import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/access_control.dart';
import '../../core/auth/workspace.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../features/sales/services/sales_target_service.dart';
import 'workspace_switcher.dart';

class _Item {
  final String label;
  final IconData icon;
  final String route;
  const _Item(this.label, this.icon, this.route);
}

class _Group {
  final String title;
  final List<_Item> items;
  const _Group(this.title, this.items);
}

/// Everything a sales user can open that isn't in the bottom bar
/// (Home · Leads · Calendar · Bookings), grouped and filtered by their role's
/// permissions — so nothing they can access is hidden behind the drawer.
List<_Group> _groupsFor(Access access) {
  final groups = <_Group>[
    if (access.canSeeSub('sales.leads'))
      const _Group('Sales workspace', [
        _Item('Lead Calendar', Icons.calendar_view_month_rounded, '/sales/leads?tab=calendar'),
        _Item('Quote', Icons.calculate_outlined, '/sales/leads?tab=quote'),
        _Item('Slots', Icons.event_available_outlined, '/sales/leads?tab=slots'),
        _Item('Invoice', Icons.receipt_long_outlined, '/sales/leads?tab=invoice'),
      ]),
    _Group('Sales', [
      if (canSetSalesTargets(access.roleKey) && access.canSeeSub('sales.targets'))
        const _Item('Sales Targets', Icons.flag_outlined, '/sales/targets'),
      if (access.canSeeSub('sales.dashboard'))
        const _Item('Sales Dashboard', Icons.insights_outlined, '/sales/dashboard'),
      if (access.canSeeSub('sales.invoices'))
        const _Item('Invoices & Bookings', Icons.request_quote_outlined, '/sales'),
      if (access.canSeeSub('sales.monthly'))
        const _Item('Monthly Bookings', Icons.calendar_month_outlined, '/sales/monthly'),
      if (access.canSeeSub('sales.cancelled'))
        const _Item('Cancelled Works', Icons.event_busy_outlined, '/sales/cancelled'),
      if (access.canSeeSub('sales.booking_map'))
        const _Item('Booking Map', Icons.travel_explore_rounded, '/sales/booking-map'),
      if (access.canSeeSales)
        const _Item('Sales Calendar', Icons.calendar_today_outlined, '/sales/calendar'),
    ]),
    _Group('Clients', [
      if (access.canSeeClients) const _Item('Clients', Icons.people_outline, '/clients'),
      if (access.canSeeTrials) const _Item('Trials', Icons.brush_outlined, '/trials'),
      if (access.canSeeTrials)
        const _Item('Trial Packages', Icons.inventory_2_outlined, '/trial-packages'),
      const _Item('Client Reviews', Icons.reviews_outlined, '/reviews'),
    ]),
    _Group('More', [
      const _Item('Notifications', Icons.notifications_none_rounded, '/notifications'),
      if (access.canSeeCompanyReports)
        const _Item('Company Reports', Icons.folder_shared_outlined, '/company-reports'),
      if (access.canSeePlanning)
        const _Item('Company Projects', Icons.account_tree_outlined, '/projects'),
      const _Item('Help Desk', Icons.support_agent_outlined, '/helpdesk'),
    ]),
  ];
  return groups.where((g) => g.items.isNotEmpty).toList();
}

/// The sales "Menu" sheet opened from the last bottom-bar tab on phones.
Future<void> showSalesMenuSheet(BuildContext context, WidgetRef ref) {
  final crm = context.crmColors;
  final uri = GoRouterState.of(context).uri;
  final current = uri.toString();
  final access = ref.read(effectiveAccessProvider);
  final groups = _groupsFor(access);

  void goTo(BuildContext sheetCtx, String route) {
    Navigator.of(sheetCtx).pop();
    context.go(route);
  }

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetCtx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: crm.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.trending_up_rounded, color: crm.primary, size: 23),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sales',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                  Text('Everything you can open',
                      style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                ]),
              ]),
              const SizedBox(height: 12),
              if (ref.read(isDualRoleProvider)) ...[
                _row(crm, Icons.swap_horiz_rounded, 'Switch to ${workspaceLabel(Workspace.inventory)}',
                    color: crm.primary, onTap: () {
                  Navigator.of(sheetCtx).pop();
                  switchToWorkspace(context, ref, Workspace.inventory);
                }),
                Divider(color: crm.border, height: 20),
              ],
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Text(g.title.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: crm.textSecondary)),
                ),
                for (final i in g.items)
                  _row(crm, i.icon, i.label,
                      selected: current == i.route || uri.path == i.route,
                      onTap: () => goTo(sheetCtx, i.route)),
              ],
              Divider(color: crm.border, height: 24),
              _row(crm, Icons.account_circle_outlined, 'My Profile',
                  selected: uri.path == '/profile', onTap: () => goTo(sheetCtx, '/profile')),
              _row(crm, Icons.logout_rounded, 'Log Out', color: crm.destructive, onTap: () async {
                Navigator.of(sheetCtx).pop();
                await ref.read(authControllerProvider).logout();
              }),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _row(CrmTheme crm, IconData icon, String label,
    {bool selected = false, Color? color, required VoidCallback onTap}) {
  final fg = color ?? (selected ? crm.primary : crm.textPrimary);
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? crm.primary.withValues(alpha: 0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, size: 21, color: fg),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: fg)),
          ),
          if (color == null) Icon(Icons.chevron_right, size: 20, color: crm.textSecondary),
        ]),
      ),
    ),
  );
}
