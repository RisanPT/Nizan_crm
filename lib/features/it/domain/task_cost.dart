// THE PLANNED COST OF TASKS — what the app knows about it (the rules are the server's: backend utils/taskCost.js).
//
//   • A task's planned cost is an amount, or hours × a rate. Only leaf tasks carry cost; a phase shows the total of its leaves.
//   • The tasks add up to "the plan by tasks", held against the project's budget. A save that would take it over (and adds to it) is
//     refused by the server with 409 TASK_COST_OVER_BUDGET — the editor then offers a budget increase for the finance head.
//   • Costs are money: they only reach people who may see a project's cost.

import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/rupees.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';

/// How a task's cost is stated.
abstract final class TaskCostMode {
  static const none = '';
  static const amount = 'amount';
  static const rate = 'rate';
}

/// One department's share of the plan.
class TaskPlanDepartment {
  const TaskPlanDepartment({
    required this.name,
    this.planned = 0,
    this.tasks = 0,
  });
  final String name;
  final double planned;
  final int tasks;

  factory TaskPlanDepartment.fromJson(Map<String, dynamic> j) =>
      TaskPlanDepartment(
        name: (j['name'] ?? '').toString(),
        planned: (j['planned'] as num?)?.toDouble() ?? 0,
        tasks: (j['tasks'] as num?)?.toInt() ?? 0,
      );
}

/// What a project's tasks add up to, against the budget (the server's `cost.taskPlan`).
class TaskPlan {
  const TaskPlan({
    this.planned = 0,
    this.ceiling = 0,
    this.level = 'none',
    this.over = 0,
    this.leaves = 0,
    this.priced = 0,
    this.unpriced = 0,
    this.byDepartment = const [],
    this.awaiting = false,
  });

  /// The leaf tasks' planned costs added up.
  final double planned;

  /// What the plan is held against: the approved budget — or what is asked for while an increase waits. 0 = nothing yet.
  final double ceiling;

  /// none (nothing to hold it against) | ok | warn (from 80%) | over
  final String level;

  /// How far above the ceiling (0 when not over).
  final double over;
  final int leaves;
  final int priced;

  /// Leaf tasks that have no cost yet.
  final int unpriced;
  final List<TaskPlanDepartment> byDepartment;

  /// An increase asked of the finance head is waiting: the ceiling is what is asked for until it is decided.
  final bool awaiting;

  factory TaskPlan.fromJson(Map<String, dynamic> j) => TaskPlan(
    planned: (j['planned'] as num?)?.toDouble() ?? 0,
    ceiling: (j['ceiling'] as num?)?.toDouble() ?? 0,
    level: (j['level'] ?? 'none').toString(),
    over: (j['over'] as num?)?.toDouble() ?? 0,
    leaves: (j['leaves'] as num?)?.toInt() ?? 0,
    priced: (j['priced'] as num?)?.toInt() ?? 0,
    unpriced: (j['unpriced'] as num?)?.toInt() ?? 0,
    byDepartment: [
      for (final d in (j['byDepartment'] as List?) ?? const [])
        if (d is Map) TaskPlanDepartment.fromJson(d.cast<String, dynamic>()),
    ],
    awaiting: j['awaiting'] == true,
  );

  /// How much of the ceiling the plan uses, 0..∞ (null when there is no ceiling).
  double? get usedFraction => ceiling > 0 ? planned / ceiling : null;

  /// Worth showing: there are tasks, or something is planned.
  bool get hasTasks => leaves > 0;
}

/// The server's refusal of a task save that would take the plan above the budget (409 TASK_COST_OVER_BUDGET).
class OverBudget {
  const OverBudget({
    required this.message,
    this.planned,
    this.ceiling,
    this.over,
    this.canRequest = false,
  });

  /// In plain words, ready to show. Carries no amounts for someone who may not see them.
  final String message;

  /// What the tasks would add up to / what they are held against / how far over — only for those who may see money.
  final double? planned;
  final double? ceiling;
  final double? over;

  /// This person may ask the finance head for a budget increase (the project manager, the owning department's head, an admin).
  final bool canRequest;

  bool get hasAmounts => planned != null;

