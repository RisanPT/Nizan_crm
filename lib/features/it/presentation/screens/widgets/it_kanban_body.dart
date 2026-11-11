import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/domain/task_rights.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

/// Specification for a column on the adaptive Kanban board
class KanbanColumnDef {
  final String id;
  final String label;
  final Color color;
  final ITTaskStatus targetStatus;
  final bool Function(ITTaskModel) matches;

  const KanbanColumnDef({required this.id, required this.label, required this.color, required this.targetStatus, required this.matches});
}

/// The status-column kanban board for a project. Shows leaf work items only —
/// phase / summary rows are organizational and live in the WBS tab.
/// Supports both IT software engineering workflows and business/functional workflows.
class ITKanbanBody extends ConsumerStatefulWidget {
  const ITKanbanBody({super.key, required this.projectId, required this.tasks, this.isItProject});

  final String projectId;
  final List<ITTaskModel> tasks;
  final bool? isItProject;

  @override
  ConsumerState<ITKanbanBody> createState() => _ITKanbanBodyState();
}

class _ITKanbanBodyState extends ConsumerState<ITKanbanBody> {
  String? _hoveredColumnStatus;
  Project? _project;
  String _me = '';

  /// What the signed-in person may do to this card (a manager-planned project lets an
  /// assignee move only their own, and only a manager / lead delete).
  TaskRights _rights(ITTaskModel t) => taskRightsFor(_project, t, myEmployeeId: _me);

