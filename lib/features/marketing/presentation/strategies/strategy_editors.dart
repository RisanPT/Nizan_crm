import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/strategy_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_widgets.dart';
import 'package:nizan_crm/features/marketing/services/strategy_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart' show TeamFilter;

// The forms of Strategies & Developments: initiative / development project, plan, roadmap line, finding, review. Each shows the server's
// refusal inline, disables Save while saving and disposes its controllers.

const _brands = [('main', 'Main'), ('kerala', 'Kerala')];

DateTime? _day(String? s) => s == null || s.isEmpty ? null : DateTime.tryParse(s);

/// The shell every form shares: a scrolling body and the footer.
Widget _formShell({required Widget body, required Widget footer}) => Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), child: body)),
      footer,
    ]);

Widget _suggestions(List<String> values, TextEditingController into, VoidCallback changed) => values.isEmpty
    ? const SizedBox.shrink()
    : Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 4, children: [for (final v in values.take(8)) ActionChip(label: Text(v, style: mktText(11)), visualDensity: VisualDensity.compact, onPressed: () { into.text = v; changed(); })]));

// ── initiative / development project ─────────────────────────────────────────

/// Add or change an initiative (`kind` 'initiative') or a development project ('project'). The progress typed here is used only until a
/// task is tied to it; owner, due day and status are the manager's (a member makes initiatives they own).
Future<void> showWorkEditor(BuildContext context, WidgetRef ref, {required String kind, WorkItem? item}) => showStrategySheet<void>(context, _WorkForm(kind: kind, item: item));

class _WorkForm extends ConsumerStatefulWidget {
  const _WorkForm({required this.kind, this.item});
  final String kind;
  final WorkItem? item;
  @override
  ConsumerState<_WorkForm> createState() => _WorkFormState();
}

