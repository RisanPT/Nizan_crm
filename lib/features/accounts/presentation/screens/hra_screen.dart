import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/accounts/data/hra_record.dart';
import 'package:nizan_crm/features/accounts/controllers/hra_provider.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/reminder_popup.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

/// Accounts → HRA. House Rent Allowance recorded separately from salary:
/// pick an employee, enter the HRA amount + date. Lists all HRA payments.
// How many days ahead of an HRA payment date we treat it as "due soon" and
// surface it in the on-open reminder popup.
const _kHraDueSoonDays = 3;

class HraScreen extends ConsumerStatefulWidget {
  const HraScreen({super.key});

  @override
  ConsumerState<HraScreen> createState() => _HraScreenState();
}

class _HraScreenState extends ConsumerState<HraScreen> {
  // Fleet-style: the urgent-HRA popup fires once per screen visit.
  bool _remindersShown = false;

  void _refresh(WidgetRef ref) {
    ref.invalidate(hraRecordsProvider);
    ref.invalidate(hraStatsProvider);
  }

  int _daysUntil(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    return target.difference(today).inDays;
  }

  /// Pending HRA records due within [_kHraDueSoonDays] (or overdue), most urgent first.
  List<HraRecord> _urgentRecords(List<HraRecord> records) {
    final urgent = records
        .where((r) => !r.isPaid && _daysUntil(r.date) <= _kHraDueSoonDays)
        .toList()
      ..sort((a, b) => _daysUntil(a.date).compareTo(_daysUntil(b.date)));
    return urgent;
  }

