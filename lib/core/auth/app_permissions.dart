import 'package:flutter/material.dart';

/// A grantable sub-section within a feature module. The [key] is namespaced
/// under its parent feature, e.g. `sales.leads`.
class AppSubFeature {
  final String key;
  final String label;

  const AppSubFeature(this.key, this.label);
}

/// A grantable feature module.
///
/// These keys are the contract between the Flutter app and the backend
/// `Role.permissions` array — keep the parent keys in sync with
/// `PERMISSION_KEYS` in backend/models/Role.js. Sub-feature keys are namespaced
/// under their parent (`sales.leads`) and validated by the backend by their
/// parent, so they need no separate backend list.
class AppFeature {
  final String key;
  final String label;
  final String description;
  final IconData icon;

  /// Optional finer-grained sub-sections. Empty = the module is all-or-nothing.
  final List<AppSubFeature> subs;

  const AppFeature(this.key, this.label, this.description, this.icon,
      {this.subs = const []});
}

/// Every feature an administrator can switch on or off for a role.
const List<AppFeature> kAppFeatures = [
  AppFeature('dashboard', 'Dashboard', 'Overview home page',
      Icons.dashboard_outlined),
  AppFeature('clients', 'Clients', 'Client directory and profiles',
      Icons.people_outline),
  AppFeature('calendar', 'Calendar', 'Works scheduler and calendar',
      Icons.calendar_month_outlined),
  AppFeature('bookings', 'Bookings', 'Booking requests and management',
      Icons.event_note_outlined),
  AppFeature('trials', 'Trials', 'Trial bookings and trial packages',
      Icons.checklist_outlined),
  AppFeature('services', 'Services', 'Packages, regions and add-ons',
      Icons.design_services_outlined),
  AppFeature('staff', 'Staff / HR', 'Employees, attendance and leave',
      Icons.badge_outlined, subs: [
    AppSubFeature('staff.employees', 'Staff Management'),
    AppSubFeature('staff.slots', 'Slot Management'),
  ]),
  AppFeature('sales', 'Sales', 'Leads, sales and invoices',
      Icons.trending_up_outlined, subs: [
    AppSubFeature('sales.leads', 'Leads'),
    AppSubFeature('sales.invoices', 'Invoices'),
    AppSubFeature('sales.dashboard', 'Sales Dashboard'),
    AppSubFeature('sales.quarterly', 'Quarterly Performance'),
    AppSubFeature('sales.cancelled', 'Cancelled Works'),
  ]),
  AppFeature('finance', 'Artist Finance', 'Artist collections and expenses',
      Icons.account_balance_wallet_outlined),
  AppFeature('payables', 'Accounts', 'Vendor bills, GST and payables',
      Icons.receipt_long_outlined, subs: [
    AppSubFeature('payables.dashboard', 'Accounts Dashboard'),
    AppSubFeature('payables.invoices', 'Invoices'),
    AppSubFeature('payables.bills', 'Bills & Payables'),
    AppSubFeature('payables.collections', 'Artist Collections'),
    AppSubFeature('payables.fleet_expenses', 'Fleet Expenses'),
    AppSubFeature('payables.admin_expenses', 'Administrative Expenses'),
    AppSubFeature('payables.subscriptions', 'Subscriptions'),
  ]),
  AppFeature('inventory', 'Inventory', 'Studio stock and staff kits',
      Icons.inventory_2_outlined, subs: [
    AppSubFeature('inventory.dashboard', 'Inventory Dashboard'),
    AppSubFeature('inventory.stock', 'Stock List'),
    AppSubFeature('inventory.kits', 'Staff Kits'),
    AppSubFeature('inventory.alerts', 'Restock Alerts'),
    AppSubFeature('inventory.expiry', 'Expiry Tracker'),
    AppSubFeature('inventory.reports', 'Inventory Reports'),
    AppSubFeature('inventory.purchases', 'Purchases'),
    AppSubFeature('inventory.vendors', 'Vendors'),
  ]),
  AppFeature('marketing', 'Marketing', 'Competitor and growth intelligence',
      Icons.campaign_outlined, subs: [
    AppSubFeature('marketing.dashboard', 'Marketing Dashboard'),
    AppSubFeature('marketing.competitors', 'Competitors'),
    AppSubFeature('marketing.scores', 'Growth Scores'),
  ]),
  AppFeature('fleet', 'Fleet', 'Vehicles, drivers and fuel',
      Icons.local_shipping_outlined, subs: [
    AppSubFeature('fleet.assignments', 'Assignments'),
    AppSubFeature('fleet.vehicles', 'Vehicles'),
    AppSubFeature('fleet.drivers', 'Drivers'),
    AppSubFeature('fleet.fuel', 'Fuel Expenses'),
    AppSubFeature('fleet.accidents', 'Accident Claims'),
    AppSubFeature('fleet.completed', 'Completed Works'),
    AppSubFeature('fleet.reminders', 'Service Reminders'),
  ]),
  AppFeature('reports', 'Reports', 'CEO daily report and analytics',
      Icons.insights_outlined),
  AppFeature('leave', 'Leave Requests', 'Apply for and review leave',
      Icons.event_busy_outlined),
  AppFeature('settings', 'Settings', 'Users, roles and configuration',
      Icons.settings_outlined),
];

AppFeature? featureForKey(String key) {
  for (final f in kAppFeatures) {
    if (f.key == key) return f;
  }
  return null;
}
