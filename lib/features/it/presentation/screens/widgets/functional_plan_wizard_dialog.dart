import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/error_message.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/rupees.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/features/it/domain/plan_drafts.dart';
import 'package:nizan_crm/features/it/domain/task_cost.dart';
import 'package:nizan_crm/features/it/domain/models/it_project_model.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/plan_wizard_table_widgets.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_spend_widgets.dart' show spendLevelColor;
import 'package:nizan_crm/features/it/presentation/screens/widgets/task_cost_widgets.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

/// Helper model for draft phases in the functional plan wizard
class PlanPhaseDraft {
  final String id;
  String name;
  Color color;

  PlanPhaseDraft({required this.id, required this.name, this.color = const Color(0xFF6366F1)});
}

/// Helper model for draft tasks in the functional plan wizard
class PlanTaskDraft {
  final String id;
  String phaseId;
  String title;
  int durationDays;
  ITSeverity severity;
  String? assigneeId;
  String? assigneeName;
  bool isMilestone;
  List<String> predecessorIds;

  /// The task this is a sub-task of (null for a task straight under its phase).
  String? parentId;

  /// A start day the planner fixed (date only); null = the plan places it. A fixed start is "not before": what the task
  /// waits for can still push it later, and the row says so.
  DateTime? startDate;

  /// A fixed end day (date only) — only ever with a fixed [startDate]. The length is then the days between the two, and
  /// the same day as the start makes a short job that ends where it starts.
  DateTime? endDate;

  /// The clock time the work starts and ends, on the start and end day. Optional; a milestone only has the first.
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  /// What the task is planned to cost — only set by someone who may set a project's costs. '' = none, 'amount' = [costAmount] typed in
  /// rupees, 'rate' = [hours] × [costRate] (rupees per hour). A task that has sub-tasks has none of its own: its cost is theirs.
  String costMode;
  double costAmount;
  double costRate;
  double hours;

  /// The planned cost this works out to (0 for none), to the paisa.
  double get plannedCost => costMode == 'amount' ? costAmount : (costMode == 'rate' ? (costRate * 100 * hours).round() / 100 : 0);

  /// Bumped when picking dates changes the length, so the Dur box shows the new number (it does not while being typed in).
  int rev = 0;

  bool get isSameDay => startDate != null && endDate != null && startDate == endDate;

  PlanTaskDraft({
    required this.id,
    required this.phaseId,
    this.parentId,
    required this.title,
    this.durationDays = 3,
    this.severity = ITSeverity.p2,
    this.assigneeId,
    this.assigneeName,
    this.isMilestone = false,
    List<String>? predecessorIds,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.costMode = '',
    this.costAmount = 0,
    this.costRate = 0,
    this.hours = 0,
  }) : predecessorIds = predecessorIds ?? [];

  PlanTaskDraft copyWith({
    String? title,
    int? durationDays,
    ITSeverity? severity,
    String? assigneeId,
    String? assigneeName,
    bool? isMilestone,
    List<String>? predecessorIds,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? costMode,
    double? costAmount,
    double? costRate,
    double? hours,
  }) {
    return PlanTaskDraft(
      id: id,
      phaseId: phaseId,
      parentId: parentId,
      title: title ?? this.title,
      durationDays: durationDays ?? this.durationDays,
      severity: severity ?? this.severity,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      isMilestone: isMilestone ?? this.isMilestone,
      predecessorIds: predecessorIds ?? List.from(this.predecessorIds),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      costMode: costMode ?? this.costMode,
      costAmount: costAmount ?? this.costAmount,
      costRate: costRate ?? this.costRate,
      hours: hours ?? this.hours,
    );
  }
}

/// When a task starts and ends, as the schedule has it.
typedef _Span = ({DateTime start, DateTime end});

/// A task's start and end as the plan saves them: the day it was scheduled on, with the clock time the planner gave it.
class _Stamp {
  const _Stamp(this.start, this.end, {this.startTimed = false, this.endTimed = false});
  final DateTime start;
  final DateTime end;
  final bool startTimed;
  final bool endTimed;
}

/// Displays the Functional Plan & Gantt Auto-Scheduler Wizard
Future<void> showFunctionalPlanWizard({
  required BuildContext context,
  required WidgetRef ref,
  required String projectId,
  required String projectName,
  required List<ITTaskModel> existingTasks,
  ITProjectModel? project,
  VoidCallback? onPlanCreated,
  String? initialDepartment,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => FunctionalPlanWizardDialog(
      projectId: projectId,
      projectName: projectName,
      existingTasks: existingTasks,
      project: project,
      onPlanCreated: onPlanCreated,
      initialDepartment: initialDepartment,
    ),
  );
}

class FunctionalPlanWizardDialog extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;
  final List<ITTaskModel> existingTasks;
  final ITProjectModel? project;
  final VoidCallback? onPlanCreated;

  /// The department to plan for, when asked from its own lane on the Timeline.
  final String? initialDepartment;

  /// A plan to start from instead of an empty one (the wizard never pre-fills one itself).
  @visibleForTesting
  final ({List<PlanPhaseDraft> phases, List<PlanTaskDraft> tasks})? seed;

  const FunctionalPlanWizardDialog({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.existingTasks,
    this.project,
    this.onPlanCreated,
    this.initialDepartment,
    this.seed,
  });

  @override
  ConsumerState<FunctionalPlanWizardDialog> createState() => _FunctionalPlanWizardDialogState();
}

class _FunctionalPlanWizardDialogState extends ConsumerState<FunctionalPlanWizardDialog> {
  int _currentStep = 0;
  bool _busy = false;

  // Step 1: Function Scope
  late final TextEditingController _leadController;
  late final TextEditingController _objectiveController;
  late List<String> _departments;
  late String _departmentName;
  DateTime _windowStartDate = DateTime.now();

  // Step 2: Phases
  final List<PlanPhaseDraft> _phases = [];

  // Step 3 & 4: Tasks
  final List<PlanTaskDraft> _tasks = [];

  // Step 3's table: the rows ticked, the tasks folded shut, and the sideways scroll of a narrow window
  final Set<String> _selected = {};
  final Set<String> _collapsed = {};
  final ScrollController _tableScroll = ScrollController();

  int _nextIdCounter = 1;
  String _generateId(String prefix) => '${prefix}_${_nextIdCounter++}';

  @override
  void initState() {
    super.initState();
    _leadController = TextEditingController();
    _objectiveController = TextEditingController();

    // Resolve departments from the project
    final allProjs = ref.read(projectsProvider).value ?? const [];
    final project = widget.project ?? ref.read(projectByIdProvider(widget.projectId)) ?? allProjs.where((p) => p.id == widget.projectId).firstOrNull;

    final targetDept = project?.targetDepartment.trim() ?? '';
    final deptNames = project?.departmentNames ?? [];
    final deptSet = <String>{};
    if (targetDept.isNotEmpty) deptSet.add(targetDept);
    deptSet.addAll(deptNames);

    if (deptSet.isNotEmpty) {
      _departments = deptSet.toList();
      _departmentName = targetDept.isNotEmpty ? targetDept : _departments.first;
    } else {
      _departments = ['IT', 'Operations', 'Marketing', 'Accounts', 'Fleet', 'Human Resources', 'Sales'];
      _departmentName = _departments.first;
    }

    final wanted = (widget.initialDepartment ?? '').trim().toLowerCase();
    if (wanted.isNotEmpty) {
      final match = _departments.where((d) => d.toLowerCase() == wanted).firstOrNull;
      if (match != null) _departmentName = match;
    }

    // Nothing is pre-filled: the phases and tasks are the ones you add.
    final seed = widget.seed;
    if (seed != null) {
      _phases.addAll(seed.phases);
      _tasks.addAll(seed.tasks);
    }
  }

  // What the project already holds — new phases go after it and nothing there is touched.
  bool get _hasExistingPlan => widget.existingTasks.isNotEmpty;
  int get _existingPhases => widget.existingTasks.where((t) => (t.parentTaskId ?? '').isEmpty).length;

