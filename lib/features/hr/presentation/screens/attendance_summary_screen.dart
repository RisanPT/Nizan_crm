import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/attendance_report_html.dart';
import '../../../../core/utils/attendance_report_service.dart';
import '../../data/timebox_models.dart';
import '../../service/timebox_service.dart';
import 'attendance_detail_screen.dart';

/// Colour ramp for an attendance percentage.
Color attendanceColor(int percent, CrmTheme crm) {
  if (percent <= 0) return crm.textSecondary;
  if (percent >= 75) return crm.success;
  if (percent >= 50) return crm.warning;
  return crm.destructive;
}

/// An employee who never clocked into Timebox for the whole period.
bool isOnLeave(AttendanceSummaryRow r) =>
    r.daysPresent <= 0 && r.hoursWorked <= 0;

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// Distinct palette for the department donut.
const _deptPalette = [
  Color(0xFF6366F1), Color(0xFF22C55E), Color(0xFFF97316), Color(0xFFEAB308),
  Color(0xFF3B82F6), Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFF8B5CF6),
  Color(0xFFEF4444), Color(0xFF64748B),
];

enum _Filter { all, present, leave }

/// One display row = attendance summary + joined designation.
class _Row {
  final AttendanceSummaryRow s;
  final String designation;
  const _Row(this.s, this.designation);
  bool get leave => isOnLeave(s);
}

/// HR Attendance dashboard: KPIs, charts, a filterable staff table, and export.
class AttendanceSummaryScreen extends HookConsumerWidget {
  const AttendanceSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final month = ref.watch(timeboxMonthProvider);
    final summaryAsync = ref.watch(attendanceSummaryProvider);
    final employeesAsync = ref.watch(timeboxEmployeesProvider);

