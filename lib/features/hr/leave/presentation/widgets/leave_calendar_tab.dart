// Calendar (leave desk): a month grid with everyone's approved and pending
// leave plus holidays. Tap a day to see everyone off that day.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/app_error_view.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/leave/data/leave_models.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_common.dart';
import 'package:nizan_crm/features/hr/leave/service/leave_service.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';

class LeaveCalendarTab extends ConsumerStatefulWidget {
  const LeaveCalendarTab({super.key});
  @override
  ConsumerState<LeaveCalendarTab> createState() => _LeaveCalendarTabState();
}

class _LeaveCalendarTabState extends ConsumerState<LeaveCalendarTab> {
  late int _month;
  bool _showPending = true;
  String _dept = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final y = ref.read(leaveYearProvider);
    _month = y == now.year ? now.month : 1;
  }

  void _shift(int delta) {
    var m = _month + delta;
    final year = ref.read(leaveYearProvider);
    if (m < 1) {
      ref.read(leaveYearProvider.notifier).state = year - 1;
      m = 12;
    } else if (m > 12) {
      ref.read(leaveYearProvider.notifier).state = year + 1;
      m = 1;
    }
    setState(() => _month = m);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final year = ref.watch(leaveYearProvider);
    final reqs = ref.watch(leaveRequestsProvider);
    final holidays = ref.watch(holidaysProvider).value ?? const <Holiday>[];

    return RefreshIndicator(
      onRefresh: () async => refreshLeaveData(ref, desk: true),
      child: reqs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(leaveRequestsProvider))]),
        data: (all) {
          final depts = all.map((r) => r.department).where((s) => s.isNotEmpty).toSet().toList()..sort();
          final shown = all
              .where((r) =>
                  (r.status == 'approved' || (_showPending && r.status == 'pending')) &&
                  (_dept == 'all' || r.department == _dept))
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'Previous month', onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                  SizedBox(
                    width: 150,
                    child: Text('${leaveMonthNames[_month]} $year',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                  ),
                  IconButton(tooltip: 'Next month', onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                ]),
                TextButton(
                  onPressed: () {
                    final now = DateTime.now();
                    ref.read(leaveYearProvider.notifier).state = now.year;
                    setState(() => _month = now.month);
                  },
                  child: const Text('Today'),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('cal-dept-$_dept-${depts.length}'),
                    initialValue: depts.contains(_dept) ? _dept : 'all',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Department', isDense: true, border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All departments')),
                      ...depts.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                    ],
                    onChanged: (v) => setState(() => _dept = v ?? 'all'),
                  ),
                ),
                FilterChip(
                  label: const Text('Show pending'),
                  selected: _showPending,
                  onSelected: (v) => setState(() => _showPending = v),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 6, children: [
                _legend(crm, crm.success, 'Approved', filled: true),
                _legend(crm, crm.warning, 'Pending', filled: false),
                _legend(crm, leaveHolidayColor, 'Holiday', filled: true),
              ]),
              const SizedBox(height: 12),
              Container(
                decoration: hrCardDecoration(crm),
                padding: const EdgeInsets.all(10),
                child: _MonthGrid(year: year, month: _month, requests: shown, holidays: holidays),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _legend(CrmTheme crm, Color c, String label, {required bool filled}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: filled ? c.withValues(alpha: 0.25) : Colors.transparent,
            border: Border.all(color: c),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
      ]);
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.year, required this.month, required this.requests, required this.holidays});
  final int year;
  final int month;
  final List<LeaveRequest> requests;
  final List<Holiday> holidays;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first
    final cells = ((lead + daysInMonth + 6) ~/ 7) * 7;
    final today = leaveDay(DateTime.now());

    return LayoutBuilder(builder: (context, c) {
      final cellW = c.maxWidth / 7;
      final compact = cellW < 96;
      final cellH = compact ? 58.0 : 104.0;
      return Column(children: [
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((d) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
                    ),
                  ))
              .toList(),
        ),
        for (var w = 0; w < cells ~/ 7; w++)
          Row(children: [
            for (var d = 0; d < 7; d++)
              Expanded(
                child: Builder(builder: (context) {
                  final idx = w * 7 + d;
                  final dayNum = idx - lead + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) return SizedBox(height: cellH);
                  final day = DateTime(year, month, dayNum);
                  final hol = holidays.where((h) => h.date != null && leaveSameDay(h.date!, day)).toList();
                  final off = requests.where((r) => leaveCovers(r, day)).toList()
                    ..sort((a, b) => a.status.compareTo(b.status)); // approved before pending
                  return _DayCell(
                    day: day,
                    height: cellH,
                    compact: compact,
                    isToday: leaveSameDay(day, today),
                    isSunday: day.weekday == DateTime.sunday,
                    holidays: hol,
                    off: off,
                    crm: crm,
                  );
                }),
              ),
          ]),
      ]);
    });
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.height,
    required this.compact,
    required this.isToday,
    required this.isSunday,
    required this.holidays,
    required this.off,
    required this.crm,
  });
  final DateTime day;
  final double height;
  final bool compact;
  final bool isToday;
  final bool isSunday;
  final List<Holiday> holidays;
  final List<LeaveRequest> off;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    final hasHoliday = holidays.isNotEmpty;
    final bg = hasHoliday
        ? leaveHolidayColor.withValues(alpha: 0.12)
        : isSunday
            ? crm.textSecondary.withValues(alpha: 0.05)
            : Colors.transparent;
    final maxNames = compact ? 0 : (hasHoliday ? 2 : 3);

    return InkWell(
      onTap: (off.isEmpty && !hasHoliday) ? null : () => _openDay(context),
      child: Container(
        height: height,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isToday ? crm.primary : crm.border.withValues(alpha: 0.6), width: isToday ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${day.day}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isToday ? crm.primary : (isSunday ? crm.textSecondary : crm.textPrimary))),
          if (compact) ...[
            const Spacer(),
            // Phone: dots instead of names — holiday (gold) and people off (count).
            Wrap(spacing: 2, runSpacing: 2, children: [
              if (hasHoliday)
                Container(width: 7, height: 7, decoration: BoxDecoration(color: leaveHolidayColor, shape: BoxShape.circle)),
              if (off.isNotEmpty)
                Text('${off.length}',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: crm.primary)),
            ]),
          ],
          if (hasHoliday && !compact)
            Text(holidays.first.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: leaveHolidayColor)),
          if (!compact) ...[
            const SizedBox(height: 2),
            ...off.take(maxNames).map((r) => _namePill(r)),
            if (off.length > maxNames)
              Text('+${off.length - maxNames} more', style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          ],
        ]),
      ),
    );
  }

  Widget _namePill(LeaveRequest r) {
    final c = r.status == 'approved' ? crm.success : crm.warning;
    final first = r.employeeName.split(' ').first;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: r.status == 'approved' ? c.withValues(alpha: 0.18) : Colors.transparent,
        border: Border.all(color: c.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$first${r.halfDay != 'none' && leaveSameDay(r.fromDate!, day) ? ' ½' : ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: crm.textPrimary)),
    );
  }

  void _openDay(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${leaveWeekday(day)}, ${leaveFmt(day)}'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ...holidays.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(Icons.celebration_outlined, size: 18, color: leaveHolidayColor),
                    const SizedBox(width: 8),
                    Text(h.name, style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  ]),
                )),
            if (off.isEmpty)
              Text('No one is on leave.', style: TextStyle(color: crm.textSecondary))
            else
              ...off.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      LeaveAvatar(r.employeeName, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.employeeName, style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
                          Text(
                              [
                                if (r.department.isNotEmpty) r.department,
                                r.leaveTypeName,
                                leaveRange(r.fromDate, r.toDate),
                              ].join(' · '),
                              style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                        ]),
                      ),
                      leaveStatusChip(r.status, crm),
                    ]),
                  )),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
      ),
    );
  }
}
