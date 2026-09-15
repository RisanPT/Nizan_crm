import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';

/// Opens the create/edit task sheet. Returns `true` when a task was saved.
Future<bool?> showTaskEditor(
  BuildContext context,
  WidgetRef ref,
  String projectId, {
  ITTaskModel? existing,
  String? defaultParentId,
  List<ITTaskModel> allTasks = const [],
}) {
  final crm = context.crmColors;
  final isEdit = existing != null;

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
  final hours = TextEditingController(
      text: existing == null || existing.estimatedHours == 0 ? '' : existing.estimatedHours.toStringAsFixed(0));
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

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      var busy = false;
      return StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEdit ? 'Edit Ticket' : 'New Ticket', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title *')),
              const SizedBox(height: 10),
              TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 10),
              // Parent (WBS)
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
              const SizedBox(height: 10),
              EmployeePickerField(
                employees: employees,
                selectedId: assignee,
                selectedName: existing?.assigneeName,
                label: 'Assignee (optional for phases)',
                allowUnassign: true,
                onChanged: (e) => setSheet(() => assignee = e?.id),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<ITTicketType>(
                    initialValue: ticketType,
                    decoration: const InputDecoration(labelText: 'Ticket Type'),
                    items: [
                      for (final t in ITTicketType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) => setSheet(() => ticketType = v ?? ticketType),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<ITSeverity>(
                    initialValue: severity,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: [
                      for (final s in ITSeverity.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) => setSheet(() => severity = v ?? severity),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<ITSubTeam>(
                    initialValue: subTeam,
                    decoration: const InputDecoration(labelText: 'Sub-Team'),
                    items: [
                      for (final tm in ITSubTeam.values)
                        DropdownMenuItem(value: tm, child: Text(tm.label)),
                    ],
                    onChanged: (v) => setSheet(() => subTeam = v ?? subTeam),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<ITTaskStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final st in ITTaskStatus.values)
                        DropdownMenuItem(value: st, child: Text(st.label)),
                    ],
                    onChanged: (v) => setSheet(() => status = v ?? status),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: hours,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Est. hours'),
              ),
              const SizedBox(height: 14),
              // Dates row
              Row(children: [
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
              ]),
              const SizedBox(height: 14),
              // % complete
              Row(children: [
                const Text('% complete', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: percentFill(percent.round()), borderRadius: BorderRadius.circular(8)),
                  child: Text('${percent.round()}%', style: TextStyle(color: percentText(percent.round()), fontWeight: FontWeight.w800)),
                ),
              ]),
              Slider(
                value: percent,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${percent.round()}%',
                onChanged: (v) => setSheet(() => percent = v),
              ),
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
                          final body = <String, dynamic>{
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
                            if (!isEdit || parentChanged) 'order': nextOrder(parentId),
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
                  child: Text(busy ? 'Saving…' : (isEdit ? 'Save ticket' : 'Create ticket')),
                ),
              ),
            ]),
          ),
        ),
      );
    },
  );
}
