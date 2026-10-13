import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr_shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/hr_regularization/data/regularization_models.dart';
import 'package:nizan_crm/features/hr_regularization/service/regularization_service.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/hr_approvals/service/approval_service.dart';

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

Color _statusColor(String s, CrmTheme crm) {
  switch (s) {
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

Widget _statusChip(String s, CrmTheme crm) =>
    hrStatusChip(s[0].toUpperCase() + s.substring(1), _statusColor(s, crm));

/// HR Attendance Regularization — employees request a correction for a day's
/// punch (missing/wrong time, WFH, on-duty); routed through approvals. An
/// approved record overrides the Timebox-derived day for payroll/reports.
class HrRegularizationScreen extends ConsumerWidget {
  const HrRegularizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);
    final hasEmployee = (session?.employeeId ?? '').isNotEmpty;
    final isManager = access.isFullAccess || access.isDepartmentHead || access.has('staff', false) || access.has('regularization', false);

    final tabs = <Tab>[
      if (hasEmployee) const Tab(text: 'My Requests'),
      if (isManager) const Tab(text: 'Team Requests'),
    ];
    final views = <Widget>[
      if (hasEmployee) _MineTab(crm: crm),
      if (isManager) _RequestsTab(crm: crm),
    ];
    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: crm.background,
        body: Center(child: Text('No employee record is linked to your account.', style: TextStyle(color: crm.textSecondary))),
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

class _MineTab extends ConsumerWidget {
  const _MineTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myRegularizationsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Regularize'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myRegularizationsProvider),
        child: mine.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(myRegularizationsProvider))]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('No regularization requests yet.', style: TextStyle(color: crm.textSecondary))),
                  )
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: list.map((r) => _row(context, ref, r, cancellable: true)).toList(),
                ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Regularization r, {bool cancellable = false}) {
    final times = [
      if (r.requestedInTime.isNotEmpty) 'in ${r.requestedInTime}',
      if (r.requestedOutTime.isNotEmpty) 'out ${r.requestedOutTime}',
    ].join(' · ');
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
                Text('${regularizationTypeLabel(r.type)} · ${_fmt(r.date)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                if (times.isNotEmpty) Text(times, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                if (r.reason.isNotEmpty)
                  Text(r.reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          _statusChip(r.status, crm),
          if (cancellable && r.status == 'pending')
            IconButton(
              icon: Icon(Icons.close, size: 18, color: crm.textSecondary),
              onPressed: () async {
                try {
                  await ref.read(regularizationServiceProvider).cancel(r.id);
                  ref.invalidate(myRegularizationsProvider);
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

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _RegularizeDialog());
    if (ok == true) {
      ref.invalidate(myRegularizationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Regularization submitted')));
      }
    }
  }
}

class _RegularizeDialog extends ConsumerStatefulWidget {
  const _RegularizeDialog();
  @override
  ConsumerState<_RegularizeDialog> createState() => _RegularizeDialogState();
}

class _RegularizeDialogState extends ConsumerState<_RegularizeDialog> {
  DateTime _date = DateTime.now();
  String _type = 'missing_punch';
  TimeOfDay? _in;
  TimeOfDay? _out;
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _fmtTod(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(regularizationServiceProvider).apply(
            date: _date,
            type: _type,
            requestedInTime: _in == null ? '' : _fmtTod(_in!),
            requestedOutTime: _out == null ? '' : _fmtTod(_out!),
            reason: _reason.text.trim(),
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
    return AlertDialog(
      title: const Text('Regularize attendance'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                    context: context, initialDate: _date, firstDate: DateTime(2023), lastDate: DateTime.now().add(const Duration(days: 1)));
                if (d != null) setState(() => _date = d);
              },
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('Date: ${_fmt(_date)}'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: kRegularizationTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(regularizationTypeLabel(t))))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? 'missing_punch'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _in ?? const TimeOfDay(hour: 9, minute: 0));
                    if (t != null) setState(() => _in = t);
                  },
                  child: Text(_in == null ? 'In time' : 'In ${_fmtTod(_in!)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _out ?? const TimeOfDay(hour: 18, minute: 0));
                    if (t != null) setState(() => _out = t);
                  },
                  child: Text(_out == null ? 'Out time' : 'Out ${_fmtTod(_out!)}'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
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
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'),
        ),
      ],
    );
  }
}

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
          title: const Text('Reject Regularization'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              hintText: 'e.g. Unverified punch record',
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
      ref.invalidate(regularizationRequestsProvider);
      ref.invalidate(approvalInboxProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Regularization approved' : 'Regularization rejected'),
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
    final reqs = ref.watch(regularizationRequestsProvider);
    final inbox = ref.watch(approvalInboxProvider).value ?? const [];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(regularizationRequestsProvider);
        ref.invalidate(approvalInboxProvider);
      },
      child: reqs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(regularizationRequestsProvider))]),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Team regularizations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                      Text('Review and approve attendance fixes directly or via inbox', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
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
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No requests.', style: TextStyle(color: crm.textSecondary))))
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
                                        regularizationTypeLabel(r.type),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crm.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Date: ${_fmt(r.date)}${r.requestedInTime.isNotEmpty ? ' · In: ${r.requestedInTime}' : ''}${r.requestedOutTime.isNotEmpty ? ' · Out: ${r.requestedOutTime}' : ''}',
                                  style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          _statusChip(r.status, crm),
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
