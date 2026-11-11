import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/domain/project_dashboard_stats.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_dashboard_kit.dart';
import 'package:nizan_crm/features/notifications/controllers/notification_providers.dart';
import 'package:nizan_crm/features/notifications/data/app_notification.dart';
import 'package:nizan_crm/features/notifications/presentation/screens/notifications_screen.dart' show notificationAgo, notificationLook;

// The project dashboard's cards about the people's side of it: my tasks, how the tasks stand, and what has been
// happening. Like the other cards they never use a LayoutBuilder; the page says how wide they are (`compact`).

// ── My tasks ─────────────────────────────────────────────────────────────────

enum TaskGroup { all, todo, doing, done }

TaskGroup groupOf(ITTask t) {
  if (t.isCompleted) return TaskGroup.done;
  return switch (t.status) {
    ITTaskStatus.backlog || ITTaskStatus.todo => TaskGroup.todo,
    _ => TaskGroup.doing,
  };
}

Color _groupColor(TaskGroup g) => switch (g) {
  TaskGroup.done => const Color(0xFF22A06B),
  TaskGroup.doing => const Color(0xFF3B82F6),
  _ => const Color(0xFF9AA0A6),
};

String _groupLabel(TaskGroup g) => switch (g) {
  TaskGroup.done => 'Completed',
  TaskGroup.doing => 'In Progress',
  _ => 'To Do',
};

class MyTasksCard extends StatefulWidget {
  const MyTasksCard({
    super.key,
    required this.tasks,
    required this.now,
    required this.onOpenTask,
    required this.onViewAll,
    this.onRetry,
    this.compact = false,
  });
  final AsyncValue<List<ITTask>> tasks;
  final DateTime now;
  final void Function(ITTask task) onOpenTask;
  final VoidCallback onViewAll;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  State<MyTasksCard> createState() => _MyTasksCardState();
}

