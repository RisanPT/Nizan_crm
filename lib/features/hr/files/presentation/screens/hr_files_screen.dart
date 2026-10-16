import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/features/hr/shared/hr_person_picker.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr/files/data/employee_document_models.dart';
import 'package:nizan_crm/features/hr/files/service/employee_document_service.dart';

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

IconData _iconFor(String fileType) {
  switch (fileType) {
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'image':
      return Icons.image_outlined;
    case 'excel':
    case 'csv':
      return Icons.table_chart_outlined;
    case 'word':
      return Icons.description_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

/// HR Files — the per-employee document vault. HR/managers pick an employee and
/// manage their documents; an employee (ESS) sees and uploads only their own.
class HrFilesScreen extends ConsumerStatefulWidget {
  const HrFilesScreen({super.key});
  @override
  ConsumerState<HrFilesScreen> createState() => _HrFilesScreenState();
}

class _HrFilesScreenState extends ConsumerState<HrFilesScreen> {
  String _selectedEmployeeId = '';

  bool _isHrManager(Access access) =>
      access.isFullAccess || access.has('staff', false) || access.has('hr_files', false);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);
    final isHr = _isHrManager(access);
    final ownEmployeeId = session?.employeeId ?? '';

    // For an ESS employee the vault is always their own; HR selects a target.
    final targetId = isHr ? _selectedEmployeeId : ownEmployeeId;
    final docs = ref.watch(employeeDocumentsProvider(targetId));

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: (targetId.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => _upload(targetId),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
            )
          : null,
      body: Column(
        children: [
          if (isHr) _employeePicker(crm),
          Expanded(
            child: (isHr && targetId.isEmpty)
                ? Center(
                    child: Text('Pick an employee to see their documents.',
                        style: TextStyle(color: crm.textSecondary)))
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(employeeDocumentsProvider(targetId)),
                    child: docs.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ListView(children: [
                        AppErrorView(error: e, onRetry: () => ref.invalidate(employeeDocumentsProvider(targetId)))
                      ]),
                      data: (list) => list.isEmpty
                          ? ListView(children: [
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                    child: Text('No documents yet.',
                                        style: TextStyle(color: crm.textSecondary))),
                              )
                            ])
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                              children: list.map((d) => _docRow(d, crm, targetId)).toList(),
                            ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _employeePicker(CrmTheme crm) {
    final employees = ref.watch(employeesProvider);
    return Container(
      color: crm.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: employees.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive)),
        data: (list) {
          final active = list.where((e) => e.status == 'active').toList();
          return Row(
            children: [
              Expanded(
                child: PersonPickerField(
                  label: 'Employee',
                  icon: Icons.person_search_outlined,
                  hint: 'Pick an employee',
                  selectedId: _selectedEmployeeId.isEmpty ? null : _selectedEmployeeId,
                  items: active.map((e) => PickerItem(id: e.id, name: e.name, department: e.department ?? '')).toList(),
                  onChanged: (v) => setState(() => _selectedEmployeeId = v ?? ''),
                ),
              ),
              if (_selectedEmployeeId.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'View Profile',
                  icon: const Icon(Icons.person_outline, size: 20),
                  onPressed: () => context.push('/staff/$_selectedEmployeeId'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _docRow(EmployeeDocument d, CrmTheme crm, String targetId) {
    final expired = d.expiresOn != null && d.expiresOn!.isBefore(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Icon(_iconFor(d.fileType), color: crm.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
                      child: Text(documentCategoryLabel(d.category),
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: crm.primary)),
                    ),
                    if (d.expiresOn != null) ...[
                      const SizedBox(width: 8),
                      Text('Expires ${_fmt(d.expiresOn)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: expired ? crm.destructive : crm.textSecondary,
                              fontWeight: expired ? FontWeight.w700 : FontWeight.w400)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open',
            icon: Icon(Icons.open_in_new, size: 18, color: crm.textSecondary),
            onPressed: () => _open(d.id),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline, size: 18, color: crm.textSecondary),
            onPressed: () => _delete(d, targetId),
          ),
        ],
      ),
    );
  }

  Future<void> _open(String id) async {
    final token = ref.read(authSessionProvider)?.token ?? '';
    final uri = Uri.parse('$apiBaseUrl/employee-documents/$id/download?inline=1&token=$token');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the file')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the file')));
      }
    }
  }

  Future<void> _delete(EmployeeDocument d, String targetId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document'),
        content: Text('Remove "${d.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(employeeDocumentServiceProvider).delete(d.id);
      ref.invalidate(employeeDocumentsProvider(targetId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  Future<void> _upload(String targetId) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xls', 'xlsx', 'csv', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyErrorMessage(e, fallback: "Couldn't open the file picker."))));
      }
      return;
    }
    if (result == null) return;
    final file = result.files.single;
    if (file.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read the file')));
      }
      return;
    }
    if (!mounted) return;
    final meta = await showDialog<_UploadMeta>(
      context: context,
      builder: (_) => _UploadDialog(defaultTitle: file.name),
    );
    if (meta == null) return;
    try {
      await ref.read(employeeDocumentServiceProvider).upload(
            employeeId: targetId,
            title: meta.title,
            category: meta.category,
            description: meta.description,
            expiresOn: meta.expiresOn,
            bytes: file.bytes,
            filename: file.name,
          );
      ref.invalidate(employeeDocumentsProvider(targetId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }
}

class _UploadMeta {
  final String title;
  final String category;
  final String description;
  final DateTime? expiresOn;
  const _UploadMeta(this.title, this.category, this.description, this.expiresOn);
}

class _UploadDialog extends StatefulWidget {
  const _UploadDialog({required this.defaultTitle});
  final String defaultTitle;
  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  late final TextEditingController _title;
  final _desc = TextEditingController();
  String _category = 'other';
  DateTime? _expiresOn;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.defaultTitle);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Document details'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: kDocumentCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(documentCategoryLabel(c))))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'other'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _expiresOn ?? now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 10),
                        );
                        if (d != null) setState(() => _expiresOn = d);
                      },
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(_expiresOn == null ? 'Expiry (optional)' : _fmt(_expiresOn)),
                    ),
                  ),
                  if (_expiresOn != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _expiresOn = null),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _desc,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.of(context).pop(_UploadMeta(_title.text.trim(), _category, _desc.text.trim(), _expiresOn));
          },
          child: const Text('Upload'),
        ),
      ],
    );
  }
}
