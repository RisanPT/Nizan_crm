import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/my_department_provider.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_projects_screen.dart' show projectStatusColor, priorityColor;
import 'package:nizan_crm/features/it/presentation/screens/widgets/company_planning_dashboard.dart';

String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');

const _statusFilters = ['all', 'planning', 'active', 'on-hold', 'completed', 'cancelled'];

/// Company-wide, department-scoped project portfolio (outside IT). Reuses the
/// same Project system and detail screen; the server scopes what each user sees.
class CompanyProjectsScreen extends ConsumerStatefulWidget {
  const CompanyProjectsScreen({super.key});

  @override
  ConsumerState<CompanyProjectsScreen> createState() => _CompanyProjectsScreenState();
}

class _CompanyProjectsScreenState extends ConsumerState<CompanyProjectsScreen> {
  String _dept = 'all'; // department filter
  String _status = 'all';
  String _query = '';
  String? _mode; // 'dashboard' | 'portfolio' (leadership only; null → default)

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final access = Access.of(ref.watch(authSessionProvider));
    final canCreate = access.isFullAccess || access.isDepartmentHead;
    final isLeadership = access.isFullAccess || access.isDepartmentHead;
    final mode = isLeadership ? (_mode ?? 'dashboard') : 'portfolio';
    final depts = (ref.watch(departmentsProvider).value ?? const <Department>[])
        .where((d) => d.active)
        .toList();

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: (mode == 'portfolio' && canCreate)
          ? FloatingActionButton.extended(
              onPressed: () => _editProject(context, access, depts),
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
            Icon(Icons.hub_outlined, color: crm.primary),
            const SizedBox(width: 10),
            Text('Company Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
            const SizedBox(width: 10),
            Flexible(child: Text('planning across departments', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textSecondary))),
            const Spacer(),
            IconButton(onPressed: () => ref.invalidate(companyProjectsProvider), icon: const Icon(Icons.refresh)),
          ]),
        ),
        if (isLeadership)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'dashboard', label: Text('Dashboard'), icon: Icon(Icons.dashboard_outlined, size: 16)),
                  ButtonSegment(value: 'portfolio', label: Text('Portfolio'), icon: Icon(Icons.grid_view_outlined, size: 16)),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
          ),
        Expanded(
          child: mode == 'dashboard'
              ? CompanyPlanningDashboard(onOpenPortfolio: () => setState(() => _mode = 'portfolio'))
              : _portfolio(context, crm, access, depts),
        ),
      ]),
    );
  }

  Widget _portfolio(BuildContext context, CrmTheme crm, Access access, List<Department> depts) {
    final async = ref.watch(companyProjectsProvider(_dept == 'all' ? null : _dept));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary))),
      data: (projects) {
        final filtered = projects.where((p) {
          if (_status != 'all' && p.status != _status) return false;
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.managerName.toLowerCase().contains(q) ||
              p.targetDepartment.toLowerCase().contains(q);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(companyProjectsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _summary(crm, projects),
              const SizedBox(height: 12),
              _deptChips(crm, depts),
              const SizedBox(height: 12),
              _controls(crm),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(child: Text(
                    projects.isEmpty ? 'No projects visible to you yet.' : 'No projects match your filters.',
                    style: TextStyle(color: crm.textSecondary),
                  )),
                )
              else
                LayoutBuilder(builder: (ctx, c) {
                  final cols = (c.maxWidth / 420).floor().clamp(1, 3);
                  const gap = 14.0;
                  final cardW = cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * gap) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [for (final p in filtered) SizedBox(width: cardW, child: _card(context, crm, access, p, depts))],
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _summary(CrmTheme crm, List<Project> all) {
    final total = all.length;
    final active = all.where((p) => p.status == 'active').length;
    final depts = all.map((p) => p.targetDepartment).where((d) => d.isNotEmpty).toSet().length;
    final withTasks = all.where((p) => p.totalTasks > 0).toList();
    final avg = withTasks.isEmpty
        ? 0
        : (withTasks.map((p) => p.completedTasks / p.totalTasks).reduce((a, b) => a + b) / withTasks.length * 100).round();
    return Row(children: [
      _stat(crm, '$total', 'Projects', Icons.hub_outlined, crm.primary),
      const SizedBox(width: 10),
      _stat(crm, '$active', 'Active', Icons.play_circle_outline, const Color(0xFF2E8B57)),
      const SizedBox(width: 10),
      _stat(crm, '$depts', 'Departments', Icons.apartment_outlined, Colors.blue.shade600),
      const SizedBox(width: 10),
      _stat(crm, '$avg%', 'Avg progress', Icons.donut_large_outlined, Colors.orange.shade700),
    ]);
  }

  Widget _stat(CrmTheme crm, String value, String label, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, size: 15, color: color), const Spacer(), Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary))]),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _deptChips(CrmTheme crm, List<Department> depts) {
    final chips = <String>['all', ...depts.map((d) => d.name)];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final d in chips)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(d == 'all' ? 'All departments' : d),
              selected: _dept == d,
              onSelected: (_) => setState(() => _dept = d),
              showCheckmark: false,
              labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _dept == d ? Colors.white : crm.textSecondary),
              selectedColor: crm.primary,
              backgroundColor: crm.surface,
              side: BorderSide(color: _dept == d ? crm.primary : crm.border),
            ),
          ),
      ]),
    );
  }

  Widget _controls(CrmTheme crm) => Column(children: [
        TextField(
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search projects, managers, departments…',
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
                  label: Text(s == 'all' ? 'Any status' : _titleCase(s)),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                  showCheckmark: false,
                  labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _status == s ? Colors.white : crm.textSecondary),
                  selectedColor: crm.primary,
                  backgroundColor: crm.surface,
                  side: BorderSide(color: _status == s ? crm.primary : crm.border),
                ),
              ),
          ]),
        ),
      ]);

  Widget _card(BuildContext context, CrmTheme crm, Access access, Project p, List<Department> depts) {
    final pct = p.totalTasks == 0 ? 0.0 : p.completedTasks / p.totalTasks;
    final canManage = access.isFullAccess || (access.isDepartmentHead && ref.read(myDepartmentNameProvider).toLowerCase().trim() == p.targetDepartment.toLowerCase().trim());
    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/projects/${p.id}'),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(p.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (canManage)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  onSelected: (v) {
                    if (v == 'open') context.go('/projects/${p.id}');
                    if (v == 'edit') _editProject(context, access, depts, existing: p);
                    if (v == 'delete') _deleteProject(context, p);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'open', child: Text('Open')),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                )
              else
                IconButton(iconSize: 18, onPressed: () => context.go('/projects/${p.id}'), icon: Icon(Icons.chevron_right, color: crm.textSecondary)),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                _chip(p.targetDepartment.isEmpty ? 'Unassigned dept' : p.targetDepartment, crm.primary),
                _chip(_titleCase(p.status), projectStatusColor(p.status)),
                _chip(_titleCase(p.priority), priorityColor(p.priority)),
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
                  child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: crm.background, valueColor: AlwaysStoppedAnimation(pct >= 1 ? const Color(0xFF2E8B57) : crm.primary)),
                ),
              ),
              const SizedBox(width: 10),
              Text('${(pct * 100).round()}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              const SizedBox(width: 8),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.person_outline, size: 14, color: crm.textSecondary),
              const SizedBox(width: 5),
              Expanded(child: Text(p.managerName.isEmpty ? 'Unassigned' : p.managerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textSecondary))),
              Text('${p.completedTasks}/${p.totalTasks} tasks', style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
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

  Future<void> _deleteProject(BuildContext context, Project p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${p.name}"?'),
        content: const Text('The project and all its tasks will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(projectServiceProvider).deleteProject(p.id);
      ref.invalidate(companyProjectsProvider);
      ref.invalidate(projectsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Project deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _editProject(BuildContext context, Access access, List<Department> depts, {Project? existing}) async {
    final isEdit = existing != null;
    final myDept = ref.read(myDepartmentNameProvider);
    final deptNames = depts.map((d) => d.name).toList();
    final lockDept = !access.isFullAccess; // department heads create only for their own dept

    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    String? managerId = (existing?.managerId.isEmpty ?? true) ? null : existing!.managerId;
    final selectedMembers = <String>{...(existing?.memberIds ?? const [])};
    String department = existing?.targetDepartment.isNotEmpty == true
        ? existing!.targetDepartment
        : (lockDept && myDept.isNotEmpty ? myDept : (_dept != 'all' ? _dept : (deptNames.isNotEmpty ? deptNames.first : 'General')));
    String status = existing?.status ?? 'planning';
    String priority = existing?.priority ?? 'medium';
    String phase = existing?.phase ?? 'discovery';
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final employees = ref.read(departmentEmployeesProvider(department));
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEdit ? 'Edit project' : 'New project', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Project name *')),
                  const SizedBox(height: 10),
                  TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 10),
                  // Department
                  DropdownButtonFormField<String>(
                    initialValue: deptNames.contains(department) ? department : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Department *'),
                    items: [
                      if (!deptNames.contains(department)) DropdownMenuItem(value: department, child: Text(department)),
                      for (final d in deptNames) DropdownMenuItem(value: d, child: Text(d)),
                    ],
                    onChanged: lockDept
                        ? null
                        : (v) => setSheet(() {
                              department = v ?? department;
                              // reset assignee if not in the new department's list
                              final ids = ref.read(departmentEmployeesProvider(department)).map((e) => e.id).toSet();
                              if (managerId != null && !ids.contains(managerId)) managerId = null;
                              selectedMembers.removeWhere((m) => !ids.contains(m));
                            }),
                  ),
                  if (lockDept)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Department heads create projects for their own department.', style: TextStyle(fontSize: 11.5, color: context.crmColors.textSecondary)),
                    ),
                  const SizedBox(height: 10),
                  EmployeePickerField(
                    employees: employees,
                    selectedId: managerId,
                    selectedName: existing?.managerName,
                    label: 'Project Head / Manager *',
                    allowUnassign: false,
                    onChanged: (e) => setSheet(() => managerId = e?.id),
                  ),
                  if (employees.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('No active staff found for "$department". Pick another department or tag staff to it.',
                          style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800)),
                    ),
                  const SizedBox(height: 12),
                  Text('Team members', style: TextStyle(fontSize: 12.5, color: context.crmColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final e in employees)
                      FilterChip(
                        label: Text(e.name, style: const TextStyle(fontSize: 12)),
                        selected: selectedMembers.contains(e.id),
                        onSelected: (v) => setSheet(() => v ? selectedMembers.add(e.id) : selectedMembers.remove(e.id)),
                      ),
                  ]),
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
                                messenger.showSnackBar(const SnackBar(content: Text('Pick a project manager')));
                                return;
                              }
                              setSheet(() => busy = true);
                              try {
                                await ref.read(projectServiceProvider).saveProject({
                                  'name': name.text.trim(),
                                  'description': desc.text.trim(),
                                  'targetDepartment': department,
                                  'managerId': managerId,
                                  'members': selectedMembers.toList(),
                                  'status': status,
                                  'priority': priority,
                                  'phase': phase,
                                  'type': 'internal',
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
            );
          },
        );
      },
    );
    if (saved == true) {
      ref.invalidate(companyProjectsProvider);
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