class _MyTasksCardState extends State<MyTasksCard> {
  TaskGroup _group = TaskGroup.all;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      key: const Key('pd_mytasks_card'),
      title: 'My Tasks',
      icon: Icons.task_alt_rounded,
      iconColor: const Color(0xFF3B82F6),
      trailing: DashLink('View All', onTap: widget.onViewAll),
      child: widget.tasks.when(
        loading: () => const DashStatus.loading(height: 200),
        error: (_, _) => DashStatus.failed(height: 200, onRetry: widget.onRetry),
        data: _body,
      ),
    );
  }

  Widget _body(List<ITTask> tasks) {
    final crm = context.crmColors;
    int n(TaskGroup g) => g == TaskGroup.all ? tasks.length : tasks.where((t) => groupOf(t) == g).length;
    // what still needs doing first, soonest due first; finished ones last
    final shown =
        [
          for (final t in tasks)
            if (_group == TaskGroup.all || groupOf(t) == _group) t,
        ]..sort((a, b) {
          final da = a.isCompleted, db = b.isCompleted;
          if (da != db) return da ? 1 : -1;
          if (a.dueDate == null || b.dueDate == null) return a.dueDate == null ? (b.dueDate == null ? 0 : 1) : -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DashSegmented<TaskGroup>(
            keyPrefix: 'pd_tasks_tab',
            dense: true,
            value: _group,
            options: [
              (TaskGroup.all, 'All (${n(TaskGroup.all)})'),
              (TaskGroup.todo, 'To Do (${n(TaskGroup.todo)})'),
              (TaskGroup.doing, 'In Progress (${n(TaskGroup.doing)})'),
              (TaskGroup.done, 'Completed (${n(TaskGroup.done)})'),
            ],
            onChanged: (g) => setState(() => _group = g),
          ),
        ),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          DashEmpty(tasks.isEmpty ? 'No tasks are assigned to you.' : 'No tasks here.', icon: Icons.task_alt_rounded, height: 150)
        else
          for (var i = 0; i < shown.length && i < 5; i++) _row(crm, shown[i], i),
      ],
    );
  }

  Widget _row(CrmTheme crm, ITTask t, int i) {
    final g = groupOf(t);
    final done = g == TaskGroup.done;
    final overdue =
        !done &&
        t.dueDate != null &&
        DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day).isBefore(DateTime(widget.now.year, widget.now.month, widget.now.day));
    final due = t.dueDate == null ? '—' : shortDate(t.dueDate!, widget.now);
    return InkWell(
      key: Key('pd_task_$i'),
      onTap: () => widget.onOpenTask(t),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: crm.border)),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: done ? _groupColor(g) : crm.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: done ? const Color(0xFF059669) : crm.textPrimary,
                      decoration: null,
                    ),
                  ),
                  if (widget.compact || t.projectName.isNotEmpty)
                    Text(
                      widget.compact ? '${t.projectName.isEmpty ? '' : '${t.projectName} · '}$due' : t.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: overdue && widget.compact ? const Color(0xFFDC4C4C) : crm.textSecondary),
                    ),
                ],
              ),
            ),
            if (!widget.compact)
              SizedBox(
                width: 62,
                child: Text(
                  due,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: overdue ? FontWeight.w800 : FontWeight.w500,
                    color: overdue ? const Color(0xFFDC4C4C) : crm.textSecondary,
                  ),
                ),
              ),
            const SizedBox(width: 10),
            SizedBox(
              width: widget.compact ? 82 : 92,
              child: Align(alignment: Alignment.centerRight, child: DashPill(_groupLabel(g), _groupColor(g))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── How the tasks stand ──────────────────────────────────────────────────────

class TaskOverviewCard extends StatelessWidget {
  const TaskOverviewCard({
    super.key,
    required this.totals,
    required this.byDepartment,
    required this.colorOf,
    this.loading = false,
    this.failed = false,
    this.onRetry,
  });
  final TaskTotals totals;

  /// Tasks per department, any order.
  final Map<String, int> byDepartment;
  final Color Function(String name) colorOf;

  /// The tasks are still coming / could not be fetched — say so rather than "no tasks".
  final bool loading;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final depts = byDepartment.entries.toList()..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    final top = depts.take(6).toList();
    final sum = byDepartment.values.fold<int>(0, (a, b) => a + b);
    final peak = top.isEmpty ? 1 : top.first.value;
    return DashCard(
      title: 'Task Overview',
      subtitle: 'All tasks in these projects',
      icon: Icons.checklist_rtl_rounded,
      iconColor: const Color(0xFF22A06B),
      child: loading
          ? const DashStatus.loading(height: 200)
          : failed
          ? DashStatus.failed(height: 200, onRetry: onRetry)
          : totals.total == 0
          ? const DashEmpty('No tasks in these projects yet.', icon: Icons.checklist_rtl_rounded, height: 200)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(
                        alignment: Alignment.center,
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: totals.done / totals.total,
                            strokeWidth: 9,
                            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.18),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF22A06B)),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${totals.percentDone}%',
                                  key: const Key('pd_tasks_done_pct'),
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.4),
                                ),
                                Text('Done', style: TextStyle(fontSize: 10, color: crm.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        children: [
                          _stat(crm, const Color(0xFF22A06B), 'Completed', totals.done),
                          _stat(crm, const Color(0xFF3B82F6), 'Open', totals.open - totals.overdue),
                          _stat(crm, const Color(0xFFDC4C4C), 'Overdue', totals.overdue),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Tasks by department',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 112,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in top)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${sum == 0 ? 0 : (d.value * 100 / sum).round()}%',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: crm.textSecondary),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                key: Key('pd_taskdept_${d.key}'),
                                width: 16,
                                height: 6 + 58.0 * d.value / peak,
                                decoration: BoxDecoration(
                                  color: colorOf(d.key),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                d.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: crm.textSecondary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _stat(CrmTheme crm, Color color, String label, int n) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
        ),
        Text(
          '$n',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
        ),
      ],
    ),
  );
}

// ── What has been happening ──────────────────────────────────────────────────

class NotificationsCard extends ConsumerWidget {
  const NotificationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(notificationsProvider);
    return DashCard(
      title: 'Notifications',
      icon: Icons.notifications_none_rounded,
      iconColor: const Color(0xFFD6409F),
      trailing: DashLink('View All', onTap: () => context.go('/notifications')),
      child: async.when(
        loading: () => const DashStatus.loading(height: 170),
        error: (_, _) => DashStatus.failed(height: 170, onRetry: () => ref.invalidate(notificationsProvider)),
        data: (page) {
          final items = page.items.take(5).toList();
          if (items.isEmpty) return const DashEmpty('You are all caught up.', icon: Icons.notifications_none_rounded, height: 150);
          return Column(children: [for (var i = 0; i < items.length; i++) _row(context, crm, items[i], i)]);
        },
      ),
    );
  }

  Widget _row(BuildContext context, CrmTheme crm, AppNotification n, int i) {
    final look = notificationLook(n.type);
    return InkWell(
      key: Key('pd_notif_$i'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go(n.link.startsWith('/') ? n.link : '/notifications'),
      child: Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 6, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: look.color.withValues(alpha: 0.13), shape: BoxShape.circle),
              child: Icon(look.icon, size: 16, color: look.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title.isEmpty ? n.body : n.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.3, fontWeight: n.read ? FontWeight.w500 : FontWeight.w700, color: crm.textPrimary),
                  ),
                  const SizedBox(height: 1),
                  Text(notificationAgo(n.createdAt), style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                ],
              ),
            ),
            if (!n.read)
              Container(
                margin: const EdgeInsets.only(top: 5, left: 6),
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: crm.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
