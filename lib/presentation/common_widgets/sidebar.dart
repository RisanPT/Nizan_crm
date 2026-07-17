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
  final bool operationsExpanded;
  final bool operationsUserCollapsed;
  final ValueChanged<bool> onOperationsExpandToggle;
  final bool inventoryExpanded;
  final bool inventoryUserCollapsed;
  final ValueChanged<bool> onInventoryExpandToggle;
  final bool salesExpanded;
  final bool salesUserCollapsed;
  final ValueChanged<bool> onSalesExpandToggle;
  final bool hrExpanded;
  final bool hrUserCollapsed;
  final ValueChanged<bool> onHrExpandToggle;

  const Sidebar({
    super.key,
    required this.fleetExpanded,
    required this.fleetUserCollapsed,
    required this.onFleetExpandToggle,
    required this.accountsExpanded,
    required this.accountsUserCollapsed,
    required this.onAccountsExpandToggle,
    required this.operationsExpanded,
    required this.operationsUserCollapsed,
    required this.onOperationsExpandToggle,
    required this.inventoryExpanded,
    required this.inventoryUserCollapsed,
    required this.onInventoryExpandToggle,
    required this.salesExpanded,
    required this.salesUserCollapsed,
    required this.onSalesExpandToggle,
    required this.hrExpanded,
    required this.hrUserCollapsed,
    required this.onHrExpandToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isTablet = ResponsiveBuilder.isTablet(context);
    final currentPath = GoRouterState.of(context).uri.path;
    final isFleetRoute = currentPath.startsWith('/fleet');
    // Operations (Dashboard / Artist Finance / Artist Collection) live under Accounts.
    final isOperationsRoute = currentPath == '/accounts/dashboard' ||
        currentPath == '/finance' ||
        currentPath == '/accounts/artist-collections';
    final isAccountsRoute =
        currentPath.startsWith('/accounts') || currentPath == '/finance';
    final isInventoryRoute = currentPath.startsWith('/inventory');
    final isMarketingRoute = currentPath.startsWith('/marketing');
    final isSalesRoute = currentPath.startsWith('/sales');
    final isHrRoute = currentPath.startsWith('/staff') || currentPath.startsWith('/hr');
    final isCollapsed = isTablet && !isMobile;
    final effectiveFleetExpanded =
        !isCollapsed && (fleetExpanded || (isFleetRoute && !fleetUserCollapsed));
    final effectiveAccountsExpanded =
        !isCollapsed && (accountsExpanded || (isAccountsRoute && !accountsUserCollapsed));
    final effectiveOperationsExpanded = !isCollapsed &&
        (operationsExpanded || (isOperationsRoute && !operationsUserCollapsed));
    final effectiveInventoryExpanded = !isCollapsed &&
        (inventoryExpanded || (isInventoryRoute && !inventoryUserCollapsed));
    final effectiveSalesExpanded =
        !isCollapsed && (salesExpanded || (isSalesRoute && !salesUserCollapsed));
    final effectiveHrExpanded =
        !isCollapsed && (hrExpanded || (isHrRoute && !hrUserCollapsed));
    final width = isCollapsed ? 80.0 : 250.0;

    // Resolve current role from session
    final session = ref.watch(authSessionProvider);
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
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Finance & Claims',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath.startsWith('/finance'),
                    onTap: () => context.go('/finance'),
                  ),
                  if (session?.inventoryAccess ?? false) ...[
                    _SidebarItem(
                      icon: Icons.inventory_2_outlined,
                      title: 'My Inventory',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath == '/inventory/my',
                      onTap: () => context.go('/inventory/my'),
                    ),
                    _SidebarItem(
                      icon: Icons.work_outline,
                      title: 'My Kits',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath == '/inventory/kits',
                      onTap: () => context.go('/inventory/kits'),
                    ),
                  ],
                ] else if (role == AppRole.inventoryManager) ...[
                  // ── INVENTORY MANAGER VIEW ────────────────────────────────
                  _SidebarItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/inventory',
                    onTap: () => context.go('/inventory'),
                  ),
                  _SidebarItem(
                    icon: Icons.list_alt_outlined,
                    title: 'Stock List',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/inventory/stock',
                    onTap: () => context.go('/inventory/stock'),
                  ),
                  _SidebarItem(
                    icon: Icons.work_outline,
                    title: 'Staff Kits',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/inventory/kits',
                    onTap: () => context.go('/inventory/kits'),
                  ),
                  _SidebarItem(
                    icon: Icons.warning_amber_rounded,
                    title: 'Restock Alerts',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/inventory/alerts',
                    onTap: () => context.go('/inventory/alerts'),
                  ),
                  _SidebarItem(
                    icon: Icons.hourglass_bottom_outlined,
                    title: 'Expiry Tracker',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/inventory/expiry',
                    onTap: () => context.go('/inventory/expiry'),
                  ),
                  _SidebarItem(
                    icon: Icons.bar_chart_outlined,
                    title: 'Reports',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/inventory/reports',
                    onTap: () => context.go('/inventory/reports'),
                  ),
                  _SidebarItem(
                    icon: Icons.add_shopping_cart_outlined,
                    title: 'Purchases',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/inventory/purchases',
                    onTap: () => context.go('/inventory/purchases'),
                  ),
                  _SidebarItem(
                    icon: Icons.storefront_outlined,
                    title: 'Vendors',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/inventory/vendors',
                    onTap: () => context.go('/inventory/vendors'),
                  ),
                ] else if (role == AppRole.driver) ...[
                  // ── DRIVER VIEW ───────────────────────────────────────────
                  _SidebarItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/driver/jobs',
                    onTap: () => context.go('/driver/jobs'),
                  ),
                  _SidebarItem(
                    icon: Icons.list_alt_outlined,
                    title: 'Works',
                    isCollapsed: isCollapsed,
                    isSelected: currentPath == '/driver/works',
                    onTap: () => context.go('/driver/works'),
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
                      icon: Icons.event_available_outlined,
                      title: 'Trials',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath == '/trials' || currentPath.startsWith('/trials/'),
                      onTap: () => context.go('/trials'),
                    ),
                  if (role.canSeeBookings)
                    _SidebarItem(
                      icon: Icons.auto_awesome_mosaic_outlined,
                      title: 'Trial Packages',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath.startsWith('/trial-packages'),
                      onTap: () => context.go('/trial-packages'),
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
                      isSelected: currentPath == '/services',
                      onTap: () => context.go('/services'),
                    ),
                    _SidebarItem(
                      icon: Icons.map_outlined,
                      title: 'Geographics',
                      isCollapsed: isCollapsed,
                      isSelected: currentPath.startsWith('/services/regions'),
                      onTap: () => context.go('/services/regions'),
                    ),
                  ],
                  if (role.canSeeStaff) ...[
                    _SidebarItem(
                      icon: Icons.groups_outlined,
                      title: 'HR',
                      isCollapsed: isCollapsed,
                      isSelected: isHrRoute,
                      trailing: isCollapsed
                          ? null
                          : Icon(
                              effectiveHrExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                      onTap: () {
                        onHrExpandToggle(!hrExpanded || hrUserCollapsed);
                      },
                    ),
                    if (!isCollapsed && effectiveHrExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.badge_outlined,
                          title: 'Staff Management',
                          isCollapsed: false,
                          isSelected: currentPath.startsWith('/staff'),
                          onTap: () => context.go('/staff'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.event_available_outlined,
                          title: 'Slot Management',
                          isCollapsed: false,
                          isSelected: currentPath.startsWith('/hr/slots'),
                          onTap: () => context.go('/hr/slots'),
                        ),
                      ),
                    ],
                  ],
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
                      // Operations — nested expandable group.
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.dashboard_customize_outlined,
                          title: 'Operations',
                          isCollapsed: false,
                          isSelected: isOperationsRoute,
                          trailing: Icon(
                            effectiveOperationsExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 18,
                          ),
                          onTap: () => onOperationsExpandToggle(
                              !operationsExpanded || operationsUserCollapsed),
                        ),
                      ),
                      if (effectiveOperationsExpanded) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: _SidebarItem(
                            icon: Icons.donut_small_outlined,
                            title: 'Dashboard',
                            isCollapsed: false,
                            isSelected: currentPath == '/accounts/dashboard',
                            onTap: () => context.go('/accounts/dashboard'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: _SidebarItem(
                            icon: Icons.receipt_outlined,
                            title: 'Artist Finance',
                            isCollapsed: false,
                            isSelected: currentPath == '/finance',
                            onTap: () => context.go('/finance'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: _SidebarItem(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Artist Collection',
                            isCollapsed: false,
                            isSelected:
                                currentPath == '/accounts/artist-collections',
                            onTap: () =>
                                context.go('/accounts/artist-collections'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: _SidebarItem(
                            icon: Icons.local_shipping_outlined,
                            title: 'Fleet Expenses',
                            isCollapsed: false,
                            isSelected:
                                currentPath == '/accounts/fleet-expenses',
                            onTap: () =>
                                context.go('/accounts/fleet-expenses'),
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.request_quote_outlined,
                          title: 'Bills & Payables',
                          isCollapsed: false,
                          isSelected: currentPath == '/accounts/bills',
                          onTap: () => context.go('/accounts/bills'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.receipt_long_outlined,
                          title: 'Invoice',
                          isCollapsed: false,
                          isSelected: currentPath == '/accounts/invoices',
                          onTap: () => context.go('/accounts/invoices'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.pie_chart_outline,
                          title: 'Budget',
                          isCollapsed: false,
                          isSelected: currentPath == '/accounts/budget',
                          onTap: () => context.go('/accounts/budget'),
                        ),
                      ),
                    ],
                  ],
                  if (role.canManageInventory) ...[
                    _SidebarItem(
                      icon: Icons.inventory_2_outlined,
                      title: 'Inventory',
                      isCollapsed: isCollapsed,
                      isSelected: isInventoryRoute,
                      trailing: isCollapsed
                          ? null
                          : Icon(
                              effectiveInventoryExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                      onTap: () {
                        onInventoryExpandToggle(
                            !inventoryExpanded || inventoryUserCollapsed);
                      },
                    ),
                    if (!isCollapsed && effectiveInventoryExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.donut_small_outlined,
                          title: 'Dashboard',
                          isCollapsed: false,
                          isSelected: currentPath == '/inventory',
                          onTap: () => context.go('/inventory'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.list_alt_outlined,
                          title: 'Stock List',
                          isCollapsed: false,
                          isSelected: currentPath == '/inventory/stock',
                          onTap: () => context.go('/inventory/stock'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.work_outline,
                          title: 'Staff Kits',
                          isCollapsed: false,
                          isSelected: currentPath == '/inventory/kits',
                          onTap: () => context.go('/inventory/kits'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.warning_amber_rounded,
                          title: 'Restock Alerts',
                          isCollapsed: false,
                          isSelected: currentPath == '/inventory/alerts',
                          onTap: () => context.go('/inventory/alerts'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.hourglass_bottom_outlined,
                          title: 'Expiry Tracker',
                          isCollapsed: false,
                          isSelected: currentPath == '/inventory/expiry',
                          onTap: () => context.go('/inventory/expiry'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.bar_chart_outlined,
                          title: 'Reports',
                          isCollapsed: false,
                          isSelected: currentPath == '/inventory/reports',
                          onTap: () => context.go('/inventory/reports'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.add_shopping_cart_outlined,
                          title: 'Purchases',
                          isCollapsed: false,
                          isSelected: currentPath == '/inventory/purchases',
                          onTap: () => context.go('/inventory/purchases'),
                        ),
                      ),
                    ],
                  ],
                  if (role.canManageMarketing) ...[
                    _SidebarItem(
                      icon: Icons.campaign_outlined,
                      title: 'Marketing',
                      isCollapsed: isCollapsed,
                      isSelected: isMarketingRoute,
                      onTap: () => context.go('/marketing/dashboard'),
                    ),
                    if (!isCollapsed) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.donut_small_outlined,
                          title: 'Dashboard',
                          isCollapsed: false,
                          isSelected: currentPath == '/marketing/dashboard',
                          onTap: () => context.go('/marketing/dashboard'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.dataset_outlined,
                          title: 'Competitors',
                          isCollapsed: false,
                          isSelected: currentPath == '/marketing/competitors',
                          onTap: () => context.go('/marketing/competitors'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.leaderboard_outlined,
                          title: 'Weekly Score',
                          isCollapsed: false,
                          isSelected: currentPath == '/marketing/scores',
                          onTap: () => context.go('/marketing/scores'),
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
                          icon: Icons.assignment_outlined,
                          title: 'Assignments',
                          isCollapsed: false,
                          isSelected: currentPath == '/fleet/assignments',
                          onTap: () => context.go('/fleet/assignments'),
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
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.warning_amber_rounded,
                          title: 'Accidents',
                          isCollapsed: false,
                          isSelected: currentPath == '/fleet/accidents',
                          onTap: () => context.go('/fleet/accidents'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.task_alt_rounded,
                          title: 'Completed Works',
                          isCollapsed: false,
                          isSelected: currentPath == '/fleet/completed-works',
                          onTap: () => context.go('/fleet/completed-works'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: _SidebarItem(
                          icon: Icons.build_circle_outlined,
                          title: 'Service Reminders',
                          isCollapsed: false,
                          isSelected: currentPath == '/fleet/service-reminders',
                          onTap: () => context.go('/fleet/service-reminders'),
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
    final theme = Theme.of(context);
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
              'assets/images/teamn_logo.png',
              height: 48,
              width: 48,
            ),
          ),
          if (!isCollapsed) ...[
            12.w,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Team N\nMakeovers',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: crmColors.sidebarForeground,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    fontSize: 16,
                  ),
                ),
              ],
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
