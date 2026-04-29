/// All recognised roles in the system.
enum AppRole {
  admin,
  manager,
  crm,
  sales,
  artist,
  accounts,
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
      default:
        return AppRole.unknown;
    }
  }

  // ── Full-access roles ─────────────────────────────────────────────────────
  bool get isFullAccess => this == admin || this == manager;

  // ── Section-level permissions ─────────────────────────────────────────────

  /// Dashboard overview
  bool get canSeeDashboard =>
      isFullAccess || this == crm || this == sales || this == accounts;

  /// Clients directory + client profiles
  bool get canSeeClients => isFullAccess || this == crm;

  /// Calendar scheduler
  bool get canSeeCalendar => isFullAccess || this == crm;

  /// Booking requests + manage booking
  bool get canSeeBookings => isFullAccess || this == crm;

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
  bool get canSeeFleet => isFullAccess;

  /// Settings (user management etc.)
  bool get canSeeSettings => isFullAccess;

  // ── Sub-permissions ───────────────────────────────────────────────────────

  /// Can verify/reject collections and expenses (accounts team + admin/manager)
  bool get canVerifyFinance => isFullAccess || this == accounts;

  /// Artist can only see their own entries, not all artists'
  bool get isScopedToOwnEntries => this == artist;

  /// Home route for this role (first page after login)
  String get homeRoute {
    switch (this) {
      case AppRole.artist:
        return '/finance';
      case AppRole.sales:
        return '/sales';
      case AppRole.crm:
        return '/';
      case AppRole.accounts:
        return '/finance';
      default:
        return '/';
    }
  }
}
