import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

/// The status-column kanban board for a project. Shows leaf work items only —
/// phase / summary rows are organizational and live in the WBS tab.
class ITKanbanBody extends ConsumerStatefulWidget {
  const ITKanbanBody({super.key, required this.projectId, required this.tasks});

  final String projectId;
  final List<ITTaskModel> tasks;

  @override
  ConsumerState<ITKanbanBody> createState() => _ITKanbanBodyState();
}

class _ITKanbanBodyState extends ConsumerState<ITKanbanBody> {
  String? _hoveredColumnStatus;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final parentIds = {for (final t in widget.tasks) if (t.parentTaskId != null) t.parentTaskId!};
    final leaves = widget.tasks.where((t) => !parentIds.contains(t.id)).toList();

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      children: [
        for (final status in ITTaskStatus.values)
          _buildColumn(crm, status, leaves.where((t) => t.status == status).toList()),
      ],
    );
  }

  Widget _buildColumn(CrmTheme crm, ITTaskStatus status, List<ITTaskModel> items) {
    final color = status.color;
    final isHovered = _hoveredColumnStatus == status.slug;

    return DragTarget<ITTaskModel>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        setState(() => _hoveredColumnStatus = null);
        _move(context, ref, details.data, status.slug);
      },
      onMove: (_) {
        if (_hoveredColumnStatus != status.slug) {
          setState(() => _hoveredColumnStatus = status.slug);
        }
      },
      onLeave: (_) {
        if (_hoveredColumnStatus == status.slug) {
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
            border: Border.all(
              color: isHovered ? color : crm.border,
              width: isHovered ? 2 : 1,
            ),
          ),
          child: Column(children: [
            // Column Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isHovered ? color.withValues(alpha: 0.4) : crm.border)),
              ),
              child: Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                const SizedBox(width: 8),
                Text(status.label, style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text('${items.length}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
            // Tasks List
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        candidateData.isNotEmpty ? 'Drop here to move' : 'No tasks',
                        style: TextStyle(color: candidateData.isNotEmpty ? color : crm.textSecondary, fontSize: 12, fontWeight: candidateData.isNotEmpty ? FontWeight.w700 : FontWeight.normal),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(10),
                      children: [
                        for (final t in items) _buildDraggableTaskCard(crm, t),
                      ],
                    ),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildDraggableTaskCard(CrmTheme crm, ITTaskModel t) {
    return Draggable<ITTaskModel>(
      data: t,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 280,
          child: _buildCardContent(crm, t, isFeedback: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildCardContent(crm, t),
      ),
      child: _buildCardContent(crm, t),
    );
  }

  Widget _buildCardContent(CrmTheme crm, ITTaskModel t, {bool isFeedback = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isFeedback ? crm.primary : crm.border),
        boxShadow: isFeedback
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.ticketType.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    t.ticketKey,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: t.ticketType.color),
                  ),
                ),
                const SizedBox(width: 8),
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
                    itemBuilder: (_) => [
                      for (final st in ITTaskStatus.values)
                        if (st != t.status) PopupMenuItem(value: st.slug, child: Text('Move to ${st.label}')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'edit', child: Text('Edit / Details')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              ]),
              if (t.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                itTag(t.severity.label, t.severity.color),
                itTag(t.ticketType.label, t.ticketType.color),
                itTag(t.subTeam.label, t.subTeam.color),
                if (t.percentComplete > 0)
                  itTag('${t.percentComplete}%', percentFill(t.percentComplete) == const Color(0xFFF1F1F1) ? crm.textSecondary : const Color(0xFF1F7A44)),
                if (t.dueDate != null)
                  itTag('${t.dueDate!.day}/${t.dueDate!.month}', crm.textSecondary),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.account_circle_outlined, size: 14, color: crm.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    t.assigneeName.isEmpty ? 'Unassigned' : t.assigneeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _refreshIf(bool? saved) {
    if (saved == true) {
      getITTasksNotifier(ref, widget.projectId).refresh();
      ref.invalidate(projectsProvider);
    }
  }

  Future<void> _move(BuildContext context, WidgetRef ref, ITTaskModel t, String statusSlug) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final notifier = getITTasksNotifier(ref, widget.projectId);
      await notifier.updateTaskField(t.id, {'status': statusSlug});
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
