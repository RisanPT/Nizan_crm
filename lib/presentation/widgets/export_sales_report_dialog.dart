import 'package:flutter/material.dart';
import '../../core/extensions/space_extension.dart';

class ExportSalesReportDialog extends StatefulWidget {
  final String financialYear;
  final String? activeFilters;
  final bool initialUseEventDate;
  final void Function(bool) onTodayReport;
  final void Function(bool) onDailyPerformance;
  final void Function(bool) onExecutiveSummary;
  final void Function(bool) onFullLedger;
  final void Function(bool) onForecastReport;
  final void Function(bool) onSixMonthsReport;
  final void Function(bool) onOneYearReport;
  final void Function(bool) onAprJunReport;
  final void Function(bool) onJulSepReport;
  final void Function(bool) onOctDecReport;
  final void Function(bool) onJanMarReport;

  const ExportSalesReportDialog({
    super.key,
    required this.financialYear,
    this.activeFilters,
    required this.initialUseEventDate,
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
  State<ExportSalesReportDialog> createState() => _ExportSalesReportDialogState();
}

class _ExportSalesReportDialogState extends State<ExportSalesReportDialog> {
  late bool _useEventDate;

  @override
  void initState() {
    super.initState();
    _useEventDate = widget.initialUseEventDate;
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            8.w,
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const Divider(height: 16, thickness: 1, color: Color(0xFFE2E8F0)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String startYear = DateTime.now().year.toString();
    String endYear = (DateTime.now().year + 1).toString();
    if (widget.financialYear.contains('-')) {
      final parts = widget.financialYear.split('-');
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
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 26, color: Color(0xFF1E293B)),
                12.w,
                Expanded(
                  child: Text(
                    'Export Sales Report',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            8.h,
            Text(
              'Generate comprehensive sales reports for performance tracking and audits.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF64748B),
              ),
            ),
            16.h,
            Row(
              children: [
                const Text(
                  'Report Date Basis:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
                16.w,
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('By Booking Date')),
                      ButtonSegment(value: true, label: Text('By Event Date')),
                    ],
                    selected: {_useEventDate},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _useEventDate = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            16.h,
            if (widget.activeFilters != null && widget.activeFilters!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9), // slate 100
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)), // slate 200
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_alt, size: 18, color: Color(0xFF475569)), // slate 600
                    10.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXPORT DATA SCOPE (ACTIVE FILTERS)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          4.h,
                          Text(
                            widget.activeFilters!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B), // slate 800
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              16.h,
            ],
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(theme, 'Core Performance & Ledgers'),
                    12.h,
                    _OptionCard(
                      icon: Icons.calendar_today_outlined,
                      title: "Today's Complete Report",
                      subtitle: 'Detailed ledger of all bookings recorded today.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onTodayReport(_useEventDate);
                      },
                    ),
                    12.h,
                    _OptionCard(
                      icon: Icons.view_day_outlined,
                      title: 'Daily Performance Breakdown',
                      subtitle: 'Daily revenue and booking counts for the current month.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onDailyPerformance(_useEventDate);
                      },
                    ),
                    12.h,
                    _OptionCard(
                      icon: Icons.bar_chart_outlined,
                      title: 'Executive Sales Summary',
                      subtitle: 'Metrics, revenue charts, and top performance stats.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onExecutiveSummary(_useEventDate);
                      },
                    ),
                    12.h,
                    _OptionCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Sales Forecast Report',
                      subtitle: 'Expected collections and upcoming payment details.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onForecastReport(_useEventDate);
                      },
                    ),
                    12.h,
                    _OptionCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Full Sales Ledger',
                      subtitle: 'Complete list of all bookings with status and totals.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onFullLedger(_useEventDate);
                      },
                    ),
                    24.h,
                    _buildSectionHeader(theme, 'Quarterly & Periodic Audits'),
                    12.h,
                    _OptionCard(
                      icon: Icons.date_range_outlined,
                      title: 'Apr - Jun Report',
                      subtitle: 'Quarterly sales and bookings for Apr - Jun $startYear.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onAprJunReport(_useEventDate);
                      },
                    ),
                    12.h,
                    _OptionCard(
                      icon: Icons.date_range_outlined,
                      title: 'Jul - Sep Report',
                      subtitle: 'Quarterly sales and bookings for Jul - Sep $startYear.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onJulSepReport(_useEventDate);
                      },
                    ),
                    12.h,
                    _OptionCard(
                      icon: Icons.date_range_outlined,
                      title: 'Oct - Dec Report',
                      subtitle: 'Quarterly sales and bookings for Oct - Dec $startYear.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onOctDecReport(_useEventDate);
                      },
                    ),
                    12.h,
                    _OptionCard(
                      icon: Icons.date_range_outlined,
                      title: 'Jan - Mar Report',
                      subtitle: 'Quarterly sales and bookings for Jan - Mar $endYear.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onJanMarReport(_useEventDate);
                      },
                    ),
                    12.h,
                    _OptionCard(
                      icon: Icons.date_range_outlined,
                      title: 'Last 6 Months Report',
                      subtitle: 'Summary of all bookings and sales in the last 6 months.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onSixMonthsReport(_useEventDate);
                      },
                    ),
                    12.h,
                    _OptionCard(
                      icon: Icons.history_toggle_off_outlined,
                      title: 'Last 1 Year Report',
                      subtitle: 'Full annual summary of bookings and sales ledger.',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onOneYearReport(_useEventDate);
                      },
                    ),
                  ],
                ),
              ),
            ),
            12.h,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)), // slate 200
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9), // slate 100
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF475569)), // slate 600
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
                      fontSize: 14,
                      color: Color(0xFF1E293B), // slate 800
                    ),
                  ),
                  4.h,
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B), // slate 500
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)), // slate 400
          ],
        ),
      ),
    );
  }
}
