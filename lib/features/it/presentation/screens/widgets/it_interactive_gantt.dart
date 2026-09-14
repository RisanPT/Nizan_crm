import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';

class ITInteractiveGantt extends ConsumerStatefulWidget {
  final List<ITTaskModel> tasks;
  final List<ITTaskModel> allTasks;
  final String? projectId;
  final GanttZoomScale zoomScale;
  final GanttSwimlaneMode swimlaneMode;

  const ITInteractiveGantt({
    super.key,
    required this.tasks,
    required this.allTasks,
    this.projectId,
    this.zoomScale = GanttZoomScale.week,
    this.swimlaneMode = GanttSwimlaneMode.bySubTeam,
  });

  @override
  ConsumerState<ITInteractiveGantt> createState() => _ITInteractiveGanttState();
}

class _ITInteractiveGanttState extends ConsumerState<ITInteractiveGantt> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final Set<String> _collapsedSwimlanes = {};

  // Dragging state
  String? _draggingTaskId;
  int _dragOffsetDays = 0;
  double _dragDistance = 0;
  bool _didInitialScroll = false;

  static const double _rowHeight = 44.0;
  static const double _headerHeight = 52.0;
  static const double _sidebarWidth = 270.0;

  double get _colWidth => switch (widget.zoomScale) {
        GanttZoomScale.day => 44.0,
        GanttZoomScale.week => 110.0,
        GanttZoomScale.month => 160.0,
      };

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

  void _scrollToToday(DateTime start, double dayRatio) {
    if (!_horizontalController.hasClients) return;
    final now = DateTime.now();
    final todayOffsetDays = now.difference(start).inDays;
    if (todayOffsetDays >= 0) {
      final targetX = math.max(0.0, (todayOffsetDays * dayRatio) - 220.0);
      final maxScroll = _horizontalController.position.maxScrollExtent;
      _horizontalController.animateTo(
        math.min(targetX, maxScroll),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final datedTasks = widget.tasks.where((t) => t.startDate != null || t.dueDate != null).toList();

    if (widget.tasks.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timeline_outlined, size: 54, color: crm.textSecondary),
          const SizedBox(height: 12),
          Text('No IT tasks match the current filters', style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w700)),
        ]),
      );
    }

    final bounds = _calculateTimeBounds();
    final totalDays = math.max(28, bounds.end.difference(bounds.start).inDays + 1);

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

    final timelineWidth = switch (widget.zoomScale) {
      GanttZoomScale.day => totalDays * _colWidth,
      GanttZoomScale.week => (totalDays / 7) * _colWidth,
      GanttZoomScale.month => (totalDays / 30) * _colWidth,
    };

    final dayRatio = timelineWidth / totalDays;

    // Trigger initial auto-scroll to Today once layout is ready
    if (!_didInitialScroll) {
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToToday(bounds.start, dayRatio);
      });
    }

    return Container(
      color: crm.surface,
      child: Column(children: [
        if (datedTasks.length < widget.tasks.length)
          _buildUndatedBanner(crm, widget.tasks.length - datedTasks.length),
        Expanded(
          child: Row(children: [
            // Left Fixed Sidebar (Swimlanes & Task Keys)
            SizedBox(
              width: _sidebarWidth,
              child: Column(children: [
                _buildSidebarHeader(crm),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    child: SizedBox(
                      height: currentRowIndex * _rowHeight,
                      child: _buildSidebarRows(crm, swimlanes),
                    ),
                  ),
                ),
              ]),
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
                    child: Column(children: [
                      _buildTimelineHeader(crm, bounds.start, totalDays, timelineWidth, dayRatio),
                      Expanded(
                        child: SingleChildScrollView(
                          child: SizedBox(
                            height: currentRowIndex * _rowHeight,
                            width: timelineWidth,
                            child: Stack(children: [
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
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildUndatedBanner(CrmTheme crm, int undatedCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.amber.shade50,
      child: Row(children: [
        Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$undatedCount task(s) have no dates assigned. Click any task in the sidebar or grid to schedule it.',
            style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
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
      child: Text(
        'TASK / SWIMLANE',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.textSecondary, letterSpacing: 0.3),
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
                  bottom: BorderSide(color: crm.border.withValues(alpha: 0.6)),
                  right: BorderSide(color: crm.border),
                ),
              ),
              child: Row(children: [
                Icon(
                  _collapsedSwimlanes.contains(lane.id) ? Icons.chevron_right : Icons.expand_more,
                  size: 18,
                  color: lane.color,
                ),
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
                  decoration: BoxDecoration(
                    color: lane.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${lane.tasks.length}',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: lane.color),
                  ),
                ),
              ]),
            ),
          ),
          // Task Rows in this swimlane
          if (!_collapsedSwimlanes.contains(lane.id))
            for (final t in lane.tasks)
              InkWell(
                onTap: () => _openTaskDetail(t),
                child: Container(
                  height: _rowHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    border: Border(
                      bottom: BorderSide(color: crm.border.withValues(alpha: 0.5)),
                      right: BorderSide(color: crm.border),
                    ),
                  ),
                  child: Row(children: [
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
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: crm.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (t.isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Closed',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                        ),
                      )
                    else if (t.startDate == null && t.dueDate == null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
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
                  ]),
                ),
              ),
        ],
      ],
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
      child: LayoutBuilder(builder: (ctx, constraints) {
        if (widget.zoomScale == GanttZoomScale.day) {
          return Row(children: [
            for (var i = 0; i < totalDays; i++) ...[
              () {
                final d = start.add(Duration(days: i));
                final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
                final isWeekend = d.weekday == 6 || d.weekday == 7;
                return Container(
                  width: _colWidth,
                  height: _headerHeight,
                  decoration: BoxDecoration(
                    color: isToday
                        ? crm.primary.withValues(alpha: 0.12)
                        : (isWeekend ? crm.background.withValues(alpha: 0.8) : null),
                    border: Border(right: BorderSide(color: crm.border.withValues(alpha: 0.4))),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                      DateFormat('E').format(d),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isToday ? crm.primary : crm.textSecondary,
                      ),
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
                  ]),
                );
              }(),
            ],
          ]);
        } else if (widget.zoomScale == GanttZoomScale.week) {
          final totalWeeks = (totalDays / 7).ceil();
          return Row(children: [
            for (var w = 0; w < totalWeeks; w++) ...[
              () {
                final wStart = start.add(Duration(days: w * 7));
                final wEnd = wStart.add(const Duration(days: 6));
                final isCurrentWeek = now.isAfter(wStart.subtract(const Duration(days: 1))) &&
                    now.isBefore(wEnd.add(const Duration(days: 1)));

                return Container(
                  width: _colWidth,
                  height: _headerHeight,
                  decoration: BoxDecoration(
                    color: isCurrentWeek ? crm.primary.withValues(alpha: 0.07) : null,
                    border: Border(right: BorderSide(color: crm.border.withValues(alpha: 0.5))),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (isCurrentWeek)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: crm.primary),
                        ),
                      Text(
                        DateFormat('MMM dd').format(wStart),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isCurrentWeek ? crm.primary : crm.textPrimary,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      'to ${DateFormat('MMM dd, yy').format(wEnd)}',
                      style: TextStyle(fontSize: 10, color: crm.textSecondary),
                    ),
                  ]),
                );
              }(),
            ],
          ]);
        } else {
          // Month zoom
          final totalMonths = (totalDays / 30).ceil();
          return Row(children: [
            for (var m = 0; m < totalMonths; m++) ...[
              () {
                final mDate = DateTime(start.year, start.month + m, 1);
                final isCurrentMonth = mDate.year == now.year && mDate.month == now.month;
                return Container(
                  width: _colWidth,
                  height: _headerHeight,
                  decoration: BoxDecoration(
                    color: isCurrentMonth ? crm.primary.withValues(alpha: 0.08) : null,
                    border: Border(right: BorderSide(color: crm.border.withValues(alpha: 0.5))),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    DateFormat('MMMM yyyy').format(mDate),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isCurrentMonth ? crm.primary : crm.textPrimary,
                    ),
                  ),
                );
              }(),
            ],
          ]);
        }
      }),
    );
  }

  Widget _buildBackgroundGrid(CrmTheme crm, DateTime start, int totalDays, double timelineWidth, double totalHeight) {
    final now = DateTime.now();
    final todayOffsetDays = now.difference(start).inDays;
    final dayRatio = timelineWidth / totalDays;
    final todayX = todayOffsetDays * dayRatio;

    return Positioned.fill(
      child: Stack(children: [
        // Grid Lines
        Row(children: [
          for (var i = 0; i < totalDays; i++) ...[
            () {
              final d = start.add(Duration(days: i));
              final isWeekend = d.weekday == 6 || d.weekday == 7;
              return Container(
                width: dayRatio,
                height: totalHeight,
                decoration: BoxDecoration(
                  color: isWeekend ? crm.background.withValues(alpha: 0.35) : null,
                  border: Border(right: BorderSide(color: crm.border.withValues(alpha: 0.25))),
                ),
              );
            }(),
          ],
        ]),
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
                    boxShadow: [
                      BoxShadow(color: Colors.redAccent, blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                ),
                Positioned(
                  top: 2,
                  left: -18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ]),
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

          widgets.add(
            Positioned(
              left: left,
              top: top + 6,
              width: width,
              height: _rowHeight - 12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openTaskDetail(t),
                onDoubleTap: () => _openTaskDetail(t),
                onHorizontalDragStart: (_) {
                  setState(() {
                    _draggingTaskId = t.id;
                    _dragOffsetDays = 0;
                    _dragDistance = 0;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  _dragDistance += details.primaryDelta!.abs();
                  final deltaDays = (details.primaryDelta! / dayRatio).round();
                  if (deltaDays != 0) {
                    setState(() {
                      _dragOffsetDays += deltaDays;
                    });
                  }
                },
                onHorizontalDragEnd: (_) async {
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
                  setState(() {
                    _draggingTaskId = null;
                    _dragOffsetDays = 0;
                    _dragDistance = 0;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    message: '${t.ticketKey} • ${t.title}\n${DateFormat('dd MMM').format(s)} – ${DateFormat('dd MMM yyyy').format(e)}\nClick to view details / drag to reschedule',
                    child: _buildTaskBarContent(crm, t, width),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Stack(children: widgets);
  }

  Widget _buildTaskBarContent(CrmTheme crm, ITTaskModel t, double barWidth) {
    final statusColor = t.status.color;
    final isBlocked = t.isBlocked;

    return Container(
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: isBlocked ? Border.all(color: Colors.amber, width: 1.5) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(children: [
          // Progress fill
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (t.percentComplete.clamp(0, 100) / 100).toDouble(),
            child: Container(color: Colors.black.withValues(alpha: 0.15)),
          ),
          // Task content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              if (isBlocked)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.lock_clock, size: 12, color: Colors.white),
                ),
              Expanded(
                child: Text(
                  '${t.ticketKey} ${t.title}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (barWidth > 110 && t.assigneeName.isNotEmpty)
                Text(
                  t.assigneeName.split(' ').first,
                  style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _persistDateShift(String taskId, DateTime start, DateTime due) async {
    final notifier = getITTasksNotifier(ref, widget.projectId);

    try {
      await notifier.shiftTaskDates(taskId, start, due);
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

  List<_GanttSwimlane> _buildSwimlanes() {
    if (widget.swimlaneMode == GanttSwimlaneMode.bySubTeam) {
      final lanes = <_GanttSwimlane>[];
      for (final tm in ITSubTeam.values) {
        final laneTasks = widget.tasks.where((t) => t.subTeam == tm).toList();
        if (laneTasks.isNotEmpty) {
          lanes.add(_GanttSwimlane(
            id: tm.slug,
            title: tm.label,
            icon: tm.icon,
            color: tm.color,
            tasks: laneTasks,
          ));
        }
      }
      return lanes;
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
        lanes.add(_GanttSwimlane(
          id: entry.key,
          title: projName,
          icon: Icons.folder_outlined,
          color: color,
          tasks: entry.value,
        ));
      }
      return lanes;
    } else {
      // Flat WBS mode
      return [
        _GanttSwimlane(
          id: 'all',
          title: 'All IT Tasks',
          icon: Icons.list_alt,
          color: const Color(0xFF2563EB),
          tasks: widget.tasks,
        ),
      ];
    }
  }
}

class _GanttSwimlane {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<ITTaskModel> tasks;

  const _GanttSwimlane({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.tasks,
  });
}

Color phaseColor(int index) {
  const palette = [
    Color(0xFF1D4E89),
    Color(0xFF3E7C8B),
    Color(0xFFC1622D),
    Color(0xFF3E7A3E),
    Color(0xFF5B3E8B),
  ];
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
