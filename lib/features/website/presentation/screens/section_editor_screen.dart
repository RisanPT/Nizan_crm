import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/data/section_changes.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/data/website_pages.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';
import 'package:nizan_crm/features/website/presentation/studio/studio_shell.dart';
import 'package:nizan_crm/features/website/presentation/studio/studio_widgets.dart';
import 'package:nizan_crm/features/website/presentation/widgets/field_editor.dart';

const _pageNames = websitePageNames;
const _pageIcons = websitePageIcons;

/// Website Studio → edit one section. Save draft → Preview → Publish (goes live),
/// or Discard changes. Fields start from what the website shows now.
class SectionEditorScreen extends ConsumerWidget {
  final String sectionKey;
  const SectionEditorScreen({super.key, required this.sectionKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(websiteSchemaProvider);
    final sectionAsync = ref.watch(websiteSectionProvider(sectionKey));

    final Widget body = schemaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        error: e,
        onRetry: () => ref.invalidate(websiteSchemaProvider),
      ),
      data: (schema) {
        final sectionSchema = schema.sections[sectionKey];
        if (sectionSchema == null) {
          return AppErrorView(
            error: 'This website section does not exist.',
            onRetry: () => context.go('/website'),
          );
        }
        return sectionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(
            error: e,
            onRetry: () => ref.invalidate(websiteSectionProvider(sectionKey)),
          ),
          // Keyed by the loaded data so a reload (after publish/discard) resets the form.
          data: (detail) => _SectionForm(
            key: ValueKey(
              '${detail.key}-${detail.status}-${detail.draftUpdatedAt}-${detail.publishedAt}',
            ),
            schema: sectionSchema,
            detail: detail,
          ),
        );
      },
    );
    return StudioShell(current: 'section:$sectionKey', child: body);
  }
}

class _SectionForm extends ConsumerStatefulWidget {
  final SectionSchema schema;
  final SectionDetail detail;
  const _SectionForm({super.key, required this.schema, required this.detail});

  @override
  ConsumerState<_SectionForm> createState() => _SectionFormState();
}

class _SectionFormState extends ConsumerState<_SectionForm> {
  /// The form starts from what the section holds (draft, else live) with any
  /// empty field showing the website's current text — so staff change only the
  /// field they want and everything else stays exactly as visitors see it now.
  late final Map<String, dynamic> _start = _startingData(widget.detail);
  late final Map<String, dynamic> _data = (deepCopyJson(_start) as Map)
      .cast<String, dynamic>();
  // What the form looked like when opened / last saved — drives "Unsaved edits".
  late String _saved = jsonEncode(_start);
  // What the server's draft holds — Publish/Preview save first when the screen differs.
  late String _serverDraft = jsonEncode(widget.detail.draft);
  // What visitors see right now (live values over the website's own text).
  late final Map<String, dynamic> _liveNow = {
    ...widget.detail.defaults,
    ...?widget.detail.published,
  };
  bool _busy = false;
  List<String> _errors = const [];

  static bool _isEmpty(dynamic v) =>
      v == null ||
      v == '' ||
      (v is List && v.isEmpty) ||
      (v is Map && v.isEmpty);

  static Map<String, dynamic> _startingData(SectionDetail d) {
    final saved = d.draft.isNotEmpty
        ? d.draft
        : (d.published ?? const <String, dynamic>{});
    return {
      ...d.defaults,
      for (final e in saved.entries)
        if (!_isEmpty(e.value)) e.key: e.value,
    };
  }

  bool get _fromWebsiteText =>
      widget.detail.draft.isEmpty && widget.detail.published == null;
  bool get _dirty => jsonEncode(_data) != _saved;
  bool get _needsSave => jsonEncode(_data) != _serverDraft;
  String get _key => widget.schema.key;

  Future<void> _saveIfNeeded(WebsiteService svc) async {
    if (!_needsSave) return;
    await svc.saveDraft(_key, _data);
    _saved = _serverDraft = jsonEncode(_data);
  }

  void _refresh() {
    ref.invalidate(websiteSectionProvider(_key));
    ref.invalidate(websiteSectionsProvider);
  }

