import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_data_grid_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_interactive_gantt.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/functional_plan_wizard_dialog.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_wbs_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_departments.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_overview.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_tabs.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_kanban_body.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_okr_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_project_docs_view.dart';
import 'package:nizan_crm/features/it/presentation/controllers/okr_notifier.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

/// A single project, seen several ways ([ProjectTab]):
/// 0. Overview (progress, departments, details, activity, phases at a glance)
/// 1. Spreadsheet (dense PlutoGrid)
/// 2. Interactive Timeline (Gantt with zoom & dependency curves)
/// 3. WBS (work breakdown structure table)
/// 4. Kanban (status board)
/// 5. OKRs and key results
/// 6. Documents
class ITProjectScreen extends ConsumerWidget {
  const ITProjectScreen({
    super.key,
    required this.projectId,
    this.initialIndex = 0,
    this.backRoute = '/it/projects',
  });
  final String projectId;
  final int initialIndex;

  /// Where the back button returns to — depends on which list opened this
  /// detail (`/it/projects` from the IT screen, `/projects` from Company
  /// Projects), since the same screen serves both routes.
  final String backRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final asyncTasks = ref.watch(itProjectTasksControllerProvider(projectId));
    final tasks = asyncTasks.value ?? const <ITTaskModel>[];

    final project = ref.watch(projectsProvider).maybeWhen(
          data: (list) => list.where((p) => p.id == projectId).firstOrNull,
          orElse: () => null,
        );
    final projectName = project?.name ?? 'Project';
    // Kanban is an IT-only feature — company (non-IT) projects get no Board tab.
    // Default to IT while the project list is still loading so IT detail views
    // (the common case) don't briefly lose the tab.
    final isItProject =
        (project?.targetDepartment ?? kItDepartment).toLowerCase().trim() == kItDepartment.toLowerCase();
    const tabCount = 7;
    assert(tabCount == ProjectTab.values.length);

