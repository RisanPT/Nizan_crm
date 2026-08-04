import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../data/hr_models.dart';
import '../../service/hr_service.dart';

class HrAttendanceScreen extends HookConsumerWidget {
  const HrAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm   = context.crmColors;
    final filter = ref.watch(hrFilterProvider);

    final staffAsync      = ref.watch(hrStaffProvider);
    final attendanceAsync = ref.watch(hrAttendanceProvider);
    final leavesAsync     = ref.watch(hrLeavesProvider);
    final holidaysAsync   = ref.watch(hrHolidaysProvider);

    // Build a quick lookup of leave dates and holiday dates for calendar colouring
    final Set<String> leaveDates = leavesAsync.whenOrNull(
          data: (leaves) => leaves
              .expand((l) => _dateRange(l.startDate, l.endDate))
              .toSet(),
        ) ??
        {};
    final Set<String> holidayDates = holidaysAsync.whenOrNull(
          data: (holidays) => holidays.map((h) => h.date).toSet(),
        ) ??
        {};
    final Map<String, HrTimebox> timeboxMap = attendanceAsync.whenOrNull(
          data: (r) => r == null
              ? {}
              : {for (final t in r.data) t.date: t},
        ) ??
        {};

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('HR Attendance'),
        backgroundColor: crm.sidebar,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Controls bar ───────────────────────────────────────────────────
          _ControlsBar(
            theme:  theme,
            crm:    crm,
            filter: filter,
            staffAsync: staffAsync,
            onFilterChanged: (f) =>
                ref.read(hrFilterProvider.notifier).state = f,
          ),
          const Divider(height: 1),

          // ── Summary chips ──────────────────────────────────────────────────
          attendanceAsync.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data: (r) {
              if (r == null) return const SizedBox.shrink();
              return _SummaryBar(summary: r.summary, crm: crm, theme: theme);
            },
          ),

          // ── Calendar ───────────────────────────────────────────────────────
          Expanded(
            child: filter.userId == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_outlined,
                            size: 56,
                            color: crm.secondary.withValues(alpha: 0.4)),
                        12.h,
                        Text(
                          'Select a staff member above',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: crm.secondary.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  )
                : attendanceAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('Error: $e')),
                    data: (_) => _CalendarGrid(
                      year:          filter.year,
                      month:         filter.month,
                      timeboxMap:    timeboxMap,
                      leaveDates:    leaveDates,
                      holidayDates:  holidayDates,
                      crm:           crm,
                      theme:         theme,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Expand a date range into a list of ISO date strings.
  static List<String> _dateRange(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      final dates = <String>[];
      for (var d = s;
          !d.isAfter(e);
          d = d.add(const Duration(days: 1))) {
        dates.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
      }
      return dates;
    } catch (_) {
      return [];
    }
  }
}

// ── Controls bar (employee picker + month navigator) ──────────────────────────
class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.theme,
    required this.crm,
    required this.filter,
    required this.staffAsync,
    required this.onFilterChanged,
  });

  final ThemeData theme;
  final CrmTheme crm;
  final HrFilter filter;
  final AsyncValue<List<HrStaffMember>> staffAsync;
  final ValueChanged<HrFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Employee dropdown
          Expanded(
            flex: 2,
            child: staffAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e',
                  style: TextStyle(color: theme.colorScheme.error)),
              data: (staff) => DropdownButtonFormField<int?>(
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Select —')),
                  ...staff.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          '${s.fullName} (${s.department})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (v) =>
                    onFilterChanged(filter.copyWith(userId: v)),
              ),
            ),
          ),
          12.w,
          // Month navigator
          _MonthNav(
            year:  filter.year,
            month: filter.month,
            crm:   crm,
            onChanged: (y, m) =>
                onFilterChanged(filter.copyWith(year: y, month: m)),
          ),
        ],
      ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.year,
    required this.month,
    required this.crm,
    required this.onChanged,
  });

  final int year;
  final int month;
  final CrmTheme crm;
  final void Function(int year, int month) onChanged;

  void _prev() {
    var m = month - 1;
    var y = year;
    if (m < 1) { m = 12; y--; }
    onChanged(y, m);
  }

  void _next() {
    var m = month + 1;
    var y = year;
    if (m > 12) { m = 1; y++; }
    onChanged(y, m);
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _prev,
          iconSize: 20,
        ),
        Text(
          '${months[month]} $year',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: crm.accent,
            fontSize: 14,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _next,
          iconSize: 20,
        ),
      ],
    );
  }
}

