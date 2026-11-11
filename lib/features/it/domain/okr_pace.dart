import 'package:nizan_crm/features/it/domain/models/okr_model.dart';

// How the OKR timeline judges an objective, orders them, and sizes its time window. Pure (no
// widgets, `now` is passed in) so the rules are tested rather than read off a screenshot.

/// An objective's standing against the clock.
enum OkrHealth {
  done,
  onTrack,
  atRisk,
  offTrack,
  blocked,
  notStarted,

  /// No start / deadline to judge against.
  unscheduled;

  String get label => switch (this) {
        OkrHealth.done => 'Done',
        OkrHealth.onTrack => 'On track',
        OkrHealth.atRisk => 'At risk',
        OkrHealth.offTrack => 'Off track',
        OkrHealth.blocked => 'Blocked',
        OkrHealth.notStarted => 'Not started',
        OkrHealth.unscheduled => 'No dates',
      };

  /// Needs somebody's attention (the "Needs attention" filter).
  bool get needsAttention => this == atRisk || this == offTrack || this == blocked;
}

/// Points behind where the calendar says it should be before an objective is "at risk" …
const okrAtRiskGap = 10;

/// … and before it is "off track".
const okrOffTrackGap = 25;

/// A key result nobody has reported on for this long (on an objective that has been running
/// at least this long) is flagged as stale.
const okrStaleAfterDays = 21;

/// Where an objective stands on [now].
class OkrPace {
  const OkrPace({required this.health, required this.progress, this.expected, this.gap, this.overdueDays = 0});

  final OkrHealth health;

  /// Its progress, 0..100.
  final int progress;

  /// Where a straight line from start to deadline says it should be today, 0..1. Null when it has no dates.
  final double? expected;

  /// Points behind (+) or ahead (−) of [expected]. Null when it has no dates.
  final int? gap;

  /// Whole days past the deadline while unfinished (0 otherwise).
  final int overdueDays;

  /// [expected] as a percentage, or null.
  int? get expectedPercent => expected == null ? null : (expected! * 100).round();
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The days an objective runs over, and whether they were really set. Without dates it is drawn
/// from when it was created for 30 days (so it still has a place on the timeline) and [dated] is false.
({DateTime start, DateTime end, bool dated}) okrSpan(OKRModel o, {DateTime? now}) {
  final dated = o.startDate != null && o.deadline != null;
  final start = _day(o.startDate ?? o.createdAt ?? (o.deadline?.subtract(const Duration(days: 30)) ?? now ?? DateTime.now()));
  var end = _day(o.deadline ?? start.add(const Duration(days: 30)));
  if (end.isBefore(start)) end = start;
  return (start: start, end: end, dated: dated);
}

/// Judges [o] on [now].
OkrPace okrPace(OKRModel o, DateTime now) {
  final progress = o.progress.clamp(0, 100);
  if (o.status == OKRStatus.completed || progress >= 100) return OkrPace(health: OkrHealth.done, progress: progress);
  if (o.status == OKRStatus.blocked) return OkrPace(health: OkrHealth.blocked, progress: progress);

  if (o.startDate == null || o.deadline == null) {
    return OkrPace(health: o.status == OKRStatus.notStarted ? OkrHealth.notStarted : OkrHealth.unscheduled, progress: progress);
  }

  final start = _day(o.startDate!);
  final endExclusive = _day(o.deadline!).add(const Duration(days: 1)); // the deadline day counts in full
  if (now.isBefore(start)) {
    return OkrPace(health: progress > 0 ? OkrHealth.onTrack : OkrHealth.notStarted, progress: progress, expected: 0, gap: -progress);
  }
  if (!now.isBefore(endExclusive)) {
    return OkrPace(
      health: OkrHealth.offTrack,
      progress: progress,
      expected: 1,
      gap: 100 - progress,
      overdueDays: _day(now).difference(_day(o.deadline!)).inDays,
    );
  }

  final total = endExclusive.difference(start).inMinutes;
  final expected = (now.difference(start).inMinutes / total).clamp(0.0, 1.0);
  final gap = (expected * 100).round() - progress;
  final health = gap > okrOffTrackGap
      ? OkrHealth.offTrack
      : gap > okrAtRiskGap
          ? OkrHealth.atRisk
          : OkrHealth.onTrack;
  return OkrPace(health: health, progress: progress, expected: expected, gap: gap);
}

/// "12 pts behind", "on pace", "8 pts ahead", "overdue by 5 days" — the short sentence next to a bar.
String okrPaceNote(OkrPace p) {
  if (p.overdueDays > 0) return 'overdue by ${p.overdueDays} day${p.overdueDays == 1 ? '' : 's'}';
  final gap = p.gap;
  if (gap == null || p.health == OkrHealth.done || p.health == OkrHealth.blocked) return '';
  if (p.health == OkrHealth.notStarted) return 'starts later';
  if (gap > 2) return '$gap pts behind';
  if (gap < -2) return '${-gap} pts ahead';
  return 'on pace';
}

/// Whether nobody has reported on [kr] for a while. Only for an objective that is running
/// (in progress, started at least [okrStaleAfterDays] ago); a key result with no log counts only
/// if it still stands at zero (a legacy one with a value is not blamed for having no history).
bool krIsStale(OKRModel o, KeyResultItem kr, DateTime now) {
  if (kr.completed || o.status != OKRStatus.inProgress) return false;
  final started = okrSpan(o, now: now).start;
  if (now.difference(started).inDays < okrStaleAfterDays) return false;
  final last = kr.lastCheckInAt;
  return last == null ? kr.currentValue == 0 : now.difference(last).inDays > okrStaleAfterDays;
}

/// Where an objective sits in the company → department → project alignment, for ordering.
int okrLevelOrder(String level) => switch (level) {
      'company' => 0,
      'department' => 1,
      _ => 2,
    };

int okrLevelRank(OKRModel o) => okrLevelOrder(o.effectiveLevel);

/// One objective with the objectives that contribute to it (`parentObjectiveId`).
class OkrNode {
  OkrNode(this.okr, this.depth);

