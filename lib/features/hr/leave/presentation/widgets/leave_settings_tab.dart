// Settings tab (leave desk): the holiday calendar and leave types.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/leave/data/leave_models.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_common.dart';
import 'package:nizan_crm/features/hr/leave/service/leave_service.dart';

class LeaveSettingsTab extends ConsumerWidget {
  const LeaveSettingsTab({super.key, required this.canEditTypes});
  final bool canEditTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(leaveYearProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(holidaysProvider);
        ref.invalidate(leaveTypesProvider);
      },
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 980;
        final holidays = _HolidaysSection(year: year);
        final types = canEditTypes ? const _LeaveTypesSection() : null;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (wide && types != null)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: holidays),
                const SizedBox(width: 16),
                Expanded(child: types),
              ])
            else ...[
              holidays,
              if (types != null) ...[const SizedBox(height: 16), types],
            ],
          ],
        );
      }),
    );
  }
}

// ─── Holidays ────────────────────────────────────────────────────────────────
class _HolidaysSection extends ConsumerWidget {
  const _HolidaysSection({required this.year});
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final holidays = ref.watch(holidaysProvider);
    final today = leaveDay(DateTime.now());
    return LeaveSection(
      title: 'Holidays $year',
      subtitle: 'Not charged as leave. Add them in Timebox too, so both count days the same way.',
      trailing: FilledButton.tonalIcon(
        onPressed: () => _addHoliday(context, ref),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add'),
      ),
      child: holidays.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(holidaysProvider)),
        data: (raw) {
          final list = [...raw]..sort((a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
          if (list.isEmpty) {
            return const LeaveEmpty(
                icon: Icons.celebration_outlined, title: 'No holidays this year', body: 'Add festivals and closures here.');
          }
          return Column(
            children: list.map((h) {
              final past = h.date != null && leaveDay(h.date!).isBefore(today);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border))),
                child: Row(children: [
                  Container(
                    width: 46,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: (past ? crm.textSecondary : crm.primary).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(children: [
                      Text(h.date == null ? '—' : '${h.date!.day}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: past ? crm.textSecondary : crm.primary)),
                      Text(h.date == null ? '' : leaveFmtShort(h.date).split(' ').last,
                          style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.name,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: past ? crm.textSecondary : crm.textPrimary)),
                      Text('${h.date == null ? '' : leaveWeekday(h.date!)} · ${leaveStatusLabel(h.type)}',
                          style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Delete holiday',
                    icon: Icon(Icons.delete_outline, size: 18, color: crm.textSecondary),
                    onPressed: () => _delete(context, ref, h),
                  ),
                ]),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Holiday h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${h.name}?'),
        content: Text('${leaveFmt(h.date)} will count as a working day again.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(leaveServiceProvider).deleteHoliday(h.id);
      ref.invalidate(holidaysProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  Future<void> _addHoliday(BuildContext context, WidgetRef ref) async {
    final added = await showDialog<bool>(context: context, builder: (_) => const _AddHolidayDialog());
    if (added == true) ref.invalidate(holidaysProvider);
  }
}

class _AddHolidayDialog extends ConsumerStatefulWidget {
  const _AddHolidayDialog();
  @override
  ConsumerState<_AddHolidayDialog> createState() => _AddHolidayDialogState();
}

class _AddHolidayDialogState extends ConsumerState<_AddHolidayDialog> {
  final _name = TextEditingController();
  DateTime? _date;
  String _type = 'national';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _date == null) {
      setState(() => _error = 'Enter a name and pick a date.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(leaveServiceProvider).createHoliday(name: _name.text.trim(), date: _date!, type: _type);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final now = DateTime.now();
    return AlertDialog(
      title: const Text('Add holiday'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'Onam', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _date ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2));
              if (d != null) setState(() => _date = d);
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: Text(_date == null ? 'Pick date' : '${leaveWeekday(_date!)}, ${leaveFmt(_date)}'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 'national', child: Text('National')),
              DropdownMenuItem(value: 'regional', child: Text('Regional / festival')),
              DropdownMenuItem(value: 'optional', child: Text('Optional')),
              DropdownMenuItem(value: 'company', child: Text('Company')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'national'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.destructive)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Adding…' : 'Add holiday')),
      ],
    );
  }
}

// ─── Leave types ─────────────────────────────────────────────────────────────
class _LeaveTypesSection extends ConsumerWidget {
  const _LeaveTypesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final types = ref.watch(leaveTypesProvider);
    return LeaveSection(
      title: 'Leave types',
      subtitle: 'Quota is credited monthly (annual ÷ 12), January to December.',
      trailing: FilledButton.tonalIcon(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add'),
      ),
      child: types.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(leaveTypesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const LeaveEmpty(icon: Icons.category_outlined, title: 'No leave types yet');
          }
          return Column(
            children: list
                .map((t) => InkWell(
                      onTap: () => _edit(context, ref, t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border))),
                        child: Row(children: [
                          Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(color: leaveHex(t.color), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${t.name}${t.code.isNotEmpty ? ' (${t.code})' : ''}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: t.active ? crm.textPrimary : crm.textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  t.annualQuota > 0 ? '${leaveNum(t.annualQuota)} days a year' : 'No quota',
                                  t.paid ? 'Paid' : 'Unpaid',
                                  if (t.carryForward)
                                    'Carry forward${t.carryForwardMax > 0 ? ' up to ${leaveNum(t.carryForwardMax)}' : ''}',
                                ].join(' · '),
                                style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                              ),
                            ]),
                          ),
                          if (!t.active) leaveStatusChip('inactive', crm) else const SizedBox.shrink(),
                          Icon(Icons.chevron_right, size: 18, color: crm.textSecondary),
                        ]),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, LeaveType? t) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => LeaveTypeDialog(existing: t));
    if (saved == true) {
      ref.invalidate(leaveTypesProvider);
      ref.invalidate(myBalancesProvider);
    }
  }
}

class LeaveTypeDialog extends ConsumerStatefulWidget {
  const LeaveTypeDialog({super.key, this.existing});
  final LeaveType? existing;
  @override
  ConsumerState<LeaveTypeDialog> createState() => LeaveTypeDialogState();
}

class LeaveTypeDialogState extends ConsumerState<LeaveTypeDialog> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _quota;
  late final TextEditingController _cfMax;
  late bool _paid;
  late bool _carry;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _name = TextEditingController(text: t?.name ?? '');
    _code = TextEditingController(text: t?.code ?? '');
    _quota = TextEditingController(text: t == null ? '' : leaveNum(t.annualQuota));
    _cfMax = TextEditingController(text: t == null ? '' : leaveNum(t.carryForwardMax));
    _paid = t?.paid ?? true;
    _carry = t?.carryForward ?? false;
    _active = t?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _quota.dispose();
    _cfMax.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    final quota = double.tryParse(_quota.text.trim().isEmpty ? '0' : _quota.text.trim());
    final cfMax = double.tryParse(_cfMax.text.trim().isEmpty ? '0' : _cfMax.text.trim());
    if (quota == null || quota < 0 || cfMax == null || cfMax < 0) {
      setState(() => _error = 'Enter valid, non-negative numbers.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(leaveServiceProvider).saveType(
            id: widget.existing?.id ?? '',
            name: name,
            code: _code.text.trim(),
            annualQuota: quota,
            paid: _paid,
            carryForward: _carry,
            carryForwardMax: _carry ? cfMax : 0,
            active: _active,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add leave type' : 'Edit ${widget.existing!.name}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: _code,
                    decoration: const InputDecoration(labelText: 'Code (e.g. CL)', border: OutlineInputBorder(), isDense: true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _quota,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Annual quota (days)', border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text('0 = no quota (no balance check). Credited monthly: quota ÷ 12 per month.',
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Paid'),
              value: _paid,
              onChanged: (v) => setState(() => _paid = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Carry forward unused days'),
              value: _carry,
              onChanged: (v) => setState(() => _carry = v),
            ),
            if (_carry)
              TextField(
                controller: _cfMax,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Carry-forward max days (0 = nothing carries)', border: OutlineInputBorder(), isDense: true),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.destructive)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}