    final deptFilter = useState<String?>(null);
    final statusFilter = useState<_Filter>(_Filter.all);
    final query = useState<String>('');
    final busy = useState<bool>(false);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        backgroundColor: crm.sidebar,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(attendanceSummaryProvider);
              ref.invalidate(timeboxEmployeesProvider);
            },
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(attendanceSummaryProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Column(children: [
              _MonthBar(month: month, crm: crm, onChanged: (m) => ref.read(timeboxMonthProvider.notifier).state = m),
              const Expanded(child: _EmptyView(text: 'No attendance data for this month.')),
            ]);
          }

          final empById = <int, TimeboxEmployee>{};
          for (final e in employeesAsync.asData?.value ?? const <TimeboxEmployee>[]) {
            empById[e.id] = e;
          }

          // ── Global overview stats ────────────────────────────────────────
          final present = rows.where((r) => !isOnLeave(r)).toList();
          final leave = rows.where(isOnLeave).toList();
          final avg = present.isEmpty
              ? 0
              : (present.map((r) => r.attendancePercent).reduce((a, b) => a + b) / present.length).round();
          final totalHours = rows.fold<double>(0, (s, r) => s + r.hoursWorked);
          final depts = rows.map((r) => r.department).toSet().toList()..sort();
          final newHires = _newHiresInMonth(empById.values, month);

          // ── Filtered table rows ──────────────────────────────────────────
          final combined = rows.map((s) => _Row(s, empById[s.employeeId]?.designation ?? '')).toList();
          final q = query.value.trim().toLowerCase();
          var visible = combined.where((r) {
            if (deptFilter.value != null && r.s.department != deptFilter.value) return false;
            if (statusFilter.value == _Filter.present && r.leave) return false;
            if (statusFilter.value == _Filter.leave && !r.leave) return false;
            if (q.isNotEmpty &&
                !r.s.employeeName.toLowerCase().contains(q) &&
                !r.s.department.toLowerCase().contains(q) &&
                !r.designation.toLowerCase().contains(q)) {
              return false;
            }
            return true;
          }).toList();
          visible.sort((a, b) {
            if (a.leave != b.leave) return a.leave ? 1 : -1;
            return b.s.attendancePercent.compareTo(a.s.attendancePercent);
          });

          Future<void> download(bool csv) async {
            busy.value = true;
            try {
              final data = _buildReport(month, visible, employeesAsync.asData?.value ?? const []);
              if (csv) {
                await downloadAttendanceCsv(data);
              } else {
                await printAttendanceReport(data);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $e'), backgroundColor: crm.destructive),
                );
              }
            } finally {
              busy.value = false;
            }
          }

          final isWide = MediaQuery.of(context).size.width >= 900;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(attendanceSummaryProvider);
              ref.invalidate(timeboxEmployeesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _TopBar(
                  month: month,
                  crm: crm,
                  busy: busy.value,
                  onMonth: (m) => ref.read(timeboxMonthProvider.notifier).state = m,
                  onDownload: download,
                ),
                14.h,
                _KpiCards(
                  totalStaff: rows.length,
                  present: present.length,
                  leave: leave.length,
                  avg: avg,
                  totalHours: totalHours,
                  newHires: newHires,
                  departments: depts.length,
                  crm: crm,
                ),
                16.h,
                _ChartsRow(rows: rows, present: present, leave: leave, crm: crm),
                20.h,
                // ── Employees section with filters ─────────────────────────
                Row(
                  children: [
                    Text('Employees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                    8.w,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: crm.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
                      child: Text('${visible.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.accent)),
                    ),
                  ],
                ),
                12.h,
                _FilterRow(
                  crm: crm,
                  depts: depts,
                  deptValue: deptFilter.value,
                  status: statusFilter.value,
                  onDept: (d) => deptFilter.value = d,
                  onStatus: (s) => statusFilter.value = s,
                  onSearch: (v) => query.value = v,
                ),
                12.h,
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Center(child: Text('No employees match these filters.', style: TextStyle(color: crm.textSecondary))),
                  )
                else if (isWide)
                  _EmployeeTable(rows: visible, crm: crm, onTap: (r) => _openDetail(context, r))
                else
                  ...visible.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SummaryCard(row: r.s, designation: r.designation, crm: crm, onTap: () => _openDetail(context, r)),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, _Row r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AttendanceDetailScreen(
        employeeId: r.s.employeeId,
        employeeName: r.s.employeeName,
        department: r.s.department,
        attendancePercent: r.s.attendancePercent,
        daysPresent: r.s.daysPresent,
        expectedDays: r.s.expectedDays,
        hoursWorked: r.s.hoursWorked,
      ),
    ));
  }

  int _newHiresInMonth(Iterable<TimeboxEmployee> emps, TimeboxMonth m) {
    var n = 0;
    for (final e in emps) {
      final d = DateTime.tryParse(e.createdAt);
      if (d != null && d.year == m.year && d.month == m.month) n++;
    }
    return n;
  }

  AttendanceReportData _buildReport(
    TimeboxMonth m,
    List<_Row> visible,
    List<TimeboxEmployee> emps,
  ) {
    final present = visible.where((r) => !r.leave).toList();
    final avg = present.isEmpty
        ? 0
        : (present.map((r) => r.s.attendancePercent).reduce((a, b) => a + b) / present.length).round();
    final totalHours = visible.fold<double>(0, (s, r) => s + r.s.hoursWorked);
    return AttendanceReportData(
      periodLabel: '${_fullMonths[m.month]} ${m.year}',
      modeLabel: 'Timebox',
      totalStaff: visible.length,
      presentCount: present.length,
      leaveCount: visible.length - present.length,
      avgAttendance: avg,
      totalHours: totalHours,
      newHires: _newHiresInMonth(emps, m),
      departments: visible.map((r) => r.s.department).toSet().length,
      rows: visible
          .map((r) => AttendanceReportRow(
                name: r.s.employeeName,
                department: r.s.department,
                designation: r.designation,
                status: r.leave ? 'On Leave' : 'Present',
                daysPresent: r.s.daysPresent,
                expectedDays: r.s.expectedDays,
                attendancePercent: r.s.attendancePercent,
                hoursWorked: r.s.hoursWorked,
                daysNoLogout: r.s.daysNoLogout,
              ))
          .toList(),
    );
  }
}

const _fullMonths = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// ── Top bar: month navigator + download menu ──────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.month,
    required this.crm,
    required this.busy,
    required this.onMonth,
    required this.onDownload,
  });
  final TimeboxMonth month;
  final CrmTheme crm;
  final bool busy;
  final ValueChanged<TimeboxMonth> onMonth;
  final void Function(bool csv) onDownload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MonthBar(month: month, crm: crm, onChanged: onMonth)),
        10.w,
        PopupMenuButton<String>(
          enabled: !busy,
          tooltip: 'Download report',
          onSelected: (v) => onDownload(v == 'csv'),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_outlined, size: 18), SizedBox(width: 10), Text('Print / PDF')])),
            PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.table_view_outlined, size: 18), SizedBox(width: 10), Text('Download CSV')])),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: crm.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, size: 18, color: Colors.white),
              8.w,
              const Text('Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              4.w,
              const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.crm, required this.onChanged});
  final TimeboxMonth month;
  final CrmTheme crm;
  final ValueChanged<TimeboxMonth> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: crm.sidebar.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.keyboard_arrow_left_rounded, color: crm.accent, size: 26),
              onPressed: () => onChanged(month.prev),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${_fullMonths[month.month]} ${month.year}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary, fontSize: 15, letterSpacing: 0.3),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.keyboard_arrow_right_rounded, color: crm.accent, size: 26),
              onPressed: () => onChanged(month.next),
            ),
          ],
        ),
      ),
    );
  }
}

