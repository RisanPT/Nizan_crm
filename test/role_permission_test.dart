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
}
