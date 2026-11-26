// Overview (leave desk): live counts, the queue of requests waiting for a
// decision, who is out today / this week, upcoming holidays and Timebox
// decisions that failed to send.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/app_error_view.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/leave/data/leave_models.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_common.dart';
import 'package:nizan_crm/features/hr/leave/service/leave_service.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';

class LeaveOverviewTab extends ConsumerWidget {
  const LeaveOverviewTab({super.key, required this.ownEmployeeId, required this.isAdmin, required this.onOpenRequests});
  final String ownEmployeeId;
  final bool isAdmin;
  final VoidCallback onOpenRequests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(leaveRequestsProvider);
    final holidays = ref.watch(holidaysProvider).value ?? const <Holiday>[];

    return RefreshIndicator(
      onRefresh: () async => refreshLeaveData(ref, desk: true),
      child: reqs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(leaveRequestsProvider))]),
        data: (list) => _body(context, list, holidays, ref.watch(leaveYearProvider) == DateTime.now().year),
      ),
    );
  }

  /// [isThisYear]: the list holds the selected year only, so today / this week
  /// counts are shown only when the current year is selected.
  Widget _body(BuildContext context, List<LeaveRequest> list, List<Holiday> holidays, bool isThisYear) {
    final crm = context.crmColors;
    final today = leaveDay(DateTime.now());
    final weekEnd = today.add(Duration(days: 7 - today.weekday)); // Sunday

    final pending = list.where((r) => r.status == 'pending').toList()
      ..sort((a, b) => (a.createdAt ?? a.fromDate ?? today).compareTo(b.createdAt ?? b.fromDate ?? today));
    final approved = list.where((r) => r.status == 'approved').toList();
    final outToday = approved.where((r) => leaveCovers(r, today)).toList();
    final laterThisWeek = approved
        .where((r) => !leaveCovers(r, today) && leaveOverlaps(r, today.add(const Duration(days: 1)), weekEnd))
        .toList()
      ..sort((a, b) => a.fromDate!.compareTo(b.fromDate!));
    final weekPeople = {...outToday, ...laterThisWeek}.map((r) => r.employeeId).toSet();
    final nextHolidays = holidays.where((h) => h.date != null && !leaveDay(h.date!).isBefore(today)).toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
    final failed = list.where((r) => r.fromTimebox && r.callbackStatus == 'failed' && r.status != 'pending').toList();

    final kpis = [
      _Kpi(Icons.hourglass_top_rounded, '${pending.length}', 'Pending decision', pending.isEmpty ? crm.success : crm.warning),
      _Kpi(Icons.person_off_outlined, isThisYear ? '${outToday.map((r) => r.employeeId).toSet().length}' : '—', 'On leave today', crm.primary),
      _Kpi(Icons.date_range_outlined, isThisYear ? '${weekPeople.length}' : '—', 'Out this week', crm.primary),
      _Kpi(
        Icons.celebration_outlined,
        nextHolidays.isEmpty ? '—' : leaveFmtShort(nextHolidays.first.date),
        nextHolidays.isEmpty ? 'No holiday ahead' : 'Next: ${nextHolidays.first.name}',
        leaveHolidayColor,
      ),
    ];

    final queue = LeaveSection(
      title: 'Waiting for decision',
      subtitle: pending.isEmpty ? '' : 'Oldest first',
      trailing: TextButton(onPressed: onOpenRequests, child: const Text('All requests')),
      child: pending.isEmpty
          ? const LeaveEmpty(icon: Icons.task_alt_rounded, title: 'All caught up', body: 'New requests from the CRM and Timebox appear here.')
          : Column(
              children: pending
                  .map((r) => _PendingRow(
                        r: r,
                        clashes: _clashes(r, list),
                        own: !isAdmin && ownEmployeeId.isNotEmpty && r.employeeId == ownEmployeeId,
                      ))
                  .toList()),
    );

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LeaveSection(
        title: "Who's out",
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!isThisYear) _muted(crm, 'Select the current year to see who is out today.') else ...[
          _subLabel(crm, 'Today · ${leaveWeekday(today)} ${leaveFmtShort(today)}'),
          if (outToday.isEmpty) _muted(crm, 'Everyone is in.') else ...outToday.map((r) => _OutRow(r, today: today)),
          const SizedBox(height: 10),
          _subLabel(crm, 'Rest of this week'),
          if (laterThisWeek.isEmpty) _muted(crm, 'No one else is off.') else ...laterThisWeek.map((r) => _OutRow(r, today: today)),
          ],
          const SizedBox(height: 6),
        ]),
      ),
      const SizedBox(height: 16),
      LeaveSection(
        title: 'Upcoming holidays',
        child: nextHolidays.isEmpty
            ? _muted(crm, 'None left this year.')
            : Column(
                children: nextHolidays
                    .take(4)
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            SizedBox(
                                width: 70,
                                child: Text('${leaveWeekday(h.date!)} ${leaveFmtShort(h.date)}',
                                    style: TextStyle(fontSize: 12, color: crm.textSecondary))),
                            Expanded(
                                child: Text(h.name,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary))),
                          ]),
                        ))
                    .toList()),
      ),
      if (failed.isNotEmpty) ...[
        const SizedBox(height: 16),
        LeaveSection(
          title: 'Not sent to Timebox',
          subtitle: 'Decided here, but Timebox did not accept the update.',
          child: Column(children: failed.map((r) => _FailedRow(r)).toList()),
        ),
      ],
    ]);

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1000;
      final cols = c.maxWidth >= 760 ? 4 : 2;
      final kw = (c.maxWidth - 32 - (cols - 1) * 12) / cols;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kpis.map((k) => SizedBox(width: kw, child: _KpiCard(k))).toList(),
          ),
          const SizedBox(height: 16),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: queue),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: side),
            ])
          else ...[
            queue,
            const SizedBox(height: 16),
            side,
          ],
        ],
      );
    });
  }

  /// Others in the same department off (approved or pending) on the same days.
  static List<LeaveRequest> _clashes(LeaveRequest r, List<LeaveRequest> all) {
    if (r.fromDate == null || r.department.isEmpty) return const [];
    return all
        .where((o) =>
            o.id != r.id &&
            o.employeeId != r.employeeId &&
            (o.status == 'approved' || o.status == 'pending') &&
            o.department.toLowerCase() == r.department.toLowerCase() &&
            leaveOverlaps(o, r.fromDate!, r.toDate ?? r.fromDate!))
        .toList();
  }

  Widget _subLabel(CrmTheme crm, String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
      );

  Widget _muted(CrmTheme crm, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(t, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
      );
}

