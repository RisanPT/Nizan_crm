import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';

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

const _statusFilters = ['all', 'planning', 'active', 'on-hold', 'completed', 'cancelled'];

class ITProjectsScreen extends ConsumerStatefulWidget {
  const ITProjectsScreen({super.key});

  @override
  ConsumerState<ITProjectsScreen> createState() => _ITProjectsScreenState();
}

class _ITProjectsScreenState extends ConsumerState<ITProjectsScreen> {
  String _status = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(itProjectsProvider);
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);
    final isManager = access.isITManager;

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => _editProject(context, ref),
              backgroundColor: crm.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
            )
          : null,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
          child: Row(children: [
            Icon(Icons.folder_special_outlined, color: crm.primary),
            const SizedBox(width: 10),
            Text('IT Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
            if (!isManager) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_ind, size: 13, color: Colors.blue),
                    SizedBox(width: 4),
                    Text('Assigned to You', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue)),
                  ],
                ),
              ),
            ],
            const Spacer(),
            IconButton(onPressed: () => ref.invalidate(itProjectsProvider), icon: const Icon(Icons.refresh)),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(itProjectsProvider)),
            data: (projects) {
              final filtered = projects.where((p) {
                if (_status != 'all' && p.status != _status) return false;
                if (_query.isEmpty) return true;
                final q = _query.toLowerCase();
                return p.name.toLowerCase().contains(q) ||
                    p.description.toLowerCase().contains(q) ||
                    p.managerName.toLowerCase().contains(q);
              }).toList();

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(itProjectsProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _summary(crm, projects),
                    const SizedBox(height: 14),
                    _controls(crm, projects),
                    const SizedBox(height: 14),
                    if (projects.isEmpty)
                      _emptyState(crm, context, ref, isManager)
                    else if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(child: Text('No projects match your filters.', style: TextStyle(color: crm.textSecondary))),
                      )
                    else
                      LayoutBuilder(builder: (ctx, c) {
                        final cols = (c.maxWidth / 420).floor().clamp(1, 3);
                        const gap = 14.0;
                        final cardW = cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * gap) / cols;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [for (final p in filtered) SizedBox(width: cardW, child: _projectCard(context, ref, crm, p, isManager))],
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ── Summary strip ────────────────────────────────────────────────────────────
  Widget _summary(CrmTheme crm, List<Project> all) {
    final total = all.length;
    final active = all.where((p) => p.status == 'active').length;
    final openTasks = all.fold<int>(0, (s, p) => s + (p.totalTasks - p.completedTasks));
    final withTasks = all.where((p) => p.totalTasks > 0).toList();
    final avg = withTasks.isEmpty
        ? 0
        : (withTasks.map((p) => p.completedTasks / p.totalTasks).reduce((a, b) => a + b) / withTasks.length * 100).round();

    return Row(children: [
      _stat(crm, '$total', 'Projects', Icons.folder_outlined, crm.primary),
      const SizedBox(width: 10),
      _stat(crm, '$active', 'Active', Icons.play_circle_outline, const Color(0xFF2E8B57)),
      const SizedBox(width: 10),
      _stat(crm, '$avg%', 'Avg progress', Icons.donut_large_outlined, Colors.blue.shade600),
      const SizedBox(width: 10),
      _stat(crm, '$openTasks', 'Open tasks', Icons.checklist_outlined, Colors.orange.shade700),
    ]);
  }

  Widget _stat(CrmTheme crm, String value, String label, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 15, color: color),
              const Spacer(),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary)),
            ]),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ── Search + status filters ──────────────────────────────────────────────────
  Widget _controls(CrmTheme crm, List<Project> all) {
    return Column(children: [
      TextField(
        onChanged: (v) => setState(() => _query = v.trim()),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search projects, managers…',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: crm.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.border)),
        ),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final s in _statusFilters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s == 'all' ? 'All' : _titleCase(s)),
                selected: _status == s,
                onSelected: (_) => setState(() => _status = s),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _status == s ? Colors.white : crm.textSecondary,
                ),
                selectedColor: crm.primary,
                backgroundColor: crm.surface,
                side: BorderSide(color: _status == s ? crm.primary : crm.border),
              ),
            ),
        ]),
      ),
    ]);
  }

  // ── Project card ─────────────────────────────────────────────────────────────
  Widget _projectCard(BuildContext context, WidgetRef ref, CrmTheme crm, Project p, bool isManager) {
    final pct = p.totalTasks == 0 ? 0.0 : p.completedTasks / p.totalTasks;
    final statusColor = projectStatusColor(p.status);
    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/it/projects/${p.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
            // Status accent stripe down the left edge.
            gradient: LinearGradient(
              colors: [statusColor.withValues(alpha: 0.10), crm.surface],
              stops: const [0.0, 0.02],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(p.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  onSelected: (v) {
                    if (v == 'open') context.go('/it/projects/${p.id}');
                    if (v == 'okr') context.go('/it/projects/${p.id}?tab=okr');
                    if (v == 'edit') _editProject(context, ref, p);
                    if (v == 'delete') _deleteProject(context, ref, p);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'open', child: Text('Open Project')),
                    const PopupMenuItem(value: 'okr', child: Text("🎯 OKR's & KR's")),
                    if (isManager) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (isManager) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip(_titleCase(p.status), statusColor),
                  _chip(_titleCase(p.priority), priorityColor(p.priority)),
                  _outlineChip(crm, _titleCase(p.phase)),
                  InkWell(
                    onTap: () => context.go('/it/projects/${p.id}?tab=okr'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: crm.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: crm.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            "OKR's",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: crm.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
              if (p.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.3)),
                ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: crm.background,
                      valueColor: AlwaysStoppedAnimation(pct >= 1 ? const Color(0xFF2E8B57) : crm.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(pct * 100).round()}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                const SizedBox(width: 8),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _avatar(crm, p.managerName),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(p.managerName.isEmpty ? 'Unassigned' : p.managerName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ),
                if (p.memberNames.isNotEmpty) ...[
                  Tooltip(
                    message: 'Team: ${p.memberNames.join(', ')}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: crm.border.faded(0.4),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group, size: 11, color: crm.textSecondary),
                          const SizedBox(width: 3),
                          Text('${p.memberNames.length}', style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text('${p.completedTasks}/${p.totalTasks} tasks', style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _avatar(CrmTheme crm, String name) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    return CircleAvatar(
      radius: 11,
      backgroundColor: crm.primary.withValues(alpha: 0.12),
      child: Text(initials, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: crm.primary)),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _outlineChip(CrmTheme crm, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: crm.border)),
        child: Text(label, style: TextStyle(color: crm.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _emptyState(CrmTheme crm, BuildContext context, WidgetRef ref, bool isManager) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.folder_open_outlined, size: 52, color: crm.textSecondary),
            const SizedBox(height: 12),
            Text(
              isManager ? 'No projects yet' : 'No assigned projects',
              style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                isManager
                    ? 'Create a project, then plan it with the WBS & Gantt tabs.'
                    : 'You will see projects here once tasks or projects are assigned to you by the project manager.',
                style: TextStyle(color: crm.textSecondary, fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ),
            if (isManager) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: crm.primary),
                onPressed: () => _editProject(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Project'),
              ),
            ],
          ]),
        ),
      );

  // ── Create / edit / delete ──────────────────────────────────────────────────
  Future<void> _deleteProject(BuildContext context, WidgetRef ref, Project p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${p.name}"?'),
        content: const Text('The project and all its tasks will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(projectServiceProvider).deleteProject(p.id);
      refreshAllItTaskViews(ref); // projects + their (now deleted) tasks
      ref.refreshData.okrs();
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
    final selectedMembers = Set<String>.from(existing?.memberIds ?? const []);
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
                EmployeePickerField(
                  employees: employees,
                  selectedId: managerId,
                  selectedName: existing?.managerName,
                  label: 'Project Head / Manager (IT) *',
                  allowUnassign: false,
                  onChanged: (e) => setSheet(() => managerId = e?.id),
                ),
                if (employees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'No IT-department employees found. Set a staff member\'s department (or category) to "IT" first.',
                      style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text('Assign Team Members:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (employees.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: employees.map((emp) {
                      final isSelected = selectedMembers.contains(emp.id);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(emp.name, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                        avatar: CircleAvatar(
                          radius: 10,
                          child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 10)),
                        ),
                        onSelected: (val) {
                          setSheet(() {
                            if (val) {
                              selectedMembers.add(emp.id);
                            } else {
                              selectedMembers.remove(emp.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
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
                                'members': selectedMembers.toList(),
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
      ref.refreshData.projects();
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
