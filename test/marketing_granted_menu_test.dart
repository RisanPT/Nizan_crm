// The Marketing Admin menu shows ONLY the main-menu features ticked for the
// role in Settings → Roles (2026-11-26). Nothing un-ticked appears.
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/routing/app_router.dart' show isRouteAllowed;
import 'package:nizan_crm/features/marketing/presentation/shell/marketing_sidebar.dart';

List<String> _labels(Set<String> granted) {
  final access = Access(AppRole.marketingAdmin, granted, roleKey: 'marketing_admin');
  return grantedExtras(access, (r) => isRouteAllowed(Uri.parse(r).path, access)).map((g) => g.label).toList();
}

void main() {
  test('only the ticked features show (as in the screenshot: Calendar, Services, 8 Sales sections)', () {
    final labels = _labels({
      'marketing', 'calendar', 'services',
      'sales.dashboard', 'sales.invoices', 'sales.leads', 'sales.monthly',
      'sales.cancelled', 'sales.booking_map', 'sales.report', 'sales.calendar',
    });
    expect(labels, containsAll(['Calendar', 'Services', 'Sales Dashboard', 'Invoices & Bookings', 'Leads']));
    // Not ticked → not shown.
    for (final no in ['Clients', 'Booking', 'Trials', 'Stylist', 'Company Reports', 'Finance', 'Accounts', 'Inventory', 'Fleet', 'Artist Finance']) {
      expect(labels, isNot(contains(no)), reason: no);
    }
  });

  test('a role with only marketing ticked gets no extra items', () {
    expect(_labels({'marketing'}), isEmpty);
  });

  test('ticking a feature later makes it appear', () {
    expect(_labels({'marketing', 'bookings'}), contains('Booking'));
  });
}
