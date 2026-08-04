import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../data/timebox_models.dart';
import '../../service/timebox_service.dart';

const _months = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Extract the wall-clock HH:mm from an ISO timestamp (keeps Timebox/IST time).
String _hm(String? iso) {
  if (iso == null || iso.length < 16) return '—';
  return iso.substring(11, 16);
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// What a single calendar day represents.
enum _DayKind { workedFull, worked, clockedIn, loggedNoHours, absent, off, future }

/// Per-employee attendance calendar + daily detail (login/out + worklist).
class AttendanceDetailScreen extends HookConsumerWidget {
  const AttendanceDetailScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    this.attendancePercent = 0,
    this.daysPresent = 0,
    this.expectedDays = 0,
    this.hoursWorked = 0,
  });

  final int employeeId;
  final String employeeName;
  final String department;
  final int attendancePercent;
  final int daysPresent;
  final int expectedDays;
  final double hoursWorked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final month = ref.watch(timeboxMonthProvider);
    final attendanceAsync = ref.watch(employeeAttendanceProvider(employeeId));
    final daysAsync = ref.watch(employeeDaysProvider(employeeId));
    final selectedDate = useState<String?>(null);

    final Map<String, AttendanceRecord> byDate = attendanceAsync.maybeWhen(
      data: (list) => {for (final r in list) r.date: r},
      orElse: () => {},
    );
    final Map<String, TimeboxDay> daysByDate = daysAsync.maybeWhen(
      data: (list) => {for (final d in list) d.date: d},
      orElse: () => {},
    );

    final onLeave = attendancePercent <= 0 && hoursWorked <= 0;
    final statusColor = onLeave
        ? crm.warning
        : attendancePercent >= 75
            ? crm.success
            : attendancePercent >= 50
                ? crm.warning
                : crm.destructive;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(employeeName.trim().isEmpty ? 'Attendance' : employeeName.trim()),
        backgroundColor: crm.sidebar,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
          ),
        ),
        data: (records) {
          final workedDays = records.where((r) => (r.workedHours ?? 0) > 0).length;
          final totalHours = records.fold<double>(0, (s, r) => s + (r.workedHours ?? 0));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _HeaderCard(
                name: employeeName,
                department: department,
                monthLabel: '${_months[month.month]} ${month.year}',
                attendancePercent: attendancePercent,
                onLeave: onLeave,
                statusColor: statusColor,
                crm: crm,
              ),
              14.h,
              if (onLeave) ...[
                _LeaveBanner(crm: crm),
                14.h,
              ],
              _MetricsRow(
                daysLogged: records.length,
                workedDays: workedDays,
                totalHours: totalHours,
                daysPresent: daysPresent,
                expectedDays: expectedDays,
                crm: crm,
              ),
              16.h,
              _Calendar(
                year: month.year,
                month: month.month,
                byDate: byDate,
                selected: selectedDate.value,
                crm: crm,
                theme: theme,
                onSelect: (d) => selectedDate.value = d,
              ),
              16.h,
              if (selectedDate.value != null)
                _DayDetail(
                  date: selectedDate.value!,
                  record: byDate[selectedDate.value!],
                  day: daysByDate[selectedDate.value!],
                  crm: crm,
                )
              else
                _Hint(text: 'Tap any day to see login/logout times and the Timebox worklist.'),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.name,
    required this.department,
    required this.monthLabel,
    required this.attendancePercent,
    required this.onLeave,
    required this.statusColor,
    required this.crm,
  });

  final String name;
  final String department;
  final String monthLabel;
  final int attendancePercent;
  final bool onLeave;
  final Color statusColor;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Text(
              _initials(name),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: statusColor),
            ),
          ),
          14.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? 'Unknown' : name.trim(),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                6.h,
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: crm.primary.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          department.isEmpty ? '—' : department.toUpperCase(),
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: crm.primary, letterSpacing: 0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    8.w,
                    Text(monthLabel, style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          12.w,
          if (onLeave)
            Column(
              children: [
                Icon(Icons.beach_access_rounded, color: crm.warning, size: 26),
                4.h,
                Text('On Leave', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.warning)),
              ],
            )
          else
            Column(
              children: [
                Text('$attendancePercent%',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: -0.5)),
                Text('attendance', style: TextStyle(fontSize: 10, color: crm.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }
}

class _LeaveBanner extends StatelessWidget {
  const _LeaveBanner({required this.crm});
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: crm.warning, size: 20),
          12.w,
          Expanded(
            child: Text(
              'No Timebox login recorded this month — treated as on leave / absent.',
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.daysLogged,
    required this.workedDays,
    required this.totalHours,
    required this.daysPresent,
    required this.expectedDays,
    required this.crm,
  });

  final int daysLogged;
  final int workedDays;
  final double totalHours;
  final int daysPresent;
  final int expectedDays;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    final absent = (expectedDays - daysPresent).clamp(0, expectedDays);
    final tiles = <Widget>[
      _Metric(label: 'Present', value: '$daysPresent/$expectedDays', color: crm.success),
      _Metric(label: 'Worked days', value: '$workedDays', color: crm.accent),
      _Metric(label: 'Absent', value: '$absent', color: crm.destructive),
      _Metric(label: 'Hours', value: totalHours.toStringAsFixed(1), color: crm.primary),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        final perRow = c.maxWidth < 460 ? 2 : 4;
        const gap = 8.0;
        final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tiles.map((t) => SizedBox(width: w, child: t)).toList(),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
          ),
          3.h,
          Text(label, style: TextStyle(fontSize: 10.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.year,
    required this.month,
    required this.byDate,
    required this.selected,
    required this.crm,
    required this.theme,
    required this.onSelect,
  });

  final int year;
  final int month;
  final Map<String, AttendanceRecord> byDate;
  final String? selected;
  final CrmTheme crm;
  final ThemeData theme;
  final ValueChanged<String> onSelect;

  _DayKind _kindFor(DateTime day, AttendanceRecord? r, DateTime today) {
    if (r != null) {
      final h = r.workedHours ?? 0;
      if (r.isActive) return _DayKind.clockedIn;
      if (h >= 6) return _DayKind.workedFull;
      if (h > 0) return _DayKind.worked;
      return _DayKind.loggedNoHours;
    }
    // No record.
    final dayOnly = DateTime(day.year, day.month, day.day);
    if (dayOnly.isAfter(today)) return _DayKind.future;
    if (day.weekday == DateTime.sunday) return _DayKind.off; // weekly off
    return _DayKind.absent; // past working day, never logged in → leave/absent
  }

  Color _fill(_DayKind k) {
    switch (k) {
      case _DayKind.workedFull:
        return crm.success.withValues(alpha: 0.28);
      case _DayKind.worked:
        return crm.success.withValues(alpha: 0.14);
      case _DayKind.clockedIn:
        return crm.warning.withValues(alpha: 0.20);
      case _DayKind.loggedNoHours:
        return crm.textSecondary.withValues(alpha: 0.12);
      case _DayKind.absent:
        return crm.destructive.withValues(alpha: 0.14);
      case _DayKind.off:
        return crm.textSecondary.withValues(alpha: 0.05);
      case _DayKind.future:
        return Colors.transparent;
    }
  }

  Color _border(_DayKind k) {
    switch (k) {
      case _DayKind.absent:
        return crm.destructive.withValues(alpha: 0.35);
      case _DayKind.workedFull:
      case _DayKind.worked:
        return crm.success.withValues(alpha: 0.35);
      case _DayKind.clockedIn:
        return crm.warning.withValues(alpha: 0.4);
      default:
        return crm.border.withValues(alpha: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday; // Mon=1..Sun=7
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: dayLabels
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: crm.textSecondary, fontWeight: FontWeight.w700)),
                      ),
                    ))
                .toList(),
          ),
          10.h,
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
            ),
            itemCount: (startWeekday - 1) + daysInMonth,
            itemBuilder: (ctx, index) {
              if (index < startWeekday - 1) return const SizedBox.shrink();
              final day = index - (startWeekday - 1) + 1;
              final date = DateTime(year, month, day);
              final dateStr =
                  '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final rec = byDate[dateStr];
              final kind = _kindFor(date, rec, today);
              final isSel = dateStr == selected;
              final isToday = dateStr == todayStr;
              final h = rec?.workedHours;

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelect(dateStr),
                child: Container(
                  decoration: BoxDecoration(
                    color: _fill(kind),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel
                          ? crm.accent
                          : isToday
                              ? crm.primary.withValues(alpha: 0.6)
                              : _border(kind),
                      width: (isSel || isToday) ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: kind == _DayKind.future
                                ? crm.textSecondary.withValues(alpha: 0.5)
                                : null,
                          )),
                      if (h != null && h > 0)
                        Text('${h.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 8))
                      else if (kind == _DayKind.absent)
                        Icon(Icons.close_rounded, size: 9, color: crm.destructive.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              );
            },
          ),
          14.h,
          Wrap(spacing: 14, runSpacing: 8, children: [
            _Legend(color: crm.success, label: 'Worked'),
            _Legend(color: crm.warning, label: 'Clocked in'),
            _Legend(color: crm.destructive, label: 'Absent / Leave'),
            _Legend(color: crm.textSecondary, label: 'Weekly off'),
          ]),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 11, height: 11, decoration: BoxDecoration(color: color.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3))),
      5.w,
      Text(label, style: const TextStyle(fontSize: 11)),
    ]);
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.date,
    required this.record,
    required this.day,
    required this.crm,
  });

  final String date;
  final AttendanceRecord? record;
  final TimeboxDay? day;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    // Classify a record-less day for the message.
    final parsed = DateTime.tryParse(date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String emptyMsg = 'No attendance recorded for this day.';
    Color emptyColor = crm.textSecondary;
    IconData emptyIcon = Icons.remove_circle_outline_rounded;
    if (record == null && parsed != null) {
      final d = DateTime(parsed.year, parsed.month, parsed.day);
      if (d.isAfter(today)) {
        emptyMsg = 'Upcoming day.';
        emptyIcon = Icons.upcoming_outlined;
      } else if (parsed.weekday == DateTime.sunday) {
        emptyMsg = 'Weekly off (Sunday).';
        emptyIcon = Icons.weekend_outlined;
      } else {
        emptyMsg = 'Absent — no Timebox login (leave/absent).';
        emptyColor = crm.destructive;
        emptyIcon = Icons.event_busy_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: crm.accent),
              8.w,
              Text(date, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          12.h,
          if (record == null)
            Row(
              children: [
                Icon(emptyIcon, size: 18, color: emptyColor),
                8.w,
                Expanded(child: Text(emptyMsg, style: TextStyle(color: emptyColor, fontSize: 13, fontWeight: FontWeight.w500))),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(child: _kv('Login', _hm(record!.loginTime), crm)),
                Expanded(
                  child: _kv(
                    'Logout',
                    record!.logoutTime == null
                        ? 'Not logged out'
                        : '${_hm(record!.logoutTime)}${record!.logoutEstimated ? " (est.)" : ""}',
                    crm,
                  ),
                ),
              ],
            ),
            10.h,
            Row(
              children: [
                Expanded(child: _kv('Worked', record!.workedHours == null ? '—' : '${record!.workedHours!.toStringAsFixed(2)} h', crm)),
                Expanded(child: _kv('Lunch', record!.lunchMinutes == null ? '—' : '${record!.lunchMinutes} min', crm)),
              ],
            ),
          ],
          if (day != null && (day!.worklist.isNotEmpty || day!.braindump.isNotEmpty || day!.schedule.isNotEmpty)) ...[
            const Divider(height: 26),
            Row(
              children: [
                Icon(Icons.checklist_rounded, size: 16, color: crm.textSecondary),
                6.w,
                Text('Timebox planner', style: TextStyle(fontWeight: FontWeight.w800, color: crm.textSecondary, fontSize: 12)),
              ],
            ),
            8.h,
            if (day!.worklist.isNotEmpty) _ItemList(title: 'Worklist', items: day!.worklist, crm: crm),
            if (day!.braindump.isNotEmpty) _ItemList(title: 'Braindump', items: day!.braindump, crm: crm),
            if (day!.schedule.isNotEmpty) _ItemList(title: 'Schedule', items: day!.schedule, crm: crm),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v, CrmTheme crm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        3.h,
        Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.title, required this.items, required this.crm});
  final String title;
  final List<TimeboxItem> items;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        6.h,
        Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.accent)),
        4.h,
        ...items.map((it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(it.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 15, color: it.done ? crm.success : crm.textSecondary),
                  6.w,
                  Expanded(
                    child: Text(
                      it.content.isEmpty ? '—' : it.content,
                      style: TextStyle(
                        fontSize: 12.5,
                        decoration: it.done ? TextDecoration.lineThrough : null,
                        color: it.done ? crm.textSecondary : null,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.accent.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(Icons.touch_app_outlined, size: 18, color: crm.accent),
        10.w,
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
      ]),
    );
  }
}
