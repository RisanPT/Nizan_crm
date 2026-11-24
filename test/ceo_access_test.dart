import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_permissions.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/routing/app_router.dart';
import 'package:nizan_crm/features/dashboard/presentation/tabs/finance_tab.dart' show kFinanceDashboardRoles;

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
  'company_finance.aging',
  'company_finance.reports',
  'company_finance.pnl',
  'company_finance.gst',
  'sales.dashboard',
  'marketing.insights',
  'hr_analytics',
  'staff.evaluation',
];

Access _ceo({List<String> permissions = _ceoPermissions, String home = '/ceo'}) =>
    Access(AppRole.ceo, permissions.toSet(), configuredHomeRoute: home, roleKey: 'ceo');

bool _open(String path, Access a) => isRouteAllowed(path, a);

void main() {
  decisionDeskAccess();
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
      // the month-end review links to these; they were dead links that bounced silently to the home
      '/company-finance/sales/by-customer',
      '/company-finance/profit-loss',
      '/company-finance/aging',
      '/company-finance/reports',
      '/company-finance/tax-filings',
      '/ceo/decisions',
      '/ceo/rules',
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

  group('the Executive Director: the CEO\'s login rules and screens, a second leader', () {
    Access ed({List<String> permissions = _ceoPermissions}) => Access(AppRole.ceo, permissions.toSet(), configuredHomeRoute: '/ceo', roleKey: 'executive_director');

    test('"executive_director" is the CEO\'s role in the app, however it is written, and lands on /ceo', () {
      for (final key in ['executive_director', ' Executive_Director ', 'EXECUTIVE_DIRECTOR', 'executivedirector']) {
        expect(AppRole.fromString(key), AppRole.ceo, reason: key);
      }
      expect(AppRole.fromString('executive_coordinator'), isNot(AppRole.ceo), reason: 'a different role, not caught by accident');
      expect(AppRole.fromString('executive'), isNot(AppRole.ceo));
      expect(AppRole.fromString('director'), isNot(AppRole.ceo));
    });

    test('a signed-in Executive Director gets the leadership access, with their own title', () {
      final a = Access.of(const AuthSession(token: 't', userId: 'u', name: 'Dir', email: 'd@x', role: 'executive_director', permissions: _ceoPermissions, homeRoute: '/ceo'));
      expect(a.isCeo, isTrue);
      expect(a.isExecutiveDirector, isTrue);
      expect(a.leadershipTitle, 'Executive Director');
      expect(a.isViewOnly, isTrue);
      expect(a.canSeeCeoHome, isTrue);
      expect(a.isFullAccess, isFalse);
      expect(a.canSeeSettings, isFalse);
    });

    test('the CEO is a CEO — not an Executive Director — and both are view-only', () {
      expect(_ceo().isExecutiveDirector, isFalse);
      expect(_ceo().leadershipTitle, 'CEO');
      expect(_ceo().isViewOnly, isTrue);
    });

    test('nobody else is a leader or view-only because of it', () {
      for (final key in ['admin', 'manager', 'accounts', 'finance_head', 'executive_coordinator', 'sales']) {
        final a = Access(AppRole.fromString(key), const {'ceo'}, roleKey: key);
        expect(a.isExecutiveDirector, isFalse, reason: key);
        expect(a.isViewOnly, isFalse, reason: key);
      }
      expect(const Access(AppRole.admin, {}, roleKey: 'admin').isExecutiveDirector, isFalse);
    });

    test('the Executive Director opens exactly what the CEO opens, and is refused exactly what the CEO is refused', () {
      for (final path in [
        '/ceo', '/ceo/decisions', '/', '/projects', '/projects/abc123', '/accounts/dashboard', '/accounts/work-profit', '/company-finance/month-end',
        '/company-finance/decisions', '/marketing/insights', '/hr/analytics', '/hr/evaluation', '/reviews', '/notifications', '/profile',
        '/hr/salaries', '/hr/compensation', '/hr/letters', '/accounts/hra', '/accounts/admin-salaries', '/company-finance/bank-balance', '/company-finance/journal',
        '/company-finance/ledger', '/settings', '/team', '/staff', '/backup', '/clients', '/booking/add', '/it/projects', '/some/route/nobody/made',
      ]) {
        expect(_open(path, ed()), _open(path, _ceo()), reason: path);
      }
      expect(_open('/ceo', ed()), isTrue);
      expect(_open('/hr/salaries', ed()), isFalse);
      expect(_open('/settings', ed()), isFalse);
    });

    test('the Executive Director may read client reviews and the finance dashboard tabs, like the CEO', () {
      expect(ed().canSeeClientReviews, isTrue);
      expect(kFinanceDashboardRoles.contains('executive_director'), isTrue);
      expect(kFinanceDashboardRoles.contains('ceo'), isTrue);
    });
  });

  group('who may change the Decision rules (what needs the CEO / Executive Director)', () {
    test('an administrator and either leader — no manager, no finance head, nobody else', () {
      expect(const Access(AppRole.admin, {}, roleKey: 'admin').canEditDecisionRules, isTrue);
      expect(_ceo().canEditDecisionRules, isTrue);
      expect(Access(AppRole.ceo, const {'ceo'}, roleKey: 'executive_director').canEditDecisionRules, isTrue);
      for (final key in ['manager', 'finance_head', 'accounts', 'sales', 'artist', 'executive_coordinator']) {
        expect(Access(AppRole.fromString(key), const {'ceo'}, roleKey: key).canEditDecisionRules, isFalse, reason: key);
      }
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


// ── who may do what on the decision desk ─────────────────────────────────────

void decisionDeskAccess() {
  group('the menu\'s own screens open for a leader whatever their role\'s permission list holds', () {
    // the sidebar offers these four under "Money" without asking the permission list; a leader whose role is older, trimmed by an
    // admin, or arrived without a list must not be bounced silently back to the home screen when they tap one
    final menuScreens = ['/accounts/dashboard', '/accounts/work-profit', '/company-finance/month-end', '/company-finance/department/sales', '/ceo/decisions', '/ceo/rules', '/projects', '/reviews'];
    for (final entry in {
      'no permissions at all (a session with no list)': <String>{},
      'only the home keys': {'dashboard', 'ceo'},
      'the finance keys missing': {'ceo', 'planning', 'sales.dashboard', 'hr_analytics'},
    }.entries) {
      for (final role in ['ceo', 'executive_director']) {
        for (final path in menuScreens) {
          test('${entry.key}, $role: opens $path', () => expect(_open(path, Access(AppRole.ceo, entry.value, roleKey: role)), isTrue));
        }
      }
    }
    test('…while the pay, bank and system screens stay closed whatever the list says', () {
      final everything = Access(AppRole.ceo, const {'payables', 'staff', 'company_finance', 'it', 'settings', 'compensation', 'payables.hra', 'staff.salaries'}, roleKey: 'ceo');
      for (final p in ['/hr/salaries', '/hr/compensation', '/accounts/hra', '/accounts/admin-salaries', '/settings', '/company-finance/ledger', '/company-finance/bank-balance', '/backup', '/staff']) {
        expect(_open(p, everything), isFalse, reason: p);
      }
    });
  });

  group('the allow-list on its own: a generous permission set still does not open the ledger or the journal', () {
    final generous = Access(AppRole.ceo, const {'company_finance', 'company_finance.ledger', 'company_finance.journal', 'payables', 'staff'}, roleKey: 'executive_director');
    for (final p in ['/company-finance/ledger', '/company-finance/journal', '/company-finance/trial-balance', '/accounts/hra', '/hr/salaries']) {
      test('does not open $p', () => expect(_open(p, generous), isFalse));
    }
  });

  group('the decision desk: who may change what', () {
    const ceo = Access(AppRole.ceo, {}, roleKey: 'ceo');
    const ed = Access(AppRole.ceo, {}, roleKey: 'executive_director');
    const admin = Access(AppRole.admin, {}, roleKey: 'admin');
    const manager = Access(AppRole.manager, {}, roleKey: 'manager');
    const accounts = Access(AppRole.accounts, {}, roleKey: 'accounts');

    test('both leaders and the administrator may set the decision rules; a manager and Accounts may not', () {
      expect(ceo.canEditDecisionRules, isTrue);
      expect(ed.canEditDecisionRules, isTrue);
      expect(admin.canEditDecisionRules, isTrue);
      expect(manager.canEditDecisionRules, isFalse);
      expect(accounts.canEditDecisionRules, isFalse);
    });

    test('the status of an entry in the manual log is for the leaders and the administrators, not for Accounts', () {
      expect(ceo.canSettleDecisionLog, isTrue);
      expect(ed.canSettleDecisionLog, isTrue);
      expect(admin.canSettleDecisionLog, isTrue);
      expect(manager.canSettleDecisionLog, isTrue);
      expect(accounts.canSettleDecisionLog, isFalse);
    });

    test('the Executive Director is a leader with their own title', () {
      expect(ed.isCeo, isTrue);
      expect(ed.leadershipTitle, 'Executive Director');
      expect(ceo.leadershipTitle, 'CEO');
      expect(admin.isCeo, isFalse);
    });
  });
}
