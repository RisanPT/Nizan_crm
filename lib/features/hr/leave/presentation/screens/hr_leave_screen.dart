import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/leave/data/leave_models.dart';
import 'package:nizan_crm/features/hr/leave/service/leave_service.dart';
import 'package:nizan_crm/features/hr/approvals/service/approval_service.dart';

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

String _num(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

/// Confirm cancelling an APPROVED leave (the days go back to the balance).
Future<bool> _confirmCancel(BuildContext context, LeaveRequest r) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel approved leave?'),
      content: Text(
          '${r.employeeName.isNotEmpty ? '${r.employeeName} · ' : ''}${r.leaveTypeName.isEmpty ? 'Leave' : r.leaveTypeName}\n'
          '${_fmt(r.fromDate)} – ${_fmt(r.toDate)} · ${_num(r.days)} day(s)\n\n'
          'The days go back to the leave balance.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cancel leave')),
      ],
    ),
  );
  return ok == true;
}

Color _statusColor(String status, CrmTheme crm) {
  switch (status) {
    case 'approved':
      return crm.success;
    case 'rejected':
      return crm.destructive;
    case 'cancelled':
      return crm.textSecondary;
    default:
      return crm.warning;
  }
}

/// HR Leave — employee self-service (apply + my balances + my requests) plus, for
/// managers/HR, the team Requests list and the Holiday calendar. Approving is
/// done in the Approvals inbox.
class HrLeaveScreen extends ConsumerWidget {
  const HrLeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);
    final isManager = access.isFullAccess || access.isDepartmentHead;
    final hasEmployee = (session?.employeeId ?? '').isNotEmpty;
    // Leave types are company master data — only HR-wide users (server decides).
    final canEditTypes = isManager && (ref.watch(leaveMasterAccessProvider).value ?? false);

    final tabs = <Tab>[
      if (hasEmployee) const Tab(text: 'My Leave'),
      if (isManager) const Tab(text: 'Requests'),
      if (isManager) const Tab(text: 'Holidays'),
      if (canEditTypes) const Tab(text: 'Leave Types'),
    ];
    final views = <Widget>[
      if (hasEmployee) _MyLeaveTab(crm: crm),
      if (isManager) _RequestsTab(crm: crm, ownEmployeeId: session?.employeeId ?? ''),
      if (isManager) _HolidaysTab(crm: crm),
      if (canEditTypes) _LeaveTypesTab(crm: crm),
    ];

    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: crm.background,
        body: Center(
          child: Text('No employee record is linked to your account.',
              style: TextStyle(color: crm.textSecondary)),
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: crm.background,
        body: Column(
          children: [
            Material(
              color: crm.surface,
              child: TabBar(
                isScrollable: true,
                labelColor: crm.primary,
                unselectedLabelColor: crm.textSecondary,
                indicatorColor: crm.primary,
                tabs: tabs,
              ),
            ),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
      ),
    );
  }
}