class _WorkFormState extends ConsumerState<_WorkForm> {
  bool get _project => widget.kind == 'project';
  late final _title = TextEditingController(text: widget.item?.title ?? '');
  late final _area = TextEditingController(text: _project ? (widget.item?.category ?? '') : (widget.item?.focusArea ?? ''));
  late final _progress = TextEditingController(text: widget.item?.typedProgress == null ? '' : '${widget.item!.typedProgress}');
  late final _description = TextEditingController(text: widget.item?.description ?? '');
  late final _notes = TextEditingController(text: widget.item?.notes ?? '');
  late String _brand = widget.item?.brand ?? 'main';
  late String _impact = widget.item?.impact.isNotEmpty == true ? widget.item!.impact : 'medium';
  late String _status = widget.item?.storedStatus.isNotEmpty == true ? widget.item!.storedStatus : (_project ? 'in_progress' : 'active');
  late String? _owner = widget.item == null ? null : (widget.item!.owner?.source == 'set' ? widget.item!.owner!.id : null);
  late String? _plan = widget.item?.planId;
  late DateTime? _start = _day(widget.item?.typedStart);
  late DateTime? _due = widget.item == null ? null : (widget.item!.dueSource == 'set' ? _day(widget.item!.due) : null);
  bool _ownerChosen = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _area, _progress, _description, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(StrategySetup setup) async {
    final noun = _project ? 'project' : 'initiative';
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Give the $noun a ${_project ? 'name' : 'title'}.');
      return;
    }
    final typed = _progress.text.trim();
    final progress = typed.isEmpty ? null : int.tryParse(typed);
    if (typed.isNotEmpty && (progress == null || progress < 0 || progress > 100)) {
      setState(() => _error = 'Progress is a whole number from 0 to 100.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final day = TeamFilter.day;
    final body = <String, dynamic>{
      _project ? 'name' : 'title': _title.text.trim(),
      'brand': _brand,
      _project ? 'category' : 'focusArea': _area.text.trim(),
      if (!_project) 'impact': _impact,
      'planId': _plan,
      'startDate': _start == null ? null : day(_start!),
      _project ? 'endDate' : 'dueDate': _due == null ? null : day(_due!),
      'progress': progress,
      'description': _description.text.trim(),
      'notes': _notes.text.trim(),
      if (setup.canManage) 'status': _status,
      if (setup.canManage) 'ownerId': (widget.item == null && !_ownerChosen) ? (_owner ?? setup.meId) : _owner,
    };
    try {
      final svc = ref.read(marketingStrategyServiceProvider);
      if (_project) {
        await svc.saveProject(body, id: widget.item?.id);
      } else {
        await svc.saveInitiative(body, id: widget.item?.id);
      }
      refreshStrategies(ref);
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

  @override
  Widget build(BuildContext context) => withStrategySetup(ref, _body);

  Widget _body(StrategySetup setup) {
    final editing = widget.item != null;
    final noun = _project ? 'development project' : 'initiative';
    final ownerValue = editing || _ownerChosen ? _owner : (_owner ?? setup.meId);
    final ownerIds = {for (final m in setup.members) m.id};
    final tasksDecide = (widget.item?.taskCount ?? 0) > 0;
    return _formShell(
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(editing ? 'Edit $noun' : 'New $noun', style: mktText(19, weight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(key: const Key('work_title'), controller: _title, decoration: strategyDec(_project ? 'Project name' : 'Initiative title')),
        const SizedBox(height: 10),
        TextField(key: const Key('work_area'), controller: _area, decoration: strategyDec(_project ? 'Category' : 'Focus area', hint: _project ? 'Technology, Operations…' : 'Revenue & Lead Growth')),
        _suggestions(_project ? setup.categories : setup.focusAreas, _area, () => setState(() {})),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(key: const Key('work_brand'), isExpanded: true, initialValue: _brand, decoration: strategyDec('Brand'), items: [for (final b in _brands) DropdownMenuItem(value: b.$1, child: Text(b.$2))], onChanged: (v) => setState(() => _brand = v ?? _brand))),
          if (!_project) ...[
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(key: const Key('work_impact'), isExpanded: true, initialValue: _impact, decoration: strategyDec('Impact'), items: [for (final i in kImpacts) DropdownMenuItem(value: i.$1, child: Text(i.$2))], onChanged: (v) => setState(() => _impact = v ?? _impact))),
          ],
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          key: const Key('work_owner'),
          isExpanded: true,
          initialValue: ownerIds.contains(ownerValue) ? ownerValue : null,
          decoration: strategyDec('Owner', hint: 'Chosen from the tasks tied to it'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('No owner — use the tasks')),
            for (final m in setup.members) DropdownMenuItem<String?>(value: m.id, child: Text(m.name)),
          ],
          // a member's initiative is theirs; only a manager gives it to someone else
          onChanged: setup.canManage ? (v) => setState(() {
                _owner = v;
                _ownerChosen = true;
              }) : null,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          key: const Key('work_plan'),
          isExpanded: true,
          initialValue: setup.plans.any((p) => p.id == _plan) ? _plan : null,
          decoration: strategyDec('Strategic plan (optional)'),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('No plan')), for (final p in setup.plans) DropdownMenuItem<String?>(value: p.id, child: Text('${p.title} (${p.year})', overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => _plan = v),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          KeyedSubtree(key: const Key('work_start'), child: DayPickerField(label: 'Start date', value: _start, onChanged: (d) => setState(() => _start = d))),
          KeyedSubtree(key: const Key('work_due'), child: DayPickerField(label: 'Due date', value: _due, onChanged: (d) => setState(() => _due = d))),
        ]),
        const SizedBox(height: 4),
        Text('With no due date, the latest due date of its tasks is used.', style: mktText(11, color: Mkt.inkSoft)),
        const SizedBox(height: 10),
        TextField(
          key: const Key('work_progress'),
          controller: _progress,
          keyboardType: TextInputType.number,
          decoration: strategyDec('Progress set by owner (0–100)', hint: tasksDecide ? 'Tasks decide now' : 'Used until a task is tied to it'),
        ),
        const SizedBox(height: 2),
        Text(tasksDecide ? 'Tasks are tied to this $noun, so its progress is counted from them; this figure is kept but not used.' : 'Tie tasks to it (Tasks → Initiative / Project) and the progress counts itself.', style: mktText(11, color: Mkt.inkSoft)),
        if (setup.canManage) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const Key('work_status'),
            isExpanded: true,
            initialValue: (_project ? kProjectStoredStatuses : kInitiativeStoredStatuses).any((s) => s.$1 == _status) ? _status : null,
            decoration: strategyDec('Status'),
            items: [for (final s in (_project ? kProjectStoredStatuses : kInitiativeStoredStatuses)) DropdownMenuItem(value: s.$1, child: Text(s.$2))],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 2),
          Text('On Track / At Risk are worked out from the due date and progress; only On hold, Completed and Cancelled are set by hand.', style: mktText(11, color: Mkt.inkSoft)),
        ],
        const SizedBox(height: 10),
        TextField(key: const Key('work_description'), controller: _description, minLines: 2, maxLines: 3, decoration: strategyDec('Description')),
        const SizedBox(height: 10),
        TextField(key: const Key('work_notes'), controller: _notes, minLines: 2, maxLines: 4, decoration: strategyDec('Notes')),
      ]),
      footer: StrategyFormFooter(keyPrefix: 'work', saving: _saving, error: _error, onSave: () => _save(setup), saveLabel: editing ? 'Save' : (_project ? 'Create project' : 'Create initiative')),
    );
  }
}

