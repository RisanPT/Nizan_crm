import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/domain/models/it_project_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_data_grid_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_interactive_gantt.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

enum ITRoadmapViewMode {
  timeline,
  spreadsheet;

  String get label => switch (this) {
        ITRoadmapViewMode.timeline => 'Timeline (Gantt)',
        ITRoadmapViewMode.spreadsheet => 'Spreadsheet (Grid)',
      };

  IconData get icon => switch (this) {
        ITRoadmapViewMode.timeline => Icons.timeline_outlined,
        ITRoadmapViewMode.spreadsheet => Icons.table_chart_outlined,
      };
}

class ITRoadmapScreen extends ConsumerStatefulWidget {
  const ITRoadmapScreen({super.key});

  @override
  ConsumerState<ITRoadmapScreen> createState() => _ITRoadmapScreenState();
}

class _ITRoadmapScreenState extends ConsumerState<ITRoadmapScreen> {
  ITRoadmapViewMode _viewMode = ITRoadmapViewMode.timeline;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final asyncTasks = ref.watch(itAllTasksControllerProvider);
    final filterState = ref.watch(itFilterProvider);
    final projects = ref.watch(itProjectsProvider).value ?? const <ITProjectModel>[];
    final itProjectIds = projects.map((p) => p.id).toSet();

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        // Top Main Header
        _buildHeader(crm),
        // Multi-Filter & Controls Toolbar
        _buildFilterToolbar(crm, filterState, projects),
        // Main Content Area
        Expanded(
          child: asyncTasks.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, size: 40, color: Colors.red.shade400),
                const SizedBox(height: 10),
                Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => ref.read(itAllTasksControllerProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ]),
            ),
            data: (allTasksRaw) {
              // Scope the IT Roadmap to IT-department projects only; company
              // (non-IT) projects live in the Company Projects portfolio.
              final allTasks = allTasksRaw.where((t) => itProjectIds.contains(t.projectId)).toList();
              final filtered = ref.watch(filteredTasksProvider(allTasks));
              return _viewMode == ITRoadmapViewMode.timeline
                  ? ITInteractiveGantt(
                      tasks: filtered,
                      allTasks: allTasks,
                      zoomScale: filterState.zoomScale,
                      swimlaneMode: filterState.swimlaneMode,
                    )
                  : ITDataGridView(
                      tasks: filtered,
                      allTasks: allTasks,
                    );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(CrmTheme crm) {
    final filterState = ref.watch(itFilterProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: Row(children: [
        Icon(Icons.terminal_outlined, color: crm.primary, size: 24),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'IT Engineering Roadmap',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary),
          ),
          Text(
            'Interactive Timeline, Dependency Blockers & Data Grid',
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
          ),
        ]),
        const Spacer(),
        // View Mode Switcher
        SegmentedButton<ITRoadmapViewMode>(
          segments: [
            for (final mode in ITRoadmapViewMode.values)
              ButtonSegment(
                value: mode,
                label: Text(mode.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                icon: Icon(mode.icon, size: 16),
              ),
          ],
          selected: {_viewMode},
          onSelectionChanged: (set) => setState(() => _viewMode = set.first),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: crm.primary.withValues(alpha: 0.12),
            selectedForegroundColor: crm.primary,
          ),
        ),
        const SizedBox(width: 14),
        // Zoom Scale selector (Visible in Timeline view)
        if (_viewMode == ITRoadmapViewMode.timeline) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: crm.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crm.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final scale in GanttZoomScale.values)
                InkWell(
                  onTap: () {
                    ref.read(itFilterProvider.notifier).setZoomScale(scale);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: filterState.zoomScale == scale ? crm.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      scale.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: filterState.zoomScale == scale ? Colors.white : crm.textSecondary,
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 14),
        ],
        // Refresh
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            ref.read(itAllTasksControllerProvider.notifier).refresh();
            ref.invalidate(itProjectsProvider);
            ref.invalidate(projectsProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
        // Add Task Action
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: crm.primary),
          onPressed: () => _openCreateTaskDialog(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Ticket'),
        ),
      ]),
    );
  }

  Widget _buildFilterToolbar(CrmTheme crm, ITFilterState filterState, List<ITProjectModel> projects) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // Sub-Team Filter Chips
          Text('Team:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary)),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('All Teams'),
            selected: filterState.selectedSubTeams.isEmpty,
            onSelected: (_) {
              ref.read(itFilterProvider.notifier).setSubTeams({});
            },
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: filterState.selectedSubTeams.isEmpty ? Colors.white : crm.textSecondary,
            ),
            selectedColor: crm.primary,
            backgroundColor: crm.surface,
            side: BorderSide(color: filterState.selectedSubTeams.isEmpty ? crm.primary : crm.border),
          ),
          const SizedBox(width: 6),
          for (final tm in ITSubTeam.values) ...[
            FilterChip(
              avatar: Icon(tm.icon, size: 14, color: filterState.selectedSubTeams.contains(tm) ? tm.color : crm.textSecondary),
              label: Text(tm.label),
              selected: filterState.selectedSubTeams.contains(tm),
              onSelected: (selected) {
                final updated = Set<ITSubTeam>.from(filterState.selectedSubTeams);
                if (selected) {
                  updated.add(tm);
                } else {
                  updated.remove(tm);
                }
                ref.read(itFilterProvider.notifier).setSubTeams(updated);
              },
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: filterState.selectedSubTeams.contains(tm) ? tm.color : crm.textPrimary,
              ),
              backgroundColor: crm.surface,
              selectedColor: tm.color.withValues(alpha: 0.14),
              side: BorderSide(color: filterState.selectedSubTeams.contains(tm) ? tm.color : crm.border),
            ),
            const SizedBox(width: 6),
          ],
          const VerticalDivider(width: 24, indent: 4, endIndent: 4),

          // Swimlane Mode Selector (if in Timeline view)
          if (_viewMode == ITRoadmapViewMode.timeline) ...[
            Text('Group by:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary)),
            const SizedBox(width: 8),
            DropdownButton<GanttSwimlaneMode>(
              value: filterState.swimlaneMode,
              isDense: true,
              underline: const SizedBox(),
              items: [
                for (final mode in GanttSwimlaneMode.values)
                  DropdownMenuItem(
                    value: mode,
                    child: Text(mode.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(itFilterProvider.notifier).setSwimlaneMode(mode);
                }
              },
            ),
            const VerticalDivider(width: 24, indent: 4, endIndent: 4),
          ],

          // Severity Filter
          PopupMenuButton<ITSeverity>(
            tooltip: 'Filter by Severity',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: filterState.selectedSeverities.isNotEmpty ? crm.primary.withValues(alpha: 0.1) : crm.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: filterState.selectedSeverities.isNotEmpty ? crm.primary : crm.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.flag_outlined, size: 14, color: filterState.selectedSeverities.isNotEmpty ? crm.primary : crm.textSecondary),
                const SizedBox(width: 6),
                Text(
                  filterState.selectedSeverities.isEmpty
                      ? 'Severity'
                      : 'Severity (${filterState.selectedSeverities.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: filterState.selectedSeverities.isNotEmpty ? crm.primary : crm.textPrimary,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 16),
              ]),
            ),
            onSelected: (sv) {
              final updated = Set<ITSeverity>.from(filterState.selectedSeverities);
              if (updated.contains(sv)) {
                updated.remove(sv);
              } else {
                updated.add(sv);
              }
              ref.read(itFilterProvider.notifier).setSeverities(updated);
            },
            itemBuilder: (_) => [
              for (final sv in ITSeverity.values)
                CheckedPopupMenuItem(
                  value: sv,
                  checked: filterState.selectedSeverities.contains(sv),
                  child: Text(sv.label, style: TextStyle(color: sv.color, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(width: 8),

          // Ticket Type Filter
          PopupMenuButton<ITTicketType>(
            tooltip: 'Filter by Ticket Type',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: filterState.selectedTicketTypes.isNotEmpty ? crm.primary.withValues(alpha: 0.1) : crm.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: filterState.selectedTicketTypes.isNotEmpty ? crm.primary : crm.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.category_outlined, size: 14, color: filterState.selectedTicketTypes.isNotEmpty ? crm.primary : crm.textSecondary),
                const SizedBox(width: 6),
                Text(
                  filterState.selectedTicketTypes.isEmpty
                      ? 'Type'
                      : 'Type (${filterState.selectedTicketTypes.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: filterState.selectedTicketTypes.isNotEmpty ? crm.primary : crm.textPrimary,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 16),
              ]),
            ),
            onSelected: (tt) {
              final updated = Set<ITTicketType>.from(filterState.selectedTicketTypes);
              if (updated.contains(tt)) {
                updated.remove(tt);
              } else {
                updated.add(tt);
              }
              ref.read(itFilterProvider.notifier).setTicketTypes(updated);
            },
            itemBuilder: (_) => [
              for (final tt in ITTicketType.values)
                CheckedPopupMenuItem(
                  value: tt,
                  checked: filterState.selectedTicketTypes.contains(tt),
                  child: Row(children: [
                    Icon(tt.icon, size: 14, color: tt.color),
                    const SizedBox(width: 8),
                    Text(tt.label),
                  ]),
                ),
            ],
          ),
          // Status Filter
          PopupMenuButton<ITTaskStatus>(
            tooltip: 'Filter by Status',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: filterState.selectedStatuses.isNotEmpty ? crm.primary.withValues(alpha: 0.1) : crm.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: filterState.selectedStatuses.isNotEmpty ? crm.primary : crm.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.checklist_rtl_outlined, size: 14, color: filterState.selectedStatuses.isNotEmpty ? crm.primary : crm.textSecondary),
                const SizedBox(width: 6),
                Text(
                  filterState.selectedStatuses.isEmpty
                      ? 'Status'
                      : 'Status (${filterState.selectedStatuses.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: filterState.selectedStatuses.isNotEmpty ? crm.primary : crm.textPrimary,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 16),
              ]),
            ),
            onSelected: (st) {
              final updated = Set<ITTaskStatus>.from(filterState.selectedStatuses);
              if (updated.contains(st)) {
                updated.remove(st);
              } else {
                updated.add(st);
              }
              ref.read(itFilterProvider.notifier).setStatuses(updated);
            },
            itemBuilder: (_) => [
              for (final st in ITTaskStatus.values)
                CheckedPopupMenuItem(
                  value: st,
                  checked: filterState.selectedStatuses.contains(st),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: st.color)),
                    const SizedBox(width: 8),
                    Text(st.label),
                  ]),
                ),
            ],
          ),
          const SizedBox(width: 8),

          // Project Filter
          if (projects.isNotEmpty) ...[
            PopupMenuButton<String>(
              tooltip: 'Filter by Project',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: filterState.selectedProjectIds.isNotEmpty ? crm.primary.withValues(alpha: 0.1) : crm.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: filterState.selectedProjectIds.isNotEmpty ? crm.primary : crm.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.folder_open, size: 14, color: filterState.selectedProjectIds.isNotEmpty ? crm.primary : crm.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    filterState.selectedProjectIds.isEmpty
                        ? 'Project'
                        : 'Projects (${filterState.selectedProjectIds.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: filterState.selectedProjectIds.isNotEmpty ? crm.primary : crm.textPrimary,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ]),
              ),
              onSelected: (pid) {
                final updated = Set<String>.from(filterState.selectedProjectIds);
                if (updated.contains(pid)) {
                  updated.remove(pid);
                } else {
                  updated.add(pid);
                }
                ref.read(itFilterProvider.notifier).setProjectIds(updated);
              },
              itemBuilder: (_) => [
                for (final p in projects)
                  CheckedPopupMenuItem(
                    value: p.id,
                    checked: filterState.selectedProjectIds.contains(p.id),
                    child: Text(p.name),
                  ),
              ],
            ),
            const SizedBox(width: 8),
          ],

          // Search Box
          SizedBox(
            width: 180,
            height: 34,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(itFilterProvider.notifier).setSearchQuery(val.trim());
              },
              decoration: InputDecoration(
                hintText: 'Search tickets...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(itFilterProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: crm.border)),
                isDense: true,
              ),
            ),
          ),

          // Clear Filters Action
          if (filterState.hasActiveFilters) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                ref.read(itFilterProvider.notifier).reset();
              },
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
            ),
          ],
        ]),
      ),
    );
  }

  void _openCreateTaskDialog() {
    final projects = ref.read(itProjectsProvider).value ?? const <ITProjectModel>[];
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a project first before adding tasks.')),
      );
      return;
    }
    final allTasks = ref.read(itAllTasksControllerProvider).value ?? const <ITTaskModel>[];
    showTaskEditor(context, ref, projects.first.id, allTasks: allTasks).then((saved) {
      if (saved == true) {
        ref.read(itAllTasksControllerProvider.notifier).refresh();
        ref.invalidate(itProjectsProvider);
        ref.invalidate(projectsProvider);
      }
    });
  }
}
