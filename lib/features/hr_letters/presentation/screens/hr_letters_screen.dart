import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr_shared/hr_ui.dart';
import 'package:nizan_crm/features/hr_shared/hr_person_picker.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr_letters/data/letter_models.dart';
import 'package:nizan_crm/features/hr_letters/service/letter_service.dart';

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

/// HR Letters — manage letter templates (with {{placeholders}}) and generate
/// filled letters for employees (offer, experience, salary certificate, …).
class HrLettersScreen extends ConsumerWidget {
  const HrLettersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: crm.background,
        body: Column(
          children: [
            Material(
              color: crm.surface,
              child: TabBar(
                labelColor: crm.primary,
                unselectedLabelColor: crm.textSecondary,
                indicatorColor: crm.primary,
                tabs: const [Tab(text: 'Templates'), Tab(text: 'Generated')],
              ),
            ),
            Expanded(child: TabBarView(children: [_TemplatesTab(crm: crm), _GeneratedTab(crm: crm)])),
          ],
        ),
      ),
    );
  }
}

class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(letterTemplatesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Template'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(letterTemplatesProvider),
        child: templates.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(letterTemplatesProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No templates yet.', style: TextStyle(color: crm.textSecondary))))])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: list.map((t) => _row(context, ref, t)).toList()),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, LetterTemplate t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: crm.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text(letterTypeLabel(t.type), style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: crm.textSecondary), onPressed: () => _edit(context, ref, t)),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: crm.textSecondary),
            onPressed: () async {
              try {
                await ref.read(letterServiceProvider).deleteTemplate(t.id);
                ref.invalidate(letterTemplatesProvider);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, LetterTemplate? existing) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _TemplateEditor(existing: existing));
    if (ok == true) ref.invalidate(letterTemplatesProvider);
  }
}

class _TemplateEditor extends ConsumerStatefulWidget {
  const _TemplateEditor({this.existing});
  final LetterTemplate? existing;
  @override
  ConsumerState<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends ConsumerState<_TemplateEditor> {
  late final TextEditingController _name;
  late final TextEditingController _body;
  String _type = 'other';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _body = TextEditingController(
      text: e?.body ??
          'Date: {{date}}\n\nThis is to certify that {{name}} ({{designation}}, {{department}}) is employed with {{company}}.\n\nRegards,\nHR — {{company}}',
    );
    _type = e?.type ?? 'other';
  }

  @override
  void dispose() {
    _name.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(letterServiceProvider).saveTemplate(
        {'name': _name.text.trim(), 'type': _type, 'body': _body.text},
        id: widget.existing?.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return AlertDialog(
      title: Text(widget.existing == null ? 'New template' : 'Edit template'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Template name')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type'),
                items: kLetterTypes.map((t) => DropdownMenuItem(value: t, child: Text(letterTypeLabel(t)))).toList(),
                onChanged: (v) => setState(() => _type = v ?? 'other'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(labelText: 'Body', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 6),
              Text('Placeholders: {{name}} {{designation}} {{department}} {{salary}} {{date}} {{joiningDate}} {{company}}',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}

class _GeneratedTab extends ConsumerWidget {
  const _GeneratedTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letters = ref.watch(generatedLettersProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _generate(context, ref),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(generatedLettersProvider),
        child: letters.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(generatedLettersProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No letters generated yet.', style: TextStyle(color: crm.textSecondary))))])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: list.map((g) => _row(context, ref, g)).toList()),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, GeneratedLetter g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${g.employeeName} · ${letterTypeLabel(g.type)}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text('${g.issuedByName.isNotEmpty ? '${g.issuedByName} · ' : ''}${_fmt(g.createdAt)}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.visibility_outlined, size: 18, color: crm.textSecondary), onPressed: () => _view(context, g)),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: crm.textSecondary),
            onPressed: () async {
              try {
                await ref.read(letterServiceProvider).deleteGenerated(g.id);
                ref.invalidate(generatedLettersProvider);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
              }
            },
          ),
        ],
      ),
    );
  }

  void _view(BuildContext context, GeneratedLetter g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${letterTypeLabel(g.type)} — ${g.employeeName}'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: SelectableText(g.body))),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: g.body));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
            },
            child: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _GenerateDialog());
    if (ok == true) {
      ref.invalidate(generatedLettersProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Letter generated')));
    }
  }
}

class _GenerateDialog extends ConsumerStatefulWidget {
  const _GenerateDialog();
  @override
  ConsumerState<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends ConsumerState<_GenerateDialog> {
  String? _templateId;
  String? _employeeId;
  final _subject = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_templateId == null || _employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a template and an employee')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(letterServiceProvider).generate(
            employeeId: _employeeId!,
            templateId: _templateId,
            subject: _subject.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(letterTemplatesProvider);
    final employees = ref.watch(employeesProvider);
    return AlertDialog(
      title: const Text('Generate letter'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            templates.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyErrorMessage(e)),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _templateId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Template'),
                items: list.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => _templateId = v),
              ),
            ),
            const SizedBox(height: 10),
            employees.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyErrorMessage(e)),
              data: (list) {
                final active = list.where((e) => e.status == 'active').toList();
                return PersonPickerField(
                  label: 'Employee',
                  icon: Icons.person_outline,
                  selectedId: _employeeId,
                  items: active.map((e) => PickerItem(id: e.id, name: e.name, department: e.department ?? '')).toList(),
                  onChanged: (v) => setState(() => _employeeId = v),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject (optional)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Generate'),
        ),
      ],
    );
  }
}