// ── strategic plan ───────────────────────────────────────────────────────────

Future<void> showPlanEditor(BuildContext context, WidgetRef ref, {PlanItem? plan}) => showStrategySheet<void>(context, _PlanForm(plan: plan));

class _PlanForm extends ConsumerStatefulWidget {
  const _PlanForm({this.plan});
  final PlanItem? plan;
  @override
  ConsumerState<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<_PlanForm> {
  late final _title = TextEditingController(text: widget.plan?.title ?? '');
  late final _focus = TextEditingController(text: widget.plan?.focusArea ?? '');
  late final _goals = TextEditingController(text: (widget.plan?.goals ?? const []).join('\n'));
  late final _description = TextEditingController(text: widget.plan?.description ?? '');
  late int _year = widget.plan?.year ?? DateTime.now().year;
  late String _brand = widget.plan?.brand ?? 'main';
  late String _status = widget.plan?.status.isNotEmpty == true ? widget.plan!.status : 'active';
  late String? _owner = widget.plan?.ownerId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _focus, _goals, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Give the plan a title.');
      return;
    }
    if (_focus.text.trim().isEmpty) {
      setState(() => _error = 'Choose the focus area of the plan.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'focusArea': _focus.text.trim(),
      'year': _year,
      'brand': _brand,
      'status': _status,
      'ownerId': _owner,
      'goals': [for (final g in _goals.text.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty)) g],
      'description': _description.text.trim(),
    };
    try {
      await ref.read(marketingStrategyServiceProvider).savePlan(body, id: widget.plan?.id);
      refreshStrategies(ref);
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

  @override
  Widget build(BuildContext context) => withStrategySetup(ref, _body);

  Widget _body(StrategySetup setup) {
    final editing = widget.plan != null;
    final thisYear = DateTime.now().year;
    final years = {for (var y = thisYear - 1; y <= thisYear + 3; y++) y, _year}.toList()..sort();
    return _formShell(
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(editing ? 'Edit strategic plan' : 'New strategic plan', style: mktText(19, weight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(key: const Key('plan_title'), controller: _title, decoration: strategyDec('Plan title')),
        const SizedBox(height: 10),
        TextField(key: const Key('plan_focus'), controller: _focus, decoration: strategyDec('Focus area', hint: 'Brand & Market Positioning')),
        _suggestions(setup.focusAreas, _focus, () => setState(() {})),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(key: const Key('plan_year'), isExpanded: true, initialValue: _year, decoration: strategyDec('Year'), items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))], onChanged: (v) => setState(() => _year = v ?? _year))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(key: const Key('plan_brand'), isExpanded: true, initialValue: _brand, decoration: strategyDec('Brand'), items: [for (final b in _brands) DropdownMenuItem(value: b.$1, child: Text(b.$2))], onChanged: (v) => setState(() => _brand = v ?? _brand))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(key: const Key('plan_status'), isExpanded: true, initialValue: _status, decoration: strategyDec('Status'), items: [for (final s in kPlanStatuses) DropdownMenuItem(value: s.$1, child: Text(s.$2))], onChanged: (v) => setState(() => _status = v ?? _status))),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String?>(
              key: const Key('plan_owner'),
              isExpanded: true,
              initialValue: setup.members.any((m) => m.id == _owner) ? _owner : null,
              decoration: strategyDec('Owner'),
              items: [const DropdownMenuItem<String?>(value: null, child: Text('No owner')), for (final m in setup.members) DropdownMenuItem<String?>(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _owner = v),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(key: const Key('plan_goals'), controller: _goals, minLines: 3, maxLines: 6, decoration: strategyDec('Key strategic goals (one per line)', hint: 'Increase qualified leads by 40%')),
        const SizedBox(height: 10),
        TextField(key: const Key('plan_description'), controller: _description, minLines: 2, maxLines: 3, decoration: strategyDec('Description')),
      ]),
      footer: StrategyFormFooter(keyPrefix: 'plan', saving: _saving, error: _error, onSave: _save, saveLabel: editing ? 'Save' : 'Create plan'),
    );
  }
}

