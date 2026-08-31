import 'package:flutter/material.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// A compact, month-native range picker (two month grids, no day scrolling).
/// Returns a [DateTimeRange] spanning whole months — start = 1st of the start
/// month, end = last day of the end month — or null if cancelled.
Future<DateTimeRange?> showMonthRangePicker(
  BuildContext context, {
  DateTimeRange? initial,
  int minYear = 2020,
  int maxYear = 2035,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _MonthRangeDialog(initial: initial, minYear: minYear, maxYear: maxYear),
  );
}

class _MonthRangeDialog extends StatefulWidget {
  const _MonthRangeDialog({this.initial, required this.minYear, required this.maxYear});
  final DateTimeRange? initial;
  final int minYear;
  final int maxYear;
  @override
  State<_MonthRangeDialog> createState() => _MonthRangeDialogState();
}

class _MonthRangeDialogState extends State<_MonthRangeDialog> {
  late DateTime _start; // 1st of the start month
  late DateTime _end; // 1st of the end month

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = widget.initial != null
        ? DateTime(widget.initial!.start.year, widget.initial!.start.month)
        : DateTime(now.year, now.month);
    _end = widget.initial != null
        ? DateTime(widget.initial!.end.year, widget.initial!.end.month)
        : DateTime(now.year, now.month);
  }

  bool _before(DateTime a, DateTime b) => a.year < b.year || (a.year == b.year && a.month < b.month);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: crm.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Select month range', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
            const SizedBox(height: 4),
            Text(
              '${_monthsShort[_start.month - 1]} ${_start.year}  –  ${_monthsShort[_end.month - 1]} ${_end.year}',
              style: TextStyle(fontSize: 13, color: crm.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _panel(crm, 'From', _start, (d) => setState(() {
                      _start = d;
                      if (_before(_end, _start)) _end = _start;
                    })),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _panel(crm, 'To', _end, (d) => setState(() {
                      _end = d;
                      if (_before(_end, _start)) _start = _end;
                    })),
              ),
            ]),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: crm.primary),
                onPressed: () => Navigator.pop(
                  context,
                  DateTimeRange(
                    start: DateTime(_start.year, _start.month, 1),
                    end: DateTime(_end.year, _end.month + 1, 0),
                  ),
                ),
                child: const Text('Apply'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _panel(CrmTheme crm, String label, DateTime value, ValueChanged<DateTime> onPick) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: crm.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: crm.border.withValues(alpha: 0.6)),
        ),
        child: Row(children: [
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: value.year > widget.minYear ? () => onPick(DateTime(value.year - 1, value.month)) : null,
            icon: Icon(Icons.chevron_left, color: crm.accent),
          ),
          Expanded(child: Center(child: Text('${value.year}', style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary)))),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: value.year < widget.maxYear ? () => onPick(DateTime(value.year + 1, value.month)) : null,
            icon: Icon(Icons.chevron_right, color: crm.accent),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.9,
        children: [for (var mo = 1; mo <= 12; mo++) _monthCell(crm, mo, value, onPick)],
      ),
    ]);
  }

  Widget _monthCell(CrmTheme crm, int mo, DateTime value, ValueChanged<DateTime> onPick) {
    final selected = value.month == mo;
    final cell = DateTime(value.year, mo);
    final inRange = !_before(cell, _start) && !_before(_end, cell);
    return InkWell(
      onTap: () => onPick(DateTime(value.year, mo)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? crm.primary : (inRange ? crm.primary.withValues(alpha: 0.10) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? crm.primary : crm.border.withValues(alpha: 0.5)),
        ),
        child: Text(
          _monthsShort[mo - 1],
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : crm.textPrimary),
        ),
      ),
    );
  }
}

/// A single month + year picker (year stepper + month grid). Returns the 1st of
/// the chosen month, or null. Use to "jump to month" instead of arrow-stepping.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  DateTime? initial,
  int minYear = 2020,
  int maxYear = 2035,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _MonthPickerDialog(initial: initial, minYear: minYear, maxYear: maxYear),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({this.initial, required this.minYear, required this.maxYear});
  final DateTime? initial;
  final int minYear;
  final int maxYear;
  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = (widget.initial ?? DateTime.now()).year;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final sel = widget.initial;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: crm.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Jump to month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: crm.border.withValues(alpha: 0.6)),
              ),
              child: Row(children: [
                IconButton(
                  onPressed: _year > widget.minYear ? () => setState(() => _year--) : null,
                  icon: Icon(Icons.chevron_left, color: crm.accent),
                ),
                Expanded(child: Center(child: Text('$_year', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: crm.primary)))),
                IconButton(
                  onPressed: _year < widget.maxYear ? () => setState(() => _year++) : null,
                  icon: Icon(Icons.chevron_right, color: crm.accent),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: [
                for (var mo = 1; mo <= 12; mo++)
                  Builder(builder: (_) {
                    final selected = sel != null && sel.year == _year && sel.month == mo;
                    return InkWell(
                      onTap: () => Navigator.pop(context, DateTime(_year, mo, 1)),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? crm.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: selected ? crm.primary : crm.border.withValues(alpha: 0.5)),
                        ),
                        child: Text(_monthsShort[mo - 1],
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : crm.textPrimary)),
                      ),
                    );
                  }),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

/// The standard day-precision range calendar, themed in the app's colours so it
/// stops looking like a stock Material dialog. Use for report/filter ranges that
/// genuinely need day precision (P&L, sales reports, client filters).
Future<DateTimeRange?> showBrandedDateRangePicker(
  BuildContext context, {
  DateTimeRange? initialDateRange,
  DateTime? firstDate,
  DateTime? lastDate,
  String? helpText,
}) {
  final crm = context.crmColors;
  return showDateRangePicker(
    context: context,
    firstDate: firstDate ?? DateTime(2020),
    lastDate: lastDate ?? DateTime(2035, 12, 31),
    initialDateRange: initialDateRange,
    helpText: helpText,
    builder: (ctx, child) {
      final base = Theme.of(ctx);
      return Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            primary: crm.primary,
            onPrimary: Colors.white,
            surface: crm.surface,
            onSurface: crm.textPrimary,
            secondary: crm.accent,
          ),
        ),
        child: child!,
      );
    },
  );
}
