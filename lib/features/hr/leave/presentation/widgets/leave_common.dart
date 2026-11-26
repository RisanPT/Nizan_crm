// Shared bits for the Leave management screen: formatting, status/source
// chips, the approve / reject / cancel actions and the "reload everything"
// helper used by the live refresh.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/approvals/presentation/widgets/hr_reason_dialog.dart';
import 'package:nizan_crm/features/hr/approvals/service/approval_service.dart';
import 'package:nizan_crm/features/hr/leave/data/leave_models.dart';
import 'package:nizan_crm/features/hr/leave/service/leave_service.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';

const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const leaveMonthNames = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

Color leaveHex(String s) {
  var h = s.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  return Color(int.tryParse(h, radix: 16) ?? 0xFF601A29);
}

/// 23 Nov 2026
String leaveFmt(DateTime? d) {
  if (d == null) return '—';
  return '${d.day} ${_months[d.month]} ${d.year}';
}

/// 23 Nov
String leaveFmtShort(DateTime? d) => d == null ? '—' : '${d.day} ${_months[d.month]}';

String leaveWeekday(DateTime d) => _weekdays[d.weekday];

/// "23 Nov" or "23 – 24 Nov" or "30 Nov – 2 Dec" (year added when not this year).
String leaveRange(DateTime? from, DateTime? to) {
  if (from == null) return '—';
  final t = to ?? from;
  final thisYear = DateTime.now().year;
  final y = t.year != thisYear ? ' ${t.year}' : '';
  if (leaveSameDay(from, t)) return '${leaveFmtShort(from)}$y';
  if (from.month == t.month && from.year == t.year) return '${from.day} – ${t.day} ${_months[t.month]}$y';
  return '${leaveFmtShort(from)} – ${leaveFmtShort(t)}$y';
}

String leaveNum(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

String leaveDays(double v) => '${leaveNum(v)} day${v == 1 ? '' : 's'}';

DateTime leaveDay(DateTime d) => DateTime(d.year, d.month, d.day);

bool leaveSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// The request covers calendar day [day].
bool leaveCovers(LeaveRequest r, DateTime day) {
  if (r.fromDate == null) return false;
  final d = leaveDay(day);
  final f = leaveDay(r.fromDate!);
  final t = leaveDay(r.toDate ?? r.fromDate!);
  return !d.isBefore(f) && !d.isAfter(t);
}

/// The request overlaps [start]..[end] (inclusive days).
bool leaveOverlaps(LeaveRequest r, DateTime start, DateTime end) {
  if (r.fromDate == null) return false;
  final f = leaveDay(r.fromDate!);
  final t = leaveDay(r.toDate ?? r.fromDate!);
  return !t.isBefore(leaveDay(start)) && !f.isAfter(leaveDay(end));
}

String leaveInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String leaveStatusLabel(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);

Color leaveStatusColor(String status, CrmTheme crm) {
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

Widget leaveStatusChip(String status, CrmTheme crm) =>
    hrStatusChip(leaveStatusLabel(status), leaveStatusColor(status, crm));

/// Small "Timebox" / "CRM" tag showing where the request came from.
class LeaveSourceTag extends StatelessWidget {
  const LeaveSourceTag(this.request, {super.key});
  final LeaveRequest request;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final tb = request.fromTimebox;
    final c = tb ? const Color(0xFF534AB7) : crm.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(tb ? 'Timebox' : 'CRM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class LeaveAvatar extends StatelessWidget {
  const LeaveAvatar(this.name, {super.key, this.size = 34});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Text(leaveInitials(name),
          style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: crm.primary)),
    );
  }
}

/// Empty-state block used across the tabs.
class LeaveEmpty extends StatelessWidget {
  const LeaveEmpty({super.key, required this.icon, required this.title, this.body = ''});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(children: [
        Icon(icon, size: 30, color: crm.textSecondary.withValues(alpha: 0.6)),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ],
      ]),
    );
  }
}

/// Card section with a title row (and optional trailing widget).
class LeaveSection extends StatelessWidget {
  const LeaveSection({super.key, required this.title, required this.child, this.trailing, this.subtitle = ''});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      decoration: hrCardDecoration(crm),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ]),
          ),
          ?trailing,
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

/// Reload every leave list (live refresh, pull-to-refresh, after an action).
void refreshLeaveData(WidgetRef ref, {bool desk = false}) {
  ref.invalidate(myLeaveProvider);
  ref.invalidate(myBalancesProvider);
  ref.invalidate(holidaysProvider);
  ref.invalidate(leaveDeskAccessProvider);
  if (desk) {
    ref.invalidate(leaveRequestsProvider);
    ref.invalidate(leaveInboxProvider);
    ref.invalidate(employeeBalancesProvider);
  }
  ref.read(leaveLastSyncProvider.notifier).state = DateTime.now();
}

