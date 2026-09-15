/// All recognised roles in the system.
enum AppRole {
  admin,
  manager,
  crm,
  sales,
  artist,
  artistHead,
  accounts,
  fleetManager,
  driver,
  inventoryManager,
  marketingAdmin,
  unknown;

  static AppRole fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'admin':
        return AppRole.admin;
      case 'manager':
        return AppRole.manager;
      case 'crm':
      case 'crm_manager':
        return AppRole.crm;
      case 'sales':
      case 'sales_manager':
      case 'sales_executive':
      case 'salesmanager':
        return AppRole.sales;
      case 'artist':
        return AppRole.artist;
      case 'artist_head':
      case 'artisthead':
      case 'regional_artist_head':
        return AppRole.artistHead;
      case 'accounts':
      case 'accounts_manager':
      case 'accounts_executive':
        return AppRole.accounts;
      case 'fleet_manager':
      case 'fleetmanager':
        return AppRole.fleetManager;
      case 'driver':
        return AppRole.driver;
      case 'inventory_manager':
      case 'inventorymanager':
        return AppRole.inventoryManager;
      case 'marketing_admin':
      case 'marketingadmin':
      case 'marketing_manager':
      case 'marketing_executive':
        return AppRole.marketingAdmin;
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
  bool get canSeeClients =>
      isFullAccess || this == crm || this == sales || this == artistHead;

  /// Calendar scheduler / Works
  bool get canSeeCalendar => isFullAccess || this == crm || this == artist || this == sales || this == accounts || this == fleetManager || this == artistHead;

  /// Booking requests + manage booking
  bool get canSeeBookings =>
      isFullAccess ||
      this == crm ||
      this == sales ||
      this == accounts ||
      this == artistHead;

  /// Services management (packages, regions, addons)
  bool get canSeeServices => isFullAccess;

  /// Staff management
  bool get canSeeStaff => isFullAccess || this == crm || this == artistHead;

  /// Sales & invoices
  bool get canSeeSales =>
      isFullAccess || this == sales || this == accounts || this == artistHead;

  /// Artist Finance module
  bool get canSeeFinance =>
      isFullAccess || this == artist || this == accounts;

  /// Company Finance (dashboard + asset register). Management + accounts.
  bool get canSeeCompanyFinance => isFullAccess || this == accounts;

  /// Company Reports library — every department uploads/reads its own reports,
  /// so it is broadly available; per-report access is enforced on the server.
  bool get canSeeCompanyReports => true;

  /// Accounts payables (vendor bills / GST). Accounts team + inventory manager.
  bool get canSeePayables =>
      isFullAccess || this == accounts || this == inventoryManager;

  /// Fleet (vehicles, drivers, fuel)
  bool get canSeeFleet => isFullAccess || this == fleetManager;

  /// Studio Inventory — the full manager app (studio stock + staff kits).
  /// Artists reach a scoped "My Inventory" view only when their account has the
  /// inventoryAccess flag (checked against the session, not the role alone).
  bool get canManageInventory => isFullAccess || this == inventoryManager;

  /// Marketing / Competitor Intelligence module (digital marketing admin).
  bool get canManageMarketing => isFullAccess || this == marketingAdmin;

  /// Settings (user management etc.)
  bool get canSeeSettings => isFullAccess;

  /// CEO Daily Report
  bool get canSeeCEOReport => isFullAccess || this == artistHead;

  /// Leave requests
  bool get canSeeLeaveRequests => this == artist || isFullAccess;

  /// IT / Projects module (projects, roadmap, tasks, OKRs, tickets)
  bool get canSeeIt => isFullAccess;

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
      case AppRole.artistHead:
        return '/artist-head';
      case AppRole.sales:
        return '/sales/leads';
      case AppRole.crm:
        return '/booking/requests';
      case AppRole.accounts:
        return '/accounts/dashboard';
      case AppRole.fleetManager:
        return '/fleet/assignments';
      case AppRole.inventoryManager:
        return '/inventory';
      case AppRole.marketingAdmin:
        return '/marketing/dashboard';
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

  // ── Department Head: which roles can this head create? ────────────────────

  /// Returns the role keys this Department Head is allowed to assign when
  /// creating new team members. Returns an empty set for Admin/Manager
  /// (they are handled separately with full role access) and for non-head roles.
  Set<String> get allowedSubordinateRoles {
    switch (this) {
      case AppRole.sales:
        return {'sales', 'sales_manager', 'sales_executive'};
      case AppRole.crm:
        return {'crm', 'crm_manager'};
      case AppRole.accounts:
        return {'accounts', 'accounts_manager', 'accounts_executive'};
      case AppRole.fleetManager:
        return {'driver'};
      case AppRole.inventoryManager:
        return {'inventory_manager', 'inventoryManager'};
      case AppRole.marketingAdmin:
        return {'marketing_admin', 'marketingadmin', 'marketing_manager', 'marketing_executive'};
      // Admin and Manager: empty = no restriction (all roles shown by caller)
      case AppRole.admin:
      case AppRole.manager:
        return {};
      default:
        return {};
    }
  }
}
