import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';

/// Calendar-day helpers for the Goals screens. Days are plain 'yyyy-MM-dd'
/// strings (the server reads them as IST days); weeks start on Monday.
String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime parseYmd(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Previous (-1) / next (+1) day, week or month.
DateTime shiftPeriod(String type, DateTime d, int dir) {
  switch (type) {
    case 'day':
      return DateTime(d.year, d.month, d.day + dir);
    case 'week':
      return DateTime(d.year, d.month, d.day + 7 * dir);
    default:
      return DateTime(d.year, d.month + dir, 1);
  }
}

/// Monday of the week containing [d].
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// "Mon, 19 Oct 2026" · "19 Oct – 25 Oct 2026" · "October 2026"
String periodLabel(String type, DateTime d) {
  switch (type) {
    case 'day':
      return DateFormat('EEE, d MMM yyyy').format(d);
    case 'week':
      final s = weekStart(d);
      final e = DateTime(s.year, s.month, s.day + 6);
      return '${DateFormat('d MMM').format(s)} – ${DateFormat('d MMM yyyy').format(e)}';
    default:
      return DateFormat('MMMM yyyy').format(d);
  }
}

const kGoalPeriodTypes = [('day', 'Day'), ('week', 'Week'), ('month', 'Month')];

/// Day / Week / Month switch + previous / next arrows + date picker + Today.
class GoalPeriodNav extends StatelessWidget {
  final String type;
  final DateTime date;
  final ValueChanged<String> onType;
  final ValueChanged<DateTime> onDate;

  /// Optional "counted on" switch (added date vs event date).
  final String? basis;
  final ValueChanged<String>? onBasis;

  const GoalPeriodNav({
    super.key,
    required this.type,
    required this.date,
    required this.onType,
    required this.onDate,
    this.basis,
    this.onBasis,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      helpText: 'Pick a ${type == 'month' ? 'day in the month' : type == 'week' ? 'day in the week' : 'day'}',
    );
    if (picked != null) onDate(dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [for (final t in kGoalPeriodTypes) ButtonSegment(value: t.$1, label: Text(t.$2))],
          selected: {type},
          onSelectionChanged: (s) => onType(s.first),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Previous $type',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => onDate(shiftPeriod(type, date, -1)),
          ),
          OutlinedButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(periodLabel(type, date)),
          ),
          IconButton(
            tooltip: 'Next $type',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => onDate(shiftPeriod(type, date, 1)),
          ),
          TextButton(onPressed: () => onDate(dateOnly(DateTime.now())), child: const Text('Today')),
        ]),
        if (basis != null && onBasis != null)
          Tooltip(
            message: 'Added: counted on the day it was made. Event: counted on the event / trial date.',
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'added', label: Text('By added date')),
                ButtonSegment(value: 'event', label: Text('By event date')),
              ],
              selected: {basis!},
              onSelectionChanged: (s) => onBasis!(s.first),
              style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(crm.textPrimary)),
            ),
          ),
      ],
    );
  }
}
