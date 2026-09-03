import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/my_department_provider.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/features/reports/data/company_report.dart';
import 'package:nizan_crm/features/reports/data/report_folder.dart';
import 'package:nizan_crm/features/reports/presentation/screens/report_viewer_screen.dart';
import 'package:nizan_crm/features/reports/services/company_report_service.dart';

const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime d) => '${d.day} ${_mon[d.month]} ${d.year}';
const _maxUploadBytes = 25 * 1024 * 1024;
const _roleOptions = [
  'admin', 'manager', 'accounts', 'sales', 'crm', 'hr',
  'marketing_admin', 'fleet_manager', 'inventory_manager', 'artist', 'driver',
];

String _fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
}

IconData _fileIcon(String t) {
  switch (t) {
    case 'pdf': return Icons.picture_as_pdf_outlined;
    case 'excel': return Icons.table_chart_outlined;
    case 'csv': return Icons.grid_on_outlined;
    case 'word': return Icons.description_outlined;
    case 'image': return Icons.image_outlined;
    default: return Icons.insert_drive_file_outlined;
  }
}

/// Company report library — files uploaded per department, access by
/// department + role (enforced on the server).
class CompanyReportsScreen extends ConsumerStatefulWidget {
  const CompanyReportsScreen({super.key});
  @override
  ConsumerState<CompanyReportsScreen> createState() => _CompanyReportsScreenState();
}

class _CompanyReportsScreenState extends ConsumerState<CompanyReportsScreen> {
  String _deptFilter = 'All';
  // null → all folders (grouped); a folder id → that folder; _kUnfiled → no folder.
  String? _folder;

