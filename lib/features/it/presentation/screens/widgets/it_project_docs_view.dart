import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/it/domain/models/project_doc_model.dart';
import 'package:nizan_crm/features/it/services/project_doc_service.dart';
import 'package:nizan_crm/features/it/presentation/controllers/project_doc_notifier.dart';

const _docMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
const _maxUploadBytes = 25 * 1024 * 1024; // 25 MB per file

/// The project "Docs" tab: versioned documents (SRS, design, API spec…), each
/// version bundling a PDF and/or an editable DOC. Managers add/upload/delete;
/// any IT staff can download.
class ITProjectDocsView extends ConsumerWidget {
  const ITProjectDocsView({super.key, required this.projectId, this.projectName = ''});
  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isManager = Access.of(ref.watch(authSessionProvider)).isITManager;
    final async = ref.watch(projectDocsNotifierProvider(projectId));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
        child: Row(children: [
          Text('Project Documents', style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(width: 8),
          Icon(Icons.history_toggle_off, size: 15, color: crm.textSecondary),
          Flexible(
            child: Text('  version-managed', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ),
          const Spacer(),
          if (isManager)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: crm.primary),
              onPressed: () => _addDocument(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add document'),
            ),
        ]),
      ),
      Expanded(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.read(projectDocsNotifierProvider(projectId).notifier).refresh(),
                child: const Text('Retry'),
              ),
            ]),
          ),
          data: (docs) => docs.isEmpty
              ? _empty(crm, context, ref, isManager)
              : RefreshIndicator(
                  onRefresh: () => ref.read(projectDocsNotifierProvider(projectId).notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 40),
                    children: [for (final d in docs) _docCard(context, ref, crm, d, isManager)],
                  ),
                ),
        ),
      ),
    ]);
  }

  Widget _empty(CrmTheme crm, BuildContext context, WidgetRef ref, bool isManager) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.folder_copy_outlined, size: 50, color: crm.textSecondary),
          const SizedBox(height: 10),
          Text('No documents yet', style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Add an SRS, design doc or API spec and keep every version here.',
              textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
          if (isManager) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: crm.primary),
              onPressed: () => _addDocument(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add document'),
            ),
          ],
        ]),
      );

  Widget _docCard(BuildContext context, WidgetRef ref, CrmTheme crm, ProjectDocModel d, bool isManager) {
    final latest = d.latest;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: d.docType.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(d.docType.icon, size: 18, color: d.docType.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  _pill(d.docType.label, d.docType.color),
                  const SizedBox(width: 6),
                  Text(
                    latest == null ? 'No versions' : 'Latest v${latest.version} · ${_fmtDate(latest.uploadedAt)}',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  ),
                ]),
              ]),
            ),
            if (isManager)
              PopupMenuButton<String>(
                iconSize: 20,
                onSelected: (v) {
                  switch (v) {
                    case 'upload':
                      _uploadVersion(context, ref, d);
                    case 'edit':
                      _addDocument(context, ref, existing: d);
                    case 'delete':
                      _deleteDoc(context, ref, d);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'upload', child: Text('Upload new version')),
                  PopupMenuItem(value: 'edit', child: Text('Edit details')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'delete', child: Text('Delete document')),
                ],
              ),
          ]),
          if (d.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Text(d.description, style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.3)),
            ),
          const SizedBox(height: 10),
          if (d.versions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: Row(children: [
                Text('No versions uploaded yet.', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                const Spacer(),
                if (isManager)
                  TextButton.icon(
                    onPressed: () => _uploadVersion(context, ref, d),
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Upload first version'),
                  ),
              ]),
            )
          else
            for (final v in d.versions) _versionRow(context, ref, crm, d, v, isManager),
        ]),
      ),
    );
  }

  Widget _versionRow(BuildContext context, WidgetRef ref, CrmTheme crm, ProjectDocModel d, ProjectDocVersion v, bool isManager) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
            child: Text('v${v.version}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.primary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_fmtDate(v.uploadedAt)}${v.uploadedByName.isEmpty ? '' : ' · ${v.uploadedByName}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
            ),
          ),
          if (isManager)
            IconButton(
              tooltip: 'Delete version',
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              onPressed: () => _deleteVersion(context, ref, d, v),
              icon: Icon(Icons.delete_outline, color: crm.textSecondary),
            ),
        ]),
        if (v.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text(v.notes, style: TextStyle(fontSize: 12, color: crm.textSecondary, fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (v.hasPdf) ...[
            _fileButton('View PDF', Icons.visibility_outlined, Colors.red.shade700, () => _openPdf(context, ref, d, v)),
            _fileButton('PDF', Icons.download_outlined, Colors.red.shade700, () => _download(context, ref, d, v, 'pdf')),
          ],
          if (v.hasDoc) _fileButton('DOC', Icons.download_outlined, Colors.blue.shade700, () => _download(context, ref, d, v, 'doc')),
        ]),
      ]),
    );
  }

  Widget _fileButton(String label, IconData icon, Color color, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15, color: color),
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _download(BuildContext context, WidgetRef ref, ProjectDocModel d, ProjectDocVersion v, String fmt) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Preparing download…'), duration: Duration(milliseconds: 900)));
    try {
      final bytes = await ref.read(projectDocServiceProvider).downloadBytes(d.id, v.version, fmt);
      final fallback = '${d.title.replaceAll(RegExp(r'[^\w.-]+'), '_')}_v${v.version}.${fmt == 'doc' ? 'docx' : 'pdf'}';
      final name = fmt == 'doc' ? (v.docName.isNotEmpty ? v.docName : fallback) : (v.pdfName.isNotEmpty ? v.pdfName : fallback);
      await saveFileBytes(name, bytes, mime: fmt == 'doc' ? _docMime : 'application/pdf');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _openPdf(BuildContext context, WidgetRef ref, ProjectDocModel d, ProjectDocVersion v) async {
    final messenger = ScaffoldMessenger.of(context);
    final token = ref.read(authSessionProvider)?.token ?? '';
    final url = '$apiBaseUrl/project-docs/${d.id}/versions/${v.version}/download?fmt=pdf&inline=1&token=$token';
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open the PDF')));
    }
  }

  Future<void> _deleteDoc(BuildContext context, WidgetRef ref, ProjectDocModel d) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${d.title}"?'),
        content: Text('The document and all ${d.versions.length} version(s) and their files will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(projectDocsNotifierProvider(projectId).notifier).deleteDoc(d.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _deleteVersion(BuildContext context, WidgetRef ref, ProjectDocModel d, ProjectDocVersion v) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete v${v.version}?'),
        content: const Text('This version and its files will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(projectDocsNotifierProvider(projectId).notifier).deleteVersion(d.id, v.version);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  /// Create (or edit) a document's metadata. On create, chains into the upload
  /// sheet so the first version can be attached immediately.
  Future<void> _addDocument(BuildContext context, WidgetRef ref, {ProjectDocModel? existing}) async {
    final isEdit = existing != null;
    final title = TextEditingController(text: existing?.title ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    ProjectDocType type = existing?.docType ?? ProjectDocType.srs;
    final messenger = ScaffoldMessenger.of(context);

    final result = await showModalBottomSheet<ProjectDocModel?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEdit ? 'Edit document' : 'New document', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title * (e.g. SRS)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<ProjectDocType>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [for (final t in ProjectDocType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                  onChanged: (v) => setSheet(() => type = v ?? type),
                ),
                const SizedBox(height: 10),
                TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (title.text.trim().isEmpty) {
                              messenger.showSnackBar(const SnackBar(content: Text('Title is required')));
                              return;
                            }
                            setSheet(() => busy = true);
                            try {
                              final notifier = ref.read(projectDocsNotifierProvider(projectId).notifier);
                              final body = {'title': title.text.trim(), 'docType': type.slug, 'description': desc.text.trim()};
                              ProjectDocModel? created;
                              if (isEdit) {
                                await notifier.updateDoc(existing.id, body);
                              } else {
                                created = await notifier.addDoc(body);
                              }
                              if (ctx.mounted) Navigator.pop(ctx, created);
                            } catch (e) {
                              setSheet(() => busy = false);
                              messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                            }
                          },
                    child: Text(busy ? 'Saving…' : (isEdit ? 'Save' : 'Create & add files')),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
    // Newly created → immediately open the version-upload sheet.
    if (result != null && context.mounted) {
      await _uploadVersion(context, ref, result);
    }
  }

  /// Pick a PDF and/or DOC and upload as a new version.
  Future<void> _uploadVersion(BuildContext context, WidgetRef ref, ProjectDocModel d) async {
    final messenger = ScaffoldMessenger.of(context);
    PlatformFile? pdf;
    PlatformFile? doc;
    final notes = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> pick(bool isPdf) async {
              final res = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: isPdf ? ['pdf'] : ['doc', 'docx'],
                withData: true,
              );
              if (res == null) return;
              final f = res.files.single;
              if (f.size > _maxUploadBytes) {
                messenger.showSnackBar(const SnackBar(content: Text('File is over the 25 MB limit')));
                return;
              }
              setSheet(() => isPdf ? pdf = f : doc = f);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Upload new version', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${d.title} · v${(d.latest?.version ?? 0) + 1}', style: TextStyle(fontSize: 12.5, color: context.crmColors.textSecondary)),
                  const SizedBox(height: 16),
                  _slot(context, 'PDF', Icons.picture_as_pdf_outlined, Colors.red.shade700, pdf, () => pick(true), () => setSheet(() => pdf = null)),
                  const SizedBox(height: 10),
                  _slot(context, 'DOC / DOCX', Icons.description_outlined, Colors.blue.shade700, doc, () => pick(false), () => setSheet(() => doc = null)),
                  const SizedBox(height: 12),
                  TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Version notes (optional)')),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (pdf == null && doc == null) {
                                messenger.showSnackBar(const SnackBar(content: Text('Attach a PDF and/or a DOC file')));
                                return;
                              }
                              setSheet(() => busy = true);
                              try {
                                await ref.read(projectDocsNotifierProvider(projectId).notifier).uploadVersion(
                                      d.id,
                                      pdfBytes: pdf?.bytes,
                                      pdfPath: pdf?.path,
                                      pdfName: pdf?.name,
                                      docBytes: doc?.bytes,
                                      docPath: doc?.path,
                                      docName: doc?.name,
                                      notes: notes.text.trim(),
                                    );
                                if (ctx.mounted) Navigator.pop(ctx);
                                messenger.showSnackBar(const SnackBar(content: Text('Version uploaded')));
                              } catch (e) {
                                setSheet(() => busy = false);
                                messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                              }
                            },
                      child: Text(busy ? 'Uploading…' : 'Upload version'),
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _slot(BuildContext context, String label, IconData icon, Color color, PlatformFile? file, VoidCallback onPick, VoidCallback onClear) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: file == null
              ? Text(label, style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w600))
              : Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        if (file == null)
          TextButton(onPressed: onPick, child: const Text('Choose'))
        else
          IconButton(onPressed: onClear, iconSize: 18, icon: Icon(Icons.close, color: crm.textSecondary)),
      ]),
    );
  }

  String _fmtDate(DateTime? d) => d == null ? '—' : '${d.day}/${d.month}/${d.year}';
}
