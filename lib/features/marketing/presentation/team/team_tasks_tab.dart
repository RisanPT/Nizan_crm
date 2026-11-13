import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_dashboard_kit.dart' show DashSegmented;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_widgets.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

enum TaskView { list, kanban, calendar }

/// Team Dashboard → Tasks & Deliverables: the team's tasks as a list, a kanban or a calendar — one set of records, three views.
class TeamTasksTab extends ConsumerStatefulWidget {
  const TeamTasksTab({super.key});

  @override
  ConsumerState<TeamTasksTab> createState() => _TeamTasksTabState();
}

class _TeamTasksTabState extends ConsumerState<TeamTasksTab> {
  TaskView _view = TaskView.list;
  WorkStatus? _status;
  String _priority = 'all';
  String _search = '';
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(teamTasksProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshTeam(ref),
      child: tasks.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshTeam(ref))]),
        data: (list) {
          var items = list.items.where((t) => (_status == null || t.status == _status) && (_priority == 'all' || t.priority == _priority)).toList();
          if (_search.trim().isNotEmpty) items = items.where((t) => t.title.toLowerCase().contains(_search.trim().toLowerCase())).toList();
          return ListView(
            key: const Key('team_tasks_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktCard(
                title: 'Tasks & Deliverables',
                subtitle: '${list.counts['all'] ?? 0} in all · ${items.length} shown',
                icon: Icons.checklist_rtl_rounded,
                trailing: MktPrimaryButton(key: const Key('team_task_new'), label: 'New task', onPressed: () => showTaskEditor(context, ref)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DashSegmented<TaskView>(
                          keyPrefix: 'team_task_view',
                          dense: true,
                          options: const [(TaskView.list, 'List'), (TaskView.kanban, 'Kanban'), (TaskView.calendar, 'Calendar')],
                          value: _view,
                          onChanged: (v) => setState(() => _view = v),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            key: const Key('team_task_search'),
                            onChanged: (v) => setState(() => _search = v),
                            style: mktText(13),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded, size: 18),
                              hintText: 'Search tasks',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.violet)),
                            ),
                          ),
                        ),
                        KeyedSubtree(
                          key: const Key('team_task_priority'),
                          child: MktDropdownPill<String>(
                            value: _priority,
                            icon: Icons.flag_outlined,
                            options: const [('all', 'Any priority'), ('high', 'High'), ('medium', 'Medium'), ('low', 'Low')],
                            onChanged: (v) => setState(() => _priority = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          MktFilterChip(key: const Key('team_task_status_all'), label: 'All', count: list.counts['all'] ?? 0, selected: _status == null, onTap: () => setState(() => _status = null)),
                          for (final s in [WorkStatus.notStarted, WorkStatus.inProgress, WorkStatus.pending, WorkStatus.blocked, WorkStatus.completed])
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: MktFilterChip(key: Key('team_task_status_${s.wire}'), label: s.label, count: list.counts[s.wire] ?? 0, selected: _status == s, onTap: () => setState(() => _status = _status == s ? null : s)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty && _view != TaskView.calendar)
                      const MktEmpty('No tasks here. Create one with New task.', icon: Icons.checklist_rtl_rounded, height: 140)
                    else
                      switch (_view) {
                        TaskView.list => _TaskList(items: items, ref: ref),
                        TaskView.kanban => _Kanban(items: items),
                        TaskView.calendar => _TaskCalendar(items: items, month: _month, onMonth: (m) => setState(() => _month = m)),
                      },
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.items, required this.ref});
  final List<TeamTask> items;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      return MktTable(
        minWidth: 640,
        rowHeight: 52,
        rowKeys: [for (final t in items) Key('team_task_${t.id}')],
        onRowTap: (i) => showTaskEditor(context, ref, task: items[i]),
        columns: const [
          MktCol('Task', flex: 6),
          MktCol('Assigned to', flex: 3),
          MktCol('Due', width: 84),
          MktCol('Priority', width: 82),
          MktCol('Progress', flex: 3),
          MktCol('Status', width: 112, align: Alignment.centerRight),
        ],
        rows: [
          for (final t in items)
            [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w700)),
                    Text([if (t.projectLabel.isNotEmpty) t.projectLabel, if (t.isDeliverable) 'Deliverable'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
                  ],
                ),
              ),
              t.assignee.isEmpty
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        MktAvatar(t.assignee, size: 24),
                        const SizedBox(width: 6),
                        Flexible(child: Text(t.assignee, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12))),
                      ],
                    ),
              Text(t.dueDate == null ? '—' : shortDay(t.dueDate!), style: mktText(12, weight: t.overdue ? FontWeight.w800 : FontWeight.w500, color: t.overdue ? Mkt.bad : Mkt.ink)),
              MktChip(t.priority[0].toUpperCase() + t.priority.substring(1), color: priorityColor(t.priority)),
              Padding(padding: const EdgeInsets.only(right: 10), child: MktProgress(pct: t.progress, color: workStatusColor(t.status))),
              MktChip(t.status.label, color: workStatusColor(t.status)),
            ],
        ],
      );
    }
    return Column(
      children: [
        for (final t in items)
          Container(
            key: Key('team_task_${t.id}'),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Mkt.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.overdue ? Mkt.bad.withValues(alpha: 0.5) : Mkt.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showTaskEditor(context, ref, task: t),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(width: 4, height: 40, decoration: BoxDecoration(color: priorityColor(t.priority), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(13.5, weight: FontWeight.w700)),
                          Text(
                            [if (t.projectLabel.isNotEmpty) t.projectLabel, if (t.assignee.isNotEmpty) t.assignee, if (t.dueDate != null) 'due ${shortDay(t.dueDate!)}', if (t.isDeliverable) 'Deliverable'].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: mktText(11.5, color: t.overdue ? Mkt.bad : Mkt.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    MktChip(t.status.label, color: workStatusColor(t.status)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Kanban extends ConsumerWidget {
  const _Kanban({required this.items});
  final List<TeamTask> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const columns = [WorkStatus.notStarted, WorkStatus.inProgress, WorkStatus.pending, WorkStatus.blocked, WorkStatus.completed];
    return SingleChildScrollView(
      key: const Key('team_kanban'),
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in columns)
            Container(
              width: 236,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Mkt.tint(workStatusColor(s), 0.07), borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 9, height: 9, decoration: BoxDecoration(color: workStatusColor(s), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(s.label, style: mktText(12.5, weight: FontWeight.w800)),
                      const Spacer(),
                      Text('${items.where((t) => t.status == s).length}', key: Key('team_kanban_count_${s.wire}'), style: mktText(12, weight: FontWeight.w700, color: Mkt.inkSoft)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final t in items.where((t) => t.status == s))
                    Container(
                      key: Key('team_kanban_${t.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(11), border: Border.all(color: Mkt.border)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () => showTaskEditor(context, ref, task: t),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                [t.assignee, if (t.dueDate != null) 'due ${shortDay(t.dueDate!)}'].where((x) => x.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: mktText(11, color: t.overdue ? Mkt.bad : Mkt.inkSoft),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  MktChip(t.priority, color: priorityColor(t.priority)),
                                  const SizedBox(width: 8),
                                  Expanded(child: MktProgress(pct: t.progress, color: workStatusColor(t.status), height: 5, showLabel: false)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskCalendar extends ConsumerWidget {
  const _TaskCalendar({required this.items, required this.month, required this.onMonth});
  final List<TeamTask> items;
  final DateTime month;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday - 1; // Monday first
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = lead + days;
    final rows = (cells / 7).ceil();
    final withDue = items.where((t) => t.dueDate != null).toList();
    return Column(
      key: const Key('team_task_calendar'),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => onMonth(DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(child: Text(DateFormat('MMMM yyyy').format(month), textAlign: TextAlign.center, style: mktText(14, weight: FontWeight.w800))),
            IconButton(onPressed: () => onMonth(DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ),
        Row(
          children: [
            for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
              Expanded(child: Center(child: Text(d, style: mktText(11, weight: FontWeight.w700, color: Mkt.inkSoft)))),
          ],
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final n = r * 7 + c - lead + 1;
                      if (n < 1 || n > days) return const SizedBox(height: 64);
                      final day = TeamFilter.day(DateTime(month.year, month.month, n));
                      final due = withDue.where((t) => t.dueDate == day).toList();
                      return Container(
                        key: Key('team_cal_$day'),
                        height: 64,
                        margin: const EdgeInsets.all(1.5),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: Mkt.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$n', style: mktText(10.5, color: Mkt.inkSoft)),
                            for (final t in due.take(2))
                              InkWell(
                                onTap: () => showTaskEditor(context, ref, task: t),
                                child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(9.5, weight: FontWeight.w700, color: workStatusColor(t.status))),
                              ),
                            if (due.length > 2) Text('+${due.length - 2}', style: mktText(9, color: Mkt.inkSoft)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// The task form: a new task, or [task] to change. A manager can give it to anyone; a member's own tasks are theirs.
Future<void> showTaskEditor(BuildContext context, WidgetRef ref, {TeamTask? task}) {
  final form = _TaskForm(task: task);
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: form)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: form));
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({this.task});
  final TeamTask? task;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _desc = TextEditingController(text: widget.task?.description ?? '');
  late final _project = TextEditingController(text: widget.task?.projectLabel ?? '');
  final _comment = TextEditingController();
  late String _priority = widget.task?.priority ?? 'medium';
  late WorkStatus _status = widget.task?.status ?? WorkStatus.notStarted;
  late double _progress = (widget.task?.progress ?? 0).toDouble();
  late TeamBrand _brand = widget.task?.brand ?? TeamBrand.main;
  late bool _deliverable = widget.task?.isDeliverable ?? false;
  late String? _due = widget.task?.dueDate;
  String? _assignee;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _assignee = widget.task?.assigneeId;
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _project, _comment]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(_due ?? '') ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2));
    if (d != null) setState(() => _due = TeamFilter.day(d));
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Give the task a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(marketingTeamServiceProvider).saveTask({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'projectLabel': _project.text.trim(),
        'priority': _priority,
        'status': _status.wire,
        'progress': _progress.round(),
        'brand': _brand.wire,
        'isDeliverable': _deliverable,
        'dueDate': _due,
        'assigneeId': ?_assignee,
      }, id: widget.task?.id);
      refreshTeam(ref);
      if (mounted) Navigator.pop(context);
    } on TeamRefusal catch (r) {
      if (mounted) {
        setState(() {
          _error = r.message;
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this task?'),
        content: const Text('Logs that pointed at it keep their record.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(key: const Key('team_task_delete_confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref.read(marketingTeamServiceProvider).deleteTask(widget.task!.id);
      refreshTeam(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final setup = ref.watch(logSetupProvider((date: TeamFilter.day(DateTime.now()), memberId: null)));
    final members = setup.maybeWhen(data: (s) => s.canLogForOthers ? s.members : const <({String id, String name})>[], orElse: () => const <({String id, String name})>[]);
    return Column(mainAxisSize: MainAxisSize.min, children: [
     Flexible(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.task == null ? 'New task' : 'Task', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        const SizedBox(height: 12),
        TextField(key: const Key('team_task_title'), controller: _title, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        TextField(key: const Key('team_task_desc'), controller: _desc, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Details', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        TextField(key: const Key('team_task_project'), controller: _project, decoration: const InputDecoration(labelText: 'Project or client', border: OutlineInputBorder(), isDense: true)),
        if (members.length > 1) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            key: const Key('team_task_assignee'),
            initialValue: members.any((m) => m.id == _assignee) ? _assignee : null,
            decoration: const InputDecoration(labelText: 'Assigned to', border: OutlineInputBorder(), isDense: true),
            items: [const DropdownMenuItem<String?>(value: null, child: Text('Myself')), for (final m in members) DropdownMenuItem<String?>(value: m.id, child: Text(m.name))],
            onChanged: (v) => setState(() => _assignee = v),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DashSegmented<TeamBrand>(keyPrefix: 'team_task_brand', dense: true, options: const [(TeamBrand.main, 'Main'), (TeamBrand.kerala, 'Kerala')], value: _brand, onChanged: (b) => setState(() => _brand = b)),
          DashSegmented<String>(keyPrefix: 'team_task_prio', dense: true, options: const [('high', 'High'), ('medium', 'Medium'), ('low', 'Low')], value: _priority, onChanged: (p) => setState(() => _priority = p)),
          OutlinedButton.icon(key: const Key('team_task_due'), onPressed: _pickDue, icon: const Icon(Icons.event_outlined, size: 16), label: Text(_due == null ? 'Due date' : 'Due ${shortDay(_due!)}')),
          if (_due != null) TextButton(onPressed: () => setState(() => _due = null), child: const Text('Clear')),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, children: [
          for (final s in WorkStatus.values) ChoiceChip(key: Key('team_task_set_${s.wire}'), label: Text(s.label), selected: _status == s, onSelected: (_) => setState(() {
                _status = s;
                if (s == WorkStatus.completed) _progress = 100;
              })),
        ]),
        Row(children: [Text('Progress ${_progress.round()}%', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)), Expanded(child: Slider(key: const Key('team_task_progress'), value: _progress, min: 0, max: 100, divisions: 20, onChanged: (v) => setState(() {
                  _progress = v;
                  if (v >= 100) _status = WorkStatus.completed;
                })))]),
        SwitchListTile(key: const Key('team_task_deliverable'), contentPadding: EdgeInsets.zero, title: const Text('This is a deliverable'), value: _deliverable, onChanged: (v) => setState(() => _deliverable = v)),
        if (widget.task != null) ...[
          for (final c in widget.task!.comments) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${c.by}: ${c.text}', style: TextStyle(fontSize: 12, color: crm.textSecondary))),
          Row(children: [
            Expanded(child: TextField(key: const Key('team_task_comment'), controller: _comment, decoration: const InputDecoration(hintText: 'Add a comment', isDense: true, border: OutlineInputBorder()))),
            IconButton(
              key: const Key('team_task_comment_send'),
              onPressed: () async {
                final text = _comment.text.trim();
                if (text.isEmpty) return;
                try {
                  await ref.read(marketingTeamServiceProvider).addComment(widget.task!.id, text);
                  _comment.clear();
                  refreshTeam(ref);
                  if (mounted) Navigator.pop(this.context);
                } catch (e) {
                  if (mounted) showErrorSnackBar(this.context, e);
                }
              },
              icon: const Icon(Icons.send_rounded, size: 18),
            ),
          ]),
        ],
      ]),
     )),
     Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const Key('team_task_error'), style: const TextStyle(color: kTeamBad, fontWeight: FontWeight.w600))),
        Row(children: [
          if (widget.task != null) TextButton(key: const Key('team_task_delete'), onPressed: _saving ? null : _delete, child: const Text('Delete', style: TextStyle(color: kTeamBad))),
          const Spacer(),
          OutlinedButton(key: const Key('team_task_cancel'), onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          const SizedBox(width: 10),
          FilledButton(key: const Key('team_task_save'), onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
        ]),
      ]),
     ),
    ]);
  }
}
