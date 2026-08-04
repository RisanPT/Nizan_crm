import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../auth/app_role.dart';
import '../auth/access_control.dart';
import '../../presentation/common_widgets/main_layout.dart';
import '../../presentation/screens/dashboard_screen.dart';
import '../../presentation/screens/clients_directory_screen.dart';
import '../../presentation/screens/client_profile_screen.dart';
import 'package:nizan_crm/features/bookings/presentation/screens/calendar_screen.dart';
import '../../presentation/screens/staff_management_screen.dart';
import '../../presentation/screens/slot_management_screen.dart';
import '../../presentation/screens/services_management_screen.dart';
import 'package:nizan_crm/features/bookings/presentation/screens/add_booking_screen.dart';
import 'package:nizan_crm/features/bookings/presentation/screens/manage_booking_screen.dart';
import '../../presentation/screens/add_service_screen.dart';
import '../../presentation/screens/geographic_management_screen.dart';
import '../../presentation/screens/addon_services_management_screen.dart';
import '../../presentation/screens/package_detail_screen.dart';
import 'package:nizan_crm/features/bookings/presentation/screens/booking_requests_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/accounts_budget_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/accounts_invoices_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/administrative_expenses_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/administrative_subscriptions_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/administrative_salaries_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/operations_salaries_screen.dart';
import '../../presentation/screens/hr_salaries_screen.dart';
import '../../features/hr/presentation/screens/attendance_summary_screen.dart';
import '../../features/hr/presentation/screens/attendance_payroll_screen.dart';


import '../../presentation/screens/login_screen.dart';
import '../../features/sales/presentation/screens/sales_invoices_screen.dart';
import '../../features/sales/presentation/screens/sales_quarterly_screen.dart';
import '../../features/sales/presentation/screens/cancelled_works_screen.dart';
import '../../features/marketing/presentation/screens/marketing_dashboard_screen.dart';
import '../../features/marketing/presentation/screens/competitors_screen.dart';
import '../../features/marketing/presentation/screens/growth_scores_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/settings/roles_permissions_screen.dart';
import '../../features/team/presentation/screens/team_management_screen.dart';
import '../../features/sales/presentation/screens/sales_dashboard_screen.dart';
import '../../features/sales/presentation/screens/sales_period_detail_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fleet_vehicles_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fleet_drivers_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fleet_assignments_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fuel_expenses_screen.dart';
import '../../presentation/screens/artist_finance_screen.dart';
import '../../presentation/screens/leave_request_screen.dart';
import '../../presentation/screens/profile_screen.dart';
import '../../features/trials/presentation/screens/trial_packages_screen.dart';
import '../../presentation/screens/artist_works_screen.dart';
import '../../features/accounts/presentation/screens/accounts_collections_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/accounts_dashboard_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/accounts_fleet_expenses_screen.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/accounts_bills_screen.dart';
import 'package:nizan_crm/features/inventory/presentation/screens/inventory_dashboard_screen.dart';
import 'package:nizan_crm/features/inventory/presentation/screens/inventory_stock_screen.dart';
import 'package:nizan_crm/features/inventory/presentation/screens/inventory_kits_screen.dart';
import 'package:nizan_crm/features/inventory/presentation/screens/inventory_alerts_screen.dart';
import 'package:nizan_crm/features/inventory/presentation/screens/inventory_expiry_screen.dart';
import 'package:nizan_crm/features/inventory/presentation/screens/inventory_reports_screen.dart';
import 'package:nizan_crm/features/inventory/presentation/screens/inventory_purchases_screen.dart';
import 'package:nizan_crm/features/inventory/presentation/screens/inventory_vendors_screen.dart';
import 'package:nizan_crm/features/inventory/presentation/screens/artist_inventory_screen.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_workspace_screen.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_person_dashboard_screen.dart';
import 'package:nizan_crm/features/reports/presentation/screens/financial_analyst_report_screen.dart';
import 'package:nizan_crm/features/sales/presentation/screens/lead_details_screen.dart';
import 'package:nizan_crm/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/driver_dashboard.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/pre_trip_inspection_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/active_job_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/driver_works_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/driver_add_expense_screen.dart';

