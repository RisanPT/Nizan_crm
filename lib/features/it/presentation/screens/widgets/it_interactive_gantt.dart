import 'dart:math' as math;
import 'dart:ui' as ui show TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/gantt_auto_scheduler.dart';
import 'package:nizan_crm/features/it/domain/gantt_weeks.dart';
import 'package:nizan_crm/features/it/domain/task_rights.dart';
import 'package:nizan_crm/features/it/domain/task_tree.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/functional_plan_wizard_dialog.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';

class ITInteractiveGantt extends ConsumerStatefulWidget {
  final List<ITTaskModel> tasks;
  final List<ITTaskModel> allTasks;
  final String? projectId;
  final GanttZoomScale zoomScale;
  final GanttSwimlaneMode swimlaneMode;

  /// A bar above the chart to move week by week, jump to today and change the scale (and the scale then belongs to
  /// the chart; [zoomScale] is only where it starts). The Roadmap has its own scale control and leaves this off.
  final bool showToolbar;

  /// Add, edit and delete from the chart itself — a project's own Timeline: a + for new phases (and for a department's
  /// own function), a menu on each row to add under it, edit or delete it. The Roadmap, which spans projects, only opens tasks.
  final bool editable;

  const ITInteractiveGantt({
    super.key,
    required this.tasks,
    required this.allTasks,
    this.projectId,
    this.zoomScale = GanttZoomScale.week,
    this.swimlaneMode = GanttSwimlaneMode.bySubTeam,
    this.showToolbar = false,
    this.editable = false,
  });

  @override
  ConsumerState<ITInteractiveGantt> createState() => _ITInteractiveGanttState();
}

