import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/approvals/data/approval_models.dart';
import 'package:nizan_crm/features/hr/approvals/service/approval_service.dart';

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]}';
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

String _moduleLabel(String m) {
  switch (m) {
    case 'leave':
      return 'Leave';
    case 'regularization':
      return 'Regularization';
    case 'timesheet':
      return 'Timesheet';
    case 'reimbursement':
      return 'Reimbursement';
    case 'travel':
      return 'Travel';
    case 'comp_revision':
      return 'Compensation';
    case 'probation':
      return 'Probation';
    default:
      return m.isEmpty ? 'Request' : m[0].toUpperCase() + m.substring(1);
  }
}

/// HR Approvals — the inbox of requests awaiting this user's decision (leave and,
/// later, regularization/reimbursement/travel…) plus the requests this user
/// raised. Decisions flow through the generic backend approval engine.
class HrApprovalsScreen extends ConsumerWidget {
  const HrApprovalsScreen({super.key});

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
                tabs: const [Tab(text: 'Inbox'), Tab(text: 'My requests')],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _InboxTab(crm: crm),
                  _MineTab(crm: crm),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxTab extends ConsumerWidget {
  const _InboxTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(approvalInboxProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(approvalInboxProvider),
      child: inbox.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(approvalInboxProvider))]),
        data: (list) => list.isEmpty
            ? ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                      child: Text('Nothing awaiting your approval.',
                          style: TextStyle(color: crm.textSecondary))),
                )
              ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: list.map((a) => _ApprovalCard(a: a, crm: crm, actionable: true)).toList(),
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
    final mine = ref.watch(myApprovalsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myApprovalsProvider),
      child: mine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(myApprovalsProvider))]),
        data: (list) => list.isEmpty
            ? ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(child: Text('You have no requests.', style: TextStyle(color: crm.textSecondary))),
                )
              ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: list.map((a) => _ApprovalCard(a: a, crm: crm, actionable: false)).toList(),
              ),
      ),
    );
  }
}

class _ApprovalCard extends ConsumerStatefulWidget {
  const _ApprovalCard({required this.a, required this.crm, required this.actionable});
  final ApprovalRequest a;
  final CrmTheme crm;
  final bool actionable;

  @override
  ConsumerState<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<_ApprovalCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final note = await _askNote(approve);
    if (note == null) return; // dismissed
    setState(() => _busy = true);
    try {
      final svc = ref.read(approvalServiceProvider);
      if (approve) {
        await svc.approve(widget.a.id, note: note);
      } else {
        await svc.reject(widget.a.id, note: note);
      }
      ref.invalidate(approvalInboxProvider);
      ref.invalidate(myApprovalsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(approve ? 'Approved' : 'Rejected')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  Future<String?> _askNote(bool approve) {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve request' : 'Reject request'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: approve ? 'Note (optional)' : 'Reason',
            border: const OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text.trim()),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final crm = widget.crm;
    final sc = _statusColor(a.status, crm);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: hrCardDecoration(crm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
                child: Text(_moduleLabel(a.module),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.primary)),
              ),
              const Spacer(),
              hrStatusChip(a.status[0].toUpperCase() + a.status.substring(1), sc),
            ],
          ),
          const SizedBox(height: 8),
          Text(a.title.isEmpty ? _moduleLabel(a.module) : a.title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          if (a.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(a.summary, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (a.requesterName.isNotEmpty) ...[
                Icon(Icons.person_outline, size: 14, color: crm.textSecondary),
                const SizedBox(width: 4),
                Text(a.requesterName, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                const SizedBox(width: 12),
              ],
              if (a.createdAt != null) ...[
                Icon(Icons.schedule, size: 14, color: crm.textSecondary),
                const SizedBox(width: 4),
                Text(_fmt(a.createdAt), style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
              if (a.amount > 0) ...[
                const SizedBox(width: 12),
                Text('₹${a.amount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              ],
            ],
          ),
          if (a.currentStepLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Pending: ${a.currentStepLabel}',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary, fontStyle: FontStyle.italic)),
            ),
          if (widget.actionable && a.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: () => _decide(false),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: crm.destructive),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _decide(true),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