// ── KPI cards ─────────────────────────────────────────────────────────────────
class _KpiCards extends StatelessWidget {
  const _KpiCards({
    required this.totalStaff,
    required this.present,
    required this.leave,
    required this.avg,
    required this.totalHours,
    required this.newHires,
    required this.departments,
    required this.crm,
  });
  final int totalStaff, present, leave, avg, newHires, departments;
  final double totalHours;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _Kpi(label: 'Total Staff', value: '$totalStaff', icon: Icons.groups_rounded, color: crm.accent),
      _Kpi(label: 'Present', value: '$present', icon: Icons.how_to_reg_rounded, color: crm.success, sub: totalStaff > 0 ? '${(present / totalStaff * 100).round()}% of total' : null),
      _Kpi(label: 'On Leave', value: '$leave', icon: Icons.beach_access_rounded, color: crm.warning, sub: totalStaff > 0 ? '${(leave / totalStaff * 100).round()}% of total' : null),
      _Kpi(label: 'Avg Attendance', value: '$avg%', icon: Icons.percent_rounded, color: attendanceColor(avg, crm)),
      _Kpi(label: 'Total Hours', value: totalHours.toStringAsFixed(0), icon: Icons.schedule_rounded, color: crm.primary),
      _Kpi(label: 'New Hires', value: '$newHires', icon: Icons.person_add_alt_1_rounded, color: const Color(0xFF6366F1)),
      _Kpi(label: 'Departments', value: '$departments', icon: Icons.apartment_rounded, color: const Color(0xFF14B8A6)),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      final perRow = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 560 ? 3 : 2);
      const gap = 10.0;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: tiles.map((t) => SizedBox(width: w, child: t)).toList());
    });
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon, required this.color, this.sub});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: color),
            ),
          ]),
          12.h,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: crm.textPrimary, letterSpacing: -0.5)),
          ),
          4.h,
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (sub != null) ...[
            2.h,
            Text(sub!, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

// ── Charts row: attendance donut + department donut + dept bars ────────────────
class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.rows, required this.present, required this.leave, required this.crm});
  final List<AttendanceSummaryRow> rows;
  final List<AttendanceSummaryRow> present;
  final List<AttendanceSummaryRow> leave;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    // Attendance band slices.
    final good = present.where((r) => r.attendancePercent >= 75).length;
    final moderate = present.where((r) => r.attendancePercent >= 50 && r.attendancePercent < 75).length;
    final low = present.where((r) => r.attendancePercent > 0 && r.attendancePercent < 50).length;
    final attendanceSlices = <_Slice>[
      _Slice('Good (75%+)', good.toDouble(), crm.success),
      _Slice('Moderate (50-74%)', moderate.toDouble(), crm.warning),
      _Slice('Low (<50%)', low.toDouble(), crm.destructive),
      _Slice('On Leave', leave.length.toDouble(), crm.textSecondary),
    ].where((s) => s.value > 0).toList();

    // Department distribution.
    final deptCounts = <String, int>{};
    for (final r in rows) {
      deptCounts[r.department] = (deptCounts[r.department] ?? 0) + 1;
    }
    final deptEntries = deptCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final deptSlices = <_Slice>[
      for (var i = 0; i < deptEntries.length; i++)
        _Slice(deptEntries[i].key, deptEntries[i].value.toDouble(), _deptPalette[i % _deptPalette.length]),
    ];

    // Avg attendance by department (bars).
    final deptAvg = <String, double>{};
    for (final e in deptEntries) {
      final members = present.where((r) => r.department == e.key).toList();
      deptAvg[e.key] = members.isEmpty ? 0 : members.map((r) => r.attendancePercent).reduce((a, b) => a + b) / members.length;
    }
    final barEntries = deptAvg.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final cards = <Widget>[
      _DonutCard(title: 'Attendance Overview', total: rows.length, totalLabel: 'Staff', slices: attendanceSlices, crm: crm),
      _DonutCard(title: 'Department Distribution', total: rows.length, totalLabel: 'Staff', slices: deptSlices, crm: crm),
      _DeptBarsCard(title: 'Avg Attendance by Dept', entries: barEntries, crm: crm),
    ];

    return LayoutBuilder(builder: (ctx, c) {
      final perRow = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
      const gap = 14.0;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: cards.map((card) => SizedBox(width: w, child: card)).toList());
    });
  }
}

