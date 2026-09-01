import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_projects_screen.dart' show priorityColor;

Color _statusColor(String s) => switch (s) {
      'in-progress' => Colors.blue.shade600,
      'review' => Colors.amber.shade700,
      'completed' => const Color(0xFF2E8B57),
      _ => Colors.blueGrey,
    };

Color _categoryColor(String c) => switch (c) {
      'bug' => Colors.red.shade600,
      'maintenance' => Colors.amber.shade700,
      'research' => Colors.purple,
      _ => Colors.blue.shade600, // feature
    };

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');

class ITBoardScreen extends ConsumerWidget {
  const ITBoardScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(tasksProvider(projectId));
    final projectName = ref.watch(projectsProvider).maybeWhen(
          data: (list) => list.where((p) => p.id == projectId).map((p) => p.name).firstOrNull ?? 'Task Board',
          orElse: () => 'Task Board',
        );

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
          decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
          child: Row(children: [
            IconButton(onPressed: () => context.go('/it/projects'), icon: const Icon(Icons.arrow_back)),
            Expanded(
              child: Text(projectName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            IconButton(onPressed: () => ref.invalidate(tasksProvider(projectId)), icon: const Icon(Icons.refresh)),
            const SizedBox(width: 6),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: crm.primary),
              onPressed: () => _editTask(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add task'),
            ),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary))),
            data: (tasks) => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              children: [
                for (final status in itTaskStatuses)
                  _column(context, ref, crm, status, tasks.where((t) => t.status == status).toList()),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _column(BuildContext context, WidgetRef ref, CrmTheme crm, String status, List<ITTask> tasks) {
    final color = _statusColor(status);
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: crm.border)),
          ),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 8),
            Text(itStatusLabel(status), style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Text('${tasks.length}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        Expanded(
          child: tasks.isEmpty
              ? Center(child: Text('No tasks', style: TextStyle(color: crm.textSecondary, fontSize: 12)))
              : ListView(
                  padding: const EdgeInsets.all(10),
                  children: [for (final t in tasks) _taskCard(context, ref, crm, t)],
                ),
        ),
      ]),
    );
  }

  Widget _taskCard(BuildContext context, WidgetRef ref, CrmTheme crm, ITTask t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
          SizedBox(
            height: 26,
            width: 26,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 18,
              onSelected: (v) {
                if (v == 'edit') {
                  _editTask(context, ref, t);
                } else if (v == 'delete') {
                  _deleteTask(context, ref, t);
                } else {
                  _move(context, ref, t, v);
                }
              },
              itemBuilder: (_) => [
                for (final s in itTaskStatuses)
                  if (s != t.status) PopupMenuItem(value: s, child: Text('Move to ${itStatusLabel(s)}')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ]),
        if (t.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _tag(_cap(t.priority), priorityColor(t.priority)),
          _tag(_cap(t.category), _categoryColor(t.category)),
          if (t.deadline != null) _tag('${t.deadline!.day}/${t.deadline!.month}', crm.textSecondary),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.person_outline, size: 13, color: crm.textSecondary),
          const SizedBox(width: 4),
          Expanded(child: Text(t.assignedToName.isEmpty ? 'Unassigned' : t.assignedToName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary))),
        ]),
      ]),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );

  Future<void> _move(BuildContext context, WidgetRef ref, ITTask t, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(itTaskServiceProvider).updateTask(t.id, {'status': status});
      ref.invalidate(tasksProvider(projectId));
      ref.invalidate(projectsProvider); // task counts changed
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref, ITTask t) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(itTaskServiceProvider).deleteTask(t.id);
      ref.invalidate(tasksProvider(projectId));
      ref.invalidate(projectsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _editTask(BuildContext context, WidgetRef ref, [ITTask? existing]) async {
    final employees = ref.read(itEmployeesProvider);
    final title = TextEditingController(text: existing?.title ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final hours = TextEditingController(text: existing == null || existing.estimatedHours == 0 ? '' : existing.estimatedHours.toStringAsFixed(0));
    String? assignee = existing?.assignedToId.isEmpty ?? true ? null : existing!.assignedToId;
    String priority = existing?.priority ?? 'medium';
    String category = existing?.category ?? 'feature';
    String status = existing?.status ?? 'todo';
    DateTime? deadline = existing?.deadline;
    final messenger = ScaffoldMessenger.of(context);
    final isEdit = existing != null;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEdit ? 'Edit task' : 'New task', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title *')),
                const SizedBox(height: 10),
                TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                EmployeePickerField(
                  employees: employees,
                  selectedId: assignee,
                  selectedName: existing?.assignedToName,
                  label: 'Assignee *',
                  allowUnassign: false,
                  onChanged: (e) => setSheet(() => assignee = e?.id),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _dd('Priority', priority, const ['low', 'medium', 'high', 'critical'], (v) => setSheet(() => priority = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _dd('Category', category, const ['feature', 'bug', 'maintenance', 'research'], (v) => setSheet(() => category = v))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _dd('Status', status, itTaskStatuses, (v) => setSheet(() => status = v), labeler: itStatusLabel)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(controller: hours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Est. hours')),
                  ),
                ]),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: deadline ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (d != null) setSheet(() => deadline = d);
                  },
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(deadline == null ? 'Set deadline' : 'Deadline: ${deadline!.day}/${deadline!.month}/${deadline!.year}'),
                ),
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
                            if (assignee == null) {
                              messenger.showSnackBar(const SnackBar(content: Text('Pick an assignee')));
                              return;
                            }
                            setSheet(() => busy = true);
                            final body = {
                              'projectId': projectId,
                              'title': title.text.trim(),
                              'description': desc.text.trim(),
                              'assignedTo': assignee,
                              'priority': priority,
                              'category': category,
                              'status': status,
                              'estimatedHours': double.tryParse(hours.text.trim()) ?? 0,
                              if (deadline != null) 'deadline': deadline!.toIso8601String(),
                            };
                            try {
                              final svc = ref.read(itTaskServiceProvider);
                              if (isEdit) {
                                await svc.updateTask(existing.id, body);
                              } else {
                                await svc.createTask(body);
                              }
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheet(() => busy = false);
                              messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                            }
                          },
                    child: Text(busy ? 'Saving…' : (isEdit ? 'Save task' : 'Create task')),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
    if (saved == true) {
      ref.invalidate(tasksProvider(projectId));
      ref.invalidate(projectsProvider);
      messenger.showSnackBar(SnackBar(content: Text(isEdit ? 'Task updated' : 'Task created')));
    }
  }

  Widget _dd(String label, String value, List<String> options, ValueChanged<String> onChanged, {String Function(String)? labeler}) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final o in options) DropdownMenuItem(value: o, child: Text(labeler?.call(o) ?? _cap(o)))],
        onChanged: (v) => onChanged(v ?? value),
      );
}