  /// The refusal inside [error] (an [AppException] around a [DioException], or the [DioException] itself), or null when it is
  /// anything else.
  static OverBudget? tryParse(Object? error) {
    final cause = error is AppException ? error.cause : error;
    if (cause is! DioException || cause.response?.statusCode != 409) {
      return null;
    }
    final data = cause.response?.data;
    if (data is! Map || data['code'] != 'TASK_COST_OVER_BUDGET') return null;
    final plan = data['plan'];
    final p = plan is Map
        ? plan.cast<String, dynamic>()
        : const <String, dynamic>{};
    return OverBudget(
      message:
          (data['message'] ??
                  'This would take the project over its approved budget.')
              .toString(),
      planned: (p['planned'] as num?)?.toDouble(),
      ceiling: (p['ceiling'] as num?)?.toDouble(),
      over: (p['over'] as num?)?.toDouble(),
      canRequest: p['canRequest'] == true,
    );
  }
}

/// What came back from saving a task: whether a budget increase went to the finance head with it.
class TaskSaveResult {
  const TaskSaveResult({this.costRequestSent = false, this.costRequestAmount});
  final bool costRequestSent;
  final double? costRequestAmount;

  factory TaskSaveResult.fromResponse(Object? data) {
    final r = data is Map ? data['costRequest'] : null;
    if (r is! Map) return const TaskSaveResult();
    return TaskSaveResult(
      costRequestSent: r['sent'] == true,
      costRequestAmount: (r['amount'] as num?)?.toDouble(),
    );
  }
}

/// What the cost box(es) of the editor hold.
class TaskCostInput {
  const TaskCostInput({
    this.mode = TaskCostMode.none,
    this.amount = 0,
    this.rate = 0,
    this.invalid = false,
  });

  /// '' | 'amount' | 'rate'
  final String mode;
  final double amount;
  final double rate;

  /// Something was typed that is not an amount.
  final bool invalid;

  /// The request body's cost keys.
  Map<String, dynamic> toBody() => {
    'costMode': mode,
    'costAmount': mode == TaskCostMode.amount ? amount : 0,
    'costRate': mode == TaskCostMode.rate ? rate : 0,
  };

  /// The planned cost this works out to for [hours] (null when there is none).
  double? planned(double hours) => switch (mode) {
    TaskCostMode.amount => amount,
    TaskCostMode.rate => (rate * 100 * (hours < 0 ? 0 : hours)).round() / 100,
    _ => null,
  };
}

/// Hours × rate as typed: the cost it works out to, or null when either is missing or not a number.
double? hoursTimesRate(String hoursText, String rateText) {
  final rate = parseAmount(rateText);
  final hours = double.tryParse(hoursText.trim());
  if (rate == null || hours == null || hours < 0) return null;
  return (rate * 100 * hours).round() / 100;
}

/// Every task's cost as the plan counts it: a leaf is its own planned cost, a phase the total of the leaves under it.
/// The same rule as the server's (a task that has sub-tasks never counts its own).
Map<String, double> rolledTaskCosts(List<ITTaskModel> tasks) {
  final ids = {for (final t in tasks) t.id};
  final parents = {
    for (final t in tasks)
      if (t.parentTaskId != null && ids.contains(t.parentTaskId))
        t.parentTaskId!,
  };
  final parentOf = {for (final t in tasks) t.id: t.parentTaskId};
  final paise = <String, int>{};
  for (final t in tasks) {
    if (parents.contains(t.id)) continue;
    final cost = (t.plannedCost * 100).round();
    final seen = <String>{};
    for (
      String? at = t.id;
      at != null && !seen.contains(at);
      at = parentOf[at]
    ) {
      seen.add(at);
      paise[at] = (paise[at] ?? 0) + cost;
    }
  }
  return {for (final e in paise.entries) e.key: e.value / 100};
}

/// "20 h × ₹500" for an hours-based task, "" for the others.
String costBasisText(ITTaskModel t) {
  if (t.costMode != TaskCostMode.rate) return '';
  final h = t.estimatedHours;
  return '${h == h.roundToDouble() ? h.round() : h} h × ${rupees(t.costRate)}';
}

/// none (nothing to hold the plan against) | ok | warn (from 80%) | over — the same words and lines as the server's.
String planLevel(double planned, double ceiling) {
  final limit = (ceiling * 100).round();
  if (limit <= 0) return 'none';
  final used = (planned * 100).round();
  if (used > limit) return 'over';
  return used * 100 >= limit * 80 ? 'warn' : 'ok';
}

/// What a project's tasks add up to as the plan counts them (leaf tasks only): every task that is not the parent of another.
double plannedTotal(List<ITTaskModel> tasks) {
  final rolled = rolledTaskCosts(tasks);
  final ids = {for (final t in tasks) t.id};
  var paise = 0;
  for (final t in tasks) {
    final isRoot = t.parentTaskId == null || !ids.contains(t.parentTaskId);
    if (isRoot) paise += ((rolled[t.id] ?? 0) * 100).round();
  }
  return paise / 100;
}