class _Slice {
  final String label;
  final double value;
  final Color color;
  const _Slice(this.label, this.value, this.color);
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.title, required this.total, required this.totalLabel, required this.slices, required this.crm});
  final String title;
  final int total;
  final String totalLabel;
  final List<_Slice> slices;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    final sum = slices.fold<double>(0, (s, e) => s + e.value);
    return _Panel(
      crm: crm,
      title: title,
      child: Column(
        children: [
          14.h,
          SizedBox(
            width: 128,
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (sum > 0)
                  PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      for (final s in slices)
                        PieChartSectionData(value: s.value, color: s.color, radius: 24, showTitle: false),
                    ],
                  ))
                else
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: crm.border, width: 8)),
                  ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$total', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                  Text(totalLabel, style: TextStyle(fontSize: 10, color: crm.textSecondary)),
                ]),
              ],
            ),
          ),
          14.h,
          ...slices.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  8.w,
                  Expanded(child: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textPrimary))),
                  Text(
                    '${s.value.toInt()}${sum > 0 ? '  (${(s.value / sum * 100).round()}%)' : ''}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}

class _DeptBarsCard extends StatelessWidget {
  const _DeptBarsCard({required this.title, required this.entries, required this.crm});
  final String title;
  final List<MapEntry<String, double>> entries;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      crm: crm,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          14.h,
          if (entries.isEmpty)
            Padding(padding: const EdgeInsets.all(20), child: Text('No data.', style: TextStyle(color: crm.textSecondary)))
          else
            ...entries.map((e) {
              final pct = e.value.round();
              final color = attendanceColor(pct, crm);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textPrimary, fontWeight: FontWeight.w600))),
                      Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                    ]),
                    6.h,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: crm.border.withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.crm, required this.title, required this.child});
  final CrmTheme crm;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          child,
        ],
      ),
    );
  }
}

// ── Filters (search + department + status) ────────────────────────────────────
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.crm,
    required this.depts,
    required this.deptValue,
    required this.status,
    required this.onDept,
    required this.onStatus,
    required this.onSearch,
  });
  final CrmTheme crm;
  final List<String> depts;
  final String? deptValue;
  final _Filter status;
  final ValueChanged<String?> onDept;
  final ValueChanged<_Filter> onStatus;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final search = SizedBox(
      height: 44,
      child: TextField(
        onChanged: onSearch,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search name, department, designation…',
          hintStyle: TextStyle(fontSize: 13, color: crm.textSecondary),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: crm.textSecondary),
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: crm.surface,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.border.withValues(alpha: 0.7))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.accent)),
        ),
      ),
    );

    final dept = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border.withValues(alpha: 0.7))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: deptValue,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded, color: crm.textSecondary),
          style: TextStyle(fontSize: 13, color: crm.textPrimary),
          hint: Text('All Departments', style: TextStyle(fontSize: 13, color: crm.textSecondary)),
          items: [
            DropdownMenuItem(value: null, child: Text('All Departments', style: TextStyle(fontSize: 13, color: crm.textPrimary))),
            ...depts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
          ],
          onChanged: onDept,
        ),
      ),
    );

    final segments = _StatusSegments(status: status, crm: crm, onChanged: onStatus);

    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth >= 720) {
        return Row(children: [
          Expanded(flex: 3, child: search),
          10.w,
          Expanded(flex: 2, child: dept),
          10.w,
          segments,
        ]);
      }
      return Column(children: [
        search,
        10.h,
        Row(children: [Expanded(child: dept)]),
        10.h,
        segments,
      ]);
    });
  }
}

class _StatusSegments extends StatelessWidget {
  const _StatusSegments({required this.status, required this.crm, required this.onChanged});
  final _Filter status;
  final CrmTheme crm;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(_Filter f, String label, Color color) {
      final sel = status == f;
      return GestureDetector(
        onTap: () => onChanged(f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: sel ? color.withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? color : crm.textSecondary)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border.withValues(alpha: 0.6))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg(_Filter.all, 'All', crm.accent),
        seg(_Filter.present, 'Present', crm.success),
        seg(_Filter.leave, 'On Leave', crm.warning),
      ]),
    );
  }
}

