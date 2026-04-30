import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/app_role.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class Sidebar extends ConsumerWidget {
  final bool fleetExpanded;
  final bool fleetUserCollapsed;
  final ValueChanged<bool> onFleetExpandToggle;
  final bool accountsExpanded;
  final bool accountsUserCollapsed;
  final ValueChanged<bool> onAccountsExpandToggle;
  final bool salesExpanded;
  final bool salesUserCollapsed;
  final ValueChanged<bool> onSalesExpandToggle;

  const Sidebar({
    super.key,
    required this.fleetExpanded,
    required this.fleetUserCollapsed,
    required this.onFleetExpandToggle,
    required this.accountsExpanded,
    required this.accountsUserCollapsed,
    required this.onAccountsExpandToggle,
    required this.salesExpanded,
    required this.salesUserCollapsed,
    required this.onSalesExpandToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isTablet = ResponsiveBuilder.isTablet(context);
    final currentPath = GoRouterState.of(context).uri.path;
    final isFleetRoute = currentPath.startsWith('/fleet');
    final isAccountsRoute = currentPath.startsWith('/accounts');
    final isSalesRoute = currentPath.startsWith('/sales');
    final isCollapsed = isTablet && !isMobile;
    final effectiveFleetExpanded =
        !isCollapsed && (fleetExpanded || (isFleetRoute && !fleetUserCollapsed));
    final effectiveAccountsExpanded =
        !isCollapsed && (accountsExpanded || (isAccountsRoute && !accountsUserCollapsed));
    final effectiveSalesExpanded =
        !isCollapsed && (salesExpanded || (isSalesRoute && !salesUserCollapsed));
    final width = isCollapsed ? 80.0 : 250.0;

    // Resolve current role from session
    final session = ref.watch(authControllerProvider).session;
    final role = session != null
        ? AppRole.fromString(session.role)
        : AppRole.artist;

    return Container(
      width: width,
      color: crmColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          24.h,
          _buildLogo(context, isCollapsed: isCollapsed),
          32.h,
          Expanded(
            child: ListView(
              padding: 16.p,
              children: [
                if (role == AppRole.artist) ...[
                  // ── ARTIST VIEW ───────────────────────────────────────────
                  _SidebarItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/',
                    onTap: () => context.go('/'),
                  ),
                  _SidebarItem(
                    icon: Icons.event_note_outlined,
                    title: 'My Works',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/works',
                    onTap: () => context.go('/works'),
                  ),
                  _SidebarItem(
                    icon: Icons.calendar_today_outlined,
                    title: 'Leave Request',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/leave-requests',
                    onTap: () => context.go('/leave-requests'),
                  ),
                  _SidebarItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Finance & Claims',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath.startsWith('/finance'),
                    onTap: () => context.go('/finance'),
                  ),
                ] else ...[
                  // ── STANDARD/ADMIN VIEW ────────────────────────────────────
                  // ── CRM SECTION ──────────────────────────────────────────────
                  if (role.canSeeDashboard || role.canSeeClients ||
                      role.canSeeCalendar || role.canSeeBookings) ...[
                    _buildSectionTitle('CRM', isCollapsed: isCollapsed, theme: theme),
                    8.h,
                  ],
                  if (role.canSeeDashboard)
                    _SidebarItem(
                      icon: Icons.dashboard_outlined,
                      title: 'Dashboard',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath == '/',
                      onTap: () => context.go('/'),
                    ),
                  if (role.canSeeClients)
                    _SidebarItem(
                      icon: Icons.people_outline,
                      title: 'Clients',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath.startsWith('/client'),
                      onTap: () => context.go('/clients'),
                    ),
                  if (role.canSeeCalendar)
                    _SidebarItem(
                      icon: Icons.calendar_month,
                      title: 'Calendar',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath == '/calendar',
                      onTap: () => context.go('/calendar'),
                    ),
                  if (role.canSeeBookings)
                    _SidebarItem(
                      icon: Icons.receipt_long_outlined,
                      title: 'Booking',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath.startsWith('/booking'),
                      onTap: () => context.go('/booking/requests'),
                    ),

                  // ── ERP SECTION ──────────────────────────────────────────────
                  if (role.canSeeServices || role.canSeeStaff ||
                      role.canSeeSales || role.canSeeFinance || role.canSeeFleet) ...[
                    32.h,
                    _buildSectionTitle('ERP', isCollapsed: isCollapsed, theme: theme),
                    8.h,
                  ],
                  if (role.canSeeServices) ...[
                    _SidebarItem(
                      icon: Icons.design_services_outlined,
                      title: 'Services',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath.startsWith('/services'),
                      onTap: () => context.go('/services'),
                    ),
                  ],
                  if (role.canSeeStaff)
                    _SidebarItem(
                      icon: Icons.badge_outlined,
                      title: 'Staff Management',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath.startsWith('/staff'),
                      onTap: () => context.go('/staff'),
                    ),
                  if (role.canSeeSales) ...[
                    _SidebarItem(
                      icon: Icons.bar_chart_outlined,
                      title: 'Sales',
                      isCollapsed: isCollapsed,
                      isSelected: isSalesRoute,
                      trailing: isCollapsed
                          ? null
                          : Icon(
                              effectiveSalesExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                      onTap: () {
                        onSalesExpandToggle(!salesExpanded || salesUserCollapsed);
                      },
                    ),
                    if (!isCollapsed && effectiveSalesExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.receipt_long_outlined,
                          title: 'Invoices & Bookings',
                          isCollapsed: false,
                          isSelected: currentPath == '/sales',
                          onTap: () => context.go('/sales'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'Leads Data Entry',
                          isCollapsed: false,
                          isSelected: currentPath == '/sales/leads',
                          onTap: () => context.go('/sales/leads'),
                        ),
                      ),
                    ],
                  ],
                  if (role.canSeeFinance) ...[
                    _SidebarItem(
                      icon: Icons.account_balance,
                      title: 'Accounts',
                      isCollapsed: isCollapsed,
                      isSelected: isAccountsRoute,
                      trailing: isCollapsed
                          ? null
                          : Icon(
                              effectiveAccountsExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                      onTap: () {
                        onAccountsExpandToggle(!accountsExpanded || accountsUserCollapsed);
                      },
                    ),
                    if (!isCollapsed && effectiveAccountsExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Artist Collections',
                          isCollapsed: false,
                          isSelected: currentPath == '/accounts/artist-collections',
                          onTap: () => context.go('/accounts/artist-collections'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.receipt_outlined,
                          title: 'Artist Finance',
                          isCollapsed: false,
                          isSelected: currentPath == '/finance',
                          onTap: () => context.go('/finance'),
                        ),
                      ),
                    ],
                  ],
                  if (role.canSeeFleet) ...[
                    _SidebarItem(
                      icon: Icons.local_shipping_outlined,
                      title: 'Fleet',
                      isCollapsed: isCollapsed,
                      isSelected: isFleetRoute,
                      trailing: isCollapsed
                          ? null
                          : Icon(
                              effectiveFleetExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                      onTap: () {
                        onFleetExpandToggle(!fleetExpanded || fleetUserCollapsed);
                      },
                    ),
                    if (!isCollapsed && effectiveFleetExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.directions_car_outlined,
                          title: 'Cars',
                          isCollapsed: false,
                          isSelected: currentPath == '/fleet/vehicles',
                          onTap: () => context.go('/fleet/vehicles'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.badge_outlined,
                          title: 'Drivers',
                          isCollapsed: false,
                          isSelected: currentPath == '/fleet/drivers',
                          onTap: () => context.go('/fleet/drivers'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.local_gas_station_outlined,
                          title: 'Expenses',
                          isCollapsed: false,
                          isSelected: currentPath == '/fleet/fuel',
                          onTap: () => context.go('/fleet/fuel'),
                        ),
                      ),
                    ],
                  ],

                  // ── BUSINESS SECTION ─────────────────────────────────────────
                  if (role.canSeeSettings || role.isFullAccess) ...[
                    32.h,
                    _buildSectionTitle('BUSINESS', isCollapsed: isCollapsed, theme: theme),
                    8.h,
                    _SidebarItem(
                      icon: Icons.campaign_outlined,
                      title: 'Marketing',
                      isCollapsed: isCollapsed,
                    ),
                    _SidebarItem(
                      icon: Icons.analytics_outlined,
                      title: 'Reports & Analytics',
                      isCollapsed: isCollapsed,
                    ),
                    if (role.canSeeSettings)
                      _SidebarItem(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        isCollapsed: isCollapsed,
                        isSelected: currentPath.startsWith('/settings'),
                        onTap: () => context.go('/settings'),
                      ),
                  ],
                ],
              ],
            ),
          ),
          // ── BOTTOM SECTION ─────────────────────────────────────────────────
          const Divider(height: 1, color: Colors.white12),
          Padding(
            padding: 16.p,
            child: _SidebarItem(
              icon: Icons.account_circle_outlined,
              title: 'My Profile',
              isCollapsed: isCollapsed,
              isSelected: currentPath == '/profile',
              onTap: () => context.go('/profile'),
            ),
          ),
          16.h,
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context, {required bool isCollapsed}) {
    final crmColors = context.crmColors;
    return Padding(
      padding: 16.px,
      child: Row(
        mainAxisAlignment: isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Container(
            padding: 8.p,
            decoration: BoxDecoration(
              color: crmColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/images/nizan_logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
          if (!isCollapsed) ...[
            12.w,
            Expanded(
              child: Text(
                'Nizan\nMakeovers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: crmColors.sidebarForeground,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title, {
    required bool isCollapsed,
    required ThemeData theme,
  }) {
    final crmColors = theme.extension<CrmTheme>()!;
    if (isCollapsed) {
      return Center(
        child: Divider(
          color: crmColors.sidebarForeground.withValues(alpha: 0.16),
        ),
      );
    }
    return Padding(
      padding: 8.px,
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: crmColors.sidebarForeground.withValues(alpha: 0.54),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isCollapsed;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isCollapsed,
    this.isSelected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: 4.py,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: 12.p,
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.70),
                size: 22,
              ),
              if (!isCollapsed) ...[
                12.w,
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.70),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                ...?(trailing != null ? [trailing!] : null),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
