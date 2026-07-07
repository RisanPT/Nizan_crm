/// All recognised roles in the system.
enum AppRole {
  admin,
  manager,
  crm,
  sales,
  artist,
  accounts,
  fleetManager,
  driver,
  unknown;

  static AppRole fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'admin':
        return AppRole.admin;
      case 'manager':
        return AppRole.manager;
      case 'crm':
        return AppRole.crm;
      case 'sales':
        return AppRole.sales;
      case 'artist':
        return AppRole.artist;
      case 'accounts':
        return AppRole.accounts;
      case 'fleet_manager':
      case 'fleetmanager':
        return AppRole.fleetManager;
      case 'driver':
        return AppRole.driver;
      default:
        return AppRole.unknown;
    }
  }

  // ── Full-access roles ─────────────────────────────────────────────────────
  bool get isFullAccess => this == admin || this == manager;

  // ── Section-level permissions ─────────────────────────────────────────────

  /// Dashboard overview
  bool get canSeeDashboard => this == admin || this == artist;

  /// Clients directory + client profiles
  bool get canSeeClients => isFullAccess || this == crm || this == sales;

  /// Calendar scheduler / Works
  bool get canSeeCalendar => isFullAccess || this == crm || this == artist || this == sales || this == accounts || this == fleetManager;

  /// Booking requests + manage booking
  bool get canSeeBookings =>
      isFullAccess ||
      this == crm ||
      this == sales ||
      this == accounts;

  /// Services management (packages, regions, addons)
  bool get canSeeServices => isFullAccess;

  /// Staff management
  bool get canSeeStaff => isFullAccess;

  /// Sales & invoices
  bool get canSeeSales => isFullAccess || this == sales || this == accounts;

  /// Artist Finance module
  bool get canSeeFinance =>
      isFullAccess || this == artist || this == accounts;

  /// Fleet (vehicles, drivers, fuel)
  bool get canSeeFleet => isFullAccess || this == fleetManager;

  /// Settings (user management etc.)
  bool get canSeeSettings => isFullAccess;

  /// CEO Daily Report
  bool get canSeeCEOReport => isFullAccess;

  /// Leave requests
  bool get canSeeLeaveRequests => this == artist || isFullAccess;

  // ── Sub-permissions ───────────────────────────────────────────────────────

  /// Can verify/reject collections and expenses (accounts team + admin/manager)
  bool get canVerifyFinance => isFullAccess || this == accounts;

  /// Artist can only see their own entries, not all artists'
  bool get isScopedToOwnEntries => this == artist;

  /// Home route for this role (first page after login)
  String get homeRoute {
    switch (this) {
      case AppRole.artist:
        return '/';
      case AppRole.sales:
        return '/sales/leads';
      case AppRole.crm:
        return '/booking/requests';
      case AppRole.accounts:
        return '/accounts/dashboard';
      case AppRole.fleetManager:
        return '/fleet/assignments';
      case AppRole.driver:
        return '/driver/jobs'; // Adjust if driver dashboard path is different
      case AppRole.manager:
        return '/clients';
      case AppRole.admin:
        return '/';
      default:
        return '/';
    }
  }
}