// ── roadmap line ─────────────────────────────────────────────────────────────

Future<void> showRoadmapEditor(BuildContext context, WidgetRef ref, {RoadmapLine? line, int? year, int? quarter, String theme = ''}) => showStrategySheet<void>(context, _RoadmapForm(line: line, year: year, quarter: quarter, theme: theme), maxWidth: 520);

class _RoadmapForm extends ConsumerStatefulWidget {
  const _RoadmapForm({this.line, this.year, this.quarter, this.theme = ''});
  final RoadmapLine? line;
  final int? year, quarter;
  final String theme;
  @override
  ConsumerState<_RoadmapForm> createState() => _RoadmapFormState();
}

class _RoadmapFormState extends ConsumerState<_RoadmapForm> {
  late final _title = TextEditingController(text: widget.line?.title ?? '');
  late final _theme = TextEditingController(text: widget.line?.theme ?? widget.theme);
  late int _year = widget.line?.year ?? widget.year ?? DateTime.now().year;
  late int _quarter = widget.line?.quarter ?? widget.quarter ?? 1;
  late String _brand = widget.line?.brand ?? 'main';
  late String? _plan = widget.line?.planId;
  late String? _initiative = widget.line?.initiativeId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _theme.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Give the roadmap line a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{'title': _title.text.trim(), 'year': _year, 'quarter': _quarter, 'theme': _theme.text.trim(), 'brand': _brand, 'planId': _plan, 'initiativeId': _initiative};
    try {
      await ref.read(marketingStrategyServiceProvider).saveRoadmapLine(body, id: widget.line?.id);
      refreshStrategies(ref);
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

  @override
  Widget build(BuildContext context) => withStrategySetup(ref, _body);

  Widget _body(StrategySetup setup) {
    final editing = widget.line != null;
    final thisYear = DateTime.now().year;
    final years = {for (var y = thisYear - 1; y <= thisYear + 3; y++) y, _year}.toList()..sort();
    return _formShell(
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(editing ? 'Edit roadmap line' : 'New roadmap line', style: mktText(19, weight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(key: const Key('rm_title'), controller: _title, decoration: strategyDec('Milestone', hint: 'Brand consolidation')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(key: const Key('rm_year'), isExpanded: true, initialValue: _year, decoration: strategyDec('Year'), items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))], onChanged: (v) => setState(() => _year = v ?? _year))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<int>(key: const Key('rm_quarter'), isExpanded: true, initialValue: _quarter, decoration: strategyDec('Quarter'), items: [for (var q = 1; q <= 4; q++) DropdownMenuItem(value: q, child: Text('Q$q'))], onChanged: (v) => setState(() => _quarter = v ?? _quarter))),
        ]),
        const SizedBox(height: 10),
        TextField(key: const Key('rm_theme'), controller: _theme, decoration: strategyDec('Name of the quarter (theme)', hint: 'Foundation')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(key: const Key('rm_brand'), isExpanded: true, initialValue: _brand, decoration: strategyDec('Brand'), items: [for (final b in _brands) DropdownMenuItem(value: b.$1, child: Text(b.$2))], onChanged: (v) => setState(() => _brand = v ?? _brand)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          key: const Key('rm_plan'),
          isExpanded: true,
          initialValue: setup.plans.any((p) => p.id == _plan) ? _plan : null,
          decoration: strategyDec('Belongs to plan (optional)'),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('No plan')), for (final p in setup.plans) DropdownMenuItem<String?>(value: p.id, child: Text('${p.title} (${p.year})', overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => _plan = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          key: const Key('rm_initiative'),
          isExpanded: true,
          initialValue: setup.initiatives.any((p) => p.id == _initiative) ? _initiative : null,
          decoration: strategyDec('Belongs to initiative (optional)'),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('No initiative')), for (final p in setup.initiatives) DropdownMenuItem<String?>(value: p.id, child: Text(p.title, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => _initiative = v),
        ),
      ]),
      footer: StrategyFormFooter(keyPrefix: 'rm', saving: _saving, error: _error, onSave: _save, saveLabel: editing ? 'Save' : 'Add line'),
    );
  }
}

