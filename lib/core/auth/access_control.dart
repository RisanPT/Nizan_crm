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

  const Access(this.role, this.granted, {this.configuredHomeRoute = '', this.isDepartmentHead = false});

  factory Access.of(AuthSession? session) {
    final role = AppRole.fromString(session?.role);
    return Access(
      role,
      (session?.permissions ?? const []).toSet(),
      configuredHomeRoute: session?.homeRoute ?? '',
      isDepartmentHead: session?.isDepartmentHead ?? false,
    );
  }

  bool get _usesFallback => granted.isEmpty;

  /// True when [key] is granted; falls back to the hard-coded default.
  bool has(String key, bool fallback) =>
      _usesFallback ? fallback : granted.contains(key);

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
  bool get canSeePayables => has('payables', role.canSeePayables);
  bool get canSeeFleet => has('fleet', role.canSeeFleet);
  bool get canManageInventory => has('inventory', role.canManageInventory);
  bool get canManageMarketing => has('marketing', role.canManageMarketing);
  bool get canSeeCEOReport => has('reports', role.canSeeCEOReport);
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
