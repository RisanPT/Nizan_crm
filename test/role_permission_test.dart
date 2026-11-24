import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/routing/app_router.dart';

void main() {
  group('Fleet Manager Role Permissions & Routing Tests', () {
    test('Fleet Manager has correct basic permissions', () {
      // General booking screen permission should be false to hide it from the sidebar
      expect(AppRole.fleetManager.canSeeBookings, isFalse);
      expect(AppRole.fleetManager.canSeeCalendar, isTrue);
      expect(AppRole.fleetManager.canSeeFleet, isTrue);
      expect(AppRole.fleetManager.homeRoute, equals('/fleet/assignments'));
    });

    test('Fleet Manager route guard allowances', () {
      // Fleet manager can access calendar
      expect(isRouteAllowed('/calendar', const Access(AppRole.fleetManager, {})), isTrue);

      // Fleet manager can access booking manage screen
      expect(isRouteAllowed('/booking/manage/1042', const Access(AppRole.fleetManager, {})), isTrue);

      // Fleet manager cannot access general booking requests or other booking screens
      expect(isRouteAllowed('/booking/requests', const Access(AppRole.fleetManager, {})), isFalse);
      expect(isRouteAllowed('/booking/add', const Access(AppRole.fleetManager, {})), isFalse);
    });
  });

  _permissionDrivenAccessTests();
}

void _permissionDrivenAccessTests() {
  group('Configurable role permissions', () {
    test('falls back to built-in matrix when no permissions are granted', () {
      const access = Access(AppRole.sales, {});
      expect(access.canSeeSales, isTrue);
      expect(access.canManageMarketing, isFalse);
    });

    test('granted permissions override the built-in matrix', () {
      // A custom role handed Marketing must reach it even though the
      // hard-coded matrix would deny it.
      const access = Access(AppRole.sales, {'marketing', 'calendar'});
      expect(access.canManageMarketing, isTrue);
      expect(access.canSeeCalendar, isTrue);
      // Not granted -> denied, even though the old matrix allowed it.
      expect(access.canSeeSales, isFalse);
    });

    test('route guard honours granted permissions', () {
      const access = Access(AppRole.sales, {'marketing'});
      expect(isRouteAllowed('/marketing/dashboard', access), isTrue);
      expect(isRouteAllowed('/sales/leads', access), isFalse);
    });

    test('settings stays admin-only even if granted', () {
      const granted = Access(AppRole.sales, {'settings'});
      expect(granted.canSeeSettings, isFalse);
      const admin = Access(AppRole.admin, {'settings'});
      expect(admin.canSeeSettings, isTrue);
    });
  });

  _salesManagerRoleTests();
}

/// A custom "Sales Manager" role resolves to [AppRole.unknown] with explicit
/// granted permissions and (often) a landing page left at '/'.
void _salesManagerRoleTests() {
  group('Custom Sales Manager role', () {
    const salesManager = Access(
      AppRole.unknown,
      {'clients', 'calendar', 'bookings', 'sales', 'marketing'},
      configuredHomeRoute: '/',
    );

    test('main dashboard stays hidden when not ticked', () {
      expect(salesManager.canSeeDashboard, isFalse);
      expect(isRouteAllowed('/', salesManager), isFalse);
    });

    test('is not stranded on the dashboard it cannot open', () {
      // Configured home is '/', but they lack the dashboard permission — the
      // landing route must send them somewhere they can actually reach instead
      // of looping back to '/'.
      final landing = landingRouteFor(salesManager);
      expect(landing, isNot('/'));
      expect(isRouteAllowed(landing, salesManager), isTrue);
      expect(landing, '/sales/dashboard');
    });

    test('can add a booking with the bookings permission', () {
      expect(salesManager.canSeeBookings, isTrue);
      expect(isRouteAllowed('/booking/add', salesManager), isTrue);
      expect(isRouteAllowed('/booking/requests', salesManager), isTrue);
    });

    test('a configured, accessible home is respected', () {
      const withSalesHome = Access(
        AppRole.unknown,
        {'sales', 'bookings'},
        configuredHomeRoute: '/sales/dashboard',
      );
      expect(landingRouteFor(withSalesHome), '/sales/dashboard');
    });

    test('dashboard, once ticked, lets them land on /', () {
      const withDashboard = Access(
        AppRole.unknown,
        {'dashboard', 'sales'},
        configuredHomeRoute: '/',
      );
      expect(isRouteAllowed('/', withDashboard), isTrue);
      expect(landingRouteFor(withDashboard), '/');
    });
  });

  group('Leave Management route', () {
    test('an HR role without the leave permission can open it', () {
      // e.g. a custom HR role granted only the Staff / HR module.
      expect(isRouteAllowed('/hr/leave', const Access(AppRole.crm, {'staff'})), isTrue);
      expect(isRouteAllowed('/hr/leave', const Access(AppRole.sales, {'dashboard'})), isTrue);
      expect(isRouteAllowed('/hr/leave', const Access(AppRole.admin, {})), isTrue);
    });
  });

  group('hr role', () {
    test('opens Employee Logins and Approvals', () {
      const hr = Access(AppRole.unknown, {'calendar', 'staff', 'fleet', 'trials'}, roleKey: 'hr');
      expect(hr.isHrRole, isTrue);
      expect(isRouteAllowed('/hr/logins', hr), isTrue);
      expect(isRouteAllowed('/hr/approvals', hr), isTrue);
      expect(isRouteAllowed('/hr/evaluation', hr), isTrue);
      const other = Access(AppRole.unknown, {'staff'}, roleKey: 'executive_coordinator');
      expect(isRouteAllowed('/hr/logins', other), isFalse);
    });
  });
}
