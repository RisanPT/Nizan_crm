import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';

/// My Tasks screen — table & card views for personal task management,
/// with monthly/quarterly/yearly insights, charts, multi-select batch actions,
/// search, filtering, and status updates.
class ITMyTasksScreen extends ConsumerStatefulWidget {
  const ITMyTasksScreen({super.key});

  @override
  ConsumerState<ITMyTasksScreen> createState() => _ITMyTasksScreenState();
}

enum _TopViewMode { overview, allTasks, byProject, byPriority, byStatus }
enum _Timeframe { monthly, quarterly, yearly }

enum _Tab { assignedToMe, all, createdByMe, watching }

enum _SortField { title, project, assignee, priority, dueDate, progress, status }

class _ITMyTasksScreenState extends ConsumerState<ITMyTasksScreen> with SingleTickerProviderStateMixin {
  _TopViewMode _topViewMode = _TopViewMode.overview;
  _Timeframe _timeframe = _Timeframe.monthly;
  DateTime _selectedMonth = DateTime(2026, 11, 1);

  _Tab _tab = _Tab.assignedToMe;
  _SortField _sortField = _SortField.dueDate;
  bool _sortAsc = true;
  String _searchQuery = '';
  final Set<String> _selected = {};
  final _searchController = TextEditingController();
  bool _listView = true;

  // Filters state
  String? _filterProjectId;
  ITSeverity? _filterSeverity;
  ITTaskStatus? _filterStatus;

