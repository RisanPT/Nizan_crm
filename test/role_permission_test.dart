import 'package:flutter_test/flutter_test.dart';
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
      expect(isRouteAllowed('/calendar', AppRole.fleetManager), isTrue);

      // Fleet manager can access booking manage screen
      expect(isRouteAllowed('/booking/manage/1042', AppRole.fleetManager), isTrue);

      // Fleet manager cannot access general booking requests or other booking screens
      expect(isRouteAllowed('/booking/requests', AppRole.fleetManager), isFalse);
      expect(isRouteAllowed('/booking/add', AppRole.fleetManager), isFalse);
    });
  });
}
