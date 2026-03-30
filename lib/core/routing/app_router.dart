import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
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

// Create a global key for the root navigator
final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

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

      if (isLoadingRoute || isLoginRoute) {
        return '/';
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
            builder: (context, state) => const CalendarScreen(),
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
