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

/// Per-employee attendance calendar + daily detail (login/out + worklist).
class AttendanceDetailScreen extends HookConsumerWidget {
  const AttendanceDetailScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.department,
  });

  final int employeeId;
  final String employeeName;
  final String department;

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
              Text('$department · ${_months[month.month]} ${month.year}',
                  style: TextStyle(color: crm.textSecondary, fontSize: 13)),
              12.h,
              Row(
                children: [
                  Expanded(child: _Metric(label: 'Days logged', value: '${records.length}', color: crm.accent)),
                  8.w,
                  Expanded(child: _Metric(label: 'Worked days', value: '$workedDays', color: crm.success)),
                  8.w,
                  Expanded(child: _Metric(label: 'Hours', value: totalHours.toStringAsFixed(1), color: crm.primary)),
                ],
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
                  theme: theme,
                )
              else
                _Hint(text: 'Tap a day to see login/logout times and the Timebox worklist.'),
            ],
          );
        },
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          2.h,
          Text(label, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
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

  Color _cellColor(AttendanceRecord? r) {
    if (r == null) return Colors.transparent;
    final h = r.workedHours ?? 0;
    if (r.isActive) return crm.warning.withValues(alpha: 0.18); // still clocked in
    if (h >= 6) return crm.success.withValues(alpha: 0.22);
    if (h > 0) return crm.success.withValues(alpha: 0.12);
    return crm.textSecondary.withValues(alpha: 0.10); // logged but 0h (estimated)
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday; // Mon=1..Sun=7
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
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
          8.h,
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: (startWeekday - 1) + daysInMonth,
            itemBuilder: (ctx, index) {
              if (index < startWeekday - 1) return const SizedBox.shrink();
              final day = index - (startWeekday - 1) + 1;
              final dateStr =
                  '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final rec = byDate[dateStr];
              final isSel = dateStr == selected;
              return InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onSelect(dateStr),
                child: Container(
                  decoration: BoxDecoration(
                    color: _cellColor(rec),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSel ? crm.accent : crm.border.withValues(alpha: 0.6),
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day',
                          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                      if (rec?.workedHours != null && rec!.workedHours! > 0)
                        Text('${rec.workedHours!.toStringAsFixed(1)}h',
                            style: const TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
              );
            },
          ),
          12.h,
          Wrap(spacing: 12, runSpacing: 6, children: [
            _Legend(color: crm.success, label: 'Worked'),
            _Legend(color: crm.warning, label: 'Clocked in'),
            _Legend(color: crm.textSecondary, label: 'No hours'),
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
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2))),
      4.w,
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
    required this.theme,
  });

  final String date;
  final AttendanceRecord? record;
  final TimeboxDay? day;
  final CrmTheme crm;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_outlined, size: 18, color: crm.accent),
              8.w,
              Text(date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          12.h,
          if (record == null)
            Text('No attendance recorded for this day.', style: TextStyle(color: crm.textSecondary))
          else ...[
            Row(
              children: [
                Expanded(child: _kv('Login', _hm(record!.loginTime), crm)),
                Expanded(child: _kv('Logout', record!.logoutTime == null ? 'Not logged out' : '${_hm(record!.logoutTime)}${record!.logoutEstimated ? " (est.)" : ""}', crm)),
              ],
            ),
            8.h,
            Row(
              children: [
                Expanded(child: _kv('Worked', record!.workedHours == null ? '—' : '${record!.workedHours!.toStringAsFixed(2)} h', crm)),
                Expanded(child: _kv('Lunch', record!.lunchMinutes == null ? '—' : '${record!.lunchMinutes} min', crm)),
              ],
            ),
          ],
          if (day != null && (day!.worklist.isNotEmpty || day!.braindump.isNotEmpty || day!.schedule.isNotEmpty)) ...[
            const Divider(height: 24),
            Text('Timebox planner', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textSecondary, fontSize: 12)),
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
        2.h,
        Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
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
                  Icon(it.done ? Icons.check_box_outlined : Icons.check_box_outline_blank,
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
