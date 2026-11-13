import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_filters.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_detail.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_phone.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_style.dart';

enum OkrZoomScale { quarter, month, week }

enum _DragMode { move, start, end }

/// The OKR timeline.
///
///  * Each objective is a bar from its start to its deadline, filled to its progress, coloured by
///    how it is doing, with a tick for where the calendar says it should be today.
///  * Objectives are laid out as the alignment tree (company → department → project): what
///    contributes to an objective sits under it, indented.
///  * Under an objective, each key result is a small chart of its check-ins against the straight
///    line to its target; a key result nobody has reported on for weeks is flagged.
///  * Tap an objective for its detail (check in, edit, add under it); drag a bar to move its dates
///    or an end to resize it, if the server says you may.
///  * On a phone it becomes a list by month (a horizontal Gantt cannot work there).
class ITOkrTimeline extends StatefulWidget {
  const ITOkrTimeline({
    super.key,
    required this.okrs,
    this.onEditOkr,
    this.onCheckInKeyResult,
    this.onAddOkr,
    this.onAddChild,
    this.canAddUnder,
    this.onChangeDates,
    this.onDelete,
    this.filter,
    this.onFilterChanged,
    this.now,
    this.groupByProject,
  });

  final List<OKRModel> okrs;
  final void Function(OKRModel okr)? onEditOkr;
  final void Function(OKRModel okr, KeyResultItem kr)? onCheckInKeyResult;
  final VoidCallback? onAddOkr;

  /// Add an objective that contributes to [parent].
  final void Function(OKRModel parent)? onAddChild;

  /// Whether "add a contributing objective" is offered under [okr] (null = always).
  final bool Function(OKRModel okr)? canAddUnder;

  /// A bar was dragged: save these dates. The timeline shows them again from the list afterwards,
  /// so a refused change simply springs back.
  final Future<void> Function(OKRModel okr, DateTime start, DateTime end)? onChangeDates;

  final void Function(OKRModel okr)? onDelete;

  /// What the timeline is narrowed to. Given (with [onFilterChanged]) it is shared with the other
  /// views; without it the timeline keeps its own.
  final OkrFilter? filter;
  final ValueChanged<OkrFilter>? onFilterChanged;

  /// The clock (tests, screenshots); defaults to now.
  final DateTime? now;

  /// Whether to group by Project as the MAIN level, showing OKRs underneath.
  final bool? groupByProject;

  @override
  State<ITOkrTimeline> createState() => _ITOkrTimelineState();
}

class _Seg {
  const _Seg(this.x, this.w, this.label, {this.strong = false});
  final double x;
  final double w;
  final String label;
  final bool strong;
}

