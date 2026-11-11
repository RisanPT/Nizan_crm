import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/domain/okr_tree_layout.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_filters.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_detail.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_style.dart';

/// The OKR alignment map. Company objectives on the left, the department objectives that feed them
/// next, then the project objectives that feed those — each a card with its progress, how it is doing
/// against the calendar, and what rolls up from what is under it. The line between two cards takes the
/// colour of the one it leads to, so a trail of red shows where a company objective is being let down.
/// Fold a branch with the arrow on its card. On a phone it is an indented list instead.
class OkrTreeView extends StatefulWidget {
  const OkrTreeView({
    super.key,
    required this.okrs,
    this.actions = const OkrDetailActions(),
    this.onAddOkr,
    this.filter,
    this.onFilterChanged,
    this.now,
  });

  final List<OKRModel> okrs;
  final OkrDetailActions actions;
  final VoidCallback? onAddOkr;

  /// Shared with the other views when given; otherwise the tree keeps its own.
  final OkrFilter? filter;
  final ValueChanged<OkrFilter>? onFilterChanged;

  /// The clock (tests, screenshots); defaults to now.
  final DateTime? now;

  @override
  State<OkrTreeView> createState() => _OkrTreeViewState();
}

class _OkrTreeViewState extends State<OkrTreeView> {
  static const _metrics = OkrTreeMetrics(nodeHeight: 124);

  final Set<String> _collapsed = {};
  late final OkrDetailLauncher _detail = OkrDetailLauncher(widget.okrs);
  OkrFilter _ownFilter = const OkrFilter();

  DateTime get _now => widget.now ?? DateTime.now();
  OkrFilter get _filter => widget.filter ?? _ownFilter;

  void _setFilter(OkrFilter f) {
    widget.onFilterChanged?.call(f);
    if (widget.filter == null) setState(() => _ownFilter = f);
  }

  @override
  void didUpdateWidget(covariant OkrTreeView old) {
    super.didUpdateWidget(old);
    if (!identical(old.okrs, widget.okrs)) _detail.update(widget.okrs);
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  void _open(OKRModel o) => _detail.open(context, o, now: _now, actions: widget.actions);

  void _toggle(String id) => setState(() => _collapsed.contains(id) ? _collapsed.remove(id) : _collapsed.add(id));

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (widget.okrs.isEmpty) return _empty(crm);

    final now = _now;
    final visible = _filter.apply(widget.okrs, now);
    final tree = buildOkrTree(visible);
    final foldable = okrIdsWithChildren(tree);

    return LayoutBuilder(
      builder: (context, c) {
        final phone = c.maxWidth < 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OkrFilterBar(
              okrs: widget.okrs,
              filter: _filter,
              onChanged: _setFilter,
              now: now,
              trailing: [
                if (foldable.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: _collapsed.isEmpty ? 'Fold everything' : 'Unfold everything',
                    icon: Icon(_collapsed.isEmpty ? Icons.unfold_less : Icons.unfold_more, size: 18),
                    onPressed: () => setState(() {
                      if (_collapsed.isEmpty) {
                        _collapsed.addAll(foldable);
                      } else {
                        _collapsed.clear();
                      }
                    }),
                  ),
              ],
            ),
            Expanded(
              child: visible.isEmpty
                  ? _noMatch(crm)
                  : phone
                  ? _list(crm, tree, now)
                  : _map(crm, tree, now),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(CrmTheme crm) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_outlined, size: 54, color: crm.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No objectives to map yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Objectives line up here: a company objective, the department objectives that feed it, and the project objectives that feed those.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
          const SizedBox(height: 16),
          if (widget.onAddOkr != null)
            FilledButton.icon(onPressed: widget.onAddOkr, icon: const Icon(Icons.add, size: 16), label: const Text('New objective')),
        ],
      ),
    ),
  );

