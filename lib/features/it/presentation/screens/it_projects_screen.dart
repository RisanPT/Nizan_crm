import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

Color projectStatusColor(String s) => switch (s) {
      'active' => const Color(0xFF2E8B57),
      'on-hold' => Colors.amber.shade700,
      'completed' => Colors.teal,
      'cancelled' => Colors.red.shade600,
      _ => Colors.blueGrey, // planning
    };

Color priorityColor(String p) => switch (p) {
      'critical' => Colors.red.shade600,
      'high' => Colors.orange.shade700,
      'medium' => Colors.blue.shade600,
      _ => Colors.grey,
    };

String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');

class ITProjectsScreen extends ConsumerWidget {
  const ITProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editProject(context, ref),
        backgroundColor: crm.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
          child: Row(children: [
            Icon(Icons.folder_special_outlined, color: crm.primary),
            const SizedBox(width: 10),
            Text('IT Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
            const Spacer(),
            IconButton(onPressed: () => ref.invalidate(projectsProvider), icon: const Icon(Icons.refresh)),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary))),
            data: (projects) => projects.isEmpty
                ? Center(child: Text('No projects yet. Create your first one.', style: TextStyle(color: crm.textSecondary)))
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(projectsProvider),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [for (final p in projects) _projectCard(context, ref, crm, p)],
                    ),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _projectCard(BuildContext context, WidgetRef ref, CrmTheme crm, Project p) {
    final pct = p.totalTasks == 0 ? 0.0 : p.completedTasks / p.totalTasks;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: crm.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/it/projects/${p.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              _chip(_titleCase(p.status), projectStatusColor(p.status)),
              const SizedBox(width: 6),
              _chip(_titleCase(p.priority), priorityColor(p.priority)),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editProject(context, ref, p);
                  if (v == 'delete') _deleteProject(context, ref, p);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ]),
            if (p.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 7,
                    backgroundColor: crm.border,
                    valueColor: AlwaysStoppedAnimation(crm.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${p.completedTasks}/${p.totalTasks} tasks', style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.person_outline, size: 14, color: crm.textSecondary),
              const SizedBox(width: 4),
              Text(p.managerName.isEmpty ? 'Unassigned' : p.managerName, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              const Spacer(),
              Text(_titleCase(p.phase), style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Future<void> _deleteProject(BuildContext context, WidgetRef ref, Project p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${p.name}"?'),
        content: const Text('The project and its tasks references will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(projectServiceProvider).deleteProject(p.id);
      ref.invalidate(projectsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Project deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _editProject(BuildContext context, WidgetRef ref, [Project? existing]) async {
    final employees = ref.read(itEmployeesProvider);
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    String? managerId = existing?.managerId.isEmpty ?? true ? null : existing!.managerId;
    String status = existing?.status ?? 'planning';
    String priority = existing?.priority ?? 'medium';
    String phase = existing?.phase ?? 'discovery';
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
                Text(isEdit ? 'Edit project' : 'New project', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Project name *')),
                const SizedBox(height: 10),
                TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: managerId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Manager (IT) *', prefixIcon: Icon(Icons.person_outline)),
                  items: [for (final e in employees) DropdownMenuItem(value: e.id, child: Text(e.name))],
                  onChanged: (v) => setSheet(() => managerId = v),
                ),
                if (employees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'No IT-department employees found. Set a staff member\'s department (or category) to "IT" first.',
                      style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _dd('Status', status, const ['planning', 'active', 'on-hold', 'completed', 'cancelled'], (v) => setSheet(() => status = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _dd('Priority', priority, const ['low', 'medium', 'high', 'critical'], (v) => setSheet(() => priority = v))),
                ]),
                const SizedBox(height: 10),
                _dd('Phase', phase, const ['discovery', 'design', 'development', 'testing', 'deployment', 'maintenance'], (v) => setSheet(() => phase = v)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (name.text.trim().isEmpty) {
                              messenger.showSnackBar(const SnackBar(content: Text('Project name is required')));
                              return;
                            }
                            if (managerId == null) {
                              messenger.showSnackBar(const SnackBar(content: Text('Pick a manager')));
                              return;
                            }
                            setSheet(() => busy = true);
                            try {
                              await ref.read(projectServiceProvider).saveProject({
                                'name': name.text.trim(),
                                'description': desc.text.trim(),
                                'managerId': managerId,
                                'status': status,
                                'priority': priority,
                                'phase': phase,
                                'targetDepartment': 'it',
                              }, id: existing?.id);
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheet(() => busy = false);
                              messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                            }
                          },
                    child: Text(busy ? 'Saving…' : (isEdit ? 'Save changes' : 'Create project')),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
    if (saved == true) {
      ref.invalidate(projectsProvider);
      messenger.showSnackBar(SnackBar(content: Text(isEdit ? 'Project updated' : 'Project created')));
    }
  }

  Widget _dd(String label, String value, List<String> options, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final o in options) DropdownMenuItem(value: o, child: Text(_titleCase(o)))],
        onChanged: (v) => onChanged(v ?? value),
      );
}