  List<KanbanColumnDef> _getColumns(bool isIt) {
    if (isIt) {
      return [
        for (final st in ITTaskStatus.values)
          KanbanColumnDef(id: st.slug, label: st.label, color: st.color, targetStatus: st, matches: (t) => t.status == st),
      ];
    }

    // Business & Functional Operations Workflow for non-IT projects
    return [
      KanbanColumnDef(
        id: 'backlog',
        label: 'Backlog',
        color: const Color(0xFF64748B),
        targetStatus: ITTaskStatus.backlog,
        matches: (t) => t.status == ITTaskStatus.backlog,
      ),
      KanbanColumnDef(
        id: 'todo',
        label: 'To Do',
        color: const Color(0xFF3B82F6),
        targetStatus: ITTaskStatus.todo,
        matches: (t) => t.status == ITTaskStatus.todo,
      ),
      KanbanColumnDef(
        id: 'in-progress',
        label: 'In Progress',
        color: const Color(0xFF0EA5E9),
        targetStatus: ITTaskStatus.inProgress,
        matches: (t) => t.status == ITTaskStatus.inProgress,
      ),
      KanbanColumnDef(
        id: 'review',
        label: 'In Review & Approval',
        color: const Color(0xFFF59E0B),
        targetStatus: ITTaskStatus.codeReview,
        matches: (t) => t.status == ITTaskStatus.codeReview || t.status == ITTaskStatus.qaTesting,
      ),
      KanbanColumnDef(
        id: 'completed',
        label: 'Completed / Done',
        color: const Color(0xFF10B981),
        targetStatus: ITTaskStatus.deployed,
        matches: (t) => t.status == ITTaskStatus.deployed || t.status == ITTaskStatus.closed,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _project = ref.watch(projectByIdProvider(widget.projectId));
    _me = ref.watch(authSessionProvider)?.employeeId ?? '';
    final crm = context.crmColors;
    final parentIds = {
      for (final t in widget.tasks)
        if (t.parentTaskId != null) t.parentTaskId!,
    };
    final leaves = widget.tasks.where((t) => !parentIds.contains(t.id)).toList();

    final isIt = widget.isItProject ?? ((_project?.targetDepartment ?? 'it').toLowerCase().trim() == 'it');
    final columns = _getColumns(isIt);

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      children: [for (final col in columns) _buildColumn(crm, col, leaves.where(col.matches).toList(), isIt, columns)],
    );
  }

  Widget _buildColumn(CrmTheme crm, KanbanColumnDef col, List<ITTaskModel> items, bool isIt, List<KanbanColumnDef> allCols) {
    final color = col.color;
    final isHovered = _hoveredColumnStatus == col.id;

    return DragTarget<ITTaskModel>(
      onWillAcceptWithDetails: (details) => !col.matches(details.data) && _rights(details.data).progress,
      onAcceptWithDetails: (details) {
        setState(() => _hoveredColumnStatus = null);
        _move(context, ref, details.data, col.targetStatus.slug);
      },
      onMove: (_) {
        if (_hoveredColumnStatus != col.id) {
          setState(() => _hoveredColumnStatus = col.id);
        }
      },
      onLeave: (_) {
        if (_hoveredColumnStatus == col.id) {
          setState(() => _hoveredColumnStatus = null);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 300,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: isHovered ? color.withValues(alpha: 0.06) : crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isHovered ? color : crm.border, width: isHovered ? 2 : 1),
          ),
          child: Column(
            children: [
              // Column Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isHovered ? color.withValues(alpha: 0.4) : crm.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        col.label,
                        style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              // Tasks List
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          candidateData.isNotEmpty ? 'Drop here to move' : 'No tasks',
                          style: TextStyle(
                            color: candidateData.isNotEmpty ? color : crm.textSecondary,
                            fontSize: 12,
                            fontWeight: candidateData.isNotEmpty ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      )
                    : ListView(padding: const EdgeInsets.all(10), children: [for (final t in items) _buildDraggableTaskCard(crm, t, isIt, allCols)]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableTaskCard(CrmTheme crm, ITTaskModel t, bool isIt, List<KanbanColumnDef> allCols) {
    if (!_rights(t).progress) return _buildCardContent(crm, t, isIt: isIt, allCols: allCols); // not theirs to move
    return Draggable<ITTaskModel>(
      data: t,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 280,
          child: _buildCardContent(crm, t, isFeedback: true, isIt: isIt, allCols: allCols),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildCardContent(crm, t, isIt: isIt, allCols: allCols),
      ),
      child: _buildCardContent(crm, t, isIt: isIt, allCols: allCols),
    );
  }

  Widget _buildCardContent(CrmTheme crm, ITTaskModel t, {bool isFeedback = false, required bool isIt, required List<KanbanColumnDef> allCols}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isFeedback ? crm.primary : crm.border),
        boxShadow: isFeedback ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            showITTaskDetailSheet(context, ref, task: t, allTasks: widget.tasks).then((s) => _refreshIf(s));
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isIt) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: t.ticketType.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          t.ticketKey,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: t.ticketType.color),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (t.departmentName.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          t.departmentName,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: crm.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        t.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      height: 26,
                      width: 26,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        onSelected: (v) {
                          if (v == 'edit') {
                            showITTaskDetailSheet(context, ref, task: t, allTasks: widget.tasks).then((s) => _refreshIf(s));
                          } else if (v == 'delete') {
                            _deleteTask(t);
                          } else {
                            _move(context, ref, t, v);
                          }
                        },
                        itemBuilder: (_) {
                          final r = _rights(t);
                          return [
                            if (r.progress)
                              for (final col in allCols)
                                if (!col.matches(t)) PopupMenuItem(value: col.targetStatus.slug, child: Text('Move to ${col.label}')),
                            if (r.progress) const PopupMenuDivider(),
                            PopupMenuItem(value: 'edit', child: Text(r.readOnly ? 'Details' : 'Edit / Details')),
                            if (r.delete) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ];
                        },
                      ),
                    ),
                  ],
                ),
                if (t.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    itTag(isIt ? t.severity.label : t.severity.label.replaceAll(RegExp(r'^P\d\s*-\s*'), ''), t.severity.color),
                    if (isIt) itTag(t.ticketType.label, t.ticketType.color),
                    if (isIt) itTag(t.subTeam.label, t.subTeam.color),
                    if (t.percentComplete > 0)
                      itTag(
                        '${t.percentComplete}%',
                        percentFill(t.percentComplete) == const Color(0xFFF1F1F1) ? crm.textSecondary : const Color(0xFF1F7A44),
                      ),
                    if (t.dueDate != null) itTag('${t.dueDate!.day}/${t.dueDate!.month}', crm.textSecondary),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 14, color: crm.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        t.assigneeName.isEmpty ? 'Unassigned' : t.assigneeName,
                        style: TextStyle(fontSize: 11, color: crm.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _refreshIf(bool? changed) {
    if (changed == true) {
      final notifier = getITTasksNotifier(ref, widget.projectId);
      notifier.refresh();
      ref.invalidate(projectsProvider);
    }
  }

  Future<void> _move(BuildContext context, WidgetRef ref, ITTaskModel task, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final statusEnum = ITTaskStatus.fromString(newStatus);
      final notifier = getITTasksNotifier(ref, widget.projectId);
      await notifier.bulkUpdateStatus([task.id], statusEnum);
      ref.invalidate(projectsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _deleteTask(ITTaskModel t) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Are you sure you want to delete "${t.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final notifier = getITTasksNotifier(ref, widget.projectId);
      await notifier.deleteTask(t.id);
      ref.invalidate(projectsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }
}
