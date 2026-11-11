import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_permissions.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/routing/app_router.dart';

// The CEO login: what it can open, what it cannot. The server refuses every write (backend middleware/ceoGuard.js); these
// tests are about the screens — the CEO lands on /ceo, reaches the company at a glance, and never reaches pay or bank screens.

/// What the backend seeds for the role (backend controllers/roleController.js, key 'ceo') — explicit sub-keys only.
const _ceoPermissions = [
  'dashboard',
  'ceo',
  'reports',
  'planning',
  'planning.manage',
  'payables.dashboard',
  'company_finance.month_end',
  'company_finance.dept_reviews',
  'company_finance.sales_reports',
  'sales.dashboard',
  'marketing.insights',
  'hr_analytics',
  'staff.evaluation',
];

Access _ceo({List<String> permissions = _ceoPermissions, String home = '/ceo'}) =>
    Access(AppRole.ceo, permissions.toSet(), configuredHomeRoute: home, roleKey: 'ceo');

bool _open(String path, Access a) => isRouteAllowed(path, a);

void main() {
  group('the role', () {
    test('"ceo" is its own role, however it is written, and lands on /ceo', () {
      expect(AppRole.fromString('ceo'), AppRole.ceo);
      expect(AppRole.fromString(' CEO '), AppRole.ceo);
      expect(AppRole.ceo.homeRoute, '/ceo');
      expect(AppRole.fromString('ceo_assistant'), AppRole.unknown); // not caught by accident
    });

    test('the CEO is not full access (that is admin / manager) and has no say in Settings', () {
      expect(AppRole.ceo.isFullAccess, isFalse);
      expect(_ceo().isFullAccess, isFalse);
      expect(_ceo().canSeeSettings, isFalse);
      expect(_ceo().canManageTeam, isFalse);
      expect(_ceo().isCeo, isTrue);
    });

    test('the role\'s permissions are all real features of the app (a typo would silently grant nothing)', () {
      final features = {for (final f in kAppFeatures) f.key: f};
      // planning.manage is read by the code (who sees every project) but is not listed on the Roles screen — an old gap
      const readByCodeOnly = {'planning.manage'};
      for (final p in _ceoPermissions) {
        final parent = p.split('.').first;
        expect(features.containsKey(parent), isTrue, reason: '$p: no feature "$parent"');
        if (p.contains('.') && !readByCodeOnly.contains(p)) {
          expect(features[parent]!.subs.any((s) => s.key == p), isTrue, reason: '$p is not a sub-feature of $parent');
        }
      }
      expect(features.containsKey('ceo'), isTrue); // so the Roles screen can show and edit it
    });

    test('and none of them is a whole module that would open pay, bank or the backup', () {
      for (final whole in ['staff', 'payables', 'company_finance', 'it', 'settings', 'finance', 'compensation', 'sales', 'marketing']) {
        expect(_ceoPermissions.contains(whole), isFalse, reason: whole);
      }
      for (final sub in ['staff.salaries', 'payables.admin_salaries', 'payables.operations_salaries', 'payables.hra', 'company_finance.bank_balance']) {
        expect(_ceoPermissions.contains(sub), isFalse, reason: sub);
      }
    });
  });

  group('landing', () {
    test('the CEO lands on /ceo', () {
      expect(landingRouteFor(_ceo()), '/ceo');
    });

    test('…even from a session saved before the role had a home route set', () {
      expect(landingRouteFor(_ceo(home: '')), '/ceo');
    });

    test('a session built the way the login builds it', () {
      final session = AuthSession(token: 't', userId: 'u', name: 'N', email: 'ceo@x', role: 'ceo', permissions: _ceoPermissions, homeRoute: '/ceo');
      final access = Access.of(session);
      expect(access.role, AppRole.ceo);
      expect(access.homeRoute, '/ceo');
      expect(landingRouteFor(access), '/ceo');
    });
  });

  group('what the CEO can open', () {
    final a = _ceo();
    for (final path in [
      '/ceo',
      '/ceo/decisions',
      '/', // the shared dashboard (Sales / Marketing / Finance tabs)
      '/projects',
      '/projects/abc123',
      '/accounts/dashboard',
      '/accounts/work-profit',
      '/company-finance/month-end',
      '/company-finance/decisions',
      '/company-finance/department/sales',
      '/marketing/insights',
      '/hr/analytics',
      '/hr/evaluation',
      '/reports/analyst',
      '/reviews', // client reviews: read-only, the server refuses writes
      '/notifications',
      '/profile',
      '/company-finance/sales/summary',
    ]) {
      test('opens $path', () => expect(_open(path, a), isTrue));
    }
  });

  group('what the CEO cannot open: pay, bank, people records, the keys to the system', () {
    final a = _ceo();
    for (final path in [
      '/hr/salaries',
      '/hr/compensation',
      '/hr/files',
      '/hr/letters',
      '/accounts/admin-salaries',
      '/accounts/operations-salaries',
      '/accounts/hra',
      '/accounts/bills',
      '/accounts/transactions',
      '/accounts/artist-collections',
      '/company-finance/bank-balance',
      '/company-finance/journal',
      '/company-finance/ledger',
      '/settings',
      '/settings/roles',
      '/team',
      '/staff',
      '/clients',
      '/booking/requests',
      '/booking/add',
      '/fleet/vehicles',
      '/inventory',
      '/it/projects',
      '/company-finance/sales/by-customer', // names the clients
      '/company-finance/sales/payments',
      '/backup',
      '/helpdesk',
      '/some/route/nobody/made', // unknown routes are closed to the CEO, not left open
    ]) {
      test('does not open $path', () => expect(_open(path, a), isFalse));
    }
  });

  group('everyone else is unaffected', () {
    test('admin and manager can see the CEO home too (to see what the CEO sees)', () {
      expect(_open('/ceo', const Access(AppRole.admin, {})), isTrue);
      expect(_open('/ceo/decisions', const Access(AppRole.manager, {})), isTrue);
    });

    test('nobody else can: artist, sales, accounts, a finance head, a custom role', () {
      for (final r in [AppRole.artist, AppRole.sales, AppRole.accounts, AppRole.crm, AppRole.fleetManager, AppRole.driver, AppRole.unknown]) {
        expect(_open('/ceo', Access(r, const {})), isFalse, reason: r.name);
      }
      expect(_open('/ceo', Access(AppRole.accounts, const {'payables'}, roleKey: 'finance_head')), isFalse);
    });

    test('a custom role can be given the CEO overview by ticking it in Roles (the `ceo` feature)', () {
      expect(_open('/ceo', Access(AppRole.unknown, const {'ceo'})), isTrue);
    });

    test('the CEO flag does not leak: nobody but the CEO is a CEO', () {
      expect(const Access(AppRole.admin, {}).isCeo, isFalse);
      expect(const Access(AppRole.accounts, {'ceo'}).isCeo, isFalse);
    });
  });

  group('the CEO may read client reviews, and nobody else gained that', () {
    test('canSeeClientReviews', () {
      expect(_ceo().canSeeClientReviews, isTrue);
      // …because it is the CEO, not only because the role happens to carry a sales key
      expect(Access(AppRole.ceo, const {'ceo'}, roleKey: 'ceo').canSeeClientReviews, isTrue);
      expect(const Access(AppRole.artist, {'dashboard'}).canSeeClientReviews, isFalse);
      expect(const Access(AppRole.driver, {}).canSeeClientReviews, isFalse);
    });
  });
}