// ── research finding ─────────────────────────────────────────────────────────

Future<void> showFindingEditor(BuildContext context, WidgetRef ref, {Finding? finding}) => showStrategySheet<void>(context, _FindingForm(finding: finding), maxWidth: 560);

class _FindingForm extends ConsumerStatefulWidget {
  const _FindingForm({this.finding});
  final Finding? finding;
  @override
  ConsumerState<_FindingForm> createState() => _FindingFormState();
}

class _FindingFormState extends ConsumerState<_FindingForm> {
  late final _title = TextEditingController(text: widget.finding?.title ?? '');
  late final _summary = TextEditingController(text: widget.finding?.summary ?? '');
  late final _link = TextEditingController(text: widget.finding?.link ?? '');
  late final _tags = TextEditingController(text: (widget.finding?.tags ?? const []).join(', '));
  late String _kind = widget.finding?.kind.isNotEmpty == true ? widget.finding!.kind : 'market_insight';
  late String _brand = widget.finding?.brand ?? 'main';
  late DateTime _date = _day(widget.finding?.date) ?? DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _summary, _link, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Give the finding a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'kind': _kind,
      'summary': _summary.text.trim(),
      'link': _link.text.trim(),
      'brand': _brand,
      'date': TeamFilter.day(_date),
      'tags': [for (final t in _tags.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty)) t],
    };
    try {
      await ref.read(marketingStrategyServiceProvider).saveFinding(body, id: widget.finding?.id);
      refreshStrategies(ref);
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

  @override
  Widget build(BuildContext context) {
    final editing = widget.finding != null;
    return _formShell(
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(editing ? 'Edit finding' : 'Add a finding', style: mktText(19, weight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(key: const Key('fd_title'), controller: _title, decoration: strategyDec('Title', hint: 'Instagram growth trends – Nov 2026')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(key: const Key('fd_kind'), isExpanded: true, initialValue: _kind, decoration: strategyDec('Kind'), items: [for (final k in kFindingKinds) DropdownMenuItem(value: k.$1, child: Text(k.$2, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => _kind = v ?? _kind))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(key: const Key('fd_brand'), isExpanded: true, initialValue: _brand, decoration: strategyDec('Brand'), items: [for (final b in _brands) DropdownMenuItem(value: b.$1, child: Text(b.$2))], onChanged: (v) => setState(() => _brand = v ?? _brand))),
        ]),
        const SizedBox(height: 10),
        TextField(key: const Key('fd_summary'), controller: _summary, minLines: 3, maxLines: 6, decoration: strategyDec('What was found')),
        const SizedBox(height: 10),
        TextField(key: const Key('fd_link'), controller: _link, keyboardType: TextInputType.url, decoration: strategyDec('Link to the file (optional)', hint: 'https://drive.google.com/…')),
        const SizedBox(height: 10),
        TextField(key: const Key('fd_tags'), controller: _tags, decoration: strategyDec('Tags (comma separated)', hint: 'bridal, kerala')),
        const SizedBox(height: 10),
        MktPill(
          key: const Key('fd_date'),
          label: strategyDay(TeamFilter.day(_date), pattern: 'EEE d MMM yyyy'),
          icon: Icons.calendar_today_outlined,
          trailing: false,
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(now.year - 3), lastDate: DateTime(now.year + 1));
            if (d != null) setState(() => _date = d);
          },
        ),
      ]),
      footer: StrategyFormFooter(keyPrefix: 'fd', saving: _saving, error: _error, onSave: _save, saveLabel: editing ? 'Save' : 'Add finding'),
    );
  }
}