  static const _phaseColors = [Color(0xFF6366F1), Color(0xFF0EA5E9), Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFFEC4899), Color(0xFF8B5CF6)];

  void _movePhase(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _phases.length) return;
    setState(() => _phases.insert(j, _phases.removeAt(i)));
  }

  /// Swaps [t] with its neighbour among the tasks under the same phase (or the same task, for a sub-task).
  void _moveTask(PlanTaskDraft t, int delta) {
    final sibs = _tasks.where((x) => x.parentId == t.parentId && (t.parentId != null || x.phaseId == t.phaseId)).toList();
    final i = sibs.indexOf(t);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= sibs.length) return;
    final a = _tasks.indexOf(t);
    final b = _tasks.indexOf(sibs[j]);
    setState(() {
      _tasks[a] = sibs[j];
      _tasks[b] = t;
    });
  }

  bool _canMoveTask(PlanTaskDraft t, int delta) {
    final sibs = _tasks.where((x) => x.parentId == t.parentId && (t.parentId != null || x.phaseId == t.phaseId)).toList();
    final j = sibs.indexOf(t) + delta;
    return j >= 0 && j < sibs.length;
  }

  /// The first thing to put right before the plan can be made, with the step it is on; null when it is ready.
  ({String message, int step})? _problem() {
    if (_tasks.isEmpty) return (message: 'Please add at least one task before generating the Gratt plan.', step: 2);
    final used = _phases.where((p) => _tasks.any((t) => t.phaseId == p.id));
    if (used.any((p) => p.name.trim().isEmpty)) return (message: 'Give every phase a name.', step: 1);
    if (_tasks.any((t) => t.title.trim().isEmpty)) return (message: 'Give every task and sub-task a title.', step: 2);
    for (final t in _tasks) {
      final a = t.startTime, b = t.endTime;
      if (_isGroup(t) || t.isMilestone || !t.isSameDay || a == null || b == null) continue;
      if (b.hour * 60 + b.minute <= a.hour * 60 + a.minute) return (message: '"${_label(t)}" ends before it starts — fix its times.', step: 2);
    }
    return null;
  }

  /// The title without its "3. " number, to tell whether a phase is already in the project.
  static String _bare(String name) => name.replaceFirst(RegExp(r'^\s*\d+\s*[.)]\s*'), '').trim().toLowerCase();

  bool _phaseExists(PlanPhaseDraft phase) {
    final name = _bare(phase.name);
    if (name.isEmpty) return false;
    return widget.existingTasks.any((t) => (t.parentTaskId ?? '').isEmpty && _bare(t.title) == name);
  }

  // The drafts as the schedule sees them, and in the order they read: each phase's tasks, each followed by its sub-tasks.
  List<DraftTask> get _draftTasks => [
    for (final t in _tasks)
      DraftTask(
        id: t.id,
        parentId: t.parentId,
        durationDays: t.durationDays,
        isMilestone: t.isMilestone,
        predecessorIds: t.predecessorIds,
        explicitStart: t.startDate,
        sameDay: t.isSameDay,
      ),
  ];

  String _label(PlanTaskDraft t) => t.title.trim().isEmpty ? 'Untitled task' : t.title;
  String _phaseLabel(PlanPhaseDraft p) => p.name.trim().isEmpty ? 'Untitled phase' : p.name;

  bool _isGroup(PlanTaskDraft t) => _tasks.any((c) => c.parentId == t.id);

  List<PlanTaskDraft> _subTasksOf(PlanTaskDraft t) => _tasks.where((c) => c.parentId == t.id).toList();

  // ── cost: only for someone who may set a project's costs (the project manager, the owning department's head, an admin) ──

  bool get _canCost => widget.project?.access.canEditCost ?? false;
  TaskPlan? get _taskPlan => widget.project?.cost?.taskPlan;

  /// What these new tasks add to the plan, against the project's budget (tasks that have sub-tasks never count: their cost is theirs).
  PlanCostSummary _costSummary() => summarizePlanCost(
    tasks: [for (final t in _tasks) (planned: t.plannedCost, isGroup: _isGroup(t))],
    existing: _taskPlan?.planned ?? plannedTotal(widget.existingTasks),
    ceiling: _taskPlan?.ceiling ?? 0,
    awaiting: _taskPlan?.awaiting ?? false,
  );

  Future<void> _editCost(PlanTaskDraft t) async {
    final choice = await showTaskCostDialog(
      context,
      initial: TaskCostInput(mode: t.costMode, amount: t.costAmount, rate: t.costRate),
      initialHours: t.hours,
      title: t.title.trim().isEmpty ? 'Planned cost' : 'Planned cost — ${t.title.trim()}',
    );
    if (choice == null || !mounted) return;
    setState(() {
      t.costMode = choice.input.mode;
      t.costAmount = choice.input.mode == TaskCostMode.amount ? choice.input.amount : 0;
      t.costRate = choice.input.mode == TaskCostMode.rate ? choice.input.rate : 0;
      t.hours = choice.input.mode == TaskCostMode.rate ? choice.hours : 0;
    });
  }

  static String _hoursText(double h) => h == h.roundToDouble() ? '${h.round()}' : '$h';

  /// The ₹ chip of a task row: what it costs, or "Add cost"; the cross takes the cost away.
  Widget _costChip(CrmTheme crm, PlanTaskDraft t) {
    final has = t.costMode.isNotEmpty && t.plannedCost > 0;
    final text = !has
        ? 'Add cost'
        : (t.costMode == TaskCostMode.rate ? '${_hoursText(t.hours)} h × ${rupees(t.costRate)} = ${rupees(t.plannedCost)}' : rupees(t.plannedCost));
    return Tooltip(
      message: has ? text : 'Give this task a planned cost',
      child: _whenChip(
        crm,
        chipKey: Key('wizard_cost_${t.id}'),
        icon: Icons.payments_outlined,
        text: text,
        fixed: has,
        onTap: () => _editCost(t),
        onClear: has
            ? () => setState(() {
                t.costMode = '';
                t.costAmount = 0;
                t.costRate = 0;
                t.hours = 0;
              })
            : null,
        clearKey: Key('wizard_cost_clear_${t.id}'),
      ),
    );
  }

  /// Above the task rows: what the new tasks add up to, and what that does to the plan against the approved budget.
  Widget _costStrip(CrmTheme crm) {
    final s = _costSummary();
    final color = spendLevelColor(s.level);
    return Container(
      key: const Key('wizard_cost_strip'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.needsIncrease ? color : crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 16, color: crm.primary),
              const SizedBox(width: 6),
              Expanded(child: Text('Planned cost of these tasks', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textSecondary))),
              Text(rupees(s.newTotal), key: const Key('wizard_cost_total'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 18,
              runSpacing: 2,
              children: [
                if (s.priced == 0)
                  Text(
                    'Costs are optional. Use the ₹ chip on a task to give it one: an amount, or hours × a rate.',
                    key: const Key('wizard_cost_hint'),
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                if (s.ceiling > 0 && s.newTotal > 0)
                  Text(
                    'The plan so far ${rupees(s.existing)} + these = ${rupees(s.after)} of the ${rupees(s.ceiling)} ${s.awaiting ? 'asked for' : 'approved'}.',
                    key: const Key('wizard_cost_plan'),
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                if (s.needsIncrease)
                  Text(
                    '${rupees(s.over)} above the budget. When you create the plan you will be asked for a budget increase for the finance head.',
                    key: const Key('wizard_cost_over'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                  ),
                if (s.priced > 0 && s.unpriced > 0)
                  Text(
                    '${s.unpriced} of ${s.priced + s.unpriced} ${s.priced + s.unpriced == 1 ? 'task has' : 'tasks have'} no cost yet.',
                    key: const Key('wizard_cost_unpriced'),
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PlanTaskDraft> get _orderedTasks => [
    for (final ph in _phases)
      for (final t in _tasks.where((t) => t.phaseId == ph.id && t.parentId == null)) ...[t, ..._subTasksOf(t)],
    // anything under a phase that is gone still shows up, so nothing is lost
    ..._tasks.where((t) => !_phases.any((p) => p.id == t.phaseId)),
  ];

  /// Takes [ids] out of the plan, and out of everything that waited for them.
  void _removeTasks(Set<String> ids) {
    _tasks.removeWhere((t) => ids.contains(t.id));
    _selected.removeAll(ids);
    _collapsed.removeAll(ids);
    for (final t in _tasks) {
      t.predecessorIds.removeWhere(ids.contains);
    }
  }

  Set<String> _withSubTasks(String id) => {id, ..._tasks.where((t) => t.parentId == id).map((t) => t.id)};

  void _addSubTask(PlanTaskDraft parent) {
    final siblings = _subTasksOf(parent);
    final first = siblings.isEmpty;
    setState(() {
      _collapsed.remove(parent.id);
      _tasks.add(
        PlanTaskDraft(
          id: _generateId('tsk'),
          phaseId: parent.phaseId,
          parentId: parent.id,
          title: '',
          // the first one keeps the length the task had, so adding it does not shrink the plan
          durationDays: first ? math.max(1, parent.durationDays) : 2,
          // ... and the dates and times that were fixed on it: from now on the task spans its sub-tasks
          startDate: first ? parent.startDate : null,
          endDate: first ? parent.endDate : null,
          startTime: first ? parent.startTime : null,
          endTime: first ? parent.endTime : null,
          // each follows the one before it (change that in the last step)
          predecessorIds: first ? [] : [siblings.last.id],
        ),
      );
      if (first) {
        parent
          ..startDate = null
          ..endDate = null
          ..startTime = null
          ..endTime = null;
      }
    });
  }

  @override
  void dispose() {
    _leadController.dispose();
    _objectiveController.dispose();
    _tableScroll.dispose();
    super.dispose();
  }

  DraftSchedule _calculateGantt() => scheduleDraftTasks(baseStart: _windowStartDate, tasks: _draftTasks);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [day] at [t]; a day with no time stays exactly as the schedule made it.
  static DateTime _withTime(DateTime day, TimeOfDay? t) => t == null ? day : DateTime(day.year, day.month, day.day, t.hour, t.minute);

  /// How a date goes to the server: a day on its own as always; with a clock time, as the exact moment (UTC) — sent
  /// without a zone the server would read 10:00 here as 10:00 there and it would come back as 15:30.
  static String _iso(DateTime d, bool timed) => timed ? d.toUtc().toIso8601String() : d.toIso8601String();

  /// Every task's start and end as saved. A task with sub-tasks (and so a phase) spans the earliest start and the latest end
  /// of what is under it, clock times included.
  Map<String, _Stamp> _stamps(DraftSchedule sched) {
    final out = <String, _Stamp>{};
    for (final t in _tasks) {
      if (_isGroup(t)) continue;
      final d = sched.dates[t.id];
      if (d == null) continue;
      final from = t.startTime;
      final to = t.isMilestone ? t.startTime : t.endTime; // a milestone is at one moment
      out[t.id] = _Stamp(_withTime(d.start, from), _withTime(d.end, to), startTimed: from != null, endTimed: to != null);
    }
    List<PlanTaskDraft> leavesOf(PlanTaskDraft g) => [
      for (final c in _subTasksOf(g)) ...(_isGroup(c) ? leavesOf(c) : [c]),
    ];
    for (final g in _tasks.where(_isGroup)) {
      _Stamp? first, last;
      for (final leaf in leavesOf(g)) {
        final s = out[leaf.id];
        if (s == null) continue;
        if (first == null || s.start.isBefore(first.start)) first = s;
        if (last == null || s.end.isAfter(last.end)) last = s;
      }
      if (first != null && last != null) out[g.id] = _Stamp(first.start, last.end, startTimed: first.startTimed, endTimed: last.endTimed);
    }
    return out;
  }

  // ── what a planner fixes on a task: when it starts, when it ends, and at what time of day ──

  /// Fixes the start day. With an end fixed too the whole stretch moves and keeps its length.
  void _setStart(PlanTaskDraft t, DateTime day) {
    final d = _day(day);
    final keep = t.endDate != null && t.startDate != null;
    final same = t.isSameDay;
    t.startDate = d;
    if (keep) t.endDate = DateTime(d.year, d.month, d.day + (same ? 0 : t.durationDays));
  }

  /// Fixes the end day (never before the start). The start is fixed where it stands now, so the two stay as chosen, and the
  /// length becomes the days between them.
  void _setEnd(PlanTaskDraft t, DateTime day, DateTime shownStart) {
    final start = _day(shownStart);
    final end = _day(day).isBefore(start) ? start : _day(day);
    t.startDate = start;
    t.endDate = end;
    t.durationDays = daysBetweenPicked(start, end);
    t.rev++;
  }

  /// A new length. With dates fixed the end follows it.
  void _setLength(PlanTaskDraft t, int days) {
    t.durationDays = days < 1 ? 1 : days;
    final start = t.startDate;
    if (start != null && t.endDate != null) t.endDate = DateTime(start.year, start.month, start.day + t.durationDays);
  }

  Future<void> _pickDate(PlanTaskDraft t, DraftSchedule sched, {required bool end}) async {
    final d = sched.dates[t.id];
    final shownStart = _day(d?.start ?? _windowStartDate);
    final shownEnd = _day(d?.end ?? shownStart);
    final planStart = _day(_windowStartDate);
    final first = end ? shownStart : (planStart.isBefore(shownStart) ? planStart : shownStart);
    final initial = end ? shownEnd : shownStart;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(first.year + 6, 12, 31),
      helpText: end ? 'Ends on' : 'Starts on',
    );
    if (picked == null || !mounted) return;
    setState(() => end ? _setEnd(t, picked, shownStart) : _setStart(t, picked));
  }

  Future<void> _pickTime(PlanTaskDraft t, {required bool end}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (end ? t.endTime : t.startTime) ?? TimeOfDay(hour: end ? 17 : 9, minute: 0),
      helpText: end ? 'Ends at' : 'Starts at',
    );
    if (picked == null || !mounted) return;
    setState(() => end ? t.endTime = picked : t.startTime = picked);
  }

  Future<void> _saveAndGeneratePlan() async {
    // a second press while the plan is being made must not make it again (the button only greys out on the next frame)
    if (_busy) return;
    final problem = _problem();
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem.message)));
      setState(() => _currentStep = problem.step); // take them to what needs fixing
      return;
    }

    final schedResult = _calculateGantt();
    if (schedResult.hasCycle) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(schedResult.cycleError ?? 'Circular dependency detected. Please resolve loops between tasks first.'),
        ),
      );
      return;
    }

    // Costs: when these tasks would take the plan above the approved budget, a budget increase is asked of the finance head FIRST, once, so
    // every task then fits inside that request (nothing is made if the person backs out).
    double? raisedTo;
    if (_canCost) {
      final cost = _costSummary();
      if (cost.needsIncrease) {
        final ask = await showBudgetIncreaseDialog(
          context,
          OverBudget(
            message:
                'With these tasks the plan comes to ${rupees(cost.after)}, ${rupees(cost.over)} above the ${rupees(cost.ceiling)} the project has. A budget increase has to be asked of the finance head before the tasks are made.',
            planned: cost.after,
            ceiling: cost.ceiling,
            over: cost.over,
            canRequest: true,
          ),
        );
        if (ask == null || !mounted) return;
        try {
          await ref.read(projectServiceProvider).raiseCost(widget.projectId, amount: ask.amount, reason: ask.reason);
          raisedTo = ask.amount;
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
          return;
        }
      }
    }

    if (!mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(itTaskRepositoryProvider);
      final stamps = _stamps(schedResult);

      // New phases go after what the project already has
      var orderSeq = widget.existingTasks.isEmpty ? 10 : widget.existingTasks.map((t) => t.order).reduce(math.max) + 1;

      // Map phase drafts to created parent task IDs
      final phaseTaskIdMap = <String, String>{};
      for (final phase in _phases) {
        final phaseTasks = _tasks.where((t) => t.phaseId == phase.id).toList();
        if (phaseTasks.isEmpty) continue;

        // Earliest start and latest due for this phase
        _Stamp? phaseFirst, phaseLast;
        for (final pt in phaseTasks) {
          final st = stamps[pt.id];
          if (st == null) continue;
          if (phaseFirst == null || st.start.isBefore(phaseFirst.start)) phaseFirst = st;
          if (phaseLast == null || st.end.isAfter(phaseLast.end)) phaseLast = st;
        }
        final phaseStart = phaseFirst?.start;
        final phaseDue = phaseLast?.end;
        final phaseDueText = _iso(phaseDue ?? _windowStartDate.add(const Duration(days: 7)), phaseLast?.endTimed ?? false);

        final phaseBody = <String, dynamic>{
          'projectId': widget.projectId,
          'title': phase.name,
          'description': 'Functional phase for $_departmentName',
          'departmentName': _departmentName,
          'ticketType': ITTicketType.feature.slug,
          'category': ITTicketType.feature.slug,
          'status': ITTaskStatus.todo.slug,
          'severity': ITSeverity.p2.slug,
          'order': orderSeq++,
          'startDate': _iso(phaseStart ?? _windowStartDate, phaseFirst?.startTimed ?? false),
          'deadline': phaseDueText,
          'dueDate': phaseDueText,
        };

        final createdPhase = await repo.createTask(phaseBody);
        phaseTaskIdMap[phase.id] = createdPhase.id;
      }

      // Tasks under their phase, sub-tasks under their task: a parent is always made before what hangs under it
      final draftIdToCreatedIdMap = <String, String>{};
      var created = 0;
      for (final task in _orderedTasks) {
        final stamp = stamps[task.id];
        final parentId = task.parentId != null ? draftIdToCreatedIdMap[task.parentId] : phaseTaskIdMap[task.phaseId];

        final taskBody = <String, dynamic>{
          'projectId': widget.projectId,
          'parentTaskId': parentId,
          'title': task.title,
          'description': 'Objective: ${_objectiveController.text.trim()}',
          'departmentName': _departmentName,
          'ticketType': ITTicketType.feature.slug,
          'category': ITTicketType.feature.slug,
          'severity': task.severity.slug,
          'priority': task.severity.slug,
          'status': ITTaskStatus.todo.slug,
          'assignedTo': task.assigneeId,
          'order': orderSeq++,
          // what the task costs: only for someone who may set it, and never for a task that has sub-tasks (their cost is the sum of theirs)
          if (_canCost && !_isGroup(task)) ...{
            'costMode': task.costMode,
            'costAmount': task.costMode == TaskCostMode.amount ? task.costAmount : 0,
            'costRate': task.costMode == TaskCostMode.rate ? task.costRate : 0,
            if (task.costMode == TaskCostMode.rate) 'estimatedHours': task.hours,
          },
          if (stamp != null) 'startDate': _iso(stamp.start, stamp.startTimed),
          if (stamp != null) 'deadline': _iso(stamp.end, stamp.endTimed),
          if (stamp != null) 'dueDate': _iso(stamp.end, stamp.endTimed),
        };

        final made = await repo.createTask(taskBody);
        draftIdToCreatedIdMap[task.id] = made.id;
        created++;
      }

      // Update predecessor references with created backend IDs
      for (final task in _tasks) {
        final createdId = draftIdToCreatedIdMap[task.id];
        if (createdId == null || task.predecessorIds.isEmpty) continue;

        final realPredecessorIds = task.predecessorIds.map((pid) => draftIdToCreatedIdMap[pid]).whereType<String>().toList();

        if (realPredecessorIds.isNotEmpty) {
          await repo.updateTask(createdId, {'predecessorIds': realPredecessorIds, 'predecessors': realPredecessorIds});
        }
      }

      refreshAllItTaskViews(ref);
      if (_canCost) ref.invalidate(projectsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onPlanCreated?.call();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Text(
              '✅ Added ${phaseTaskIdMap.length} phase${phaseTaskIdMap.length == 1 ? '' : 's'} and $created task${created == 1 ? '' : 's'} to the plan!'
              '${raisedTo == null ? '' : ' A budget of ${rupees(raisedTo)} was sent to the finance head.'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final size = MediaQuery.of(context).size;
    final dialogWidth = math.min(1280.0, size.width - 32);
    final dialogHeight = math.min(940.0, size.height - 40);

    return Dialog(
      backgroundColor: crm.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogHeight),
        child: Column(
          children: [
            // Header
            _buildHeader(crm),
            // Step Progress Indicator
            _buildStepIndicator(crm),
            const Divider(height: 1),
            // Body Step Content
            Expanded(
              child: Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 16), child: _buildCurrentStepContent(crm)),
            ),
            const Divider(height: 1),
            // Footer Navigation
            _buildFooter(crm),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CrmTheme crm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.view_timeline_outlined, color: crm.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Functional Plan & Gratt Auto-Scheduler',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Define department scope, phases, deliverables, and auto-sequence the interactive Gratt chart.',
                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 20), tooltip: 'Cancel'),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(CrmTheme crm) {
    final steps = ['Scope & Lead', 'Phases & WBS', 'Tasks & Team', 'Dependencies & Gratt'];

    // the step you are on is the filled pill; the ones done are ticked green
    Widget pill(int i, {required bool stretch}) {
      final isActive = i == _currentStep;
      final isPast = i < _currentStep;
      final label = Text(
        steps[i],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          color: isActive ? Colors.white : (isPast ? crm.textPrimary : crm.textSecondary),
        ),
      );
      return InkWell(
        key: Key('wizard_step_$i'),
        onTap: _busy ? null : () => setState(() => _currentStep = i),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: isActive ? crm.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isPast ? const Color(0xFF10B981) : (isActive ? Colors.white : crm.border),
                child: isPast
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isActive ? crm.primary : crm.textSecondary),
                      ),
              ),
              const SizedBox(width: 10),
              stretch ? Flexible(child: label) : label,
            ],
          ),
        ),
      );
    }

    // a hairline between two steps (none beside the filled one)
    Widget divider(int i) => Container(width: 1, height: 22, color: (i == _currentStep || i + 1 == _currentStep) ? Colors.transparent : crm.border);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 14),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: crm.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            // wide: the four share the bar; narrow: they keep their size and the bar scrolls
            if (c.maxWidth >= 820) {
              return Row(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[Expanded(child: pill(i, stretch: true)), if (i < steps.length - 1) divider(i)],
                ],
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[pill(i, stretch: false), if (i < steps.length - 1) divider(i)],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent(CrmTheme crm) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Scope(crm);
      case 1:
        return _buildStep2Phases(crm);
      case 2:
        return _buildStep3Tasks(crm);
      case 3:
      default:
        return _buildStep4GanttPreview(crm);
    }
  }

  // -------------------------------------------------------------
  // STEP 1: FUNCTION SCOPE
  // -------------------------------------------------------------
  Widget _buildStep1Scope(CrmTheme crm) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final main = _scopeCard(crm);
        final summary = _planSummaryCard(crm);
        return SingleChildScrollView(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: main),
                    const SizedBox(width: 20),
                    SizedBox(width: 340, child: summary),
                  ],
                )
              : Column(children: [main, const SizedBox(height: 16), summary]),
        );
      },
    );
  }

  /// A white card with a hairline border and a soft shadow: what step 1 is made of.
  Widget _card(CrmTheme crm, {required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(24), Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  /// A small rounded tile that holds an icon.
  Widget _iconTile(CrmTheme crm, IconData icon, {double size = 36}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, size: size * 0.5, color: crm.primary),
  );

  Widget _fieldLabel(CrmTheme crm, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
    ),
  );

  InputDecoration _fieldDecoration(CrmTheme crm, {String? hint, IconData? icon, Widget? prefix}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13.5, color: crm.textSecondary.withValues(alpha: 0.8)),
    filled: true,
    fillColor: crm.surface,
    prefixIcon: prefix ?? (icon == null ? null : Icon(icon, size: 19, color: crm.textSecondary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.primary, width: 1.5)),
  );

  Widget _scopeCard(CrmTheme crm) {
    return _card(
      crm,
      key: const Key('wizard_scope_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconTile(crm, Icons.track_changes_rounded, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Function Overview',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Specify which functional department is leading this delivery window and the core milestone objectives.',
                      style: TextStyle(fontSize: 13, color: crm.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasExistingPlan) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('wizard_existing_note'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: crm.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: crm.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: crm.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This project already has $_existingPhases phase${_existingPhases == 1 ? '' : 's'} and ${widget.existingTasks.length - _existingPhases} '
                      'task${widget.existingTasks.length - _existingPhases == 1 ? '' : 's'}. What you add here goes after them — nothing that is there changes.',
                      style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _departmentField(crm)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(crm, 'Functional Lead / Head'),
                    TextField(
                      key: const Key('wizard_lead_field'),
                      controller: _leadController,
                      style: const TextStyle(fontSize: 14),
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDecoration(crm, hint: 'e.g. Head of Operations / Team Lead', icon: Icons.person_outline_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(crm, 'Window Start Date'),
                    InkWell(
                      key: const Key('wizard_start_window'),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: _windowStartDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                        if (picked != null) setState(() => _windowStartDate = picked);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                        decoration: BoxDecoration(border: Border.all(color: crm.border), borderRadius: BorderRadius.circular(10), color: crm.surface),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 19, color: crm.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(child: Text(DateFormat.yMMMd().format(_windowStartDate), style: const TextStyle(fontSize: 14))),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: crm.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: crm.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You build the plan yourself in the next steps: add its phases, then the tasks (and sub-tasks) in each. Tasks are dated from this day, along their dependencies.',
                            style: TextStyle(fontSize: 12, height: 1.4, color: crm.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _fieldLabel(crm, 'Key Deliverable / Objective Statement'),
          Stack(
            children: [
              TextField(
                key: const Key('wizard_objective_field'),
                controller: _objectiveController,
                minLines: 4,
                maxLines: 4,
                maxLength: _objectiveMax,
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => setState(() {}),
                buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$currentLength / $maxLength',
                    key: const Key('wizard_objective_count'),
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ),
                decoration: _fieldDecoration(
                  crm,
                  hint: 'Briefly describe what this functional plan aims to accomplish and its expected outcome...',
                ).copyWith(contentPadding: const EdgeInsets.fromLTRB(46, 15, 14, 15)),
              ),
              Positioned(
                left: 14,
                top: 15,
                child: IgnorePointer(child: Icon(Icons.subject_rounded, size: 19, color: crm.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// How long the objective statement may be (it is a brief, and goes into each phase's description).
  static const int _objectiveMax = 500;

  Widget _departmentField(CrmTheme crm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(crm, 'Department'),
        if (_departments.length == 1)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
            child: Row(
              children: [
                Icon(Icons.business_center_outlined, size: 19, color: crm.primary),
                const SizedBox(width: 10),
                Text(
                  _departmentName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'Project Owner',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.primary),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _departments.contains(_departmentName) ? _departmentName : _departments.first,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: crm.textSecondary),
            decoration: _fieldDecoration(crm, icon: Icons.business_center_outlined).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
            items: _departments
                .map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text(d, style: const TextStyle(fontSize: 14)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _departmentName = v);
            },
          ),
        const SizedBox(height: 6),
        Text(
          _departments.length == 1
              ? 'This project belongs to $_departmentName. To involve other departments, invite them in Project Settings.'
              : 'Active participating departments on this project.',
          style: TextStyle(fontSize: 11.5, color: crm.textSecondary.withValues(alpha: 0.9)),
        ),
        if (widget.project?.invitedDepartments.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.info_outline, size: 12, color: crm.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Pending invites: ${widget.project!.invitedDepartments.map((d) => d.name).join(', ')} (available once accepted)',
                  style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// The right-hand card of step 1: what has been entered so far, as it will read.
  Widget _planSummaryCard(CrmTheme crm) {
    final lead = _leadController.text.trim();
    final objective = _objectiveController.text.trim();
    Widget row(IconData icon, String label, String value, Key key, {bool last = false, int maxLines = 1, bool muted = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: crm.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconTile(crm, icon, size: 34),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(label, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                value,
                key: key,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: muted ? FontWeight.w500 : FontWeight.w700, color: muted ? crm.textSecondary : crm.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );

    return _card(
      crm,
      key: const Key('wizard_summary_card'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(color: crm.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              children: [
                _iconTile(crm, Icons.view_timeline_outlined, size: 38),
                const SizedBox(width: 12),
                Text(
                  'Plan Summary',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: Column(
              children: [
                row(Icons.business_center_outlined, 'Department', _departmentName, const Key('wizard_summary_department')),
                row(Icons.person_outline_rounded, 'Functional Lead', lead.isEmpty ? '—' : lead, const Key('wizard_summary_lead'), muted: lead.isEmpty),
                row(Icons.calendar_month_outlined, 'Start Date', DateFormat.yMMMd().format(_windowStartDate), const Key('wizard_summary_start')),
                row(
                  Icons.track_changes_rounded,
                  'Key Objective',
                  objective.isEmpty ? '—' : objective,
                  const Key('wizard_summary_objective'),
                  last: true,
                  maxLines: 3,
                  muted: objective.isEmpty,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 2: PHASES & WBS
  // -------------------------------------------------------------
  Widget _buildStep2Phases(CrmTheme crm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Milestones & Phases (WBS)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add the phases of this plan and put them in the order they happen.',
                    style: TextStyle(fontSize: 13, color: crm.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: crm.primary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              onPressed: () {
                setState(() {
                  final newId = _generateId('ph');
                  _phases.add(PlanPhaseDraft(id: newId, name: '', color: _phaseColors[_phases.length % _phaseColors.length]));
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Phase', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _phases.isEmpty
              ? Center(
                  child: Text('No phases yet. Add the first phase of this plan.', style: TextStyle(color: crm.textSecondary)),
                )
              : ListView.separated(
                  itemCount: _phases.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final phase = _phases[i];
                    final phaseTaskCount = _tasks.where((t) => t.phaseId == phase.id).length;
                    return Container(
                      key: ValueKey('phase_${phase.id}'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: crm.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: crm.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 38,
                            decoration: BoxDecoration(color: phase.color, borderRadius: BorderRadius.circular(4)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: phase.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Name this phase'),
                              onChanged: (val) => setState(() => phase.name = val),
                            ),
                          ),
                          if (_phaseExists(phase))
                            Tooltip(
                              message: 'The project already has a phase with this name',
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Already in the project',
                                      key: Key('phase_exists_${phase.id}'),
                                      style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Chip(
                            label: Text('$phaseTaskCount tasks', style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            key: Key('wizard_phase_up_${phase.id}'),
                            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                            tooltip: 'Move up',
                            onPressed: i == 0 ? null : () => _movePhase(i, -1),
                          ),
                          IconButton(
                            key: Key('wizard_phase_down_${phase.id}'),
                            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                            tooltip: 'Move down',
                            onPressed: i == _phases.length - 1 ? null : () => _movePhase(i, 1),
                          ),
                          IconButton(
                            key: Key('wizard_phase_remove_${phase.id}'),
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            tooltip: 'Remove Phase',
                            onPressed: () {
                              setState(() {
                                _phases.removeAt(i);
                                _removeTasks({
                                  for (final t in _tasks)
                                    if (t.phaseId == phase.id) t.id,
                                });
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // STEP 3: TASKS & OWNERSHIP — one table, a row for each task, read the way the plan will be
  // -------------------------------------------------------------

  // The column widths. The title takes what is left; a window narrower than all of them scrolls the table sideways.
  static const double _cCheck = 40, _cPhase = 148, _cDur = 100, _cAssignee = 120, _cDate = 154, _cCost = 164, _cMenu = 48, _cTitleMin = 236;
  double get _tableMinWidth => _cCheck + _cTitleMin + _cPhase + _cDur + _cAssignee + _cDate * 2 + (_canCost ? _cCost : 0) + _cMenu;

  /// The rows on show: a folded task hides its sub-tasks.
  List<PlanTaskDraft> get _visibleTasks => [
    for (final t in _orderedTasks)
      if (t.parentId == null || !_collapsed.contains(t.parentId)) t,
  ];

  /// One more task, under the phase of the last one added (a task belongs to a phase, so there has to be one).
  void _addTask() {
    if (_phases.isEmpty) return;
    final last = _tasks.where((t) => t.parentId == null).lastOrNull;
    final phase = _phases.where((p) => p.id == last?.phaseId).firstOrNull ?? _phases.first;
    setState(() => _tasks.add(PlanTaskDraft(id: _generateId('tsk'), phaseId: phase.id, title: '', durationDays: 3)));
  }

  /// Asks for a pasted list and adds each line as a task.
  Future<void> _importTasks() async {
    if (_phases.isEmpty) return;
    final last = _tasks.where((t) => t.parentId == null).lastOrNull;
    final choice = await showImportTasksDialog(context, phases: [for (final p in _phases) (id: p.id, label: _phaseLabel(p))], initialPhaseId: last?.phaseId);
    if (choice == null || !mounted) return;
    setState(() {
      for (final t in choice.tasks) {
        _tasks.add(PlanTaskDraft(id: _generateId('tsk'), phaseId: choice.phaseId, title: t.title, durationDays: t.days));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${choice.tasks.length} task${choice.tasks.length == 1 ? '' : 's'} added.')));
  }

  Future<void> _pickAssignee(PlanTaskDraft t, List<Employee> employees) async {
    final picked = await showEmployeePicker(context, employees: employees, selectedId: t.assigneeId, title: 'Assignee');
    if (picked == null || !mounted) return;
    setState(() {
      t.assigneeId = picked.id;
      t.assigneeName = picked.name;
    });
  }

  void _toggleFold(String id) => setState(() => _collapsed.contains(id) ? _collapsed.remove(id) : _collapsed.add(id));

  void _toggleAll(List<PlanTaskDraft> rows) => setState(() {
    final all = rows.isNotEmpty && rows.every((r) => _selected.contains(r.id));
    _selected.clear();
    if (!all) _selected.addAll(rows.map((r) => r.id));
  });

  void _toggleSelected(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  /// The selected tasks go to [phaseId] (a sub-task goes with its task, never on its own).
  void _bulkMove(String phaseId) {
    setState(() {
      for (final t in _tasks.where((t) => _selected.contains(t.id) && t.parentId == null)) {
        t.phaseId = phaseId;
        for (final s in _subTasksOf(t)) {
          s.phaseId = phaseId;
        }
      }
    });
  }

  Future<void> _bulkAssign(List<Employee> employees) async {
    final picked = await showEmployeePicker(context, employees: employees, title: 'Assign ${_selected.length} selected');
    if (picked == null || !mounted) return;
    setState(() {
      for (final t in _tasks.where((t) => _selected.contains(t.id))) {
        t.assigneeId = picked.id;
        t.assigneeName = picked.name;
      }
    });
  }

  Future<void> _bulkDelete() async {
    final ids = <String>{for (final id in _selected) ..._withSubTasks(id)};
    final n = ids.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('wizard_bulk_delete_dialog'),
        title: Text('Delete $n task${n == 1 ? '' : 's'}?'),
        content: Text('${n == 1 ? 'This task' : 'These tasks'}, with any sub-tasks, will be taken out of the plan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            key: const Key('wizard_bulk_delete_ok'),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _removeTasks(ids));
  }

  Widget _buildStep3Tasks(CrmTheme crm) {
    final employees = ref.watch(projectEmployeesProvider(widget.projectId));
    final rows = _visibleTasks;
    final sched = _calculateGantt(); // shows each task's date as it stands, so a picked date can be compared with it

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasks & Ownership',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add deliverables under each phase with a length in days and an assignee. Fix a task\'s dates and times, or leave them "auto" and the plan places it.',
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              key: const Key('wizard_import_open'),
              style: OutlinedButton.styleFrom(
                foregroundColor: crm.primary,
                side: BorderSide(color: crm.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: _phases.isEmpty ? null : _importTasks,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Import Tasks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: crm.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _phases.isEmpty ? null : _addTask,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Task', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_canCost) ...[_costStrip(crm), const SizedBox(height: 10)],
        Expanded(child: _taskTable(crm, rows, employees, sched)),
      ],
    );
  }

  Widget _taskTable(CrmTheme crm, List<PlanTaskDraft> rows, List<Employee> employees, DraftSchedule sched) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = math.max(c.maxWidth, _tableMinWidth);
        final extra = rows.isEmpty ? 1 : 0;
        final table = SizedBox(
          width: width,
          child: Column(
            children: [
              _selected.isEmpty ? _columnHeader(crm, rows) : _bulkBar(crm, rows, employees),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length + extra + 1,
                  itemBuilder: (ctx, i) {
                    if (i < extra) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            _phases.isEmpty ? 'Add a phase first (step 2), then add its tasks here.' : 'No tasks yet. Add one under a phase.',
                            style: TextStyle(color: crm.textSecondary),
                          ),
                        ),
                      );
                    }
                    final r = i - extra;
                    if (r < rows.length) return _taskRow(crm, rows[r], employees, sched);
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: DashedAddRow(key: const Key('wizard_add_row'), label: 'Add a task', onTap: _phases.isEmpty ? null : _addTask),
                    );
                  },
                ),
              ),
            ],
          ),
        );
        return Container(
          decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
          clipBehavior: Clip.antiAlias,
          child: width > c.maxWidth
              ? Scrollbar(
                  controller: _tableScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(controller: _tableScroll, scrollDirection: Axis.horizontal, child: table),
                )
              : table,
        );
      },
    );
  }

  Widget _selectAll(List<PlanTaskDraft> rows) {
    final all = rows.isNotEmpty && rows.every((r) => _selected.contains(r.id));
    return Checkbox(
      key: const Key('wizard_select_all'),
      tristate: true,
      value: all ? true : (_selected.isNotEmpty ? null : false),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: rows.isEmpty ? null : (_) => _toggleAll(rows),
    );
  }

  Widget _columnHeader(CrmTheme crm, List<PlanTaskDraft> rows) {
    final style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.textSecondary, letterSpacing: 0.2);
    Widget cell(double w, String text) => SizedBox(
      width: w,
      child: Text(text, style: style),
    );
    return Container(
      height: 44,
      color: crm.background,
      child: Row(
        children: [
          SizedBox(width: _cCheck, child: Center(child: _selectAll(rows))),
          Expanded(child: Text('Task / Deliverable', style: style)),
          cell(_cPhase, 'Phase'),
          cell(_cDur, 'Duration'),
          cell(_cAssignee, 'Assignee'),
          cell(_cDate, 'Start Date'),
          cell(_cDate, 'End Date'),
          if (_canCost) cell(_cCost, 'Cost'),
          SizedBox(
            width: _cMenu,
            child: Text('Actions', textAlign: TextAlign.center, style: style),
          ),
        ],
      ),
    );
  }

  /// Takes the place of the column names while rows are selected: what can be done to all of them at once.
  Widget _bulkBar(CrmTheme crm, List<PlanTaskDraft> rows, List<Employee> employees) {
    Widget action(Key key, IconData icon, String label, VoidCallback onTap, {Color? color}) => TextButton.icon(
      key: key,
      style: TextButton.styleFrom(foregroundColor: color ?? crm.primary, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
    return Container(
      key: const Key('wizard_bulk_bar'),
      height: 44,
      color: crm.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          SizedBox(width: _cCheck, child: Center(child: _selectAll(rows))),
          Text(
            '${_selected.length} selected',
            key: const Key('wizard_bulk_count'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            key: const Key('wizard_bulk_move'),
            tooltip: 'Move the selected tasks to a phase',
            onSelected: _bulkMove,
            itemBuilder: (_) => [
              for (final p in _phases)
                PopupMenuItem(
                  key: Key('wizard_bulk_move_${p.id}'),
                  value: p.id,
                  child: Text(_phaseLabel(p)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.drive_file_move_outlined, size: 17, color: crm.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Move to phase',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.primary),
                  ),
                ],
              ),
            ),
          ),
          action(const Key('wizard_bulk_assign'), Icons.person_add_alt_1_outlined, 'Assign to', () => _bulkAssign(employees)),
          action(const Key('wizard_bulk_delete'), Icons.delete_outline_rounded, 'Delete', _bulkDelete, color: Colors.redAccent),
          const Spacer(),
          TextButton(key: const Key('wizard_bulk_clear'), onPressed: () => setState(_selected.clear), child: const Text('Clear selection')),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// A phase as a coloured pill (a sub-task's phase is its task's, so it only shows it).
  Widget _phaseLabelPill(PlanPhaseDraft? phase, CrmTheme crm) {
    final color = phase?.color ?? crm.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(
        phase == null ? 'General' : _phaseLabel(phase),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _phasePicker(CrmTheme crm, PlanTaskDraft task) {
    final valid = _phases.any((p) => p.id == task.phaseId) ? task.phaseId : (_phases.isNotEmpty ? _phases.first.id : null);
    final phase = _phases.where((p) => p.id == valid).firstOrNull;
    final color = phase?.color ?? crm.primary;
    TextStyle style(Color c) => TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c);
    return DropdownButtonFormField<String>(
      // the key follows the phase, so a task moved from outside this box (the bulk bar) shows where it went
      key: ValueKey('wizard_phase_${task.id}_${task.phaseId}'),
      initialValue: valid,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: color),
      style: style(color),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: color.withValues(alpha: 0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      ),
      selectedItemBuilder: (_) => [for (final p in _phases) Text(_phaseLabel(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: style(p.color))],
      items: [
        for (final p in _phases)
          DropdownMenuItem(
            value: p.id,
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(_phaseLabel(p), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
                ),
              ],
            ),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          task.phaseId = v;
          for (final sub in _subTasksOf(task)) {
            sub.phaseId = v; // its sub-tasks go where it goes
          }
        });
      },
    );
  }

  Widget _priorityPill(CrmTheme crm, PlanTaskDraft task) {
    return PopupMenuButton<ITSeverity>(
      key: Key('wizard_priority_${task.id}'),
      tooltip: 'Priority: ${task.severity.label}',
      padding: EdgeInsets.zero,
      initialValue: task.severity,
      onSelected: (v) => setState(() => task.severity = v),
      itemBuilder: (_) => [
        for (final s in ITSeverity.values)
          PopupMenuItem(
            value: s,
            child: Text(
              s.label,
              style: TextStyle(fontSize: 12.5, color: s.color, fontWeight: FontWeight.w700),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: task.severity.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
        child: Text(
          task.severity.shortLabel,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: task.severity.color),
        ),
      ),
    );
  }

  Widget _assigneeCell(CrmTheme crm, PlanTaskDraft task, List<Employee> employees) {
    final own = (task.assigneeId ?? '').isNotEmpty;
    String nameOf(String? id, String? fallback) => employees.where((e) => e.id == id).firstOrNull?.name ?? fallback ?? 'Assigned';
    // a task with sub-tasks and no one of its own shows the people on its sub-tasks
    final fromSubs = <String>{
      if (!own)
        for (final s in _subTasksOf(task))
          if ((s.assigneeId ?? '').isNotEmpty) nameOf(s.assigneeId, s.assigneeName),
    }.toList();

    Widget content;
    if (own) {
      final name = nameOf(task.assigneeId, task.assigneeName);
      content = Row(
        children: [
          InitialsAvatar(name: name),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary),
            ),
          ),
        ],
      );
    } else if (fromSubs.isNotEmpty) {
      final shown = fromSubs.take(3).toList();
      content = Row(
        children: [
          SizedBox(
            width: 28 + (shown.length - 1) * 18.0,
            height: 28,
            child: Stack(children: [for (var i = 0; i < shown.length; i++) Positioned(left: i * 18.0, child: InitialsAvatar(name: shown[i]))]),
          ),
          if (fromSubs.length > shown.length) ...[
            const SizedBox(width: 6),
            Text('+${fromSubs.length - shown.length}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
          ],
        ],
      );
    } else {
      content = Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: crm.border)),
            child: Icon(Icons.person_add_alt_1_outlined, size: 14, color: crm.textSecondary),
          ),
          const SizedBox(width: 6),
          Text('Assign', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ],
      );
    }
    return InkWell(
      key: Key('wizard_assignee_${task.id}'),
      borderRadius: BorderRadius.circular(20),
      onTap: () => _pickAssignee(task, employees),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2), child: content),
    );
  }

  Widget _milestoneToggle(CrmTheme crm, PlanTaskDraft task) {
    return Tooltip(
      message: 'Milestone Gate (Zero Duration)',
      child: IconButton(
        style: _tinyIcon(28),
        icon: Icon(
          task.isMilestone ? Icons.flag_rounded : Icons.outlined_flag_rounded,
          size: 18,
          color: task.isMilestone ? const Color(0xFFF59E0B) : crm.textSecondary,
        ),
        onPressed: () => setState(() {
          task.isMilestone = !task.isMilestone;
          if (task.isMilestone) {
            task.endDate = null;
            task.endTime = null;
          }
        }),
      ),
    );
  }

  /// An icon button as small as [size] (the default one is 40 wide, which no table cell has room for).
  static ButtonStyle _tinyIcon(double size) => IconButton.styleFrom(
    minimumSize: Size(size, size),
    maximumSize: Size(size, size),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );

  /// A leaf task's length: a number of days, and the flag that makes it a milestone.
  Widget _durationCell(CrmTheme crm, PlanTaskDraft task) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: TextFormField(
            key: Key('wizard_dur_${task.id}_${task.rev}'),
            initialValue: task.durationDays.toString(),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              suffixText: 'd',
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => setState(() {
              final n = int.tryParse(val) ?? 1;
              if (task.endDate != null) {
                _setLength(task, n);
              } else {
                task.durationDays = n;
              }
            }),
          ),
        ),
        const SizedBox(width: 2),
        _milestoneToggle(crm, task),
      ],
    );
  }

  /// A task with sub-tasks has no days of its own: it is as long as the span of its sub-tasks.
  Widget _spanCell(CrmTheme crm, PlanTaskDraft task, _Span? d) {
    final days = d == null ? null : daysBetweenPicked(d.start, d.end);
    return Tooltip(
      message: 'Its length is the span of its sub-tasks',
      child: Column(
        key: Key('wizard_span_${task.id}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            days == null ? '—' : '$days ${days == 1 ? 'day' : 'days'}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
          ),
          Text('from sub-tasks', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: crm.textSecondary)),
        ],
      ),
    );
  }

  Widget _groupDateCell(CrmTheme crm, PlanTaskDraft task, _Span? d, {required bool end}) {
    return Row(
      children: [
        Icon(Icons.event_outlined, size: 14, color: crm.textSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            d == null ? '—' : _chipDate.format(end ? d.end : d.start),
            key: Key('wizard_group_${end ? 'end' : 'start'}_${task.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: crm.textSecondary),
          ),
        ),
      ],
    );
  }

  /// A leaf task's start or end: the day (fixed by the planner, or "auto" as the plan chose it) and the time of day.
  Widget _dateCell(CrmTheme crm, PlanTaskDraft t, DraftSchedule sched, {required bool end}) {
    final d = sched.dates[t.id];
    final start = d?.start ?? _day(_windowStartDate);
    final shown = end ? (d?.end ?? start) : start;
    final pushedFrom = t.startDate;
    final pushed = pushedFrom != null && start.isAfter(_day(pushedFrom));
    // a milestone is at one moment: it has a start and no end
    if (end && t.isMilestone) {
      return Text('Milestone', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: crm.textSecondary));
    }
    final which = end ? 'end' : 'start';
    final time = end ? t.endTime : t.startTime;
    final timeKey = Key('wizard_${which}_time_${t.id}');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // a start the plan had to move (an earlier task is not done by then) shows the day it really starts, in amber; the end
            // that was picked no longer holds either, so it is shown as the plan's
            Flexible(
              child: _whenChip(
                crm,
                chipKey: Key('wizard_${which}_date_${t.id}'),
                icon: Icons.calendar_today_outlined,
                text: _chipDate.format(shown),
                fixed: end ? (t.endDate != null && !pushed) : t.startDate != null,
                warn: !end && pushed,
                onTap: () => _pickDate(t, sched, end: end),
              ),
            ),
            if (!end && t.startDate != null)
              IconButton(
                key: Key('wizard_clear_dates_${t.id}'),
                tooltip: 'Let the plan decide this task\'s dates',
                style: _tinyIcon(26),
                icon: Icon(Icons.restart_alt_rounded, size: 16, color: crm.textSecondary),
                onPressed: () => setState(() {
                  t.startDate = null;
                  t.endDate = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (time == null)
          InkWell(
            key: timeKey,
            borderRadius: BorderRadius.circular(6),
            onTap: () => _pickTime(t, end: end),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 12, color: crm.textSecondary),
                  const SizedBox(width: 4),
                  Text('Add time', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                ],
              ),
            ),
          )
        else
          _whenChip(
            crm,
            chipKey: timeKey,
            icon: Icons.schedule_rounded,
            text: time.format(context),
            fixed: true,
            onTap: () => _pickTime(t, end: end),
            onClear: () => setState(() => end ? t.endTime = null : t.startTime = null),
            clearKey: Key('wizard_${which}_time_clear_${t.id}'),
          ),
      ],
    );
  }

  Widget _menuRow(IconData icon, String text, {Color? color}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Flexible(
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: color)),
      ),
    ],
  );

  Widget _actionsMenu(CrmTheme crm, PlanTaskDraft task, bool isSub, bool isGroup) {
    return PopupMenuButton<String>(
      key: Key('wizard_menu_${task.id}'),
      tooltip: 'Actions',
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz_rounded, size: 20, color: crm.textSecondary),
      onSelected: (v) {
        switch (v) {
          case 'sub':
            _addSubTask(task);
          case 'up':
            _moveTask(task, -1);
          case 'down':
            _moveTask(task, 1);
          case 'unassign':
            setState(() {
              task.assigneeId = null;
              task.assigneeName = null;
            });
          case 'remove':
            setState(() => _removeTasks(_withSubTasks(task.id)));
        }
      },
      itemBuilder: (_) => [
        if (!isSub)
          PopupMenuItem(
            key: Key('wizard_add_sub_${task.id}'),
            value: 'sub',
            enabled: !task.isMilestone,
            child: _menuRow(Icons.account_tree_outlined, task.isMilestone ? 'A milestone cannot have sub-tasks' : 'Add sub-task'),
          ),
        PopupMenuItem(key: const Key('wizard_move_up'), value: 'up', enabled: _canMoveTask(task, -1), child: _menuRow(Icons.arrow_upward_rounded, 'Move up')),
        PopupMenuItem(key: const Key('wizard_move_down'), value: 'down', enabled: _canMoveTask(task, 1), child: _menuRow(Icons.arrow_downward_rounded, 'Move down')),
        if ((task.assigneeId ?? '').isNotEmpty)
          PopupMenuItem(key: Key('wizard_unassign_${task.id}'), value: 'unassign', child: _menuRow(Icons.person_remove_outlined, 'Remove assignee')),
        const PopupMenuDivider(),
        PopupMenuItem(
          key: Key('wizard_remove_${task.id}'),
          value: 'remove',
          child: _menuRow(Icons.delete_outline_rounded, isSub ? 'Remove sub-task' : (isGroup ? 'Remove task and its sub-tasks' : 'Remove'), color: Colors.redAccent),
        ),
      ],
    );
  }

  Widget _taskRow(CrmTheme crm, PlanTaskDraft task, List<Employee> employees, DraftSchedule sched) {
    final isSub = task.parentId != null;
    final isGroup = _isGroup(task);
    final selected = _selected.contains(task.id);
    final d = sched.dates[task.id];
    final subs = isGroup ? _subTasksOf(task) : const <PlanTaskDraft>[];
    final phase = _phases.where((p) => p.id == task.phaseId).firstOrNull;

    final start = d?.start ?? _day(_windowStartDate);
    final pushedFrom = task.startDate;
    final pushed = !isGroup && pushedFrom != null && start.isAfter(_day(pushedFrom));

    final title = Padding(
      padding: EdgeInsets.only(left: isSub ? 28 : 0, right: 8),
      child: Row(
        children: [
          if (isGroup)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                key: Key('wizard_toggle_${task.id}'),
                tooltip: _collapsed.contains(task.id) ? 'Show sub-tasks' : 'Fold sub-tasks',
                style: _tinyIcon(28),
                icon: Icon(_collapsed.contains(task.id) ? Icons.chevron_right_rounded : Icons.expand_more_rounded, size: 20, color: crm.textSecondary),
                onPressed: () => _toggleFold(task.id),
              ),
            )
          else
            const SizedBox(width: 28),
          Icon(isGroup ? Icons.folder_outlined : Icons.description_outlined, size: 18, color: isGroup ? crm.primary : crm.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: task.title,
                  style: TextStyle(fontSize: 13.5, fontWeight: isSub ? FontWeight.w500 : FontWeight.w700, color: crm.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: isSub ? 'Sub-task title' : 'Deliverable Title',
                    contentPadding: const EdgeInsets.symmetric(vertical: 7),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: crm.primary, width: 1.5)),
                  ),
                  onChanged: (val) => task.title = val,
                ),
                if (isGroup)
                  Text(
                    '${subs.length} task${subs.length == 1 ? '' : 's'}',
                    key: Key('wizard_group_count_${task.id}'),
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _priorityPill(crm, task),
        ],
      ),
    );

    return Container(
      key: ValueKey('task_${task.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: selected ? crm.primary.withValues(alpha: 0.06) : (isSub ? crm.background.withValues(alpha: 0.5) : crm.surface),
        border: Border(top: BorderSide(color: crm.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _cCheck,
                child: Center(
                  child: Checkbox(
                    key: Key('wizard_select_${task.id}'),
                    value: selected,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (_) => _toggleSelected(task.id),
                  ),
                ),
              ),
              Expanded(child: title),
              SizedBox(
                width: _cPhase,
                child: Padding(padding: const EdgeInsets.only(right: 8), child: isSub ? _phaseLabelPill(phase, crm) : _phasePicker(crm, task)),
              ),
              SizedBox(width: _cDur, child: isGroup ? _spanCell(crm, task, d) : _durationCell(crm, task)),
              SizedBox(
                width: _cAssignee,
                child: _assigneeCell(crm, task, employees),
              ),
              SizedBox(
                width: _cDate,
                child: Padding(padding: const EdgeInsets.only(right: 6), child: isGroup ? _groupDateCell(crm, task, d, end: false) : _dateCell(crm, task, sched, end: false)),
              ),
              SizedBox(
                width: _cDate,
                child: Padding(padding: const EdgeInsets.only(right: 6), child: isGroup ? _groupDateCell(crm, task, d, end: true) : _dateCell(crm, task, sched, end: true)),
              ),
              if (_canCost)
                SizedBox(
                  width: _cCost,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: isGroup
                        ? Text(
                            'Cost ${rupees(subs.fold<double>(0, (sum, c) => sum + c.plannedCost))} from its sub-tasks',
                            key: Key('wizard_cost_group_${task.id}'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
                          )
                        : _costChip(crm, task),
                  ),
                ),
              SizedBox(width: _cMenu, child: Center(child: _actionsMenu(crm, task, isSub, isGroup))),
            ],
          ),
          if (pushed)
            Padding(
              padding: EdgeInsets.only(left: _cCheck + (isSub ? 28 : 0) + 36, top: 4),
              child: Row(
                key: Key('wizard_pushed_${task.id}'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                  const SizedBox(width: 4),
                  Text(
                    'Waits for an earlier task — starts ${_chipDate.format(start)}, not ${_chipDate.format(_day(pushedFrom))}.',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── the timeline strip: Start / End date and time of day ──

  static final _chipDate = DateFormat('MMM dd, yyyy');

  /// A button that shows one date or time: filled when the planner fixed it, plain (and marked "auto") when the plan chose it.
  Widget _whenChip(
    CrmTheme crm, {
    required Key chipKey,
    required IconData icon,
    required String text,
    required bool fixed,
    required VoidCallback onTap,
    VoidCallback? onClear,
    Key? clearKey,
    bool warn = false,
  }) {
    const amber = Color(0xFFB45309);
    final color = warn ? amber : (fixed ? crm.primary : crm.textSecondary);
    return Material(
      color: warn ? amber.withValues(alpha: 0.08) : (fixed ? crm.primary.withValues(alpha: 0.07) : crm.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: warn ? amber.withValues(alpha: 0.6) : (fixed ? crm.primary.withValues(alpha: 0.5) : crm.border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: InkWell(
            key: chipKey,
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(9, 6, onClear == null ? 10 : 4, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: fixed ? FontWeight.w700 : FontWeight.w500,
                      color: fixed ? crm.textPrimary : crm.textSecondary,
                    ),
                  ),
                  ),
                  if (!fixed && icon == Icons.calendar_today_outlined) ...[
                    const SizedBox(width: 5),
                    Text(
                      'auto',
                      style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: crm.textSecondary.withValues(alpha: 0.7)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ),
          if (onClear != null)
            InkWell(
              key: clearKey,
              borderRadius: BorderRadius.circular(8),
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 6, 7, 6),
                child: Icon(Icons.close, size: 13, color: crm.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 4: DEPENDENCIES & GANTT AUTO-SCHEDULE
  // -------------------------------------------------------------
  Widget _buildStep4GanttPreview(CrmTheme crm) {
    final sched = _calculateGantt();
    final stamps = _stamps(sched);
    final fmt = DateFormat('MMM dd, yyyy');
    // "Nov 05, 2026" — and ", 10:00 AM" after it when the planner gave that end a time of day
    String when(DateTime d, bool timed) => timed ? '${fmt.format(d)}, ${TimeOfDay.fromDateTime(d).format(context)}' : fmt.format(d);
    final rows = _orderedTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dependencies & Gratt Auto-Schedule',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Link predecessor dependencies. The scheduling engine auto-computes dates, durations & critical paths.',
                    style: TextStyle(fontSize: 13, color: crm.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // KPI Summary Ribbon
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: crm.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: crm.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildKpiItem(crm, 'Total Duration', '${sched.totalDays} Days', Icons.timer_outlined, crm.primary),
                const SizedBox(width: 20),
                _buildKpiItem(
                  crm,
                  'Planned Window',
                  '${fmt.format(sched.start)} → ${fmt.format(sched.end)}',
                  Icons.date_range_outlined,
                  const Color(0xFF0EA5E9),
                ),
                const SizedBox(width: 20),
                _buildKpiItem(crm, 'Critical Path', '${sched.criticalLeafCount} tasks', Icons.alt_route_rounded, const Color(0xFFEF4444)),
                const SizedBox(width: 20),
                _buildKpiItem(crm, 'Total Tasks', '${_tasks.length}', Icons.check_circle_outline, const Color(0xFF10B981)),
                if (_canCost && _costSummary().newTotal > 0) ...[
                  const SizedBox(width: 20),
                  _buildKpiItem(crm, 'Planned Cost', rupees(_costSummary().newTotal), Icons.payments_outlined, const Color(0xFFB45309)),
                ],
              ],
            ),
          ),
        ),

        if (sched.hasCycle) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sched.cycleError ?? 'Circular dependency loop detected. Please resolve loops between tasks.',
                        style: const TextStyle(fontSize: 12.5, color: Colors.deepOrange, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'A task cannot depend on another task that depends on it. Remove circular links or click Reset to restore sequential order.',
                        style: TextStyle(fontSize: 11.5, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.deepOrange,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.amber),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () {
                    setState(() {
                      // tasks follow each other in the order they read; sub-tasks follow the one before them in their own task
                      PlanTaskDraft? previousTask;
                      for (final t in _tasks) {
                        t.predecessorIds.clear();
                      }
                      for (final t in _orderedTasks) {
                        if (t.parentId == null) {
                          if (previousTask != null) t.predecessorIds.add(previousTask.id);
                          previousTask = t;
                        } else {
                          final sibs = _subTasksOf(_tasks.firstWhere((p) => p.id == t.parentId));
                          final at = sibs.indexOf(t);
                          if (at > 0) t.predecessorIds.add(sibs[at - 1].id);
                        }
                      }
                    });
                  },
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('Reset to Sequence', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Live Table of Tasks with Predecessors & Calculated Dates
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final task = rows[i];
              final isSub = task.parentId != null;
              final isGroup = _isGroup(task);
              final dates = sched.dates[task.id];
              final isCritical = sched.critical.contains(task.id);
              final candidates = {for (final id in eligiblePredecessorIds(_draftTasks, task.id)) id};
              final eligibleCandidates = _orderedTasks.where((c) => candidates.contains(c.id)).toList();
              final days = dates == null ? task.durationDays : dates.end.difference(dates.start).inDays;
              final stamp = stamps[task.id];
              final sameDay = task.isSameDay && !isGroup && !task.isMilestone;

              return Container(
                key: ValueKey('dep_${task.id}'),
                margin: EdgeInsets.only(left: isSub ? 36 : 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCritical ? const Color(0xFFEF4444).withValues(alpha: 0.04) : crm.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isCritical ? const Color(0xFFEF4444).withValues(alpha: 0.4) : crm.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Phase Tag
                        if (isSub) ...[
                          Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: crm.textSecondary),
                          const SizedBox(width: 6),
                        ] else ...[
                          _buildPhaseBadge(task.phaseId),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            _label(task),
                            style: TextStyle(
                              fontSize: isSub ? 13 : 13.5,
                              fontWeight: isSub ? FontWeight.w600 : FontWeight.w700,
                              fontStyle: task.title.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                              color: task.title.trim().isEmpty ? crm.textSecondary : crm.textPrimary,
                            ),
                          ),
                        ),
                        if (isGroup)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'Summary',
                              style: TextStyle(fontSize: 10, color: crm.primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (task.isMilestone)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: const Text(
                              'Milestone',
                              style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (isCritical)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 7, color: Color(0xFFEF4444)),
                                SizedBox(width: 4),
                                Text(
                                  'Critical Path',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                                ),
                              ],
                            ),
                          )
                        else
                          Text('Float: ${sched.float[task.id] ?? 0}d', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Auto-calculated Dates & Predecessors row
                    Row(
                      children: [
                        // Scheduled date range pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: crm.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: crm.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_outlined, size: 14, color: crm.primary),
                              const SizedBox(width: 6),
                              Text(
                                key: Key('wizard_range_${task.id}'),
                                dates == null || stamp == null
                                    ? '${task.durationDays} days'
                                    : '${when(stamp.start, stamp.startTimed)} → ${when(stamp.end, stamp.endTimed)} (${sameDay ? 'same day' : '${days}d'})',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Predecessor link trigger
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Depends on:',
                                style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w600),
                              ),
                              if (task.predecessorIds.isEmpty)
                                Text('None (Starts with project)', style: TextStyle(fontSize: 11, color: crm.textSecondary.withValues(alpha: 0.6)))
                              else
                                ...task.predecessorIds.map((pid) {
                                  final pred = _tasks.firstWhere(
                                    (t) => t.id == pid,
                                    orElse: () => PlanTaskDraft(id: pid, phaseId: '', title: 'Task $pid'),
                                  );
                                  return Chip(
                                    label: Text(_label(pred), style: const TextStyle(fontSize: 10.5)),
                                    onDeleted: () {
                                      setState(() {
                                        task.predecessorIds.remove(pid);
                                      });
                                    },
                                    visualDensity: VisualDensity.compact,
                                  );
                                }),
                              // Add predecessor button menu
                              if (eligibleCandidates.isEmpty)
                                Tooltip(
                                  message: 'No eligible predecessors (downstream tasks excluded to prevent loops)',
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(Icons.link_off_rounded, size: 18, color: crm.textSecondary.withValues(alpha: 0.4)),
                                  ),
                                )
                              else
                                PopupMenuButton<String>(
                                  tooltip: 'Add dependency',
                                  icon: Icon(Icons.add_link_rounded, size: 18, color: crm.primary),
                                  onSelected: (predId) {
                                    setState(() {
                                      if (!task.predecessorIds.contains(predId) && !draftWouldCycle(_draftTasks, task.id, predId)) {
                                        task.predecessorIds.add(predId);
                                      }
                                    });
                                  },
                                  itemBuilder: (ctx) => eligibleCandidates
                                      .map(
                                        (c) => PopupMenuItem(
                                          value: c.id,
                                          child: Text(c.parentId == null ? _label(c) : '    ${_label(c)}', style: const TextStyle(fontSize: 12)),
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseBadge(String phaseId) {
    final phase = _phases.firstWhere(
      (p) => p.id == phaseId,
      orElse: () => PlanPhaseDraft(id: phaseId, name: 'General'),
    );
    final label = phase.name.trim().isEmpty ? 'Untitled phase' : phase.name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: phase.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: phase.color),
      ),
    );
  }

  Widget _buildKpiItem(CrmTheme crm, String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
            Text(
              value,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // FOOTER NAVIGATION
  // -------------------------------------------------------------
  Widget _buildFooter(CrmTheme crm) {
    // where the next button goes
    const nextLabels = ['Next: Phases & WBS', 'Next: Tasks & Team', 'Next: Dependencies & Gratt'];
    final outlined = OutlinedButton.styleFrom(
      foregroundColor: crm.textPrimary,
      side: BorderSide(color: crm.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              key: const Key('wizard_back'),
              onPressed: _busy ? null : () => setState(() => _currentStep--),
              style: outlined,
              child: const Text('Back'),
            )
          else
            OutlinedButton(key: const Key('wizard_cancel'), onPressed: _busy ? null : () => Navigator.of(context).pop(), style: outlined, child: const Text('Cancel')),
          Row(
            children: [
              if (_currentStep > 0) ...[
                TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 12),
              ],
              if (_currentStep < 3)
                FilledButton(
                  key: const Key('wizard_next'),
                  onPressed: _busy ? null : () => setState(() => _currentStep++),
                  style: FilledButton.styleFrom(
                    backgroundColor: crm.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nextLabels[_currentStep], style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final hasCycle = _currentStep == 3 && _calculateGantt().hasCycle;
                    return FilledButton.icon(
                      key: const Key('wizard_generate'),
                      onPressed: (_busy || hasCycle) ? null : _saveAndGeneratePlan,
                      style: FilledButton.styleFrom(
                        backgroundColor: hasCycle ? Colors.grey : const Color(0xFF059669),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      ),
                      icon: _busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        _busy ? 'Generating Plan…' : (hasCycle ? 'Resolve Loops to Generate' : 'Generate Gratt Plan'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
