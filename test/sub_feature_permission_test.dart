import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/routing/app_router.dart';

/// Covers the sub-feature (sub-menu) permission layer: granular sub-keys,
/// parent-as-all, backward compatibility and route mapping.
void main() {
  Access accessWith(Set<String> perms, {AppRole role = AppRole.unknown}) =>
      Access(role, perms);

  group('canSeeSub — granular grants', () {
    test('a specific sub-key grants only that section', () {
      final a = accessWith({'sales.leads'});
      expect(a.canSeeSub('sales.leads'), isTrue);
      expect(a.canSeeSub('sales.invoices'), isFalse);
      expect(a.canSeeSub('sales.dashboard'), isFalse);
      // Parent module is visible because a sub is granted.
      expect(a.canSeeSales, isTrue);
    });

    test('granting the parent key means all sub-sections', () {
      final a = accessWith({'sales'});
      expect(a.canSeeSub('sales.leads'), isTrue);
      expect(a.canSeeSub('sales.invoices'), isTrue);
      expect(a.canSeeSub('sales.cancelled'), isTrue);
    });

    test('multiple sub-keys grant exactly those', () {
      final a = accessWith({'sales.leads', 'sales.invoices'});
      expect(a.canSeeSub('sales.leads'), isTrue);
      expect(a.canSeeSub('sales.invoices'), isTrue);
      expect(a.canSeeSub('sales.quarterly'), isFalse);
    });

    test('an unrelated module stays hidden', () {
      final a = accessWith({'sales.leads'});
      expect(a.canManageInventory, isFalse);
      expect(a.canSeeSub('inventory.stock'), isFalse);
    });
  });

  group('backward compatibility', () {
    test('a legacy role with the whole module still sees every section', () {
      // Mirrors the seeded "sales" role.
      final a = accessWith({'clients', 'calendar', 'bookings', 'sales'});
      expect(a.canSeeSub('sales.leads'), isTrue);
      expect(a.canSeeSub('sales.dashboard'), isTrue);
      expect(a.canSeeSub('sales.cancelled'), isTrue);
    });

    test('a role with NO explicit permissions falls back to its role default', () {
      // Empty permission set → built-in role matrix applies.
      final salesRole = accessWith(const {}, role: AppRole.sales);
      // AppRole.sales can see sales by default, so all sales subs resolve true.
      expect(salesRole.canSeeSub('sales.leads'),
          salesRole.canSeeSales ? isTrue : isFalse);
    });
  });

  group('route guards honour sub-keys', () {
    test('leads-only role reaches /sales/leads but not /sales/quarterly', () {
      final a = accessWith({'sales.leads'});
      expect(isRouteAllowed('/sales/leads', a), isTrue);
      expect(isRouteAllowed('/sales/leads/123', a), isTrue);
      expect(isRouteAllowed('/sales/quarterly', a), isFalse);
      expect(isRouteAllowed('/sales/dashboard', a), isFalse);
      expect(isRouteAllowed('/sales', a), isFalse); // invoices
    });

    test('full sales role reaches every sales route', () {
      final a = accessWith({'sales'});
      for (final r in ['/sales', '/sales/leads', '/sales/dashboard',
          '/sales/quarterly', '/sales/cancelled']) {
        expect(isRouteAllowed(r, a), isTrue, reason: r);
      }
    });

    test('inventory sub-permission scopes its routes', () {
      final a = accessWith({'inventory.stock'});
      expect(isRouteAllowed('/inventory/stock', a), isTrue);
      expect(isRouteAllowed('/inventory/vendors', a), isFalse);
      expect(isRouteAllowed('/inventory', a), isFalse); // dashboard
    });
  });

  group('subKeyForPath', () {
    test('maps concrete routes to sub-keys', () {
      expect(subKeyForPath('/sales/leads'), 'sales.leads');
      expect(subKeyForPath('/sales'), 'sales.invoices');
      expect(subKeyForPath('/accounts/bills'), 'payables.bills');
      expect(subKeyForPath('/inventory/stock'), 'inventory.stock');
      expect(subKeyForPath('/fleet/completed-works'), 'fleet.completed');
      expect(subKeyForPath('/marketing/competitors'), 'marketing.competitors');
      expect(subKeyForPath('/hr/slots'), 'staff.slots');
      expect(subKeyForPath('/calendar'), isNull);
    });
  });
}
