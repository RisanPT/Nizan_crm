import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart' show kDashBad, kDashGood;
import 'package:nizan_crm/features/it/domain/models/monthly_objective.dart';
import 'package:nizan_crm/features/it/services/monthly_objective_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

// The dialogs of monthly objectives: add / edit one (key results that are a number, a percentage or a yes/no; whether it runs several
// months), report progress on a key result, close the month out (a result for each — a note if it differs from the progress — then carry
// what is unfinished into the next month), and give a reason (to cancel or postpone one).

const kObjectiveAmber = Color(0xFFB7791F);
const _maxKeyResults = 8;

Color resultColor(ObjectiveResult r) => switch (r) {
  ObjectiveResult.achieved => kDashGood,
  ObjectiveResult.partly => kObjectiveAmber,
  ObjectiveResult.missed => kDashBad,
  ObjectiveResult.continued => const Color(0xFF2F6BB3),
  ObjectiveResult.cancelled => const Color(0xFF7A7A7A),
  ObjectiveResult.deferred => const Color(0xFF7B5EA7),
};

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

/// "25 / 40 screens" · "60%" · "Done" / "Not yet"
String progressText(MonthlyKeyResult k) => switch (k.kind) {
  KeyResultKind.yesno => k.completed ? 'Done' : 'Not yet',
  KeyResultKind.percent => '${_num(k.currentValue)}%',
  KeyResultKind.number => '${_num(k.currentValue)} / ${_num(k.targetValue)}${k.unit.isEmpty ? '' : ' ${k.unit}'}',
};

// ── add / edit ───────────────────────────────────────────────────────────────

class _KrRow {
  _KrRow({this.id, String title = '', String target = '', String unit = '', this.current, this.kind = 'number'})
    : title = TextEditingController(text: title),
      target = TextEditingController(text: target),
      unit = TextEditingController(text: unit);
  final String? id;
  final double? current; // what it has reached so far (an existing key result) — shown, not edited here
  String kind; // number | percent | yesno
  final TextEditingController title;
  final TextEditingController target;
  final TextEditingController unit;
  void dispose() {
    title.dispose();
    target.dispose();
    unit.dispose();
  }
}