class _ITOkrTimelineState extends State<ITOkrTimeline> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _leftVertical = ScrollController();
  final ScrollController _rightVertical = ScrollController();
  final Set<String> _collapsed = {};
  final Set<String> _collapsedProjects = {};
  late bool _groupByProject = widget.groupByProject ?? false;
  late final OkrDetailLauncher _detail = OkrDetailLauncher(widget.okrs);
  OkrFilter _ownFilter = const OkrFilter();
  OkrZoomScale _zoom = OkrZoomScale.month;
  bool _didInitialScroll = false;

  // a bar being dragged
  String? _dragId;
  _DragMode _dragMode = _DragMode.move;
  double _dragPx = 0;

  static const double _leftPaneWidth = 330;
  static const double _projectRow = 46;
  static const double _objectiveRow = 46;
  static const double _keyResultRow = 40;
  static const double _headerHeight = 56;

  DateTime get _now => widget.now ?? DateTime.now();

  OkrFilter get _filter => widget.filter ?? _ownFilter;

  void _setFilter(OkrFilter f) {
    widget.onFilterChanged?.call(f);
    if (widget.filter == null) setState(() => _ownFilter = f);
  }

  double get _dayWidth => switch (_zoom) {
        OkrZoomScale.week => 24.0,
        OkrZoomScale.month => 12.0,
        OkrZoomScale.quarter => 5.5,
      };

  @override
  void initState() {
    super.initState();
    // the two panes scroll together vertically
    _leftVertical.addListener(() {
      if (_rightVertical.hasClients && _rightVertical.offset != _leftVertical.offset) _rightVertical.jumpTo(_leftVertical.offset);
    });
    _rightVertical.addListener(() {
      if (_leftVertical.hasClients && _leftVertical.offset != _rightVertical.offset) _leftVertical.jumpTo(_rightVertical.offset);
    });
  }

  @override
  void didUpdateWidget(covariant ITOkrTimeline old) {
    super.didUpdateWidget(old);
    if (!identical(old.okrs, widget.okrs)) _detail.update(widget.okrs);
    if (widget.groupByProject != null && widget.groupByProject != old.groupByProject) {
      _groupByProject = widget.groupByProject!;
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _leftVertical.dispose();
    _rightVertical.dispose();
    _detail.dispose();
    super.dispose();
  }

  // ── dates ─────────────────────────────────────────────────────────────────

  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  static DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  void _scrollToToday(DateTime start, {bool animate = true}) {
    if (!_horizontal.hasClients) return;
    final now = _now;
    final days = _daysBetween(start, now);
    if (days < 0) return;
    final x = math.max(0.0, (days + now.hour / 24) * _dayWidth - 220);
    final target = math.min(x, _horizontal.position.maxScrollExtent);
    if (animate) {
      _horizontal.animateTo(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      _horizontal.jumpTo(target);
    }
  }

  // ── filters ───────────────────────────────────────────────────────────────

  // ── detail ────────────────────────────────────────────────────────────────

  void _open(OKRModel o) {
    _detail.open(
      context,
      o,
      now: _now,
      actions: OkrDetailActions(
        onEdit: widget.onEditOkr,
        onCheckIn: widget.onCheckInKeyResult,
        onAddChild: widget.onAddChild,
        canAddUnder: widget.canAddUnder,
        onDelete: widget.onDelete,
      ),
    );
  }

  // ── drag ──────────────────────────────────────────────────────────────────

  void _dragStart(OKRModel o, _DragMode mode) => setState(() {
        _dragId = o.id;
        _dragMode = mode;
        _dragPx = 0;
      });

  void _dragUpdate(double dx) => setState(() => _dragPx += dx);

  Future<void> _dragEnd(OKRModel o) async {
    final days = (_dragPx / _dayWidth).round();
    final mode = _dragMode;
    setState(() {
      _dragId = null;
      _dragPx = 0;
    });
    if (days == 0 || widget.onChangeDates == null) return;
    final span = okrSpan(o, now: _now);
    var s = span.start;
    var e = span.end;
    switch (mode) {
      case _DragMode.move:
        s = _addDays(s, days);
        e = _addDays(e, days);
      case _DragMode.start:
        s = _addDays(s, days);
        if (s.isAfter(e)) s = e;
      case _DragMode.end:
        e = _addDays(e, days);
        if (e.isBefore(s)) e = s;
    }
    await widget.onChangeDates!(o, s, e);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (widget.okrs.isEmpty) return _empty(crm);

    final now = _now;
    final visible = _filter.apply(widget.okrs, now);

    return LayoutBuilder(builder: (context, c) {
      final phone = c.maxWidth < 720;
      final tree = buildOkrTree(visible);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OkrFilterBar(
          okrs: widget.okrs,
          filter: _filter,
          onChanged: _setFilter,
          now: now,
          trailing: phone ? const [] : _wideControls(crm, okrTimelineBounds(visible, now).start),
        ),
        Expanded(
          child: visible.isEmpty
              ? _noMatch(crm)
              : phone
                  ? OkrPhoneTimeline(okrs: visible, now: now, onOpen: _open)
                  : _canvas(crm, visible, tree, now),
        ),
      ]);
    });
  }

  Widget _empty(CrmTheme crm) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timeline_outlined, size: 54, color: crm.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No objectives to show on the timeline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            const SizedBox(height: 6),
            Text('Add an objective with a start date and a deadline to see its progress over time.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            const SizedBox(height: 16),
            if (widget.onAddOkr != null) FilledButton.icon(onPressed: widget.onAddOkr, icon: const Icon(Icons.add, size: 16), label: const Text('New objective')),
          ]),
        ),
      );

  Widget _noMatch(CrmTheme crm) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Nothing matches these filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _setFilter(const OkrFilter()),
              child: const Text('Clear filters'),
            ),
          ]),
        ),
      );

  // ── toolbar ───────────────────────────────────────────────────────────────

  /// What the timeline adds to the shared filter bar on a wide screen: fold / unfold, jump to
  /// today, and the zoom.
  List<Widget> _wideControls(CrmTheme crm, DateTime boundsStart) => [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: _collapsed.isEmpty && _collapsedProjects.isEmpty ? 'Collapse all' : 'Expand all',
          icon: Icon(_collapsed.isEmpty && _collapsedProjects.isEmpty ? Icons.unfold_less : Icons.unfold_more, size: 18),
          onPressed: () => setState(() {
            if (_collapsed.isEmpty && _collapsedProjects.isEmpty) {
              if (_groupByProject) {
                final prjKeys = <String>{};
                for (final o in widget.okrs) {
                  final k = o.projectName.trim().isNotEmpty
                      ? (o.projectId != null && o.projectId!.isNotEmpty ? o.projectId! : 'name:${o.projectName.trim().toLowerCase()}')
                      : (o.projectId != null && o.projectId!.isNotEmpty ? o.projectId! : '__company__');
                  prjKeys.add(k);
                }
                _collapsedProjects.addAll(prjKeys);
              }
              _collapsed.addAll([for (final o in widget.okrs) if (o.keyResults.isNotEmpty || widget.okrs.any((c) => c.parentObjectiveId == o.id)) o.id]);
            } else {
              _collapsedProjects.clear();
              _collapsed.clear();
            }
          }),
        ),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          segments: const [
            ButtonSegment(value: true, icon: Icon(Icons.folder_outlined, size: 14), label: Text('By Project', style: TextStyle(fontSize: 11.5))),
            ButtonSegment(value: false, icon: Icon(Icons.account_tree_outlined, size: 14), label: Text('Tree', style: TextStyle(fontSize: 11.5))),
          ],
          selected: {_groupByProject},
          onSelectionChanged: (s) => setState(() => _groupByProject = s.first),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: const Size(0, 32)),
          onPressed: () => _scrollToToday(boundsStart),
          icon: const Icon(Icons.my_location, size: 14),
          label: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        SegmentedButton<OkrZoomScale>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          segments: const [
            ButtonSegment(value: OkrZoomScale.quarter, label: Text('Quarter', style: TextStyle(fontSize: 11.5))),
            ButtonSegment(value: OkrZoomScale.month, label: Text('Month', style: TextStyle(fontSize: 11.5))),
            ButtonSegment(value: OkrZoomScale.week, label: Text('Week', style: TextStyle(fontSize: 11.5))),
          ],
          selected: {_zoom},
          onSelectionChanged: (s) {
            setState(() => _zoom = s.first);
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday(boundsStart, animate: false));
          },
        ),
      ];

  // ── the canvas ────────────────────────────────────────────────────────────

  Widget _canvas(CrmTheme crm, List<OKRModel> visible, List<OkrNode> tree, DateTime now) {
    final rows = _groupByProject
        ? okrProjectRows(visible, collapsedProjects: _collapsedProjects, collapsedObjectives: _collapsed)
        : okrRows(tree, collapsed: _collapsed);
    final paces = {for (final o in visible) o.id: okrPace(o, now)};
    final bounds = okrTimelineBounds(visible, now);
    final totalDays = _daysBetween(bounds.start, bounds.end) + 1;
    final dw = _dayWidth;
    final width = math.max(900.0, totalDays * dw);
    final todayX = (_daysBetween(bounds.start, now) + now.hour / 24) * dw;
    final headerSegs = _headerSegments(bounds.start, bounds.end, dw);
    final multiProject = {for (final o in visible) o.projectId ?? ''}.length > 1;

    if (!_didInitialScroll) {
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday(bounds.start, animate: false));
    }

    return Container(
      color: crm.background,
      child: Row(children: [
        // left: the alignment tree
        SizedBox(
          width: _leftPaneWidth,
          child: Column(children: [
            Container(
              height: _headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(color: crm.surface, border: Border(right: BorderSide(color: crm.border), bottom: BorderSide(color: crm.border))),
              child: Text(_groupByProject ? 'Projects & OKRs' : 'Objectives & key results', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            ),
            Expanded(
              child: ListView.builder(
                controller: _leftVertical,
                itemCount: rows.length,
                itemBuilder: (context, i) => switch (rows[i]) {
                  final OkrProjectRow r => _leftProject(crm, r),
                  final OkrObjectiveRow r => _leftObjective(crm, r, paces[r.okr.id]!, multiProject),
                  final OkrKeyResultRow r => _leftKeyResult(crm, r, now),
                },
              ),
            ),
          ]),
        ),

        // right: time
        Expanded(
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(children: [
                _header(crm, headerSegs, todayX, width),
                Expanded(
                  child: Stack(children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPainter(
                          top: headerSegs.top,
                          bottom: headerSegs.bottom,
                          start: bounds.start,
                          totalDays: totalDays,
                          dayWidth: dw,
                          weekends: _zoom == OkrZoomScale.week,
                          line: crm.border.withValues(alpha: 0.35),
                          strong: crm.border.withValues(alpha: 0.8),
                          shade: crm.border.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    ListView.builder(
                      controller: _rightVertical,
                      itemCount: rows.length,
                      itemBuilder: (context, i) => switch (rows[i]) {
                        final OkrProjectRow r => _rightProject(crm, r, bounds.start, width, now),
                        final OkrObjectiveRow r => _rightObjective(crm, r.okr, paces[r.okr.id]!, bounds.start, width, now),
                        final OkrKeyResultRow r => _rightKeyResult(crm, r.okr, r.kr, bounds.start, width, now),
                      },
                    ),
                    if (todayX >= 0 && todayX <= width) Positioned(top: 0, bottom: 0, left: todayX - 1, child: IgnorePointer(child: Container(width: 2, color: Colors.red.shade400.withValues(alpha: 0.8)))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────

  ({List<_Seg> top, List<_Seg> bottom}) _headerSegments(DateTime start, DateTime end, double dw) {
    final top = <_Seg>[];
    final bottom = <_Seg>[];
    double x(DateTime d) => _daysBetween(start, d) * dw;

    if (_zoom == OkrZoomScale.quarter) {
      var q = DateTime(start.year, start.month - (start.month - 1) % 3, 1);
      while (!q.isAfter(end)) {
        final next = DateTime(q.year, q.month + 3, 1);
        final from = q.isBefore(start) ? start : q;
        top.add(_Seg(x(from), x(next) - x(from), 'Q${(q.month - 1) ~/ 3 + 1} ${q.year}', strong: true));
        q = next;
      }
      var m = DateTime(start.year, start.month, 1);
      while (!m.isAfter(end)) {
        final next = DateTime(m.year, m.month + 1, 1);
        bottom.add(_Seg(x(m), x(next) - x(m), DateFormat('MMM').format(m)));
        m = next;
      }
      return (top: top, bottom: bottom);
    }

    var m = DateTime(start.year, start.month, 1);
    while (!m.isAfter(end)) {
      final next = DateTime(m.year, m.month + 1, 1);
      top.add(_Seg(x(m), x(next) - x(m), DateFormat('MMMM yyyy').format(m), strong: true));
      m = next;
    }
    if (_zoom == OkrZoomScale.week) {
      for (var d = start; !d.isAfter(end); d = _addDays(d, 1)) {
        bottom.add(_Seg(x(d), dw, '${d.day}'));
      }
    } else {
      // weeks, from each Monday
      var d = start;
      while (d.weekday != DateTime.monday) {
        d = _addDays(d, 1);
      }
      for (; !d.isAfter(end); d = _addDays(d, 7)) {
        bottom.add(_Seg(x(d), 7 * dw, '${d.day}'));
      }
    }
    return (top: top, bottom: bottom);
  }

  Widget _header(CrmTheme crm, ({List<_Seg> top, List<_Seg> bottom}) segs, double todayX, double width) {
    Widget label(_Seg s, {required double top, required double height, required bool bold}) => Positioned(
          left: s.x,
          top: top,
          width: s.w,
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(s.label, maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: bold ? 11 : 10, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? crm.textPrimary : crm.textSecondary)),
            ),
          ),
        );

    return Container(
      height: _headerHeight,
      width: width,
      decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
      child: Stack(children: [
        for (final s in segs.top) label(s, top: 0, height: 28, bold: true),
        Positioned(left: 0, right: 0, top: 28, child: Container(height: 1, color: crm.border.withValues(alpha: 0.5))),
        for (final s in segs.bottom) label(s, top: 28, height: 28, bold: false),
        if (todayX >= 0 && todayX <= width)
          Positioned(
            left: todayX - 19,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(8)),
              child: const Text('Today', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
      ]),
    );
  }

  // ── left rows ─────────────────────────────────────────────────────────────

  Widget _leftProject(CrmTheme crm, OkrProjectRow r) {
    final dateSub = [
      if (r.earliestStart != null) DateFormat('MMM d').format(r.earliestStart!),
      if (r.latestEnd != null) DateFormat('MMM d').format(r.latestEnd!),
    ].join(' – ');

    final subtitle = [
      if (r.department.isNotEmpty) r.department,
      if (r.projectHeadName.isNotEmpty) r.projectHeadName,
      '${r.okrs.length} ${r.okrs.length == 1 ? "OKR" : "OKRs"}',
      if (dateSub.isNotEmpty) dateSub,
    ].join(' · ');

    final color = r.isCompany ? const Color(0xFF8B5CF6) : crm.primary;

    return Container(
      height: _projectRow,
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(
          right: BorderSide(color: crm.border),
          bottom: BorderSide(color: crm.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: _projectRow,
            color: color,
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => r.collapsed ? _collapsedProjects.remove(r.key) : _collapsedProjects.add(r.key)),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                r.collapsed ? Icons.arrow_right : Icons.arrow_drop_down,
                size: 20,
                color: crm.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              r.isCompany ? Icons.corporate_fare_rounded : Icons.rocket_launch_rounded,
              size: 13,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: crm.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '${r.progress}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _leftObjective(CrmTheme crm, OkrObjectiveRow r, OkrPace pace, bool multiProject) {
    final o = r.okr;
    final color = okrHealthColor(pace.health);
    final level = o.effectiveLevel;
    final scope = switch (level) {
      'company' => 'Company',
      'department' => o.department,
      _ => multiProject && o.projectName.isNotEmpty ? o.projectName : '',
    };
    final subtitle = [
      if (scope.isNotEmpty && !_groupByProject) scope,
      if (o.projectHeadName.isNotEmpty) o.projectHeadName,
    ].join(' · ');

    return InkWell(
      onTap: () => _open(o),
      child: Container(
        height: _objectiveRow,
        padding: EdgeInsets.only(left: 6 + r.depth * 16.0, right: 10),
        decoration: BoxDecoration(color: crm.surface, border: Border(right: BorderSide(color: crm.border), bottom: BorderSide(color: crm.border.withValues(alpha: 0.4)))),
        child: Row(children: [
          if (r.expandable)
            InkWell(
              onTap: () => setState(() => r.collapsed ? _collapsed.remove(o.id) : _collapsed.add(o.id)),
              child: Padding(padding: const EdgeInsets.all(2), child: Icon(r.collapsed ? Icons.arrow_right : Icons.arrow_drop_down, size: 20, color: crm.textSecondary)),
            )
          else
            const SizedBox(width: 24),
          OkrLevelChip(level: level),
          const SizedBox(width: 7),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.objective, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
            ]),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: [pace.health.label, okrPaceNote(pace)].where((t) => t.isNotEmpty).join(' · '),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
              child: Text('${pace.progress}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _leftKeyResult(CrmTheme crm, OkrKeyResultRow r, DateTime now) {
    final kr = r.kr;
    final stale = krIsStale(r.okr, kr, now);
    final color = okrKeyResultColor(kr);
    return InkWell(
      onTap: r.okr.access.canCheckIn && widget.onCheckInKeyResult != null ? () => widget.onCheckInKeyResult!(r.okr, kr) : () => _open(r.okr),
      child: Container(
        height: _keyResultRow,
        padding: EdgeInsets.only(left: 30 + r.depth * 16.0, right: 10),
        decoration: BoxDecoration(color: crm.background, border: Border(right: BorderSide(color: crm.border), bottom: BorderSide(color: crm.border.withValues(alpha: 0.2)))),
        child: Row(children: [
          Icon(kr.completed ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(kr.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: kr.completed ? const Color(0xFF059669) : crm.textPrimary, decoration: null)),
          ),
          if (stale) Tooltip(message: 'Nobody has reported on this lately', child: Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.schedule, size: 14, color: okrHealthColor(OkrHealth.atRisk)))),
          Text('${okrNumber(kr.currentValue)}/${okrNumber(kr.targetValue)} ${kr.unit}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
        ]),
      ),
    );
  }

  // ── right rows ────────────────────────────────────────────────────────────

  BoxDecoration _rowBorder(CrmTheme crm, {double alpha = 0.2}) => BoxDecoration(border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: alpha))));

  Widget _rightProject(CrmTheme crm, OkrProjectRow r, DateTime boundsStart, double width, DateTime now) {
    final dw = _dayWidth;
    final color = r.isCompany ? const Color(0xFF8B5CF6) : crm.primary;

    Widget? bar;
    if (r.earliestStart != null && r.latestEnd != null) {
      final start = r.earliestStart!;
      final end = r.latestEnd!.isBefore(start) ? start : r.latestEnd!;
      final left = _daysBetween(boundsStart, start) * dw;
      final spanDays = _daysBetween(start, end) + 1;
      final barW = math.max(dw, spanDays * dw);
      final pct = (r.progress / 100.0).clamp(0.0, 1.0);

      bar = Positioned(
        left: left,
        top: 13,
        width: barW,
        height: 20,
        child: Tooltip(
          message: '${r.projectName} · ${r.progress}% complete (${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)})',
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
            ),
            child: Stack(
              children: [
                if (pct > 0)
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${r.projectName} · ${r.progress}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: _projectRow,
      width: width,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.03),
        border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.35))),
      ),
      child: Stack(
        children: [
          ?bar,
        ],
      ),
    );
  }

  Widget _rightObjective(CrmTheme crm, OKRModel o, OkrPace pace, DateTime boundsStart, double width, DateTime now) {
    final dw = _dayWidth;
    final span = okrSpan(o, now: now);
    final spanDays = _daysBetween(span.start, span.end) + 1;
    final canDrag = o.access.canManage && widget.onChangeDates != null;
    final color = okrHealthColor(pace.health);

    var left = _daysBetween(boundsStart, span.start) * dw;
    var barW = spanDays * dw;
    if (_dragId == o.id) {
      final d = (_dragPx / dw).round();
      switch (_dragMode) {
        case _DragMode.move:
          left += d * dw;
        case _DragMode.start:
          final c = math.min(d, spanDays - 1);
          left += c * dw;
          barW -= c * dw;
        case _DragMode.end:
          barW = math.max(dw, barW + d * dw);
      }
    }
    barW = math.max(barW, 30.0);

    final note = [pace.health.label, okrPaceNote(pace)].where((s) => s.isNotEmpty).join(' · ');
    final noteW = note.length * 6.4 + 10;
    final noteOnRight = left + barW + 8 + noteW <= width;

    final tip = [
      o.objective,
      '${pace.progress}% done${pace.expectedPercent != null && pace.health != OkrHealth.done ? ' · should be ${pace.expectedPercent}% by today' : ''}',
      span.dated ? '${DateFormat('d MMM').format(span.start)} – ${DateFormat('d MMM yyyy').format(span.end)}' : 'No dates set',
      if (canDrag) 'Drag to move · drag an end to resize',
    ].join('\n');

    return Container(
      height: _objectiveRow,
      width: width,
      decoration: _rowBorder(crm),
      child: Stack(children: [
        Positioned(
          left: left,
          top: 11,
          width: barW,
          height: 24,
          child: Tooltip(
            message: tip,
            waitDuration: const Duration(milliseconds: 500),
            child: Stack(children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _open(o),
                  onHorizontalDragStart: canDrag ? (_) => _dragStart(o, _DragMode.move) : null,
                  onHorizontalDragUpdate: canDrag ? (d) => _dragUpdate(d.delta.dx) : null,
                  onHorizontalDragEnd: canDrag ? (_) => _dragEnd(o) : null,
                  child: _bar(crm, o, pace, color, span.dated),
                ),
              ),
              if (canDrag) ...[
                Positioned(left: 0, top: 0, bottom: 0, width: 8, child: _handle(o, _DragMode.start)),
                Positioned(right: 0, top: 0, bottom: 0, width: 8, child: _handle(o, _DragMode.end)),
              ],
            ]),
          ),
        ),
        if (note.isNotEmpty)
          Positioned(
            top: 15,
            left: noteOnRight ? left + barW + 8 : null,
            right: noteOnRight ? null : math.max(0, width - left + 8),
            child: IgnorePointer(child: Text(note, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color))),
          ),
      ]),
    );
  }

  Widget _handle(OKRModel o, _DragMode mode) => MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _dragStart(o, mode),
          onHorizontalDragUpdate: (d) => _dragUpdate(d.delta.dx),
          onHorizontalDragEnd: (_) => _dragEnd(o),
          child: Center(child: Container(width: 3, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(2)))),
        ),
      );

  Widget _bar(CrmTheme crm, OKRModel o, OkrPace pace, Color color, bool dated) {
    final tick = pace.expected;
    return LayoutBuilder(builder: (context, c) {
      return Stack(clipBehavior: Clip.none, children: [
        Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: dated ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: dated ? 0.6 : 0.4)),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: (pace.progress / 100).clamp(0.0, 1.0), child: Container(color: color.withValues(alpha: 0.5))),
          ),
        ),
        // Where it should be today IS the today line for a bar that crosses it, so the tick is only
        // drawn once the deadline has passed (100% is the end of the bar).
        if (tick != null && pace.overdueDays > 0)
          Positioned(
            left: (c.maxWidth * tick).clamp(0.0, c.maxWidth) - 1,
            top: -3,
            bottom: -3,
            child: Container(width: 2, decoration: BoxDecoration(color: crm.textPrimary.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(1))),
          ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (pace.health == OkrHealth.blocked) ...[
                  Icon(Icons.block, size: 12, color: crm.textPrimary),
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(
                    dated ? '${pace.progress}%' : '${pace.progress}% · no dates',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.textPrimary),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]);
    });
  }

  Widget _rightKeyResult(CrmTheme crm, OKRModel o, KeyResultItem kr, DateTime boundsStart, double width, DateTime now) {
    final dw = _dayWidth;
    final span = okrSpan(o, now: now);
    final spanDays = _daysBetween(span.start, span.end) + 1;
    final left = _daysBetween(boundsStart, span.start) * dw;
    final trackW = math.max(spanDays * dw, 60.0);
    final color = okrKeyResultColor(kr);
    final stale = krIsStale(o, kr, now);

    double fx(DateTime d) => ((_daysBetween(span.start, d) + d.hour / 24) / spanDays).clamp(0.0, 1.0);
    double fy(double value, bool done) => done ? 1.0 : (kr.targetValue <= 0 ? 0.0 : (value / kr.targetValue).clamp(0.0, 1.0));

    final points = <Offset>[
      for (final c in kr.checkIns) Offset(fx(c.at), fy(c.value, c.completed)),
      // a key result with a value but no log (older than the log): one point, as of today
      if (kr.checkIns.isEmpty && (kr.currentValue > 0 || kr.completed)) Offset(fx(now), kr.attainment),
    ];

    final label = '${okrNumber(kr.currentValue)}/${okrNumber(kr.targetValue)} ${kr.unit}  ·  ${(kr.attainment * 100).round()}%';
    final labelW = label.length * 6.2 + 28;
    final onRight = left + trackW + 8 + labelW <= width;
    final canCheckIn = o.access.canCheckIn && widget.onCheckInKeyResult != null;

    final reports = kr.checkIns.length;
    final tip = [
      kr.title,
      '${okrNumber(kr.currentValue)} of ${okrNumber(kr.targetValue)} ${kr.unit}',
      reports == 0 ? 'No reports yet' : '$reports report${reports == 1 ? '' : 's'} · last ${DateFormat('d MMM').format(kr.lastCheckInAt!)}',
      if (canCheckIn) 'Click to check in',
    ].join('\n');

    return Container(
      height: _keyResultRow,
      width: width,
      decoration: _rowBorder(crm, alpha: 0.12),
      child: Stack(children: [
        Positioned(
          left: left,
          top: 4,
          bottom: 4,
          width: trackW,
          child: Tooltip(
            message: tip,
            waitDuration: const Duration(milliseconds: 500),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canCheckIn ? () => widget.onCheckInKeyResult!(o, kr) : () => _open(o),
              child: CustomPaint(
                painter: _KeyResultPainter(
                  points: points,
                  nowFx: kr.completed ? null : fx(now),
                  color: color,
                  track: color.withValues(alpha: 0.07),
                  ideal: crm.textSecondary.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: onRight ? left + trackW + 8 : null,
          right: onRight ? null : math.max(0, width - left + 8),
          child: IgnorePointer(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (stale) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.schedule, size: 13, color: okrHealthColor(OkrHealth.atRisk))),
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── painters ──────────────────────────────────────────────────────────────────

/// Month / week lines behind the bars, and the weekends when zoomed in to days.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.top,
    required this.bottom,
    required this.start,
    required this.totalDays,
    required this.dayWidth,
    required this.weekends,
    required this.line,
    required this.strong,
    required this.shade,
  });

  final List<_Seg> top;
  final List<_Seg> bottom;
  final DateTime start;
  final int totalDays;
  final double dayWidth;
  final bool weekends;
  final Color line;
  final Color strong;
  final Color shade;

  @override
  void paint(Canvas canvas, Size size) {
    if (weekends) {
      final p = Paint()..color = shade;
      for (var i = 0; i < totalDays; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        if (d.weekday >= DateTime.saturday) canvas.drawRect(Rect.fromLTWH(i * dayWidth, 0, dayWidth, size.height), p);
      }
    }
    final thin = Paint()..color = line..strokeWidth = 1;
    for (final s in bottom) {
      canvas.drawLine(Offset(s.x, 0), Offset(s.x, size.height), thin);
    }
    final bold = Paint()..color = strong..strokeWidth = 1;
    for (final s in top) {
      canvas.drawLine(Offset(s.x, 0), Offset(s.x, size.height), bold);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.totalDays != totalDays || old.dayWidth != dayWidth || old.weekends != weekends || old.start != start || old.line != line;
}

/// A key result over the objective's span: the straight line to the target (where it should be),
/// the reports so far, and a flat run from the last one to today — so a key result that has gone
/// quiet is visibly flat.
class _KeyResultPainter extends CustomPainter {
  _KeyResultPainter({required this.points, required this.nowFx, required this.color, required this.track, required this.ideal});

  /// (x along the span 0..1, how far to the target 0..1), oldest first.
  final List<Offset> points;
  final double? nowFx;
  final Color color;
  final Color track;
  final Color ideal;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)), Paint()..color = track);

    const pad = 5.0;
    final bottom = size.height - pad;
    final topY = pad;
    Offset at(double fx, double fy) => Offset(fx * size.width, bottom - fy * (bottom - topY));

    _dashed(canvas, at(0, 0), at(1, 1), Paint()..color = ideal..strokeWidth = 1.2);

    if (points.isEmpty) return;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    final pts = [for (final p in points) at(p.dx, p.dy)];
    if (pts.length > 1) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, line);
    }
    final last = pts.last;
    final nowX = nowFx == null ? null : nowFx! * size.width;
    if (nowX != null && nowX > last.dx + 1) {
      _dashed(canvas, last, Offset(nowX, last.dy), Paint()..color = color.withValues(alpha: 0.6)..strokeWidth = 1.5);
    }
    for (final p in pts) {
      canvas.drawCircle(p, 3.2, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3.2, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6);
    }
    canvas.drawCircle(last, 3.4, Paint()..color = color);
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final len = (b - a).distance;
    if (len == 0) return;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len; d += 7) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 3.5, len), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _KeyResultPainter old) =>
      !listEquals(old.points, points) || old.nowFx != nowFx || old.color != color || old.ideal != ideal;
}
