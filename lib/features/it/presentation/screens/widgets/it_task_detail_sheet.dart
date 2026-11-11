import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/features/it/domain/markdown_edit.dart';
import 'package:nizan_crm/features/it/domain/task_rights.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

/// Opens a task: its details, subtasks, dependencies and discussion. A dialog on a desktop, a sheet on a phone.
Future<bool?> showITTaskDetailSheet(BuildContext context, WidgetRef ref, {required ITTaskModel task, required List<ITTaskModel> allTasks}) {
  final size = MediaQuery.of(context).size;
  final isDesktop = size.width > 800;

  if (isDesktop) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SizedBox(
          width: math.min(1120, size.width - 48),
          height: math.min(900, size.height * 0.92),
          child: _ITTaskDetailModal(task: task, allTasks: allTasks),
        ),
      ),
    );
  } else {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: size.height * 0.90,
        child: _ITTaskDetailModal(task: task, allTasks: allTasks),
      ),
    );
  }
}

/// The details tab puts "Basic Information" beside the overview + blockers from this width of the dialog.
const double _twoColumnsAt = 760;

class _ITTaskDetailModal extends ConsumerStatefulWidget {
  final ITTaskModel task;
  final List<ITTaskModel> allTasks;

  const _ITTaskDetailModal({required this.task, required this.allTasks});

  @override
  ConsumerState<_ITTaskDetailModal> createState() => _ITTaskDetailModalState();
}