    return DefaultTabController(
      length: tabCount,
      initialIndex: initialIndex.clamp(0, tabCount - 1),
      child: Builder(
        builder: (tabContext) {
          void openTab(int i) => DefaultTabController.of(tabContext).animateTo(i);

          Widget actions({required bool narrow}) => Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (project == null || project.access.canCreateTasks) ...[
                  OutlinedButton.icon(
                    key: const Key('gantt_plan_wizard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: crm.textPrimary,
                      side: BorderSide(color: crm.border.faded(2.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 16, vertical: 13),
                    ),
                    onPressed: () => showFunctionalPlanWizard(
                      context: context,
                      ref: ref,
                      projectId: projectId,
                      projectName: projectName,
                      existingTasks: tasks,
                      project: project,
                      onPlanCreated: () => openTab(ProjectTab.timeline.index),
                    ),
                    icon: Icon(Icons.trending_up_rounded, size: 18, color: crm.primary),
                    label: const Text('Gantt Plan Wizard', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  FilledButton.icon(
                    key: const Key('add_task'),
                    style: FilledButton.styleFrom(
                      backgroundColor: crm.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.symmetric(horizontal: narrow ? 14 : 18, vertical: 13),
                    ),
                    onPressed: () => showTaskEditor(context, ref, projectId, allTasks: tasks),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(isItProject ? 'Add Ticket' : 'Add Task', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
                PopupMenuButton<String>(
                  key: const Key('project_more'),
                  tooltip: 'More',
                  position: PopupMenuPosition.under,
                  onSelected: (v) async {
                    if (v == 'refresh') {
                      ref.read(itProjectTasksControllerProvider(projectId).notifier).refresh();
                      ref.read(projectOKRsNotifierProvider(projectId).notifier).refresh();
                      ref.invalidate(projectsProvider);
                    } else if (v == 'activity') {
                      final events = await ref.read(projectActivityProvider(projectId).future);
                      if (tabContext.mounted) await showProjectActivity(tabContext, events);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                    PopupMenuItem(value: 'activity', child: Text('View activity')),
                  ],
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: crm.border.faded(2.5)),
                    ),
                    child: Icon(Icons.more_horiz_rounded, color: crm.textPrimary),
                  ),
                ),
              ]);

          final subtitle = _subtitle(project);

          return Scaffold(
            backgroundColor: crm.background,
            body: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
                decoration: BoxDecoration(
                  color: crm.surface,
                  border: Border(bottom: BorderSide(color: crm.border)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Projects › name [H2]
                  Row(children: [
                    IconButton(
                      onPressed: () => context.go(backRoute),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      tooltip: 'Back to Projects',
                    ),
                    InkWell(
                      onTap: () => context.go(backRoute),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text('Projects', style: TextStyle(fontSize: 13.5, color: crm.textSecondary, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(Icons.chevron_right_rounded, size: 16, color: crm.textSecondary.withValues(alpha: 0.6)),
                    ),
                    Flexible(
                      child: Text(
                        projectName,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: crm.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (project != null) ...[
                      const SizedBox(width: 8),
                      _horizonBadge(project.horizonNumber),
                    ],
                  ]),
                  // [icon]  Title / subtitle ........ actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 0, 14),
                    child: LayoutBuilder(builder: (context, box) {
                      final wide = box.maxWidth >= 820;
                      final titleBlock = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14)),
                          child: Icon(Icons.layers_outlined, size: 26, color: crm.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              projectName,
                              key: const Key('project_title'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: wide ? 26 : 21, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.4, height: 1.15),
                            ),
                            if (subtitle.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
                              ),
                          ]),
                        ),
                      ]);
                      return wide
                          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: titleBlock), const SizedBox(width: 16), actions(narrow: false)])
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, const SizedBox(height: 12), actions(narrow: true)]);
                    }),
                  ),
                  // what is waiting on the viewer (an invitation to answer, a proposal to decide); nothing when there is none.
                  // Who else has been invited is the Overview's Department Invitations card, not a banner each.
                  if (project != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ProjectDecisionBanner(project: project, compact: true, showSentInvitations: false),
                    ),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    labelColor: crm.primary,
                    unselectedLabelColor: crm.textSecondary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    indicator: BoxDecoration(
                      color: crm.primary.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      border: Border(bottom: BorderSide(color: crm.primary, width: 2.5)),
                    ),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    tabs: [
                      for (final t in ProjectTab.values)
                        Tab(
                          key: Key('tab_${t.name}'),
                          height: 48,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(t.icon, size: 19),
                              const SizedBox(width: 8),
                              Text(t.label),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ]),
              ),
              Expanded(
                child: asyncTasks.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => AppErrorView(
                    error: e,
                    onRetry: () => ref.read(itProjectTasksControllerProvider(projectId).notifier).refresh(),
                  ),
                  data: (list) => TabBarView(children: [
                    ProjectOverview(projectId: projectId, project: project, tasks: list, onOpenTab: openTab),
                    ITDataGridView(tasks: list, allTasks: list, projectId: projectId),
                    ITInteractiveGantt(
                      tasks: list,
                      allTasks: list,
                      projectId: projectId,
                      // A project several departments work on reads best one lane per department.
                      swimlaneMode: (project?.isCrossDepartment ?? false) ? GanttSwimlaneMode.byDepartment : GanttSwimlaneMode.bySubTeam,
                      showToolbar: true, // week by week, Today, and the scale
                      editable: true, // add / edit / delete from the chart itself
                    ),
                    ITWbsView(projectId: projectId, tasks: list),
                    ITKanbanBody(projectId: projectId, tasks: list, isItProject: isItProject),
                    ITOkrView(projectId: projectId, projectName: projectName),
                    ITProjectDocsView(projectId: projectId, projectName: projectName),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  /// The line under the title: what the project is for, else what kind of project it is.
  static String _subtitle(Project? p) {
    if (p == null) return '';
    final d = p.description.trim();
    if (d.isNotEmpty) return d.split('\n').first;
    final dept = p.targetDepartment.trim();
    // The category (Software, Security …) is an IT notion that defaults to "Software" on every project, so only IT projects say it.
    if (dept.toLowerCase() == kItDepartment.toLowerCase()) return '${p.category.label} project · $dept';
    return dept.isEmpty ? '' : '$dept project';
  }

  static Widget _horizonBadge(int n) {
    final color = n == 2 ? const Color(0xFF7C3AED) : (n == 3 ? const Color(0xFFE11D48) : const Color(0xFF2563EB));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text('H$n', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
