import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_dashboard_kit.dart' show DashSegmented;
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_widgets.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Open the Log Activity form — a bottom sheet on a phone, a dialog on a laptop. [editing] changes a log already saved.
/// → true when something was saved. (The document's "Log Activity" button in the header, and the "Log Daily Activity" strip.)
Future<bool?> showLogActivity(BuildContext context, {DateTime? date, SavedLog? editing, String? memberId}) {
  final form = LogActivityForm(date: date ?? DateTime.now(), editing: editing, memberId: memberId);
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<bool>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760), child: form)));
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: form),
  );
}

/// The one log form: what you worked on, for which project or client, what is done and what is pending, the next priority, the time
/// spent, links, and the counts that make up your day. Saving it once is all there is — the day's EOD totals, the dashboards and the
/// reports all read this record.
class LogActivityForm extends ConsumerStatefulWidget {
  const LogActivityForm({super.key, required this.date, this.editing, this.memberId});

  final DateTime date;
  final SavedLog? editing;
  final String? memberId;

  @override
  ConsumerState<LogActivityForm> createState() => _LogActivityFormState();
}

class _LogActivityFormState extends ConsumerState<LogActivityForm> {
  late DateTime _date = widget.date;
  String? _memberId;
  TeamBrand _brand = TeamBrand.main;
  ActivityKind _kind = ActivityKind.task;
  WorkStatus _status = WorkStatus.completed;
  String? _taskId;
  String? _shootId;
  String _shootStage = 'production';
  double _taskProgress = 0;
  bool _saving = false;
  bool _seeded = false;
  bool _needsReason = false;
  String? _error;
  String? _errorField;