// ─── My Leave ───────────────────────────────────────────────────────────────
class _MyLeaveTab extends ConsumerWidget {
  const _MyLeaveTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(myBalancesProvider);
    final mine = ref.watch(myLeaveProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myBalancesProvider);
        ref.invalidate(myLeaveProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('My leave',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              ),
              FilledButton.icon(
                onPressed: () => _openApplyDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Apply for leave'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          balances.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(myBalancesProvider)),
            data: (list) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: list
                  .map((b) => _balanceCard(b))
                  .toList(),
            ),
          ),
          const SizedBox(height: 22),
          Text('Requests',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          const SizedBox(height: 8),
          mine.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(myLeaveProvider)),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                        child: Text('No leave requests yet.',
                            style: TextStyle(color: crm.textSecondary))))
                : Column(
                    children: list.map((r) => _requestRow(context, ref, r, cancellable: true)).toList()),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(LeaveBalance b) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: hrCardDecoration(crm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: _hex(b.color), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(b.name,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary))),
          ]),
          const SizedBox(height: 8),
          if (b.limited) ...[
            Text(_num(b.available),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: b.available < 0 ? crm.destructive : crm.primary)),
            Text(b.available < 0 ? 'overdrawn' : 'available',
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            const SizedBox(height: 6),
            _balLine('Credited so far', b.credited),
            if (b.carriedForward > 0) _balLine('Carried forward', b.carriedForward),
            _balLine('Used', b.used),
            if (b.pending > 0) _balLine('Pending', b.pending),
            _balLine('Annual quota', b.allocated),
          ] else ...[
            Text(_num(b.used),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: crm.primary)),
            Text(b.paid ? 'used · no quota' : 'used · unpaid',
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            if (b.pending > 0) _balLine('Pending', b.pending),
          ],
        ],
      ),
    );
  }

  Widget _balLine(String label, double v) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary))),
          Text(_num(v), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textPrimary)),
        ]),
      );

  /// Own approved leave can be cancelled before its start date.
  bool _ownCancellable(LeaveRequest r) {
    if (r.status == 'pending') return true;
    if (r.status != 'approved' || r.fromDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(r.fromDate!.year, r.fromDate!.month, r.fromDate!.day);
    return start.isAfter(today);
  }

  Widget _requestRow(BuildContext context, WidgetRef ref, LeaveRequest r, {bool cancellable = false}) {
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
                Text(
                  '${r.leaveTypeName.isEmpty ? 'Leave' : r.leaveTypeName} · ${r.days.toStringAsFixed(r.days % 1 == 0 ? 0 : 1)} day(s)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
                const SizedBox(height: 2),
                Text('${_fmt(r.fromDate)} – ${_fmt(r.toDate)}',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                if (r.reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(r.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  ),
              ],
            ),
          ),
          _statusChip(r.status),
          if (cancellable && _ownCancellable(r))
            IconButton(
              tooltip: r.status == 'approved' ? 'Cancel approved leave' : 'Cancel',
              icon: Icon(Icons.close, size: 18, color: crm.textSecondary),
              onPressed: () async {
                if (r.status == 'approved' && !await _confirmCancel(context, r)) return;
                try {
                  await ref.read(leaveServiceProvider).cancel(r.id);
                  ref.invalidate(myLeaveProvider);
                  ref.invalidate(myBalancesProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) =>
      hrStatusChip(status[0].toUpperCase() + status.substring(1), _statusColor(status, crm));

  Future<void> _openApplyDialog(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ApplyLeaveDialog(),
    );
    if (ok == true) {
      ref.invalidate(myLeaveProvider);
      ref.invalidate(myBalancesProvider);
      ref.invalidate(approvalInboxProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Leave request submitted')));
      }
    }
  }
}

// ─── Apply dialog ─────────────────────────────────────────────────────────
class _ApplyLeaveDialog extends ConsumerStatefulWidget {
  const _ApplyLeaveDialog();
  @override
  ConsumerState<_ApplyLeaveDialog> createState() => _ApplyLeaveDialogState();
}

class _ApplyLeaveDialogState extends ConsumerState<_ApplyLeaveDialog> {
  String? _typeId;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String _halfDay = 'none';
  final _reason = TextEditingController();
  bool _submitting = false;
  String? _error; // the server's rejection message, shown inside the form

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) {
      setState(() {
        _error = null;
        if (from) {
          _from = d;
          if (_to.isBefore(d)) _to = d;
        } else {
          _to = d;
          if (_from.isAfter(d)) _from = d;
        }
      });
    }
  }

  double get _calculatedDays {
    final diff = _to.difference(_from).inDays + 1;
    if (diff <= 1 && _halfDay != 'none') return 0.5;
    return diff.toDouble();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(leaveServiceProvider).apply(
            leaveTypeId: _typeId,
            from: _from,
            to: _to,
            halfDay: _halfDay,
            reason: _reason.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // Shown inside the dialog — a snackbar would sit behind it.
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final types = ref.watch(leaveTypesProvider);
    final days = _calculatedDays;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.beach_access_rounded, color: crm.primary, size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('Apply for Leave', maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Leave Type Dropdown with safe fallback
            types.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive)),
              data: (all) {
                final list = all.where((t) => t.active).toList();
                final safeItems = list.isNotEmpty
                    ? list
                    : const [
                        LeaveType(id: 'cl', name: 'Casual Leave'),
                        LeaveType(id: 'sl', name: 'Sick Leave'),
                        LeaveType(id: 'el', name: 'Earned Leave'),
                        LeaveType(id: 'lwp', name: 'Unpaid Leave (LWP)'),
                      ];
                final currentId = _typeId ?? safeItems.first.id;
                final selectedVal = safeItems.any((t) => t.id == currentId) ? currentId : safeItems.first.id;
                if (_typeId != selectedVal) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _typeId = selectedVal);
                  });
                }

                return DropdownButtonFormField<String>(
                  key: ValueKey('leave_type_$selectedVal'),
                  initialValue: selectedVal,
                  isExpanded: true,
                  dropdownColor: crm.surface,
                  style: TextStyle(color: crm.textPrimary, fontSize: 13.5),
                  decoration: const InputDecoration(
                    labelText: 'Leave Type *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: safeItems
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _hex(t.color),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(t.name,
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: crm.textPrimary, fontSize: 13.5)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _typeId = v;
                        _error = null;
                      });
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 14),

            // Date Range Pickers
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pick(true),
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'From Date *',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                      ),
                      child: Text(
                        _fmt(_from),
                        style: TextStyle(color: crm.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _pick(false),
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'To Date *',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.event_available_rounded, size: 16),
                      ),
                      child: Text(
                        _fmt(_to),
                        style: TextStyle(color: crm.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Half-Day & Duration Summary
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _halfDay,
                    isExpanded: true,
                    dropdownColor: crm.surface,
                    style: TextStyle(color: crm.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Day Portion',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('Full Day')),
                      DropdownMenuItem(value: 'first', child: Text('First Half (Morning)')),
                      DropdownMenuItem(value: 'second', child: Text('Second Half (Afternoon)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _halfDay = v;
                          _error = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: crm.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 16, color: crm.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${_num(days)} calendar day${days == 1 ? '' : 's'}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: crm.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Weekly offs and holidays inside the dates are not charged.',
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            const SizedBox(height: 12),

            // Reason field
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 3,
              style: TextStyle(color: crm.textPrimary, fontSize: 13.5),
              decoration: const InputDecoration(
                labelText: 'Reason for leave',
                hintText: 'e.g. Attending family function',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: crm.destructive.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: crm.destructive.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: crm.destructive),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.destructive)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 16),
          label: const Text('Submit Application'),
        ),
      ],
    );
  }
}

