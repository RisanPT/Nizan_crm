import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/features/it/domain/task_rights.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';

/// Opens the create/edit task sheet. Returns `true` when a task was saved.
Future<bool?> showTaskEditor(
  BuildContext context,
  WidgetRef ref,
  String projectId, {
  ITTaskModel? existing,
  String? defaultParentId,

  /// For a new task: the department it starts in (else its parent's, else the first the person may pick).
  String? defaultDepartment,
  List<ITTaskModel> allTasks = const [],
}) {
  final crm = context.crmColors;
  final isEdit = existing != null;

  // What this person may do here — the server applies the same rules.
  final project = ref.read(projectByIdProvider(projectId));
  final isItProject = (project?.targetDepartment ?? 'it').toLowerCase().trim() == 'it';
  final entityName = isItProject ? 'Ticket' : 'Task';
  final myEmployeeId = ref.read(authSessionProvider)?.employeeId ?? '';
  final rights = isEdit ? taskRightsFor(project, existing, myEmployeeId: myEmployeeId) : TaskRights.all;
  final access = project?.access;
  if (isEdit && rights.readOnly) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Only the project manager, a department lead, or the person it is assigned to can change this ${entityName.toLowerCase()}.'),
      ),
    );
    return Future.value(false);
  }
  if (!isEdit && access != null && !access.canCreateTasks) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('The project manager adds the ${isItProject ? 'tickets' : 'tasks'} on this project.')));
    return Future.value(false);
  }
  // An assignee on a managed project changes only how their ticket is going.
  final planLocked = isEdit && rights.progressOnly;

  // Departments a ticket can belong to: all of them for the manager, only the ones
  // they lead for a department lead. A single-department project has no choice to make.
  final crossDepartment = (project?.isCrossDepartment ?? false);
  final departmentChoices = !crossDepartment
      ? const <String>[]
      : (access == null || access.canManage || !access.isManaged)
      ? project!.departmentNames
      : project!.departmentNames.where((d) => access.leadDepartments.any((l) => l.toLowerCase() == d.toLowerCase())).toList();
  // a new sub-task starts in its parent's department, a new task in the one it was asked for
  final parentDepartment = allTasks.where((t) => t.id == defaultParentId).firstOrNull?.departmentName ?? '';
  final wantedDepartment = (defaultDepartment ?? '').trim().isNotEmpty ? defaultDepartment!.trim() : parentDepartment.trim();
  String departmentName = (existing?.departmentName.isNotEmpty ?? false)
      ? existing!.departmentName
      : (departmentChoices.any((d) => d.toLowerCase() == wantedDepartment.toLowerCase())
            ? departmentChoices.firstWhere((d) => d.toLowerCase() == wantedDepartment.toLowerCase())
            : (departmentChoices.isNotEmpty ? departmentChoices.first : ''));

  final forest = buildWbsForest(allTasks);
  final flat = flattenWbs(forest);
  final excluded = <String>{};
  if (isEdit) {
    excluded.add(existing.id);
    void banSubtree(WbsNode n) {
      excluded.add(n.task.id);
      for (final c in n.children) {
        banSubtree(c);
      }
    }

    for (final n in flat) {
      if (n.task.id == existing.id) banSubtree(n);
    }
  }
  final parentOptions = flat.where((n) => !excluded.contains(n.task.id)).toList();

  int nextOrder(String? parentId) {
    final sibs = allTasks.where((t) => (t.parentTaskId ?? '') == (parentId ?? ''));
    if (sibs.isEmpty) return 0;
    return sibs.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
  }

  final employees = ref.read(projectEmployeesProvider(projectId));
  final title = TextEditingController(text: existing?.title ?? '');
  final desc = TextEditingController(text: existing?.description ?? '');
  final hours = TextEditingController(text: existing == null || existing.estimatedHours == 0 ? '' : existing.estimatedHours.toStringAsFixed(0));
  String? assignee = (existing?.assigneeId.isEmpty ?? true) ? null : existing!.assigneeId;
  String? parentId = existing?.parentTaskId ?? defaultParentId;
  ITTicketType ticketType = existing?.ticketType ?? ITTicketType.feature;
  ITSeverity severity = existing?.severity ?? ITSeverity.p2;
  ITSubTeam subTeam = existing?.subTeam ?? ITSubTeam.general;
  ITTaskStatus status = existing?.status ?? ITTaskStatus.todo;
  DateTime? startDate = existing?.startDate;
  DateTime? deadline = existing?.dueDate;
  double percent = (existing?.percentComplete ?? 0).toDouble();
  final messenger = ScaffoldMessenger.of(context);
  Widget lock(Widget w) => planLocked ? IgnorePointer(child: Opacity(opacity: 0.55, child: w)) : w;

  return showModalBottomSheet<bool>(
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
                Text(isEdit ? 'Edit $entityName' : 'New $entityName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (planLocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'The project manager plans this ${entityName.toLowerCase()}. You can update its status and % complete.',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    ),
                  ),
                const SizedBox(height: 14),
                lock(
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                ),
                const SizedBox(height: 10),
                lock(
                  TextField(
                    controller: desc,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ),
                const SizedBox(height: 10),
                // Parent (WBS)
                lock(
                  DropdownButtonFormField<String?>(
                    initialValue: parentOptions.any((n) => n.task.id == parentId) ? parentId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Parent (leave as top-level for a phase)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None — top-level phase')),
                      for (final n in parentOptions)
                        DropdownMenuItem<String?>(
                          value: n.task.id,
                          child: Text('${n.wbs}  ${n.task.title}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setSheet(() => parentId = v),
                  ),
                ),
                const SizedBox(height: 10),
                if (departmentChoices.isNotEmpty) ...[
                  lock(
                    DropdownButtonFormField<String>(
                      initialValue: departmentChoices.contains(departmentName) ? departmentName : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Department *',
                        helperText: 'Which department does this ${entityName.toLowerCase()} belong to',
                      ),
                      items: [for (final d in departmentChoices) DropdownMenuItem(value: d, child: Text(d))],
                      onChanged: (v) => setSheet(() => departmentName = v ?? departmentName),
                    ),
                  ),
                  if (project?.invitedDepartments.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 13, color: crm.textSecondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Pending invites: ${project!.invitedDepartments.map((d) => d.name).join(', ')} (available once accepted)',
                            style: TextStyle(fontSize: 11, color: crm.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
                lock(
                  EmployeePickerField(
                    employees: employees,
                    selectedId: assignee,
                    selectedName: existing?.assigneeName,
                    label: 'Assignee (optional for phases)',
                    allowUnassign: true,
                    onChanged: (e) => setSheet(() => assignee = e?.id),
                  ),
                ),
                const SizedBox(height: 10),
                if (isItProject) ...[
                  Row(
                    children: [
                      Expanded(
                        child: lock(
                          DropdownButtonFormField<ITTicketType>(
                            initialValue: ticketType,
                            decoration: const InputDecoration(labelText: 'Ticket Type'),
                            items: [for (final t in ITTicketType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                            onChanged: (v) => setSheet(() => ticketType = v ?? ticketType),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: lock(
                          DropdownButtonFormField<ITSeverity>(
                            initialValue: severity,
                            decoration: const InputDecoration(labelText: 'Severity'),
                            items: [for (final s in ITSeverity.values) DropdownMenuItem(value: s, child: Text(s.label))],
                            onChanged: (v) => setSheet(() => severity = v ?? severity),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: lock(
                          DropdownButtonFormField<ITSubTeam>(
                            initialValue: subTeam,
                            decoration: const InputDecoration(labelText: 'Sub-Team'),
                            items: [for (final tm in ITSubTeam.values) DropdownMenuItem(value: tm, child: Text(tm.label))],
                            onChanged: (v) => setSheet(() => subTeam = v ?? subTeam),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<ITTaskStatus>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: [for (final st in ITTaskStatus.values) DropdownMenuItem(value: st, child: Text(st.label))],
                          onChanged: (v) => setSheet(() => status = v ?? status),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: lock(
                          DropdownButtonFormField<ITSeverity>(
                            initialValue: severity,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Priority'),
                            items: [
                              for (final s in ITSeverity.values)
                                DropdownMenuItem(value: s, child: Text(s.label.replaceAll(RegExp(r'^P\d\s*-\s*'), ''))),
                            ],
                            onChanged: (v) => setSheet(() => severity = v ?? severity),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<ITTaskStatus>(
                          initialValue: status,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: [
                            const DropdownMenuItem(value: ITTaskStatus.backlog, child: Text('Backlog')),
                            const DropdownMenuItem(value: ITTaskStatus.todo, child: Text('To Do')),
                            const DropdownMenuItem(value: ITTaskStatus.inProgress, child: Text('In Progress')),
                            const DropdownMenuItem(value: ITTaskStatus.codeReview, child: Text('In Review')),
                            if (status == ITTaskStatus.qaTesting)
                              const DropdownMenuItem(value: ITTaskStatus.qaTesting, child: Text('In Review (QA)')),
                            const DropdownMenuItem(value: ITTaskStatus.deployed, child: Text('Completed')),
                            if (status == ITTaskStatus.closed) const DropdownMenuItem(value: ITTaskStatus.closed, child: Text('Closed')),
                          ],
                          onChanged: (v) => setSheet(() => status = v ?? status),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                lock(
                  TextField(
                    controller: hours,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Est. hours'),
                  ),
                ),
                const SizedBox(height: 14),
                // Dates row
                lock(
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: crm.primary,
                                    onPrimary: Colors.white,
                                    onSurface: crm.textPrimary,
                                    surface: crm.surface,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (d != null) setSheet(() => startDate = d);
                          },
                          icon: const Icon(Icons.play_arrow_outlined, size: 18),
                          label: Text(startDate == null ? 'Start date' : 'Start: ${shortDate(startDate)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: deadline ?? startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: crm.primary,
                                    onPrimary: Colors.white,
                                    onSurface: crm.textPrimary,
                                    surface: crm.surface,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (d != null) setSheet(() => deadline = d);
                          },
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: Text(deadline == null ? 'Due date' : 'Due: ${shortDate(deadline)}'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // % complete
                Row(
                  children: [
                    const Text('% complete', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: percentFill(percent.round()), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${percent.round()}%',
                        style: TextStyle(color: percentText(percent.round()), fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                Slider(value: percent, min: 0, max: 100, divisions: 20, label: '${percent.round()}%', onChanged: (v) => setSheet(() => percent = v)),
                const SizedBox(height: 8),
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
                            if (startDate != null && deadline != null && deadline!.isBefore(startDate!)) {
                              messenger.showSnackBar(const SnackBar(content: Text('Due date is before the start date')));
                              return;
                            }
                            setSheet(() => busy = true);
                            final parentChanged = isEdit && (existing.parentTaskId ?? '') != (parentId ?? '');
                            // Someone who only reports progress sends only progress.
                            final body = planLocked
                                ? <String, dynamic>{'status': status.slug, 'percentComplete': percent.round()}
                                : <String, dynamic>{
                                    'projectId': projectId,
                                    'parentTaskId': parentId,
                                    'title': title.text.trim(),
                                    'description': desc.text.trim(),
                                    'assignedTo': assignee,
                                    'ticketType': ticketType.slug,
                                    'category': ticketType.slug,
                                    'severity': severity.slug,
                                    'priority': severity.slug,
                                    'subTeam': subTeam.slug,
                                    'status': status.slug,
                                    'percentComplete': percent.round(),
                                    'estimatedHours': double.tryParse(hours.text.trim()) ?? 0,
                                    'startDate': startDate?.toIso8601String(),
                                    'deadline': deadline?.toIso8601String(),
                                    'dueDate': deadline?.toIso8601String(),
                                    if (departmentChoices.isNotEmpty) 'departmentName': departmentName,
                                    if (!isEdit || parentChanged) 'order': nextOrder(parentId),
                                  };
                            try {
                              final svc = ref.read(itTaskServiceProvider);
                              if (isEdit) {
                                await svc.updateTask(existing.id, body);
                              } else {
                                await svc.createTask(body);
                              }
                              refreshAllItTaskViews(ref);
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheet(() => busy = false);
                              messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                            }
                          },
                    child: Text(busy ? 'Saving…' : (isEdit ? 'Save ${entityName.toLowerCase()}' : 'Create ${entityName.toLowerCase()}')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
