import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nizan_crm/features/accounts/data/account_report.dart';
import 'package:nizan_crm/features/accounts/controllers/account_report_provider.dart';

class StaffReportsScreen extends ConsumerStatefulWidget {
  final String staffName;

  const StaffReportsScreen({
    super.key,
    required this.staffName,
  });

  @override
  ConsumerState<StaffReportsScreen> createState() => _StaffReportsScreenState();
}

class _StaffReportsScreenState extends ConsumerState<StaffReportsScreen> {
  DateTimeRange? _selectedDateRange;

  Future<void> _selectDateRange() async {
    final crm = context.crmColors;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: crm.primary,
              onPrimary: Colors.white,
              surface: crm.surface,
              onSurface: crm.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _deleteReport(AccountReport report) async {
    final crm = context.crmColors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: crm.surface,
        title: Text('Delete Report', style: TextStyle(color: crm.textPrimary)),
        content: Text('Are you sure you want to delete "${report.title}"?', style: TextStyle(color: crm.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: crm.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: crm.destructive)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final service = ref.read(accountReportServiceProvider);
        await service.deleteReport(report.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted')),
          );
        }
        ref.invalidate(accountReportsProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncReports = ref.watch(accountReportsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        backgroundColor: crm.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: crm.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.staffName,
          style: TextStyle(
            color: crm.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: _selectedDateRange != null ? crm.primary : crm.textSecondary,
            ),
            tooltip: 'Filter by Date',
            onPressed: _selectDateRange,
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: Icon(Icons.clear, color: crm.destructive),
              tooltip: 'Clear Filter',
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                });
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: asyncReports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Error loading reports: $error', style: TextStyle(color: crm.destructive)),
        ),
        data: (allReports) {
          // Filter by staff name and date range
          final reports = allReports.where((report) {
            final matchesStaff = report.uploadedByName == widget.staffName;
            if (!matchesStaff) return false;

            if (_selectedDateRange != null) {
              final date = report.createdAt;
              // include start day from 00:00:00 and end day up to 23:59:59
              final start = _selectedDateRange!.start;
              final end = _selectedDateRange!.end.add(const Duration(days: 1, milliseconds: -1));
              return date.isAfter(start) && date.isBefore(end);
            }
            return true;
          }).toList();

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: crm.border),
                  16.h,
                  Text(
                    _selectedDateRange != null
                        ? 'No reports found for the selected dates'
                        : 'No reports found for this staff',
                    style: TextStyle(
                      fontSize: 16,
                      color: crm.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24,
              16,
              isMobile ? 16 : 24,
              80,
            ),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final isPdf = report.fileType.toLowerCase() == 'pdf';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: crm.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: crm.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPdf ? crm.destructive.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.table_chart,
                      color: isPdf ? crm.destructive : Colors.green,
                    ),
                  ),
                  title: Text(
                    report.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: crm.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Uploaded on ${DateFormat('MMM d, yyyy h:mm a').format(report.createdAt)}',
                      style: TextStyle(
                        color: crm.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.download_rounded, color: crm.primary),
                        tooltip: 'Download / View',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final uri = Uri.parse(report.fileUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Could not open the file.')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: crm.destructive),
                        tooltip: 'Delete',
                        onPressed: () => _deleteReport(report),
                      ),
                    ],
                  ),
                  onTap: () async {
                    final uri = Uri.parse(report.fileUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
