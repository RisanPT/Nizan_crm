import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/account_report_provider.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/staff_reports_screen.dart';

/// Human-readable file size.
String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Cloudinary raw uploads are capped; reject oversized files client-side with a
/// clear message instead of a failed request.
const _maxUploadBytes = 25 * 1024 * 1024; // 25 MB

class AccountsReportsScreen extends ConsumerStatefulWidget {
  const AccountsReportsScreen({super.key});

  @override
  ConsumerState<AccountsReportsScreen> createState() =>
      _AccountsReportsScreenState();
}

class _AccountsReportsScreenState extends ConsumerState<AccountsReportsScreen> {
  Future<void> _uploadReport() async {
    final crm = context.crmColors;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xls', 'xlsx', 'csv'],
      withData: true,
    );
    if (result == null) return;

    final file = result.files.single;
    final fileName = file.name;

    if (file.size > _maxUploadBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('“$fileName” is ${_fmtSize(file.size)} — max is ${_fmtSize(_maxUploadBytes)}.'),
            backgroundColor: crm.destructive,
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    {
      // Ask for title
      final titleController = TextEditingController(text: fileName);
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: crm.surface,
          title: Text('Upload Report', style: TextStyle(color: crm.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$fileName · ${_fmtSize(file.size)}', style: TextStyle(color: crm.textSecondary)),
              16.h,
              TextField(
                controller: titleController,
                style: TextStyle(color: crm.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Report Title',
                  labelStyle: TextStyle(color: crm.textSecondary),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: crm.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: crm.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: crm.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
              child: const Text('Upload', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true && titleController.text.isNotEmpty) {
        try {
          // Show loading
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Uploading report...')),
            );
          }

          final service = ref.read(accountReportServiceProvider);
          await service.uploadReport(
            title: titleController.text,
            filename: fileName,
            filePath: file.path,
            bytes: file.bytes,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upload successful!')),
            );
          }
          ref.invalidate(accountReportsProvider);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e')),
            );
          }
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadReport,
        backgroundColor: crm.primary,
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text('Upload Report', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountReportsProvider),
        child: asyncReports.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Error loading reports: $error', style: TextStyle(color: crm.destructive)),
          ),
          data: (reports) {
            if (reports.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: crm.border),
                          16.h,
                          Text(
                            'No reports uploaded yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: crm.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            final Map<String, int> staffReportCounts = {};
            for (var report in reports) {
              staffReportCounts[report.uploadedByName] = 
                  (staffReportCounts[report.uploadedByName] ?? 0) + 1;
            }
            final staffNames = staffReportCounts.keys.toList();

            return GridView.builder(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                16,
                isMobile ? 16 : 24,
                80,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 2 : 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: staffNames.length,
              itemBuilder: (context, index) {
                final staffName = staffNames[index];
                final count = staffReportCounts[staffName]!;

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StaffReportsScreen(
                          staffName: staffName,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: crm.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: crm.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_shared,
                          size: 48,
                          color: crm.primary,
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            staffName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: crm.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count file${count == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: crm.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
