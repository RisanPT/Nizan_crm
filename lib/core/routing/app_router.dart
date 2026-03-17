import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/common_widgets/main_layout.dart';
import '../../presentation/screens/dashboard_screen.dart';
import '../../presentation/screens/clients_directory_screen.dart';
import '../../presentation/screens/add_client_screen.dart';
import '../../presentation/screens/client_profile_screen.dart';
import '../../presentation/screens/calendar_screen.dart';
import '../../presentation/screens/staff_management_screen.dart';
import '../../presentation/screens/services_management_screen.dart';
import '../../presentation/screens/add_booking_screen.dart';
import '../../presentation/screens/manage_booking_screen.dart';

// Create a global key for the root navigator
final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          // Provide appropriate title based on route
          String title = 'Nizan Makeovers';
          if (state.uri.path == '/') {
            title = 'Dashboard Overview';
          } else if (state.uri.path == '/clients')
            title = 'Clients Directory';
          else if (state.uri.path == '/calendar')
            title = 'Calendar Scheduler';
          else if (state.uri.path == '/services')
            title = 'Services Management';
          else if (state.uri.path == '/staff')
            title = 'Staff Management';

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
            path: '/clients/add',
            builder: (context, state) => const AddClientScreen(),
          ),
          GoRoute(
            path: '/client/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? 'Unknown';
              return ClientProfileScreen(clientName: id);
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
            path: '/staff',
            builder: (context, state) => const StaffManagementScreen(),
          ),
          GoRoute(
            path: '/booking/add',
            builder: (context, state) => const AddBookingScreen(),
          ),
          GoRoute(
            path: '/booking/manage/:id',
            builder: (context, state) => ManageBookingScreen(
              bookingId: state.pathParameters['id'] ?? '1042',
            ),
          ),
        ],
      ),
    ],
  );
});
