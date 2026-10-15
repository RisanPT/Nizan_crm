import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/features/hr/shared/hr_person_picker.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr/shift/data/shift_models.dart';
import 'package:nizan_crm/features/hr/shift/service/shift_service.dart';

const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

Color _hex(String s) {
  var h = s.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  return Color(int.tryParse(h, radix: 16) ?? 0xFF601A29);
}

String _fmt(DateTime? d) {
  if (d == null) return '—';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

/// HR Shift — define work shifts (window + grace + working days) and assign
/// employees to them (the roster). Informational; feeds attendance expectation.
class HrShiftScreen extends ConsumerWidget {
  const HrShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: crm.background,
        body: Column(
          children: [
            Material(
              color: crm.surface,
              child: TabBar(
                labelColor: crm.primary,
                unselectedLabelColor: crm.textSecondary,
                indicatorColor: crm.primary,
                tabs: const [Tab(text: 'Shifts'), Tab(text: 'Roster')],
              ),
            ),
            Expanded(child: TabBarView(children: [_ShiftsTab(crm: crm), _RosterTab(crm: crm)])),
          ],
        ),
      ),
    );
  }
}

class _ShiftsTab extends ConsumerWidget {
  const _ShiftsTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(shiftsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editShift(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Shift'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shiftsProvider),
        child: shifts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(shiftsProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('No shifts defined yet.', style: TextStyle(color: crm.textSecondary))),
                  )
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: list.map((s) => _shiftRow(context, ref, s)).toList(),
                ),
        ),
      ),
    );
  }

  Widget _shiftRow(BuildContext context, WidgetRef ref, Shift s) {
    final days = s.workingDays.map((d) => _dayNames[d % 7]).join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Container(width: 6, height: 40, decoration: BoxDecoration(color: _hex(s.color), borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text('${s.startTime}–${s.endTime} · grace ${s.graceInMin}/${s.graceOutMin}m',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                Text(days, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: crm.textSecondary), onPressed: () => _editShift(context, ref, s)),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: crm.textSecondary),
            onPressed: () async {
              try {
                await ref.read(shiftServiceProvider).deleteShift(s.id);
                ref.invalidate(shiftsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editShift(BuildContext context, WidgetRef ref, Shift? existing) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _ShiftEditor(existing: existing));
    if (ok == true) ref.invalidate(shiftsProvider);
  }
}

class _ShiftEditor extends ConsumerStatefulWidget {
  const _ShiftEditor({this.existing});
  final Shift? existing;
  @override
  ConsumerState<_ShiftEditor> createState() => _ShiftEditorState();
}

class _ShiftEditorState extends ConsumerState<_ShiftEditor> {
  late final TextEditingController _name;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late int _graceIn;
  late int _graceOut;
  late Set<int> _days;
  bool _busy = false;

  TimeOfDay _parse(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.tryParse(p.first) ?? 9, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  String _fmtTod(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _start = _parse(e?.startTime ?? '09:00');
    _end = _parse(e?.endTime ?? '18:00');
    _graceIn = e?.graceInMin ?? 10;
    _graceOut = e?.graceOutMin ?? 10;
    _days = {...(e?.workingDays ?? const [1, 2, 3, 4, 5, 6])};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _busy = true);
    final body = {
      'name': _name.text.trim(),
      'startTime': _fmtTod(_start),
      'endTime': _fmtTod(_end),
      'graceInMin': _graceIn,
      'graceOutMin': _graceOut,
      'workingDays': (_days.toList()..sort()),
    };
    try {
      final svc = ref.read(shiftServiceProvider);
      if (widget.existing == null) {
        await svc.createShift(body);
      } else {
        await svc.updateShift(widget.existing!.id, body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New shift' : 'Edit shift'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Shift name')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _start);
                      if (t != null) setState(() => _start = t);
                    },
                    child: Text('Start ${_fmtTod(_start)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _end);
                      if (t != null) setState(() => _end = t);
                    },
                    child: Text('End ${_fmtTod(_end)}'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _grace('Grace in (min)', _graceIn, (v) => setState(() => _graceIn = v))),
                const SizedBox(width: 10),
                Expanded(child: _grace('Grace out (min)', _graceOut, (v) => setState(() => _graceOut = v))),
              ]),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Working days', style: TextStyle(color: context.crmColors.textSecondary, fontSize: 12.5))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: List.generate(7, (i) {
                  return FilterChip(
                    label: Text(_dayNames[i]),
                    selected: _days.contains(i),
                    onSelected: (sel) => setState(() => sel ? _days.add(i) : _days.remove(i)),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }

  Widget _grace(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: context.crmColors.textSecondary)),
        Row(children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: value > 0 ? () => onChanged(value - 5) : null),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => onChanged(value + 5)),
        ]),
      ],
    );
  }
}

class _RosterTab extends ConsumerWidget {
  const _RosterTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(shiftAssignmentsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _assign(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Assign'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shiftAssignmentsProvider),
        child: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(shiftAssignmentsProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('No shift assignments yet.', style: TextStyle(color: crm.textSecondary))),
                  )
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: list.map((a) => _row(context, ref, a)).toList(),
                ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, ShiftAssignment a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.employeeName} · ${a.shiftName}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                Text('${_fmt(a.fromDate)} → ${a.toDate == null ? 'ongoing' : _fmt(a.toDate)}',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: crm.textSecondary),
            onPressed: () async {
              try {
                await ref.read(shiftServiceProvider).deleteAssignment(a.id);
                ref.invalidate(shiftAssignmentsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _AssignDialog());
    if (ok == true) ref.invalidate(shiftAssignmentsProvider);
  }
}

class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog();
  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  String? _employeeId;
  String? _shiftId;
  DateTime _from = DateTime.now();
  DateTime? _to;
  bool _busy = false;

  Future<void> _save() async {
    if (_employeeId == null || _shiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an employee and a shift')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(shiftServiceProvider).createAssignment(
            employeeId: _employeeId!,
            shiftId: _shiftId!,
            fromDate: _from,
            toDate: _to,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    final shifts = ref.watch(shiftsProvider);
    return AlertDialog(
      title: const Text('Assign shift'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            employees.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyErrorMessage(e)),
              data: (list) {
                final active = list.where((e) => e.status == 'active').toList();
                return PersonPickerField(
                  label: 'Employee',
                  icon: Icons.person_outline,
                  selectedId: _employeeId,
                  items: active.map((e) => PickerItem(id: e.id, name: e.name, department: e.department ?? '')).toList(),
                  onChanged: (v) => setState(() => _employeeId = v),
                );
              },
            ),
            const SizedBox(height: 10),
            shifts.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyErrorMessage(e)),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _shiftId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Shift'),
                items: list.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => _shiftId = v),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: context, initialDate: _from, firstDate: DateTime(2023), lastDate: DateTime(2030));
                    if (d != null) setState(() => _from = d);
                  },
                  child: Text('From ${_fmt(_from)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: context, initialDate: _to ?? _from, firstDate: _from, lastDate: DateTime(2031));
                    if (d != null) setState(() => _to = d);
                  },
                  child: Text(_to == null ? 'To (ongoing)' : 'To ${_fmt(_to)}'),
                ),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Assign'),
        ),
      ],
    );
  }
}
