import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/app_role.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/responsive_builder.dart';
import 'accounts_menu_sheet.dart';
import 'fleet_menu_sheet.dart';
import 'inventory_menu_sheet.dart';
import 'sidebar.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final String title;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  bool _fleetExpanded = false;
  bool _fleetUserCollapsed = false;
  bool _accountsExpanded = false;
  bool _accountsUserCollapsed = false;
  bool _operationsExpanded = false;
  bool _operationsUserCollapsed = false;
  bool _inventoryExpanded = false;
  bool _inventoryUserCollapsed = false;
  bool _salesExpanded = false;
  bool _salesUserCollapsed = false;
  bool _hrExpanded = false;
  bool _hrUserCollapsed = false;

  int _calculateSelectedIndex(BuildContext context, AppRole role) {
    final location = GoRouterState.of(context).uri.path;
    if (role == AppRole.artist) {
      final inv = ref.read(authSessionProvider)?.inventoryAccess ?? false;
      if (location == '/') return 0;
      if (location == '/works') return 1;
      if (location == '/finance') return 2;
      if (inv) {
        if (location.startsWith('/inventory')) return 3;
        if (location == '/profile') return 4;
      } else {
        if (location == '/profile') return 3;
      }
    } else if (role == AppRole.inventoryManager) {
      if (location == '/inventory') return 0;
      if (location == '/inventory/stock') return 1;
      if (location == '/inventory/kits') return 2;
      return 3; // Alerts / Expiry / Reports / Profile live in the Menu sheet.
    } else if (role == AppRole.sales) {
      if (location.startsWith('/sales/leads')) return 0;
      if (location == '/calendar') return 1;
      if (location.startsWith('/booking')) return 2;
      if (location == '/sales') return 3;
      if (location == '/profile') return 4;
    } else if (role == AppRole.fleetManager) {
      if (location.startsWith('/fleet/assignments')) return 0;
      if (location.startsWith('/fleet/vehicles')) return 1;
      if (location.startsWith('/fleet/drivers')) return 2;
      if (location == '/calendar') return 3;
      // Everything else the fleet manager can reach (profile + the fleet
      // sections that live in the "Menu" sheet) highlights the Menu tab.
      return 4;
    } else if (role == AppRole.driver) {
      if (location.startsWith('/driver/jobs')) return 0;
      if (location.startsWith('/driver/works')) return 1;
      if (location == '/profile') return 2;
    } else if (role == AppRole.accounts) {
      if (location == '/accounts/dashboard') return 0;
      if (location.startsWith('/finance')) return 1;
      if (location == '/accounts/artist-collections') return 2;
      // Invoice / Budget / Profile live in the Menu sheet.
      return 3;
    } else if (role == AppRole.marketingAdmin) {
      if (location == '/marketing/dashboard') return 0;
      if (location.startsWith('/marketing/competitors')) return 1;
      if (location.startsWith('/marketing/scores')) return 2;
      return 0;
    } else {
      if (location == '/') return 0;
      if (location.startsWith('/clients')) return 1;
      if (location == '/calendar') return 2;
      if (location.startsWith('/booking')) return 3;
      if (location.startsWith('/finance')) return 4;
    }
    return 0;
  }

  void _onItemTapped(int index, AppRole role) {
    if (role == AppRole.artist) {
      final inv = ref.read(authSessionProvider)?.inventoryAccess ?? false;
      if (inv) {
        switch (index) {
          case 0: context.go('/'); break;
          case 1: context.go('/works'); break;
          case 2: context.go('/finance'); break;
          case 3: context.go('/inventory/my'); break;
          case 4: context.go('/profile'); break;
        }
      } else {
        switch (index) {
          case 0: context.go('/'); break;
          case 1: context.go('/works'); break;
          case 2: context.go('/finance'); break;
          case 3: context.go('/profile'); break;
        }
      }
    } else if (role == AppRole.inventoryManager) {
      switch (index) {
        case 0: context.go('/inventory'); break;
        case 1: context.go('/inventory/stock'); break;
        case 2: context.go('/inventory/kits'); break;
        case 3: showInventoryMenuSheet(context, ref); break;
      }
    } else if (role == AppRole.sales) {
      switch (index) {
        case 0: context.go('/sales/leads'); break;
        case 1: context.go('/calendar'); break;
        case 2: context.go('/booking/requests'); break;
        case 3: context.go('/sales'); break;
        case 4: context.go('/profile'); break;
      }
    } else if (role == AppRole.fleetManager) {
      switch (index) {
        case 0: context.go('/fleet/assignments'); break;
        case 1: context.go('/fleet/vehicles'); break;
        case 2: context.go('/fleet/drivers'); break;
        case 3: context.go('/calendar'); break;
        case 4: showFleetMenuSheet(context, ref); break; // opens the hamburger menu
      }
    } else if (role == AppRole.driver) {
      switch (index) {
        case 0: context.go('/driver/jobs'); break;
        case 1: context.go('/driver/works'); break;
        case 2: context.go('/profile'); break;
      }
    } else if (role == AppRole.accounts) {
      switch (index) {
        case 0: context.go('/accounts/dashboard'); break;
        case 1: context.go('/finance'); break;
        case 2: context.go('/accounts/artist-collections'); break;
        case 3: showAccountsMenuSheet(context, ref); break; // opens the menu
      }
    } else if (role == AppRole.marketingAdmin) {
      switch (index) {
        case 0: context.go('/marketing/dashboard'); break;
        case 1: context.go('/marketing/competitors'); break;
        case 2: context.go('/marketing/scores'); break;
      }
    } else {
      switch (index) {
        case 0: context.go('/'); break;
        case 1: context.go('/clients'); break;
        case 2: context.go('/calendar'); break;
        case 3: context.go('/booking/requests'); break;
        case 4: context.go('/finance'); break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final session = ref.watch(authSessionProvider);
    final role = session != null
        ? AppRole.fromString(session.role)
        : AppRole.artist;
    final invAccess = session?.inventoryAccess ?? false;

    if (isMobile) {
      return Scaffold(
        body: SafeArea(child: widget.child),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _calculateSelectedIndex(context, role),
          onDestinationSelected: (index) => _onItemTapped(index, role),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          destinations: role == AppRole.artist
              ? [
                  const NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Home',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.event_note_outlined),
                    selectedIcon: Icon(Icons.event_note),
                    label: 'Works',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: Icon(Icons.account_balance_wallet),
                    label: 'Finance',
                  ),
                  if (invAccess)
                    const NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Inventory',
                    ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ]
              : role == AppRole.inventoryManager
                  ? const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: 'Dashboard',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.list_alt_outlined),
                        selectedIcon: Icon(Icons.list_alt),
                        label: 'Stock',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.work_outline),
                        selectedIcon: Icon(Icons.work),
                        label: 'Kits',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.menu),
                        selectedIcon: Icon(Icons.menu_open),
                        label: 'Menu',
                      ),
                    ]
              : role == AppRole.sales
                  ? const [
                      NavigationDestination(
                        icon: Icon(Icons.person_add_alt_1_outlined),
                        selectedIcon: Icon(Icons.person_add_alt_1),
                        label: 'Leads',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: 'Calendar',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: 'Bookings',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bar_chart_outlined),
                        selectedIcon: Icon(Icons.bar_chart),
                        label: 'Sales',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: 'Profile',
                      ),
                    ]
                  : role == AppRole.fleetManager
                      ? const [
                          NavigationDestination(
                            icon: Icon(Icons.assignment_outlined),
                            selectedIcon: Icon(Icons.assignment),
                            label: 'Assign',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.directions_car_outlined),
                            selectedIcon: Icon(Icons.directions_car),
                            label: 'Cars',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.badge_outlined),
                            selectedIcon: Icon(Icons.badge),
                            label: 'Drivers',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.calendar_month_outlined),
                            selectedIcon: Icon(Icons.calendar_month),
                            label: 'Calendar',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.menu),
                            selectedIcon: Icon(Icons.menu_open),
                            label: 'Menu',
                          ),
                        ]
                  : role == AppRole.driver
                      ? const [
                          NavigationDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            selectedIcon: Icon(Icons.dashboard),
                            label: 'Home',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.list_alt_outlined),
                            selectedIcon: Icon(Icons.list_alt),
                            label: 'Works',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.person_outline),
                            selectedIcon: Icon(Icons.person),
                            label: 'Profile',
                          ),
                        ]
                      : role == AppRole.accounts
                          ? const [
                              NavigationDestination(
                                icon: Icon(Icons.donut_small_outlined),
                                selectedIcon: Icon(Icons.donut_small),
                                label: 'Dashboard',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.receipt_outlined),
                                selectedIcon: Icon(Icons.receipt),
                                label: 'Finance',
                              ),
                              NavigationDestination(
                                icon: Icon(
                                    Icons.account_balance_wallet_outlined),
                                selectedIcon:
                                    Icon(Icons.account_balance_wallet),
                                label: 'Collection',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.menu),
                                selectedIcon: Icon(Icons.menu_open),
                                label: 'Menu',
                              ),
                            ]
                          : role == AppRole.marketingAdmin
                          ? const [
                              NavigationDestination(
                                icon: Icon(Icons.donut_small_outlined),
                                selectedIcon: Icon(Icons.donut_small),
                                label: 'Overview',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.dataset_outlined),
                                selectedIcon: Icon(Icons.dataset),
                                label: 'Competitors',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.leaderboard_outlined),
                                selectedIcon: Icon(Icons.leaderboard),
                                label: 'Score',
                              ),
                            ]
                          : const [
                          NavigationDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            selectedIcon: Icon(Icons.dashboard),
                            label: 'Home',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.people_outline),
                            selectedIcon: Icon(Icons.people),
                            label: 'Clients',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.calendar_month_outlined),
                            selectedIcon: Icon(Icons.calendar_month),
                            label: 'Calendar',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.receipt_long_outlined),
                            selectedIcon: Icon(Icons.receipt_long),
                            label: 'Bookings',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.account_balance_wallet_outlined),
                            selectedIcon: Icon(Icons.account_balance_wallet),
                            label: 'Finance',
                          ),
                        ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Sidebar(
            fleetExpanded: _fleetExpanded,
            fleetUserCollapsed: _fleetUserCollapsed,
            onFleetExpandToggle: (expanded) {
              setState(() {
                _fleetExpanded = expanded;
                if (!expanded) {
                  _fleetUserCollapsed = true;
                } else {
                  _fleetUserCollapsed = false;
                }
              });
            },
            accountsExpanded: _accountsExpanded,
            accountsUserCollapsed: _accountsUserCollapsed,
            onAccountsExpandToggle: (expanded) {
              setState(() {
                _accountsExpanded = expanded;
                if (!expanded) {
                  _accountsUserCollapsed = true;
                } else {
                  _accountsUserCollapsed = false;
                }
              });
            },
            operationsExpanded: _operationsExpanded,
            operationsUserCollapsed: _operationsUserCollapsed,
            onOperationsExpandToggle: (expanded) {
              setState(() {
                _operationsExpanded = expanded;
                _operationsUserCollapsed = !expanded;
              });
            },
            inventoryExpanded: _inventoryExpanded,
            inventoryUserCollapsed: _inventoryUserCollapsed,
            onInventoryExpandToggle: (expanded) {
              setState(() {
                _inventoryExpanded = expanded;
                _inventoryUserCollapsed = !expanded;
              });
            },
            salesExpanded: _salesExpanded,
            salesUserCollapsed: _salesUserCollapsed,
            onSalesExpandToggle: (expanded) {
              setState(() {
                _salesExpanded = expanded;
                if (!expanded) {
                  _salesUserCollapsed = true;
                } else {
                  _salesUserCollapsed = false;
                }
              });
            },
            hrExpanded: _hrExpanded,
            hrUserCollapsed: _hrUserCollapsed,
            onHrExpandToggle: (expanded) {
              setState(() {
                _hrExpanded = expanded;
                if (!expanded) {
                  _hrUserCollapsed = true;
                } else {
                  _hrUserCollapsed = false;
                }
              });
            },
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