// ── Desktop table ─────────────────────────────────────────────────────────────
class _EmployeeTable extends StatelessWidget {
  const _EmployeeTable({required this.rows, required this.crm, required this.onTap});
  final List<_Row> rows;
  final CrmTheme crm;
  final ValueChanged<_Row> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: crm.sidebar.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Expanded(flex: 3, child: _Th('Employee')),
              const Expanded(flex: 2, child: _Th('Department')),
              const Expanded(flex: 2, child: _Th('Designation')),
              const Expanded(flex: 2, child: _Th('Days')),
              const Expanded(flex: 2, child: _Th('Hours')),
              const Expanded(flex: 2, child: _Th('Attendance')),
              const SizedBox(width: 40),
            ]),
          ),
          ...rows.asMap().entries.map((entry) {
            final r = entry.value;
            final color = r.leave ? crm.warning : attendanceColor(r.s.attendancePercent, crm);
            return InkWell(
              onTap: () => onTap(r),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: crm.border.withValues(alpha: 0.5))),
                ),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: Row(children: [
                      _Avatar(name: r.s.employeeName, color: color, size: 34),
                      10.w,
                      Expanded(
                        child: Text(r.s.employeeName.trim().isEmpty ? 'Unknown' : r.s.employeeName.trim(),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ),
                    ]),
                  ),
                  Expanded(flex: 2, child: Text(r.s.department, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
                  Expanded(flex: 2, child: Text(r.designation.isEmpty ? '—' : r.designation, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
                  Expanded(flex: 2, child: Text('${r.s.daysPresent}/${r.s.expectedDays}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                  Expanded(flex: 2, child: Text('${r.s.hoursWorked.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 12.5))),
                  Expanded(
                    flex: 2,
                    child: r.leave
                        ? _Tag(label: 'On Leave', color: crm.warning)
                        : Row(children: [
                            Text('${r.s.attendancePercent}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                          ]),
                  ),
                  SizedBox(width: 40, child: Icon(Icons.chevron_right_rounded, color: crm.textSecondary.withValues(alpha: 0.6))),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Text(text.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: crm.textSecondary, letterSpacing: 0.5));
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      ),
    );
  }
}

// ── Mobile card ───────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.row, required this.designation, required this.crm, required this.onTap});
  final AttendanceSummaryRow row;
  final String designation;
  final CrmTheme crm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final leave = isOnLeave(row);
    final color = leave ? crm.warning : attendanceColor(row.attendancePercent, crm);
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _Avatar(name: row.employeeName, color: color, size: 44),
                  12.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.employeeName.trim().isEmpty ? 'Unknown' : row.employeeName.trim(),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                        4.h,
                        Text(designation.isEmpty ? row.department : '$designation · ${row.department}',
                            style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  10.w,
                  if (leave)
                    _Tag(label: 'On Leave', color: crm.warning)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
                      child: Text('${row.attendancePercent}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                    ),
                  6.w,
                  Icon(Icons.chevron_right_rounded, color: crm.textSecondary.withValues(alpha: 0.5), size: 22),
                ]),
                if (leave) ...[
                  10.h,
                  Text('No Timebox login this month.', style: TextStyle(fontSize: 12, color: crm.textSecondary, fontStyle: FontStyle.italic)),
                ] else ...[
                  12.h,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: row.expectedDays > 0 ? (row.daysPresent / row.expectedDays).clamp(0.0, 1.0) : 0,
                      minHeight: 7,
                      backgroundColor: crm.border.withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  10.h,
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _MiniChip(icon: Icons.event_available_rounded, label: '${row.daysPresent}/${row.expectedDays} days', color: crm.accent),
                    _MiniChip(icon: Icons.schedule_rounded, label: '${row.hoursWorked.toStringAsFixed(1)} h', color: crm.primary),
                    if (row.daysNoLogout > 0) _MiniChip(icon: Icons.error_outline_rounded, label: '${row.daysNoLogout} no-logout', color: crm.warning),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color, this.size = 44});
  final String name;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Text(_initials(name), style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w900, color: color)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        6.w,
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, height: 1.1)),
      ]),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.event_busy_outlined, size: 54, color: crm.textSecondary.withValues(alpha: 0.5)),
        12.h,
        Text(text, style: TextStyle(color: crm.textSecondary)),
      ]),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: crm.destructive),
          12.h,
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
          16.h,
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]),
      ),
    );
  }
}
