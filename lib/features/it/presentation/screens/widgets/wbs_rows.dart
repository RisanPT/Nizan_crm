import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';

// What the WBS tab shows: the numbers in the strip above the table, which rows are listed (Tree: phases with their
// tasks under them, folded or open; Table: one flat list) once the search box and the filter are applied, and the rows
// of an export. No widgets in here — test/wbs_rows_test.dart.

/// Owner choice in the filter for "nobody is assigned".
const kWbsUnassigned = '__unassigned__';

/// What the Filter button narrows the table to. Empty = everything.
class WbsFilter {
  const WbsFilter({this.statuses = const {}, this.owner = ''});

  /// Only these statuses (none chosen = all).
  final Set<ITTaskStatus> statuses;

  /// '' = anyone, [kWbsUnassigned] = nobody, otherwise an employee id.
  final String owner;

  bool get isActive => statuses.isNotEmpty || owner.isNotEmpty;

  /// How many things are narrowed (for the badge on the Filter button).
  int get count => (statuses.isNotEmpty ? 1 : 0) + (owner.isNotEmpty ? 1 : 0);

  WbsFilter copyWith({Set<ITTaskStatus>? statuses, String? owner}) => WbsFilter(statuses: statuses ?? this.statuses, owner: owner ?? this.owner);
}

/// The strip above the table.
class WbsSummary {
  const WbsSummary({required this.phases, required this.tasks, required this.total, required this.completed, required this.overall});

  /// Top-level items.
  final int phases;

  /// Everything under a phase, at any depth.
  final int tasks;
  final int total;
  final int completed;

  /// Average of the leaf tasks' % (a phase is only as done as the work under it).
  final int overall;

  int get remaining => total - completed;
}

WbsSummary wbsSummary(List<ITTask> tasks, List<WbsNode> forest) {
  final leaves = tasks.where((t) => !tasks.any((o) => o.parentTaskId == t.id)).toList();
  final overall = leaves.isEmpty
      ? 0
      : (leaves
              .map((t) => (t.isCompleted || t.percentComplete >= 100)
                  ? 100
                  : t.percentComplete.clamp(0, 100))
              .reduce((a, b) => a + b) /
          leaves.length)
          .round();
  return WbsSummary(
    phases: forest.length,
    tasks: tasks.length - forest.length,
    total: tasks.length,
    completed: tasks.where((t) => t.isCompleted).length,
    overall: overall,
  );
}

/// Does [node] pass the search words and the filter? The words are looked for in the title, the owner's name and the
/// WBS number ("2.1").
bool wbsMatches(WbsNode node, {String query = '', WbsFilter filter = const WbsFilter()}) {
  final t = node.task;
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty && !(t.title.toLowerCase().contains(q) || t.assigneeName.toLowerCase().contains(q) || node.wbs.toLowerCase().contains(q))) {
    return false;
  }
  if (filter.statuses.isNotEmpty && !filter.statuses.contains(t.status)) return false;
  if (filter.owner.isNotEmpty) {
    if (filter.owner == kWbsUnassigned) {
      if (t.assigneeId.isNotEmpty) return false;
    } else if (t.assigneeId != filter.owner) {
      return false;
    }
  }
  return true;
}

/// One listed row.
class WbsRow {
  const WbsRow({required this.node, required this.phase, required this.isLast, required this.hasChildren, required this.open});

  final WbsNode node;

  /// Position of the top-level phase this row belongs to (picks its colour).
  final int phase;

  /// Last of its siblings in the list (where the tree line turns instead of running on).
  final bool isLast;

  /// Tree view: it has tasks under it (so it can be folded).
  final bool hasChildren;

  /// Tree view: those tasks are listed under it.
  final bool open;
}

class _Shown {
  _Shown(this.node, this.phase, this.children);
  final WbsNode node;
  final int phase;
  final List<_Shown> children;
}

/// The rows to list.
///
/// Tree: every phase with its tasks, except those under a phase in [collapsed]. With a search or a filter, only what
/// matches is listed — plus the phases above it, held open so the match can be seen. Table: just the matching items,
/// flat, in work-breakdown order.
List<WbsRow> wbsRows(
  List<WbsNode> forest, {
  required bool tree,
  Set<String> collapsed = const {},
  String query = '',
  WbsFilter filter = const WbsFilter(),
}) {
  final filtering = query.trim().isNotEmpty || filter.isActive;
  final out = <WbsRow>[];

  if (!tree) {
    for (final n in flattenWbs(forest)) {
      if (wbsMatches(n, query: query, filter: filter)) {
        out.add(WbsRow(node: n, phase: _phaseOf(forest, n), isLast: false, hasChildren: false, open: false));
      }
    }
    return out;
  }

  List<_Shown> prune(List<WbsNode> nodes, int? phase) {
    final shown = <_Shown>[];
    for (var i = 0; i < nodes.length; i++) {
      final ph = phase ?? i;
      final kids = prune(nodes[i].children, ph);
      if (kids.isNotEmpty || wbsMatches(nodes[i], query: query, filter: filter)) shown.add(_Shown(nodes[i], ph, kids));
    }
    return shown;
  }

  void flat(List<_Shown> list) {
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      final hasChildren = s.node.isGroup;
      final open = hasChildren && (filtering ? s.children.isNotEmpty : !collapsed.contains(s.node.task.id));
      out.add(WbsRow(node: s.node, phase: s.phase, isLast: i == list.length - 1, hasChildren: hasChildren, open: open));
      if (open) flat(s.children);
    }
  }

  flat(prune(forest, null));
  return out;
}

int _phaseOf(List<WbsNode> forest, WbsNode node) {
  final top = int.tryParse(node.wbs.split('.').first) ?? 1;
  return (top - 1).clamp(0, forest.isEmpty ? 0 : forest.length - 1);
}

String durationText(ITTask t) {
  final d = durationDays(t);
  if (d == null) return '—';
  return d == 1 ? '1 day' : '$d days';
}

const wbsExportHeaders = ['#', 'Task / Phase', 'Owner', 'Start Date', 'Due Date', 'Duration (days)', 'Progress %', 'Status'];

/// What an export lists: everything that matches the search and the filter, with its phase, whatever is folded on screen.
List<List<dynamic>> wbsExportRows(List<WbsNode> forest, {String query = '', WbsFilter filter = const WbsFilter(), bool isIt = false}) {
  return [
    for (final r in wbsRows(forest, tree: true, query: query, filter: filter))
      [
        r.node.wbs,
        r.node.task.title,
        r.node.task.assigneeName,
        shortDate(r.node.task.startDate),
        shortDate(r.node.task.deadline),
        durationDays(r.node.task) ?? '',
        rolledUpPercent(r.node),
        r.node.task.status.labelFor(isIt: isIt),
      ],
  ];
}
