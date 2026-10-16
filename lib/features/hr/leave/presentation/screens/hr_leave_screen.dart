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

    final tabs = <Tab>[
      if (hasEmployee) const Tab(text: 'My Leave'),
      if (isManager) const Tab(text: 'Requests'),
      if (isManager) const Tab(text: 'Holidays'),
    ];
    final views = <Widget>[
      if (hasEmployee) _MyLeaveTab(crm: crm),
      if (isManager) _RequestsTab(crm: crm),
      if (isManager) _HolidaysTab(crm: crm),
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
          Text(b.available.toStringAsFixed(b.available % 1 == 0 ? 0 : 1),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: crm.primary)),
          Text(b.paid
              ? 'of ${b.allocated.toStringAsFixed(0)} left'
              : 'unpaid',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ],
      ),
    );
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
          if (cancellable && r.status == 'pending')
            IconButton(
              tooltip: 'Cancel',
              icon: Icon(Icons.close, size: 18, color: crm.textSecondary),
              onPressed: () async {
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
  DateTime? _from;
  DateTime? _to;
  final _reason = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) {
      setState(() {
        if (from) {
          _from = d;
          if (_to == null || _to!.isBefore(d)) _to = d;
        } else {
          _to = d;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick the leave dates')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(leaveServiceProvider).apply(
            leaveTypeId: _typeId,
            from: _from!,
            to: _to!,
            reason: _reason.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final types = ref.watch(leaveTypesProvider);
    return AlertDialog(
      title: const Text('Apply for leave'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            types.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive)),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _typeId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Leave type'),
                items: list
                    .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => _typeId = v),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(true),
                  child: Text(_from == null ? 'From date' : _fmt(_from)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(false),
                  child: Text(_to == null ? 'To date' : _fmt(_to)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }
}

// ─── Requests (manager / HR) ───────────────────────────────────────────────
class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab({required this.crm});
  final CrmTheme crm;

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab> {
  String? _actingId;

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
                                Row(
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
                                    const SizedBox(width: 8),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.crm});
  final String status;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) =>
      hrStatusChip(status[0].toUpperCase() + status.substring(1), _statusColor(status, crm));
}
