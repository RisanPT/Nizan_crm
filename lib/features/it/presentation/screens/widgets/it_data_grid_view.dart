import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

class ITDataGridView extends ConsumerStatefulWidget {
  final List<ITTaskModel> tasks;
  final List<ITTaskModel> allTasks;
  final String? projectId;

  const ITDataGridView({
    super.key,
    required this.tasks,
    required this.allTasks,
    this.projectId,
  });

  @override
  ConsumerState<ITDataGridView> createState() => _ITDataGridViewState();
}

class _ITDataGridViewState extends ConsumerState<ITDataGridView> {
  PlutoGridStateManager? _stateManager;
  final Set<String> _selectedTaskIds = {};

  @override
  void didUpdateWidget(covariant ITDataGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_stateManager != null && oldWidget.tasks != widget.tasks) {
      _reloadRows();
    }
  }

  void _reloadRows() {
    if (_stateManager == null) return;
    final rows = _buildRows(widget.tasks);
    _stateManager!.removeAllRows();
    _stateManager!.appendRows(rows);
  }

  void _uncheckAllRows() {
    if (_stateManager == null) return;
    for (final r in _stateManager!.rows) {
      r.setChecked(false);
    }
    _stateManager!.notifyListeners();
  }

  List<PlutoColumn> _buildColumns(CrmTheme crm, List<Employee> employees) {
    return [
      PlutoColumn(
        title: 'KEY',
        field: 'key',
        type: PlutoColumnType.text(),
        width: 100,
        enableEditingMode: false,
        enableRowChecked: true,
        renderer: (renderContext) {
          final taskId = renderContext.row.cells['id']!.value.toString();
          final key = renderContext.cell.value.toString();
          return InkWell(
            onTap: () => _openDetail(taskId),
            child: Container(
              alignment: Alignment.centerLeft,
              child: Text(
                key,
                style: TextStyle(
                  color: crm.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
      PlutoColumn(
        title: 'TYPE',
        field: 'type',
        type: PlutoColumnType.select(ITTicketType.values.map((e) => e.label).toList()),
        width: 125,
        renderer: (renderContext) {
          final t = ITTicketType.fromString(renderContext.cell.value.toString());
          return Container(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: t.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(t.icon, size: 13, color: t.color),
                const SizedBox(width: 5),
                Text(
                  t.label,
                  style: TextStyle(color: t.color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          );
        },
      ),
      PlutoColumn(
        title: 'SUMMARY',
        field: 'title',
        type: PlutoColumnType.text(),
        width: 260,
        renderer: (renderContext) {
          final taskId = renderContext.row.cells['id']!.value.toString();
          final title = renderContext.cell.value.toString();
          final isBlocked = renderContext.row.cells['isBlocked']!.value == true;
          return Row(children: [
            if (isBlocked)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: 'Blocked by predecessor task',
                  child: Icon(Icons.lock_clock, size: 15, color: Colors.amber),
                ),
              ),
            Expanded(
              child: InkWell(
                onTap: () => _openDetail(taskId),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: crm.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ]);
        },
      ),
      PlutoColumn(
        title: 'STATUS',
        field: 'status',
        type: PlutoColumnType.select(ITTaskStatus.values.map((e) => e.label).toList()),
        width: 140,
        renderer: (renderContext) {
          final st = ITTaskStatus.fromString(renderContext.cell.value.toString());
          return Container(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: st.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: st.color),
                ),
                const SizedBox(width: 6),
                Text(
                  st.label,
                  style: TextStyle(color: st.color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          );
        },
      ),
      PlutoColumn(
        title: 'SEVERITY',
        field: 'severity',
        type: PlutoColumnType.select(ITSeverity.values.map((e) => e.label).toList()),
        width: 125,
        renderer: (renderContext) {
          final sv = ITSeverity.fromString(renderContext.cell.value.toString());
          return Container(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: sv.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sv.label,
                style: TextStyle(color: sv.color, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ),
      PlutoColumn(
        title: 'SUB-TEAM',
        field: 'subTeam',
        type: PlutoColumnType.select(ITSubTeam.values.map((e) => e.label).toList()),
        width: 120,
        renderer: (renderContext) {
          final tm = ITSubTeam.fromString(renderContext.cell.value.toString());
          return Container(
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(tm.icon, size: 14, color: tm.color),
              const SizedBox(width: 5),
              Text(
                tm.label,
                style: TextStyle(color: tm.color, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ]),
          );
        },
      ),
      PlutoColumn(
        title: 'ASSIGNEE',
        field: 'assignee',
        type: PlutoColumnType.select([
          'Unassigned',
          for (final e in employees) e.name,
        ]),
        width: 140,
        renderer: (renderContext) {
          final name = renderContext.cell.value.toString();
          return Container(
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_circle_outlined, size: 16, color: crm.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name.isEmpty ? 'Unassigned' : name,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: name.isEmpty ? crm.textSecondary : crm.textPrimary,
                    fontWeight: name.isEmpty ? FontWeight.normal : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          );
        },
      ),
      PlutoColumn(
        title: 'START',
        field: 'startDate',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        renderer: (renderContext) {
          final dateStr = renderContext.cell.value?.toString() ?? '';
          final taskId = renderContext.row.cells['id']!.value.toString();
          final hasDate = dateStr.isNotEmpty;
          return InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _pickDate(renderContext, taskId, 'startDate', dateStr),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: hasDate ? crm.primary : crm.textSecondary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasDate ? dateStr : 'Set date',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                      color: hasDate ? crm.textPrimary : crm.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      PlutoColumn(
        title: 'DUE',
        field: 'dueDate',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        renderer: (renderContext) {
          final dateStr = renderContext.cell.value?.toString() ?? '';
          final taskId = renderContext.row.cells['id']!.value.toString();
          final hasDate = dateStr.isNotEmpty;
          return InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _pickDate(renderContext, taskId, 'dueDate', dateStr),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 13,
                    color: hasDate ? const Color(0xFFE11D48) : crm.textSecondary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasDate ? dateStr : 'Set date',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                      color: hasDate ? crm.textPrimary : crm.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      PlutoColumn(
        title: 'EST. (HRS)',
        field: 'estimatedHours',
        type: PlutoColumnType.number(format: '#,###.0'),
        width: 100,
      ),
      PlutoColumn(
        title: 'ACT. (HRS)',
        field: 'actualHours',
        type: PlutoColumnType.number(format: '#,###.0'),
        width: 100,
      ),
      PlutoColumn(
        title: 'PROGRESS',
        field: 'percentComplete',
        type: PlutoColumnType.number(format: '##0%'),
        width: 105,
        renderer: (renderContext) {
          final pct = (renderContext.cell.value as num?)?.toInt() ?? 0;
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 6,
                    backgroundColor: crm.background,
                    valueColor: AlwaysStoppedAnimation(
                      pct >= 100 ? const Color(0xFF10B981) : crm.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$pct%',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
              ),
            ]),
          );
        },
      ),
    ];
  }

  List<PlutoRow> _buildRows(List<ITTaskModel> taskList) {
    return taskList.map((t) {
      return PlutoRow(
        cells: {
          'id': PlutoCell(value: t.id),
          'key': PlutoCell(value: t.ticketKey),
          'type': PlutoCell(value: t.ticketType.label),
          'title': PlutoCell(value: t.title),
          'status': PlutoCell(value: t.status.label),
          'severity': PlutoCell(value: t.severity.label),
          'subTeam': PlutoCell(value: t.subTeam.label),
          'assignee': PlutoCell(value: t.assigneeName.isEmpty ? 'Unassigned' : t.assigneeName),
          'startDate': PlutoCell(value: t.startDate != null ? DateFormat('yyyy-MM-dd').format(t.startDate!) : ''),
          'dueDate': PlutoCell(value: t.dueDate != null ? DateFormat('yyyy-MM-dd').format(t.dueDate!) : ''),
          'estimatedHours': PlutoCell(value: t.estimatedHours),
          'actualHours': PlutoCell(value: t.actualHours),
          'percentComplete': PlutoCell(value: t.percentComplete),
          'isBlocked': PlutoCell(value: t.isBlocked),
        },
      );
    }).toList();
  }

  void _openDetail(String taskId) {
    final task = widget.allTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;
    showITTaskDetailSheet(context, ref, task: task, allTasks: widget.allTasks).then((saved) {
      if (saved == true) {
        getITTasksNotifier(ref, widget.projectId).refresh();
      }
    });
  }

  Future<void> _pickDate(
    PlutoColumnRendererContext renderContext,
    String taskId,
    String field,
    String currentVal,
  ) async {
    final crm = context.crmColors;
    final parsedCurrent = DateTime.tryParse(currentVal);
    final initial = parsedCurrent ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: crm.primary,
              onPrimary: Colors.white,
              onSurface: crm.textPrimary,
              surface: crm.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final formatted = DateFormat('yyyy-MM-dd').format(picked);
    renderContext.cell.value = formatted;
    _stateManager?.notifyListeners();

    final updates = <String, dynamic>{};
    if (field == 'startDate') {
      updates['startDate'] = picked.toIso8601String();
    } else {
      updates['deadline'] = picked.toIso8601String();
      updates['dueDate'] = picked.toIso8601String();
    }

    try {
      await getITTasksNotifier(ref, widget.projectId).updateTaskField(taskId, updates);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
        _reloadRows();
      }
    }
  }

  Future<void> _handleCellChange(PlutoGridOnChangedEvent event) async {
    final row = event.row;
    final taskId = row.cells['id']!.value.toString();
    final field = event.column.field;
    final val = event.value;

    final notifier = getITTasksNotifier(ref, widget.projectId);

    final updates = <String, dynamic>{};
    if (field == 'title') {
      updates['title'] = val.toString().trim();
    } else if (field == 'status') {
      final st = ITTaskStatus.fromString(val.toString());
      updates['status'] = st.slug;
    } else if (field == 'severity') {
      final sv = ITSeverity.fromString(val.toString());
      updates['severity'] = sv.slug;
      updates['priority'] = sv.slug;
    } else if (field == 'type') {
      final tt = ITTicketType.fromString(val.toString());
      updates['ticketType'] = tt.slug;
      updates['category'] = tt.slug;
    } else if (field == 'subTeam') {
      final tm = ITSubTeam.fromString(val.toString());
      updates['subTeam'] = tm.slug;
    } else if (field == 'assignee') {
      final employees = ref.read(itEmployeesProvider);
      final match = employees.where((e) => e.name == val.toString()).firstOrNull;
      updates['assignedTo'] = match?.id;
    } else if (field == 'startDate') {
      if (val.toString().isNotEmpty) {
        updates['startDate'] = DateTime.tryParse(val.toString())?.toIso8601String();
      }
    } else if (field == 'dueDate') {
      if (val.toString().isNotEmpty) {
        updates['deadline'] = DateTime.tryParse(val.toString())?.toIso8601String();
        updates['dueDate'] = DateTime.tryParse(val.toString())?.toIso8601String();
      }
    } else if (field == 'estimatedHours') {
      updates['estimatedHours'] = (val as num?)?.toDouble() ?? 0;
    } else if (field == 'actualHours') {
      updates['actualHours'] = (val as num?)?.toDouble() ?? 0;
    } else if (field == 'percentComplete') {
      updates['percentComplete'] = (val as num?)?.toInt() ?? 0;
    }

    if (updates.isNotEmpty) {
      try {
        await notifier.updateTaskField(taskId, updates);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
          _reloadRows();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final employees = ref.watch(itEmployeesProvider);

    return Stack(
      children: [
        PlutoGrid(
          columns: _buildColumns(crm, employees),
          rows: _buildRows(widget.tasks),
          onLoaded: (event) {
            _stateManager = event.stateManager;
            _stateManager!.setShowColumnFilter(true);
          },
          onChanged: _handleCellChange,
          onSelected: (event) {
            if (_stateManager != null) {
              setState(() {
                _selectedTaskIds.clear();
                for (final r in _stateManager!.checkedRows) {
                  _selectedTaskIds.add(r.cells['id']!.value.toString());
                }
              });
            }
          },
          onRowDoubleTap: (event) {
            final taskId = event.row.cells['id']!.value.toString();
            _openDetail(taskId);
          },
          configuration: PlutoGridConfiguration(
            style: PlutoGridStyleConfig(
              gridBackgroundColor: crm.surface,
              rowColor: crm.surface,
              oddRowColor: crm.background.withValues(alpha: 0.5),
              gridBorderColor: crm.border,
              borderColor: crm.border,
              columnTextStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: crm.textSecondary,
                letterSpacing: 0.3,
              ),
              cellTextStyle: TextStyle(fontSize: 12.5, color: crm.textPrimary),
              rowHeight: 38,
              columnHeight: 36,
              enableColumnBorderVertical: true,
              enableColumnBorderHorizontal: true,
            ),
          ),
        ),

        // Bulk Actions Floating Toolbar
        if (_selectedTaskIds.isNotEmpty)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: crm.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${_selectedTaskIds.length} Selected',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 14),
                  PopupMenuButton<ITTaskStatus>(
                    tooltip: 'Change Status',
                    child: Row(children: const [
                      Icon(Icons.autorenew, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Status', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                    onSelected: (st) async {
                      final notifier = getITTasksNotifier(ref, widget.projectId);
                      await notifier.bulkUpdateStatus(_selectedTaskIds.toList(), st);
                      _uncheckAllRows();
                      setState(() => _selectedTaskIds.clear());
                    },
                    itemBuilder: (_) => [
                      for (final st in ITTaskStatus.values)
                        PopupMenuItem(
                          value: st,
                          child: Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: st.color)),
                            const SizedBox(width: 8),
                            Text(st.label),
                          ]),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  PopupMenuButton<Employee>(
                    tooltip: 'Assign Team Member',
                    child: Row(children: const [
                      Icon(Icons.person_add_outlined, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Assign', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                    onSelected: (emp) async {
                      final notifier = getITTasksNotifier(ref, widget.projectId);
                      await notifier.bulkReassign(_selectedTaskIds.toList(), emp.id);
                      _uncheckAllRows();
                      setState(() => _selectedTaskIds.clear());
                    },
                    itemBuilder: (_) => [
                      for (final emp in employees)
                        PopupMenuItem(value: emp, child: Text(emp.name)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Delete Selected',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete Selected Tasks?'),
                          content: Text('Are you sure you want to delete ${_selectedTaskIds.length} tasks?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Delete All'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && mounted) {
                        final notifier = getITTasksNotifier(ref, widget.projectId);
                        await notifier.bulkDelete(_selectedTaskIds.toList());
                        _uncheckAllRows();
                        setState(() => _selectedTaskIds.clear());
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    tooltip: 'Deselect all',
                    onPressed: () {
                      _uncheckAllRows();
                      setState(() => _selectedTaskIds.clear());
                    },
                  ),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}
