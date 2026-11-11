import 'package:nizan_crm/features/it/domain/okr_pace.dart';

// The OKR alignment map: company objectives on the left, the department objectives that feed them
// next, then project objectives — each a card at a fixed size, so where everything goes (and the
// lines between them) is worked out here rather than measured on screen. Pure, so it is tested.

/// What is under an objective in the alignment tree.
class OkrBelow {
  const OkrBelow({required this.fedBy, required this.total, required this.rollup, required this.health});

  /// The objectives that contribute to it directly.
  final int fedBy;

  /// Everything beneath it, however deep.
  final int total;

  /// The average progress of the objectives that feed it directly (percent); null when nothing does.
  final int? rollup;

  /// Everything beneath it, by how it is doing.
  final Map<OkrHealth, int> health;

  /// How many beneath it need attention (at risk, off track, blocked).
  int get attention => health.entries.where((e) => e.key.needsAttention).fold(0, (a, e) => a + e.value);
}

/// What sits under [n], as of [now]. The roll-up is the plain average of what feeds it directly:
/// it is shown beside the objective's own progress, it never replaces it.
OkrBelow okrBelow(OkrNode n, DateTime now) {
  final health = <OkrHealth, int>{};
  var total = 0;
  void walk(OkrNode c) {
    total++;
    final h = okrPace(c.okr, now).health;
    health[h] = (health[h] ?? 0) + 1;
    c.children.forEach(walk);
  }

  n.children.forEach(walk);
  final rollup = n.children.isEmpty
      ? null
      : (n.children.map((c) => c.okr.progress.clamp(0, 100)).reduce((a, b) => a + b) / n.children.length).round();
  return OkrBelow(fedBy: n.children.length, total: total, rollup: rollup, health: health);
}

/// The size of a card and the space around it.
class OkrTreeMetrics {
  const OkrTreeMetrics({this.nodeWidth = 300, this.nodeHeight = 120, this.gapX = 64, this.gapY = 14, this.padding = 16});

  final double nodeWidth;
  final double nodeHeight;
  final double gapX;
  final double gapY;
  final double padding;
}

/// A card and where it goes.
class OkrPlaced {
  const OkrPlaced(this.node, this.x, this.y, {this.parentId, required this.collapsed});

  final OkrNode node;
  final double x;
  final double y;
  final String? parentId;

  /// It has objectives under it that are folded away.
  final bool collapsed;

  bool get hasChildren => node.children.isNotEmpty;
}

class OkrTreeLayout {
  const OkrTreeLayout(this.nodes, this.width, this.height);

  /// Parents before the objectives under them.
  final List<OkrPlaced> nodes;
  final double width;
  final double height;

  OkrPlaced? byId(String id) {
    for (final n in nodes) {
      if (n.node.okr.id == id) return n;
    }
    return null;
  }
}

/// Lays the forest out left to right: depth is the column, objectives that have nothing (visible)
/// under them take the next free row, and a parent sits level with the middle of what feeds it.
/// An objective in [collapsed] is drawn as a single card with everything under it folded away.
OkrTreeLayout layoutOkrTree(List<OkrNode> roots, {Set<String> collapsed = const {}, OkrTreeMetrics metrics = const OkrTreeMetrics()}) {
  final rowOf = <String, double>{};
  var nextRow = 0;

  bool isCollapsed(OkrNode n) => n.children.isNotEmpty && collapsed.contains(n.okr.id);

  double place(OkrNode n) {
    final shown = isCollapsed(n) ? const <OkrNode>[] : n.children;
    final double row;
    if (shown.isEmpty) {
      row = nextRow.toDouble();
      nextRow++;
    } else {
      final rows = [for (final c in shown) place(c)];
      row = (rows.first + rows.last) / 2;
    }
    rowOf[n.okr.id] = row;
    return row;
  }

  for (final r in roots) {
    place(r);
  }
  if (rowOf.isEmpty) return const OkrTreeLayout([], 0, 0);

  final nodes = <OkrPlaced>[];
  var maxDepth = 0;
  void emit(OkrNode n, String? parentId) {
    if (n.depth > maxDepth) maxDepth = n.depth;
    nodes.add(OkrPlaced(
      n,
      metrics.padding + n.depth * (metrics.nodeWidth + metrics.gapX),
      metrics.padding + rowOf[n.okr.id]! * (metrics.nodeHeight + metrics.gapY),
      parentId: parentId,
      collapsed: isCollapsed(n),
    ));
    if (isCollapsed(n)) return;
    for (final c in n.children) {
      emit(c, n.okr.id);
    }
  }

  for (final r in roots) {
    emit(r, null);
  }

  final rows = nextRow;
  return OkrTreeLayout(
    nodes,
    metrics.padding * 2 + (maxDepth + 1) * metrics.nodeWidth + maxDepth * metrics.gapX,
    metrics.padding * 2 + (rows == 0 ? 0 : rows * metrics.nodeHeight + (rows - 1) * metrics.gapY),
  );
}

/// The ids of every objective that has something under it (for "collapse all").
Set<String> okrIdsWithChildren(List<OkrNode> roots) {
  final out = <String>{};
  void walk(OkrNode n) {
    if (n.children.isNotEmpty) out.add(n.okr.id);
    n.children.forEach(walk);
  }

  roots.forEach(walk);
  return out;
}

/// One card in the narrow (phone) tree: the objective, how deep it sits, and whether it is folded.
class OkrListedNode {
  const OkrListedNode(this.node, this.collapsed);

  final OkrNode node;
  final bool collapsed;

  int get depth => node.depth;
  bool get hasChildren => node.children.isNotEmpty;
}

/// The same tree as a top-to-bottom list, depth first, skipping what is folded away.
List<OkrListedNode> listOkrNodes(List<OkrNode> roots, {Set<String> collapsed = const {}}) {
  final out = <OkrListedNode>[];
  void walk(OkrNode n) {
    final folded = n.children.isNotEmpty && collapsed.contains(n.okr.id);
    out.add(OkrListedNode(n, folded));
    if (!folded) n.children.forEach(walk);
  }

  roots.forEach(walk);
  return out;
}
