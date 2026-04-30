import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/app_role.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/responsive_builder.dart';
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
  bool _salesExpanded = false;
  bool _salesUserCollapsed = false;

  int _calculateSelectedIndex(BuildContext context, AppRole role) {
    final location = GoRouterState.of(context).uri.path;
    if (role == AppRole.artist) {
      if (location == '/') return 0;
      if (location == '/works') return 1;
      if (location == '/leave-requests') return 2;
      if (location == '/finance') return 3;
      if (location == '/profile') return 4;
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
      switch (index) {
        case 0: context.go('/'); break;
        case 1: context.go('/works'); break;
        case 2: context.go('/leave-requests'); break;
        case 3: context.go('/finance'); break;
        case 4: context.go('/profile'); break;
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
    final session = ref.watch(authControllerProvider).session;
    final role = session != null
        ? AppRole.fromString(session.role)
        : AppRole.artist;

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
              ? const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.event_note_outlined),
                    selectedIcon: Icon(Icons.event_note),
                    label: 'Works',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_today),
                    label: 'Leaves',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: Icon(Icons.account_balance_wallet),
                    label: 'Finance',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
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