import 'package:nizan_crm/features/fleet/presentation/screens/fleet_accidents_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fleet_completed_works_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fleet_service_reminders_screen.dart';
import '../../features/trials/presentation/screens/trials_screen.dart';
import '../../features/trials/presentation/screens/trials_calendar_screen.dart';
import '../../features/trials/presentation/screens/manage_trial_screen.dart';
// Create a global key for the root navigator
final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

DateTime? _parseCalendarFocusDate(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;

  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Maps a concrete route to its sub-feature permission key (`sales.leads`),
/// or null when the route has no finer-grained key (fall back to the module).
String? subKeyForPath(String path) {
  // Sales
  if (path.startsWith('/sales/leads')) return 'sales.leads';
  if (path.startsWith('/sales/dashboard')) return 'sales.dashboard';
  if (path == '/sales/quarterly') return 'sales.quarterly';
  if (path == '/sales/cancelled') return 'sales.cancelled';
  if (path == '/sales') return 'sales.invoices';
  // Accounts (payables)
  if (path == '/accounts/dashboard') return 'payables.dashboard';
  if (path == '/accounts/invoices') return 'payables.invoices';
  if (path.startsWith('/accounts/bills')) return 'payables.bills';
  if (path == '/accounts/artist-collections') return 'payables.collections';
  if (path == '/accounts/fleet-expenses') return 'payables.fleet_expenses';
  if (path == '/accounts/admin-expenses') return 'payables.admin_expenses';
  if (path == '/accounts/subscriptions') return 'payables.subscriptions';
  if (path == '/accounts/admin-salaries') return 'payables.admin_salaries';
  if (path == '/accounts/operations-salaries') return 'payables.operations_salaries';
  if (path == '/accounts/attendance-payroll') return 'payables.admin_salaries';
  // Inventory
  if (path == '/inventory') return 'inventory.dashboard';
  if (path.startsWith('/inventory/stock')) return 'inventory.stock';
  if (path.startsWith('/inventory/kits')) return 'inventory.kits';
  if (path.startsWith('/inventory/alerts')) return 'inventory.alerts';
  if (path.startsWith('/inventory/expiry')) return 'inventory.expiry';
  if (path.startsWith('/inventory/reports')) return 'inventory.reports';
  if (path.startsWith('/inventory/purchases')) return 'inventory.purchases';
  if (path.startsWith('/inventory/vendors')) return 'inventory.vendors';
  // Fleet
  if (path.startsWith('/fleet/assignments')) return 'fleet.assignments';
  if (path.startsWith('/fleet/vehicles')) return 'fleet.vehicles';
  if (path.startsWith('/fleet/drivers')) return 'fleet.drivers';
  if (path.startsWith('/fleet/fuel')) return 'fleet.fuel';
  if (path.startsWith('/fleet/accidents')) return 'fleet.accidents';
  if (path.startsWith('/fleet/completed-works')) return 'fleet.completed';
  if (path.startsWith('/fleet/service-reminders')) return 'fleet.reminders';
  // Marketing
  if (path.startsWith('/marketing/competitors')) return 'marketing.competitors';
  if (path.startsWith('/marketing/scores')) return 'marketing.scores';
  if (path.startsWith('/marketing/dashboard')) return 'marketing.dashboard';
  // Staff / HR
  if (path == '/hr/salaries') return 'staff.salaries';
  if (path == '/hr/slots') return 'staff.slots';
  if (path == '/hr/attendance') return 'staff.attendance';
  if (path.startsWith('/staff')) return 'staff.employees';
  return null;
}

bool isRouteAllowed(String path, Access access, {bool inventoryAccess = false}) {
  final role = access.role;
  if (path == '/' || path == '/auth/loading') return access.canSeeDashboard;
  if (path.startsWith('/client')) return access.canSeeClients;
  if (path.startsWith('/calendar')) return access.canSeeCalendar;
  if (path.startsWith('/booking/manage')) {
    return access.canSeeBookings || role == AppRole.fleetManager;
  }
  if (path.startsWith('/booking')) return access.canSeeBookings;
  if (path.startsWith('/services')) return access.canSeeServices;
  if (path == '/hr/slots') return access.canSeeSub('staff.slots');
  if (path == '/hr/attendance') return access.canSeeSub('staff.attendance');
  if (path.startsWith('/staff')) return access.canSeeSub('staff.employees');
  if (path.startsWith('/sales')) {
    final sub = subKeyForPath(path);
    return sub != null ? access.canSeeSub(sub) : access.canSeeSales;
  }
  if (path.startsWith('/finance')) return access.canSeeFinance;
  // Artist "My Inventory" needs the inventoryAccess flag; the manager views
  // need the inventory-manager (or full-access) role. Artists with inventory
  // access reach their own inventory + their own kit.
  if (path == '/inventory/my') {
    return access.canManageInventory ||
        (role == AppRole.artist && inventoryAccess);
  }
  if (path == '/inventory/kits') {
    return access.canSeeSub('inventory.kits') ||
        (role == AppRole.artist && inventoryAccess);
  }
  if (path.startsWith('/inventory')) {
    final sub = subKeyForPath(path);
    return sub != null ? access.canSeeSub(sub) : access.canManageInventory;
  }
  if (path.startsWith('/accounts')) {
    final sub = subKeyForPath(path);
    return sub != null ? access.canSeeSub(sub) : access.canSeePayables;
  }
  if (path.startsWith('/fleet')) {
    final sub = subKeyForPath(path);
    return sub != null ? access.canSeeSub(sub) : access.canSeeFleet;
  }
  if (path.startsWith('/marketing')) {
    final sub = subKeyForPath(path);
    return sub != null ? access.canSeeSub(sub) : access.canManageMarketing;
  }
  if (path.startsWith('/trials')) return access.canSeeBookings;
  if (path.startsWith('/driver')) return role == AppRole.driver || role == AppRole.fleetManager || access.isFullAccess;
  if (path.startsWith('/reports')) return access.canSeeCEOReport;
  if (path.startsWith('/settings')) return access.canSeeSettings;
  if (path.startsWith('/team')) return access.canManageTeam;
  return true; // unknown routes — let the 404 handle it
}

/// A route the signed-in user is guaranteed to be able to open.
///
/// Prefers their configured landing page, but ONLY when they can actually
/// access it. A custom role (e.g. "Sales Manager") resolves to
/// [AppRole.unknown], whose default home is '/', and its landing page may be
/// left as '/' too — yet it might not have the `dashboard` permission. Without
/// this check the guard would redirect '/' → '/', which go_router treats as a
/// no-op, so the dashboard would render despite being unticked. Here we fall
/// back to the first section the role can actually reach.
String landingRouteFor(Access access, {bool inventoryAccess = false}) {
  final configured = access.homeRoute;
  if (configured.isNotEmpty &&
      isRouteAllowed(configured, access, inventoryAccess: inventoryAccess)) {
    return configured;
  }
  // Fall back to the first route the role can actually open. Each module lists
  // its sub-routes so a role with only, say, `sales.leads` still lands on a page
  // it can reach (not the module's default sub-page it may lack).
  const candidates = <String>[
    '/',
    '/sales/dashboard', '/sales/leads', '/sales', '/sales/quarterly', '/sales/cancelled',
    '/booking/requests',
    '/clients',
    '/calendar',
    '/finance',
    '/accounts/dashboard', '/accounts/invoices', '/accounts/bills',
    '/accounts/artist-collections', '/accounts/fleet-expenses',
    '/accounts/admin-expenses', '/accounts/subscriptions',
    '/accounts/admin-salaries', '/accounts/operations-salaries',
    '/accounts/attendance-payroll',
    '/marketing/dashboard', '/marketing/competitors', '/marketing/scores',
    '/inventory', '/inventory/stock', '/inventory/kits', '/inventory/alerts',
    '/inventory/expiry', '/inventory/reports', '/inventory/purchases', '/inventory/vendors',
    '/fleet/assignments', '/fleet/vehicles', '/fleet/drivers', '/fleet/fuel',
    '/fleet/accidents', '/fleet/completed-works', '/fleet/service-reminders',
    '/staff', '/hr/slots', '/hr/salaries',
  ];
  for (final route in candidates) {
    if (isRouteAllowed(route, access, inventoryAccess: inventoryAccess)) {
      return route;
    }
  }
  return '/login';
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: auth,
    initialLocation: '/',
    // An unknown location (e.g. a stale build after a route was added, or a
    // home route the current build doesn't know) must never strand the user on
    // a "Page Not Found". Send them to a page their role can actually open.
    onException: (context, state, router) {
      if (!auth.isAuthenticated) {
        router.go('/login');
        return;
      }
      final access = Access.of(auth.session);
      final inventoryAccess = auth.session?.inventoryAccess ?? false;
      router.go(landingRouteFor(access, inventoryAccess: inventoryAccess));
    },
    redirect: (context, state) {
      final path = state.uri.path;
      final isLoadingRoute = path == '/auth/loading';
      final isLoginRoute = path == '/login';

      if (auth.isInitializing) {
        return isLoadingRoute ? null : '/auth/loading';
      }

      if (!auth.isAuthenticated) {
        return isLoginRoute ? null : '/login';
      }

      final access = Access.of(auth.session);
      final inventoryAccess = auth.session?.inventoryAccess ?? false;

      // After login, land on a page the role can actually open (respecting its
      // configured home when accessible, else the first reachable section).
      if (isLoadingRoute || isLoginRoute) {
        return landingRouteFor(access, inventoryAccess: inventoryAccess);
      }

      // Role-based route guards.
      if (!isRouteAllowed(path, access, inventoryAccess: inventoryAccess)) {
        return landingRouteFor(access, inventoryAccess: inventoryAccess);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/loading',
        builder: (context, state) => const _AuthLoadingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          // Provide appropriate title based on route
          String title = 'Team N Makeovers';
          if (state.uri.path == '/') {
            title = 'Dashboard Overview';
          } else if (state.uri.path == '/clients') {
            title = 'Clients Directory';
          } else if (state.uri.path == '/booking/requests') {
            title = 'Booking Requests';
          } else if (state.uri.path == '/calendar') {
            title = 'Calendar Scheduler';
          } else if (state.uri.path == '/services') {
            title = 'Services Management';
          } else if (state.uri.path == '/services/regions') {
            title = 'Service Regions';
          } else if (state.uri.path == '/services/addons') {
            title = 'Add-on Services';
          } else if (state.uri.path == '/staff') {
            title = 'Staff Management';
          } else if (state.uri.path == '/hr/slots') {
            title = 'Slot Management';
          } else if (state.uri.path == '/sales') {
            title = 'Sales & Invoices';
          } else if (state.uri.path == '/sales/dashboard') {
            title = 'Sales Dashboard';
          } else if (state.uri.path == '/sales/dashboard/today') {
            title = "Today's Sales";
          } else if (state.uri.path == '/sales/dashboard/week') {
            title = 'This Week';
          } else if (state.uri.path == '/sales/dashboard/day') {
            title = 'Day Report';
          } else if (state.uri.path == '/sales/quarterly') {
            title = 'Quarterly Performance';
          } else if (state.uri.path == '/sales/cancelled') {
            title = 'Cancelled Works';
          } else if (state.uri.path == '/reports/analyst') {
            title = 'Financial Report';
          } else if (state.uri.path == '/sales/home') {
            title = 'My Dashboard';
          } else if (state.uri.path == '/sales/leads') {
            title = 'Sales Workspace';
          } else if (state.uri.path.startsWith('/sales/leads/')) {
            title = 'Lead Details';
          } else if (state.uri.path == '/fleet/vehicles') {
            title = 'Fleet Vehicles';
          } else if (state.uri.path == '/fleet/drivers') {
            title = 'Fleet Drivers';
          } else if (state.uri.path == '/fleet/assignments') {
            title = 'Fleet Assignments';
          } else if (state.uri.path == '/fleet/fuel') {
            title = 'Fleet Expenses';
          } else if (state.uri.path == '/fleet/accidents') {
            title = 'Accident Claims';
          } else if (state.uri.path == '/fleet/completed-works') {
            title = 'Completed Works';
          } else if (state.uri.path == '/fleet/service-reminders') {
            title = 'Service Reminders';
          } else if (state.uri.path == '/driver/jobs') {
            title = 'Driver Dashboard';
          } else if (state.uri.path == '/driver/works') {
            title = 'Driver Works';
          } else if (state.uri.path == '/driver/expenses') {
            title = 'Add Expense';
          } else if (state.uri.path == '/inventory') {
            title = 'Inventory Dashboard';
          } else if (state.uri.path == '/inventory/stock') {
            title = 'Stock List';
          } else if (state.uri.path == '/inventory/kits') {
            title = 'Staff Kits';
          } else if (state.uri.path == '/inventory/alerts') {
            title = 'Restock Alerts';
          } else if (state.uri.path == '/inventory/expiry') {
            title = 'Expiry Tracker';
          } else if (state.uri.path == '/inventory/reports') {
            title = 'Inventory Reports';
          } else if (state.uri.path == '/inventory/purchases') {
            title = 'Purchases';
          } else if (state.uri.path == '/inventory/vendors') {
            title = 'Vendors';
          } else if (state.uri.path == '/inventory/my') {
            title = 'My Inventory';
          } else if (state.uri.path == '/accounts/dashboard') {
            title = 'Accounts Dashboard';
          } else if (state.uri.path == '/accounts/artist-collections') {
            title = 'Artist Collections';
          } else if (state.uri.path == '/accounts/invoices') {
            title = 'Invoices';
          } else if (state.uri.path == '/accounts/bills') {
            title = 'Bills & Payables';
          } else if (state.uri.path == '/accounts/fleet-expenses') {
            title = 'Fleet Expenses';
          } else if (state.uri.path == '/accounts/admin-expenses') {
            title = 'Administrative Expenses';
          } else if (state.uri.path == '/accounts/subscriptions') {
            title = 'Software & Subscriptions';
          } else if (state.uri.path == '/marketing/dashboard') {
            title = 'Marketing Intelligence';
          } else if (state.uri.path == '/marketing/competitors') {
            title = 'Competitors';
          } else if (state.uri.path == '/marketing/scores') {
            title = 'Weekly Growth Score';
          } else if (state.uri.path == '/finance') {
            title = 'Artist Finance';
          } else if (state.uri.path == '/works') {
            title = 'My Works';
          } else if (state.uri.path == '/leave-requests') {
            title = 'Leave Requests';
          } else if (state.uri.path == '/notifications') {
            title = 'Notifications';
          } else if (state.uri.path == '/profile') {
            title = 'My Profile';
          } else if (state.uri.path == '/settings') {
            title = 'Settings';
          } else if (state.uri.path == '/trials') {
            title = 'Trials Calendar';
          } else if (state.uri.path == '/trials/list') {
            title = 'Studio Trials';
          } else if (state.uri.path.startsWith('/trials/')) {
            title = 'Manage Trial';
          } else if (state.uri.path == '/trial-packages') {
            title = 'Trial Packages';
          }

          return MainLayout(title: title, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          // We will add other routes here as we build them.
          GoRoute(
            path: '/clients',
            builder: (context, state) => const ClientsDirectoryScreen(),
          ),

          GoRoute(
            path: '/client/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return ClientProfileScreen(clientId: id);
            },
          ),
          GoRoute(
            path: '/calendar',
            builder: (context, state) => CalendarScreen(
              initialFocusDate: _parseCalendarFocusDate(
                state.uri.queryParameters['date'],
              ),
            ),
          ),
          GoRoute(
            path: '/works',
            builder: (context, state) => const ArtistWorksScreen(),
          ),
          GoRoute(
            path: '/leave-requests',
            builder: (context, state) => const LeaveRequestScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/services',
            builder: (context, state) => const ServicesManagementScreen(),
          ),
          GoRoute(
            path: '/services/add',
            builder: (context, state) => AddServiceScreen(
              packageId: state.uri.queryParameters['id'],
            ),
          ),
          GoRoute(
            path: '/services/detail',
            builder: (context, state) => PackageDetailScreen(
              packageId: state.uri.queryParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/services/regions',
            builder: (context, state) => const GeographicManagementScreen(),
          ),
          GoRoute(
            path: '/services/addons',
            builder: (context, state) => const AddonServicesManagementScreen(),
          ),
          GoRoute(
            path: '/staff',
            builder: (context, state) => const StaffManagementScreen(),
          ),
          GoRoute(
            path: '/hr/salaries',
            builder: (context, state) => const HRSalariesScreen(),
          ),
          GoRoute(
            path: '/hr/slots',
            builder: (context, state) => const SlotManagementScreen(),
          ),
          GoRoute(
            path: '/hr/attendance',
            builder: (context, state) => const AttendanceSummaryScreen(),
          ),
          GoRoute(
            path: '/accounts/attendance-payroll',
            builder: (context, state) => const AttendancePayrollScreen(),
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesBookingsScreen(),
          ),
          GoRoute(
            path: '/sales/quarterly',
            builder: (context, state) => SalesQuarterlyScreen(
              financialYear:
                  state.uri.queryParameters['fy'] ?? '2026-27',
              dateBasis:
                  state.uri.queryParameters['basis'] ?? 'event_date',
            ),
          ),
          GoRoute(
            path: '/sales/cancelled',
            builder: (context, state) => const CancelledWorksScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/sales/home',
            builder: (context, state) => const SalesPersonDashboardScreen(),
          ),
          GoRoute(
            path: '/reports/analyst',
            builder: (context, state) => const FinancialAnalystReportScreen(),
          ),
          GoRoute(
            path: '/sales/leads',
            builder: (context, state) => const SalesWorkspaceScreen(),
          ),
          GoRoute(
            path: '/sales/leads/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return LeadDetailsScreen(leadId: id);
            },
          ),
          GoRoute(
            path: '/fleet/vehicles',
            builder: (context, state) => const FleetVehiclesScreen(),
          ),
          GoRoute(
            path: '/fleet/drivers',
            builder: (context, state) => const FleetDriversScreen(),
          ),
          GoRoute(
            path: '/fleet/assignments',
            builder: (context, state) => const FleetAssignmentsScreen(),
          ),
          GoRoute(
            path: '/fleet/fuel',
            builder: (context, state) => const FuelExpensesScreen(),
          ),
          GoRoute(
            path: '/fleet/accidents',
            builder: (context, state) => const FleetAccidentsScreen(),
          ),
          GoRoute(
            path: '/fleet/completed-works',
            builder: (context, state) => const FleetCompletedWorksScreen(),
          ),
          GoRoute(
            path: '/fleet/service-reminders',
            builder: (context, state) => const FleetServiceRemindersScreen(),
          ),
          GoRoute(
            path: '/accounts/dashboard',
            builder: (context, state) => const AccountsDashboardScreen(),
          ),
          GoRoute(
            path: '/accounts/bills',
            builder: (context, state) => const AccountsBillsScreen(),
          ),
          GoRoute(
            path: '/accounts/fleet-expenses',
            builder: (context, state) =>
                const AccountsFleetExpensesScreen(),
          ),
          GoRoute(
            path: '/accounts/admin-expenses',
            builder: (context, state) =>
                const AdministrativeExpensesScreen(),
          ),
          GoRoute(
            path: '/accounts/subscriptions',
            builder: (context, state) =>
                const AdministrativeSubscriptionsScreen(),
          ),
          GoRoute(
            path: '/accounts/admin-salaries',
            builder: (context, state) =>
                const AdministrativeSalariesScreen(),
          ),
          GoRoute(
            path: '/accounts/operations-salaries',
            builder: (context, state) =>
                const OperationsSalariesScreen(),
          ),
          // ── Marketing (Competitor Intelligence) ──────────────────────
          GoRoute(
            path: '/marketing/dashboard',
            builder: (context, state) => const MarketingDashboardScreen(),
          ),
          GoRoute(
            path: '/marketing/competitors',
            builder: (context, state) => const CompetitorsScreen(),
          ),
          GoRoute(
            path: '/marketing/scores',
            builder: (context, state) => const GrowthScoresScreen(),
          ),
          // ── Inventory ────────────────────────────────────────────────
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryDashboardScreen(),
          ),
          GoRoute(
            path: '/inventory/stock',
            builder: (context, state) => const InventoryStockScreen(),
          ),
          GoRoute(
            path: '/inventory/kits',
            builder: (context, state) => const InventoryKitsScreen(),
          ),
          GoRoute(
            path: '/inventory/alerts',
            builder: (context, state) => const InventoryAlertsScreen(),
          ),
          GoRoute(
            path: '/inventory/expiry',
            builder: (context, state) => const InventoryExpiryScreen(),
          ),
          GoRoute(
            path: '/inventory/reports',
            builder: (context, state) => const InventoryReportsScreen(),
          ),
          GoRoute(
            path: '/inventory/purchases',
            builder: (context, state) => const InventoryPurchasesScreen(),
          ),
          GoRoute(
            path: '/inventory/vendors',
            builder: (context, state) => const InventoryVendorsScreen(),
          ),
          GoRoute(
            path: '/inventory/my',
            builder: (context, state) => const ArtistInventoryScreen(),
          ),
          GoRoute(
            path: '/accounts/artist-collections',
            builder: (context, state) => const AccountsCollectionsScreen(),
          ),
          GoRoute(
            path: '/accounts/budget',
            builder: (context, state) => const AccountsBudgetScreen(),
          ),
          GoRoute(
            path: '/accounts/invoices',
            builder: (context, state) => const AccountsInvoicesScreen(),
          ),
          GoRoute(
            path: '/trials',
            builder: (context, state) => const TrialsCalendarScreen(),
          ),
          GoRoute(
            path: '/trials/list',
            builder: (context, state) => const TrialsScreen(),
          ),
          GoRoute(
            path: '/trials/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? 'new';
              return ManageTrialScreen(trialId: id);
            },
          ),
          GoRoute(
            path: '/trial-packages',
            builder: (context, state) => const TrialPackagesScreen(),
          ),
          GoRoute(
            path: '/booking/add',
            builder: (context, state) => const AddBookingScreen(),
          ),
          GoRoute(
            path: '/booking/requests',
            builder: (context, state) => const BookingRequestsScreen(),
          ),
          GoRoute(
            path: '/booking/manage/:id',
            builder: (context, state) => ManageBookingScreen(
              bookingId: state.pathParameters['id'] ?? '1042',
              bookingEntryId: state.uri.queryParameters['entry'],
            ),
          ),
          GoRoute(
            path: '/finance',
            builder: (context, state) => const ArtistFinanceScreen(),
          ),
          GoRoute(
            path: '/sales/dashboard',
            builder: (context, state) => const SalesDashboardScreen(),
          ),
          GoRoute(
            path: '/sales/dashboard/today',
            builder: (context, state) =>
                const SalesPeriodDetailScreen(mode: 'today'),
          ),
          GoRoute(
            path: '/sales/dashboard/week',
            builder: (context, state) =>
                const SalesPeriodDetailScreen(mode: 'week'),
          ),
          GoRoute(
            path: '/sales/dashboard/day',
            builder: (context, state) => SalesPeriodDetailScreen(
              mode: 'day',
              date: DateTime.tryParse(
                  state.uri.queryParameters['date'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/roles',
            builder: (context, state) => const RolesPermissionsScreen(),
          ),
          GoRoute(
            path: '/team/manage',
            builder: (context, state) => const TeamManagementScreen(),
          ),
          GoRoute(
            path: '/driver/jobs',
            builder: (context, state) => const DriverDashboard(),
          ),
          GoRoute(
            path: '/driver/works',
            builder: (context, state) => const DriverWorksScreen(),
          ),
          GoRoute(
            path: '/driver/inspection/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return PreTripInspectionScreen(jobId: id);
            },
          ),
          GoRoute(
            path: '/driver/active_job/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return ActiveJobScreen(jobId: id); 
            },
          ),
          GoRoute(
            path: '/driver/expenses',
            builder: (context, state) => const DriverAddExpenseScreen(),
          ),
          GoRoute(
            path: '/driver/works/:id/expense',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return DriverAddExpenseScreen(jobId: id);
            },
          ),
        ],
      ),
    ],
  );
});

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
