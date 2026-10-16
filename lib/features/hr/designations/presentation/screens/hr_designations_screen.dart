import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/features/hr/designations/data/designation_models.dart';
import 'package:nizan_crm/features/hr/designations/service/designation_service.dart';

/// HR Designations — CRUD for job titles. Optional department scoping and a
/// `level` (grade) used by the org-hierarchy view.
class HrDesignationsScreen extends ConsumerWidget {
  const HrDesignationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final items = ref.watch(designationsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Designation'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(designationsProvider),
        child: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(designationsProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                        child: Text('No designations yet. Add your first job title.',
                            style: TextStyle(color: crm.textSecondary))),
                  )
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: list.map((d) => _row(context, ref, d, crm)).toList(),
                ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Designation d, CrmTheme crm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: crm.primary.withValues(alpha: 0.12),
            child: Text('${d.level}', style: TextStyle(color: crm.primary, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text(
                  [
                    if (d.code.isNotEmpty) d.code,
                    if (d.departmentName.isNotEmpty) d.departmentName,
                    'Level ${d.level}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: crm.textSecondary),
            onPressed: () => _openEditor(context, ref, d),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: crm.textSecondary),
            onPressed: () => _confirmDelete(context, ref, d),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Designation d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete designation'),
        content: Text('Remove "${d.name}"? Employees currently assigned to it will block this.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(designationServiceProvider).remove(d.id);
      ref.invalidate(designationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, Designation? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _DesignationEditor(existing: existing),
    );
    if (saved == true) ref.invalidate(designationsProvider);
  }
}

class _DesignationEditor extends ConsumerStatefulWidget {
  const _DesignationEditor({this.existing});
  final Designation? existing;
  @override
  ConsumerState<_DesignationEditor> createState() => _DesignationEditorState();
}

class _DesignationEditorState extends ConsumerState<_DesignationEditor> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _desc;
  late int _level;
  String? _departmentId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _code = TextEditingController(text: e?.code ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _level = e?.level ?? 1;
    _departmentId = (e?.departmentId.isNotEmpty ?? false) ? e!.departmentId : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _busy = true);
    try {
      final svc = ref.read(designationServiceProvider);
      if (widget.existing == null) {
        await svc.create(
          name: _name.text.trim(),
          code: _code.text.trim(),
          departmentId: _departmentId,
          level: _level,
          description: _desc.text.trim(),
        );
      } else {
        await svc.update(widget.existing!.id, {
          'name': _name.text.trim(),
          'code': _code.text.trim(),
          'departmentId': _departmentId ?? '',
          'level': _level,
          'description': _desc.text.trim(),
        });
      }
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
    final depts = ref.watch(departmentsProvider);
    return AlertDialog(
      title: Text(widget.existing == null ? 'New designation' : 'Edit designation'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code (optional)')),
              const SizedBox(height: 10),
              depts.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) => DropdownButtonFormField<String?>(
                  initialValue: _departmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Department (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— None —')),
                    ...list.map((d) => DropdownMenuItem<String?>(value: d.id, child: Text(d.name))),
                  ],
                  onChanged: (v) => setState(() => _departmentId = v),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('Level (grade)', style: TextStyle(color: context.crmColors.textSecondary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _level > 1 ? () => setState(() => _level -= 1) : null,
                  ),
                  Text('$_level', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _level < 20 ? () => setState(() => _level += 1) : null,
                  ),
                ],
              ),
              TextField(
                controller: _desc,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
