import 'package:flutter/material.dart';

/// A grantable feature module.
///
/// These keys are the contract between the Flutter app and the backend
/// `Role.permissions` array — keep them in sync with `PERMISSION_KEYS` in
/// backend/models/Role.js.
class AppFeature {
  final String key;
  final String label;
  final String description;
  final IconData icon;

  const AppFeature(this.key, this.label, this.description, this.icon);
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
      Icons.badge_outlined),
  AppFeature('sales', 'Sales', 'Leads, sales and invoices',
      Icons.trending_up_outlined),
  AppFeature('finance', 'Artist Finance', 'Artist collections and expenses',
      Icons.account_balance_wallet_outlined),
  AppFeature('payables', 'Accounts', 'Vendor bills, GST and payables',
      Icons.receipt_long_outlined),
  AppFeature('inventory', 'Inventory', 'Studio stock and staff kits',
      Icons.inventory_2_outlined),
  AppFeature('marketing', 'Marketing', 'Competitor and growth intelligence',
      Icons.campaign_outlined),
  AppFeature('fleet', 'Fleet', 'Vehicles, drivers and fuel',
      Icons.local_shipping_outlined),
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
