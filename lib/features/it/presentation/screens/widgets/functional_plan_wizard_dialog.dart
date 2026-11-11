import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/error_message.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/features/it/domain/plan_drafts.dart';
import 'package:nizan_crm/features/it/domain/models/it_project_model.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
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
    );
  }
}

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
    if (_tasks.isEmpty) return (message: 'Please add at least one task before generating the Gantt plan.', step: 2);
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

  List<PlanTaskDraft> get _orderedTasks => [
    for (final ph in _phases)
      for (final t in _tasks.where((t) => t.phaseId == ph.id && t.parentId == null)) ...[t, ..._subTasksOf(t)],
    // anything under a phase that is gone still shows up, so nothing is lost
    ..._tasks.where((t) => !_phases.any((p) => p.id == t.phaseId)),
  ];

  /// Takes [ids] out of the plan, and out of everything that waited for them.
  void _removeTasks(Set<String> ids) {
    _tasks.removeWhere((t) => ids.contains(t.id));
    for (final t in _tasks) {
      t.predecessorIds.removeWhere(ids.contains);
    }
  }

  Set<String> _withSubTasks(String id) => {id, ..._tasks.where((t) => t.parentId == id).map((t) => t.id)};

  void _addSubTask(PlanTaskDraft parent) {
    final siblings = _subTasksOf(parent);
    final first = siblings.isEmpty;
    setState(() {
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

      if (mounted) {
        Navigator.of(context).pop();
        widget.onPlanCreated?.call();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Text(
              '✅ Added ${phaseTaskIdMap.length} phase${phaseTaskIdMap.length == 1 ? '' : 's'} and $created task${created == 1 ? '' : 's'} to the plan!',
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
    final dialogWidth = math.min(920.0, size.width * 0.92);
    final dialogHeight = math.min(740.0, size.height * 0.88);

    return Dialog(
      backgroundColor: crm.surface,
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
              child: Padding(padding: const EdgeInsets.all(24), child: _buildCurrentStepContent(crm)),
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
            child: Icon(Icons.auto_graph_rounded, color: crm.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Functional Plan & Gantt Auto-Scheduler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Define department scope, phases, deliverables, and auto-sequence the interactive Gantt chart.',
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
    final steps = ['1. Scope & Lead', '2. Phases & WBS', '3. Tasks & Team', '4. Dependencies & Gantt'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: crm.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              return Container(
                width: 32,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: (index ~/ 2 < _currentStep) ? crm.primary : crm.border,
              );
            }
            final stepIdx = index ~/ 2;
            final isActive = stepIdx == _currentStep;
            final isPast = stepIdx < _currentStep;

            return InkWell(
              onTap: _busy ? null : () => setState(() => _currentStep = stepIdx),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isPast ? const Color(0xFF10B981) : (isActive ? crm.primary : crm.border),
                      child: isPast
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text(
                              '${stepIdx + 1}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? Colors.white : crm.textSecondary),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      steps[stepIdx],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? crm.textPrimary : crm.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Function Overview',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Specify which functional department is leading this delivery window and the core milestone objectives.',
            style: TextStyle(fontSize: 13, color: crm.textSecondary),
          ),
          if (_hasExistingPlan) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('wizard_existing_note'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: crm.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Department',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    if (_departments.length == 1)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: crm.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: crm.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.business_center_outlined, size: 18, color: crm.primary),
                            const SizedBox(width: 8),
                            Text(
                              _departmentName,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                'Project Owner',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.primary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _departments.contains(_departmentName) ? _departmentName : _departments.first,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: crm.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: _departments
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text(d, style: const TextStyle(fontSize: 13)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _departmentName = v);
                        },
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _departments.length == 1
                          ? 'This project belongs to $_departmentName. To involve other departments, invite them in Project Settings.'
                          : 'Active participating departments on this project.',
                      style: TextStyle(fontSize: 11, color: crm.textSecondary.withValues(alpha: 0.8)),
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
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Functional Lead / Head',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _leadController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Head of Operations / Team Lead',
                        filled: true,
                        fillColor: crm.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Window Start Date',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _windowStartDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _windowStartDate = picked);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: crm.border),
                          borderRadius: BorderRadius.circular(8),
                          color: crm.surface,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 18, color: crm.primary),
                            const SizedBox(width: 10),
                            Text(DateFormat.yMMMd().format(_windowStartDate), style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Text(
                    'You build the plan yourself in the next steps: add its phases, then the tasks (and sub-tasks) in each. Tasks are dated from this day, along their dependencies.',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Key Deliverable / Objective Statement',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _objectiveController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Briefly describe what this functional plan aims to accomplish and its expected outcome...',
              filled: true,
              fillColor: crm.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
  // STEP 3: TASKS & OWNERSHIP
  // -------------------------------------------------------------
  Widget _buildStep3Tasks(CrmTheme crm) {
    final employees = ref.watch(projectEmployeesProvider(widget.projectId));
    final rows = _orderedTasks;
    final sched = _calculateGantt(); // shows each task's date as it stands, so a picked date can be compared with it

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
                    'Tasks & Ownership',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add deliverables under each phase with duration (days) and assignees. Pick a start and end date, and a time of day, to fix a task on the timeline; '
                    'otherwise the plan places it. A task that needs steps of its own gets sub-tasks.',
                    style: TextStyle(fontSize: 13, color: crm.textSecondary),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: crm.primary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              // a task belongs to a phase, so there has to be one; it starts in the phase of the last task added
              onPressed: _phases.isEmpty
                  ? null
                  : () {
                      final last = _tasks.where((t) => t.parentId == null).lastOrNull;
                      final phase = _phases.where((p) => p.id == last?.phaseId).firstOrNull ?? _phases.first;
                      setState(() {
                        _tasks.add(PlanTaskDraft(id: _generateId('tsk'), phaseId: phase.id, title: '', durationDays: 3));
                      });
                    },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Task', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    _phases.isEmpty ? 'Add a phase first (step 2), then add its tasks here.' : 'No tasks yet. Add one under a phase.',
                    style: TextStyle(color: crm.textSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _taskRow(crm, rows[i], employees, sched),
                ),
        ),
      ],
    );
  }

  Widget _taskRow(CrmTheme crm, PlanTaskDraft task, List<dynamic> employees, DraftSchedule sched) {
    final isSub = task.parentId != null;
    final isGroup = _isGroup(task);

    final duration = SizedBox(
      width: 80,
      child: isGroup
          ? Tooltip(
              message: 'Its length is the span of its sub-tasks',
              child: Container(
                key: Key('wizard_span_${task.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: crm.border),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'from sub-tasks',
                    style: TextStyle(fontSize: 10.5, color: crm.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            )
          : TextFormField(
              key: Key('wizard_dur_${task.id}_${task.rev}'),
              initialValue: task.durationDays.toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                suffixText: 'd',
                labelText: 'Dur',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
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
    );

    final priority = SizedBox(
      width: 90,
      child: DropdownButtonFormField<ITSeverity>(
        initialValue: task.severity,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
        items: ITSeverity.values
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s.shortLabel,
                  style: TextStyle(fontSize: 12, color: s.color, fontWeight: FontWeight.w700),
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => task.severity = v);
        },
      ),
    );

    final assignee = SizedBox(
      width: 130,
      child: EmployeePickerField(
        employees: employees.cast(),
        selectedId: task.assigneeId,
        selectedName: task.assigneeName,
        label: 'Assignee',
        allowUnassign: true,
        onChanged: (emp) {
          setState(() {
            task.assigneeId = emp?.id;
            task.assigneeName = emp?.name;
          });
        },
      ),
    );

    final milestone = Tooltip(
      message: isGroup ? 'A task with sub-tasks cannot be a milestone' : 'Milestone Gate (Zero Duration)',
      child: IconButton(
        icon: Icon(
          task.isMilestone ? Icons.flag_rounded : Icons.outlined_flag_rounded,
          size: 20,
          color: task.isMilestone ? const Color(0xFFF59E0B) : crm.textSecondary,
        ),
        onPressed: isGroup
            ? null
            : () => setState(() {
                task.isMilestone = !task.isMilestone;
                if (task.isMilestone) {
                  task.endDate = null;
                  task.endTime = null;
                }
              }),
      ),
    );

    final remove = IconButton(
      key: Key('wizard_remove_${task.id}'),
      icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
      tooltip: isSub ? 'Remove sub-task' : (isGroup ? 'Remove task and its sub-tasks' : 'Remove'),
      onPressed: () => setState(() => _removeTasks(_withSubTasks(task.id))),
    );

    return Container(
      key: ValueKey('task_${task.id}'),
      margin: EdgeInsets.only(left: isSub ? 36 : 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSub ? crm.surface : crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _taskFields(crm, task, isSub, isGroup, duration, priority, assignee, milestone, remove),
          const SizedBox(height: 10),
          _timelineStrip(crm, task, sched),
        ],
      ),
    );
  }

  /// The first line of a task: phase, title, length, priority, assignee and the little actions.
  Widget _taskFields(
    CrmTheme crm,
    PlanTaskDraft task,
    bool isSub,
    bool isGroup,
    Widget duration,
    Widget priority,
    Widget assignee,
    Widget milestone,
    Widget remove,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isSub) ...[
          Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: crm.textSecondary),
          const SizedBox(width: 8),
        ] else ...[
          // Phase selector
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<String>(
              initialValue: _phases.any((p) => p.id == task.phaseId) ? task.phaseId : (_phases.isNotEmpty ? _phases.first.id : null),
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              items: _phases
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(_phaseLabel(p), style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  task.phaseId = v;
                  for (final sub in _subTasksOf(task)) {
                    sub.phaseId = v; // its sub-tasks go where it goes
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 10),
        ],
        // Task title
        Expanded(
          flex: 3,
          child: TextFormField(
            initialValue: task.title,
            style: TextStyle(fontSize: isSub ? 12.5 : 13, fontWeight: isSub ? FontWeight.w500 : FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              hintText: isSub ? 'Sub-task title' : 'Deliverable Title',
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (val) => task.title = val,
          ),
        ),
        const SizedBox(width: 10),
        duration,
        const SizedBox(width: 10),
        priority,
        const SizedBox(width: 10),
        assignee,
        PopupMenuButton<String>(
          key: Key('wizard_task_move_${task.id}'),
          tooltip: 'Move',
          padding: EdgeInsets.zero,
          icon: Icon(Icons.swap_vert_rounded, size: 20, color: crm.textSecondary),
          onSelected: (v) => _moveTask(task, v == 'up' ? -1 : 1),
          itemBuilder: (_) => [
            PopupMenuItem(key: const Key('wizard_move_up'), value: 'up', enabled: _canMoveTask(task, -1), child: const Text('Move up')),
            PopupMenuItem(key: const Key('wizard_move_down'), value: 'down', enabled: _canMoveTask(task, 1), child: const Text('Move down')),
          ],
        ),
        milestone,
        if (!isSub)
          IconButton(
            key: Key('wizard_add_sub_${task.id}'),
            icon: Icon(Icons.account_tree_outlined, size: 18, color: task.isMilestone ? crm.textSecondary.withValues(alpha: 0.4) : crm.primary),
            tooltip: task.isMilestone ? 'A milestone cannot have sub-tasks' : 'Add sub-task',
            onPressed: task.isMilestone ? null : () => _addSubTask(task),
          ),
        remove,
      ],
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
          InkWell(
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
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: fixed ? FontWeight.w700 : FontWeight.w500,
                      color: fixed ? crm.textPrimary : crm.textSecondary,
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

  Widget _timelineStrip(CrmTheme crm, PlanTaskDraft t, DraftSchedule sched) {
    final d = sched.dates[t.id];
    if (_isGroup(t)) {
      return Row(
        key: Key('wizard_group_range_${t.id}'),
        children: [
          Icon(Icons.event_outlined, size: 14, color: crm.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              d == null ? 'Its dates come from its sub-tasks.' : '${_chipDate.format(d.start)} → ${_chipDate.format(d.end)} · from its sub-tasks',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
            ),
          ),
        ],
      );
    }
    final start = d?.start ?? _day(_windowStartDate);
    final end = d?.end ?? start;
    final pushedFrom = t.startDate;
    final pushed = pushedFrom != null && start.isAfter(_day(pushedFrom));

    Widget label(String text) => Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary, letterSpacing: 0.3),
    );
    Widget timeChip({required bool end}) {
      final value = end ? t.endTime : t.startTime;
      return _whenChip(
        crm,
        chipKey: Key('wizard_${end ? 'end' : 'start'}_time_${t.id}'),
        icon: Icons.schedule_rounded,
        text: value == null ? 'Add time' : value.format(context),
        fixed: value != null,
        onTap: () => _pickTime(t, end: end),
        onClear: value == null ? null : () => setState(() => end ? t.endTime = null : t.startTime = null),
        clearKey: Key('wizard_${end ? 'end' : 'start'}_time_clear_${t.id}'),
      );
    }

    // a start the plan had to move (an earlier task is not done by then) shows the day it really starts, in amber; the end
    // that was picked no longer holds either, so it is shown as the plan's
    Widget dateChip({required bool end, required DateTime shown}) => _whenChip(
      crm,
      chipKey: Key('wizard_${end ? 'end' : 'start'}_date_${t.id}'),
      icon: Icons.calendar_today_outlined,
      text: _chipDate.format(shown),
      fixed: end ? (t.endDate != null && !pushed) : t.startDate != null,
      warn: !end && pushed,
      onTap: () => _pickDate(t, sched, end: end),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.event_outlined, size: 15, color: crm.textSecondary),
        label(t.isMilestone ? 'ON' : 'START'),
        dateChip(end: false, shown: start),
        timeChip(end: false),
        if (!t.isMilestone) ...[
          Icon(Icons.arrow_forward_rounded, size: 15, color: crm.textSecondary),
          label('END'),
          dateChip(end: true, shown: end),
          timeChip(end: true),
        ],
        if (t.startDate != null)
          TextButton.icon(
            key: Key('wizard_clear_dates_${t.id}'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 30),
              foregroundColor: crm.textSecondary,
            ),
            onPressed: () => setState(() {
              t.startDate = null;
              t.endDate = null;
            }),
            icon: const Icon(Icons.restart_alt_rounded, size: 15),
            label: const Tooltip(
              message: 'Let the plan decide this task\'s dates',
              child: Text('Auto dates', style: TextStyle(fontSize: 11.5)),
            ),
          ),
        if (pushed)
          Row(
            key: Key('wizard_pushed_${t.id}'),
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
      ],
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
                    'Dependencies & Gantt Auto-Schedule',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: _busy ? null : () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          Row(
            children: [
              TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
              const SizedBox(width: 12),
              if (_currentStep < 3)
                FilledButton(
                  onPressed: _busy ? null : () => setState(() => _currentStep++),
                  style: FilledButton.styleFrom(
                    backgroundColor: crm.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final hasCycle = _currentStep == 3 && _calculateGantt().hasCycle;
                    return FilledButton.icon(
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
                        _busy ? 'Generating Plan…' : (hasCycle ? 'Resolve Loops to Generate' : 'Generate Gantt Plan'),
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