class _ITInteractiveGanttState extends ConsumerState<ITInteractiveGantt> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final Set<String> _collapsedSwimlanes = {};

  // Which projects the tasks belong to, and who is looking (what they may reschedule).
  Map<String, Project> _projectsById = const {};
  String _me = '';

  TaskRights _rights(ITTaskModel t) => taskRightsFor(_projectsById[t.projectId], t, myEmployeeId: _me);

  // Adding from the chart (editable timeline): who may add, and how the rows sit in the plan.
  Project? get _project => _projectsById[widget.projectId];
  bool get _canAdd => widget.editable && widget.projectId != null && (_project?.access.canCreateTasks ?? true);
  bool _canAddIn(String department) {
    if (!_canAdd) return false;
    final p = _project;
    if (p == null) return true;
    final d = department.trim().isEmpty ? p.targetDepartment : department;
    return p.access.canPlanIn(d);
  }

  Map<String, int> _rowDepth = const {}; // how far in each row sits (phase 0, its tasks 1, theirs 2 …) within its lane
  Set<String> _parentIds = const {}; // tasks that have something under them

  // Dragging state
  String? _draggingTaskId;
  int _dragOffsetDays = 0;
  double _dragDistance = 0;
  bool _didInitialScroll = false;

  static const double _rowHeight = 44.0;
  static const double _headerHeight = 52.0;
  static const double _sidebarWidth = 270.0;

  // Scale and week (toolbar mode). "1 week" fits seven days to the screen: it is the day layout with wide columns.
  late GanttZoomScale _scale = widget.zoomScale;
  bool _fitWeek = false;
  DateTime? _focusWeek; // the Monday of the week being looked at
  double _paneWidth = 900; // the room the timeline has (the screen less the task list)
  DateTime _boundsStart = DateTime.now();
  DateTime _boundsEnd = DateTime.now();
  double _dayWidth = 16; // as last drawn: where a date sits along the timeline

  GanttZoomScale get _layoutScale => _fitWeek ? GanttZoomScale.day : _scale;

  double get _colWidth => _fitWeek
      ? _paneWidth / 7
      : switch (_scale) {
          GanttZoomScale.day => 44.0,
          GanttZoomScale.week => 110.0,
          GanttZoomScale.month => 160.0,
        };

  @override
  void didUpdateWidget(covariant ITInteractiveGantt old) {
    super.didUpdateWidget(old);
    // a parent that owns the scale (the Roadmap) can still change it
    if (!widget.showToolbar && widget.zoomScale != old.zoomScale) _scale = widget.zoomScale;
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  /// Calculates timeline bounds anchored around current date (Today)
  ({DateTime start, DateTime end}) _calculateTimeBounds() {
    final now = DateTime.now();
    DateTime minD = now.subtract(const Duration(days: 14));
    DateTime maxD = now.add(const Duration(days: 42));

    for (final t in widget.tasks) {
      if (t.startDate != null) {
        if (t.startDate!.isBefore(minD)) minD = t.startDate!;
        if (t.startDate!.isAfter(maxD)) maxD = t.startDate!;
      }
      if (t.dueDate != null) {
        if (t.dueDate!.isBefore(minD)) minD = t.dueDate!;
        if (t.dueDate!.isAfter(maxD)) maxD = t.dueDate!;
      }
    }

    minD = minD.subtract(const Duration(days: 7));
    maxD = maxD.add(const Duration(days: 14));

    // Align to start of week (Monday)
    final startMonday = DateTime(minD.year, minD.month, minD.day).subtract(Duration(days: minD.weekday - 1));
    final endSunday = DateTime(maxD.year, maxD.month, maxD.day).add(Duration(days: 7 - maxD.weekday));

    return (start: startMonday, end: endSunday);
  }

  // ── week by week (toolbar mode) ───────────────────────────────────────────

  static String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Makes [monday]'s week the one in focus and brings it into view, its first day at the left edge.
  void _showWeek(DateTime monday, {bool animate = true}) {
    setState(() => _focusWeek = monday);
    // after the frame: a change of scale has been laid out by then, so the dates sit where they now are
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_horizontalController.hasClients) return;
      final x = daysBetween(_boundsStart, monday) * _dayWidth - (_fitWeek ? 0 : 24);
      final target = x.clamp(0.0, _horizontalController.position.maxScrollExtent).toDouble();
      if (animate) {
        _horizontalController.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      } else {
        _horizontalController.jumpTo(target);
      }
    });
  }

  /// Is there a whole week [weeks] away from the one in focus, inside the timeline?
  bool _hasWeek(int weeks) {
    final f = _focusWeek;
    if (f == null) return false;
    final w = addWeeks(f, weeks);
    return !w.isBefore(_boundsStart) && !DateTime(w.year, w.month, w.day + 6).isAfter(_boundsEnd);
  }

  void _openWeek(DateTime monday) {
    setState(() => _fitWeek = true);
    _showWeek(monday);
  }

  void _setScale({required GanttZoomScale scale, required bool fit}) {
    setState(() {
      _scale = scale;
      _fitWeek = fit;
    });
    final f = _focusWeek;
    if (f != null) _showWeek(f, animate: false); // stay on the same week
  }

  Widget _openWeekOnTap(Widget cell, DateTime monday, {required Key key, required bool enabled}) {
    if (!enabled || !widget.showToolbar) return cell;
    return Tooltip(
      message: 'Open this week',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(key: key, onTap: () => _openWeek(monday), child: cell),
    );
  }

  Widget _buildToolbar(CrmTheme crm) {
    final focus = _focusWeek ?? mondayOf(DateTime.now());
    final thisWeek = focus == mondayOf(DateTime.now());
    final border = BorderSide(color: crm.border.faded(2.5));

    Widget step(Key key, IconData icon, String tip, int weeks) => IconButton(
      key: key,
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      onPressed: _hasWeek(weeks) ? () => _showWeek(addWeeks(focus, weeks)) : null,
      icon: Icon(icon),
    );

    final navigator = Container(
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(10), border: Border.fromBorderSide(border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          step(const Key('gantt_prev_week'), Icons.chevron_left_rounded, 'Previous week', -1),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 236),
            child: Text(
              weekLabel(focus),
              key: const Key('gantt_week_label'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary),
            ),
          ),
          step(const Key('gantt_next_week'), Icons.chevron_right_rounded, 'Next week', 1),
        ],
      ),
    );

    final todayButton = OutlinedButton.icon(
      key: const Key('gantt_today'),
      onPressed: () => _showWeek(mondayOf(DateTime.now())),
      icon: const Icon(Icons.today_outlined, size: 18),
      label: const Text('Today', style: TextStyle(fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: crm.textPrimary,
        side: border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 40),
      ),
    );

    Widget option(Key key, String label, bool on, VoidCallback onTap) => InkWell(
      key: key,
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: on ? crm.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : crm.textPrimary),
        ),
      ),
    );
    final scaleSwitch = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(10), border: Border.fromBorderSide(border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(const Key('gantt_scale_fit'), '1 Week', _fitWeek, () => _setScale(scale: _scale, fit: true)),
          option(
            const Key('gantt_scale_day'),
            'Days',
            !_fitWeek && _scale == GanttZoomScale.day,
            () => _setScale(scale: GanttZoomScale.day, fit: false),
          ),
          option(
            const Key('gantt_scale_week'),
            'Weeks',
            !_fitWeek && _scale == GanttZoomScale.week,
            () => _setScale(scale: GanttZoomScale.week, fit: false),
          ),
          option(
            const Key('gantt_scale_month'),
            'Months',
            !_fitWeek && _scale == GanttZoomScale.month,
            () => _setScale(scale: GanttZoomScale.month, fit: false),
          ),
        ],
      ),
    );

    final left = Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        navigator,
        if (thisWeek)
          Container(
            key: const Key('gantt_this_week'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(
              'This week',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.primary),
            ),
          ),
        todayButton,
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 860) {
            return Row(
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                scaleSwitch,
              ],
            );
          }
          return Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [left, scaleSwitch]);
        },
      ),
    );
  }

  // ── add / edit / delete from the chart ────────────────────────────────────

  /// A new phase (no parent), or a task / sub-task under [parentId]; in [department] when given.
  Future<void> _addTask({String? parentId, String? department}) async {
    // the editor refreshes every task view itself once it has saved
    await showTaskEditor(context, ref, widget.projectId!, defaultParentId: parentId, defaultDepartment: department, allTasks: widget.allTasks);
  }

  void _openPlanWizard({String? department}) {
    showFunctionalPlanWizard(
      context: context,
      ref: ref,
      projectId: widget.projectId!,
      projectName: _project?.name ?? 'Project',
      existingTasks: widget.allTasks,
      project: _project,
      initialDepartment: department,
    );
  }

  Future<void> _deleteTask(ITTaskModel t) async {
    final below = descendantIds(widget.allTasks, t.id).length;
    final isPhase = (t.parentTaskId ?? '').isEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isPhase ? 'Delete phase?' : 'Delete task?'),
        content: Text(below > 0 ? '“${t.title}” and all $below item(s) under it will be deleted.' : '“${t.title}” will be deleted.'),
        actions: [
          TextButton(key: const Key('gantt_delete_cancel'), onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('gantt_delete_confirm'),
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await getITTasksNotifier(ref, widget.projectId).deleteTask(t.id);
      ref.invalidate(projectsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  /// The sort positions to write for [t] to go one place up (-1) or down (+1) among the things beside it — and only when this
  /// person may plan every one of them (a department lead cannot reorder another department's phase).
  Map<String, int> _moveChanges(ITTaskModel t, int delta) {
    final changes = orderAfterMove(widget.allTasks, t.id, delta);
    if (changes.isEmpty) return const {};
    final byId = {for (final x in widget.allTasks) x.id: x};
    return changes.keys.every((id) => byId[id] != null && _rights(byId[id]!).plan) ? changes : const {};
  }

  Future<void> _moveTask(ITTaskModel t, int delta) async {
    final changes = _moveChanges(t, delta);
    if (changes.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = getITTasksNotifier(ref, widget.projectId);
    try {
      for (final e in changes.entries) {
        await notifier.updateTaskField(e.key, {'order': e.value});
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  /// How deep [t] really is in the plan (0 = a phase), whatever lane it is shown in.
  int _planLevel(ITTaskModel t) {
    final byId = {for (final x in widget.allTasks) x.id: x};
    var level = 0;
    var p = t.parentTaskId;
    final seen = <String>{t.id};
    while (p != null && p.isNotEmpty && byId.containsKey(p) && seen.add(p)) {
      level++;
      p = byId[p]!.parentTaskId;
    }
    return level;
  }

  Widget _buildEmpty(CrmTheme crm) {
    final canAdd = _canAdd;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline_outlined, size: 54, color: crm.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Nothing on the timeline yet',
              style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              canAdd
                  ? 'Add a phase and break it into tasks, or let the plan wizard lay a whole plan out for you.'
                  : 'The project manager adds the work to this project.',
              textAlign: TextAlign.center,
              style: TextStyle(color: crm.textSecondary, fontSize: 13),
            ),
            if (canAdd) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const Key('gantt_empty_add_phase'),
                    style: FilledButton.styleFrom(backgroundColor: crm.primary),
                    onPressed: _addTask,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add first phase'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('gantt_empty_wizard'),
                    onPressed: _openPlanWizard,
                    icon: Icon(Icons.trending_up_rounded, size: 18, color: crm.primary),
                    label: const Text('Gantt Plan Wizard'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _scrollToToday(DateTime start, double dayRatio) {
    if (!_horizontalController.hasClients) return;
    final now = DateTime.now();
    final todayOffsetDays = now.difference(start).inDays;
    if (todayOffsetDays >= 0) {
      final targetX = math.max(0.0, (todayOffsetDays * dayRatio) - 220.0);
      final maxScroll = _horizontalController.position.maxScrollExtent;
      _horizontalController.animateTo(math.min(targetX, maxScroll), duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    _projectsById = {for (final p in ref.watch(projectsProvider).value ?? const <Project>[]) p.id: p};
    _me = ref.watch(authSessionProvider)?.employeeId ?? '';
    final datedTasks = widget.tasks.where((t) => t.startDate != null || t.dueDate != null).toList();

    if (widget.tasks.isEmpty && widget.editable) return _buildEmpty(crm);
    if (widget.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline_outlined, size: 54, color: crm.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No IT tasks match the current filters',
              style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    // the one-week view needs to know how wide the timeline pane is
    return LayoutBuilder(
      builder: (context, box) {
        _paneWidth = math.max(300.0, box.maxWidth - _sidebarWidth);
        return _buildChart(crm, datedTasks);
      },
    );
  }

  Widget _buildChart(CrmTheme crm, List<ITTaskModel> datedTasks) {
    final bounds = _calculateTimeBounds();
    final totalDays = math.max(28, bounds.end.difference(bounds.start).inDays + 1);
    _boundsStart = bounds.start;
    _boundsEnd = bounds.end;

    // Group tasks into swimlanes
    final swimlanes = _buildSwimlanes();

    // Map each task to row index for drawing dependency connectors
    final taskRowIndices = <String, int>{};
    var currentRowIndex = 0;
    for (final lane in swimlanes) {
      currentRowIndex++; // lane header
      if (!_collapsedSwimlanes.contains(lane.id)) {
        for (final t in lane.tasks) {
          taskRowIndices[t.id] = currentRowIndex;
          currentRowIndex++;
        }
      }
    }

    final timelineWidth = switch (_layoutScale) {
      GanttZoomScale.day => totalDays * _colWidth,
      GanttZoomScale.week => (totalDays / 7) * _colWidth,
      GanttZoomScale.month => (totalDays / 30) * _colWidth,
    };

    final dayRatio = timelineWidth / totalDays;
    _dayWidth = dayRatio;

    // Trigger initial auto-scroll once layout is ready: to the week in focus (toolbar mode), else to Today
    if (!_didInitialScroll) {
      _didInitialScroll = true;
      if (widget.showToolbar) {
        DateTime? first;
        DateTime? last;
        for (final t in widget.tasks) {
          final s = t.startDate ?? t.dueDate;
          final e = t.dueDate ?? t.startDate;
          if (s != null && (first == null || s.isBefore(first))) first = s;
          if (e != null && (last == null || e.isAfter(last))) last = e;
        }
        _focusWeek = initialFocusWeek(today: DateTime.now(), firstStart: first, lastDue: last);
        WidgetsBinding.instance.addPostFrameCallback((_) => _showWeek(_focusWeek!, animate: false));
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToToday(bounds.start, dayRatio);
        });
      }
    }

    return Container(
      color: crm.surface,
      child: Column(
        children: [
          if (widget.showToolbar) _buildToolbar(crm),
          if (datedTasks.length < widget.tasks.length) _buildUndatedBanner(crm, widget.tasks.length - datedTasks.length),
          Expanded(
            child: Row(
              children: [
                // Left Fixed Sidebar (Swimlanes & Task Keys)
                SizedBox(
                  width: _sidebarWidth,
                  child: Column(
                    children: [
                      _buildSidebarHeader(crm),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          child: SizedBox(height: currentRowIndex * _rowHeight, child: _buildSidebarRows(crm, swimlanes)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right Scrollable Timeline Canvas
                Expanded(
                  child: Scrollbar(
                    controller: _horizontalController,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: timelineWidth,
                        child: Column(
                          children: [
                            _buildTimelineHeader(crm, bounds.start, totalDays, timelineWidth, dayRatio),
                            Expanded(
                              child: SingleChildScrollView(
                                child: SizedBox(
                                  height: currentRowIndex * _rowHeight,
                                  width: timelineWidth,
                                  child: Stack(
                                    children: [
                                      // Background grid & Today Line
                                      _buildBackgroundGrid(crm, bounds.start, totalDays, timelineWidth, currentRowIndex * _rowHeight),
                                      // Dependency Curves Layer
                                      CustomPaint(
                                        size: Size(timelineWidth, currentRowIndex * _rowHeight),
                                        painter: _GanttDependencyPainter(
                                          tasks: widget.tasks,
                                          taskRowIndices: taskRowIndices,
                                          timelineStart: bounds.start,
                                          totalDays: totalDays,
                                          timelineWidth: timelineWidth,
                                          rowHeight: _rowHeight,
                                          collapsedSwimlanes: _collapsedSwimlanes,
                                        ),
                                      ),
                                      // Task Bars Layer
                                      _buildTaskBars(crm, swimlanes, bounds.start, totalDays, timelineWidth),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUndatedBanner(CrmTheme crm, int undatedCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.amber.shade50,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$undatedCount task(s) have no dates assigned. Click any task in the sidebar or grid to schedule it.',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(CrmTheme crm) {
    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: crm.background,
        border: Border(
          bottom: BorderSide(color: crm.border),
          right: BorderSide(color: crm.border),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'TASK / SWIMLANE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.textSecondary, letterSpacing: 0.3),
            ),
          ),
          if (_canAdd)
            PopupMenuButton<String>(
              key: const Key('gantt_add'),
              tooltip: 'Add to the plan',
              position: PopupMenuPosition.under,
              onSelected: (v) => v == 'phase' ? _addTask() : _openPlanWizard(),
              itemBuilder: (_) => const [
                PopupMenuItem(key: Key('gantt_add_phase'), value: 'phase', child: Text('Add phase')),
                PopupMenuItem(key: Key('gantt_add_wizard'), value: 'wizard', child: Text('Plan a function (wizard)…')),
              ],
              child: SizedBox(width: 30, height: 30, child: Icon(Icons.add_circle_outline_rounded, size: 21, color: crm.primary)),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarRows(CrmTheme crm, List<_GanttSwimlane> swimlanes) {
    return Column(
      children: [
        for (final lane in swimlanes) ...[
          // Swimlane Header
          InkWell(
            onTap: () {
              setState(() {
                if (_collapsedSwimlanes.contains(lane.id)) {
                  _collapsedSwimlanes.remove(lane.id);
                } else {
                  _collapsedSwimlanes.add(lane.id);
                }
              });
            },
            child: Container(
              height: _rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: lane.color.withValues(alpha: 0.08),
                border: Border(
                  left: BorderSide(color: lane.color, width: 3),
                  bottom: BorderSide(color: crm.border.faded(0.6)),
                  right: BorderSide(color: crm.border),
                ),
              ),
              child: Row(
                children: [
                  Icon(_collapsedSwimlanes.contains(lane.id) ? Icons.chevron_right : Icons.expand_more, size: 18, color: lane.color),
                  const SizedBox(width: 6),
                  Icon(lane.icon, size: 16, color: lane.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lane.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: lane.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${lane.tasks.length}',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: lane.color),
                    ),
                  ),
                  // a department's own lane: add a phase to it, or plan its function
                  if (widget.swimlaneMode == GanttSwimlaneMode.byDepartment && lane.title != 'No department' && _canAddIn(lane.title)) ...[
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      key: Key('gantt_lane_add_${lane.id}'),
                      tooltip: 'Add to ${lane.title}',
                      onSelected: (v) => v == 'phase' ? _addTask(department: lane.title) : _openPlanWizard(department: lane.title),
                      itemBuilder: (_) => [
                        PopupMenuItem(key: const Key('gantt_lane_add_phase'), value: 'phase', child: Text('Add phase for ${lane.title}')),
                        PopupMenuItem(key: const Key('gantt_lane_add_wizard'), value: 'wizard', child: Text('Plan ${lane.title} function…')),
                      ],
                      child: SizedBox(width: 26, height: 26, child: Icon(Icons.add, size: 18, color: lane.color)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Task Rows in this swimlane
          if (!_collapsedSwimlanes.contains(lane.id))
            for (final t in lane.tasks)
              InkWell(
                onTap: () => _openTaskDetail(t),
                child: Container(
                  height: _rowHeight,
                  // a task sits in from its phase, a sub-task in from its task
                  padding: EdgeInsets.only(left: 14.0 + 14.0 * (_rowDepth[t.id] ?? 0), right: widget.editable ? 2 : 14),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    border: Border(
                      bottom: BorderSide(color: crm.border.faded(0.5)),
                      right: BorderSide(color: crm.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: t.status.color),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.ticketKey,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _parentIds.contains(t.id) ? FontWeight.w800 : FontWeight.w500,
                            color: crm.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (t.isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                          child: const Text(
                            'Closed',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                          ),
                        )
                      else if (t.startDate == null && t.dueDate == null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            'Undated',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.amber.shade900),
                          ),
                        )
                      else if (t.isBlocked)
                        const Tooltip(
                          message: 'Blocked by predecessor',
                          child: Icon(Icons.lock_clock, size: 14, color: Colors.amber),
                        ),
                      if (widget.editable) _buildRowMenu(crm, t),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }

  /// The ⋮ on a row: add under it, add another beside it, edit, delete — only what this person may do.
  Widget _buildRowMenu(CrmTheme crm, ITTaskModel t) {
    final r = _rights(t);
    final canAdd = _canAddIn(t.departmentName);
    return PopupMenuButton<String>(
      key: Key('gantt_row_menu_${t.id}'),
      tooltip: 'More',
      onSelected: (v) {
        switch (v) {
          case 'child':
            _addTask(parentId: t.id, department: t.departmentName);
          case 'sibling':
            _addTask(parentId: t.parentTaskId, department: t.departmentName);
          case 'up':
            _moveTask(t, -1);
          case 'down':
            _moveTask(t, 1);
          case 'edit':
            _openTaskDetail(t);
          case 'delete':
            _deleteTask(t);
        }
      },
      // worked out when the menu opens, not for every row on every build
      itemBuilder: (_) {
        final level = _planLevel(t);
        return <PopupMenuEntry<String>>[
          if (canAdd) ...[
            PopupMenuItem(key: const Key('gantt_menu_child'), value: 'child', child: Text(level == 0 ? 'Add task to this phase' : 'Add sub-task')),
            PopupMenuItem(
              key: const Key('gantt_menu_sibling'),
              value: 'sibling',
              child: Text(switch (level) {
                0 => 'Add another phase',
                1 => 'Add another task',
                _ => 'Add another sub-task',
              }),
            ),
            const PopupMenuDivider(),
          ],
          if (r.plan) ...[
            PopupMenuItem(key: const Key('gantt_menu_up'), value: 'up', enabled: _moveChanges(t, -1).isNotEmpty, child: const Text('Move up')),
            PopupMenuItem(key: const Key('gantt_menu_down'), value: 'down', enabled: _moveChanges(t, 1).isNotEmpty, child: const Text('Move down')),
            const PopupMenuDivider(),
          ],
          PopupMenuItem(key: const Key('gantt_menu_edit'), value: 'edit', child: Text(r.readOnly ? 'View details' : 'Edit')),
          if (r.delete)
            const PopupMenuItem(
              key: Key('gantt_menu_delete'),
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
        ];
      },
      child: SizedBox(width: 28, height: 28, child: Icon(Icons.more_vert_rounded, size: 18, color: crm.textSecondary)),
    );
  }

  Widget _buildTimelineHeader(CrmTheme crm, DateTime start, int totalDays, double timelineWidth, double dayRatio) {
    final now = DateTime.now();

    return Container(
      height: _headerHeight,
      width: timelineWidth,
      decoration: BoxDecoration(
        color: crm.background,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          if (_layoutScale == GanttZoomScale.day) {
            return Row(
              children: [
                for (var i = 0; i < totalDays; i++) ...[
                  () {
                    final d = start.add(Duration(days: i));
                    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
                    final isWeekend = d.weekday == 6 || d.weekday == 7;
                    final inFocus = widget.showToolbar && _focusWeek != null && mondayOf(d) == _focusWeek;
                    final cell = Container(
                      width: _colWidth,
                      height: _headerHeight,
                      decoration: BoxDecoration(
                        color: isToday
                            ? crm.primary.withValues(alpha: 0.12)
                            : (inFocus ? crm.primary.withValues(alpha: 0.05) : (isWeekend ? crm.background.withValues(alpha: 0.8) : null)),
                        border: Border(right: BorderSide(color: crm.border.faded(0.4))),
                      ),
                      // painted over the cell, so the line that starts a week and the one under the week in focus take no room from it
                      foregroundDecoration: BoxDecoration(
                        border: Border(
                          left: d.weekday == DateTime.monday ? BorderSide(color: crm.border.faded(1.6)) : BorderSide.none,
                          bottom: inFocus ? BorderSide(color: crm.primary, width: 3) : BorderSide.none,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('E').format(d),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isToday ? crm.primary : crm.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: isToday ? BoxDecoration(color: crm.primary, borderRadius: BorderRadius.circular(10)) : null,
                            child: Text(
                              DateFormat('d MMM').format(d),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isToday ? Colors.white : (isWeekend ? crm.textSecondary : crm.textPrimary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    // a day opens its week in the one-week view (unless that is the view already)
                    return _openWeekOnTap(cell, mondayOf(d), key: Key('gantt_open_day_${_iso(d)}'), enabled: !_fitWeek);
                  }(),
                ],
              ],
            );
          } else if (_layoutScale == GanttZoomScale.week) {
            final totalWeeks = (totalDays / 7).ceil();
            return Row(
              children: [
                for (var w = 0; w < totalWeeks; w++) ...[
                  () {
                    final wStart = start.add(Duration(days: w * 7));
                    final wEnd = wStart.add(const Duration(days: 6));
                    final isCurrentWeek = now.isAfter(wStart.subtract(const Duration(days: 1))) && now.isBefore(wEnd.add(const Duration(days: 1)));

                    final inFocus = widget.showToolbar && _focusWeek != null && wStart == _focusWeek;
                    final cell = Container(
                      width: _colWidth,
                      height: _headerHeight,
                      decoration: BoxDecoration(
                        color: inFocus ? crm.primary.withValues(alpha: 0.13) : (isCurrentWeek ? crm.primary.withValues(alpha: 0.07) : null),
                        border: Border(right: BorderSide(color: crm.border.faded(0.5))),
                      ),
                      foregroundDecoration: inFocus
                          ? BoxDecoration(
                              border: Border(bottom: BorderSide(color: crm.primary, width: 3)),
                            )
                          : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isCurrentWeek)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: crm.primary),
                                ),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'W${isoWeekNumber(wStart)} · ${DateFormat('MMM dd').format(wStart)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: isCurrentWeek ? crm.primary : crm.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('to ${DateFormat('MMM dd, yy').format(wEnd)}', style: TextStyle(fontSize: 10, color: crm.textSecondary)),
                        ],
                      ),
                    );
                    return _openWeekOnTap(cell, wStart, key: Key('gantt_open_week_${_iso(wStart)}'), enabled: true);
                  }(),
                ],
              ],
            );
          } else {
            // Month zoom
            final totalMonths = (totalDays / 30).ceil();
            // the months are counted up to a whole one, so the row can be a little longer than the timeline: clip it
            return ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: totalMonths * _colWidth,
                child: Row(
                  children: [
                    for (var m = 0; m < totalMonths; m++) ...[
                      () {
                        final mDate = DateTime(start.year, start.month + m, 1);
                        final isCurrentMonth = mDate.year == now.year && mDate.month == now.month;
                        return Container(
                          width: _colWidth,
                          height: _headerHeight,
                          decoration: BoxDecoration(
                            color: isCurrentMonth ? crm.primary.withValues(alpha: 0.08) : null,
                            border: Border(right: BorderSide(color: crm.border.faded(0.5))),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            DateFormat('MMMM yyyy').format(mDate),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isCurrentMonth ? crm.primary : crm.textPrimary),
                          ),
                        );
                      }(),
                    ],
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildBackgroundGrid(CrmTheme crm, DateTime start, int totalDays, double timelineWidth, double totalHeight) {
    final now = DateTime.now();
    final todayOffsetDays = now.difference(start).inDays;
    final dayRatio = timelineWidth / totalDays;
    final todayX = todayOffsetDays * dayRatio;

    return Positioned.fill(
      child: Stack(
        children: [
          // Grid Lines
          Row(
            children: [
              for (var i = 0; i < totalDays; i++) ...[
                () {
                  final d = start.add(Duration(days: i));
                  final isWeekend = d.weekday == 6 || d.weekday == 7;
                  return Container(
                    width: dayRatio,
                    height: totalHeight,
                    decoration: BoxDecoration(
                      color: isWeekend ? crm.background.withValues(alpha: 0.35) : null,
                      border: Border(
                        left: d.weekday == DateTime.monday && dayRatio >= 12 ? BorderSide(color: crm.border.faded(0.9)) : BorderSide.none,
                        right: BorderSide(color: crm.border.faded(0.25)),
                      ),
                    ),
                  );
                }(),
              ],
            ],
          ),
          // The week in focus (toolbar mode)
          if (widget.showToolbar && _focusWeek != null)
            Positioned(
              left: daysBetween(start, _focusWeek!) * dayRatio,
              width: 7 * dayRatio,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(key: const Key('gantt_focus_band'), color: crm.primary.withValues(alpha: 0.045)),
              ),
            ),
          // Red Pulsing Today Line
          if (todayOffsetDays >= 0 && todayOffsetDays <= totalDays)
            Positioned(
              left: todayX,
              top: 0,
              bottom: 0,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 2,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 4, spreadRadius: 1)],
                    ),
                  ),
                  Positioned(
                    top: 2,
                    left: -18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskBars(CrmTheme crm, List<_GanttSwimlane> swimlanes, DateTime timelineStart, int totalDays, double timelineWidth) {
    final dayRatio = timelineWidth / totalDays;
    var rowIdx = 0;
    final widgets = <Widget>[];

    for (final lane in swimlanes) {
      // Lane Header spacer
      rowIdx++;

      if (!_collapsedSwimlanes.contains(lane.id)) {
        for (final t in lane.tasks) {
          final top = rowIdx * _rowHeight;
          rowIdx++;

          final hasExplicitDates = t.startDate != null || t.dueDate != null;

          if (!hasExplicitDates) {
            // Render an undated prompt button
            widgets.add(
              Positioned(
                left: 16,
                top: top + 8,
                height: _rowHeight - 16,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: BorderSide(color: Colors.amber.shade300, style: BorderStyle.solid),
                    backgroundColor: Colors.amber.shade50.withValues(alpha: 0.7),
                  ),
                  onPressed: () => _openTaskDetail(t),
                  icon: Icon(Icons.edit_calendar, size: 14, color: Colors.amber.shade900),
                  label: Text(
                    'Set Schedule for ${t.ticketKey}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber.shade900),
                  ),
                ),
              ),
            );
            continue;
          }

          final s = t.startDate ?? t.dueDate!.subtract(Duration(days: math.max(1, (t.estimatedHours / 8).ceil())));
          final e = t.dueDate ?? s.add(Duration(days: math.max(1, (t.estimatedHours / 8).ceil())));

          var startOffset = s.difference(timelineStart).inDays;
          var spanDays = math.max(1, e.difference(s).inDays + 1);

          // Apply live drag offset if currently dragging
          if (_draggingTaskId == t.id) {
            startOffset += _dragOffsetDays;
          }

          final left = startOffset * dayRatio;
          final width = math.max(34.0, spanDays * dayRatio);
          final fit = _labelFit(t, width);
          final tooltip =
              '${t.ticketKey} • ${t.title}\n${DateFormat('dd MMM').format(s)} – ${DateFormat('dd MMM yyyy').format(e)}\n${_rights(t).plan ? 'Click to view details / drag to reschedule' : 'Click to view details'}';

          widgets.add(
            Positioned(
              left: left,
              top: top + 6,
              width: width,
              height: _rowHeight - 12,
              child: GestureDetector(
                key: Key('gantt_bar_${t.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _openTaskDetail(t),
                onDoubleTap: () => _openTaskDetail(t),
                onHorizontalDragStart: !_rights(t).plan
                    ? null // only who plans the ticket reschedules it
                    : (_) {
                        setState(() {
                          _draggingTaskId = t.id;
                          _dragOffsetDays = 0;
                          _dragDistance = 0;
                        });
                      },
                onHorizontalDragUpdate: !_rights(t).plan
                    ? null
                    : (details) {
                        _dragDistance += details.primaryDelta!.abs();
                        final deltaDays = (details.primaryDelta! / dayRatio).round();
                        if (deltaDays != 0) {
                          setState(() {
                            _dragOffsetDays += deltaDays;
                          });
                        }
                      },
                onHorizontalDragEnd: !_rights(t).plan
                    ? null
                    : (_) async {
                        if (_draggingTaskId != null) {
                          if (_dragOffsetDays != 0 && _dragDistance > 6) {
                            final newStart = s.add(Duration(days: _dragOffsetDays));
                            final newDue = e.add(Duration(days: _dragOffsetDays));
                            await _persistDateShift(t.id, newStart, newDue);
                          } else if (_dragDistance <= 6) {
                            // Click / tap without substantial dragging
                            _openTaskDetail(t);
                          }
                        }
                        if (!mounted) return;
                        setState(() {
                          _draggingTaskId = null;
                          _dragOffsetDays = 0;
                          _dragDistance = 0;
                        });
                      },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(message: tooltip, child: _buildTaskBarContent(crm, t, fit)),
                ),
              ),
            ),
          );

          // a bar too short to hold its title: the title goes beside it (on the left when the bar is near the right edge)
          if (!fit.inside) {
            final wanted = math.min(_textWidth(t.title, _outsideStyle) + 6, 300.0);
            final roomRight = timelineWidth - (left + width) - 8;
            final goLeft = roomRight < wanted && left - 8 >= wanted;
            final room = goLeft ? wanted : math.min(wanted, roomRight);
            if (room >= 24) {
              widgets.add(
                Positioned(
                  left: goLeft ? left - 8 - room : left + width + 8,
                  top: top + 6,
                  width: room,
                  height: _rowHeight - 12,
                  child: GestureDetector(
                    key: Key('gantt_label_${t.id}'),
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _openTaskDetail(t),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Tooltip(
                        message: tooltip,
                        child: Align(
                          alignment: goLeft ? Alignment.centerRight : Alignment.centerLeft,
                          child: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: goLeft ? TextAlign.right : TextAlign.left,
                            style: _outsideStyle.copyWith(color: crm.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          }
        }
      }
    }

    return Stack(children: widgets);
  }

  static const _insideStyle = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white);
  static const _assigneeStyle = TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600);
  static const _outsideStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

  double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  /// Does the title fit inside a bar of [barWidth] (and the assignee's first name too)? A bar that cannot
  /// hold it shows nothing, rather than a cut-off "IT-A2…": its title is written beside it instead.
  ({bool inside, bool assignee}) _labelFit(ITTaskModel t, double barWidth) {
    final need = _textWidth(t.title, _insideStyle) + 20 + (t.isBlocked ? 16 : 0);
    if (barWidth < need) return (inside: false, assignee: false);
    final first = t.assigneeName.trim().split(' ').first;
    return (inside: true, assignee: first.isNotEmpty && barWidth >= need + _textWidth(first, _assigneeStyle) + 8);
  }

  Widget _buildTaskBarContent(CrmTheme crm, ITTaskModel t, ({bool inside, bool assignee}) fit) {
    final statusColor = t.status.color;
    final isBlocked = t.isBlocked;

    return Container(
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 4, offset: const Offset(0, 2))],
        border: isBlocked ? Border.all(color: Colors.amber, width: 1.5) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          children: [
            // Progress fill
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (t.percentComplete.clamp(0, 100) / 100).toDouble(),
              child: Container(color: Colors.black.withValues(alpha: 0.15)),
            ),
            // Task content (centred in the bar)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    if (isBlocked)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.lock_clock, size: 12, color: Colors.white),
                      ),
                    if (fit.inside) ...[
                      Expanded(
                        child: Text(t.title, key: Key('gantt_bar_text_${t.id}'), maxLines: 1, style: _insideStyle, overflow: TextOverflow.ellipsis),
                      ),
                      if (fit.assignee) Text(t.assigneeName.trim().split(' ').first, style: _assigneeStyle),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _persistDateShift(String taskId, DateTime start, DateTime due) async {
    final notifier = getITTasksNotifier(ref, widget.projectId);

    final shifted = GanttAutoScheduler.rippleShift(allTasks: widget.allTasks, changedTaskId: taskId, newStartDate: start, newDueDate: due);

    try {
      if (shifted.length > 1) {
        for (final entry in shifted.entries) {
          await notifier.shiftTaskDates(entry.key, entry.value.start, entry.value.due);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rescheduled task and cascaded ${shifted.length - 1} dependent task(s).'), duration: const Duration(seconds: 3)),
          );
        }
      } else {
        await notifier.shiftTaskDates(taskId, start, due);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  void _openTaskDetail(ITTaskModel task) {
    showITTaskDetailSheet(context, ref, task: task, allTasks: widget.allTasks).then((saved) {
      if (saved == true) {
        getITTasksNotifier(ref, widget.projectId).refresh();
      }
    });
  }

  /// The lanes, each reading as a plan: a phase, then its tasks, then their sub-tasks (and how far in each sits).
  List<_GanttSwimlane> _buildSwimlanes() {
    final depth = <String, int>{};
    final lanes = [
      for (final lane in _buildLanes())
        () {
          final ordered = inPlanOrder(lane.tasks);
          depth.addAll(ordered.depth);
          return _GanttSwimlane(id: lane.id, title: lane.title, icon: lane.icon, color: lane.color, tasks: ordered.tasks);
        }(),
    ];
    _rowDepth = depth;
    _parentIds = {
      for (final t in widget.allTasks)
        if ((t.parentTaskId ?? '').isNotEmpty) t.parentTaskId!,
    };
    return lanes;
  }

  List<_GanttSwimlane> _buildLanes() {
    if (widget.swimlaneMode == GanttSwimlaneMode.bySubTeam) {
      final lanes = <_GanttSwimlane>[];
      for (final tm in ITSubTeam.values) {
        final laneTasks = widget.tasks.where((t) => t.subTeam == tm).toList();
        if (laneTasks.isNotEmpty) {
          lanes.add(_GanttSwimlane(id: tm.slug, title: tm.label, icon: tm.icon, color: tm.color, tasks: laneTasks));
        }
      }
      return lanes;
    } else if (widget.swimlaneMode == GanttSwimlaneMode.byDepartment) {
      // A ticket with no department belongs to its project's owning department.
      String deptOf(ITTaskModel t) =>
          t.departmentName.trim().isNotEmpty ? t.departmentName.trim() : (_projectsById[t.projectId]?.targetDepartment ?? '').trim();
      final byDept = <String, List<ITTaskModel>>{};
      for (final t in widget.tasks) {
        final d = deptOf(t);
        (byDept[d.isEmpty ? 'No department' : d] ??= []).add(t);
      }
      final names = byDept.keys.toList()..sort((a, b) => a.compareTo(b));
      return [
        for (var i = 0; i < names.length; i++)
          _GanttSwimlane(id: 'dept-${names[i]}', title: names[i], icon: Icons.apartment_outlined, color: phaseColor(i), tasks: byDept[names[i]]!),
      ];
    } else if (widget.swimlaneMode == GanttSwimlaneMode.byProject) {
      final byProj = <String, List<ITTaskModel>>{};
      for (final t in widget.tasks) {
        (byProj[t.projectId] ??= []).add(t);
      }
      final lanes = <_GanttSwimlane>[];
      var idx = 0;
      for (final entry in byProj.entries) {
        final projName = entry.value.first.projectName.isNotEmpty ? entry.value.first.projectName : 'Project';
        final color = phaseColor(idx++);
        lanes.add(_GanttSwimlane(id: entry.key, title: projName, icon: Icons.folder_outlined, color: color, tasks: entry.value));
      }
      return lanes;
    } else {
      // Group by Phase (Parent Tasks) if any exist, otherwise flat list
      final parentTasks = widget.allTasks.where((t) => t.parentTaskId == null || t.parentTaskId!.isEmpty).toList();
      final hasParentHierarchy = widget.allTasks.any((t) => t.parentTaskId != null && t.parentTaskId!.isNotEmpty);

      if (hasParentHierarchy && parentTasks.isNotEmpty) {
        final lanes = <_GanttSwimlane>[];
        var idx = 0;
        for (final parent in parentTasks) {
          final children = widget.tasks.where((t) => t.parentTaskId == parent.id).toList();
          final phaseTasks = [if (widget.tasks.any((t) => t.id == parent.id)) parent, ...children];
          if (phaseTasks.isNotEmpty) {
            lanes.add(
              _GanttSwimlane(id: parent.id, title: parent.title, icon: Icons.account_tree_outlined, color: phaseColor(idx++), tasks: phaseTasks),
            );
          }
        }
        final orphans = widget.tasks
            .where((t) => (t.parentTaskId == null || t.parentTaskId!.isEmpty) && !parentTasks.any((p) => p.id == t.id))
            .toList();
        if (orphans.isNotEmpty) {
          lanes.add(_GanttSwimlane(id: 'general', title: 'General Tasks', icon: Icons.list_alt, color: phaseColor(idx), tasks: orphans));
        }
        if (lanes.isNotEmpty) return lanes;
      }

      return [_GanttSwimlane(id: 'all', title: 'All Tasks', icon: Icons.list_alt, color: const Color(0xFF2563EB), tasks: widget.tasks)];
    }
  }
}

class _GanttSwimlane {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<ITTaskModel> tasks;

  const _GanttSwimlane({required this.id, required this.title, required this.icon, required this.color, required this.tasks});
}

Color phaseColor(int index) {
  const palette = [Color(0xFF1D4E89), Color(0xFF3E7C8B), Color(0xFFC1622D), Color(0xFF3E7A3E), Color(0xFF5B3E8B)];
  return palette[index % palette.length];
}

/// Custom painter for Bézier dependency links between tasks
class _GanttDependencyPainter extends CustomPainter {
  final List<ITTaskModel> tasks;
  final Map<String, int> taskRowIndices;
  final DateTime timelineStart;
  final int totalDays;
  final double timelineWidth;
  final double rowHeight;
  final Set<String> collapsedSwimlanes;

  _GanttDependencyPainter({
    required this.tasks,
    required this.taskRowIndices,
    required this.timelineStart,
    required this.totalDays,
    required this.timelineWidth,
    required this.rowHeight,
    required this.collapsedSwimlanes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dayRatio = timelineWidth / totalDays;

    for (final task in tasks) {
      if (task.predecessorIds.isEmpty) continue;
      final targetRowIdx = taskRowIndices[task.id];
      if (targetRowIdx == null) continue;

      final targetStart = task.startDate ?? task.createdAt ?? timelineStart;
      final targetStartX = targetStart.difference(timelineStart).inDays * dayRatio;
      final targetY = (targetRowIdx * rowHeight) + (rowHeight / 2);

      for (final pid in task.predecessorIds) {
        final pred = tasks.where((t) => t.id == pid).firstOrNull;
        if (pred == null) continue;

        final predRowIdx = taskRowIndices[pred.id];
        if (predRowIdx == null) continue;

        final predDue = pred.dueDate ?? (pred.startDate ?? timelineStart).add(const Duration(days: 3));
        final predEndX = (predDue.difference(timelineStart).inDays + 1) * dayRatio;
        final predY = (predRowIdx * rowHeight) + (rowHeight / 2);

        // Check if this dependency is a Blocker (predecessor due date > successor start date)
        final isBlocker = !pred.isCompleted && predDue.isAfter(targetStart);

        final strokeColor = isBlocker ? Colors.redAccent : Colors.blueGrey.shade400;
        final paint = Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isBlocker ? 2.2 : 1.5;

        // Draw smooth Bézier curve from predecessor end to target start
        final path = Path();
        path.moveTo(predEndX, predY);

        final dx = targetStartX - predEndX;
        final controlX1 = predEndX + math.max(16.0, dx * 0.5);
        final controlX2 = targetStartX - math.max(16.0, dx * 0.5);

        path.cubicTo(controlX1, predY, controlX2, targetY, targetStartX, targetY);
        canvas.drawPath(path, paint);

        // Arrowhead at target start
        final arrowPaint = Paint()
          ..color = strokeColor
          ..style = PaintingStyle.fill;
        final arrowPath = Path()
          ..moveTo(targetStartX, targetY)
          ..lineTo(targetStartX - 6, targetY - 4)
          ..lineTo(targetStartX - 6, targetY + 4)
          ..close();
        canvas.drawPath(arrowPath, arrowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GanttDependencyPainter oldDelegate) {
    return oldDelegate.tasks != tasks ||
        oldDelegate.taskRowIndices != taskRowIndices ||
        oldDelegate.timelineWidth != timelineWidth ||
        oldDelegate.collapsedSwimlanes != collapsedSwimlanes;
  }
}