/// What the plan wizard's NEW tasks add to a project's plan, against the budget.
class PlanCostSummary {
  const PlanCostSummary({
    this.newTotal = 0,
    this.existing = 0,
    this.ceiling = 0,
    this.priced = 0,
    this.unpriced = 0,
    this.awaiting = false,
  });

  /// The new tasks' planned costs added up (a task with sub-tasks never counts: its cost is theirs).
  final double newTotal;

  /// What the project's tasks already add up to.
  final double existing;

  /// What the plan is held against (0 = nothing approved or asked yet).
  final double ceiling;
  final int priced;
  final int unpriced;

  /// An increase is already waiting for the finance head (the ceiling is what is asked for).
  final bool awaiting;

  double get after => ((existing + newTotal) * 100).round() / 100;
  String get level => planLevel(after, ceiling);
  double get over =>
      level == 'over' ? ((after - ceiling) * 100).round() / 100 : 0;

  /// Making these tasks would take the plan above the budget: a budget increase has to be asked of the finance head first.
  bool get needsIncrease => ceiling > 0 && newTotal > 0 && level == 'over';
}

/// Adds up the wizard's tasks: only leaf tasks (no sub-tasks) count; [planned] is 0 for a task with no cost yet.
PlanCostSummary summarizePlanCost({
  required Iterable<({double planned, bool isGroup})> tasks,
  double existing = 0,
  double ceiling = 0,
  bool awaiting = false,
}) {
  var paise = 0;
  var priced = 0;
  var unpriced = 0;
  for (final t in tasks) {
    if (t.isGroup) continue;
    final p = (t.planned * 100).round();
    paise += p;
    if (p > 0) {
      priced++;
    } else {
      unpriced++;
    }
  }
  return PlanCostSummary(
    newTotal: paise / 100,
    existing: existing,
    ceiling: ceiling,
    priced: priced,
    unpriced: unpriced,
    awaiting: awaiting,
  );
}

/// One task behind a project's plan, as someone deciding on the budget sees it: what it is, where it hangs, and what it is planned to
/// cost (0 = no cost yet).
class TaskCostLine {
  const TaskCostLine({
    this.id = '',
    required this.title,
    this.department = '',
    this.phase = '',
    this.planned = 0,
  });
  final String id;
  final String title;
  final String department;

  /// The phase (the top of the chain) the task hangs under; '' for a task that is not under one.
  final String phase;
  final double planned;

  bool get hasCost => planned > 0;

  factory TaskCostLine.fromJson(Map<String, dynamic> j) => TaskCostLine(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    department: (j['department'] ?? '').toString(),
    phase: (j['phase'] ?? '').toString(),
    planned: (j['planned'] as num?)?.toDouble() ?? 0,
  );
}

/// The leaf tasks of [tasks] as lines (a task that has sub-tasks is its leaves' total, so it is no line of its own): those with a cost
/// first, the biggest first, then those with none in the order they were given. The server builds the same list for the finance head.
List<TaskCostLine> taskCostLinesOf(
  List<ITTaskModel> tasks, {
  String ownerDepartment = '',
}) {
  final byId = {for (final t in tasks) t.id: t};
  final parents = {
    for (final t in tasks)
      if (t.parentTaskId != null && byId.containsKey(t.parentTaskId))
        t.parentTaskId!,
  };
  String phaseOf(ITTaskModel t) {
    final seen = <String>{t.id};
    ITTaskModel? top;
    for (
      var at = byId[t.parentTaskId];
      at != null && !seen.contains(at.id);
      at = byId[at.parentTaskId]
    ) {
      seen.add(at.id);
      top = at;
    }
    return top?.title ?? '';
  }

  final lines = <(int, TaskCostLine)>[];
  var order = 0;
  for (final t in tasks) {
    if (parents.contains(t.id)) continue;
    lines.add((
      order++,
      TaskCostLine(
        id: t.id,
        title: t.title,
        department: t.departmentName.trim().isNotEmpty
            ? t.departmentName.trim()
            : ownerDepartment,
        phase: phaseOf(t),
        planned: t.plannedCost,
      ),
    ));
  }
  lines.sort((a, b) {
    final ac = a.$2.hasCost, bc = b.$2.hasCost;
    if (ac != bc) return ac ? -1 : 1;
    final byCost = b.$2.planned.compareTo(a.$2.planned);
    return byCost != 0 ? byCost : a.$1.compareTo(b.$1);
  });
  return [for (final l in lines) l.$2];
}