  Future<bool> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _errors = const [];
    });
    try {
      await action();
      if (mounted) showSuccessSnackBar(context, success);
      return true;
    } on WebsiteValidationException catch (e) {
      if (mounted) {
        setState(() => _errors = e.errors.isEmpty ? [e.message] : e.errors);
      }
      return false;
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDraft() async {
    final svc = ref.read(websiteServiceProvider);
    final ok = await _run(() async {
      await svc.saveDraft(_key, _data);
      _saved = _serverDraft = jsonEncode(_data);
    }, 'Draft saved. Not live yet — press Publish to show it on the website.');
    if (ok) _refresh();
  }

  Future<void> _publish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish to the website?'),
        content: Text(
          '"${widget.schema.label}" will change on the live website for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final svc = ref.read(websiteServiceProvider);
    final ok = await _run(() async {
      await _saveIfNeeded(svc); // publish exactly what is on screen
      await svc.publish(_key);
    }, 'Published. The website now shows these changes.');
    if (ok) _refresh();
  }

  /// Opens the website with saved drafts (unsaved edits are saved first).
  Future<void> _preview() async {
    final svc = ref.read(websiteServiceProvider);
    String? token;
    final ok = await _run(() async {
      await _saveIfNeeded(svc);
      token = await svc.getPreviewToken();
    }, 'Opening the preview in a new tab…');
    if (!ok || token == null) return;
    final url = Uri.parse(
      websiteBaseUrl,
    ).replace(queryParameters: {'preview': token});
    final opened = await launchUrl(url, webOnlyWindowName: '_blank');
    if (!opened && mounted) {
      showErrorSnackBar(context, 'Could not open the website.');
    }
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unpublished changes?'),
        content: const Text(
          'The draft goes back to what is live on the website now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _run(
      () => ref.read(websiteServiceProvider).revert(_key),
      'Changes discarded.',
    );
    if (ok) _refresh();
  }

  Widget _field(FieldDef def) => FieldEditor(
    def: def,
    value: _data[def.name],
    uploadSection: _key,
    onChanged: (v) => setState(() => _data[def.name] = v),
  );

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final d = widget.detail;
    final status = _dirty ? 'changed' : d.status;
    final canDiscard = d.published != null && (d.status == 'changed' || _dirty);

    final fields = widget.schema.fields.values.toList();
    final textFields = fields
        .where((f) => f.type != 'image' && f.type != 'list')
        .toList();
    final imageFields = fields.where((f) => f.type == 'image').toList();
    final listFields = fields.where((f) => f.type == 'list').toList();

    final form = <Widget>[
      if (_errors.isNotEmpty) ...[
        StudioCard(
          color: crm.destructive.withValues(alpha: 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please fix these first:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: crm.destructive,
                ),
              ),
              const SizedBox(height: 4),
              for (final e in _errors)
                Text('• $e', style: TextStyle(color: crm.destructive)),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      if (textFields.isNotEmpty) ...[
        StudioCard(
          title: 'Text',
          subtitle: 'Leave a box empty to keep what the website shows now.',
          child: Column(
            children: [
              for (final f in textFields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _field(f),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      if (imageFields.isNotEmpty) ...[
        StudioCard(
          title: imageFields.length == 1 ? 'Photo' : 'Photos',
          subtitle:
              'Not uploading keeps the website\'s current photo. Every upload is checked for size and shape.',
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final f in imageFields)
                SizedBox(width: 360, child: _field(f)),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      for (final f in listFields) ...[
        StudioCard(child: _field(f)),
        const SizedBox(height: 14),
      ],
    ];

    final changes = changedFieldLabels(widget.schema.fields, _data, _liveNow);
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    final side = <Widget>[
      StudioCard(
        title: 'Status',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(status: status),
            const SizedBox(height: 10),
            if (_fromWebsiteText)
              Text(
                'Showing the website\'s current text. Change only what you need, then press Publish.',
                style: TextStyle(fontSize: 13, color: crm.textPrimary),
              ),
            if (d.publishedAt != null)
              _InfoLine(
                icon: Icons.public,
                text:
                    'Live since ${fmt.format(d.publishedAt!)}${d.publishedBy != null ? ' · ${d.publishedBy}' : ''}',
              ),
            if (d.draftUpdatedAt != null)
              _InfoLine(
                icon: Icons.save_outlined,
                text:
                    'Draft saved ${fmt.format(d.draftUpdatedAt!)}${d.draftUpdatedBy != null ? ' · ${d.draftUpdatedBy}' : ''}',
              ),
            if (_dirty)
              _InfoLine(
                icon: Icons.circle,
                color: crm.warning,
                text: 'Unsaved edits',
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      StudioCard(
        title: 'Changes not yet on the website',
        child: changes.isEmpty
            ? Text(
                'None — this matches what visitors see.',
                style: TextStyle(fontSize: 13, color: crm.textSecondary),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 14, color: crm.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              c,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Press Publish to make ${changes.length == 1 ? 'it' : 'them'} live.',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 14),
      StudioCard(
        title: 'How it works',
        color: crm.secondary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _Step(
              n: '1',
              text: 'Edit the boxes. Nothing changes on the website yet.',
            ),
            _Step(
              n: '2',
              text: 'Preview opens the website with your edits, only for you.',
            ),
            _Step(n: '3', text: 'Publish puts them live for every visitor.'),
          ],
        ),
      ),
    ];

    final actions = <Widget>[
      if (canDiscard)
        TextButton(
          onPressed: _busy ? null : _discard,
          child: const Text('Discard changes'),
        ),
      OutlinedButton(
        onPressed: _busy || !_dirty ? null : _saveDraft,
        child: const Text('Save draft'),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _preview,
        icon: const Icon(Icons.visibility_outlined, size: 18),
        label: const Text('Preview'),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : _publish,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.public),
        label: const Text('Publish'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioPageHeader(
          icon: _pageIcons[widget.schema.page] ?? Icons.web_outlined,
          title: widget.schema.label,
          subtitle: _pageNames[widget.schema.page],
          badge: StatusPill(status: status),
          actions: actions,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 1100) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 10, 40),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 820),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: form,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 330,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(10, 20, 20, 40),
                        children: side,
                      ),
                    ),
                  ],
                );
              }
              return StudioBody(
                maxWidth: 820,
                children: [
                  ...side.take(3),
                  const SizedBox(height: 14),
                  ...form,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoLine({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: icon == Icons.circle ? 9 : 15,
            color: color ?? crm.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: color ?? crm.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: crm.primary,
            child: Text(
              n,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: crm.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
