import 'package:flutter/material.dart';

/// One entry in the Reports Center catalog. [route] points at the existing
/// report screen; [key] is a stable id used for favorites / last-visited.
class FinanceReport {
  final String key;
  final String name;
  final String category;
  final String description;
  final String route;
  final IconData icon;

  const FinanceReport({
    required this.key,
    required this.name,
    required this.category,
    required this.description,
    required this.route,
    required this.icon,
  });
}

/// Category display order for the Reports Center rail.
const kReportCategories = <String>[
  'Business Overview',
  'Sales',
  'Accountant',
  'Receivables & Payables',
  'Taxes',
  'Banking',
  'Assets',
];

/// Every finance report, grouped by category. Add new reports here and they
/// appear in the Reports Center automatically.
const kFinanceReports = <FinanceReport>[
  FinanceReport(
    key: 'pnl',
    name: 'Profit and Loss',
    category: 'Business Overview',
    description: 'Income minus expenses over a period.',
    route: '/company-finance/profit-loss',
    icon: Icons.trending_up_outlined,
  ),
  FinanceReport(
    key: 'balance_sheet',
    name: 'Balance Sheet',
    category: 'Business Overview',
    description: 'Assets, liabilities and equity as of a date.',
    route: '/company-finance/balance-sheet',
    icon: Icons.account_balance_outlined,
  ),
  FinanceReport(
    key: 'trial_balance',
    name: 'Trial Balance',
    category: 'Business Overview',
    description: 'Closing debit and credit of every ledger account.',
    route: '/company-finance/trial-balance',
    icon: Icons.balance_outlined,
  ),
  FinanceReport(
    key: 'sales_customer',
    name: 'Sales by Customer',
    category: 'Sales',
    description: 'Which customers bring the most revenue.',
    route: '/company-finance/sales/by-customer',
    icon: Icons.people_alt_outlined,
  ),
  FinanceReport(
    key: 'sales_package',
    name: 'Sales by Package',
    category: 'Sales',
    description: 'Revenue by package / service.',
    route: '/company-finance/sales/by-package',
    icon: Icons.card_giftcard_outlined,
  ),
  FinanceReport(
    key: 'sales_salesperson',
    name: 'Sales by Sales Person',
    category: 'Sales',
    description: 'Revenue attributed to each sales person.',
    route: '/company-finance/sales/by-salesperson',
    icon: Icons.badge_outlined,
  ),
  FinanceReport(
    key: 'sales_summary',
    name: 'Sales Summary',
    category: 'Sales',
    description: 'Sales by day or month over a period.',
    route: '/company-finance/sales/summary',
    icon: Icons.stacked_line_chart_outlined,
  ),
  FinanceReport(
    key: 'payments_by_mode',
    name: 'Payments by Mode',
    category: 'Sales',
    description: 'Payments received by cash, bank, UPI…',
    route: '/company-finance/sales/payments',
    icon: Icons.payments_outlined,
  ),
  FinanceReport(
    key: 'ledger',
    name: 'General Ledger',
    category: 'Accountant',
    description: 'Every posting for an account with a running balance.',
    route: '/company-finance/ledger',
    icon: Icons.menu_book_outlined,
  ),
  FinanceReport(
    key: 'journal',
    name: 'Journal',
    category: 'Accountant',
    description: 'All double-entry vouchers, filterable by type and date.',
    route: '/company-finance/journal',
    icon: Icons.receipt_long_outlined,
  ),
  FinanceReport(
    key: 'chart',
    name: 'Chart of Accounts',
    category: 'Accountant',
    description: 'The ledger accounts your books post to.',
    route: '/company-finance/chart',
    icon: Icons.account_tree_outlined,
  ),
  FinanceReport(
    key: 'aging',
    name: 'Receivables & Payables',
    category: 'Receivables & Payables',
    description: 'Who owes you and whom you owe, aged into buckets.',
    route: '/company-finance/aging',
    icon: Icons.request_quote_outlined,
  ),
  FinanceReport(
    key: 'gst',
    name: 'GST Summary & GSTR-1',
    category: 'Taxes',
    description: 'Net GST payable and the outward supplies register.',
    route: '/company-finance/gst',
    icon: Icons.percent_outlined,
  ),
  FinanceReport(
    key: 'reconciliation',
    name: 'Bank Reconciliation',
    category: 'Banking',
    description: 'Match a bank statement against the ledger.',
    route: '/company-finance/reconciliation',
    icon: Icons.rule_outlined,
  ),
  FinanceReport(
    key: 'assets',
    name: 'Company Assets',
    category: 'Assets',
    description: 'Digital and physical asset register.',
    route: '/company-finance/assets',
    icon: Icons.inventory_outlined,
  ),
  FinanceReport(
    key: 'depreciation',
    name: 'Depreciation',
    category: 'Assets',
    description: 'Asset book values and the monthly depreciation run.',
    route: '/company-finance/depreciation',
    icon: Icons.trending_down_outlined,
  ),
];