/// Add an objective to [department]'s [month], or change [existing]. Returns true when something was saved.
Future<bool?> showMonthlyObjectiveEditor(
  BuildContext context, {
  required MonthlyDepartment department,
  required MonthKey month,
  MonthlyObjective? existing,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _ObjectiveEditor(department: department, month: month, existing: existing),
);

class _ObjectiveEditor extends ConsumerStatefulWidget {
  const _ObjectiveEditor({required this.department, required this.month, this.existing});
  final MonthlyDepartment department;
  final MonthKey month;
  final MonthlyObjective? existing;

  @override
  ConsumerState<_ObjectiveEditor> createState() => _ObjectiveEditorState();
}

class _ObjectiveEditorState extends ConsumerState<_ObjectiveEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(text: widget.existing?.objective ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.existing?.description ?? '');
  late String _priority = widget.existing?.priority ?? 'medium';
  late String? _ownerId = widget.existing?.ownerId;
  late final List<_KrRow> _krs = [
    for (final k in widget.existing?.keyResults ?? const <MonthlyKeyResult>[])
      _KrRow(id: k.id, title: k.title, target: _num(k.targetValue), unit: k.unit, current: k.currentValue, kind: k.kind.slug),
  ];
  late bool _multi = (widget.existing?.span?.total ?? 1) > 1;
  late int _spanMonths = widget.existing?.span?.total ?? 3;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _reason.dispose();
    for (final k in _krs) {
      k.dispose();
    }
    super.dispose();
  }

  /// Has the plan itself changed — the title, or a key result added, taken out, renamed, retyped or given another target?
  /// (The server decides what needs a reason; this only lets the form ask for it before sending.)
  bool _planChanged() {
    final e = widget.existing;
    if (e == null) return false;
    if (_title.text.trim() != e.objective) return true;
    final old = {for (final k in e.keyResults) k.id: k};
    if (_krs.length != old.length) return true;
    for (final r in _krs) {
      final o = old[r.id];
      if (o == null || r.title.text.trim() != o.title || r.kind != o.kind.slug) return true;
      if (r.kind == 'number' && (double.tryParse(r.target.text.trim()) ?? -1) != o.targetValue) return true;
    }
    return false;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(monthlyObjectiveServiceProvider);
    final krs = [
      for (final k in _krs)
        KeyResultInput(
          id: k.id,
          kind: k.kind,
          title: k.title.text.trim(),
          // a percentage is out of 100 and a yes/no is done or not: no target to type
          targetValue: switch (k.kind) {
            'percent' => 100,
            'yesno' => 1,
            _ => double.parse(k.target.text.trim()),
          },
          unit: k.kind == 'number' ? k.unit.text.trim() : '',
        ),
    ];
    final spanMonths = _multi ? _spanMonths : 1;
    try {
      if (_isEdit) {
        await service.update(
          widget.existing!,
          objective: _title.text.trim(),
          description: _desc.text.trim(),
          priority: _priority,
          ownerId: _ownerId,
          spanMonths: spanMonths,
          changeReason: _reason.text.trim(),
          keyResults: krs,
        );
      } else {
        await service.create(
          departmentId: widget.department.departmentId,
          month: widget.month,
          objective: _title.text.trim(),
          description: _desc.text.trim(),
          priority: _priority,
          ownerId: _ownerId,
          spanMonths: spanMonths,
          keyResults: krs,
        );
      }
      ref.invalidate(monthlyObjectivesProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  List<Employee> _staff(List<Employee> all) {
    final dept = widget.department.name.toLowerCase();
    final active = all.where((e) => e.isActive).toList();
    final inDept = active.where((e) => (e.department ?? '').trim().toLowerCase() == dept).toList();
    // a department the staff list does not name (or an owner outside it) must still be assignable
    final mine = inDept.isEmpty ? active : inDept;
    final id = _ownerId;
    if (id != null && !mine.any((e) => e.id == id)) {
      final chosen = all.where((e) => e.id == id).toList();
      return [...mine, ...chosen];
    }
    return mine;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final employees = ref.watch(employeesProvider).value ?? const <Employee>[];
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final priority = DropdownButtonFormField<String>(
      key: const Key('mo_form_priority'),
      initialValue: _priority,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Priority'),
      items: [
        for (final p in ['low', 'medium', 'high', 'critical']) DropdownMenuItem(value: p, child: Text('${p[0].toUpperCase()}${p.substring(1)}')),
      ],
      onChanged: (v) => setState(() => _priority = v ?? _priority),
    );
    final owner = EmployeePickerField(
      key: const Key('mo_form_owner'),
      employees: _staff(employees),
      selectedId: _ownerId,
      selectedName: widget.existing?.ownerName,
      label: 'Owner (optional)',
      allowUnassign: true,
      onChanged: (e) => setState(() => _ownerId = e?.id),
    );

    return Dialog(
      backgroundColor: crm.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 640 : double.infinity, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEdit ? 'Edit objective' : 'New objective',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary),
                          ),
                          Text('${widget.department.name} · ${monthTitle(widget.month)}', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Cancel',
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        key: const Key('mo_form_title'),
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Objective *', hintText: 'What should the department achieve this month?'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Give the objective a title.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('mo_form_desc'),
                        controller: _desc,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Details (optional)'),
                      ),
                      const SizedBox(height: 12),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: priority),
                            const SizedBox(width: 12),
                            Expanded(child: owner),
                          ],
                        )
                      else ...[
                        priority,
                        const SizedBox(height: 12),
                        owner,
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Key results',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                            ),
                          ),
                          Text('${_krs.length} of $_maxKeyResults', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'How you will know it is done: a number to reach, a percentage, or a yes / no. Progress follows them.',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < _krs.length; i++) _keyResultRow(crm, i),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('mo_form_add_kr'),
                          onPressed: _krs.length >= _maxKeyResults ? null : () => setState(() => _krs.add(_KrRow())),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add key result'),
                        ),
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        key: const Key('mo_form_span_switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Takes several months', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          'Progress keeps adding up from month to month, and the month-end carries it on instead of starting again.',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary),
                        ),
                        value: _multi,
                        onChanged: (v) => setState(() => _multi = v),
                      ),
                      if (_multi)
                        DropdownButtonFormField<int>(
                          key: const Key('mo_form_span_months'),
                          initialValue: _spanMonths,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Runs for', isDense: true),
                          items: [
                            for (final n in ({...List.generate(11, (i) => i + 2), _spanMonths}.toList()..sort()))
                              DropdownMenuItem(value: n, child: Text('$n months')),
                          ],
                          onChanged: (v) => setState(() => _spanMonths = v ?? _spanMonths),
                        ),
                      if (_isEdit && widget.existing!.planLocked) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('mo_form_reason'),
                          controller: _reason,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Why is the plan changing?',
                            helperText: 'This month has already started, so a change to the title or key results is kept with its reason.',
                            helperMaxLines: 3,
                          ),
                          validator: (v) => _planChanged() && (v ?? '').trim().length < 3 ? 'Say why the plan is changing.' : null,
                        ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            key: const Key('mo_form_error'),
                            style: TextStyle(color: crm.destructive, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(
                      key: const Key('mo_form_save'),
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(backgroundColor: crm.primary),
                      child: Text(_busy ? 'Saving…' : (_isEdit ? 'Save changes' : 'Add objective')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keyResultRow(CrmTheme crm, int i) {
    final k = _krs[i];
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final isNumber = k.kind == 'number';
    final title = TextFormField(
      key: Key('mo_form_kr_title_$i'),
      controller: k.title,
      decoration: InputDecoration(labelText: 'Key result ${i + 1}', hintText: 'e.g. Bookings closed', isDense: true),
      validator: (v) => (v ?? '').trim().isEmpty ? 'Name key result ${i + 1}.' : null,
    );
    final target = TextFormField(
      key: Key('mo_form_kr_target_$i'),
      controller: k.target,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Target', isDense: true),
      validator: (v) {
        final n = double.tryParse((v ?? '').trim());
        return n == null || n <= 0 ? 'Target above 0' : null;
      },
    );
    final unit = TextFormField(
      key: Key('mo_form_kr_unit_$i'),
      controller: k.unit,
      decoration: const InputDecoration(labelText: 'Unit', hintText: 'bookings', isDense: true),
    );
    // what kind of result it is: chips (not a dropdown) so removing a row above never leaves another showing the wrong choice
    final kinds = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final kind in KeyResultKind.values)
          ChoiceChip(
            key: Key('mo_form_kr_kind_${i}_${kind.slug}'),
            label: Text(kind.label, style: const TextStyle(fontSize: 12)),
            selected: k.kind == kind.slug,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => setState(() => k.kind = kind.slug),
          ),
      ],
    );
    final hint = switch (k.kind) {
      'percent' => 'Out of 100%. Report how far along it is.',
      'yesno' => 'Done or not done. Tick it when it is complete.',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: crm.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: crm.border.faded(2.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (narrow || !isNumber)
                    title
                  else
                    Row(
                      children: [
                        Expanded(flex: 5, child: title),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: target),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: unit),
                      ],
                    ),
                  if (narrow && isNumber) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: target),
                        const SizedBox(width: 8),
                        Expanded(child: unit),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  kinds,
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(hint, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                    ),
                ],
              ),
            ),
            IconButton(
              key: Key('mo_form_kr_remove_$i'),
              tooltip: 'Remove',
              icon: Icon(Icons.close, size: 18, color: crm.destructive),
              onPressed: () => setState(() => _krs.removeAt(i).dispose()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── report progress ──────────────────────────────────────────────────────────

/// Report progress on [kr]: the new number and / or "done". Returns true when it was saved.
Future<bool?> showKeyResultProgress(BuildContext context, {required MonthlyObjective objective, required MonthlyKeyResult kr}) => showDialog<bool>(
  context: context,
  builder: (_) => _KeyResultProgress(objective: objective, kr: kr),
);

class _KeyResultProgress extends ConsumerStatefulWidget {
  const _KeyResultProgress({required this.objective, required this.kr});
  final MonthlyObjective objective;
  final MonthlyKeyResult kr;

  @override
  ConsumerState<_KeyResultProgress> createState() => _KeyResultProgressState();
}

class _KeyResultProgressState extends ConsumerState<_KeyResultProgress> {
  late final TextEditingController _value = TextEditingController(text: _num(widget.kr.currentValue));
  late bool _done = widget.kr.completed;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kind = widget.kr.kind;
    // a yes/no has no number to give — it is only done or not
    double? v;
    if (kind != KeyResultKind.yesno) {
      v = double.tryParse(_value.text.trim());
      if (v == null || v < 0) {
        setState(
          () => _error = kind == KeyResultKind.percent ? 'Enter how far along it is (0 to 100).' : 'Enter the number reached so far (0 or more).',
        );
        return;
      }
      if (kind == KeyResultKind.percent && v > 100) {
        setState(() => _error = 'A percentage is out of 100.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // "done" is sent only when it changed — reaching the target marks it done by itself
      await ref
          .read(monthlyObjectiveServiceProvider)
          .checkIn(
            widget.objective.id,
            widget.kr.id,
            value: v,
            completed: kind == KeyResultKind.yesno || _done != widget.kr.completed ? _done : null,
          );
      ref.invalidate(monthlyObjectivesProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final k = widget.kr;
    return AlertDialog(
      backgroundColor: crm.surface,
      title: Text(k.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (k.kind) {
              KeyResultKind.yesno => k.completed ? 'Done so far' : 'Not done yet',
              KeyResultKind.percent => 'So far ${_num(k.currentValue)}% of 100%',
              KeyResultKind.number => 'Target ${_num(k.targetValue)}${k.unit.isEmpty ? '' : ' ${k.unit}'}  ·  so far ${_num(k.currentValue)}',
            }, style: TextStyle(color: crm.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            if (k.kind != KeyResultKind.yesno)
              TextField(
                key: const Key('mo_ci_value'),
                controller: _value,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: k.kind == KeyResultKind.percent ? 'How far along (0–100)' : 'Reached so far',
                  suffixText: k.kind == KeyResultKind.percent ? '%' : k.unit,
                ),
              ),
            CheckboxListTile(
              key: const Key('mo_ci_done'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _done,
              onChanged: (v) => setState(() => _done = v ?? false),
              title: Text(k.kind == KeyResultKind.yesno ? 'Done' : 'Mark as done'),
            ),
            if (k.checkIns.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Recent reports',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.textSecondary),
              ),
              for (final c in k.checkIns.reversed.take(3))
                Text(
                  '${k.kind == KeyResultKind.yesno ? (c.completed ? 'done' : 'not done') : _num(c.value)}${k.kind != KeyResultKind.yesno && c.completed ? ' · done' : ''}${c.byName.isEmpty ? '' : ' · ${c.byName}'}',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('mo_ci_error'),
                  style: TextStyle(color: crm.destructive, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          key: const Key('mo_ci_save'),
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: crm.primary),
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

// ── close the month out ──────────────────────────────────────────────────────

/// Close [department]'s [month]: a result for each objective still open, and carry what is unfinished into the next month.
/// Returns a one-line summary of what was done, or null if it was cancelled.
Future<String?> showCloseOut(BuildContext context, {required MonthlyDepartment department, required MonthKey month}) => showDialog<String>(
  context: context,
  builder: (_) => _CloseOut(department: department, month: month),
);

class _CloseRow {
  _CloseRow(this.objective) : result = objective.suggestedResult, carry = objective.hasWorkLeft && !objective.carriedTo;
  final MonthlyObjective objective;
  ObjectiveResult? result; // null: nothing measures it (no key results), so the head chooses
  bool carry;
  final note = TextEditingController();
}

class _CloseOut extends ConsumerStatefulWidget {
  const _CloseOut({required this.department, required this.month});
  final MonthlyDepartment department;
  final MonthKey month;

  @override
  ConsumerState<_CloseOut> createState() => _CloseOutState();
}

class _CloseOutState extends ConsumerState<_CloseOut> {
  late final List<_CloseRow> _rows = [for (final o in widget.department.objectives) _CloseRow(o)];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final r in _rows) {
      r.note.dispose();
    }
    super.dispose();
  }

  List<_CloseRow> get _toClose => _rows.where((r) => !r.objective.isClosed).toList();

  /// Can this one be carried? Not if it is achieved or cancelled (chosen now, or closed that way), has no result yet, or was already.
  bool _canCarry(_CloseRow r) {
    final result = r.objective.isClosed ? r.objective.result : r.result;
    if (result == null || r.objective.carriedTo) return false;
    return r.objective.hasWorkLeftAs(result);
  }

  /// What can be chosen: a several-month objective with months to go may simply continue; everything else is scored.
  List<ObjectiveResult> _choices(MonthlyObjective o) {
    final s = o.span;
    return s != null && !s.isFinal ? const [ObjectiveResult.continued, ObjectiveResult.achieved, ObjectiveResult.missed] : ObjectiveResult.scored;
  }

  /// Ended differently from what the progress points to — it says why.
  bool _needsWhy(_CloseRow r) => r.result != null && r.objective.suggestedResult != null && r.result != r.objective.suggestedResult;

  String? _problem() {
    for (final r in _toClose) {
      final o = r.objective;
      if (r.result == null) return 'Choose how “${o.objective}” ended.';
      if (_needsWhy(r) && r.note.text.trim().length < 3) {
        return 'Add a note for “${o.objective}”: its progress is ${o.progress}%, which points to ${o.suggestedResult!.label}, but you marked it ${r.result!.label}.';
      }
    }
    return null;
  }

  Future<void> _confirm() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(monthlyObjectiveServiceProvider);
    var closed = 0;
    try {
      for (final r in _toClose) {
        await service.close(r.objective.id, r.result!, note: r.note.text.trim());
        closed++;
      }
      final ids = [
        for (final r in _rows)
          if (r.carry && _canCarry(r)) r.objective.id,
      ];
      var carried = 0;
      if (ids.isNotEmpty) {
        carried = (await service.carryOver(departmentId: widget.department.departmentId, month: widget.month, ids: ids)).created.length;
      }
      ref.invalidate(monthlyObjectivesProvider);
      final next = monthTitle(nextMonthOf(widget.month));
      if (mounted) Navigator.pop(context, 'Closed $closed objective${closed == 1 ? '' : 's'}${carried > 0 ? ' · carried $carried into $next' : ''}');
    } catch (e) {
      ref.invalidate(monthlyObjectivesProvider); // whatever did close stays closed
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '${closed > 0 ? 'Closed $closed, then it stopped: ' : ''}${friendlyErrorMessage(e)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final next = monthTitle(nextMonthOf(widget.month));
    final carryCount = _rows.where((r) => r.carry && _canCarry(r)).length;
    final nothingToDo = _toClose.isEmpty && carryCount == 0;

    return Dialog(
      backgroundColor: crm.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 680, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Close out ${monthTitle(widget.month)}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary),
                        ),
                        Text('${widget.department.name} · how did each objective end?', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20), tooltip: 'Cancel'),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                children: [for (final r in _rows) _row(crm, r, next)],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                child: Text(
                  _error!,
                  key: const Key('mo_co_error'),
                  style: TextStyle(color: crm.destructive, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
              // the summary above the buttons, which wrap rather than overflow on a narrow phone
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (carryCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '$carryCount will be carried into $next',
                        key: const Key('mo_co_summary'),
                        style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                      FilledButton(
                        key: const Key('mo_co_confirm'),
                        onPressed: _busy || nothingToDo ? null : _confirm,
                        style: FilledButton.styleFrom(backgroundColor: crm.primary),
                        child: Text(_busy ? 'Closing…' : (_toClose.isEmpty ? 'Carry over' : 'Close out')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(CrmTheme crm, _CloseRow r, String next) {
    final o = r.objective;
    final closed = o.isClosed;
    final effective = closed ? o.result : r.result;
    final canCarry = _canCarry(r);
    final why = _needsWhy(r);
    return Padding(
      key: Key('mo_co_row_${o.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      // a Material, not a coloured Container: the checkbox row below is a ListTile, which paints its ink on the nearest Material
      child: Material(
        color: crm.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: crm.border.faded(2.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      o.objective,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${o.progress}%',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (closed)
                Row(
                  children: [
                    _resultChip(effective!),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_closedText(o, next), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ),
                  ],
                )
              else ...[
                // scrolls sideways rather than overflowing when the dialog is narrow (a phone) and the choices are wide
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ObjectiveResult>(
                    key: Key('mo_co_result_${o.id}'),
                    showSelectedIcon: false,
                    emptySelectionAllowed: o.suggestedResult == null, // nothing measures it: the choice starts empty
                    segments: [
                      for (final v in _choices(o))
                        ButtonSegment(
                          value: v,
                          label: Text(v.label, style: const TextStyle(fontSize: 12.5)),
                        ),
                    ],
                    selected: r.result == null ? <ObjectiveResult>{} : {r.result!},
                    onSelectionChanged: _busy
                        ? null
                        : (s) => setState(() {
                            r.result = s.isEmpty ? null : s.first;
                            r.carry = _canCarry(r); // achieved: nothing to carry; otherwise offer it
                          }),
                  ),
                ),
                if (why)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Progress is ${o.progress}%, which points to ${o.suggestedResult!.label}. Say why it ended as ${r.result!.label}.',
                      key: Key('mo_co_why_${o.id}'),
                      style: const TextStyle(fontSize: 12, color: kObjectiveAmber, fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  key: Key('mo_co_note_${o.id}'),
                  controller: r.note,
                  decoration: InputDecoration(isDense: true, hintText: why ? 'Why? (needed)' : 'A note on how it went (optional)'),
                ),
              ],
              if (canCarry)
                CheckboxListTile(
                  key: Key('mo_co_carry_${o.id}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: r.carry,
                  onChanged: _busy ? null : (v) => setState(() => r.carry = v ?? false),
                  title: Text(
                    o.span != null ? 'Continue into $next — keeps what has been done' : 'Carry what is left into $next',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _closedText(MonthlyObjective o, String next) => switch (o.result!) {
    ObjectiveResult.cancelled => 'Cancelled — not carried',
    ObjectiveResult.deferred => o.carriedTo ? 'Postponed — already in $next' : 'Postponed — not moved into $next yet',
    _ => o.carriedTo ? 'Already carried into $next' : 'Closed already',
  };

  Widget _resultChip(ObjectiveResult r) {
    final c = resultColor(r);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(
        r.label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c),
      ),
    );
  }
}

extension on MonthlyObjective {
  /// Is there work left if it ended as [r]? (An achieved or cancelled one has none; the rest depend on its key results.)
  bool hasWorkLeftAs(ObjectiveResult r) =>
      r != ObjectiveResult.achieved && r != ObjectiveResult.cancelled && (keyResults.isEmpty || keyResults.any((k) => k.attainment < 100));
}

// ── give a reason ────────────────────────────────────────────────────────────

/// Asks why — for cancelling or postponing an objective. Returns the reason, or null if it was cancelled.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String hint = 'Why?',
}) => showDialog<String>(
  context: context,
  builder: (_) => _ReasonDialog(title: title, message: message, confirmLabel: confirmLabel, hint: hint),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.message, required this.confirmLabel, required this.hint});
  final String title;
  final String message;
  final String confirmLabel;
  final String hint;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final ok = _text.text.trim().length >= 3;
    return AlertDialog(
      backgroundColor: crm.surface,
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: TextStyle(color: crm.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('mo_reason_text'),
              controller: _text,
              autofocus: true,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: widget.hint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('mo_reason_cancel'), onPressed: () => Navigator.pop(context), child: const Text('Not now')),
        FilledButton(
          key: const Key('mo_reason_confirm'),
          onPressed: ok ? () => Navigator.pop(context, _text.text.trim()) : null,
          style: FilledButton.styleFrom(backgroundColor: crm.primary),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
