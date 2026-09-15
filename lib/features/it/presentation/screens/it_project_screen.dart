import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_data_grid_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_interactive_gantt.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_wbs_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_kanban_body.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_okr_view.dart';
import 'package:nizan_crm/features/it/presentation/controllers/okr_notifier.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

/// A single project viewed four ways:
/// 1. Spreadsheet (Dense Google Sheets PlutoGrid)
/// 2. Interactive Timeline (Gantt with zoom & dependency curves)
/// 3. WBS (Work breakdown structure table)
/// 4. Kanban (Status board)
class ITProjectScreen extends ConsumerWidget {
  const ITProjectScreen({super.key, required this.projectId, this.initialIndex = 0});
  final String projectId;
  final int initialIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final asyncTasks = ref.watch(itProjectTasksControllerProvider(projectId));
    final tasks = asyncTasks.value ?? const <ITTaskModel>[];

    final projectName = ref.watch(projectsProvider).maybeWhen(
          data: (list) => list.where((p) => p.id == projectId).map((p) => p.name).firstOrNull ?? 'Project',
          orElse: () => 'Project',
        );

    return DefaultTabController(
      length: 5,
      initialIndex: initialIndex.clamp(0, 4),
      child: Scaffold(
        backgroundColor: crm.background,
        body: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
            decoration: BoxDecoration(
              color: crm.surface,
              border: Border(bottom: BorderSide(color: crm.border)),
            ),
            child: Column(children: [
              Row(children: [
                IconButton(
                  onPressed: () => context.go('/it/projects'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Projects',
                ),
                Expanded(
                  child: Text(
                    projectName,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    ref.read(itProjectTasksControllerProvider(projectId).notifier).refresh();
                    ref.read(projectOKRsNotifierProvider(projectId).notifier).refresh();
                    ref.invalidate(projectsProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: crm.primary),
                  onPressed: () => showTaskEditor(context, ref, projectId, allTasks: tasks).then((s) {
                    if (s == true) {
                      ref.read(itProjectTasksControllerProvider(projectId).notifier).refresh();
                      ref.invalidate(projectsProvider);
                    }
                  }),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Ticket'),
                ),
              ]),
              TabBar(
                labelColor: crm.primary,
                unselectedLabelColor: crm.textSecondary,
                indicatorColor: crm.primary,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'Spreadsheet', icon: Icon(Icons.table_chart_outlined, size: 17)),
                  Tab(text: 'Timeline', icon: Icon(Icons.timeline_outlined, size: 17)),
                  Tab(text: 'WBS', icon: Icon(Icons.account_tree_outlined, size: 17)),
                  Tab(text: 'Board', icon: Icon(Icons.view_kanban_outlined, size: 17)),
                  Tab(text: "OKR's & KR's", icon: Icon(Icons.track_changes_outlined, size: 17)),
                ],
              ),
            ]),
          ),
          Expanded(
            child: asyncTasks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary))),
              data: (list) => TabBarView(children: [
                ITDataGridView(tasks: list, allTasks: list, projectId: projectId),
                ITInteractiveGantt(tasks: list, allTasks: list, projectId: projectId),
                ITWbsView(projectId: projectId, tasks: list),
                ITKanbanBody(projectId: projectId, tasks: list),
                ITOkrView(projectId: projectId, projectName: projectName),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
