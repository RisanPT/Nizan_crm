import '../models/auth_session.dart';
import 'app_role.dart';

/// Resolves what the signed-in user may access.
///
/// Permissions come from the backend `Role` record, so an administrator can
/// change a role's features without a code change. When the session carries no
/// permissions — an older stored session, or a backend that predates roles —
/// this falls back to the built-in [AppRole] matrix, so access never silently
/// disappears for an existing user.
class Access {
  final AppRole role;
  final Set<String> granted;

  /// Landing page from the role record; blank falls back to [AppRole.homeRoute]
  /// so built-in roles behave exactly as before.
  final String configuredHomeRoute;

  /// Mirrors [AuthSession.isDepartmentHead] — true when this user can manage
  /// their own department's staff members.
  final bool isDepartmentHead;

  /// Mirrors [AuthSession.artistHead] — an artist who also leads the artist
  /// team, granting the Artist Head dashboard on top of their artist role.
  final bool artistHead;

  const Access(this.role, this.granted,
      {this.configuredHomeRoute = '',
      this.isDepartmentHead = false,
      this.artistHead = false});

  factory Access.of(AuthSession? session) {
    final role = AppRole.fromString(session?.role);
    final isManager = session != null &&
        (session.role.endsWith('_manager') ||
         session.role.endsWith('manager') ||
         session.role.endsWith('_admin') ||
         session.role.endsWith('admin'));
    return Access(
      role,
      (session?.permissions ?? const []).toSet(),
      configuredHomeRoute: session?.homeRoute ?? '',
      isDepartmentHead: (session?.isDepartmentHead ?? false) || isManager,
      artistHead: session?.artistHead ?? false,
    );
  }

  bool get _usesFallback => granted.isEmpty;

  /// True when [key] is granted; falls back to the hard-coded default.
  /// Admin/Manager always have blanket access across all features.
  /// Parent-aware: a module counts as visible if either the parent key OR any
  /// of its sub-keys (`parent.child`) is granted.
  bool has(String key, bool fallback) {
    if (isFullAccess) return true;
    if (_usesFallback) return fallback;
    return granted.contains(key) || granted.any((k) => k.startsWith('$key.'));
  }

  /// True when a specific sub-section (`sales.leads`, `it.projects`) is allowed.
  /// Admin/Manager always have blanket access across all sub-features.
  /// Backward compatible:
  ///  • a role with NO explicit permissions uses the parent's role default;
  ///  • granting the parent key alone means the whole module (all sub-sections);
  ///  • otherwise the exact sub-key must be present.
  bool canSeeSub(String subKey) {
    if (isFullAccess) return true;
    final dot = subKey.indexOf('.');
    final parent = dot == -1 ? subKey : subKey.substring(0, dot);
    if (_usesFallback) return _parentFallback(parent);
    if (granted.contains(parent)) return true;
    return granted.contains(subKey);
  }

  bool _parentFallback(String parent) {
    switch (parent) {
      case 'dashboard':
        return role.canSeeDashboard;
      case 'clients':
        return role.canSeeClients;
      case 'calendar':
        return role.canSeeCalendar;
      case 'bookings':
      case 'trials':
        return role.canSeeBookings;
      case 'services':
        return role.canSeeServices;
      case 'staff':
        return role.canSeeStaff;
      case 'sales':
        return role.canSeeSales;
      case 'finance':
        return role.canSeeFinance;
      case 'company_finance':
        return role.canSeeCompanyFinance;
      case 'company_reports':
        return role.canSeeCompanyReports;
      case 'payables':
        return role.canSeePayables;
      case 'fleet':
        return role.canSeeFleet;
      case 'inventory':
        return role.canManageInventory;
      case 'marketing':
        return role.canManageMarketing;
      case 'reports':
        return role.canSeeCEOReport;
      case 'it':
        return role.canSeeIt;
      case 'leave':
        return role.canSeeLeaveRequests;
      default:
        return false;
    }
  }