  Widget _noMatch(CrmTheme crm) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Nothing matches these filters',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => _setFilter(const OkrFilter()), child: const Text('Clear filters')),
      ],
    ),
  );

  // ── wide: the map ─────────────────────────────────────────────────────────

  Widget _map(CrmTheme crm, List<OkrNode> tree, DateTime now) {
    final layout = layoutOkrTree(tree, collapsed: _collapsed, metrics: _metrics);
    final byId = {for (final p in layout.nodes) p.node.okr.id: p};
    final edges = <_Edge>[
      for (final p in layout.nodes)
        if (p.parentId != null)
          _Edge(
            Offset(byId[p.parentId]!.x + _metrics.nodeWidth, byId[p.parentId]!.y + _metrics.nodeHeight / 2),
            Offset(p.x, p.y + _metrics.nodeHeight / 2),
            okrHealthColor(okrPace(p.node.okr, now).health),
          ),
    ];

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(layout.width, 300),
          height: layout.height,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _EdgePainter(edges))),
              for (final p in layout.nodes)
                Positioned(
                  left: p.x,
                  top: p.y,
                  width: _metrics.nodeWidth,
                  height: _metrics.nodeHeight,
                  child: _card(p.node, now, collapsed: p.collapsed, fixedHeight: true),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── narrow: an indented list ──────────────────────────────────────────────

  Widget _list(CrmTheme crm, List<OkrNode> tree, DateTime now) {
    final nodes = listOkrNodes(tree, collapsed: _collapsed);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
      itemCount: nodes.length,
      itemBuilder: (context, i) {
        final n = nodes[i];
        return Padding(
          padding: EdgeInsets.only(left: math.min(n.depth, 3) * 14.0, bottom: 8),
          child: _card(n.node, now, collapsed: n.collapsed, fixedHeight: false),
        );
      },
    );
  }

  Widget _card(OkrNode node, DateTime now, {required bool collapsed, required bool fixedHeight}) {
    return _NodeCard(
      node: node,
      pace: okrPace(node.okr, now),
      below: okrBelow(node, now),
      now: now,
      collapsed: collapsed,
      fixedHeight: fixedHeight,
      onTap: () => _open(node.okr),
      onToggle: node.children.isEmpty ? null : () => _toggle(node.okr.id),
    );
  }
}

/// One objective on the map.
class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.pace,
    required this.below,
    required this.now,
    required this.collapsed,
    required this.fixedHeight,
    required this.onTap,
    required this.onToggle,
  });

  final OkrNode node;
  final OkrPace pace;
  final OkrBelow below;
  final DateTime now;
  final bool collapsed;
  final bool fixedHeight;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final o = node.okr;
    final color = okrHealthColor(pace.health);
    final span = okrSpan(o, now: now);
    final day = DateFormat('d MMM');
    final stale = o.keyResults.any((k) => krIsStale(o, k, now));

    final meta = [
      if (o.projectHeadName.isNotEmpty) o.projectHeadName,
      span.dated ? '${day.format(span.start)} → ${day.format(span.end)}' : 'no dates',
      if (o.keyResults.isNotEmpty) '${o.keyResults.length} KR${o.keyResults.length == 1 ? '' : 's'}',
    ].join(' · ');

    final fed = below.fedBy == 0
        ? ''
        : [
            collapsed ? '${below.total} folded' : 'fed by ${below.fedBy}',
            if (below.rollup != null) 'avg ${below.rollup}%',
            if (below.attention > 0) '${below.attention} need${below.attention == 1 ? 's' : ''} attention',
          ].join(' · ');

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: fixedHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: OkrLevelChip(level: o.effectiveLevel),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  o.objective,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary, height: 1.2),
                ),
              ),
              if (onToggle != null)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onToggle,
                  child: Tooltip(
                    message: collapsed ? 'Unfold ${below.total} below' : 'Fold what is under this',
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: Icon(collapsed ? Icons.chevron_right : Icons.expand_more, size: 20, color: crm.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Flexible(child: OkrHealthChip(pace: pace, withNote: true)),
              const SizedBox(width: 8),
              Text(
                '${pace.progress}%',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          OkrProgressBar(pace: pace, height: 7),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
                ),
              ),
              if (stale)
                Tooltip(
                  message: 'A key result needs a check-in',
                  child: Icon(Icons.schedule, size: 13, color: okrHealthColor(OkrHealth.atRisk)),
                ),
            ],
          ),
          if (fed.isNotEmpty)
            Text(
              fed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: below.attention > 0 ? okrHealthColor(OkrHealth.atRisk) : crm.textSecondary,
              ),
            ),
        ],
      ),
    );

    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: crm.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            // (a Stack, not an IntrinsicHeight row: the progress bar inside measures itself with a
            // LayoutBuilder, which cannot answer intrinsic-size questions)
            child: Stack(
              children: [
                Padding(padding: const EdgeInsets.only(left: 4), child: body),
                Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Edge {
  const _Edge(this.from, this.to, this.color);

  final Offset from;
  final Offset to;
  final Color color;
}

/// The lines from a card to what feeds it: a curve out of the right of the parent into the left of the
/// child, in the child's colour.
class _EdgePainter extends CustomPainter {
  _EdgePainter(this.edges);

  final List<_Edge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final bend = (e.to.dx - e.from.dx) / 2;
      final path = Path()
        ..moveTo(e.from.dx, e.from.dy)
        ..cubicTo(e.from.dx + bend, e.from.dy, e.to.dx - bend, e.to.dy, e.to.dx, e.to.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = e.color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      canvas.drawCircle(e.to, 3, Paint()..color = e.color.withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) {
    if (old.edges.length != edges.length) return true;
    for (var i = 0; i < edges.length; i++) {
      if (old.edges[i].from != edges[i].from || old.edges[i].to != edges[i].to || old.edges[i].color != edges[i].color) return true;
    }
    return false;
  }
}
