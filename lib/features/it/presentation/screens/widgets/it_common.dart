import 'package:flutter/material.dart';

import 'package:nizan_crm/features/it/data/it_task.dart';

// ── WBS tree ──────────────────────────────────────────────────────────────────

/// A task placed in the WBS hierarchy, carrying its computed number ("1.2.1"),
/// depth (0 = top-level phase) and children.
class WbsNode {
  final ITTask task;
  final String wbs;
  final int depth;
  final List<WbsNode> children;
  const WbsNode(this.task, this.wbs, this.depth, this.children);

  bool get isGroup => children.isNotEmpty;
}

/// Builds the WBS forest from a flat task list using [ITTask.parentTaskId].
/// Siblings are ordered by [ITTask.order] then title; numbers are assigned by a
/// depth-first walk (1, 1.1, 1.1.1, 1.2, 2 …). Orphans (parent missing) and any
/// tasks caught in a cycle are surfaced as extra top-level rows so nothing is
/// silently dropped.
List<WbsNode> buildWbsForest(List<ITTask> tasks) {
  final byParent = <String, List<ITTask>>{};
  final ids = {for (final t in tasks) t.id};
  for (final t in tasks) {
    final key = (t.parentTaskId != null && ids.contains(t.parentTaskId)) ? t.parentTaskId! : '';
    (byParent[key] ??= []).add(t);
  }
  for (final list in byParent.values) {
    list.sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.title.compareTo(b.title));
  }

  final visited = <String>{};
  List<WbsNode> build(String parentKey, String prefix) {
    final kids = byParent[parentKey] ?? const <ITTask>[];
    final out = <WbsNode>[];
    var i = 0;
    for (final t in kids) {
      if (!visited.add(t.id)) continue; // guard against cycles
      i++;
      final wbs = prefix.isEmpty ? '$i' : '$prefix.$i';
      out.add(WbsNode(t, wbs, prefix.split('.').where((e) => e.isNotEmpty).length, build(t.id, wbs)));
    }
    return out;
  }

  final roots = build('', '');
  // Any task never reached (part of a cycle) becomes its own root, so the UI
  // still shows it and the user can fix it.
  final stranded = tasks.where((t) => !visited.contains(t.id)).toList();
  var n = roots.length;
  for (final t in stranded) {
    n++;
    roots.add(WbsNode(t, '$n', 0, const []));
  }
  return roots;
}

/// Flattens the forest depth-first (pre-order) — the WBS table row order.
List<WbsNode> flattenWbs(List<WbsNode> forest) {
  final out = <WbsNode>[];
  void walk(WbsNode n) {
    out.add(n);
    for (final c in n.children) {
      walk(c);
    }
  }

  for (final r in forest) {
    walk(r);
  }
  return out;
}

/// Rolled-up completion for a node: leaves use their own [ITTask.percentComplete];
/// groups average across all their leaf descendants (equal weight).
int rolledUpPercent(WbsNode node) {
  if (node.children.isEmpty) return node.task.percentComplete.clamp(0, 100);
  final leaves = <int>[];
  void collect(WbsNode n) {
    if (n.children.isEmpty) {
      leaves.add(n.task.percentComplete.clamp(0, 100));
    } else {
      for (final c in n.children) {
        collect(c);
      }
    }
  }

  collect(node);
  if (leaves.isEmpty) return 0;
  return (leaves.reduce((a, b) => a + b) / leaves.length).round();
}

/// The earliest start / latest end across a node's subtree (self + descendants),
/// used to draw a phase's summary bar. Falls back to createdAt for a start.
({DateTime? start, DateTime? end}) subtreeSpan(WbsNode node) {
  DateTime? start, end;
  void visit(WbsNode n) {
    final s = n.task.startDate ?? n.task.createdAt;
    final e = n.task.deadline;
    if (s != null && (start == null || s.isBefore(start!))) start = s;
    if (e != null && (end == null || e.isAfter(end!))) end = e;
    for (final c in n.children) {
      visit(c);
    }
  }

  visit(node);
  return (start: start, end: end);
}

// ── Colors & small UI helpers ─────────────────────────────────────────────────

Color itTaskStatusColor(String s) => switch (s) {
      'in-progress' => Colors.blue.shade600,
      'review' => Colors.amber.shade700,
      'completed' => const Color(0xFF2E8B57),
      _ => Colors.blueGrey,
    };

Color itCategoryColor(String c) => switch (c) {
      'bug' => Colors.red.shade600,
      'maintenance' => Colors.amber.shade700,
      'research' => Colors.purple,
      _ => Colors.blue.shade600, // feature
    };

/// Distinct color per phase index (cycles), for the Gantt bars / WBS accents.
const List<Color> kPhasePalette = [
  Color(0xFF1D4E89), // blue
  Color(0xFF3E7C8B), // teal
  Color(0xFFC1622D), // orange
  Color(0xFF3E7A3E), // green
  Color(0xFF5B3E8B), // purple
  Color(0xFF8B3E5B), // magenta
  Color(0xFF8B7A1D), // gold
];
Color phaseColor(int index) => kPhasePalette[index % kPhasePalette.length];

/// Discrete green scale for the "% complete" cell (matches the calendar heatmap
/// approach): consistent color = consistent progress across the table.
Color percentFill(int pct) {
  if (pct <= 0) return const Color(0xFFF1F1F1);
  if (pct < 25) return const Color(0xFFDCF3DD);
  if (pct < 50) return const Color(0xFFB6E3BC);
  if (pct < 75) return const Color(0xFF7FCB8C);
  if (pct < 100) return const Color(0xFF43A75F);
  return const Color(0xFF1F7A44);
}

Color percentText(int pct) => pct >= 50 ? Colors.white : const Color(0xFF1B4332);

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');

String shortDate(DateTime? d) => d == null ? '—' : '${d.day}/${d.month}/${d.year % 100}';

/// Calendar-day span between start and due (matches the template's counting).
int? durationDays(ITTask t) {
  if (t.startDate == null || t.deadline == null) return null;
  return t.deadline!.difference(t.startDate!).inDays;
}

Widget itTag(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
