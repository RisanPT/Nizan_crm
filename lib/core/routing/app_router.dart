import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../auth/app_role.dart';
import '../../presentation/common_widgets/main_layout.dart';
import '../../presentation/screens/dashboard_screen.dart';
import '../../presentation/screens/clients_directory_screen.dart';
import '../../presentation/screens/client_profile_screen.dart';
import '../../presentation/screens/calendar_screen.dart';
import '../../presentation/screens/staff_management_screen.dart';
import '../../presentation/screens/services_management_screen.dart';
import '../../presentation/screens/add_booking_screen.dart';
import '../../presentation/screens/manage_booking_screen.dart';
import '../../presentation/screens/add_service_screen.dart';
import '../../presentation/screens/regions_management_screen.dart';
import '../../presentation/screens/addon_services_management_screen.dart';
import '../../presentation/screens/booking_requests_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/sales_bookings_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/fleet_vehicles_screen.dart';
import '../../presentation/screens/fleet_drivers_screen.dart';
import '../../presentation/screens/fuel_expenses_screen.dart';
import '../../presentation/screens/artist_finance_screen.dart';
import '../../presentation/screens/leave_request_screen.dart';
import '../../presentation/screens/profile_screen.dart';
import '../../presentation/screens/artist_works_screen.dart';
import '../../presentation/screens/accounts_collections_screen.dart';
import '../../presentation/screens/sales_leads_screen.dart';

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

bool _isRouteAllowed(String path, AppRole role) {
  if (path == '/' || path == '/auth/loading') return role.canSeeDashboard;
  if (path.startsWith('/client')) return role.canSeeClients;
  if (path.startsWith('/calendar')) return role.canSeeCalendar;
  if (path.startsWith('/booking')) return role.canSeeBookings;
  if (path.startsWith('/services')) return role.canSeeServices;
  if (path.startsWith('/staff')) return role.canSeeStaff;
  if (path.startsWith('/sales')) return role.canSeeSales;
  if (path.startsWith('/finance')) return role.canSeeFinance;
  if (path.startsWith('/fleet')) return role.canSeeFleet;
  if (path.startsWith('/settings')) return role.canSeeSettings;
  return true; // unknown routes — let the 404 handle it
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: auth,
    initialLocation: '/',
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

      // After login, redirect to role-specific home
      if (isLoadingRoute || isLoginRoute) {
        final role = AppRole.fromString(auth.session?.role);
        return role.homeRoute;
      }

      // Role-based route guards
      final role = AppRole.fromString(auth.session?.role);
      if (!_isRouteAllowed(path, role)) {
        return role.homeRoute;
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
          String title = 'Nizan Makeovers';
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
          } else if (state.uri.path == '/sales') {
            title = 'Sales & Invoices';
          } else if (state.uri.path == '/sales/leads') {
            title = 'Leads Management';
          } else if (state.uri.path == '/fleet/vehicles') {
            title = 'Fleet Vehicles';
          } else if (state.uri.path == '/fleet/drivers') {
            title = 'Fleet Drivers';
          } else if (state.uri.path == '/fleet/fuel') {
            title = 'Fleet Expenses';
          } else if (state.uri.path == '/accounts/artist-collections') {
            title = 'Artist Collections';
          } else if (state.uri.path == '/finance') {
            title = 'Artist Finance';
          } else if (state.uri.path == '/works') {
            title = 'My Works';
          } else if (state.uri.path == '/leave-requests') {
            title = 'Leave Requests';
          } else if (state.uri.path == '/profile') {
            title = 'My Profile';
          } else if (state.uri.path == '/settings') {
            title = 'Settings';
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
            path: '/services/regions',
            builder: (context, state) => const RegionsManagementScreen(),
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
            path: '/sales',
            builder: (context, state) => const SalesBookingsScreen(),
          ),
          GoRoute(
            path: '/sales/leads',
            builder: (context, state) => const SalesLeadsScreen(),
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
            path: '/fleet/fuel',
            builder: (context, state) => const FuelExpensesScreen(),
          ),
          GoRoute(
            path: '/accounts/artist-collections',
            builder: (context, state) => const AccountsCollectionsScreen(),
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
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
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
