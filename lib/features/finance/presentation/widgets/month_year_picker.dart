import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';

const _monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// A compact month + year picker dialog (calendar-style), returning the chosen
/// `(month 1-12, year)` or null if dismissed. Used by the finance review /
/// planning / decisions screens so tapping the month opens a picker instead of
/// only stepping one month at a time.
Future<({int month, int year})?> showMonthYearPicker(
  BuildContext context, {
  required int month,
  required int year,
}) {
  return showDialog<({int month, int year})>(
    context: context,
    builder: (_) => _MonthYearDialog(month: month, year: year),
  );
}

class _MonthYearDialog extends StatefulWidget {
  const _MonthYearDialog({required this.month, required this.year});
  final int month, year;

  @override
  State<_MonthYearDialog> createState() => _MonthYearDialogState();
}

class _MonthYearDialogState extends State<_MonthYearDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.year;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final now = DateTime.now();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Year stepper.
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(
                onPressed: () => setState(() => _year--),
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
              ),
              Text('$_year', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary)),
              IconButton(
                onPressed: () => setState(() => _year++),
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
              ),
            ]),
            const SizedBox(height: 12),
            // 12-month grid (3 rows × 4).
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                for (var m = 1; m <= 12; m++)
                  _monthCell(crm, m,
                      isCurrent: m == now.month && _year == now.year,
                      isSelected: m == widget.month && _year == widget.year),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _monthCell(CrmTheme crm, int m, {required bool isCurrent, required bool isSelected}) {
    return Material(
      color: isSelected ? crm.primary : crm.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.pop(context, (month: m, year: _year)),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isCurrent && !isSelected ? Border.all(color: crm.primary, width: 1.5) : null,
          ),
          child: Text(
            _monthNames[m],
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : crm.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
