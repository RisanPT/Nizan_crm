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
  'CEO Review',
  'Departmental Reviews',
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
    key: 'month_end',
    name: 'Month-End Review',
    category: 'CEO Review',
    description: 'The 90-minute finance review — revenue, profit, cash, AR/AP, KPIs vs plan.',
    route: '/company-finance/month-end',
    icon: Icons.fact_check_outlined,
  ),
  FinanceReport(
    key: 'planning',
    name: 'Monthly Planning',
    category: 'CEO Review',
    description: 'Set the month’s revenue/profit/collection targets and budget allocation.',
    route: '/company-finance/planning',
    icon: Icons.flag_outlined,
  ),
  FinanceReport(
    key: 'decisions',
    name: 'CEO Decisions & Action Items',
    category: 'CEO Review',
    description: 'Approvals, hiring, CapEx and action items with owner, deadline and status.',
    route: '/company-finance/decisions',
    icon: Icons.gavel_outlined,
  ),
  FinanceReport(
    key: 'glossary',
    name: 'Financial Glossary',
    category: 'CEO Review',
    description: 'Key financial terms in plain English, each with this month’s live value.',
    route: '/company-finance/glossary',
    icon: Icons.menu_book_outlined,
  ),
  // Departmental month-end reviews (per the reporting framework doc).
  FinanceReport(
    key: 'dept_sales',
    name: 'Sales — Month-End Review',
    category: 'Departmental Reviews',
    description: 'Bookings vs target, conversion, pipeline, ABV, cancellations + planning.',
    route: '/company-finance/department/sales',
    icon: Icons.point_of_sale_outlined,
  ),
  FinanceReport(
    key: 'dept_marketing',
    name: 'Marketing — Month-End Review',
    category: 'Departmental Reviews',
    description: 'Ad spend, ROAS, content & lead-gen performance, brand presence + planning.',
    route: '/company-finance/department/marketing',
    icon: Icons.campaign_outlined,
  ),
  FinanceReport(
    key: 'dept_hr',
    name: 'HR — Month-End Review',
    category: 'Departmental Reviews',
    description: 'Headcount, hiring, attrition, attendance, training, payroll + planning.',
    route: '/company-finance/department/hr',
    icon: Icons.groups_outlined,
  ),
  FinanceReport(
    key: 'dept_operations',
    name: 'Operations — Month-End Review',
    category: 'Departmental Reviews',
    description: 'Service delivery, utilization, CSAT, rework, logistics + planning.',
    route: '/company-finance/department/operations',
    icon: Icons.build_outlined,
  ),
  FinanceReport(
    key: 'dept_crm',
    name: 'CRM — Month-End Review',
    category: 'Departmental Reviews',
    description: 'Client database, query/complaint SLA, NPS, follow-up conversion + planning.',
    route: '/company-finance/department/crm',
    icon: Icons.support_agent_outlined,
  ),
  FinanceReport(
    key: 'dept_it',
    name: 'IT — Month-End Review',
    category: 'Departmental Reviews',
    description: 'Uptime, tickets, security, tool subscriptions, releases + planning.',
    route: '/company-finance/department/it',
    icon: Icons.dns_outlined,
  ),
  FinanceReport(
    key: 'dept_inventory',
    name: 'Inventory — Month-End Review',
    category: 'Departmental Reviews',
    description: 'Stock, wastage, reorder/vendor status, valuation, turnover + planning.',
    route: '/company-finance/department/inventory',
    icon: Icons.inventory_2_outlined,
  ),
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
    key: 'inventory_valuation',
    name: 'Inventory Valuation',
    category: 'Business Overview',
    description:
        'Current stock value (quantity × unit price), with low / out-of-stock counts.',
    route: '/company-finance/inventory-valuation',
    icon: Icons.inventory_2_outlined,
  ),
  FinanceReport(
    key: 'cash_flow',
    name: 'Cash Flow Statement',
    category: 'Business Overview',
    description:
        'Cash in (collections, advances, trials) vs cash out (expenses, purchases) and the net movement.',
    route: '/company-finance/cash-flow',
    icon: Icons.swap_vert_circle_outlined,
  ),
  FinanceReport(
    key: 'expenses_by_category',
    name: 'Expenses by Category',
    category: 'Business Overview',
    description:
        'Drill from category totals → the transactions inside → each receipt/invoice.',
    route: '/company-finance/expenses-by-category',
    icon: Icons.account_tree_outlined,
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
    key: 'tax-filings',
    name: 'GST / TDS Filings',
    category: 'Taxes',
    description:
        'Statutory filing calendar — GSTR-1, GSTR-3B, TDS payment & return — with due dates and filed / overdue / pending status.',
    route: '/company-finance/tax-filings',
    icon: Icons.fact_check_outlined,
  ),
  FinanceReport(
    key: 'gstr3b',
    name: 'GSTR-3B Summary',
    category: 'Taxes',
    description:
        'The monthly GST return — 3.1 outward supplies, 4 eligible ITC, net tax payable.',
    route: '/company-finance/gstr3b',
    icon: Icons.summarize_outlined,
  ),
  FinanceReport(
    key: 'tds',
    name: 'TDS Summary',
    category: 'Taxes',
    description: 'Tax deducted at source on vendor payments, grouped by section.',
    route: '/company-finance/tds',
    icon: Icons.request_quote_outlined,
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