void _snack(BuildContext context, String text, {Color? color}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
}

/// Approve or reject a pending request (leave desk). Rejecting asks for a
/// reason. Returns true when the decision went through.
Future<bool> decideLeave(BuildContext context, WidgetRef ref, LeaveRequest r, {required bool approve}) async {
  final crm = context.crmColors;
  var approvalId = r.approvalId;
  if (approvalId.isEmpty) {
    final inbox = ref.read(leaveInboxProvider).value ?? const [];
    approvalId = inbox.where((a) => a.refId == r.id).firstOrNull?.id ?? '';
  }
  if (approvalId.isEmpty) {
    _snack(context, 'This request has no approval record. Refresh and try again.');
    return false;
  }

  var note = '';
  if (!approve) {
    // A reason is required; the dialog owns (and disposes) its controller.
    final reason = await askHrReason(
      context,
      title: 'Reject ${r.employeeName.isEmpty ? 'leave' : '${r.employeeName}\'s leave'}?',
      header: Text('${r.leaveTypeName.isEmpty ? 'Leave' : r.leaveTypeName} · ${leaveRange(r.fromDate, r.toDate)} · ${leaveDays(r.days)}',
          style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
      label: 'Reason (sent to the employee)',
      hint: 'Studio short-staffed that week',
      cancelLabel: 'Keep pending',
      confirmLabel: 'Reject',
      confirmColor: crm.destructive,
    );
    if (reason == null) return false;
    note = reason;
  }

  try {
    final svc = ref.read(approvalServiceProvider);
    if (approve) {
      await svc.approve(approvalId, note: note);
    } else {
      await svc.reject(approvalId, note: note);
    }
    refreshLeaveData(ref, desk: true);
    if (context.mounted) {
      final who = r.employeeName.isEmpty ? 'Leave' : '${r.employeeName}\'s leave';
      final tb = r.fromTimebox ? ' Timebox has been told.' : '';
      _snack(context, '$who ${approve ? 'approved' : 'rejected'}.$tb',
          color: approve ? crm.success : crm.destructive);
    }
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, friendlyErrorMessage(e));
    return false;
  }
}

/// Cancel a request. Approved leave asks for confirmation first.
Future<bool> cancelLeaveRequest(BuildContext context, WidgetRef ref, LeaveRequest r, {bool desk = false}) async {
  final crm = context.crmColors;
  final approved = r.status == 'approved';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(approved ? 'Cancel approved leave?' : 'Withdraw this request?'),
      content: SizedBox(
        width: 380,
        child: Text(
          '${r.employeeName.isNotEmpty && desk ? '${r.employeeName} · ' : ''}'
          '${r.leaveTypeName.isEmpty ? 'Leave' : r.leaveTypeName} · ${leaveRange(r.fromDate, r.toDate)} · ${leaveDays(r.days)}\n\n'
          '${approved ? 'The days go back to the leave balance.' : 'It will be removed from the approval queue.'}'
          '${r.fromTimebox ? '\n\nThis came from Timebox. Timebox is updated automatically once its cancellation link is switched on; until then, cancel it in Timebox too.' : ''}',
          style: TextStyle(fontSize: 13, color: crm.textPrimary),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: crm.destructive),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(approved ? 'Cancel leave' : 'Withdraw'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await ref.read(leaveServiceProvider).cancel(r.id);
    refreshLeaveData(ref, desk: desk);
    if (context.mounted) _snack(context, approved ? 'Leave cancelled.' : 'Request withdrawn.');
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, friendlyErrorMessage(e));
    return false;
  }
}

/// Re-send a decided Timebox request's decision to Timebox.
Future<void> resendToTimebox(BuildContext context, WidgetRef ref, LeaveRequest r) async {
  final crm = context.crmColors;
  try {
    final sent = await ref.read(leaveServiceProvider).retryCallback(r.id);
    refreshLeaveData(ref, desk: true);
    if (context.mounted) {
      _snack(context, sent ? 'Decision sent to Timebox.' : 'Timebox did not accept it. Try again later.',
          color: sent ? crm.success : crm.destructive);
    }
  } catch (e) {
    if (context.mounted) _snack(context, friendlyErrorMessage(e));
  }
}

/// Holidays on the calendar and overview (amber, readable on light and dark).
const leaveHolidayColor = Color(0xFFB7791F);