class _ITTaskDetailModalState extends ConsumerState<_ITTaskDetailModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _subtaskInputController;
  late TextEditingController _commentInputController;
  late TextEditingController _estHoursController;
  late TextEditingController _actHoursController;

  late ITTicketType _type;
  late ITSeverity _severity;
  late ITSubTeam _subTeam;
  late ITTaskStatus _status;
  late String _assigneeId;
  late String _assigneeName;
  late DateTime? _startDate;
  late DateTime? _dueDate;
  late int _percentComplete;
  late List<String> _predecessorIds;

  /// Where this task sits in the work breakdown ("1", "2.3"), when it is in the list we were given.
  String? _wbsNumber;

  bool _previewDesc = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description);
    _subtaskInputController = TextEditingController();
    _commentInputController = TextEditingController();
    _estHoursController = TextEditingController(text: widget.task.estimatedHours > 0 ? widget.task.estimatedHours.toStringAsFixed(1) : '');
    _actHoursController = TextEditingController(text: widget.task.actualHours > 0 ? widget.task.actualHours.toStringAsFixed(1) : '');

    _type = widget.task.ticketType;
    _severity = widget.task.severity;
    _subTeam = widget.task.subTeam;
    _status = widget.task.status;
    _assigneeId = widget.task.assigneeId;
    _assigneeName = widget.task.assigneeName;
    _startDate = widget.task.startDate;
    _dueDate = widget.task.dueDate;
    _percentComplete = widget.task.percentComplete;
    _predecessorIds = List.from(widget.task.predecessorIds);

    _wbsNumber = flattenWbs(buildWbsForest(widget.allTasks)).where((n) => n.task.id == widget.task.id).firstOrNull?.wbs;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _subtaskInputController.dispose();
    _commentInputController.dispose();
    _estHoursController.dispose();
    _actHoursController.dispose();
    super.dispose();
  }

  /// The task as currently held by the controller the sheet mutates through,
  /// so subtasks / comments added here show up immediately (the `widget.task`
  /// snapshot passed in never changes). Falls back to the snapshot.
  ITTaskModel _liveTask() {
    final pid = widget.task.projectId;
    final AsyncValue<List<ITTaskModel>> tasks = pid.isNotEmpty
        ? ref.watch(itProjectTasksControllerProvider(pid))
        : ref.watch(itAllTasksControllerProvider);
    return tasks.value?.where((t) => t.id == widget.task.id).firstOrNull ?? widget.task;
  }

  /// What the signed-in person may do to this ticket (the server applies the same rules).
  TaskRights get _rights =>
      taskRightsFor(ref.read(projectByIdProvider(widget.task.projectId)), widget.task, myEmployeeId: ref.read(authSessionProvider)?.employeeId ?? '');

  /// Greys out and disables a control the person may not change.
  Widget _lockPlan(Widget w) => _rights.plan ? w : IgnorePointer(child: Opacity(opacity: 0.55, child: w));
  Widget _lockProgress(Widget w) => _rights.progress ? w : IgnorePointer(child: Opacity(opacity: 0.55, child: w));

  /// A predecessor that is not finished and ends after this task is meant to start.
  bool _isBlocking(ITTaskModel pred) => !pred.isCompleted && _startDate != null && pred.dueDate != null && pred.dueDate!.isAfter(_startDate!);

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final notifier = getITTasksNotifier(ref, widget.task.projectId);

      if (_status == ITTaskStatus.closed || _status == ITTaskStatus.deployed) {
        _percentComplete = 100;
      } else if (_percentComplete >= 100) {
        _status = _isItProject ? ITTaskStatus.deployed : ITTaskStatus.closed;
      }

      // Someone who only reports progress sends only progress.
      final updates = _rights.progressOnly
          ? <String, dynamic>{
              'status': _status.slug,
              'actualHours': double.tryParse(_actHoursController.text.trim()) ?? 0,
              'percentComplete': _percentComplete,
            }
          : <String, dynamic>{
              'title': _titleController.text.trim(),
              'description': _descController.text.trim(),
              'ticketType': _type.slug,
              'category': _type.slug,
              'severity': _severity.slug,
              'priority': _severity.slug,
              'subTeam': _subTeam.slug,
              'status': _status.slug,
              'assignedTo': _assigneeId.isNotEmpty ? _assigneeId : null,
              'startDate': _startDate?.toIso8601String(),
              'deadline': _dueDate?.toIso8601String(),
              'dueDate': _dueDate?.toIso8601String(),
              'estimatedHours': double.tryParse(_estHoursController.text.trim()) ?? 0,
              'actualHours': double.tryParse(_actHoursController.text.trim()) ?? 0,
              'percentComplete': _percentComplete,
              'predecessorIds': _predecessorIds,
            };

      await notifier.updateTaskField(widget.task.id, updates);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  bool get _isItProject {
    final project = ref.read(projectByIdProvider(widget.task.projectId));
    return (project?.targetDepartment ?? 'it').toLowerCase().trim() == 'it';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    final live = _liveTask();

    final blockers = <ITTaskModel>[
      for (final pid in _predecessorIds)
        if (widget.allTasks.where((t) => t.id == pid).firstOrNull case final ITTaskModel pred when _isBlocking(pred)) pred,
    ];

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 28, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 14),
        child: Scaffold(
          backgroundColor: crm.surface,
          body: Column(
            children: [
              _buildTopBar(crm),
              if (blockers.isNotEmpty) _buildBlockerBanner(crm, blockers),
              _buildTabBar(crm, live),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildDetailsTab(crm), _buildSubtasksTab(crm, live), _buildDependenciesTab(crm), _buildActivityTab(crm, live)],
                ),
              ),
              _buildBottomActionBar(crm),
            ],
          ),
        ),
      ),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────

  Widget _chip({required IconData? icon, required String label, required Color color, Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 6)],
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    ),
  );

  Widget _iconTile(CrmTheme crm, IconData icon, double size, {bool circle = false}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: crm.primary.withValues(alpha: 0.09),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, size: size * 0.5, color: crm.primary),
  );

  /// "P2 · Medium" — the severity's short name and its words.
  String get _priorityChipText => '${_severity.shortLabel} · ${_severity.label.replaceAll(RegExp(r'^P\d\s*-\s*'), '')}';

  /// The first line of the description, without Markdown marks: what the task is for, under its title.
  String _subtitleOf(String description) {
    final first = description.trim().split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    return first.replaceAll(RegExp(r'[*_`#>]'), '').replaceFirst(RegExp(r'^\s*(-|\d+[.)])\s+'), '').trim();
  }

  Widget _buildTopBar(CrmTheme crm) {
    final isItProject = _isItProject;
    final titleStyle = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.4, height: 1.15);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
      decoration: BoxDecoration(color: crm.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    isItProject
                        ? _chip(
                            key: const Key('task_key_chip'),
                            icon: _type.icon,
                            label: '${widget.task.ticketKey} • ${_type.label}',
                            color: _type.color,
                          )
                        : _chip(key: const Key('task_key_chip'), icon: Icons.task_alt, label: widget.task.ticketKey, color: crm.primary),
                    _chip(key: const Key('task_priority_chip'), icon: null, label: _priorityChipText, color: _severity.color),
                    if (RegExp(r'TKT-\d+-\d+').firstMatch(widget.task.description)?.group(0) case final String tktNum)
                      _chip(icon: Icons.confirmation_number_outlined, label: tktNum, color: Colors.purple),
                  ],
                ),
              ),
              IconButton(key: const Key('task_close'), icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), tooltip: 'Close'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconTile(crm, Icons.track_changes, 46, circle: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_wbsNumber != null) ...[
                          Text('$_wbsNumber.', key: const Key('task_wbs_number'), style: titleStyle),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: _lockPlan(
                            TextField(
                              key: const Key('task_title'),
                              controller: _titleController,
                              style: titleStyle,
                              minLines: 1,
                              maxLines: 3,
                              inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: isItProject ? 'Ticket summary...' : 'Task summary...',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ListenableBuilder(
                      listenable: _descController,
                      builder: (context, _) {
                        final sub = _subtitleOf(_descController.text);
                        if (sub.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            sub,
                            key: const Key('task_subtitle'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14.5, color: crm.textSecondary),
                          ),
                        );
                      },
                    ),
                    if (_rights.progressOnly)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'The project manager plans this ${isItProject ? 'ticket' : 'task'}. You can update its status, % complete and hours.',
                          style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                        ),
                      )
                    else if (_rights.readOnly)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'View only: you are not on this ${isItProject ? 'ticket' : 'task'}.',
                          style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockerBanner(CrmTheme crm, List<ITTaskModel> blockers) {
    return Container(
      key: const Key('task_blocker_banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dependency blocker detected',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.red.shade800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Blocked by: ${blockers.map((b) => "${b.ticketKey} (${b.title}) due ${b.dueDate != null ? DateFormat('MMM dd').format(b.dueDate!) : 'TBD'}").join(', ')}',
                  style: TextStyle(fontSize: 11.5, color: Colors.red.shade900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(CrmTheme crm, ITTaskModel live) {
    Tab tab(String key, IconData icon, String label) => Tab(
      key: Key('task_tab_$key'),
      height: 50,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final scrolls = box.maxWidth < 640;
        return Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: scrolls,
            tabAlignment: scrolls ? TabAlignment.start : TabAlignment.fill,
            dividerColor: Colors.transparent,
            labelColor: crm.primary,
            unselectedLabelColor: crm.textSecondary,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: crm.primary, width: 2.5)),
            ),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              tab('details', Icons.description_outlined, 'Details'),
              tab('subtasks', Icons.checklist_rounded, 'Subtasks (${live.subtasks.length})'),
              tab('dependencies', Icons.link_rounded, 'Dependencies (${_predecessorIds.length})'),
              tab('activity', Icons.chat_outlined, 'Activity & Comments'),
            ],
          ),
        );
      },
    );
  }

  // ── shared pieces ─────────────────────────────────────────────────────────

  Widget _card(CrmTheme crm, {required Widget child, Key? key}) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: crm.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: crm.border),
    ),
    child: child,
  );

  Widget _cardTitle(CrmTheme crm, String text, {IconData? icon, Widget? trailing}) => Row(
    children: [
      if (icon != null) ...[_iconTile(crm, icon, 38), const SizedBox(width: 12)],
      Expanded(
        child: Text(
          text,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: crm.textPrimary),
        ),
      ),
      ?trailing,
    ],
  );

  Widget _labeled(CrmTheme crm, String label, Widget field) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: crm.textPrimary),
      ),
      const SizedBox(height: 6),
      field,
    ],
  );

  InputDecoration _fieldDeco(CrmTheme crm, {String? hint, Widget? prefix, Widget? suffix}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: crm.surface,
      hintText: hint,
      hintStyle: TextStyle(color: crm.textSecondary.withValues(alpha: 0.7)),
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: border(crm.border.faded(2.5)),
      enabledBorder: border(crm.border.faded(2.5)),
      focusedBorder: border(crm.primary),
    );
  }

  Widget _row2(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 14),
      Expanded(child: b),
    ],
  );

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(
      text,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
    ),
  );

  // ── details ───────────────────────────────────────────────────────────────

  Widget _buildDetailsTab(CrmTheme crm) {
    return LayoutBuilder(
      builder: (context, box) {
        final two = box.maxWidth >= _twoColumnsAt;
        final basic = _basicInformation(crm);
        final overview = _taskOverview(crm);
        final deps = _dependenciesCard(crm);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: two
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 62, child: basic),
                    const SizedBox(width: 18),
                    Expanded(flex: 38, child: Column(children: [overview, const SizedBox(height: 16), deps])),
                  ],
                )
              : Column(children: [basic, const SizedBox(height: 16), overview, const SizedBox(height: 16), deps]),
        );
      },
    );
  }

  Widget _basicInformation(CrmTheme crm) {
    final employees = ref.watch(projectEmployeesProvider(widget.task.projectId));
    final isItProject = _isItProject;

    final status = _labeled(
      crm,
      'Status',
      _lockProgress(
        DropdownButtonFormField<ITTaskStatus>(
          key: const Key('task_status'),
          initialValue: _status,
          isExpanded: true,
          decoration: _fieldDeco(crm),
          items: isItProject
              ? [
                  for (final st in ITTaskStatus.values)
                    DropdownMenuItem(
                      value: st,
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: st.color),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(st.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
                          ),
                        ],
                      ),
                    ),
                ]
              : [
                  _statusItem(ITTaskStatus.backlog, 'Backlog'),
                  _statusItem(ITTaskStatus.todo, 'To Do'),
                  _statusItem(ITTaskStatus.inProgress, 'In Progress'),
                  _statusItem(ITTaskStatus.codeReview, 'In Review & Approval'),
                  if (_status == ITTaskStatus.qaTesting) _statusItem(ITTaskStatus.qaTesting, 'In Review & Approval (QA)'),
                  _statusItem(ITTaskStatus.deployed, 'Completed / Done'),
                  if (_status == ITTaskStatus.closed) _statusItem(ITTaskStatus.closed, 'Completed (Closed)'),
                ],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _status = v;
                if (v == ITTaskStatus.closed || v == ITTaskStatus.deployed) {
                  _percentComplete = 100;
                }
              });
            }
          },
        ),
      ),
    );

    final priority = _labeled(
      crm,
      isItProject ? 'Severity' : 'Priority',
      _lockPlan(
        DropdownButtonFormField<ITSeverity>(
          key: const Key('task_priority'),
          initialValue: _severity,
          isExpanded: true,
          decoration: _fieldDeco(crm).copyWith(fillColor: _severity.color.withValues(alpha: 0.07)),
          items: [
            for (final sv in ITSeverity.values)
              DropdownMenuItem(
                value: sv,
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 18, color: sv.color),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        isItProject ? sv.label : sv.label.replaceAll(RegExp(r'^P\d\s*-\s*'), ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, color: sv.color, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _severity = v);
          },
        ),
      ),
    );

    Widget hours(Key key, TextEditingController c, String hint, IconData icon, {required bool progress}) {
      final field = TextField(
        key: key,
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _fieldDeco(crm, hint: hint, prefix: Icon(icon, size: 19)),
      );
      return progress ? _lockProgress(field) : _lockPlan(field);
    }

    return _card(
      crm,
      key: const Key('task_basic_info'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: crm.textPrimary),
          ),
          const SizedBox(height: 14),
          _row2(status, priority),
          if (isItProject) ...[
            const SizedBox(height: 14),
            _row2(
              _labeled(
                crm,
                'IT Sub-Team',
                _lockPlan(
                  DropdownButtonFormField<ITSubTeam>(
                    key: const Key('task_subteam'),
                    initialValue: _subTeam,
                    isExpanded: true,
                    decoration: _fieldDeco(crm),
                    items: [
                      for (final tm in ITSubTeam.values)
                        DropdownMenuItem(
                          value: tm,
                          child: Row(
                            children: [
                              Icon(tm.icon, size: 17, color: tm.color),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(tm.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _subTeam = v);
                    },
                  ),
                ),
              ),
              _labeled(
                crm,
                'Ticket Type',
                _lockPlan(
                  DropdownButtonFormField<ITTicketType>(
                    key: const Key('task_type'),
                    initialValue: _type,
                    isExpanded: true,
                    decoration: _fieldDeco(crm),
                    items: [
                      for (final tt in ITTicketType.values)
                        DropdownMenuItem(
                          value: tt,
                          child: Row(
                            children: [
                              Icon(tt.icon, size: 17, color: tt.color),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(tt.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _labeled(
            crm,
            'Assignee',
            _lockPlan(
              KeyedSubtree(
                key: const Key('task_assignee'),
                child: EmployeePickerField(
                  employees: employees,
                  selectedId: _assigneeId.isNotEmpty ? _assigneeId : null,
                  selectedName: _assigneeName.isNotEmpty ? _assigneeName : null,
                  label: 'Assignee',
                  allowUnassign: true,
                  decorate: (base) => _fieldDeco(crm, prefix: base.prefixIcon, suffix: base.suffixIcon),
                  onChanged: (e) => setState(() {
                    _assigneeId = e?.id ?? '';
                    _assigneeName = e?.name ?? '';
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _row2(
            _dateField(crm, const Key('task_start'), 'Start Date', _startDate, (d) => setState(() => _startDate = d)),
            _dateField(crm, const Key('task_due'), 'Due Date', _dueDate, (d) => setState(() => _dueDate = d), fallback: _startDate),
          ),
          const SizedBox(height: 14),
          _row2(
            _labeled(crm, 'Estimated Hours', hours(const Key('task_est_hours'), _estHoursController, 'e.g. 40', Icons.schedule, progress: false)),
            _labeled(
              crm,
              'Actual Hours Spent',
              hours(const Key('task_actual_hours'), _actHoursController, 'e.g. 0', Icons.play_circle_outline, progress: true),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Progress',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary),
              ),
              const Spacer(),
              Text(
                '$_percentComplete%',
                key: const Key('task_progress_text'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.primary),
              ),
            ],
          ),
          _lockProgress(
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: crm.primary,
                inactiveTrackColor: crm.border.faded(2),
                thumbColor: crm.primary,
                overlayColor: crm.primary.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                tickMarkShape: SliderTickMarkShape.noTickMark,
              ),
              child: Slider(
                key: const Key('task_progress'),
                value: _percentComplete.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$_percentComplete%',
                onChanged: (v) {
                  setState(() {
                    _percentComplete = v.round();
                    if (_percentComplete >= 100) {
                      _status = _isItProject ? ITTaskStatus.deployed : ITTaskStatus.closed;
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Description & Acceptance Criteria',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: crm.textPrimary),
          ),
          const SizedBox(height: 10),
          _lockPlan(_descriptionEditor(crm)),
        ],
      ),
    );
  }

  DropdownMenuItem<ITTaskStatus> _statusItem(ITTaskStatus st, String text) => DropdownMenuItem(
    value: st,
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(shape: BoxShape.circle, color: st.color),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
        ),
      ],
    ),
  );

  Widget _dateField(CrmTheme crm, Key key, String label, DateTime? value, ValueChanged<DateTime> onPicked, {DateTime? fallback}) {
    return _labeled(
      crm,
      label,
      _lockPlan(
        InkWell(
          key: key,
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: value ?? fallback ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(primary: crm.primary, onPrimary: Colors.white, onSurface: crm.textPrimary, surface: crm.surface),
                ),
                child: child!,
              ),
            );
            if (d != null) onPicked(d);
          },
          child: InputDecorator(
            decoration: _fieldDeco(crm, prefix: const Icon(Icons.calendar_today_outlined, size: 18)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value == null ? 'Select date' : DateFormat('dd MMM yyyy').format(value),
                maxLines: 1,
                style: TextStyle(fontSize: 14.5, color: value == null ? crm.textSecondary : crm.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A small formatting toolbar (the description is stored as Markdown) over a text area, or the rendered text.
  Widget _descriptionEditor(CrmTheme crm) {
    void apply(TextEditingValue Function(TextEditingValue) edit) {
      setState(() => _descController.value = edit(_descController.value));
    }

    Widget tool(Key key, IconData icon, String tip, VoidCallback onTap) => IconButton(
      key: key,
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      iconSize: 19,
      color: crm.textPrimary,
      onPressed: _previewDesc ? null : onTap,
      icon: Icon(icon),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border.faded(2.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: crm.background,
              border: Border(bottom: BorderSide(color: crm.border)),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxWidth < 420;
                return Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            tool(
                              const Key('md_bold'),
                              Icons.format_bold,
                              'Bold',
                              () => apply((v) => wrapSelection(v, '**', '**', placeholder: 'bold text')),
                            ),
                            tool(
                              const Key('md_italic'),
                              Icons.format_italic,
                              'Italic',
                              () => apply((v) => wrapSelection(v, '*', '*', placeholder: 'italic text')),
                            ),
                            Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 4), color: crm.border),
                            tool(
                              const Key('md_bullets'),
                              Icons.format_list_bulleted,
                              'Bulleted list',
                              () => apply((v) => toggleList(v, ordered: false)),
                            ),
                            tool(
                              const Key('md_numbered'),
                              Icons.format_list_numbered,
                              'Numbered list',
                              () => apply((v) => toggleList(v, ordered: true)),
                            ),
                            tool(const Key('md_link'), Icons.link, 'Link', () => apply(insertLink)),
                          ],
                        ),
                      ),
                    ),
                    if (compact)
                      IconButton(
                        key: const Key('md_preview'),
                        tooltip: _previewDesc ? 'Edit' : 'Preview',
                        visualDensity: VisualDensity.compact,
                        color: crm.primary,
                        onPressed: () => setState(() => _previewDesc = !_previewDesc),
                        icon: Icon(_previewDesc ? Icons.edit_outlined : Icons.visibility_outlined, size: 19),
                      )
                    else
                      TextButton.icon(
                        key: const Key('md_preview'),
                        onPressed: () => setState(() => _previewDesc = !_previewDesc),
                        icon: Icon(_previewDesc ? Icons.edit_outlined : Icons.visibility_outlined, size: 17),
                        label: Text(_previewDesc ? 'Edit' : 'Preview'),
                        style: TextButton.styleFrom(foregroundColor: crm.primary, visualDensity: VisualDensity.compact),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_previewDesc)
            Container(
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(14),
              child: _descController.text.trim().isEmpty
                  ? Text(
                      'No description yet.',
                      style: TextStyle(color: crm.textSecondary, fontStyle: FontStyle.italic),
                    )
                  : MarkdownBody(
                      data: _descController.text,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(p: TextStyle(fontSize: 14, color: crm.textPrimary)),
                    ),
            )
          else
            TextField(
              key: const Key('task_description'),
              controller: _descController,
              minLines: 5,
              maxLines: 12,
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.all(14),
                hintText: 'Add detailed description, objectives and acceptance criteria...',
                hintStyle: TextStyle(color: crm.textSecondary.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _taskOverview(CrmTheme crm) {
    final project = ref.watch(projectByIdProvider(widget.task.projectId));
    final created = widget.task.createdAt;

    Widget row(IconData icon, String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 19, color: crm.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: crm.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
    Widget text(String v) => Text(
      v,
      textAlign: TextAlign.right,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: crm.textPrimary),
    );
    final divider = Divider(height: 1, color: crm.border.faded(0.8));

    return _card(
      crm,
      key: const Key('task_overview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(crm, 'Task Overview', icon: Icons.bar_chart_rounded),
          const SizedBox(height: 8),
          row(Icons.layers_outlined, 'Phase', project == null ? text('—') : _pill(cap(project.phase), crm.textSecondary)),
          divider,
          row(Icons.folder_outlined, 'Project', text(project?.name ?? widget.task.projectName.ifEmpty('—'))),
          divider,
          row(Icons.person_outline_rounded, 'Manager', text((project?.managerName ?? '').ifEmpty('—'))),
          divider,
          row(Icons.calendar_today_outlined, 'Created', text(created == null ? '—' : DateFormat('dd MMM yyyy, hh:mm a').format(created))),
          const SizedBox(height: 12),
          Container(
            key: const Key('task_completion'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _iconTile(crm, Icons.track_changes, 38, circle: true),
                const SizedBox(width: 12),
                Text(
                  'Completion',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
                const Spacer(),
                Text(
                  '$_percentComplete%',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dependenciesCard(CrmTheme crm) {
    return _card(
      crm,
      key: const Key('task_dependencies_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            crm,
            'Predecessor Dependencies (Blockers)',
            icon: Icons.link_rounded,
            trailing: Tooltip(
              message: 'This task cannot start until these are done. Their dates also move this one when you shift the plan.',
              child: Icon(Icons.info_outline, size: 19, color: crm.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          Text('Tasks that must be completed before this one can start.', style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
          if (_predecessorIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            _lockPlan(
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final pid in _predecessorIds)
                    Chip(
                      key: Key('blocker_chip_$pid'),
                      backgroundColor: crm.background,
                      side: BorderSide(color: crm.border),
                      label: Text(
                        widget.allTasks.where((t) => t.id == pid).map((t) => '${t.ticketKey} ${t.title}').firstOrNull ?? pid,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 15),
                      onDeleted: () => setState(() => _predecessorIds.remove(pid)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _lockPlan(_addDependencyButton(crm)),
        ],
      ),
    );
  }

  Widget _addDependencyButton(CrmTheme crm) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      key: const Key('add_dependency'),
      onPressed: () => _showAddDependencyDialog(crm, widget.allTasks.where((t) => t.id != widget.task.id).toList()),
      icon: const Icon(Icons.add, size: 19),
      label: const Text('Add Dependency', style: TextStyle(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: crm.primary,
        backgroundColor: crm.primary.withValues(alpha: 0.04),
        side: BorderSide(color: crm.primary.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );

  void _showAddDependencyDialog(CrmTheme crm, List<ITTaskModel> candidates) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Predecessor Task'),
        content: SizedBox(
          width: 400,
          child: candidates.isEmpty
              ? const Text('There are no other tasks in this project yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, idx) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = candidates[i];
                    final isSelected = _predecessorIds.contains(t.id);
                    return ListTile(
                      key: Key('dependency_option_${t.id}'),
                      title: Text('${t.ticketKey} • ${t.title}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Due: ${t.dueDate != null ? DateFormat('dd MMM').format(t.dueDate!) : 'No date'} • ${t.status.label}',
                        style: TextStyle(fontSize: 11, color: crm.textSecondary),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _predecessorIds.remove(t.id);
                          } else {
                            _predecessorIds.add(t.id);
                          }
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      ),
    );
  }

  // ── subtasks ──────────────────────────────────────────────────────────────

  Widget _buildSubtasksTab(CrmTheme crm, ITTaskModel live) {
    final subtasks = live.subtasks;
    final done = subtasks.where((s) => s.isCompleted).length;
    final notifier = getITTasksNotifier(ref, widget.task.projectId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: _card(
        crm,
        key: const Key('task_subtasks_card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              crm,
              'Checklist',
              icon: Icons.checklist_rounded,
              trailing: subtasks.isEmpty ? null : _pill('$done of ${subtasks.length} done', crm.primary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('subtask_input'),
                    controller: _subtaskInputController,
                    decoration: _fieldDeco(crm, hint: 'Add a checklist item (e.g. Unit tests pass, Security scan clean)...'),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _tryAction(() => notifier.addSubtask(widget.task.id, val.trim()), onSuccess: _subtaskInputController.clear);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const Key('subtask_add'),
                  style: FilledButton.styleFrom(
                    backgroundColor: crm.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (_subtaskInputController.text.trim().isNotEmpty) {
                      _tryAction(
                        () => notifier.addSubtask(widget.task.id, _subtaskInputController.text.trim()),
                        onSuccess: _subtaskInputController.clear,
                      );
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: subtasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.checklist, size: 40, color: crm.textSecondary),
                          const SizedBox(height: 8),
                          Text('No subtasks or checklist items yet.', style: TextStyle(color: crm.textSecondary, fontSize: 13.5)),
                        ],
                      ),
                    )
                  : Material(
                      type: MaterialType.transparency,
                      child: ListView.separated(
                        itemCount: subtasks.length,
                        separatorBuilder: (_, idx) => Divider(height: 1, color: crm.border.faded(0.8)),
                        itemBuilder: (_, i) {
                          final item = subtasks[i];
                          return CheckboxListTile(
                            key: Key('subtask_${item.id}'),
                            value: item.isCompleted,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: crm.primary,
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14,
                                decoration: null,
                                color: item.isCompleted ? const Color(0xFF059669) : crm.textPrimary,
                                fontWeight: item.isCompleted ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                            onChanged: (val) => _tryAction(() => notifier.toggleSubtask(widget.task.id, item.id, val ?? false)),
                            secondary: IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline, size: 19),
                              onPressed: () => _tryAction(() => notifier.removeSubtask(widget.task.id, item.id)),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── dependencies ──────────────────────────────────────────────────────────

  Widget _buildDependenciesTab(CrmTheme crm) {
    final blockers = [for (final id in _predecessorIds) (id, widget.allTasks.where((t) => t.id == id).firstOrNull)];
    final waiting = widget.allTasks.where((t) => t.predecessorIds.contains(widget.task.id)).toList();

    Widget taskRow(ITTaskModel t, {Widget? trailing, bool blocking = false}) => Container(
      key: Key('dep_row_${t.id}'),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: crm.border.faded(0.8))),
      ),
      child: Row(
        children: [
          _pill(t.ticketKey, crm.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: crm.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Due ${t.dueDate == null ? 'not set' : DateFormat('dd MMM yyyy').format(t.dueDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: blocking ? Colors.red.shade700 : crm.textSecondary,
                    fontWeight: blocking ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _pill(t.status.label, t.status.color),
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        children: [
          _card(
            crm,
            key: const Key('dependencies_blockers'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardTitle(crm, 'Blockers — must finish first', icon: Icons.link_rounded),
                const SizedBox(height: 4),
                Text('This task cannot start until these are completed.', style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
                const SizedBox(height: 10),
                if (blockers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text('No blockers. This task can start any time.', style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
                  )
                else
                  for (final (id, t) in blockers)
                    if (t == null)
                      Padding(
                        key: Key('dep_row_$id'),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'A task that is no longer in this project',
                                style: TextStyle(fontSize: 13.5, color: crm.textSecondary, fontStyle: FontStyle.italic),
                              ),
                            ),
                            _lockPlan(
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() => _predecessorIds.remove(id)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      taskRow(
                        t,
                        blocking: _isBlocking(t),
                        trailing: _lockPlan(
                          IconButton(
                            key: Key('dep_remove_${t.id}'),
                            tooltip: 'Remove dependency',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _predecessorIds.remove(t.id)),
                          ),
                        ),
                      ),
                const SizedBox(height: 14),
                _lockPlan(_addDependencyButton(crm)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            crm,
            key: const Key('dependencies_waiting'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardTitle(crm, 'Waiting on this task', icon: Icons.hourglass_empty_rounded),
                const SizedBox(height: 4),
                Text('These tasks cannot start until this one is completed.', style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
                const SizedBox(height: 10),
                if (waiting.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text('Nothing is waiting on this task.', style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
                  )
                else
                  for (final t in waiting) taskRow(t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── activity ──────────────────────────────────────────────────────────────

  Widget _buildActivityTab(CrmTheme crm, ITTaskModel live) {
    final logs = live.activityLogs;
    final notifier = getITTasksNotifier(ref, widget.task.projectId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: _card(
        crm,
        key: const Key('task_activity_card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(crm, 'Activity & Comments', icon: Icons.chat_outlined),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('comment_input'),
                    controller: _commentInputController,
                    decoration: _fieldDeco(crm, hint: 'Post a comment, note, or blocker update...'),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _tryAction(() => notifier.addActivityComment(widget.task.id, val.trim()), onSuccess: _commentInputController.clear);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const Key('comment_post'),
                  style: FilledButton.styleFrom(
                    backgroundColor: crm.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (_commentInputController.text.trim().isNotEmpty) {
                      _tryAction(
                        () => notifier.addActivityComment(widget.task.id, _commentInputController.text.trim()),
                        onSuccess: _commentInputController.clear,
                      );
                    }
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Post'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Text('No activity or comments yet.', style: TextStyle(color: crm.textSecondary, fontSize: 13.5)),
                    )
                  : ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, idx) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final log = logs[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: crm.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: crm.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.account_circle_outlined, size: 17, color: crm.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    log.authorName,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                                  ),
                                  const Spacer(),
                                  Text(
                                    DateFormat('MMM dd, hh:mm a').format(log.timestamp),
                                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(log.message, style: TextStyle(fontSize: 13.5, color: crm.textPrimary)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Runs a quick inline action (subtask / comment). The text box is only
  /// cleared when the save worked, so a failed post is not lost.
  Future<void> _tryAction(Future<void> Function() action, {VoidCallback? onSuccess}) async {
    try {
      await action();
      if (mounted) onSuccess?.call();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  // ── footer ────────────────────────────────────────────────────────────────

  /// Asks first, then removes the task and closes the dialog.
  Future<void> _confirmDelete() async {
    final isItProject = _isItProject;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${isItProject ? 'Ticket' : 'Task'}?'),
        content: Text('Are you sure you want to delete "${widget.task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final notifier = getITTasksNotifier(ref, widget.task.projectId);
      try {
        await notifier.deleteTask(widget.task.id);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) showErrorSnackBar(context, e);
      }
    }
  }

  Widget _buildBottomActionBar(CrmTheme crm) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(top: BorderSide(color: crm.border)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // on a phone: Delete is just the bin, and the buttons are snug
          final narrow = box.maxWidth < 520;
          final pad = EdgeInsets.symmetric(horizontal: narrow ? 16 : 22, vertical: 14);
          return Row(
            children: [
              if (_rights.delete)
                narrow
                    ? IconButton(
                        key: const Key('task_delete'),
                        tooltip: 'Delete',
                        color: Colors.red.shade700,
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete_outline, size: 22),
                      )
                    : TextButton.icon(
                        key: const Key('task_delete'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
              const Spacer(),
              OutlinedButton(
                key: const Key('task_cancel'),
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: crm.textPrimary,
                  side: BorderSide(color: crm.border.faded(2.5)),
                  shape: shape,
                  padding: pad,
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (!_rights.readOnly) ...[
                SizedBox(width: narrow ? 8 : 12),
                FilledButton.icon(
                  key: const Key('task_save'),
                  style: FilledButton.styleFrom(backgroundColor: crm.primary, shape: shape, padding: pad),
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: const Icon(Icons.check, size: 19),
                  label: Text(_isSaving ? 'Saving…' : (narrow ? 'Save' : 'Save Changes'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

extension on String {
  /// This text, or [fallback] when it is empty.
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
