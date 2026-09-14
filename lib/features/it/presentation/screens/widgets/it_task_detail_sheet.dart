import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

/// Opens the developer-focused Task Detail Slide-over modal / dialog.
Future<bool?> showITTaskDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required ITTaskModel task,
  required List<ITTaskModel> allTasks,
}) {
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
          width: 880,
          height: math.min(820, size.height * 0.90),
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

  bool _isEditingDesc = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description);
    _subtaskInputController = TextEditingController();
    _commentInputController = TextEditingController();
    _estHoursController = TextEditingController(
        text: widget.task.estimatedHours > 0 ? widget.task.estimatedHours.toStringAsFixed(1) : '');
    _actHoursController = TextEditingController(
        text: widget.task.actualHours > 0 ? widget.task.actualHours.toStringAsFixed(1) : '');

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

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final notifier = getITTasksNotifier(ref, widget.task.projectId);

      final updates = <String, dynamic>{
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

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    // Detect blockers
    final blockers = <ITTaskModel>[];
    for (final pid in _predecessorIds) {
      final pred = widget.allTasks.where((t) => t.id == pid).firstOrNull;
      if (pred != null) {
        if (!pred.isCompleted && (_startDate != null && pred.dueDate != null && pred.dueDate!.isAfter(_startDate!))) {
          blockers.add(pred);
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        child: Scaffold(
          backgroundColor: crm.surface,
          body: Column(children: [
            // Top Bar
            _buildTopBar(crm),
            // Blocker Alert Banner if any
            if (blockers.isNotEmpty) _buildBlockerBanner(crm, blockers),
            // Tab Header
            TabBar(
              controller: _tabController,
              labelColor: crm.primary,
              unselectedLabelColor: crm.textSecondary,
              indicatorColor: crm.primary,
              tabs: const [
                Tab(icon: Icon(Icons.tune_outlined, size: 18), text: 'Specs & Description'),
                Tab(icon: Icon(Icons.checklist_outlined, size: 18), text: 'Subtasks'),
                Tab(icon: Icon(Icons.forum_outlined, size: 18), text: 'Activity & Comments'),
              ],
            ),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSpecTab(crm),
                  _buildSubtasksTab(crm),
                  _buildActivityTab(crm),
                ],
              ),
            ),
            // Bottom Action Bar
            _buildBottomActionBar(crm),
          ]),
        ),
      ),
    );
  }

  Widget _buildTopBar(CrmTheme crm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: BoxDecoration(
        color: crm.background,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _type.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _type.color.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_type.icon, size: 14, color: _type.color),
              const SizedBox(width: 5),
              Text(
                '${widget.task.ticketKey} • ${_type.label}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _type.color),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _severity.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _severity.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _severity.color),
            ),
          ),
          if (RegExp(r'TKT-\d+-\d+').firstMatch(widget.task.description)?.group(0) case final String tktNum) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.confirmation_number_outlined, size: 13, color: Colors.purple),
                const SizedBox(width: 4),
                Text(
                  tktNum,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.purple),
                ),
              ]),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            hintText: 'Ticket summary...',
          ),
        ),
      ]),
    );
  }

  Widget _buildBlockerBanner(CrmTheme crm, List<ITTaskModel> blockers) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.shade50,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_rounded, size: 20, color: Colors.red.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Technical Dependency Blocker Detected',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.red.shade800),
            ),
            const SizedBox(height: 2),
            Text(
              'Blocked by: ${blockers.map((b) => "${b.ticketKey} (${b.title}) due ${b.dueDate != null ? DateFormat('MMM dd').format(b.dueDate!) : 'TBD'}").join(', ')}',
              style: TextStyle(fontSize: 11.5, color: Colors.red.shade900),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSpecTab(CrmTheme crm) {
    final employees = ref.watch(itEmployeesProvider);
    final availablePredecessors = widget.allTasks.where((t) => t.id != widget.task.id).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Meta attributes Grid
        Wrap(spacing: 16, runSpacing: 14, children: [
          // Status Dropdown
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<ITTaskStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status', isDense: true),
              items: [
                for (final st in ITTaskStatus.values)
                  DropdownMenuItem(
                    value: st,
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: st.color)),
                      const SizedBox(width: 8),
                      Text(st.label, style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
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
          // Severity Dropdown
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<ITSeverity>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Severity', isDense: true),
              items: [
                for (final sv in ITSeverity.values)
                  DropdownMenuItem(
                    value: sv,
                    child: Text(sv.label, style: TextStyle(fontSize: 13, color: sv.color, fontWeight: FontWeight.w600)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _severity = v);
              },
            ),
          ),
          // Sub-Team Dropdown
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<ITSubTeam>(
              initialValue: _subTeam,
              decoration: const InputDecoration(labelText: 'IT Sub-Team', isDense: true),
              items: [
                for (final tm in ITSubTeam.values)
                  DropdownMenuItem(
                    value: tm,
                    child: Row(children: [
                      Icon(tm.icon, size: 15, color: tm.color),
                      const SizedBox(width: 8),
                      Text(tm.label, style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _subTeam = v);
              },
            ),
          ),
          // Ticket Type
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<ITTicketType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Ticket Type', isDense: true),
              items: [
                for (final tt in ITTicketType.values)
                  DropdownMenuItem(
                    value: tt,
                    child: Row(children: [
                      Icon(tt.icon, size: 15, color: tt.color),
                      const SizedBox(width: 8),
                      Text(tt.label, style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Assignee Picker
        EmployeePickerField(
          employees: employees,
          selectedId: _assigneeId.isNotEmpty ? _assigneeId : null,
          selectedName: _assigneeName.isNotEmpty ? _assigneeName : null,
          label: 'Assignee',
          allowUnassign: true,
          onChanged: (e) {
            setState(() {
              _assigneeId = e?.id ?? '';
              _assigneeName = e?.name ?? '';
            });
          },
        ),
        const SizedBox(height: 16),
        // Timeline & Dates
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: crm.primary,
                        onPrimary: Colors.white,
                        onSurface: crm.textPrimary,
                        surface: crm.surface,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (d != null) setState(() => _startDate = d);
              },
              icon: const Icon(Icons.play_arrow_outlined, size: 16),
              label: Text(_startDate == null ? 'Set Start Date' : 'Start: ${DateFormat('dd/MM/yy').format(_startDate!)}'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: crm.primary,
                        onPrimary: Colors.white,
                        onSurface: crm.textPrimary,
                        surface: crm.surface,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (d != null) setState(() => _dueDate = d);
              },
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text(_dueDate == null ? 'Set Due Date' : 'Due: ${DateFormat('dd/MM/yy').format(_dueDate!)}'),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Estimated and Actual Hours
        Row(children: [
          Expanded(
            child: TextField(
              controller: _estHoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Estimated Hours', prefixIcon: Icon(Icons.timer_outlined, size: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _actHoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Actual Hours Spent', prefixIcon: Icon(Icons.timelapse_outlined, size: 18)),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        // Progress Slider
        Row(children: [
          Text('Progress completion', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary)),
          const Spacer(),
          Text('$_percentComplete%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.primary)),
        ]),
        Slider(
          value: _percentComplete.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: '$_percentComplete%',
          onChanged: (v) => setState(() => _percentComplete = v.round()),
        ),
        const SizedBox(height: 20),
        // Predecessor Dependencies Selector
        Text('Predecessor Dependencies (Blockers)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final pid in _predecessorIds)
              Chip(
                backgroundColor: crm.background,
                label: Text(
                  widget.allTasks.where((t) => t.id == pid).map((t) => '${t.ticketKey} ${t.title}').firstOrNull ?? pid,
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() => _predecessorIds.remove(pid));
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add_link, size: 16),
              label: const Text('Add Dependency'),
              onPressed: () {
                _showAddDependencyDialog(crm, availablePredecessors);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Technical Acceptance Criteria / Description
        Row(children: [
          Text('Description & Acceptance Criteria', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const Spacer(),
          TextButton.icon(
            icon: Icon(_isEditingDesc ? Icons.visibility_outlined : Icons.edit_note_outlined, size: 16),
            label: Text(_isEditingDesc ? 'Preview' : 'Edit'),
            onPressed: () => setState(() => _isEditingDesc = !_isEditingDesc),
          ),
        ]),
        const SizedBox(height: 8),
        if (_isEditingDesc)
          TextField(
            controller: _descController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Enter technical specifications, acceptance criteria (Markdown supported)...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: crm.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crm.border),
            ),
            child: _descController.text.trim().isEmpty
                ? Text('No description provided. Click Edit to add specs.', style: TextStyle(color: crm.textSecondary, fontStyle: FontStyle.italic))
                : MarkdownBody(
                    data: _descController.text,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: TextStyle(fontSize: 13, color: crm.textPrimary),
                    ),
                  ),
          ),
      ]),
    );
  }

  void _showAddDependencyDialog(CrmTheme crm, List<ITTaskModel> candidates) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Predecessor Task'),
        content: SizedBox(
          width: 400,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: candidates.length,
            separatorBuilder: (_, idx) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = candidates[i];
              final isSelected = _predecessorIds.contains(t.id);
              return ListTile(
                title: Text('${t.ticketKey} • ${t.title}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('Due: ${t.dueDate != null ? DateFormat('dd MMM').format(t.dueDate!) : 'No date'} • ${t.status.label}', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  Widget _buildSubtasksTab(CrmTheme crm) {
    final subtasks = widget.task.subtasks;
    final notifier = getITTasksNotifier(ref, widget.task.projectId);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Add Subtask row
        Row(children: [
          Expanded(
            child: TextField(
              controller: _subtaskInputController,
              decoration: const InputDecoration(
                hintText: 'Add QA/Code review checklist item (e.g. Unit tests pass, Security scan clean)...',
                isDense: true,
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  notifier.addSubtask(widget.task.id, val.trim());
                  _subtaskInputController.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: crm.primary),
            onPressed: () {
              if (_subtaskInputController.text.trim().isNotEmpty) {
                notifier.addSubtask(widget.task.id, _subtaskInputController.text.trim());
                _subtaskInputController.clear();
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
          ),
        ]),
        const SizedBox(height: 16),
        // Subtasks List
        Expanded(
          child: subtasks.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.checklist, size: 40, color: crm.textSecondary),
                    const SizedBox(height: 8),
                    Text('No subtasks or review checklist items yet.', style: TextStyle(color: crm.textSecondary, fontSize: 13)),
                  ]),
                )
              : ListView.separated(
                  itemCount: subtasks.length,
                  separatorBuilder: (_, idx) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = subtasks[i];
                    return CheckboxListTile(
                      value: item.isCompleted,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                          color: item.isCompleted ? crm.textSecondary : crm.textPrimary,
                        ),
                      ),
                      onChanged: (val) {
                        notifier.toggleSubtask(widget.task.id, item.id, val ?? false);
                      },
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => notifier.removeSubtask(widget.task.id, item.id),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _buildActivityTab(CrmTheme crm) {
    final logs = widget.task.activityLogs;
    final notifier = getITTasksNotifier(ref, widget.task.projectId);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Add note / discussion input
        Row(children: [
          Expanded(
            child: TextField(
              controller: _commentInputController,
              decoration: const InputDecoration(
                hintText: 'Post a comment, triage note, or blocker update...',
                isDense: true,
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  notifier.addActivityComment(widget.task.id, val.trim());
                  _commentInputController.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: crm.primary),
            onPressed: () {
              if (_commentInputController.text.trim().isNotEmpty) {
                notifier.addActivityComment(widget.task.id, _commentInputController.text.trim());
                _commentInputController.clear();
              }
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Post'),
          ),
        ]),
        const SizedBox(height: 16),
        // Activity Feed
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Text('No activity logs or comments recorded yet.', style: TextStyle(color: crm.textSecondary, fontSize: 13)),
                )
              : ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, idx) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: crm.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: crm.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.account_circle_outlined, size: 16, color: crm.primary),
                          const SizedBox(width: 6),
                          Text(log.authorName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                          const Spacer(),
                          Text(DateFormat('MMM dd, hh:mm a').format(log.timestamp), style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                        ]),
                        const SizedBox(height: 6),
                        Text(log.message, style: TextStyle(fontSize: 13, color: crm.textPrimary)),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _buildBottomActionBar(CrmTheme crm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(top: BorderSide(color: crm.border)),
      ),
      child: Row(children: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Delete Ticket?'),
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
              await notifier.deleteTask(widget.task.id);
              if (mounted) Navigator.pop(context, true);
            }
          },
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 10),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: crm.primary),
          onPressed: _isSaving ? null : _saveChanges,
          child: Text(_isSaving ? 'Saving…' : 'Save Changes'),
        ),
      ]),
    );
  }
}