  final OKRModel okr;
  final int depth;
  final List<OkrNode> children = [];
}

/// The alignment forest of [okrs]: an objective whose parent is in the list goes under it, anything
/// else (no parent, or a parent that is not in the list — another project's, one filtered out) is a
/// root. Siblings run by `order`, then start date, then title; roots by level first. A loop in bad
/// data cannot hang it: whatever is caught in one becomes a root.
List<OkrNode> buildOkrTree(List<OKRModel> okrs) {
  final ids = {for (final o in okrs) o.id};
  final byParent = <String, List<OKRModel>>{};
  for (final o in okrs) {
    final p = o.parentObjectiveId;
    (byParent[p != null && p != o.id && ids.contains(p) ? p : ''] ??= []).add(o);
  }

  int bySibling(OKRModel a, OKRModel b) {
    if (a.order != b.order) return a.order.compareTo(b.order);
    final sa = a.startDate ?? a.createdAt;
    final sb = b.startDate ?? b.createdAt;
    if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
    if ((sa == null) != (sb == null)) return sa == null ? 1 : -1;
    return a.objective.toLowerCase().compareTo(b.objective.toLowerCase());
  }

  for (final list in byParent.values) {
    list.sort(bySibling);
  }
  byParent['']?.sort((a, b) {
    final r = okrLevelRank(a).compareTo(okrLevelRank(b));
    return r != 0 ? r : bySibling(a, b);
  });

  final seen = <String>{};
  List<OkrNode> grow(String parentKey, int depth) {
    final out = <OkrNode>[];
    for (final o in byParent[parentKey] ?? const <OKRModel>[]) {
      if (!seen.add(o.id)) continue;
      final node = OkrNode(o, depth);
      node.children.addAll(grow(o.id, depth + 1));
      out.add(node);
    }
    return out;
  }

  final roots = grow('', 0);
  // anything never reached is part of a loop: show it rather than lose it
  for (final o in okrs) {
    if (seen.contains(o.id)) continue;
    seen.add(o.id);
    final node = OkrNode(o, 0);
    node.children.addAll(grow(o.id, 1));
    roots.add(node);
  }
  return roots;
}

/// A line on the timeline: a project group header, an objective, or one of its key results.
sealed class OkrRow {
  const OkrRow(this.depth);
  final int depth;
}

/// A project header row on the timeline when grouped by Project.
class OkrProjectRow extends OkrRow {
  const OkrProjectRow({
    required this.key,
    this.projectId,
    required this.projectName,
    required this.department,
    required this.projectHeadName,
    required this.okrs,
    required this.progress,
    this.earliestStart,
    this.latestEnd,
    required this.collapsed,
    int depth = 0,
  }) : super(depth);

  final String key;
  final String? projectId;
  final String projectName;
  final String department;
  final String projectHeadName;
  final List<OKRModel> okrs;
  final int progress;
  final DateTime? earliestStart;
  final DateTime? latestEnd;
  final bool collapsed;

  bool get isCompany => key == '__company__';
}

class OkrObjectiveRow extends OkrRow {
  const OkrObjectiveRow(this.okr, super.depth, {required this.hasChildren, required this.collapsed});
  final OKRModel okr;
  final bool hasChildren;
  final bool collapsed;

