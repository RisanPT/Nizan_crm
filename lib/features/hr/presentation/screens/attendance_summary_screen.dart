import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../data/timebox_models.dart';
import '../../service/timebox_service.dart';
import 'attendance_detail_screen.dart';

const _months = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

Color attendanceColor(int percent, CrmTheme crm) {
  if (percent <= 0) return crm.textSecondary;
  if (percent >= 75) return crm.success;
  if (percent >= 50) return crm.warning;
  return crm.destructive;
}

/// HR landing: monthly attendance summary for every Timebox employee.
class AttendanceSummaryScreen extends HookConsumerWidget {
  const AttendanceSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final month = ref.watch(timeboxMonthProvider);
    final summaryAsync = ref.watch(attendanceSummaryProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: crm.sidebar,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(attendanceSummaryProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthBar(
            month: month,
            crm: crm,
            onChanged: (m) => ref.read(timeboxMonthProvider.notifier).state = m,
          ),
          const Divider(height: 1),
          Expanded(
            child: summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(attendanceSummaryProvider),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const _EmptyView(text: 'No attendance data for this month.');
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(attendanceSummaryProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                    children: [
                      _StatsHeader(rows: rows, crm: crm, theme: theme),
                      12.h,
                      ...(_sorted(rows)).map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SummaryCard(
                              row: r,
                              crm: crm,
                              theme: theme,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AttendanceDetailScreen(
                                    employeeId: r.employeeId,
                                    employeeName: r.employeeName,
                                    department: r.department,
                                  ),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<AttendanceSummaryRow> _sorted(List<AttendanceSummaryRow> rows) {
    final list = [...rows];
    list.sort((a, b) => b.attendancePercent.compareTo(a.attendancePercent));
    return list;
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.crm, required this.onChanged});
  final TimeboxMonth month;
  final CrmTheme crm;
  final ValueChanged<TimeboxMonth> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(month.prev),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_months[month.month]} ${month.year}',
                style: TextStyle(fontWeight: FontWeight.w700, color: crm.accent, fontSize: 15),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(month.next),
          ),
        ],
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.rows, required this.crm, required this.theme});
  final List<AttendanceSummaryRow> rows;
  final CrmTheme crm;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final active = rows.where((r) => r.attendancePercent > 0).toList();
    final avg = active.isEmpty
        ? 0
        : (active.map((r) => r.attendancePercent).reduce((a, b) => a + b) / active.length).round();
    final totalHours = rows.fold<double>(0, (s, r) => s + r.hoursWorked);
    final noData = rows.where((r) => r.attendancePercent == 0).length;

    return Row(
      children: [
        Expanded(child: _StatTile(label: 'Staff', value: '${rows.length}', icon: Icons.groups_outlined, color: crm.accent)),
        8.w,
        Expanded(child: _StatTile(label: 'Avg Attendance', value: '$avg%', icon: Icons.percent, color: attendanceColor(avg, crm))),
        8.w,
        Expanded(child: _StatTile(label: 'Total Hours', value: totalHours.toStringAsFixed(0), icon: Icons.schedule, color: crm.primary)),
        8.w,
        Expanded(child: _StatTile(label: 'No Data', value: '$noData', icon: Icons.help_outline, color: crm.textSecondary)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          6.h,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          ),
          2.h,
          Text(label, style: TextStyle(fontSize: 10.5, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.row, required this.crm, required this.theme, required this.onTap});
  final AttendanceSummaryRow row;
  final CrmTheme crm;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = attendanceColor(row.attendancePercent, crm);
    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
          ),
          child: Row(
            children: [
              _PercentRing(percent: row.attendancePercent, color: color),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.employeeName.trim().isEmpty ? 'Unknown' : row.employeeName.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    2.h,
                    Text(row.department, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                    8.h,
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniChip(icon: Icons.event_available_outlined, label: '${row.daysPresent}/${row.expectedDays} days', color: crm.accent),
                        _MiniChip(icon: Icons.schedule, label: '${row.hoursWorked.toStringAsFixed(1)} h', color: crm.primary),
                        if (row.daysNoLogout > 0)
                          _MiniChip(icon: Icons.logout, label: '${row.daysNoLogout} no-logout', color: crm.warning),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: crm.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PercentRing extends StatelessWidget {
  const _PercentRing({required this.percent, required this.color});
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: (percent.clamp(0, 100)) / 100,
              strokeWidth: 5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text('$percent%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          4.w,
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_outlined, size: 54, color: crm.textSecondary.withValues(alpha: 0.5)),
          12.h,
          Text(text, style: TextStyle(color: crm.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: crm.destructive),
            12.h,
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
            16.h,
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