// ─── Requests (manager / HR) ───────────────────────────────────────────────
class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab({required this.crm, this.ownEmployeeId = ''});
  final CrmTheme crm;
  final String ownEmployeeId;

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab> {
  String? _actingId;

  /// Manager cancels an approved leave (any time, inside their scope).
  Future<void> _cancelApproved(LeaveRequest r) async {
    if (!await _confirmCancel(context, r)) return;
    setState(() => _actingId = r.id);
    try {
      await ref.read(leaveServiceProvider).cancel(r.id);
      ref.invalidate(leaveRequestsProvider);
      ref.invalidate(myBalancesProvider);
      ref.invalidate(myLeaveProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Leave cancelled')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  Future<void> _handleDecision(String approvalId, bool approve) async {
    String note = '';
    if (!approve) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject Leave Request'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              hintText: 'e.g. Critical studio coverage required',
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      note = ctrl.text.trim();
    }

    setState(() => _actingId = approvalId);
    try {
      if (approve) {
        await ref.read(approvalServiceProvider).approve(approvalId, note: note);
      } else {
        await ref.read(approvalServiceProvider).reject(approvalId, note: note);
      }
      ref.invalidate(leaveRequestsProvider);
      ref.invalidate(approvalInboxProvider);
      ref.invalidate(myBalancesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Leave request approved' : 'Leave request rejected'),
            backgroundColor: approve ? widget.crm.success : widget.crm.destructive,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = widget.crm;
    final reqs = ref.watch(leaveRequestsProvider);
    final inbox = ref.watch(approvalInboxProvider).value ?? const [];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaveRequestsProvider);
        ref.invalidate(approvalInboxProvider);
      },
      child: reqs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(leaveRequestsProvider))]),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Team leave requests',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                      Text('Review and approve time-off applications directly or via inbox',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/hr/approvals'),
                  icon: const Icon(Icons.inbox_outlined, size: 16),
                  label: const Text('Approvals Inbox'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: crm.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('No requests.', style: TextStyle(color: crm.textSecondary))),
              )
            else
              ...list.map((r) {
                String approvalId = r.approvalId;
                if (approvalId.isEmpty) {
                  final m = inbox.where((a) => a.refId == r.id).firstOrNull;
                  if (m != null) approvalId = m.id;
                }
                final isPending = r.status == 'pending';
                final canAct = isPending && approvalId.isNotEmpty;
                final isActing = _actingId == approvalId;
                // Own leave is cancelled from My Leave, not with manager rights.
                final canCancel = r.status == 'approved' &&
                    (widget.ownEmployeeId.isEmpty || r.employeeId != widget.ownEmployeeId);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: hrCardDecoration(crm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: r.employeeId.isNotEmpty
                                          ? () => context.push('/staff/${r.employeeId}')
                                          : null,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Text(
                                        r.employeeName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: crm.primary,
                                          decoration: TextDecoration.underline,
                                          decorationColor: crm.primary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: crm.border.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        r.leaveTypeName.isEmpty ? 'Leave' : r.leaveTypeName,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crm.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_fmt(r.fromDate)} – ${_fmt(r.toDate)} · ${r.days.toStringAsFixed(r.days % 1 == 0 ? 0 : 1)} day(s)',
                                  style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          _StatusPill(status: r.status, crm: crm),
                        ],
                      ),
                      if (r.reason.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: crm.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            r.reason,
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: crm.textPrimary),
                          ),
                        ),
                      ],
                      if (canAct) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isActing)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            else ...[
                              OutlinedButton.icon(
                                onPressed: () => _handleDecision(approvalId, false),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: crm.destructive,
                                  side: BorderSide(color: crm.destructive.withValues(alpha: 0.5)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () => _handleDecision(approvalId, true),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Approve'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: crm.success,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (canCancel) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _actingId == r.id
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : OutlinedButton.icon(
                                  onPressed: () => _cancelApproved(r),
                                  icon: const Icon(Icons.event_busy_rounded, size: 16),
                                  label: const Text('Cancel leave'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: crm.destructive,
                                    side: BorderSide(color: crm.destructive.withValues(alpha: 0.5)),
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ─── Holidays (manager / HR) ───────────────────────────────────────────────
class _HolidaysTab extends ConsumerWidget {
  const _HolidaysTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidays = ref.watch(holidaysProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(holidaysProvider),
      child: holidays.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(holidaysProvider))]),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(children: [
              Expanded(
                child: Text('Holiday calendar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              ),
              FilledButton.icon(
                onPressed: () => _addHoliday(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add holiday'),
              ),
            ]),
            const SizedBox(height: 14),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('No holidays yet.', style: TextStyle(color: crm.textSecondary))),
              )
            else
              ...list.map((h) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: hrCardDecoration(crm),
                    child: Row(
                      children: [
                        SizedBox(width: 92, child: Text(_fmt(h.date), style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
                        Expanded(
                            child: Text(h.name,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary))),
                        Text(h.type, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: crm.textSecondary),
                          onPressed: () async {
                            try {
                              await ref.read(leaveServiceProvider).deleteHoliday(h.id);
                              ref.invalidate(holidaysProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _addHoliday(BuildContext context, WidgetRef ref) async {
    final nameCtl = TextEditingController();
    DateTime? date;
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add holiday'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Holiday name')),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                      context: ctx, initialDate: date ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2));
                  if (d != null) setState(() => date = d);
                },
                child: Text(date == null ? 'Pick date' : _fmt(date)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtl.text.trim().isEmpty || date == null) return;
                try {
                  await ref.read(leaveServiceProvider).createHoliday(name: nameCtl.text.trim(), date: date!);
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nameCtl.dispose();
    if (added == true) ref.invalidate(holidaysProvider);
  }
}

// ─── Leave types (HR-wide only) ──────────────────────────────────────────────
class _LeaveTypesTab extends ConsumerWidget {
  const _LeaveTypesTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(leaveTypesProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(leaveTypesProvider),
      child: types.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(leaveTypesProvider))]),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Leave types',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                  Text('Quota is credited monthly (annual ÷ 12), Jan–Dec',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ]),
              ),
              FilledButton.icon(
                onPressed: () => _edit(context, ref, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add type'),
              ),
            ]),
            const SizedBox(height: 14),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('No leave types yet.', style: TextStyle(color: crm.textSecondary))),
              )
            else
              ...list.map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: hrCardDecoration(crm),
                    child: Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: _hex(t.color), shape: BoxShape.circle)),
                      const SizedBox(width: 10),
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
                              t.annualQuota > 0 ? '${_num(t.annualQuota)} days/yr' : 'No quota',
                              t.paid ? 'Paid' : 'Unpaid',
                              if (t.carryForward)
                                'Carry forward${t.carryForwardMax > 0 ? ' up to ${_num(t.carryForwardMax)}' : ''}',
                              if (!t.active) 'Inactive',
                            ].join(' · '),
                            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                          ),
                        ]),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        icon: Icon(Icons.edit_outlined, size: 18, color: crm.textSecondary),
                        onPressed: () => _edit(context, ref, t),
                      ),
                    ]),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, LeaveType? t) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _LeaveTypeDialog(existing: t));
    if (saved == true) {
      ref.invalidate(leaveTypesProvider);
      ref.invalidate(myBalancesProvider);
    }
  }
}

class _LeaveTypeDialog extends ConsumerStatefulWidget {
  const _LeaveTypeDialog({this.existing});
  final LeaveType? existing;
  @override
  ConsumerState<_LeaveTypeDialog> createState() => _LeaveTypeDialogState();
}

class _LeaveTypeDialogState extends ConsumerState<_LeaveTypeDialog> {
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
    _quota = TextEditingController(text: t == null ? '' : _num(t.annualQuota));
    _cfMax = TextEditingController(text: t == null ? '' : _num(t.carryForwardMax));
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.crm});
  final String status;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) =>
      hrStatusChip(status[0].toUpperCase() + status.substring(1), _statusColor(status, crm));
}