  bool get expandable => hasChildren || okr.keyResults.isNotEmpty;
}

class OkrKeyResultRow extends OkrRow {
  const OkrKeyResultRow(this.okr, super.depth, this.kr);
  final OKRModel okr;
  final KeyResultItem kr;
}

/// The lines to draw, top to bottom: each objective, then its key results, then the objectives that
/// contribute to it. An objective in [collapsed] hides its key results and everything under it.
List<OkrRow> okrRows(List<OkrNode> roots, {Set<String> collapsed = const {}}) {
  final rows = <OkrRow>[];
  void walk(OkrNode n) {
    final isCollapsed = collapsed.contains(n.okr.id);
    rows.add(OkrObjectiveRow(n.okr, n.depth, hasChildren: n.children.isNotEmpty, collapsed: isCollapsed));
    if (isCollapsed) return;
    for (final kr in n.okr.keyResults) {
      rows.add(OkrKeyResultRow(n.okr, n.depth, kr));
    }
    n.children.forEach(walk);
  }

  roots.forEach(walk);
  return rows;
}

/// Lines to draw grouped by Project as the MAIN level, and underneath each project,
/// its objectives and key results.
List<OkrRow> okrProjectRows(
  List<OKRModel> okrs, {
  Set<String> collapsedProjects = const {},
  Set<String> collapsedObjectives = const {},
}) {
  if (okrs.isEmpty) return const [];

  final groupMap = <String, ({
    String key,
    String? projectId,
    String projectName,
    String department,
    String projectHeadName,
    List<OKRModel> items,
  })>{};

  for (final o in okrs) {
    final String key;
    final String name;
    final String dept = o.projectDepartment.isNotEmpty ? o.projectDepartment : o.department;
    final String head = o.projectHeadName;

    if (o.projectName.trim().isNotEmpty) {
      key = o.projectId != null && o.projectId!.isNotEmpty ? o.projectId! : 'name:${o.projectName.trim().toLowerCase()}';
      name = o.projectName.trim();
    } else if (o.projectId != null && o.projectId!.isNotEmpty) {
      key = o.projectId!;
      name = 'Project';
    } else {
      key = '__company__';
      name = o.effectiveLevel == 'department' ? '${o.department.toUpperCase()} Department' : 'Company Initiatives';
    }

    final entry = groupMap[key];
    if (entry != null) {
      entry.items.add(o);
    } else {
      groupMap[key] = (
        key: key,
        projectId: o.projectId,
        projectName: name,
        department: dept,
        projectHeadName: head,
        items: [o],
      );
    }
  }

  // Company group first, then alphabetically by project name
  final sortedGroups = groupMap.values.toList()
    ..sort((a, b) {
      if (a.key == '__company__') return -1;
      if (b.key == '__company__') return 1;
      return a.projectName.toLowerCase().compareTo(b.projectName.toLowerCase());
    });

  final rows = <OkrRow>[];

  for (final g in sortedGroups) {
    final isProjectCollapsed = collapsedProjects.contains(g.key);

    DateTime? earliest;
    DateTime? latest;
    for (final o in g.items) {
      final s = o.startDate ?? o.createdAt;
      final e = o.deadline ?? o.startDate ?? o.createdAt;
      if (s != null && (earliest == null || s.isBefore(earliest))) earliest = s;
      if (e != null && (latest == null || e.isAfter(latest))) latest = e;
    }

    final avgProgress = g.items.isEmpty
        ? 0
        : (g.items.map((o) => o.progress).reduce((a, b) => a + b) / g.items.length).round();

    rows.add(OkrProjectRow(
      key: g.key,
      projectId: g.projectId,
      projectName: g.projectName,
      department: g.department,
      projectHeadName: g.projectHeadName,
      okrs: g.items,
      progress: avgProgress,
      earliestStart: earliest,
      latestEnd: latest,
      collapsed: isProjectCollapsed,
      depth: 0,
    ));

    if (isProjectCollapsed) continue;

    final tree = buildOkrTree(g.items);
    void walkObjective(OkrNode n) {
      final isObjCollapsed = collapsedObjectives.contains(n.okr.id);
      rows.add(OkrObjectiveRow(n.okr, 1 + n.depth, hasChildren: n.children.isNotEmpty, collapsed: isObjCollapsed));
      if (!isObjCollapsed) {
        for (final kr in n.okr.keyResults) {
          rows.add(OkrKeyResultRow(n.okr, 1 + n.depth, kr));
        }
        n.children.forEach(walkObjective);
      }
    }

    tree.forEach(walkObjective);
  }

  return rows;
}

/// The window the timeline shows: at least a month back and four ahead of [now], stretched to
/// cover every objective's dates, and aligned to whole months.
({DateTime start, DateTime end}) okrTimelineBounds(List<OKRModel> okrs, DateTime now) {
  var lo = DateTime(now.year, now.month - 1, 1);
  var hi = DateTime(now.year, now.month + 5, 0); // the end of the 4th month after this one
  for (final o in okrs) {
    final s = okrSpan(o, now: now);
    if (s.start.isBefore(lo)) lo = s.start;
    if (s.end.isAfter(hi)) hi = s.end;
  }
  return (start: DateTime(lo.year, lo.month, 1), end: DateTime(hi.year, hi.month + 1, 0));
}

/// How many objectives are in each state on [now] (for the summary chips).
Map<OkrHealth, int> okrHealthCounts(Iterable<OKRModel> okrs, DateTime now) {
  final out = <OkrHealth, int>{};
  for (final o in okrs) {
    final h = okrPace(o, now).health;
    out[h] = (out[h] ?? 0) + 1;
  }
  return out;
}

/// A number as people write it: `40` not `40.0`, `12.5` not `12.50`.
String okrNumber(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}