// ── Summary chips ─────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.summary,
    required this.crm,
    required this.theme,
  });

  final HrAttendanceSummary summary;
  final CrmTheme crm;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _Chip(label: 'Present',   value: summary.present,   color: Colors.green,   icon: Icons.check_circle_outline),
          8.w,
          _Chip(label: 'Completed', value: summary.completed, color: crm.accent,     icon: Icons.task_alt),
          8.w,
          _Chip(label: 'Missed',    value: summary.missed,    color: Colors.red,     icon: Icons.cancel_outlined),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          4.w,
          Text(
            '$value $label',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Monthly calendar grid ─────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.year,
    required this.month,
    required this.timeboxMap,
    required this.leaveDates,
    required this.holidayDates,
    required this.crm,
    required this.theme,
  });

  final int year;
  final int month;
  final Map<String, HrTimebox> timeboxMap;
  final Set<String> leaveDates;
  final Set<String> holidayDates;
  final CrmTheme crm;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final firstDay     = DateTime(year, month, 1);
    final daysInMonth  = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday; // Mon=1 … Sun=7
    final today        = DateTime.now();
    final todayStr     = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';

    const dayLabels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day headers
          Row(
            children: dayLabels
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: crm.secondary, fontWeight: FontWeight.w700)),
                      ),
                    ))
                .toList(),
          ),
          8.h,
          // Calendar cells
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: (startWeekday - 1) + daysInMonth,
            itemBuilder: (ctx, index) {
              if (index < startWeekday - 1) {
                return const SizedBox.shrink();
              }
              final day = index - (startWeekday - 1) + 1;
              final dateStr =
                  '$year-${month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
              final timebox  = timeboxMap[dateStr];
              final isLeave  = leaveDates.contains(dateStr);
              final isHoliday= holidayDates.contains(dateStr);
              final isToday  = dateStr == todayStr;

              return _CalCell(
                day:       day,
                timebox:   timebox,
                isLeave:   isLeave,
                isHoliday: isHoliday,
                isToday:   isToday,
                crm:       crm,
                theme:     theme,
              );
            },
          ),
          16.h,
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _Legend(color: Colors.green,  label: 'Present'),
              _Legend(color: Colors.teal,   label: 'Completed'),
              _Legend(color: Colors.red,    label: 'Missed'),
              _Legend(color: Colors.orange, label: 'On Leave'),
              _Legend(color: Colors.purple, label: 'Holiday'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalCell extends StatelessWidget {
  const _CalCell({
    required this.day,
    required this.timebox,
    required this.isLeave,
    required this.isHoliday,
    required this.isToday,
    required this.crm,
    required this.theme,
  });

  final int day;
  final HrTimebox? timebox;
  final bool isLeave;
  final bool isHoliday;
  final bool isToday;
  final CrmTheme crm;
  final ThemeData theme;

  Color get _cellColor {
    if (isLeave)               return Colors.orange.withValues(alpha: 0.15);
    if (isHoliday)             return Colors.purple.withValues(alpha: 0.12);
    if (timebox?.isCompleted == true) return Colors.teal.withValues(alpha: 0.15);
    if (timebox?.isPresent  == true)  return Colors.green.withValues(alpha: 0.12);
    if (timebox?.isMissed   == true)  return Colors.red.withValues(alpha: 0.12);
    return Colors.transparent;
  }

  Color get _borderColor {
    if (isToday)               return crm.accent;
    if (isLeave)               return Colors.orange.withValues(alpha: 0.5);
    if (isHoliday)             return Colors.purple.withValues(alpha: 0.4);
    if (timebox?.isCompleted == true) return Colors.teal.withValues(alpha: 0.5);
    if (timebox?.isPresent  == true)  return Colors.green.withValues(alpha: 0.4);
    if (timebox?.isMissed   == true)  return Colors.red.withValues(alpha: 0.4);
    return crm.border;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cellColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderColor, width: isToday ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isToday ? crm.accent : null,
            ),
          ),
          if (timebox != null)
            Text(
              timebox!.status,
              style: const TextStyle(fontSize: 8),
              overflow: TextOverflow.ellipsis,
            ),
          if (isLeave && timebox == null)
            const Text('leave', style: TextStyle(fontSize: 8, color: Colors.orange)),
          if (isHoliday && timebox == null && !isLeave)
            const Text('holiday', style: TextStyle(fontSize: 8, color: Colors.purple)),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2))),
        4.w,
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