  // Admin and manager keep blanket access regardless of the matrix, so an
  // administrator can never lock themselves out of Settings.
  bool get isFullAccess => role.isFullAccess;

  bool get canSeeDashboard => has('dashboard', role.canSeeDashboard);
  bool get canSeeClients => has('clients', role.canSeeClients);
  bool get canSeeCalendar => has('calendar', role.canSeeCalendar);
  bool get canSeeBookings => has('bookings', role.canSeeBookings);
  bool get canSeeTrials => has('trials', role.canSeeBookings);
  bool get canSeeServices => has('services', role.canSeeServices);
  bool get canSeeStaff => has('staff', role.canSeeStaff);
  bool get canSeeSales => has('sales', role.canSeeSales);
  bool get canSeeFinance => has('finance', role.canSeeFinance);
  // isFullAccess bypass so a brand-new section is never invisible to admin /
  // manager before the `company_finance` key has been granted to their role.
  bool get canSeeCompanyFinance =>
      isFullAccess || has('company_finance', role.canSeeCompanyFinance);
  bool get canSeeCompanyReports =>
      isFullAccess || has('company_reports', role.canSeeCompanyReports);
  bool get canSeePayables => has('payables', role.canSeePayables);

  /// The Administrative Expenses screen. Accounts/Admin reach it through the
  /// normal payables permission; any department head also reaches it to SUBMIT
  /// their own department's expenses for Accounts to approve.
  bool get canSeeAdminExpenses =>
      isFullAccess || canSeeSub('payables.admin_expenses') || isDepartmentHead;
  bool get canSeeFleet => has('fleet', role.canSeeFleet);
  bool get canManageInventory => has('inventory', role.canManageInventory);
  bool get canManageMarketing => has('marketing', role.canManageMarketing);
  bool get canSeeCEOReport => has('reports', role.canSeeCEOReport);

  /// Artist Head dashboard — the dedicated artist_head role, an artist flagged
  /// as also-head, or full-access management.
  bool get canSeeArtistHead =>
      isFullAccess || role == AppRole.artistHead || artistHead;
  // IT hub (projects, task board, and — later — helpdesk tickets). No AppRole
  // matrix entry yet, so it's driven by the granted 'it' permission (admin/
  // manager see it via the isFullAccess bypass).
  bool get canSeeIt => isFullAccess || has('it', false);

  /// True when user is an IT Project Manager who can create, edit, delete, and
  /// control all projects across the organization.
  bool get isITManager =>
      isFullAccess ||
      role == AppRole.admin ||
      role == AppRole.manager ||
      isDepartmentHead ||
      canSeeSub('it.manage');

  bool get canSeeLeaveRequests => has('leave', role.canSeeLeaveRequests);

  /// Settings stays admin/manager-only even if granted, to protect the role
  /// editor itself from being handed out accidentally.
  bool get canSeeSettings => isFullAccess && has('settings', true);

  // ── Behavioural flags (not feature toggles) ───────────────────────────────
  bool get canVerifyFinance => role.canVerifyFinance;
  bool get isScopedToOwnEntries => role.isScopedToOwnEntries;
  String get homeRoute =>
      configuredHomeRoute.isNotEmpty ? configuredHomeRoute : role.homeRoute;

  // ── Department Head team management ───────────────────────────────────────

  /// True when this user may add/edit/deactivate staff in their own department.
  /// Full-access roles (admin/manager) always qualify.
  bool get canManageTeam => isFullAccess || isDepartmentHead;

  /// The set of role keys this user is allowed to assign when creating a new
  /// team member. An empty set means "no restriction" (admin / manager can
  /// assign any role — the caller shows the full list).
  Set<String> get creatableRoles {
    if (isFullAccess) return {};
    if (isDepartmentHead) return role.allowedSubordinateRoles;
    return {};
  }
}