  void _maybeShowReminders(List<HraRecord> records) {
    if (_remindersShown) return;
    final urgent = _urgentRecords(records);
    if (urgent.isEmpty) return;
    _remindersShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showReminderPopup(
        context,
        title: 'HRA Payments Due',
        items: urgent.map((r) {
          final days = _daysUntil(r.date);
          final String subtitle;
          if (days < 0) {
            subtitle = 'Payment overdue since ${_fmtDate(r.date)}';
          } else if (days == 0) {
            subtitle = 'Due today (${_fmtDate(r.date)})';
          } else {
            subtitle =
                'Due in $days ${days == 1 ? 'day' : 'days'} (${_fmtDate(r.date)})';
          }
          return ReminderItem(
            icon: Icons.home_work_outlined,
            title: '${r.employeeName} · ${_money(r.amount)}',
            subtitle: subtitle,
            overdue: days < 0,
          );
        }).toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final recordsAsync = ref.watch(hraRecordsProvider);
    final statsAsync = ref.watch(hraStatsProvider);

    // Fleet-style on-open reminder popup for overdue / due-soon HRA payments.
    if (recordsAsync.hasValue) _maybeShowReminders(recordsAsync.value!);

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: crm.primary,
        icon: const Icon(Icons.add_home_work_outlined, color: Colors.white),
        label: const Text('Add HRA', style: TextStyle(color: Colors.white)),
        onPressed: () => _openForm(context, ref),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text('House Rent Allowance (HRA)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            4.h,
            Text('HRA is paid separately from the monthly salary run.',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            14.h,
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (s) => _StatsRow(stats: s, crm: crm),
            ),
            16.h,
            recordsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Text('Error: $e', style: TextStyle(color: crm.destructive))),
              ),
              data: (records) {
                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.home_outlined, size: 56, color: crm.border),
                        12.h,
                        Text('No HRA recorded yet', style: TextStyle(color: crm.textSecondary)),
                        6.h,
                        Text('Tap "Add HRA" to pay an employee.',
                            style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                      ]),
                    ),
                  );
                }
                return Column(
                  children: records
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HraCard(
                              r: r,
                              crm: crm,
                              onEdit: () => _openForm(context, ref, existing: r),
                              onDelete: () => _delete(context, ref, r),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, HraRecord r) async {
    final crm = context.crmColors;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: crm.surface,
        title: const Text('Delete HRA record?'),
        content: Text('Delete ${_money(r.amount)} HRA for ${r.employeeName}?',
            style: TextStyle(color: crm.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: crm.destructive))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(hraServiceProvider).delete(r.id);
      _refresh(ref);
      messenger.showSnackBar(const SnackBar(content: Text('HRA record deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _openForm(BuildContext context, WidgetRef ref, {HraRecord? existing}) {
    showDialog(
      context: context,
      builder: (_) => _HraDialog(existing: existing, onSaved: () => _refresh(ref)),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.crm});
  final HraStats stats;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _tile('This Month', _money(stats.thisMonthAmount), Icons.calendar_month_rounded, crm.accent),
      _tile('Pending', _money(stats.pendingAmount), Icons.hourglass_bottom_rounded, crm.warning),
      _tile('Total Paid', _money(stats.totalAmount), Icons.home_work_rounded, crm.success),
      _tile('Employees', '${stats.employeeCount}', Icons.groups_rounded, crm.primary),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      final perRow = c.maxWidth >= 720 ? 4 : 2;
      const gap = 10.0;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: tiles.map((t) => SizedBox(width: w, child: t)).toList());
    });
  }

  Widget _tile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          8.h,
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: crm.textPrimary))),
          2.h,
          Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HraCard extends StatelessWidget {
  const _HraCard({required this.r, required this.crm, required this.onEdit, required this.onDelete});
  final HraRecord r;
  final CrmTheme crm;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Pending records surface their urgency (overdue / due soon) so a past-due
    // payment stands out from one that is simply scheduled for later.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(r.date.year, r.date.month, r.date.day);
    final daysUntil = target.difference(today).inDays;

    final Color statusColor;
    final String statusLabel;
    if (r.isPaid) {
      statusColor = crm.success;
      statusLabel = 'Paid';
    } else if (daysUntil < 0) {
      statusColor = crm.destructive;
      statusLabel = 'Overdue';
    } else if (daysUntil <= _kHraDueSoonDays) {
      statusColor = crm.warning;
      statusLabel = 'Due soon';
    } else {
      statusColor = crm.warning;
      statusLabel = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: crm.primary.withValues(alpha: 0.12),
            child: Text(
              r.employeeName.isNotEmpty ? r.employeeName[0].toUpperCase() : '?',
              style: TextStyle(color: crm.primary, fontWeight: FontWeight.w800),
            ),
          ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.employeeName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                2.h,
                Text('${r.department} · ${_fmtDate(r.date)} · ${r.paymentMethodLabel}',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (r.notes.isNotEmpty) ...[
                  4.h,
                  Text(r.notes, style: TextStyle(fontSize: 11.5, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          8.w,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(r.amount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: crm.textPrimary)),
              4.h,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: crm.textSecondary),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HraDialog extends ConsumerStatefulWidget {
  const _HraDialog({this.existing, required this.onSaved});
  final HraRecord? existing;
  final VoidCallback onSaved;
  @override
  ConsumerState<_HraDialog> createState() => _HraDialogState();
}

class _HraDialogState extends ConsumerState<_HraDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  String? _employeeId;
  DateTime _date = DateTime.now();
  String _paymentMethod = 'bank_transfer';
  String _status = 'pending';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountCtrl = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _employeeId = e?.employeeId;
    _date = e?.date ?? DateTime.now();
    _paymentMethod = e?.paymentMethod ?? 'bank_transfer';
    _status = e?.status ?? 'pending';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// This month's occurrence of a recurring HRA [day] (1–31), clamped to the
  /// number of days in the current month (e.g. 31 → 28/29/30 as applicable).
  DateTime _dateForHraDay(int day) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final d = day.clamp(1, daysInMonth);
    return DateTime(now.year, now.month, d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_employeeId == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final payload = {
        'employeeId': _employeeId,
        'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
        'date': _date.toIso8601String(),
        'paymentMethod': _paymentMethod,
        'status': _status,
        'notes': _notesCtrl.text.trim(),
      };
      final svc = ref.read(hraServiceProvider);
      if (widget.existing == null) {
        await svc.create(payload);
      } else {
        await svc.update(widget.existing!.id, payload);
      }
      widget.onSaved();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('HRA saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final employeesAsync = ref.watch(employeesProvider);
    final editing = widget.existing != null;

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editing ? 'Edit HRA' : 'Add HRA Payment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                16.h,
                // Employee picker
                employeesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load employees: $e', style: TextStyle(color: crm.destructive)),
                  data: (staff) => DropdownButtonFormField<String>(
                    initialValue: _employeeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Employee *'),
                    items: staff
                        .map((emp) => DropdownMenuItem(
                              value: emp.id,
                              child: Text('${emp.name} (${emp.department ?? emp.role ?? 'Staff'})',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    validator: (v) => (v == null || v.isEmpty) ? 'Select an employee' : null,
                    onChanged: editing
                        ? null
                        : (v) {
                            // Prefill the amount from the HRA configured on the
                            // employee record (set in the employee edit form).
                            // The user can still override before saving.
                            Employee? emp;
                            for (final e in staff) {
                              if (e.id == v) {
                                emp = e;
                                break;
                              }
                            }
                            setState(() {
                              _employeeId = v;
                              if (emp != null && emp.hra > 0) {
                                _amountCtrl.text = emp.hra.toStringAsFixed(0);
                              }
                              // Auto-fill the payment date from the employee's
                              // recurring HRA day-of-month (this month's occurrence).
                              if (emp != null && emp.hraDay > 0) {
                                _date = _dateForHraDay(emp.hraDay);
                              }
                            });
                          },
                  ),
                ),
                12.h,
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'HRA Amount (₹) *', prefixText: '₹ '),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter amount';
                        if (double.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  12.w,
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date *', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                        child: Text(_fmtDate(_date)),
                      ),
                    ),
                  ),
                ]),
                12.h,
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(labelText: 'Payment Mode'),
                      items: const [
                        DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _paymentMethod = v ?? 'bank_transfer'),
                    ),
                  ),
                  12.w,
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'pending'),
                    ),
                  ),
                ]),
                12.h,
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                20.h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                    8.w,
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