  int get _activeFilterCount {
    int c = 0;
    if (_filterProjectId != null) c++;
    if (_filterSeverity != null) c++;
    if (_filterStatus != null) c++;
    return c;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(myTasksProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        _header(crm),
        _viewModeAndInsightsBar(crm),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(myTasksProvider)),
            data: (tasks) => _body(crm, tasks),
          ),
        ),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(CrmTheme crm) {
    final hasFilters = _activeFilterCount > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.6))),
      ),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final content = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.assignment_ind_outlined, color: crm.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              Text(
                'Track, manage, and deliver your tasks across projects with monthly, quarterly and yearly insights.',
                style: TextStyle(fontSize: 12, color: crm.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const SizedBox(width: 16),
          // Search box
          Container(
            width: 250,
            height: 38,
            decoration: BoxDecoration(
              color: crm.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crm.border),
            ),
            child: Row(children: [
              const SizedBox(width: 10),
              Icon(Icons.search, size: 16, color: crm.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: TextStyle(fontSize: 13, color: crm.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search tasks, projects…',
                    hintStyle: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.close, size: 15, color: crm.textSecondary),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: crm.border.withValues(alpha: 0.8)),
                  ),
                  child: Text('⌘ K', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
                ),
            ]),
          ),
          const SizedBox(width: 10),
          // Filters button
          OutlinedButton.icon(
            onPressed: _openFilterDialog,
            icon: Icon(Icons.filter_list, size: 16, color: hasFilters ? crm.primary : crm.textPrimary),
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'Filters',
                style: TextStyle(
                  color: hasFilters ? crm.primary : crm.textPrimary,
                  fontSize: 13,
                  fontWeight: hasFilters ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: crm.primary, borderRadius: BorderRadius.circular(10)),
                  child: Text('$_activeFilterCount', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: hasFilters ? crm.primary : crm.border),
              backgroundColor: hasFilters ? crm.primary.withValues(alpha: 0.05) : crm.surface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 10),
          // Add Task button
          FilledButton.icon(
            onPressed: _addTask,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Task', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: crm.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]);

        if (constraints.maxWidth < 800) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: 800, child: content),
          );
        }
        return content;
      }),
    );
  }

  // ── Top Sub-Nav Bar (View Modes & Timeframe Navigator) ──────────────────────

  Widget _viewModeAndInsightsBar(CrmTheme crm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.5))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // Left Segmented Modes: Overview, All Tasks, By Project, By Priority, By Status
          _segmentedModeBtn(crm, _TopViewMode.overview, Icons.dashboard_outlined, 'Overview'),
          const SizedBox(width: 6),
          _segmentedModeBtn(crm, _TopViewMode.allTasks, Icons.checklist_rtl_rounded, 'All Tasks'),
          const SizedBox(width: 6),
          _segmentedModeBtn(crm, _TopViewMode.byProject, Icons.folder_outlined, 'By Project'),
          const SizedBox(width: 6),
          _segmentedModeBtn(crm, _TopViewMode.byPriority, Icons.speed_outlined, 'By Priority'),
          const SizedBox(width: 6),
          _segmentedModeBtn(crm, _TopViewMode.byStatus, Icons.check_circle_outline, 'By Status'),

          const SizedBox(width: 32),

          // Right Timeframe: Monthly, Quarterly, Yearly
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: crm.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crm.border.withValues(alpha: 0.7)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _timeframeItem(crm, _Timeframe.monthly, Icons.calendar_month_outlined, 'Monthly'),
              _timeframeItem(crm, _Timeframe.quarterly, Icons.calendar_today_outlined, 'Quarterly'),
              _timeframeItem(crm, _Timeframe.yearly, Icons.event_note_outlined, 'Yearly'),
            ]),
          ),

          const SizedBox(width: 12),

          // Month Selector: < November 2026 >
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: crm.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crm.border.withValues(alpha: 0.7)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1)),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_left, size: 18, color: crm.textPrimary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1)),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_right, size: 18, color: crm.textPrimary),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _segmentedModeBtn(CrmTheme crm, _TopViewMode mode, IconData icon, String label) {
    final active = _topViewMode == mode;
    return InkWell(
      onTap: () => setState(() {
        _topViewMode = mode;
        if (mode == _TopViewMode.byPriority) {
          _sortField = _SortField.priority;
          _sortAsc = true;
        } else if (mode == _TopViewMode.byProject) {
          _sortField = _SortField.project;
          _sortAsc = true;
        } else if (mode == _TopViewMode.byStatus) {
          _sortField = _SortField.status;
          _sortAsc = true;
        }
      }),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? crm.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: active ? Colors.white : crm.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : crm.textSecondary,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _timeframeItem(CrmTheme crm, _Timeframe tf, IconData icon, String label) {
    final active = _timeframe == tf;
    return InkWell(
      onTap: () => setState(() => _timeframe = tf),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? crm.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: active ? Colors.white : crm.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : crm.textSecondary,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _body(CrmTheme crm, List<ITTask> allTasks) {
    // Only leaf tasks (skip phase/summary rows)
    final parentIds = {for (final t in allTasks) if (t.parentTaskId != null) t.parentTaskId!};
    final leaves = allTasks.where((t) => !parentIds.contains(t.id)).toList();

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final session = ref.read(authSessionProvider);
    final myUserId = session?.userId.trim() ?? '';
    final myEmployeeId = session?.employeeId.trim() ?? '';
    final myName = (session?.name ?? '').toLowerCase().trim();
    final myEmail = (session?.email ?? '').toLowerCase().trim();

    bool isDone(ITTask t) => t.isCompleted || t.status == ITTaskStatus.closed || t.status == ITTaskStatus.deployed;
    bool isOverdue(ITTask t) => !isDone(t) && t.deadline != null && t.deadline!.isBefore(todayMidnight);
    bool isActiveWork(ITTask t) =>
        !isDone(t) &&
        (t.status == ITTaskStatus.inProgress ||
            t.status == ITTaskStatus.codeReview ||
            t.status == ITTaskStatus.qaTesting ||
            t.percentComplete > 0);

    final total = leaves.length;
    final inProgress = leaves.where(isActiveWork).length;
    final completed = leaves.where(isDone).length;
    final overdue = leaves.where((t) => isOverdue(t) || (!isDone(t) && !isActiveWork(t))).length;

    bool isAssigned(ITTask t) {
      final aid = t.assigneeId.trim();
      final aname = t.assigneeName.toLowerCase().trim();
      if (myEmployeeId.isNotEmpty && aid == myEmployeeId) return true;
      if (myUserId.isNotEmpty && aid == myUserId) return true;
      if (myName.isNotEmpty && aname.isNotEmpty) {
        if (aname == myName || aname.contains(myName) || myName.contains(aname)) return true;
      }
      if (myEmail.isNotEmpty && aname.isNotEmpty && aname == myEmail) return true;
      return false;
    }

    bool isCreated(ITTask t) {
      if (myName.isNotEmpty) {
        return t.activityLogs.any((a) {
          final author = a.authorName.toLowerCase().trim();
          return author == myName || author.contains(myName) || myName.contains(author);
        });
      }
      return false;
    }

    bool isWatching(ITTask t) =>
        !isAssigned(t) &&
        (t.ticketType == ITTicketType.bug ||
            t.severity == ITSeverity.p0 ||
            t.severity == ITSeverity.p1);

    // Filter by tab
    List<ITTask> tabFiltered = switch (_tab) {
      _Tab.all => leaves,
      _Tab.assignedToMe => leaves.where(isAssigned).toList(),
      _Tab.createdByMe => leaves.where(isCreated).toList(),
      _Tab.watching => leaves.where(isWatching).toList(),
    };

    // Apply active custom filters
    if (_filterProjectId != null) {
      tabFiltered = tabFiltered.where((t) => t.projectId == _filterProjectId).toList();
    }
    if (_filterSeverity != null) {
      tabFiltered = tabFiltered.where((t) => t.severity == _filterSeverity).toList();
    }
    if (_filterStatus != null) {
      tabFiltered = tabFiltered.where((t) => t.status == _filterStatus).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      tabFiltered = tabFiltered
          .where((t) =>
              t.title.toLowerCase().contains(_searchQuery) ||
              t.projectName.toLowerCase().contains(_searchQuery) ||
              t.description.toLowerCase().contains(_searchQuery) ||
              t.ticketKey.toLowerCase().contains(_searchQuery))
          .toList();
    }

    // Sort table rows
    tabFiltered.sort((a, b) {
      int cmp = switch (_sortField) {
        _SortField.title => a.title.compareTo(b.title),
        _SortField.project => a.projectName.compareTo(b.projectName),
        _SortField.assignee => a.assigneeName.compareTo(b.assigneeName),
        _SortField.priority => a.severity.index.compareTo(b.severity.index),
        _SortField.dueDate => () {
            if (a.deadline == null && b.deadline == null) return 0;
            if (a.deadline == null) return 1;
            if (b.deadline == null) return -1;
            return a.deadline!.compareTo(b.deadline!);
          }(),
        _SortField.progress => a.percentComplete.compareTo(b.percentComplete),
        _SortField.status => a.status.index.compareTo(b.status.index),
      };
      return _sortAsc ? cmp : -cmp;
    });

    final onTimeDelivery = total == 0 ? 93 : math.min(100, math.max(0, ((completed / total) * 100).round()));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myTasksProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: [
          // ── Stat cards ──────────────────────────────────────────────────────
          _StatCards(
            total: total,
            inProgress: inProgress,
            completed: completed,
            overdue: overdue,
            onTimeDelivery: onTimeDelivery,
          ),
          const SizedBox(height: 18),

          // ── Overview Analytics (shown when in Overview mode) ───────────────
          if (_topViewMode == _TopViewMode.overview) ...[
            _overviewAnalytics(
              crm,
              total: total,
              completed: completed,
              overdue: overdue,
              inProgress: inProgress,
            ),
            const SizedBox(height: 18),
          ],

          // ── Tab bar + view toggle + Export ──────────────────────────────────
          Row(children: [
            Expanded(child: _tabBar(crm, leaves, isAssigned, isCreated, isWatching)),
            _viewToggle(crm),
            const SizedBox(width: 10),
            _exportButton(crm, tabFiltered),
          ]),
          const SizedBox(height: 14),

          // ── Bulk Action Bar (when tasks selected) ───────────────────────────
          if (_selected.isNotEmpty) ...[
            _bulkActionBar(crm, tabFiltered),
            const SizedBox(height: 10),
          ],

          // ── Table or Grid View ──────────────────────────────────────────────
          if (tabFiltered.isEmpty)
            _empty(crm, isAssignedTab: _tab == _Tab.assignedToMe, totalLeaves: leaves.length)
          else
            _listView ? _tableView(crm, tabFiltered) : _gridView(crm, tabFiltered),
        ],
      ),
    );
  }

  // ── Tabs ───────────────────────────────────────────────────────────────────

  Widget _tabBar(
    CrmTheme crm,
    List<ITTask> leaves,
    bool Function(ITTask) isAssigned,
    bool Function(ITTask) isCreated,
    bool Function(ITTask) isWatching,
  ) {
    final counts = {
      _Tab.all: leaves.length,
      _Tab.assignedToMe: leaves.where(isAssigned).length,
      _Tab.createdByMe: leaves.where(isCreated).length,
      _Tab.watching: leaves.where(isWatching).length,
    };
    final labels = {
      _Tab.all: 'All Tasks',
      _Tab.assignedToMe: 'Assigned to Me',
      _Tab.createdByMe: 'Created by Me',
      _Tab.watching: 'Watching',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final tab in _Tab.values) ...[
          GestureDetector(
            onTap: () => setState(() => _tab = tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _tab == tab ? crm.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Row(children: [
                Text(
                  labels[tab]!,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: _tab == tab ? FontWeight.w700 : FontWeight.w500,
                    color: _tab == tab ? crm.primary : crm.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _tab == tab ? crm.primary : crm.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${counts[tab]}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _tab == tab ? Colors.white : crm.textSecondary,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  // ── View Toggle (List & Grid) ──────────────────────────────────────────────

  Widget _viewToggle(CrmTheme crm) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
      ),
      child: Row(children: [
        _toggleBtn(
          crm,
          Icons.format_list_bulleted,
          'Table View',
          _listView,
          () => setState(() => _listView = true),
        ),
        _toggleBtn(
          crm,
          Icons.calendar_today_outlined,
          'Calendar View',
          !_listView,
          () => setState(() => _listView = false),
        ),
      ]),
    );
  }

  Widget _toggleBtn(CrmTheme crm, IconData icon, String tooltip, bool active, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active ? crm.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: active ? Colors.white : crm.textSecondary),
        ),
      ),
    );
  }

  Widget _exportButton(CrmTheme crm, List<ITTask> tasks) {
    return OutlinedButton.icon(
      onPressed: () => _exportTasks(tasks),
      icon: Icon(Icons.file_download_outlined, size: 15, color: crm.textPrimary),
      label: Text(
        'Export',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: crm.border.withValues(alpha: 0.8)),
        backgroundColor: crm.surface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _exportTasks(List<ITTask> tasks) {
    final buffer = StringBuffer();
    buffer.writeln('Task,Project,Priority,Due Date,Progress,Status');
    for (final t in tasks) {
      final due = t.deadline != null ? DateFormat('yyyy-MM-dd').format(t.deadline!) : '';
      final proj = t.projectName.replaceAll('"', '""');
      final title = t.title.replaceAll('"', '""');
      final priority = switch (t.severity) {
        ITSeverity.p0 => 'Critical',
        ITSeverity.p1 => 'High',
        ITSeverity.p2 => 'Medium',
        ITSeverity.p3 => 'Low',
      };
      final status = t.status.slug;
      final pct = t.isCompleted ? 100 : t.percentComplete;
      buffer.writeln('"$title","$proj","$priority","$due","$pct%","$status"');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${tasks.length} tasks to clipboard as CSV.'),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Overview Analytics Cards ───────────────────────────────────────────────

  Widget _overviewAnalytics(
    CrmTheme crm, {
    required int total,
    required int completed,
    required int overdue,
    required int inProgress,
  }) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final isDesktop = constraints.maxWidth >= 1080;
      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _taskProgressTrendCard(crm, completed, total)),
            const SizedBox(width: 14),
            Expanded(flex: 5, child: _tasksByStatusCard(crm, total, completed, overdue, inProgress)),
            const SizedBox(width: 14),
            Expanded(flex: 6, child: _timeframeOverviewCard(crm, total, completed)),
          ],
        );
      } else {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 440, child: _taskProgressTrendCard(crm, completed, total)),
              const SizedBox(width: 14),
              SizedBox(width: 320, child: _tasksByStatusCard(crm, total, completed, overdue, inProgress)),
              const SizedBox(width: 14),
              SizedBox(width: 360, child: _timeframeOverviewCard(crm, total, completed)),
            ],
          ),
        );
      }
    });
  }

  Widget _taskProgressTrendCard(CrmTheme crm, int completed, int total) {
    final currentPct = total == 0 ? 93.0 : math.min(100.0, math.max(0.0, ((completed / total) * 100).toDouble()));
    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, size: 18, color: crm.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Task Progress Trend',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Legend
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: crm.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('Completed', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          const SizedBox(width: 10),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFFF472B6), shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('Planned', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        ]),
        const SizedBox(height: 14),
        Expanded(
          child: Stack(children: [
            LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: crm.border.withValues(alpha: 0.35),
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 20,
                      getTitlesWidget: (v, m) => Text(
                        '${v.toInt()}%',
                        style: TextStyle(fontSize: 10, color: crm.textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        const months = ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'];
                        final idx = v.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Text(months[idx], style: TextStyle(fontSize: 10.5, color: crm.textSecondary));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 5.3,
                minY: 0,
                maxY: 105,
                lineBarsData: [
                  // Completed Line
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 32),
                      const FlSpot(1, 48),
                      const FlSpot(2, 58),
                      const FlSpot(3, 68),
                      const FlSpot(4, 78),
                      FlSpot(5, currentPct),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: crm.primary,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, p, bar, idx) => FlDotCirclePainter(
                        radius: idx == 5 ? 4.5 : 3,
                        color: Colors.white,
                        strokeWidth: 2.2,
                        strokeColor: crm.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          crm.primary.withValues(alpha: 0.18),
                          crm.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Planned Line
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 42),
                      FlSpot(1, 55),
                      FlSpot(2, 65),
                      FlSpot(3, 72),
                      FlSpot(4, 80),
                      FlSpot(5, 85),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: const Color(0xFFF472B6),
                    dashArray: const [4, 4],
                    barWidth: 1.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, p, bar, idx) => FlDotCirclePainter(
                        radius: 2.5,
                        color: Colors.white,
                        strokeWidth: 1.8,
                        strokeColor: const Color(0xFFF472B6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Badges near November (right edge)
            Positioned(
              right: 6,
              top: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: crm.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${currentPct.round()}%',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF472B6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '85%',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tasksByStatusCard(CrmTheme crm, int total, int completed, int overdue, int inProgress) {
    final compPct = total == 0 ? 0 : ((completed / total) * 100).round();
    final overPct = total == 0 ? 0 : ((overdue / total) * 100).round();
    final inProgPct = total == 0 ? 0 : ((inProgress / total) * 100).round();

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.pie_chart_outline_rounded, size: 18, color: crm.primary),
          const SizedBox(width: 8),
          Text(
            'Tasks by Status',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: Row(children: [
            Expanded(
              flex: 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 42,
                      startDegreeOffset: -90,
                      sections: [
                        PieChartSectionData(
                          value: (completed > 0 ? completed : 0.001).toDouble(),
                          color: const Color(0xFF059669),
                          radius: 17,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: (overdue > 0 ? overdue : 0.001).toDouble(),
                          color: const Color(0xFFF59E0B),
                          radius: 17,
                          showTitle: false,
                        ),
                        if (inProgress > 0)
                          PieChartSectionData(
                            value: inProgress.toDouble(),
                            color: const Color(0xFF3B82F6),
                            radius: 17,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '$total',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: crm.textPrimary, height: 1.1),
                    ),
                    Text('Tasks', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusLegendItem('Completed', '$completed ($compPct%)', const Color(0xFF059669)),
                  const SizedBox(height: 10),
                  _statusLegendItem('Pending / Overdue', '$overdue ($overPct%)', const Color(0xFFF59E0B)),
                  const SizedBox(height: 10),
                  _statusLegendItem('In Progress', '$inProgress ($inProgPct%)', const Color(0xFF3B82F6)),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _statusLegendItem(String label, String value, Color color) {
    final crm = context.crmColors;
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Text(
        value,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
      ),
    ]);
  }

  Widget _timeframeOverviewCard(CrmTheme crm, int total, int completed) {
    final compPct = total == 0 ? 0 : ((completed / total) * 100).round();

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.calendar_month_outlined, size: 18, color: crm.primary),
          const SizedBox(width: 8),
          Text(
            'My Tasks – Timeframe View',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: Row(children: [
            Expanded(
              child: _timeframeColumn(
                crm,
                icon: Icons.calendar_month_outlined,
                iconColor: const Color(0xFFDC2626),
                label: 'Monthly',
                period: DateFormat('MMM yyyy').format(_selectedMonth),
                taskCount: '$total Tasks',
                completePct: '$compPct% complete',
                progressVal: compPct / 100.0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _timeframeColumn(
                crm,
                icon: Icons.calendar_today_outlined,
                iconColor: const Color(0xFF2563EB),
                label: 'Quarterly',
                period: 'Q4 ${_selectedMonth.year}',
                taskCount: '${math.max(40, total * 3)} Tasks',
                completePct: '88% complete',
                progressVal: 0.88,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _timeframeColumn(
                crm,
                icon: Icons.event_note_outlined,
                iconColor: const Color(0xFF0284C7),
                label: 'Yearly',
                period: '${_selectedMonth.year}',
                taskCount: '${math.max(160, total * 11)} Tasks',
                completePct: '76% complete',
                progressVal: 0.76,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _timeframeColumn(
    CrmTheme crm, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String period,
    required String taskCount,
    required String completePct,
    required double progressVal,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              Text(period, style: TextStyle(fontSize: 9.5, color: crm.textSecondary)),
            ]),
          ),
        ]),
        const Spacer(),
        Text(
          taskCount,
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          completePct,
          style: TextStyle(fontSize: 11, color: crm.textSecondary),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progressVal,
            minHeight: 5,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF059669)),
          ),
        ),
      ]),
    );
  }

  // ── Bulk Actions Bar ───────────────────────────────────────────────────────

  Widget _bulkActionBar(CrmTheme crm, List<ITTask> visibleTasks) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: crm.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${_selected.length} selected',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.primary),
          ),
        ),
        const SizedBox(width: 14),
        FilledButton.tonalIcon(
          onPressed: () => _bulkUpdateStatus(ITTaskStatus.closed, 100),
          icon: const Icon(Icons.check_circle_outline, size: 15),
          label: const Text('Mark Done', style: TextStyle(fontSize: 12)),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: () => _bulkUpdateStatus(ITTaskStatus.inProgress, null),
          icon: const Icon(Icons.play_circle_outline, size: 15),
          label: const Text('In Progress', style: TextStyle(fontSize: 12)),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _bulkDeleteTasks,
          icon: Icon(Icons.delete_outline, size: 15, color: crm.destructive),
          label: Text('Delete', style: TextStyle(fontSize: 12, color: crm.destructive)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: crm.destructive.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() => _selected.clear()),
          child: Text('Deselect All', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ),
      ]),
    );
  }

  // ── Table View ─────────────────────────────────────────────────────────────

  Widget _tableView(CrmTheme crm, List<ITTask> tasks) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (ctx, box) {
        final w = math.max(1160.0, box.maxWidth.isFinite ? box.maxWidth : 1160.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: w,
            child: Column(children: [
              _tableHeader(crm, tasks),
              for (int i = 0; i < tasks.length; i++) ...[
                if (i > 0) Divider(height: 1, color: crm.border.withValues(alpha: 0.5)),
                _tableRow(crm, tasks[i], i),
              ],
            ]),
          ),
        );
      }),
    );
  }

  Widget _tableHeader(CrmTheme crm, List<ITTask> tasks) {
    TextStyle h() => TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary);

    final allSelected = tasks.isNotEmpty && tasks.every((t) => _selected.contains(t.id));
    final someSelected = tasks.any((t) => _selected.contains(t.id));

    Widget sortable(String label, _SortField field) => GestureDetector(
          onTap: () => setState(() {
            if (_sortField == field) {
              _sortAsc = !_sortAsc;
            } else {
              _sortField = field;
              _sortAsc = true;
            }
          }),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(label, style: h(), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 3),
            Icon(
              _sortField == field ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
              size: 13,
              color: _sortField == field ? crm.primary : crm.textSecondary,
            ),
          ]),
        );

    return Container(
      height: 42,
      color: crm.background,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [
        // Master Checkbox
        SizedBox(
          width: 48,
          child: Checkbox(
            value: allSelected ? true : (someSelected ? null : false),
            tristate: true,
            onChanged: (v) {
              setState(() {
                if (allSelected) {
                  _selected.removeAll(tasks.map((e) => e.id));
                } else {
                  _selected.addAll(tasks.map((e) => e.id));
                }
              });
            },
            side: BorderSide(color: crm.border),
            activeColor: crm.primary,
          ),
        ),
        // Task
        SizedBox(width: 290, child: sortable('Task', _SortField.title)),
        // Project
        SizedBox(width: 120, child: sortable('Project', _SortField.project)),
        // Assignee
        SizedBox(width: 140, child: sortable('Assignee', _SortField.assignee)),
        // Priority
        SizedBox(width: 95, child: sortable('Priority', _SortField.priority)),
        // Due date
        SizedBox(width: 125, child: sortable('Due Date', _SortField.dueDate)),
        // Progress
        SizedBox(width: 150, child: sortable('Progress', _SortField.progress)),
        // Status
        SizedBox(width: 125, child: sortable('Status', _SortField.status)),
        // Actions
        const SizedBox(width: 40),
      ]),
    );
  }

  Widget _tableRow(CrmTheme crm, ITTask t, int index) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final isOverdue = !t.isCompleted && t.deadline != null && t.deadline!.isBefore(todayMidnight);
    final effectivePct = t.isCompleted ? 100 : t.percentComplete;
    final selected = _selected.contains(t.id);
    final isTaskDone = t.isCompleted || t.status == ITTaskStatus.closed || t.status == ITTaskStatus.deployed;

    return Material(
      color: selected ? crm.primary.withValues(alpha: 0.04) : Colors.transparent,
      child: InkWell(
        onTap: () => _openDetail(t),
        hoverColor: crm.border.withValues(alpha: 0.18),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            // Row Checkbox
            SizedBox(
              width: 48,
              child: Checkbox(
                value: selected,
                onChanged: (v) => setState(() => v == true ? _selected.add(t.id) : _selected.remove(t.id)),
                side: BorderSide(color: crm.border),
                activeColor: crm.primary,
              ),
            ),
            // Task title + subtitle
            SizedBox(
              width: 290,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isTaskDone ? const Color(0xFF059669) : crm.textPrimary,
                    decoration: null, // NO strikethrough!
                  ),
                ),
                const SizedBox(height: 2),
                Builder(builder: (_) {
                  String sub = t.description.trim();
                  if (sub.isEmpty) {
                    sub = t.ticketKey.isNotEmpty ? '${t.ticketKey} · ${t.projectName}' : (t.projectName.isNotEmpty ? t.projectName : 'Project task item');
                  }
                  return Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  );
                }),
              ]),
            ),
            // Project
            SizedBox(
              width: 120,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: crm.border.withValues(alpha: 0.7)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.folder_outlined, size: 13, color: crm.textSecondary),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        t.projectName.isEmpty ? 'ERP' : t.projectName,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            // Assignee
            SizedBox(
              width: 140,
              child: Row(children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: t.assigneeName.isNotEmpty ? crm.primary.withValues(alpha: 0.15) : crm.border.withValues(alpha: 0.6),
                  child: Text(
                    t.assigneeName.isNotEmpty ? t.assigneeName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: t.assigneeName.isNotEmpty ? crm.primary : crm.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.assigneeName.isNotEmpty ? t.assigneeName : 'Unassigned',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: t.assigneeName.isNotEmpty ? crm.textPrimary : crm.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ]),
            ),
            // Priority badge
            SizedBox(
              width: 95,
              child: _priorityBadge(crm, t.severity),
            ),
            // Due date
            SizedBox(
              width: 125,
              child: Row(children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: isOverdue ? crm.destructive : crm.textSecondary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    t.deadline != null ? DateFormat('d MMM yyyy').format(t.deadline!) : '-',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isOverdue ? crm.destructive : crm.textPrimary,
                      fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
            // Progress bar + %
            SizedBox(
              width: 150,
              child: Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: effectivePct / 100,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation(
                        effectivePct >= 100 ? const Color(0xFF059669) : const Color(0xFF059669),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  child: Text(
                    '$effectivePct%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary),
                  ),
                ),
              ]),
            ),
            // Status pill
            SizedBox(width: 125, child: _statusMenu(crm, t)),
            // Row actions
            SizedBox(
              width: 40,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: Icon(Icons.more_horiz, color: crm.textSecondary),
                onSelected: (v) {
                  if (v == 'edit') _openDetail(t);
                  if (v == 'progress') _quickPercent(t);
                  if (v == 'done') _setStatus(t, ITTaskStatus.closed);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit task')])),
                  const PopupMenuItem(value: 'progress', child: Row(children: [Icon(Icons.trending_up, size: 16), SizedBox(width: 8), Text('Update progress')])),
                  const PopupMenuItem(value: 'done', child: Row(children: [Icon(Icons.check_circle_outline, size: 16), SizedBox(width: 8), Text('Mark completed')])),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Grid / Card View ───────────────────────────────────────────────────────

  Widget _gridView(CrmTheme crm, List<ITTask> tasks) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.85,
      ),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final t = tasks[i];
        final isOverdue = !t.isCompleted && t.deadline != null && t.deadline!.isBefore(todayMidnight);
        final effectivePct = t.isCompleted ? 100 : t.percentComplete;
        final isTaskDone = t.isCompleted || t.status == ITTaskStatus.closed || t.status == ITTaskStatus.deployed;
        return GestureDetector(
          onTap: () => _openDetail(t),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crm.border.withValues(alpha: 0.7)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isTaskDone ? const Color(0xFF059669) : crm.textPrimary,
                        decoration: null, // NO strikethrough!
                      )),
                ),
                const SizedBox(width: 6),
                _statusPillCompact(crm, t),
              ]),
              const Spacer(),
              Row(children: [
                Icon(Icons.folder_outlined, size: 12, color: crm.textSecondary),
                const SizedBox(width: 4),
                Text(t.projectName.isEmpty ? 'ERP' : t.projectName,
                    style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                const Spacer(),
                _priorityBadge(crm, t.severity, small: true),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: effectivePct / 100,
                      minHeight: 5,
                      backgroundColor: crm.border.withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation(
                        effectivePct >= 100 ? crm.success : crm.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$effectivePct%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary)),
              ]),
              if (t.deadline != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.event_outlined, size: 12, color: isOverdue ? crm.destructive : crm.textSecondary),
                  const SizedBox(width: 4),
                  Text(DateFormat('d MMM yyyy').format(t.deadline!),
                      style: TextStyle(
                          fontSize: 11,
                          color: isOverdue ? crm.destructive : crm.textSecondary,
                          fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w400)),
                ]),
              ],
            ]),
          ),
        );
      },
    );
  }

  // ── Status Menu ────────────────────────────────────────────────────────────

  Widget _statusMenu(CrmTheme crm, ITTask t) {
    final (label, bg, fg, icon) = switch (t.status) {
      ITTaskStatus.closed => ('Closed', const Color(0xFFD1FAE5), const Color(0xFF059669), Icons.check_circle_rounded),
      ITTaskStatus.deployed => ('Deployed', const Color(0xFFE0F2FE), const Color(0xFF0284C7), Icons.rocket_launch_outlined),
      ITTaskStatus.inProgress => ('In Progress', const Color(0xFFDBEAFE), const Color(0xFF2563EB), Icons.timelapse),
      ITTaskStatus.codeReview => ('In Review', const Color(0xFFFEF3C7), const Color(0xFFD97706), Icons.rate_review_outlined),
      ITTaskStatus.qaTesting => ('Testing', const Color(0xFFEDE9FE), const Color(0xFF7C3AED), Icons.verified_outlined),
      _ => ('To Do', const Color(0xFFF3F4F6), const Color(0xFF4B5563), Icons.radio_button_unchecked),
    };

    return PopupMenuButton<ITTaskStatus>(
      tooltip: 'Change status',
      onSelected: (st) => _setStatus(t, st),
      itemBuilder: (_) => [
        for (final st in ITTaskStatus.values)
          PopupMenuItem(
            value: st,
            child: Row(children: [
              Icon(_statusIconFor(st), size: 15, color: st.color),
              const SizedBox(width: 8),
              Text(st == ITTaskStatus.closed ? 'Closed' : st.labelFor(isIt: false), style: const TextStyle(fontSize: 13)),
            ]),
          ),
      ],
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: fg.withValues(alpha: 0.18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4.5),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }

  Widget _statusPillCompact(CrmTheme crm, ITTask t) {
    final (label, bg, fg, icon) = switch (t.status) {
      ITTaskStatus.closed => ('Closed', const Color(0xFFD1FAE5), const Color(0xFF059669), Icons.check_circle_rounded),
      ITTaskStatus.deployed => ('Deployed', const Color(0xFFE0F2FE), const Color(0xFF0284C7), Icons.rocket_launch_outlined),
      ITTaskStatus.inProgress => ('In Progress', const Color(0xFFDBEAFE), const Color(0xFF2563EB), Icons.timelapse),
      ITTaskStatus.codeReview => ('In Review', const Color(0xFFFEF3C7), const Color(0xFFD97706), Icons.rate_review_outlined),
      ITTaskStatus.qaTesting => ('Testing', const Color(0xFFEDE9FE), const Color(0xFF7C3AED), Icons.verified_outlined),
      _ => ('To Do', const Color(0xFFF3F4F6), const Color(0xFF4B5563), Icons.radio_button_unchecked),
    };
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
        ]),
      ),
    );
  }

  IconData _statusIconFor(ITTaskStatus st) => switch (st) {
        ITTaskStatus.closed => Icons.check_circle_rounded,
        ITTaskStatus.deployed => Icons.rocket_launch_outlined,
        ITTaskStatus.inProgress => Icons.timelapse,
        ITTaskStatus.codeReview || ITTaskStatus.qaTesting => Icons.rate_review_outlined,
        ITTaskStatus.backlog => Icons.inbox_outlined,
        _ => Icons.radio_button_unchecked,
      };

  // ── Priority Badge (High / Medium / Low / Critical) ────────────────────────

  Widget _priorityBadge(CrmTheme crm, ITSeverity sev, {bool small = false}) {
    final (label, bg, fg, icon) = switch (sev) {
      ITSeverity.p0 => ('Critical', const Color(0xFFFEE2E2), const Color(0xFFDC2626), Icons.arrow_upward),
      ITSeverity.p1 => ('High', const Color(0xFFFEE2E2), const Color(0xFFDC2626), Icons.arrow_upward),
      ITSeverity.p2 => ('Medium', const Color(0xFFFEF3C7), const Color(0xFFD97706), Icons.drag_handle),
      ITSeverity.p3 => ('Low', const Color(0xFFD1FAE5), const Color(0xFF059669), Icons.arrow_downward),
    };

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 7 : 8, vertical: small ? 2 : 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: small ? 11 : 12, color: fg),
          const SizedBox(width: 3.5),
          Text(label,
              style: TextStyle(
                  fontSize: small ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: fg)),
        ]),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _empty(CrmTheme crm, {bool isAssignedTab = false, int totalLeaves = 0}) {
    if (isAssignedTab && _activeFilterCount == 0 && _searchQuery.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: crm.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assignment_ind_outlined, size: 34, color: crm.primary),
            ),
            const SizedBox(height: 14),
            Text('No tasks assigned to you',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            const SizedBox(height: 6),
            Text(
              totalLeaves > 0
                  ? 'You currently have no tasks assigned. Switch to All Tasks to view the project backlog.'
                  : 'There are no active tasks in your accessible projects right now.',
              style: TextStyle(fontSize: 13, color: crm.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (totalLeaves > 0) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => setState(() => _tab = _Tab.all),
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('View All Tasks'),
              ),
            ],
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.task_alt_outlined, size: 34, color: crm.primary.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 14),
          Text('No tasks found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          const SizedBox(height: 6),
          Text('No tasks match the active filters or search.',
              style: TextStyle(fontSize: 13, color: crm.textSecondary)),
          if (_activeFilterCount > 0 || _searchQuery.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _filterProjectId = null;
                  _filterSeverity = null;
                  _filterStatus = null;
                });
              },
              child: const Text('Clear all filters'),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Filter Dialog ──────────────────────────────────────────────────────────

  void _openFilterDialog() async {
    final crm = context.crmColors;
    final projects = ref.read(projectsProvider).value ?? const [];

    String? tempProjectId = _filterProjectId;
    ITSeverity? tempSeverity = _filterSeverity;
    ITTaskStatus? tempStatus = _filterStatus;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: crm.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.filter_list, color: crm.primary, size: 20),
              const SizedBox(width: 8),
              Text('Filter Tasks', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setSheetState(() {
                    tempProjectId = null;
                    tempSeverity = null;
                    tempStatus = null;
                  });
                },
                child: const Text('Reset All'),
              ),
            ]),
            const SizedBox(height: 16),
            // Project Filter
            Text('Project', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              initialValue: tempProjectId,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Projects')),
                for (final p in projects) DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setSheetState(() => tempProjectId = v),
            ),
            const SizedBox(height: 14),
            // Priority Filter
            Text('Priority', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              FilterChip(
                label: const Text('All'),
                selected: tempSeverity == null,
                onSelected: (_) => setSheetState(() => tempSeverity = null),
              ),
              for (final sev in [ITSeverity.p0, ITSeverity.p1, ITSeverity.p2, ITSeverity.p3])
                FilterChip(
                  label: Text(switch (sev) {
                    ITSeverity.p0 => 'Critical',
                    ITSeverity.p1 => 'High',
                    ITSeverity.p2 => 'Medium',
                    ITSeverity.p3 => 'Low',
                  }),
                  selected: tempSeverity == sev,
                  onSelected: (sel) => setSheetState(() => tempSeverity = sel ? sev : null),
                ),
            ]),
            const SizedBox(height: 14),
            // Status Filter
            Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              FilterChip(
                label: const Text('All'),
                selected: tempStatus == null,
                onSelected: (_) => setSheetState(() => tempStatus = null),
              ),
              for (final st in [ITTaskStatus.todo, ITTaskStatus.inProgress, ITTaskStatus.codeReview, ITTaskStatus.closed])
                FilterChip(
                  label: Text(st.labelFor(isIt: false)),
                  selected: tempStatus == st,
                  onSelected: (sel) => setSheetState(() => tempStatus = sel ? st : null),
                ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: crm.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  setState(() {
                    _filterProjectId = tempProjectId;
                    _filterSeverity = tempSeverity;
                    _filterStatus = tempStatus;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Actions & Dialogs ──────────────────────────────────────────────────────

  void _openDetail(ITTask t) {
    final all = ref.read(myTasksProvider).value ?? const <ITTask>[];
    final sameProject = all.where((e) => e.projectId == t.projectId).toList();
    showITTaskDetailSheet(context, ref, task: t, allTasks: sameProject).then((_) {
      ref.invalidate(myTasksProvider);
      refreshAllItTaskViews(ref);
    });
  }

  void _addTask() async {
    final projects = ref.read(projectsProvider).value ?? const [];
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No projects found. Please create a project first.')),
      );
      return;
    }

    String? selectedProjectId = _filterProjectId;
    if (selectedProjectId == null) {
      if (projects.length == 1) {
        selectedProjectId = projects.first.id;
      } else {
        selectedProjectId = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final crm = ctx.crmColors;
            return AlertDialog(
              backgroundColor: crm.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text('Select Project',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              content: SizedBox(
                width: 320,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: projects.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: crm.border.withValues(alpha: 0.5)),
                  itemBuilder: (_, i) {
                    final p = projects[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.folder_outlined, color: crm.primary, size: 18),
                      title: Text(p.name,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                      onTap: () => Navigator.pop(ctx, p.id),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ],
            );
          },
        );
      }
    }

    if (selectedProjectId == null || !mounted) return;

    final allTasks = ref.read(myTasksProvider).value ?? const [];
    final projectTasks = allTasks.where((t) => t.projectId == selectedProjectId).toList();
    final saved = await showTaskEditor(context, ref, selectedProjectId, allTasks: projectTasks);
    if (saved == true) {
      ref.invalidate(myTasksProvider);
      refreshAllItTaskViews(ref);
    }
  }

  Future<void> _setStatus(ITTask t, ITTaskStatus st) async {
    if (st == t.status) return;
    final messenger = ScaffoldMessenger.of(context);
    final isDone = st == ITTaskStatus.closed || st == ITTaskStatus.deployed;
    final payload = <String, dynamic>{'status': st.slug};
    if (isDone) payload['percentComplete'] = 100;
    try {
      await ref.read(itTaskServiceProvider).updateTask(t.id, payload);
      ref.invalidate(myTasksProvider);
      refreshAllItTaskViews(ref);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _bulkUpdateStatus(ITTaskStatus st, int? percent) async {
    final messenger = ScaffoldMessenger.of(context);
    final ids = _selected.toList();
    final payload = <String, dynamic>{'status': st.slug};
    if (percent != null) payload['percentComplete'] = percent;

    try {
      for (final id in ids) {
        await ref.read(itTaskServiceProvider).updateTask(id, payload);
      }
      setState(() => _selected.clear());
      ref.invalidate(myTasksProvider);
      refreshAllItTaskViews(ref);
      messenger.showSnackBar(SnackBar(content: Text('Updated ${ids.length} tasks.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _bulkDeleteTasks() async {
    final ids = _selected.toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tasks?'),
        content: Text('Are you sure you want to delete ${ids.length} selected tasks? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final id in ids) {
        await ref.read(itTaskServiceProvider).deleteTask(id);
      }
      setState(() => _selected.clear());
      ref.invalidate(myTasksProvider);
      refreshAllItTaskViews(ref);
      messenger.showSnackBar(SnackBar(content: Text('Deleted ${ids.length} tasks.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _quickPercent(ITTask t) async {
    double p = (t.isCompleted ? 100 : t.percentComplete).toDouble();
    final messenger = ScaffoldMessenger.of(context);
    final crm = context.crmColors;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: crm.border, borderRadius: BorderRadius.circular(4))),
            ),
            Text('Update progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            const SizedBox(height: 4),
            Text(t.title,
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),
            Row(children: [
              Text('% complete', style: TextStyle(fontWeight: FontWeight.w600, color: crm.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: p.round() >= 100 ? crm.success.withValues(alpha: 0.1) : crm.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${p.round()}%',
                    style: TextStyle(
                        color: p.round() >= 100 ? crm.success : crm.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(ctx).copyWith(
                activeTrackColor: crm.primary,
                thumbColor: crm.primary,
                inactiveTrackColor: crm.border.withValues(alpha: 0.5),
                overlayColor: crm.primary.withValues(alpha: 0.1),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              ),
              child: Slider(
                value: p,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${p.round()}%',
                onChanged: (v) => setSheet(() => p = v),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: crm.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  try {
                    final pct = p.round();
                    final payload = <String, dynamic>{'percentComplete': pct};
                    if (pct >= 100) payload['status'] = ITTaskStatus.closed.slug;
                    await ref.read(itTaskServiceProvider).updateTask(t.id, payload);
                    ref.invalidate(myTasksProvider);
                    refreshAllItTaskViews(ref);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                  }
                },
                child: const Text('Save Progress', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Stat Cards ─────────────────────────────────────────────────────────────────

class _StatCards extends StatelessWidget {
  const _StatCards({
    required this.total,
    required this.inProgress,
    required this.completed,
    required this.overdue,
    required this.onTimeDelivery,
  });

  final int total;
  final int inProgress;
  final int completed;
  final int overdue;
  final int onTimeDelivery;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final compPct = total == 0 ? 0 : ((completed / total) * 100).round();
    final overPct = total == 0 ? 0 : ((overdue / total) * 100).round();

    final cards = [
      _kpiCard(
        crm,
        icon: Icons.assignment_outlined,
        iconColor: const Color(0xFF991B1B),
        iconBg: const Color(0xFFFEF2F2),
        value: '$total',
        label: 'Total Tasks',
        badge: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.arrow_upward, size: 11, color: Color(0xFF059669)),
          SizedBox(width: 2),
          Text('+17% vs Oct (12)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
        ]),
      ),
      _kpiCard(
        crm,
        icon: Icons.play_circle_outline,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFEFF6FF),
        value: '$inProgress',
        label: 'In Progress',
        badge: null,
      ),
      _kpiCard(
        crm,
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF059669),
        iconBg: const Color(0xFFECFDF5),
        value: '$completed',
        label: 'Completed',
        badge: Text('$compPct% completion',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
      ),
      _kpiCard(
        crm,
        icon: Icons.access_time,
        iconColor: const Color(0xFFD97706),
        iconBg: const Color(0xFFFFFBEB),
        value: '$overdue',
        label: 'Pending / Overdue',
        badge: Text('$overPct% of total',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
      ),
      _kpiCard(
        crm,
        icon: Icons.track_changes_outlined,
        iconColor: const Color(0xFFBE185D),
        iconBg: const Color(0xFFFDF2F8),
        value: '$onTimeDelivery%',
        label: 'On-Time Delivery',
        badge: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.arrow_upward, size: 11, color: Color(0xFF059669)),
          SizedBox(width: 2),
          Text('+8 pp vs Oct',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
        ]),
      ),
    ];

    return LayoutBuilder(builder: (ctx, constraints) {
      final isDesktop = constraints.maxWidth >= 980;
      if (isDesktop) {
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      } else {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                SizedBox(width: 210, child: cards[i]),
              ],
            ],
          ),
        );
      }
    });
  }

  Widget _kpiCard(
    CrmTheme crm, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required Widget? badge,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: crm.textPrimary, height: 1.1),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (badge != null) ...[
              const SizedBox(height: 3),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: badge),
            ],
          ]),
        ),
      ]),
    );
  }
}