// ── review ───────────────────────────────────────────────────────────────────

Future<void> showReviewEditor(BuildContext context, WidgetRef ref, {StrategyReview? review, String type = 'strategy'}) => showStrategySheet<void>(context, _ReviewForm(review: review, type: type), maxWidth: 760);

class _OutcomeRow {
  _OutcomeRow({String text = '', this.state = 'achieved'}) : text = TextEditingController(text: text);
  final TextEditingController text;
  String state;
}

class _ActionRow {
  _ActionRow({this.id, String text = '', this.ownerId, this.priority = 'medium', this.target, this.status = 'open'}) : text = TextEditingController(text: text);
  final String? id;
  final TextEditingController text;
  String? ownerId;
  String priority, status;
  DateTime? target;
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({this.review, this.type = 'strategy'});
  final StrategyReview? review;
  final String type;
  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  late final _period = TextEditingController(text: widget.review?.periodLabel ?? '');
  late final _summary = TextEditingController(text: widget.review?.summary ?? '');
  late String _type = widget.review?.type.isNotEmpty == true ? widget.review!.type : widget.type;
  late String _brand = widget.review?.brand ?? 'main';
  late DateTime _date = _day(widget.review?.reviewDate) ?? DateTime.now();
  // what the review is about: 'plan:<id>', 'project:<id>' or 'initiative:<id>' (null = nothing named)
  late String? _link = widget.review?.linked == null ? null : '${widget.review!.linked!.kind}:${widget.review!.linked!.id}';
  late final List<_OutcomeRow> _outcomes = [for (final o in widget.review?.outcomes ?? const <ReviewOutcome>[]) _OutcomeRow(text: o.text, state: o.state)];
  late final List<_ActionRow> _actions = [for (final a in widget.review?.actionItems ?? const <ActionItem>[]) _ActionRow(id: a.id, text: a.text, ownerId: a.ownerId, priority: a.priority, target: _day(a.targetDate), status: a.status)];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_outcomes.isEmpty) _outcomes.add(_OutcomeRow());
  }

  @override
  void dispose() {
    _period.dispose();
    _summary.dispose();
    for (final o in _outcomes) {
      o.text.dispose();
    }
    for (final a in _actions) {
      a.text.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_period.text.trim().isEmpty) {
      setState(() => _error = 'Name the period or subject of the review (for example Q3 2026).');
      return;
    }
    final outcomes = [for (final o in _outcomes) if (o.text.text.trim().isNotEmpty) {'text': o.text.text.trim(), 'state': o.state}];
    if (outcomes.isEmpty) {
      setState(() => _error = 'Add at least one outcome — the score is counted from them.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'type': _type,
      'periodLabel': _period.text.trim(),
      'reviewDate': TeamFilter.day(_date),
      'brand': _brand,
      'summary': _summary.text.trim(),
      'outcomes': outcomes,
      'linkKind': _link?.split(':').first,
      'linkId': _link?.split(':').last,
      'actionItems': [
        for (final a in _actions)
          if (a.text.text.trim().isNotEmpty) {'id': a.id, 'text': a.text.text.trim(), 'ownerId': a.ownerId, 'priority': a.priority, 'targetDate': a.target == null ? null : TeamFilter.day(a.target!), 'status': a.status},
      ],
    };
    try {
      await ref.read(marketingStrategyServiceProvider).saveReview(body, id: widget.review?.id);
      refreshStrategies(ref);
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

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> set) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: current ?? now, firstDate: DateTime(now.year - 3), lastDate: DateTime(now.year + 2));
    if (d != null) setState(() => set(d));
  }

  @override
  Widget build(BuildContext context) => withStrategySetup(ref, _body);

  Widget _body(StrategySetup setup) {
    final editing = widget.review != null;
    return _formShell(
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(editing ? 'Edit review' : 'New review', style: mktText(19, weight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(key: const Key('rv_type'), isExpanded: true, initialValue: _type, decoration: strategyDec('Type'), items: [for (final t in kReviewTypes) DropdownMenuItem(value: t.$1, child: Text(t.$2, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => _type = v ?? _type))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(key: const Key('rv_brand'), isExpanded: true, initialValue: _brand, decoration: strategyDec('Brand'), items: [for (final b in _brands) DropdownMenuItem(value: b.$1, child: Text(b.$2))], onChanged: (v) => setState(() => _brand = v ?? _brand))),
        ]),
        const SizedBox(height: 10),
        TextField(key: const Key('rv_period'), controller: _period, decoration: strategyDec('Period or subject', hint: 'Q3 2026')),
        const SizedBox(height: 10),
        MktPill(key: const Key('rv_date'), label: strategyDay(TeamFilter.day(_date), pattern: 'EEE d MMM yyyy'), icon: Icons.calendar_today_outlined, trailing: false, onTap: () => _pickDate(_date, (d) => _date = d)),
        const SizedBox(height: 10),
        TextField(key: const Key('rv_summary'), controller: _summary, minLines: 2, maxLines: 4, decoration: strategyDec('Summary (optional)')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          key: const Key('rv_link'),
          isExpanded: true,
          initialValue: reviewLinkOptions(setup, widget.review?.linked).any((o) => o.$1 == _link) ? _link : null,
          decoration: strategyDec('What it reviews (optional) — its progress is shown with the review'),
          items: [for (final o in reviewLinkOptions(setup, widget.review?.linked)) DropdownMenuItem<String?>(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => _link = v),
        ),
        const SizedBox(height: 16),
        Text('Outcomes', style: mktText(13, weight: FontWeight.w800)),
        Text('What the team set out to do and how each one ended. The score is counted from these.', style: mktText(11.5, color: Mkt.inkSoft)),
        const SizedBox(height: 8),
        for (final (i, o) in _outcomes.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 280, child: TextField(key: Key('rv_outcome_text_$i'), controller: o.text, decoration: strategyDec('Outcome'))),
              SizedBox(width: 170, child: DropdownButtonFormField<String>(key: Key('rv_outcome_state_$i'), isExpanded: true, initialValue: o.state, decoration: strategyDec('Result'), items: [for (final s in kOutcomeStates) DropdownMenuItem(value: s.$1, child: Text(s.$2, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => o.state = v ?? o.state))),
              IconButton(key: Key('rv_outcome_del_$i'), tooltip: 'Remove', onPressed: _outcomes.length <= 1 ? null : () => setState(() => _outcomes.removeAt(i).text.dispose()), icon: const Icon(Icons.close_rounded, size: 18)),
            ]),
          ),
        TextButton.icon(key: const Key('rv_add_outcome'), onPressed: () => setState(() => _outcomes.add(_OutcomeRow())), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add outcome')),
        const SizedBox(height: 12),
        Text('Action items & next steps', style: mktText(13, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final (i, a) in _actions.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: Mkt.border), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: TextField(key: Key('rv_action_text_$i'), controller: a.text, decoration: strategyDec('Action'))),
                IconButton(key: Key('rv_action_del_$i'), tooltip: 'Remove', onPressed: () => setState(() => _actions.removeAt(i).text.dispose()), icon: const Icon(Icons.close_rounded, size: 18)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String?>(
                    key: Key('rv_action_owner_$i'),
                    isExpanded: true,
                    initialValue: setup.members.any((m) => m.id == a.ownerId) ? a.ownerId : null,
                    decoration: strategyDec('Owner'),
                    items: [const DropdownMenuItem<String?>(value: null, child: Text('No owner')), for (final m in setup.members) DropdownMenuItem<String?>(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() => a.ownerId = v),
                  ),
                ),
                SizedBox(width: 120, child: DropdownButtonFormField<String>(key: Key('rv_action_priority_$i'), isExpanded: true, initialValue: a.priority, decoration: strategyDec('Priority'), items: [for (final p in kPriorities) DropdownMenuItem(value: p.$1, child: Text(p.$2))], onChanged: (v) => setState(() => a.priority = v ?? a.priority))),
                SizedBox(width: 140, child: DropdownButtonFormField<String>(key: Key('rv_action_status_$i'), isExpanded: true, initialValue: a.status, decoration: strategyDec('Status'), items: [for (final s in kActionStatuses) DropdownMenuItem(value: s.$1, child: Text(s.$2, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => a.status = v ?? a.status))),
                KeyedSubtree(key: Key('rv_action_date_$i'), child: DayPickerField(label: 'Target date', value: a.target, lastYearsAhead: 2, onChanged: (d) => setState(() => a.target = d))),
              ]),
            ]),
          ),
        TextButton.icon(key: const Key('rv_add_action'), onPressed: () => setState(() => _actions.add(_ActionRow())), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add action item')),
      ]),
      footer: StrategyFormFooter(keyPrefix: 'rv', saving: _saving, error: _error, onSave: _save, saveLabel: editing ? 'Save' : 'Add review'),
    );
  }
}

/// The choices of a review's "what it reviews" picker: nothing, then every plan, development project and initiative ('kind:id' → label).
/// A link to a record that has since been cancelled or removed stays choosable, so editing the review does not drop it silently.
List<(String?, String)> reviewLinkOptions(StrategySetup setup, ReviewLink? current) {
  final out = <(String?, String)>[(null, 'Nothing in particular')];
  for (final p in setup.plans) {
    out.add(('plan:${p.id}', 'Plan · ${p.title} (${p.year})'));
  }
  for (final p in setup.projects) {
    out.add(('project:${p.id}', 'Project · ${p.title}'));
  }
  for (final i in setup.initiatives) {
    out.add(('initiative:${i.id}', 'Initiative · ${i.title}'));
  }
  if (current != null && !out.any((o) => o.$1 == '${current.kind}:${current.id}')) out.add(('${current.kind}:${current.id}', '${current.kindLabel} · ${current.title.isEmpty ? 'no longer listed' : current.title}'));
  return out;
}

