import 'package:flutter/material.dart';
import '../../core/extensions/space_extension.dart';

class ExportSalesReportDialog extends StatelessWidget {
  final String financialYear;
  final VoidCallback onTodayReport;
  final VoidCallback onDailyPerformance;
  final VoidCallback onExecutiveSummary;
  final VoidCallback onFullLedger;
  final VoidCallback onForecastReport;
  final VoidCallback onSixMonthsReport;
  final VoidCallback onOneYearReport;
  final VoidCallback onAprJunReport;
  final VoidCallback onJulSepReport;
  final VoidCallback onOctDecReport;
  final VoidCallback onJanMarReport;

  const ExportSalesReportDialog({
    super.key,
    required this.financialYear,
    required this.onTodayReport,
    required this.onDailyPerformance,
    required this.onExecutiveSummary,
    required this.onFullLedger,
    required this.onForecastReport,
    required this.onSixMonthsReport,
    required this.onOneYearReport,
    required this.onAprJunReport,
    required this.onJulSepReport,
    required this.onOctDecReport,
    required this.onJanMarReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String startYear = DateTime.now().year.toString();
    String endYear = (DateTime.now().year + 1).toString();
    if (financialYear.contains('-')) {
      final parts = financialYear.split('-');
      if (parts.length == 2) {
        startYear = parts[0];
        if (parts[1].length == 2) {
          endYear = '20${parts[1]}';
        } else {
          endYear = parts[1];
        }
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 24),
                  12.w,
                  Text(
                    'Export Sales Report',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              12.h,
              Text(
                'Generate comprehensive sales reports for performance tracking and audits.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              24.h,
              _OptionCard(
                icon: Icons.calendar_today_outlined,
                title: "Today's Complete Report",
                subtitle: 'Detailed ledger of all bookings recorded today.',
                onTap: () {
                  Navigator.pop(context);
                  onTodayReport();
                },
              ),
              12.h,
              _OptionCard(
                icon: Icons.view_day_outlined,
                title: 'Daily Performance Breakdown',
                subtitle: 'Daily revenue and booking counts for the current month.',
                onTap: () {
                  Navigator.pop(context);
                  onDailyPerformance();
                },
              ),
              12.h,
              _OptionCard(
                icon: Icons.bar_chart_outlined,
                title: 'Executive Sales Summary',
                subtitle: 'Metrics, revenue charts, and top performance stats.',
                onTap: () {
                  Navigator.pop(context);
                  onExecutiveSummary();
                },
              ),
              12.h,
              _OptionCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Sales Forecast Report',
                subtitle: 'Expected collections and upcoming payment details.',
                onTap: () {
                  Navigator.pop(context);
                  onForecastReport();
                },
              ),
              12.h,
              _OptionCard(
                icon: Icons.receipt_long_outlined,
                title: 'Full Sales Ledger',
                subtitle: 'Complete list of all bookings with status and totals.',
                onTap: () {
                  Navigator.pop(context);
                  onFullLedger();
                },
              ),
              12.h,
              _OptionCard(
                icon: Icons.date_range_outlined,
                title: 'Apr - Jun Report',
                subtitle: 'Quarterly sales and bookings for Apr - Jun $startYear.',
                onTap: () {
                  Navigator.pop(context);
                  onAprJunReport();
                },
              ),
              12.h,
              _OptionCard(
                icon: Icons.date_range_outlined,
                title: 'Jul - Sep Report',
                subtitle: 'Quarterly sales and bookings for Jul - Sep $startYear.',
                onTap: () {
                  Navigator.pop(context);
                  onJulSepReport();
                },
              ),
              12.h,
              _OptionCard(
                icon: Icons.date_range_outlined,
                title: 'Oct - Dec Report',
                subtitle: 'Quarterly sales and bookings for Oct - Dec $startYear.',
                onTap: () {
                  Navigator.pop(context);
                  onOctDecReport();
                },
              ),
              12.h,
              _OptionCard(
                icon: Icons.date_range_outlined,
                title: 'Jan - Mar Report',
                subtitle: 'Quarterly sales and bookings for Jan - Mar $endYear.',
                onTap: () {
                  Navigator.pop(context);
                  onJanMarReport();
                },
              ),
              12.h,
              _OptionCard(
                icon: Icons.date_range_outlined,
                title: 'Last 6 Months Report',
                subtitle: 'Summary of all bookings and sales in the last 6 months.',
                onTap: () {
                  Navigator.pop(context);
                  onSixMonthsReport();
                },
              ),
              12.h,
              _OptionCard(
                icon: Icons.history_toggle_off_outlined,
                title: 'Last 1 Year Report',
                subtitle: 'Full annual summary of bookings and sales ledger.',
                onTap: () {
                  Navigator.pop(context);
                  onOneYearReport();
                },
              ),
              24.h,
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: Colors.blueGrey[700]),
            ),
            16.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  4.h,
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