  final _workedOn = TextEditingController();
  final _project = TextEditingController();
  final _completed = TextEditingController();
  final _pending = TextEditingController();
  final _next = TextEditingController();
  final _comment = TextEditingController();
  final _hours = TextEditingController(text: '0');
  final _minutes = TextEditingController(text: '0');
  final _reason = TextEditingController();
  final _counts = <String, TextEditingController>{};
  final _details = <String, TextEditingController>{};
  final _links = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _memberId = widget.memberId;
  }

  @override
  void dispose() {
    for (final c in [_workedOn, _project, _completed, _pending, _next, _comment, _hours, _minutes, _reason, ..._counts.values, ..._details.values, ..._links]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _countCtl(String id) => _counts.putIfAbsent(id, () => TextEditingController());
  TextEditingController _detailCtl(String id) => _details.putIfAbsent(id, () => TextEditingController());

  /// Fill the fields once, from the log being edited.
  void _seed(LogSetup setup) {
    if (_seeded) return;
    _seeded = true;
    final e = widget.editing;
    if (e == null) {
      _brand = TeamBrand.main;
      return;
    }
    _workedOn.text = e.workedOn;
    _project.text = e.projectLabel;
    _completed.text = e.completed;
    _pending.text = e.pending;
    _next.text = e.nextPriority;
    _comment.text = e.comment;
    _hours.text = '${e.minutes ~/ 60}';
    _minutes.text = '${e.minutes % 60}';
    _brand = e.brand;
    _kind = e.kind;
    _status = e.status;
    _taskId = e.taskId;
    _shootId = e.shootId;
    if (e.shootStage != null && e.shootStage!.isNotEmpty) _shootStage = e.shootStage!;
    for (final entry in e.counts.entries) {
      _countCtl(entry.key).text = entry.value == entry.value.roundToDouble() ? entry.value.toInt().toString() : entry.value.toString();
      _detailCtl(entry.key).text = e.details[entry.key] ?? '';
    }
    for (final url in e.attachments) {
      _links.add(TextEditingController(text: url));
    }
  }

  LogSetupKey get _key => (date: TeamFilter.day(_date), memberId: _memberId);

  int get _totalMinutes => (int.tryParse(_hours.text.trim()) ?? 0) * 60 + (int.tryParse(_minutes.text.trim()) ?? 0);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _date.isAfter(now) ? now : _date, firstDate: DateTime(now.year - 1), lastDate: now);
    if (d != null) setState(() => _date = d);
  }

  /// What the form can say before asking the server.
  String? _problem(LogSetup setup) {
    if (_workedOn.text.trim().length < 2) return 'Say what you worked on.';
    final h = int.tryParse(_hours.text.trim());
    final m = int.tryParse(_minutes.text.trim());
    if (h == null || m == null || h < 0 || m < 0 || m > 59 || h > 24) return 'Time spent: hours 0–24 and minutes 0–59.';
    if (_totalMinutes > 1440) return 'A day has only 24 hours.';
    for (final id in _counts.keys) {
      final t = _counts[id]!.text.trim();
      if (t.isNotEmpty && (double.tryParse(t) == null || double.parse(t) < 0)) return 'Counts must be numbers, not less than 0.';
    }
    for (final l in _links) {
      final t = l.text.trim();
      if (t.isNotEmpty && !RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(t)) return 'A link must start with http:// or https://.';
    }
    if (!setup.self && _reason.text.trim().isEmpty) return 'Say why you are logging this for someone else.';
    return null;
  }

  Future<void> _save(LogSetup setup) async {
    final problem = _problem(setup);
    if (problem != null) {
      setState(() {
        _error = problem;
        _errorField = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _errorField = null;
    });
    final counts = <String, num>{};
    final details = <String, String>{};
    for (final g in setup.groups) {
      for (final metric in g.metrics) {
        final v = num.tryParse(_counts[metric.id]?.text.trim() ?? '') ?? 0;
        if (v > 0) {
          counts[metric.id] = v;
          details[metric.id] = _details[metric.id]?.text.trim() ?? '';
        }
      }
    }
    // counts on a log that the member's current activity set no longer lists are kept as they were
    final known = {for (final g in setup.groups) for (final m in g.metrics) m.id};
    for (final e in (widget.editing?.counts ?? const <String, num>{}).entries) {
      if (!known.contains(e.key)) {
        counts[e.key] = e.value;
        details[e.key] = widget.editing!.details[e.key] ?? '';
      }
    }
    final draft = LogDraft(
      memberId: _memberId ?? (setup.self ? null : setup.memberId),
      entryDate: TeamFilter.day(_date),
      workedOn: _workedOn.text.trim(),
      projectLabel: _project.text.trim(),
      completed: _completed.text.trim(),
      pending: _pending.text.trim(),
      nextPriority: _next.text.trim(),
      minutes: _totalMinutes,
      status: _status,
      kind: _kind,
      brand: _brand,
      comment: _comment.text.trim(),
      attachments: [for (final l in _links) l.text],
      counts: counts,
      details: details,
      taskId: _taskId,
      taskProgress: _taskId != null && _status != WorkStatus.completed ? _taskProgress.round() : null,
      shootId: _shootId,
      shootStage: _shootId == null ? null : _shootStage,
      overrideReason: _reason.text,
    );
    try {
      final warnings = await ref.read(marketingTeamServiceProvider).saveLog(draft, id: widget.editing?.id);
      refreshTeam(ref);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(SnackBar(key: const Key('log_saved'), content: Text(warnings.isEmpty ? 'Logged.' : 'Logged. ${warnings.join(' ')}')));
    } on TeamRefusal catch (r) {
      if (mounted) {
        setState(() {
          _error = r.message;
          _errorField = r.field;
          _needsReason = _needsReason || r.reasonRequired;
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

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final setup = ref.watch(logSetupProvider(_key));
    return setup.when(
      loading: () => const SizedBox(height: 260, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: AppErrorView(error: e, onRetry: () => ref.invalidate(logSetupProvider(_key)))),
      data: (s) {
        _seed(s);
        final open = s.tasks;
        final editingOthers = !s.self;
        final locked = !s.canEdit;
        // the fields scroll; the error and the Cancel / Save buttons stay in view whatever the length of the form
        return Column(mainAxisSize: MainAxisSize.min, children: [
         Flexible(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(widget.editing == null ? 'Log Activity' : 'Change this log', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: crm.textPrimary))),
              OutlinedButton.icon(key: const Key('log_date'), onPressed: _pickDate, icon: const Icon(Icons.calendar_today_outlined, size: 15), label: Text(DateFormat('EEE d MMM').format(_date))),
            ]),
            if (s.canLogForOthers && widget.editing == null) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: const Key('log_member'),
                initialValue: _memberId,
                decoration: const InputDecoration(labelText: 'Logging for', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Myself')),
                  for (final m in s.members) DropdownMenuItem<String?>(value: m.id, child: Text(m.name)),
                ],
                onChanged: (v) => setState(() {
                  _memberId = v;
                  _seeded = true;
                  _taskId = null;
                }),
              ),
            ],
            if (s.notice.isNotEmpty)
              Container(key: const Key('log_notice'), margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kTeamWatch.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text(s.notice, style: TextStyle(color: crm.textPrimary, fontSize: 12.5))),
            const SizedBox(height: 14),
            DashSegmented<TeamBrand>(keyPrefix: 'log_brand', dense: true, options: const [(TeamBrand.main, 'Main'), (TeamBrand.kerala, 'Kerala')], value: _brand, onChanged: (b) => setState(() => _brand = b)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final k in ActivityKind.values)
                ChoiceChip(key: Key('log_kind_${k.wire}'), avatar: Icon(kindIcon(k), size: 15), label: Text(k.label), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
            ]),
            const SizedBox(height: 12),
            _field('log_worked_on', _workedOn, 'What did you work on?', errorField: 'workedOn', maxLength: 300),
            TextField(key: const Key('log_project'), controller: _project, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Which project or client?', border: OutlineInputBorder(), isDense: true)),
            // projects that match what is being typed — one tap fills it in (anything else typed is kept as it is)
            if (_project.text.trim().isNotEmpty)
              Wrap(spacing: 6, children: [
                for (final p in s.projects.where((p) => p.name.toLowerCase().contains(_project.text.trim().toLowerCase()) && p.name != _project.text.trim()).take(4))
                  ActionChip(key: Key('log_project_${p.id}'), label: Text(p.name), onPressed: () => setState(() => _project.text = p.name)),
              ]),
            const SizedBox(height: 12),
            _field('log_completed', _completed, 'What did you complete?', lines: 2),
            _field('log_pending', _pending, 'What is still pending?', lines: 2),
            _field('log_next', _next, 'Next priority'),
            Row(children: [
              Expanded(child: _field('log_hours', _hours, 'Hours', keyboard: TextInputType.number, errorField: 'timeSpentMinutes')),
              const SizedBox(width: 10),
              Expanded(child: _field('log_minutes', _minutes, 'Minutes', keyboard: TextInputType.number, errorField: 'timeSpentMinutes')),
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('day so far: ${hoursLabel(s.dayMinutes)}', key: const Key('log_day_total'), style: TextStyle(fontSize: 11.5, color: crm.textSecondary))),
            ]),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final st in [WorkStatus.completed, WorkStatus.inProgress, WorkStatus.pending, WorkStatus.blocked])
                ChoiceChip(key: Key('log_status_${st.wire}'), label: Text(st.label), selected: _status == st, selectedColor: workStatusColor(st).withValues(alpha: 0.2), onSelected: (_) => setState(() => _status = st)),
            ]),
            if (open.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: const Key('log_task'),
                initialValue: open.any((t) => t.id == _taskId) ? _taskId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Part of a task? (logging it completed completes the task)', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('No task')),
                  for (final t in open) DropdownMenuItem<String?>(value: t.id, child: Text(t.dueDate == null ? t.title : '${t.title} · due ${shortDay(t.dueDate!)}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() {
                  _taskId = v;
                  _taskProgress = (open.where((t) => t.id == v).firstOrNull?.progress ?? 0).toDouble();
                }),
              ),
              if (_taskId != null && _status != WorkStatus.completed)
                Row(children: [
                  Text('Task progress ${_taskProgress.round()}%', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  Expanded(child: Slider(key: const Key('log_task_progress'), value: _taskProgress, min: 0, max: 99, divisions: 99, onChanged: (v) => setState(() => _taskProgress = v))),
                ]),
            ],
            if (s.shoots.isNotEmpty || _shootId != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: const Key('log_shoot'),
                initialValue: s.shoots.any((x) => x.id == _shootId) ? _shootId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'For a shoot? (moves the shoot\'s progress)', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('No shoot')),
                  for (final x in s.shoots) DropdownMenuItem<String?>(value: x.id, child: Text('${x.title} · ${shortDay(x.shootDate)}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _shootId = v),
              ),
              if (_shootId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 8, children: [
                    for (final st in const [('pre_production', 'Pre-production'), ('production', 'Production'), ('post_production', 'Post-production')])
                      ChoiceChip(key: Key('log_shoot_stage_${st.$1}'), label: Text(st.$2), selected: _shootStage == st.$1, onSelected: (_) => setState(() => _shootStage = st.$1)),
                  ]),
                ),
            ],
            if (s.groups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('WHAT DID YOU COUNT?', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
              for (final g in s.groups) ...[
                Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(g.name, style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary))),
                for (final metric in g.metrics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(metric.name, style: TextStyle(fontSize: 13, color: crm.textPrimary)))),
                      SizedBox(width: 78, child: TextField(key: Key('log_count_${metric.id}'), controller: _countCtl(metric.id), keyboardType: TextInputType.number, decoration: InputDecoration(hintText: metric.isMoney ? '₹' : '0', border: const OutlineInputBorder(), isDense: true))),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: TextField(key: Key('log_details_${metric.id}'), controller: _detailCtl(metric.id), decoration: const InputDecoration(hintText: 'Details', border: OutlineInputBorder(), isDense: true))),
                    ]),
                  ),
              ],
            ],
            const SizedBox(height: 10),
            Text('ATTACHMENTS (LINKS)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
            for (var i = 0; i < _links.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Expanded(child: TextField(key: Key('log_attach_$i'), controller: _links[i], decoration: const InputDecoration(hintText: 'https://…', border: OutlineInputBorder(), isDense: true))),
                  IconButton(tooltip: 'Remove', onPressed: () => setState(() => _links.removeAt(i).dispose()), icon: const Icon(Icons.close_rounded, size: 18)),
                ]),
              ),
            TextButton.icon(key: const Key('log_attach_add'), onPressed: _links.length >= 10 ? null : () => setState(() => _links.add(TextEditingController())), icon: const Icon(Icons.add_link_rounded, size: 18), label: const Text('Add a link')),
            _field('log_comment', _comment, 'Comment (optional)', lines: 2),
            if (editingOthers || _needsReason) _field('log_reason', _reason, 'Why? (a manager logging for someone else, or for an older day, has to say why)', errorField: 'reason'),
          ]),
         )),
         Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const Key('log_error'), style: const TextStyle(color: kTeamBad, fontWeight: FontWeight.w600))),
            Row(children: [
              Expanded(child: OutlinedButton(key: const Key('log_cancel'), onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('log_save'),
                  onPressed: _saving || locked ? null : () => _save(s),
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.editing == null ? 'Log it' : 'Save changes'),
                ),
              ),
            ]),
          ]),
         ),
        ]);
      },
    );
  }

  Widget _field(String key, TextEditingController c, String label, {int lines = 1, TextInputType? keyboard, String? errorField, int? maxLength}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: Key(key),
          controller: c,
          keyboardType: keyboard,
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 1,
          maxLength: maxLength,
          textCapitalization: keyboard == null ? TextCapitalization.sentences : TextCapitalization.none,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, counterText: '', errorText: errorField != null && _errorField == errorField ? _error : null),
        ),
      );
}
