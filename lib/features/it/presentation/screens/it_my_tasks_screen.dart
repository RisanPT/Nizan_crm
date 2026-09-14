import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_projects_screen.dart' show priorityColor;
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';

/// The logged-in user's tasks across every project, grouped by project, with
/// quick status and % updates.
class ITMyTasksScreen extends ConsumerWidget {
  const ITMyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(myTasksProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
          child: Row(children: [
            Icon(Icons.assignment_ind_outlined, color: crm.primary),
            const SizedBox(width: 10),
            Text('My Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
            const Spacer(),
            IconButton(onPressed: () => ref.invalidate(myTasksProvider), icon: const Icon(Icons.refresh)),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary))),
            data: (tasks) => _build(context, ref, crm, tasks),
          ),
        ),
      ]),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref, CrmTheme crm, List<ITTask> tasks) {
    // Leaf work items only (skip phase/summary rows) assigned to me.
    final parentIds = {for (final t in tasks) if (t.parentTaskId != null) t.parentTaskId!};
    final mine = tasks.where((t) => !parentIds.contains(t.id)).toList();

    if (mine.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.task_alt_outlined, size: 50, color: crm.textSecondary),
          const SizedBox(height: 10),
          Text('Nothing assigned to you', style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Tasks assigned to you across all projects show up here.', style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
        ]),
      );
    }

    final open = mine.where((t) => t.status != ITTaskStatus.closed && t.status != ITTaskStatus.deployed).length;
    final today = DateTime.now();
    final overdue = mine.where((t) => t.status != ITTaskStatus.closed && t.status != ITTaskStatus.deployed && t.deadline != null && t.deadline!.isBefore(DateTime(today.year, today.month, today.day))).length;

    // Group by project name, ordered by name; within a project, due-date asc.
    final byProject = <String, List<ITTask>>{};
    for (final t in mine) {
      (byProject[t.projectName.isEmpty ? 'Project' : t.projectName] ??= []).add(t);
    }
    final names = byProject.keys.toList()..sort();
    for (final list in byProject.values) {
      list.sort((a, b) {
        final ad = a.deadline, bd = b.deadline;
        if (ad == null && bd == null) return a.title.compareTo(b.title);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myTasksProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Row(children: [
            _summaryChip(crm, '${mine.length}', 'Total', crm.primary),
            const SizedBox(width: 10),
            _summaryChip(crm, '$open', 'Open', Colors.blue.shade600),
            const SizedBox(width: 10),
            _summaryChip(crm, '$overdue', 'Overdue', Colors.red.shade600),
          ]),
          const SizedBox(height: 16),
          for (final name in names) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4, left: 2),
              child: Row(children: [
                Icon(Icons.folder_outlined, size: 15, color: crm.textSecondary),
                const SizedBox(width: 6),
                Text(name, style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
                const SizedBox(width: 6),
                Text('(${byProject[name]!.length})', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              ]),
            ),
            for (final t in byProject[name]!) _taskCard(context, ref, crm, t),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(CrmTheme crm, String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
          child: Row(children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _taskCard(BuildContext context, WidgetRef ref, CrmTheme crm, ITTask t) {
    final today = DateTime.now();
    final isOverdue = t.status != ITTaskStatus.closed && t.status != ITTaskStatus.deployed && t.deadline != null && t.deadline!.isBefore(DateTime(today.year, today.month, today.day));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openEditor(context, ref, t),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
                _statusMenu(context, ref, t),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                if (t.deadline != null) ...[
                  Icon(Icons.event_outlined, size: 14, color: isOverdue ? Colors.red.shade600 : crm.textSecondary),
                  const SizedBox(width: 4),
                  Text(shortDate(t.deadline),
                      style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red.shade600 : crm.textSecondary, fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500)),
                  if (isOverdue) Padding(padding: const EdgeInsets.only(left: 6), child: itTag('Overdue', Colors.red.shade600)),
                  const SizedBox(width: 10),
                ],
                itTag(cap(t.priority), priorityColor(t.priority)),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: () => _quickPercent(context, ref, t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: percentFill(t.percentComplete), borderRadius: BorderRadius.circular(7)),
                    child: Text('${t.percentComplete}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: percentText(t.percentComplete))),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _statusMenu(BuildContext context, WidgetRef ref, ITTask t) {
    final color = itTaskStatusColor(t.status.slug);
    return PopupMenuButton<String>(
      tooltip: 'Change status',
      onSelected: (s) => _setStatus(context, ref, t, s),
      itemBuilder: (_) => [for (final s in itTaskStatuses) PopupMenuItem(value: s, child: Text(itStatusLabel(s)))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text(itStatusLabel(t.status.slug), style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
          Icon(Icons.arrow_drop_down, size: 16, color: color),
        ]),
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, WidgetRef ref, ITTask t, String status) async {
    if (status == t.status.slug) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(itTaskServiceProvider).updateTask(t.id, {'status': status});
      ref.invalidate(myTasksProvider);
      ref.invalidate(projectsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _quickPercent(BuildContext context, WidgetRef ref, ITTask t) async {
    double p = t.percentComplete.toDouble();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Update progress', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(t.title, style: TextStyle(fontSize: 12.5, color: context.crmColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Row(children: [
              const Text('% complete', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: percentFill(p.round()), borderRadius: BorderRadius.circular(8)),
                child: Text('${p.round()}%', style: TextStyle(color: percentText(p.round()), fontWeight: FontWeight.w800)),
              ),
            ]),
            Slider(value: p, min: 0, max: 100, divisions: 20, label: '${p.round()}%', onChanged: (v) => setSheet(() => p = v)),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  try {
                    await ref.read(itTaskServiceProvider).updateTask(t.id, {'percentComplete': p.round()});
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                  }
                },
                child: const Text('Save'),
              ),
            ),
          ]),
        ),
      ),
    );
    if (saved == true) {
      ref.invalidate(myTasksProvider);
      ref.invalidate(projectsProvider);
    }
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, ITTask t) async {
    // Parent dropdown should list only this task's project.
    final all = ref.read(myTasksProvider).value ?? const <ITTask>[];
    final sameProject = all.where((e) => e.projectId == t.projectId).toList();
    final saved = await showTaskEditor(context, ref, t.projectId, existing: t, allTasks: sameProject);
    if (saved == true) {
      ref.invalidate(myTasksProvider);
      ref.invalidate(projectsProvider);
    }
  }
}