  static const _kTeam = '__team__';
  static const _kUnfiled = '__unfiled__';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final isHead = session?.isDepartmentHead == true;
    final isTeam = _deptFilter == _kTeam;
    final chipsAsync = ref.watch(companyReportsProvider);
    final bodyAsync = isTeam ? ref.watch(teamReportsProvider) : chipsAsync;

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        title: const Text('Company Reports'),
        backgroundColor: crm.surface,
        foregroundColor: crm.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        backgroundColor: crm.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload report'),
      ),
      body: Column(
        children: [
          // Filter row: All · (My Team — dept heads only) · each department.
          chipsAsync.maybeWhen(
            data: (reports) {
              final depts = <String>{for (final r in reports) r.department}.toList()..sort();
              return SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _chip('All', 'All', reports.length),
                    if (isHead) _chip(_kTeam, 'My Team', null, icon: Icons.groups_outlined),
                    for (final d in depts) _chip(d, d, reports.where((r) => r.department == d).length),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox(height: 52),
          ),
          // Folders live inside a department, so the folder bar only shows when
          // a single department is selected.
          if (!isTeam && _deptFilter != 'All') _folderBar(_deptFilter),
          Expanded(
            child: bodyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorView(
                error: e,
                onRetry: () => ref.invalidate(isTeam ? teamReportsProvider : companyReportsProvider),
              ),
              data: (reports) {
                if (reports.isEmpty) return _emptyState(context, isTeam);
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(isTeam ? teamReportsProvider : companyReportsProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    children: _bodyChildren(reports, isTeam),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _bodyChildren(List<CompanyReport> reports, bool isTeam) {
    String uploader(CompanyReport r) => r.uploadedByName.isEmpty ? 'Unknown' : r.uploadedByName;
    if (isTeam) {
      // A department head's view — group their team's uploads by employee.
      final people = <String>{for (final r in reports) uploader(r)}.toList()..sort();
      return [
        for (final p in people) ...[
          _sectionHeader(Icons.person_outline, p, reports.where((r) => uploader(r) == p).length),
          for (final r in reports.where((r) => uploader(r) == p)) _reportTile(r),
        ],
      ];
    }
    if (_deptFilter == 'All') {
      final depts = <String>{for (final r in reports) r.department}.toList()..sort();
      return [
        for (final d in depts) ...[
          _sectionHeader(Icons.folder_outlined, d, reports.where((r) => r.department == d).length),
          for (final r in reports.where((r) => r.department == d)) _reportTile(r),
        ],
      ];
    }
    // A single department is selected — organise its reports by folder.
    final deptReports =
        reports.where((r) => r.department == _deptFilter).toList();
    final folders =
        ref.watch(reportFoldersProvider(_deptFilter)).value ?? const <ReportFolder>[];

    if (_folder == _kUnfiled) {
      return [
        for (final r in deptReports.where((r) => r.folderId.isEmpty))
          _reportTile(r),
      ];
    }
    if (_folder != null) {
      return [
        for (final r in deptReports.where((r) => r.folderId == _folder))
          _reportTile(r),
      ];
    }

    // All folders → group by folder, with an "Unfiled" bucket at the end.
    final children = <Widget>[];
    for (final f in folders) {
      final inFolder = deptReports.where((r) => r.folderId == f.id).toList();
      children.add(_sectionHeader(Icons.folder_outlined, f.name, inFolder.length));
      for (final r in inFolder) {
        children.add(_reportTile(r));
      }
    }
    final unfiled = deptReports.where((r) => r.folderId.isEmpty).toList();
    if (unfiled.isNotEmpty || folders.isEmpty) {
      children.add(_sectionHeader(Icons.folder_off_outlined, 'Unfiled', unfiled.length));
      for (final r in unfiled) {
        children.add(_reportTile(r));
      }
    }
    return children;
  }

  Widget _chip(String value, String label, int? count, {IconData? icon}) {
    final crm = context.crmColors;
    final selected = _deptFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? crm.primary : crm.textSecondary),
        label: Text(count == null ? label : '$label ($count)'),
        selected: selected,
        onSelected: (_) => setState(() {
          _deptFilter = value;
          _folder = null; // reset folder when switching department
        }),
        selectedColor: crm.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: selected ? crm.primary : crm.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _folderBar(String dept) {
    final crm = context.crmColors;
    final folders = ref.watch(reportFoldersProvider(dept)).value ?? const <ReportFolder>[];
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            _folderChip(null, 'All folders', Icons.folder_copy_outlined),
            for (final f in folders)
              _folderChip(f.id, f.name, Icons.folder_outlined, folder: f),
            _folderChip(_kUnfiled, 'Unfiled', Icons.folder_off_outlined),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ActionChip(
                avatar: Icon(Icons.create_new_folder_outlined, size: 16, color: crm.primary),
                label: const Text('New folder'),
                onPressed: () => _addFolder(dept),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _folderChip(String? value, String label, IconData icon, {ReportFolder? folder}) {
    final crm = context.crmColors;
    final selected = _folder == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: folder == null ? null : () => _manageFolder(folder),
        child: ChoiceChip(
          avatar: Icon(icon, size: 15, color: selected ? crm.primary : crm.textSecondary),
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _folder = value),
          selectedColor: crm.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: selected ? crm.primary : crm.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool isTeam) {
    final crm = context.crmColors;
    return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(
              child: Column(children: [
                Icon(isTeam ? Icons.groups_outlined : Icons.folder_open_outlined, size: 52, color: crm.textSecondary),
                const SizedBox(height: 10),
                Text(isTeam ? 'No uploads from your team yet.' : 'No reports here yet.',
                    style: TextStyle(color: crm.textSecondary)),
                const SizedBox(height: 2),
                Text(isTeam ? 'Reports your team members upload will appear here.' : 'Upload a report and file it under a department.',
                    style: TextStyle(color: crm.textSecondary, fontSize: 12)),
              ]),
            ),
          ),
        ],
      );
  }

  Widget _sectionHeader(IconData icon, String name, int count) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: crm.primary),
          const SizedBox(width: 8),
          Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
            child: Text('$count',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.primary)),
          ),
          Expanded(child: Divider(indent: 12, color: crm.border)),
        ],
      ),
    );
  }

  Widget _reportTile(CompanyReport r) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final canManage = session?.role == 'admin' || session?.role == 'manager' || r.uploadedById == (session?.userId ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
      child: ListTile(
        onTap: () => _openViewer(r),
        leading: CircleAvatar(
          backgroundColor: crm.primary.withValues(alpha: 0.1),
          child: Icon(_fileIcon(r.fileType), color: crm.primary, size: 20),
        ),
        title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            r.department,
            if (r.folderName.isNotEmpty) r.folderName,
            if (r.period.isNotEmpty) r.period,
            if (r.uploadedByName.isNotEmpty) 'by ${r.uploadedByName}',
            _date(r.createdAt),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Download',
              onPressed: () => _download(r),
            ),
            if (canManage)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: crm.textSecondary),
                tooltip: 'More',
                onSelected: (v) {
                  if (v == 'open') _openViewer(r);
                  if (v == 'move') _moveToFolder(r);
                  if (v == 'delete') _confirmDelete(r);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'open',
                    child: ListTile(
                      leading: Icon(Icons.open_in_full),
                      title: Text('Open'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'move',
                    child: ListTile(
                      leading: Icon(Icons.drive_file_move_outline),
                      title: Text('Move to folder'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _openViewer(CompanyReport r) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportViewerScreen(report: r)),
    );
  }

  Future<void> _download(CompanyReport r) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref.read(companyReportServiceProvider).downloadBytes(r.id);
      if (bytes.isEmpty) throw Exception('Empty file');
      await saveFileBytes(r.downloadName, bytes);
      messenger.showSnackBar(SnackBar(content: Text('Downloaded ${r.downloadName}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _confirmDelete(CompanyReport r) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete report?'),
        content: Text('Remove "${r.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.crmColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(companyReportServiceProvider).delete(r.id);
      ref.invalidate(companyReportsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Report deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<String?> _promptFolderName(String title, {String initial = ''}) async {
    final ctrl = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'e.g. Monthly Reports',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<void> _addFolder(String dept) async {
    final name = await _promptFolderName('New folder in $dept');
    if (name == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(companyReportServiceProvider).createFolder(name, department: dept);
      ref.invalidate(reportFoldersProvider(dept));
      messenger.showSnackBar(SnackBar(content: Text('Folder "$name" created')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Future<void> _manageFolder(ReportFolder f) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename folder'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete folder'),
              subtitle: const Text('Documents inside move to Unfiled'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename') {
      final name = await _promptFolderName('Rename folder', initial: f.name);
      if (name == null || name == f.name || !mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(companyReportServiceProvider).renameFolder(f.id, name);
        ref.invalidate(reportFoldersProvider(f.department));
        ref.invalidate(companyReportsProvider);
        messenger.showSnackBar(const SnackBar(content: Text('Folder renamed')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(_err(e))));
      }
    } else if (action == 'delete') {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete folder?'),
          content: Text('Delete "${f.name}"? Documents inside move to Unfiled.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ctx.crmColors.destructive),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await ref.read(companyReportServiceProvider).deleteFolder(f.id);
        if (_folder == f.id) setState(() => _folder = null);
        ref.invalidate(reportFoldersProvider(f.department));
        ref.invalidate(companyReportsProvider);
        messenger.showSnackBar(const SnackBar(content: Text('Folder deleted')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(_err(e))));
      }
    }
  }

  Future<void> _moveToFolder(CompanyReport r) async {
    final messenger = ScaffoldMessenger.of(context);
    List<ReportFolder> folders;
    try {
      folders = await ref.read(reportFoldersProvider(r.department).future);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_err(e))));
      return;
    }
    if (!mounted) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Move to folder', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Unfiled'),
              trailing: r.folderId.isEmpty ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final f in folders)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f.name),
                trailing: r.folderId == f.id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, f.id),
              ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder…'),
              onTap: () => Navigator.pop(ctx, '__new__'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return; // dismissed

    try {
      if (choice == '__new__') {
        final name = await _promptFolderName('New folder in ${r.department}');
        if (name == null) return;
        final folder =
            await ref.read(companyReportServiceProvider).createFolder(name, department: r.department);
        await ref.read(companyReportServiceProvider).moveToFolder(r.id, folder.id);
        ref.invalidate(reportFoldersProvider(r.department));
      } else {
        await ref
            .read(companyReportServiceProvider)
            .moveToFolder(r.id, choice.isEmpty ? null : choice);
      }
      ref.invalidate(companyReportsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Report moved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Future<void> _upload() async {
    final crm = context.crmColors;
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xls', 'xlsx', 'csv', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    if (file.size > _maxUploadBytes) {
      messenger.showSnackBar(SnackBar(
        content: Text('"${file.name}" is ${_fmtSize(file.size)} — max is ${_fmtSize(_maxUploadBytes)}.'),
        backgroundColor: crm.destructive,
      ));
      return;
    }

    if (!mounted) return;
    final titleCtrl = TextEditingController(text: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''));
    final periodCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? department;
    String? folderId;
    List<ReportFolder> folders = const [];
    final roles = <String>{};

    // Ensure the department list is loaded (for admins/managers who pick one).
    List<String> deptNames = const [];
    try {
      deptNames =
          (await ref.read(departmentsProvider.future)).map((d) => d.name).toList();
    } catch (_) {/* fall back to empty; lock path below still works */}
    if (!mounted) return;

    // A department user (not admin/manager) files under their OWN department —
    // pre-fill and lock it instead of showing an empty required dropdown.
    final session = ref.read(authSessionProvider);
    final fullAccess = session?.role == 'admin' || session?.role == 'manager';
    final myDept = ref.read(myDepartmentNameProvider);
    final lockDept = !fullAccess && myDept.isNotEmpty;
    if (lockDept) {
      department = myDept;
      try {
        folders = await ref.read(reportFoldersProvider(myDept).future);
      } catch (_) {/* folders optional */}
    }
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upload report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(_fileIcon(_extType(file.name)), size: 18, color: crm.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${file.name} · ${_fmtSize(file.size)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textSecondary))),
                  ]),
                  const SizedBox(height: 14),
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 10),
                  if (lockDept)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Department *',
                        helperText: 'Your department',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(department ?? '',
                                style: const TextStyle(fontSize: 15)),
                          ),
                          Icon(Icons.lock_outline, size: 15, color: crm.textSecondary),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: department,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Department *', border: OutlineInputBorder(), isDense: true),
                      items: deptNames.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (v) async {
                        setSheet(() {
                          department = v;
                          folderId = null;
                          folders = const [];
                        });
                        if (v != null) {
                          try {
                            final fs = await ref.read(reportFoldersProvider(v).future);
                            if (ctx.mounted && department == v) {
                              setSheet(() => folders = fs);
                            }
                          } catch (_) {/* folders optional */}
                        }
                      },
                    ),
                  if (department != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: folderId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Folder (optional)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('Unfiled')),
                              for (final f in folders)
                                DropdownMenuItem<String?>(
                                    value: f.id, child: Text(f.name)),
                            ],
                            onChanged: (v) => setSheet(() => folderId = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'New folder',
                          icon: Icon(Icons.create_new_folder_outlined, color: crm.primary),
                          onPressed: () async {
                            final name = await _promptFolderName('New folder in ${department!}');
                            if (name == null) return;
                            try {
                              final folder = await ref
                                  .read(companyReportServiceProvider)
                                  .createFolder(name, department: department!);
                              ref.invalidate(reportFoldersProvider(department!));
                              if (ctx.mounted) {
                                setSheet(() {
                                  folders = [...folders, folder];
                                  folderId = folder.id;
                                });
                              }
                            } catch (e) {
                              messenger.showSnackBar(SnackBar(content: Text(_err(e))));
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(controller: periodCtrl, decoration: const InputDecoration(labelText: 'Period (e.g. Aug 2026)', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 10),
                  TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 14),
                  Text('Also visible to roles (optional)', style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: _roleOptions.map((role) {
                      final on = roles.contains(role);
                      return FilterChip(
                        label: Text(role),
                        selected: on,
                        onSelected: (v) => setSheet(() => v ? roles.add(role) : roles.remove(role)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (titleCtrl.text.trim().isEmpty) {
                                messenger.showSnackBar(const SnackBar(content: Text('Enter a title')));
                                return;
                              }
                              if (department == null) {
                                messenger.showSnackBar(const SnackBar(content: Text('Choose a department')));
                                return;
                              }
                              setSheet(() => busy = true);
                              try {
                                await ref.read(companyReportServiceProvider).upload(
                                      title: titleCtrl.text.trim(),
                                      department: department!,
                                      description: descCtrl.text.trim(),
                                      period: periodCtrl.text.trim(),
                                      filePath: file.path,
                                      bytes: file.bytes,
                                      filename: file.name,
                                      visibleToRoles: roles.toList(),
                                      folderId: folderId,
                                    );
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                setSheet(() => busy = false);
                                messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                              }
                            },
                      child: Text(busy ? 'Uploading…' : 'Upload'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (saved == true) {
      ref.invalidate(companyReportsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Report uploaded')));
    }
  }

  String _extType(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return 'pdf';
    if (ext.startsWith('xls')) return 'excel';
    if (ext == 'csv') return 'csv';
    if (['doc', 'docx'].contains(ext)) return 'word';
    if (['png', 'jpg', 'jpeg', 'webp'].contains(ext)) return 'image';
    return 'other';
  }
}
