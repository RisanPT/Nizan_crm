import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/accounts/data/account_report.dart';
import 'package:nizan_crm/features/accounts/controllers/account_report_provider.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/report_access_picker.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

String _mimeFor(String fileType) {
  switch (fileType) {
    case 'pdf':
      return 'application/pdf';
    case 'excel':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'csv':
      return 'text/csv';
    default:
      return 'application/octet-stream';
  }
}

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
        ref.refreshData.accountReports();
      } catch (e) {
        if (mounted) showErrorSnackBar(context, e);
      }
    }
  }

  /// Download the file through the API (streamed with the correct content-type
  /// and filename) so it always saves as a valid file — no Cloudinary raw
  /// inline / missing-extension issues.
  Future<void> _download(AccountReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Downloading…')));
    try {
      final bytes = await ref.read(accountReportServiceProvider).downloadBytes(report.id);
      if (bytes.isEmpty) throw Exception('Empty file');
      await saveFileBytes(report.downloadName, bytes, mime: _mimeFor(report.fileType));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  /// Modify a report — rename its title and/or replace the underlying file.
  Future<void> _editReport(AccountReport report) async {
    final crm = context.crmColors;
    final titleCtrl = TextEditingController(text: report.title);
    PlatformFile? picked;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: crm.surface,
          title: Text('Modify report', style: TextStyle(color: crm.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: crm.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Report title',
                  labelStyle: TextStyle(color: crm.textSecondary),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: crm.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: crm.accent)),
                ),
              ),
              12.h,
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(picked == null ? 'Replace file (optional)' : 'Selected: ${picked!.name}',
                    overflow: TextOverflow.ellipsis),
                onPressed: () async {
                  final res = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: const ['pdf', 'xls', 'xlsx', 'csv'],
                    withData: true,
                  );
                  if (res != null) setLocal(() => picked = res.files.single);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: crm.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final newTitle = titleCtrl.text.trim();
    if (newTitle.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Updating report…')));
    try {
      await ref.read(accountReportServiceProvider).updateReport(
            id: report.id,
            title: newTitle,
            bytes: picked?.bytes,
            filePath: picked?.path,
            filename: picked?.name,
          );
      ref.refreshData.accountReports();
      messenger.showSnackBar(const SnackBar(content: Text('Report updated')));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  /// Owner/admin only — change which users may view this report.
  Future<void> _manageAccess(AccountReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showReportAccessPicker(
      context,
      ref,
      initial: report.sharedWith.map((v) => v.id).toSet(),
      ownerId: report.uploadedById,
      title: 'Who can view “${report.title}”',
    );
    if (picked == null) return;
    try {
      await ref.read(accountReportServiceProvider).updateAccess(report.id, picked);
      ref.refreshData.accountReports();
      messenger.showSnackBar(
        SnackBar(
          content: Text(picked.isEmpty
              ? 'Report is now private to you'
              : 'Shared with ${picked.length} ${picked.length == 1 ? 'person' : 'people'}'),
        ),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncReports = ref.watch(accountReportsProvider);
    final session = ref.watch(authSessionProvider);
    final myId = session?.userId ?? '';
    final isAdmin = session?.role == 'admin';

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
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(accountReportsProvider),
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
              // Only the uploader (or an admin) may rename/replace, delete, or
              // change who can view a report.
              final canManage = isAdmin || report.uploadedById == myId;
              final shareCount = report.sharedWith.length;
              final accessLabel = shareCount == 0
                  ? 'Private'
                  : 'Shared with $shareCount ${shareCount == 1 ? 'person' : 'people'}';

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
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Uploaded on ${DateFormat('MMM d, yyyy h:mm a').format(report.createdAt)}',
                            style: TextStyle(color: crm.textSecondary, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        8.w,
                        Icon(
                          shareCount == 0 ? Icons.lock_outline : Icons.group_outlined,
                          size: 13,
                          color: crm.textSecondary,
                        ),
                        4.w,
                        Text(accessLabel,
                            style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.download_rounded, color: crm.primary),
                        tooltip: 'Download',
                        onPressed: () => _download(report),
                      ),
                      if (canManage)
                        IconButton(
                          icon: Icon(Icons.lock_person_outlined, color: crm.primary),
                          tooltip: 'Manage access',
                          onPressed: () => _manageAccess(report),
                        ),
                      if (canManage)
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: crm.accent),
                          tooltip: 'Rename / Replace',
                          onPressed: () => _editReport(report),
                        ),
                      if (canManage)
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: crm.destructive),
                          tooltip: 'Delete',
                          onPressed: () => _deleteReport(report),
                        ),
                    ],
                  ),
                  onTap: () => _download(report),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