class _Kpi {
  const _Kpi(this.icon, this.value, this.label, this.color);
  final IconData icon;
  final String value;
  final String label;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.k);
  final _Kpi k;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: hrCardDecoration(crm),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: k.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(k.icon, color: k.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            Text(k.label,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}

class _PendingRow extends ConsumerStatefulWidget {
  const _PendingRow({required this.r, required this.clashes, required this.own});
  final LeaveRequest r;
  final List<LeaveRequest> clashes;
  final bool own;
  @override
  ConsumerState<_PendingRow> createState() => _PendingRowState();
}

class _PendingRowState extends ConsumerState<_PendingRow> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    await decideLeave(context, ref, widget.r, approve: approve);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = widget.r;
    final balance = r.employeeId.isEmpty
        ? null
        : (ref.watch(employeeBalancesProvider(r.employeeId)).value ?? const <LeaveBalance>[])
            .where((b) => b.leaveTypeId == r.leaveTypeId)
            .firstOrNull;
    final age = r.createdAt == null ? null : DateTime.now().difference(r.createdAt!);
    final ageText = age == null
        ? ''
        : age.inDays >= 1
            ? 'waiting ${age.inDays} day${age.inDays == 1 ? '' : 's'}'
            : age.inHours >= 1
                ? 'waiting ${age.inHours} h'
                : 'just now';

    final details = [
      r.leaveTypeName.isEmpty ? 'Leave' : r.leaveTypeName,
      leaveRange(r.fromDate, r.toDate),
      '${leaveDays(r.days)}${r.halfDay != 'none' ? ' (${r.halfDay} half)' : ''}',
    ].join(' · ');

    final actions = widget.own
        ? Text('Your own — another HR user or admin decides',
            style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: crm.textSecondary))
        : _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton(
                  onPressed: () => _decide(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: crm.destructive,
                    side: BorderSide(color: crm.destructive.withValues(alpha: 0.5)),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _decide(true),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Approve'),
                ),
              ]);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border))),
      child: LayoutBuilder(builder: (context, c) {
        final info = Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(r.employeeName.isEmpty ? 'Employee' : r.employeeName,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              LeaveSourceTag(r),
              if (r.department.isNotEmpty) Text(r.department, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ]),
            const SizedBox(height: 3),
            Text(details, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary)),
            if (r.reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('"${r.reason}"', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              ),
            const SizedBox(height: 5),
            Wrap(spacing: 10, runSpacing: 4, children: [
              if (balance != null && balance.limited)
                _note(
                  Icons.account_balance_wallet_outlined,
                  '${leaveNum(balance.available)} left after pending',
                  balance.available < 0 ? crm.destructive : crm.textSecondary,
                ),
              if (widget.clashes.isNotEmpty)
                _note(
                  Icons.groups_outlined,
                  'Also off: ${widget.clashes.map((o) => o.employeeName).toSet().take(3).join(', ')}',
                  crm.warning,
                ),
              if (ageText.isNotEmpty) _note(Icons.schedule, ageText, crm.textSecondary),
            ]),
          ]),
        );
        final narrow = c.maxWidth < 520;
        if (narrow) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [LeaveAvatar(r.employeeName), const SizedBox(width: 12), info]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: actions),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LeaveAvatar(r.employeeName),
          const SizedBox(width: 12),
          info,
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(top: 2), child: actions),
        ]);
      }),
    );
  }

  Widget _note(IconData icon, String text, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ),
      ]);
}

class _OutRow extends StatelessWidget {
  const _OutRow(this.r, {required this.today});
  final LeaveRequest r;
  final DateTime today;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final until = r.toDate == null ? null : leaveDay(r.toDate!);
    final when = leaveCovers(r, today)
        ? (until == null || leaveSameDay(until, today) ? 'today only' : 'until ${leaveWeekday(until)} ${leaveFmtShort(until)}')
        : leaveRange(r.fromDate, r.toDate);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        LeaveAvatar(r.employeeName, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.employeeName, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            Text(
                [if (r.department.isNotEmpty) r.department, r.leaveTypeName, if (r.halfDay != 'none') '½ day']
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ]),
        ),
        Text(when, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
      ]),
    );
  }
}

class _FailedRow extends ConsumerStatefulWidget {
  const _FailedRow(this.r);
  final LeaveRequest r;
  @override
  ConsumerState<_FailedRow> createState() => _FailedRowState();
}

class _FailedRowState extends ConsumerState<_FailedRow> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = widget.r;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
          child: Text('${r.employeeName} · ${leaveRange(r.fromDate, r.toDate)} · ${leaveStatusLabel(r.status)}',
              style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
        ),
        _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(
                onPressed: () async {
                  setState(() => _busy = true);
                  await resendToTimebox(context, ref, r);
                  if (mounted) setState(() => _busy = false);
                },
                child: const Text('Re-send'),
              ),
      ]),
    );
  }
}
