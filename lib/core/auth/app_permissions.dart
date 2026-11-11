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
  AppFeature('consultations', 'Consultations',
      'Bridal video consultations and stylist schedule',
      Icons.video_camera_front_outlined, subs: [
    AppSubFeature('consultations.calendar', 'Consultation Calendar'),
    AppSubFeature('consultations.notes', 'Consultation Notes'),
    AppSubFeature('consultations.reports', 'Stylist Reports'),
  ]),
  AppFeature('services', 'Services', 'Packages, regions and add-ons',
      Icons.design_services_outlined),
  AppFeature('staff', 'Staff / HR', 'Employees, attendance and leave',
      Icons.badge_outlined, subs: [
    AppSubFeature('staff.employees', 'Staff Management'),
    AppSubFeature('staff.attendance', 'Attendance (Timebox)'),
    AppSubFeature('staff.salaries', 'Salaries & Payroll'),
    AppSubFeature('staff.slots', 'Slot Management'),
    AppSubFeature('staff.evaluation', 'HR Evaluation / 5 Pillars'),
  ]),
  AppFeature('sales', 'Sales', 'Leads, sales and invoices',
      Icons.trending_up_outlined, subs: [
    AppSubFeature('sales.leads', 'Leads'),
    AppSubFeature('sales.invoices', 'Invoices'),
    AppSubFeature('sales.dashboard', 'Sales Dashboard'),
    AppSubFeature('sales.monthly', 'Monthly Bookings'),
    AppSubFeature('sales.quarterly', 'Quarterly Performance'),
    AppSubFeature('sales.cancelled', 'Cancelled Works'),
  AppSubFeature('sales.booking_map', 'Booking Map'),
    AppSubFeature('sales.targets', 'Sales Targets'),
    AppSubFeature('sales.report', 'Report & Goals'),
  ]),
  AppFeature('finance', 'Artist Finance', 'Artist collections and expenses',
      Icons.account_balance_wallet_outlined),
  AppFeature('company_reports', 'Company Reports', 'Per-department report document library',
      Icons.folder_shared_outlined),
  AppFeature('company_finance', 'Finance', 'Company finance, ledger and assets',
      Icons.savings_outlined, subs: [
    AppSubFeature('company_finance.dashboard', 'Finance Dashboard'),
    AppSubFeature('company_finance.reports', 'Reports Center'),
    AppSubFeature('company_finance.month_end', 'Month-End Review & Planning'),
    AppSubFeature('company_finance.dept_reviews', 'Departmental Reviews'),
    AppSubFeature('company_finance.sales_reports', 'Sales Reports'),
    AppSubFeature('company_finance.chart', 'Chart of Accounts'),
    AppSubFeature('company_finance.journal', 'Journal'),
    AppSubFeature('company_finance.trial_balance', 'Trial Balance'),
    AppSubFeature('company_finance.ledger', 'General Ledger'),
    AppSubFeature('company_finance.pnl', 'Profit & Loss'),
    AppSubFeature('company_finance.balance_sheet', 'Balance Sheet'),
    AppSubFeature('company_finance.aging', 'Receivables & Payables'),
    AppSubFeature('company_finance.bank_balance', 'Bank Balance'),
    AppSubFeature('company_finance.reconciliation', 'Bank Reconciliation'),
    AppSubFeature('company_finance.gst', 'GST'),
    AppSubFeature('company_finance.assets', 'Assets'),
    AppSubFeature('company_finance.depreciation', 'Depreciation'),
  ]),
  AppFeature('payables', 'Accounts', 'Vendor bills, GST and payables',
      Icons.receipt_long_outlined, subs: [
    AppSubFeature('payables.dashboard', 'Accounts Dashboard'),
    AppSubFeature('payables.transactions', 'Cash In / Out'),
    AppSubFeature('payables.invoices', 'Invoices'),
    AppSubFeature('payables.bills', 'Bills & Payables'),
    AppSubFeature('payables.collections', 'Artist Collections'),
    AppSubFeature('payables.fleet_expenses', 'Fleet Expenses'),
    AppSubFeature('payables.operations_salaries', 'Operations Payouts'),
    AppSubFeature('payables.admin_expenses', 'Administrative Expenses'),
    AppSubFeature('payables.admin_salaries', 'Administrative Salaries'),
    AppSubFeature('payables.hra', 'HRA (House Rent Allowance)'),
    AppSubFeature('payables.sales_returns', 'Sales Returns / Credit Notes'),
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
    AppSubFeature('marketing.eod', 'EOD & Dashboard'),
    AppSubFeature('marketing.competitors', 'Competitors'),
    AppSubFeature('marketing.scores', 'Growth Scores'),
    AppSubFeature('marketing.insights', 'Marketing Insights'),
    AppSubFeature('marketing.analytics', 'Analytics'),
    AppSubFeature('marketing.calendar', 'Sales Calendar'),
    AppSubFeature('marketing.campaigns', 'Campaigns & ROI'),
    AppSubFeature('marketing.leads_report', 'Leads Report'),
  ]),
  AppFeature('fleet', 'Fleet', 'Vehicles, drivers and fuel',
      Icons.local_shipping_outlined, subs: [
    AppSubFeature('fleet.assignments', 'Assignments'),
    AppSubFeature('fleet.vehicles', 'Vehicles'),
    AppSubFeature('fleet.drivers', 'Drivers'),
    AppSubFeature('fleet.fuel', 'Fuel Expenses'),
    AppSubFeature('fleet.accidents', 'Accident Claims'),
    AppSubFeature('fleet.completed', 'Completed Works'),
    AppSubFeature('fleet.km_report', 'Km Report'),
    AppSubFeature('fleet.reminders', 'Service Reminders'),
  ]),
  AppFeature('reports', 'Reports', 'CEO daily report and analytics',
      Icons.insights_outlined),
  AppFeature('it', 'IT & Projects', 'Projects, task board, OKRs and helpdesk',
      Icons.computer_outlined, subs: [
    AppSubFeature('it.projects', 'Projects & WBS'),
    AppSubFeature('it.roadmap', 'Roadmap'),
    AppSubFeature('it.my_tasks', 'My Tasks'),
    AppSubFeature('it.tickets', 'Tickets & Helpdesk'),
    AppSubFeature('it.okrs', "OKR's & Key Results"),
    AppSubFeature('it.manage', 'Project Manager (All Projects Control)'),
  ]),
  AppFeature('planning', 'Company Projects', 'Company-wide, per-department project planning',
      Icons.hub_outlined),
  AppFeature('leave', 'Leave Requests', 'Apply for and review leave',
      Icons.event_busy_outlined),
  AppFeature('approvals', 'Approvals', 'Review and decide leave and HR requests',
      Icons.fact_check_outlined),
  AppFeature('designations', 'Designations', 'Job titles and grades',
      Icons.workspace_premium_outlined),
  AppFeature('org', 'Organization', 'Reporting hierarchy / org chart',
      Icons.account_tree_outlined),
  AppFeature('hr_files', 'Employee Files', 'Per-employee document vault',
      Icons.folder_shared_outlined),
  AppFeature('shift', 'Shifts & Roster', 'Work shifts and shift assignments',
      Icons.schedule_outlined),
  AppFeature('timesheet', 'Time Tracker', 'Weekly timesheets and approvals',
      Icons.timer_outlined),
  AppFeature('regularization', 'Regularization', 'Attendance correction requests',
      Icons.event_available_outlined),
  AppFeature('recruitment', 'Recruitment', 'Job posts, candidates and offers',
      Icons.work_outline),
  AppFeature('onboarding', 'Onboarding', 'New-hire onboarding checklists',
      Icons.assignment_turned_in_outlined),
  AppFeature('offboarding', 'Offboarding', 'Employee exit and clearance',
      Icons.logout_outlined),
  AppFeature('reimbursement', 'Reimbursements', 'Employee expense claims',
      Icons.receipt_long_outlined),
  AppFeature('travel', 'Travel', 'Travel requests and advances',
      Icons.flight_takeoff_outlined),
  AppFeature('compensation', 'Compensation', 'Salary bands and revisions',
      Icons.payments_outlined),
  AppFeature('engagement', 'Engagement', 'Announcements and events feed',
      Icons.campaign_outlined),
  AppFeature('lms', 'Learning', 'Courses and training',
      Icons.school_outlined),
  AppFeature('hr_letters', 'HR Letters', 'Letter templates and generation',
      Icons.description_outlined),
  AppFeature('grievance', 'Grievances', 'Employee grievance cases',
      Icons.report_gmailerrorred_outlined),
  AppFeature('hr_analytics', 'HR Analytics', 'Headcount and workload dashboard',
      Icons.insights_outlined),
  AppFeature('settings', 'Settings', 'Users, roles and configuration',
      Icons.settings_outlined),
];

AppFeature? featureForKey(String key) {
  for (final f in kAppFeatures) {
    if (f.key == key) return f;
  }
  return null;
}
