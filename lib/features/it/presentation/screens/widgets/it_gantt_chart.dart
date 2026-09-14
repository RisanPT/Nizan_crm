import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';

/// Appends the Gantt rows/labels/bars for a WBS forest into the given lists.
/// Leaves draw a start→due bar (with a % fill); groups draw a summary bar over
/// their subtree. Returns the number of leaves skipped for having no dates.
int appendForestToGantt({
  required List<WbsNode> forest,
  required List<LegacyGanttRow> rows,
  required List<GanttRowLabel> labels,
  required List<LegacyGanttTask> bars,
  required Map<String, int> stack,
  required Color Function(WbsNode node) colorOf,
  int depthOffset = 0,
}) {
  var undated = 0;
  for (final node in flattenWbs(forest)) {
    final t = node.task;
    rows.add(LegacyGanttRow(id: t.id, label: '${node.wbs}  ${t.title}'));
    labels.add(GanttRowLabel(wbs: node.wbs, title: t.title, depth: node.depth + depthOffset, isGroup: node.isGroup));
    stack[t.id] = 1;
    final color = colorOf(node);
    if (node.isGroup) {
      final span = subtreeSpan(node);
      if (span.start != null && span.end != null && span.end!.isAfter(span.start!)) {
        bars.add(LegacyGanttTask(
            id: 'sum_${t.id}', rowId: t.id, start: span.start!, end: span.end!, color: color.withValues(alpha: 0.30), isSummary: true));
      }
    } else {
      if (t.startDate == null && t.deadline == null) {
        undated++;
        continue;
      }
      final start = t.startDate ?? t.deadline!;
      var end = t.deadline ?? start.add(Duration(days: math.max(1, (t.estimatedHours / 8).ceil())));
      if (!end.isAfter(start)) end = start.add(const Duration(days: 1));
      bars.add(LegacyGanttTask(
          id: t.id, rowId: t.id, start: start, end: end, name: t.title, color: color, completion: t.percentComplete.clamp(0, 100) / 100.0));
    }
  }
  return undated;
}

/// Row label shown in the left column, parallel (by index) to [ItGanttChart.rows].
class GanttRowLabel {
  final String wbs; // number/prefix, e.g. "1.2" (may be empty)
  final String title;
  final int depth; // indentation level
  final bool isGroup; // bold header row
  const GanttRowLabel({this.wbs = '', required this.title, this.depth = 0, this.isGroup = false});
}

/// A reusable Gantt surface: a fixed left label column synced with the
/// [LegacyGanttChartWidget] bars (drag/resize enabled). Used by both the
/// per-project Gantt tab and the cross-project Roadmap.
class ItGanttChart extends StatelessWidget {
  const ItGanttChart({
    super.key,
    required this.rows,
    required this.labels,
    required this.bars,
    required this.stack,
    this.onPressTask,
    this.onTaskUpdate,
    this.enableDrag = true,
    this.emptyHint,
  }) : assert(rows.length == labels.length);

  final List<LegacyGanttRow> rows;
  final List<GanttRowLabel> labels;
  final List<LegacyGanttTask> bars;
  final Map<String, int> stack;
  final void Function(LegacyGanttTask bar)? onPressTask;
  final void Function(LegacyGanttTask bar, DateTime newStart, DateTime newEnd)? onTaskUpdate;
  final bool enableDrag;
  final Widget? emptyHint;

  static const double rowH = 32;
  static const double axisH = 34;
  static const double labelW = 220;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (bars.isEmpty) {
      return emptyHint ?? Center(child: Text('Nothing to plot yet.', style: TextStyle(color: crm.textSecondary)));
    }

    DateTime? gMin, gMax;
    for (final b in bars) {
      if (gMin == null || b.start.isBefore(gMin)) gMin = b.start;
      if (gMax == null || b.end.isAfter(gMax)) gMax = b.end;
    }
    var gridMin = gMin!.subtract(const Duration(days: 3));
    var gridMax = gMax!.add(const Duration(days: 3));
    // Keep a readable minimum window so a single short task doesn't zoom the
    // axis down to half-days — expand symmetrically to ~4 weeks.
    const minSpanDays = 28;
    final spanDays = gridMax.difference(gridMin).inDays;
    if (spanDays < minSpanDays) {
      final extra = minSpanDays - spanDays;
      gridMin = gridMin.subtract(Duration(days: extra ~/ 2));
      gridMax = gridMax.add(Duration(days: extra - extra ~/ 2));
    }
    final totalHeight = axisH + rowH * rows.length;

    return SingleChildScrollView(
      child: SizedBox(
        height: totalHeight,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _labelColumn(crm),
          Expanded(
            child: LegacyGanttChartWidget(
              data: bars,
              visibleRows: rows,
              rowMaxStackDepth: stack,
              rowHeight: rowH,
              axisHeight: axisH,
              gridMin: gridMin.millisecondsSinceEpoch.toDouble(),
              gridMax: gridMax.millisecondsSinceEpoch.toDouble(),
              showNowLine: true,
              nowLineDate: DateTime.now(),
              enableDragAndDrop: enableDrag,
              enableResize: enableDrag,
              enableDragEdgeAutoScroll: true,
              onPressTask: onPressTask,
              onTaskUpdate: onTaskUpdate,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _labelColumn(CrmTheme crm) => SizedBox(
        width: labelW,
        child: Column(children: [
          Container(
            height: axisH,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: crm.border), right: BorderSide(color: crm.border))),
            child: Text('TASK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.textSecondary)),
          ),
          for (final l in labels)
            Container(
              height: rowH,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.only(left: 10 + l.depth * 12, right: 6),
              decoration: BoxDecoration(
                color: l.isGroup ? crm.background : null,
                border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.5), width: 0.5), right: BorderSide(color: crm.border)),
              ),
              child: Row(children: [
                if (l.wbs.isNotEmpty)
                  SizedBox(width: 34, child: Text(l.wbs, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: crm.textSecondary))),
                Expanded(
                  child: Text(l.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: l.isGroup ? FontWeight.w800 : FontWeight.w500, color: crm.textPrimary)),
                ),
              ]),
            ),
        ]),
      );
}
