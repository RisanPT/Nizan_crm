import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
String _pct(num v) => '${v.toStringAsFixed(1)}%';

class _Term {
  final String name;
  final String definition;
  final String Function(MonthEndReview r)? value;
  const _Term(this.name, this.definition, [this.value]);
}

/// Finance → Financial Glossary: the terms every CEO reviews monthly, in plain
/// English, each paired with this month's live value from the review.
class FinancialGlossaryScreen extends ConsumerStatefulWidget {
  const FinancialGlossaryScreen({super.key});

  @override
  ConsumerState<FinancialGlossaryScreen> createState() => _FinancialGlossaryScreenState();
}

class _FinancialGlossaryScreenState extends ConsumerState<FinancialGlossaryScreen> {
  String _search = '';

  static final List<_Term> _terms = [
    _Term('Revenue', 'Total income earned from sales/bookings before any costs.', (r) => _money(r.revenue)),
    _Term('Gross Profit (GP)', 'Revenue minus the direct cost of delivering the service.', (r) => _money(r.grossProfit)),
    _Term('Gross Margin', 'Gross profit as a % of revenue — how much each rupee of sales keeps after direct costs.', (r) => _pct(r.grossMarginPct)),
    _Term('EBITDA', 'Earnings Before Interest, Tax, Depreciation & Amortisation — core operating profit.', (r) => _money(r.ebitda)),
    _Term('EBITDA Margin', 'EBITDA as a % of revenue — operating profitability.', (r) => _pct(r.ebitdaMarginPct)),
    _Term('Net Profit (PAT)', 'Profit After Tax — what remains after ALL costs. The bottom line.', (r) => _money(r.netProfit)),
    _Term('Net Margin', 'Net profit as a % of revenue.', (r) => _pct(r.netMarginPct)),
    _Term('Cash Flow', 'Actual cash in minus cash out this month (different from profit).', (r) => _money(r.cashNet)),
    _Term('Free Cash Flow', 'Operating cash flow minus CapEx — cash left to reinvest or distribute.', (r) => _money(r.freeCashFlow)),
    _Term('Burn Rate', 'How much cash the business loses per month when spending exceeds income.', (r) => _money(r.burnRate)),
    _Term('Cash Runway', 'Months the business can operate on current cash at the present burn rate.', (r) => r.cashRunwayMonths != null ? '${r.cashRunwayMonths!.toStringAsFixed(1)} months' : '∞ (profitable)'),
    _Term('Working Capital', 'Current assets minus current liabilities — short-term financial health.', (r) => _money(r.workingCapital)),
    _Term('Current Ratio', 'Current assets ÷ current liabilities. Above 1 means bills are covered.', (r) => r.currentRatio?.toStringAsFixed(2) ?? '—'),
    _Term('Accounts Receivable (AR)', 'Money customers still owe you.', (r) => _money(r.arOutstanding)),
    _Term('Accounts Payable (AP)', 'Money you still owe vendors/suppliers.', (r) => _money(r.apOutstanding)),
    _Term('Budget vs Actual', 'Planned spend compared with what was actually spent.', (r) => '${_money(r.totalActual)} / ${_money(r.totalBudget)}'),
    _Term('Variance Analysis', 'The gap between budget and actual, and why it happened.', (r) => _money(r.totalVariance)),
    _Term('Operating Expenses (OPEX)', 'Day-to-day running costs — salaries, rent, utilities, marketing.', (r) => _money(r.totalExpense)),
    _Term('Capital Expenditure (CAPEX)', 'Spend on long-term assets like equipment — capitalised, not expensed.', (r) => _money(r.capex)),
    _Term('Return on Investment (ROI)', 'Profit generated relative to the money invested.', null),
    _Term('Customer Acquisition Cost (CAC)', 'Marketing spend divided by new customers won.', (r) => _money(r.cac)),
    _Term('Customer Lifetime Value (LTV)', 'Total revenue expected from a customer over the relationship.', (r) => _money(r.ltv)),
    _Term('Inventory Turnover', 'How many times stock is sold and replaced in a year (annualised).',
        (r) => r.inventoryTurnover != null ? '${r.inventoryTurnover!.toStringAsFixed(1)}×' : '—'),
    _Term('Days Sales Outstanding (DSO)', 'Average days to collect payment after a sale.',
        (r) => r.dso != null ? '${r.dso!.toStringAsFixed(0)} days' : '—'),
    _Term('Days Payable Outstanding (DPO)', 'Average days you take to pay suppliers.',
        (r) => r.dpo != null ? '${r.dpo!.toStringAsFixed(0)} days' : '—'),
    _Term('Debt-to-Equity Ratio', 'Total liabilities relative to owner equity — financial leverage.',
        (r) => r.debtToEquity != null ? r.debtToEquity!.toStringAsFixed(2) : '—'),
    _Term('Revenue per Employee', 'Revenue divided by headcount — productivity.', (r) => _money(r.revenuePerEmployee)),
  ];

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final now = DateTime.now();
    final async = ref.watch(monthEndReviewProvider((month: now.month, year: now.year)));
    final q = _search.trim().toLowerCase();
    final terms = q.isEmpty
        ? _terms
        : _terms.where((t) => '${t.name} ${t.definition}'.toLowerCase().contains(q)).toList();

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search a term…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            // Definitions always render; live values fill in when the review loads.
            loading: () => _list(crm, terms, null),
            error: (_, _) => _list(crm, terms, null),
            data: (r) => _list(crm, terms, r),
          ),
        ),
      ]),
    );
  }

  Widget _list(CrmTheme crm, List<_Term> terms, MonthEndReview? r) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 40),
      itemCount: terms.length,
      itemBuilder: (_, i) {
        final t = terms[i];
        final live = (r != null && t.value != null) ? t.value!(r) : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crm.border.faded(0.6)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(t.name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary))),
                if (live != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(live, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.primary)),
                  ),
              ]),
              6.h,
              Text(t.definition, style: TextStyle(fontSize: 13, height: 1.35, color: crm.textSecondary)),
            ]),
          ),
        );
      },
    );
  }
}
