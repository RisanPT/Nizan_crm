// My leave: the signed-in person's balances for the year, their upcoming
// leave and their request history.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/app_error_view.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/leave/data/leave_models.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_common.dart';
import 'package:nizan_crm/features/hr/leave/service/leave_service.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';

class LeaveMyTab extends ConsumerWidget {
  const LeaveMyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final balances = ref.watch(myBalancesProvider);
    final mine = ref.watch(myLeaveProvider);
    final year = ref.watch(leaveYearProvider);

    return RefreshIndicator(
      onRefresh: () async => refreshLeaveData(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _TimeboxNote(),
          const SizedBox(height: 16),
          const HrSectionLabel('Balance'),
          balances.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(myBalancesProvider)),
            data: (list) => list.isEmpty
                ? const LeaveEmpty(icon: Icons.account_balance_wallet_outlined, title: 'No leave types set up yet')
                : LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth >= 1100 ? 4 : c.maxWidth >= 760 ? 3 : c.maxWidth >= 480 ? 2 : 1;
                    final w = (c.maxWidth - (cols - 1) * 12) / cols;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: list.map((b) => SizedBox(width: w, child: _BalanceCard(b))).toList(),
                    );
                  }),
          ),
          const SizedBox(height: 8),
          Text('Credited monthly from January (or your joining month). Pending requests are held from the balance.',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          const SizedBox(height: 20),
          mine.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(myLeaveProvider)),
            data: (list) {
              final today = leaveDay(DateTime.now());
              bool upcoming(LeaveRequest r) =>
                  (r.status == 'approved' || r.status == 'pending') &&
                  r.toDate != null &&
                  !leaveDay(r.toDate!).isBefore(today);
              final next = list.where(upcoming).toList()
                ..sort((a, b) => (a.fromDate ?? today).compareTo(b.fromDate ?? today));
              final rest = list.where((r) => !upcoming(r)).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                LeaveSection(
                  title: 'Upcoming',
                  subtitle: next.isEmpty ? '' : '${next.length} planned',
                  child: next.isEmpty
                      ? const LeaveEmpty(
                          icon: Icons.beach_access_outlined,
                          title: 'Nothing planned',
                          body: 'Leave you apply for in Timebox shows up here.',
                        )
                      : Column(children: next.map((r) => _MyRequestRow(r, today: today)).toList()),
                ),
                const SizedBox(height: 16),
                LeaveSection(
                  title: 'History $year',
                  child: rest.isEmpty
                      ? const LeaveEmpty(icon: Icons.history, title: 'No past requests this year')
                      : Column(children: rest.map((r) => _MyRequestRow(r, today: today)).toList()),
                ),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(this.b);
  final LeaveBalance b;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = leaveHex(b.color);
    final pool = b.credited + b.carriedForward;
    final usedShare = pool <= 0 ? 0.0 : (b.used / pool).clamp(0.0, 1.0);
    final pendingShare = pool <= 0 ? 0.0 : (b.pending / pool).clamp(0.0, 1.0 - usedShare);
    final over = b.limited && b.available < 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: hrCardDecoration(crm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(b.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          ),
          if (!b.paid) hrStatusChip('Unpaid', crm.textSecondary),
        ]),
        const SizedBox(height: 10),
        if (b.limited) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(leaveNum(b.available),
                style: TextStyle(
                    fontSize: 28, height: 1, fontWeight: FontWeight.w800, color: over ? crm.destructive : crm.textPrimary)),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(over ? 'overdrawn' : 'of ${leaveNum(pool)} left',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LayoutBuilder(
                builder: (context, c) => Stack(children: [
                  Container(color: crm.border.withValues(alpha: 0.6)),
                  Container(width: c.maxWidth * (usedShare + pendingShare), color: color.withValues(alpha: 0.4)),
                  Container(width: c.maxWidth * usedShare, color: color),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              '${leaveNum(b.used)} used',
              if (b.pending > 0) '${leaveNum(b.pending)} pending',
              if (b.carriedForward > 0) '${leaveNum(b.carriedForward)} carried',
              '${leaveNum(b.allocated)}/yr',
            ].join(' · '),
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
          ),
        ] else ...[
          Text(leaveNum(b.used),
              style: TextStyle(fontSize: 28, height: 1, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(height: 4),
          Text(
            '${b.paid ? 'used · no quota' : 'days taken this year'}${b.pending > 0 ? ' · ${leaveNum(b.pending)} pending' : ''}',
            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
          ),
        ],
      ]),
    );
  }
}

class _MyRequestRow extends ConsumerWidget {
  const _MyRequestRow(this.r, {required this.today});
  final LeaveRequest r;
  final DateTime today;

  /// Pending can be withdrawn; approved only before it starts. Leave sent
  /// in from Timebox is cancelled in Timebox, not here.
  bool get _cancellable {
    if (r.fromTimebox) return false;
    if (r.status == 'pending') return true;
    if (r.status != 'approved' || r.fromDate == null) return false;
    return leaveDay(r.fromDate!).isAfter(today);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final f = r.fromDate;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text(f == null ? '—' : '${f.day}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.primary)),
            Text(f == null ? '' : leaveFmtShort(f).split(' ').last, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(r.leaveTypeName.isEmpty ? 'Leave' : r.leaveTypeName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              if (r.fromTimebox) LeaveSourceTag(r),
            ]),
            const SizedBox(height: 2),
            Text(
                '${leaveRange(r.fromDate, r.toDate)} · ${leaveDays(r.days)}${r.halfDay != 'none' ? ' (${r.halfDay} half)' : ''}',
                style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            if (r.reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(r.reason,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textPrimary)),
              ),
            if (r.decisionNote.isNotEmpty && r.status != 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('HR: ${r.decisionNote}',
                    style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: leaveStatusColor(r.status, crm))),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          leaveStatusChip(r.status, crm),
          if (_cancellable)
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: crm.destructive, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
              onPressed: () => cancelLeaveRequest(context, ref, r),
              child: Text(r.status == 'pending' ? 'Withdraw' : 'Cancel'),
            ),
        ]),
      ]),
    );
  }
}

/// Leave is applied in Timebox (every employee's attendance app); the CRM
/// shows the balance, history and HR's decision.
class _TimeboxNote extends StatelessWidget {
  const _TimeboxNote();
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: crm.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Apply for or cancel leave in Timebox (Attendance → Request Leave). It comes here for HR to decide, and the decision goes back to Timebox.',
            style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
          ),
        ),
      ]),
    );
  }
}
