import 'package:csv/csv.dart';

/// One employee row in the attendance report.
class AttendanceReportRow {
  final String name;
  final String department;
  final String designation;
  final String status; // 'Present' | 'On Leave'
  final int daysPresent;
  final int expectedDays;
  final int attendancePercent;
  final double hoursWorked;
  final int daysNoLogout;

  const AttendanceReportRow({
    required this.name,
    required this.department,
    required this.designation,
    required this.status,
    required this.daysPresent,
    required this.expectedDays,
    required this.attendancePercent,
    required this.hoursWorked,
    required this.daysNoLogout,
  });
}

/// Everything the attendance report needs, independent of Flutter widgets so it
/// can be shared by the web (print) and mobile (PDF) exporters.
class AttendanceReportData {
  final String periodLabel; // e.g. "July 2026"
  final String modeLabel; // "Demo data" | "Live"
  final int totalStaff;
  final int presentCount;
  final int leaveCount;
  final int avgAttendance;
  final double totalHours;
  final int newHires;
  final int departments;
  final List<AttendanceReportRow> rows;

  const AttendanceReportData({
    required this.periodLabel,
    required this.modeLabel,
    required this.totalStaff,
    required this.presentCount,
    required this.leaveCount,
    required this.avgAttendance,
    required this.totalHours,
    required this.newHires,
    required this.departments,
    required this.rows,
  });
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _attColor(int p) {
  if (p <= 0) return '#9CA3AF';
  if (p >= 75) return '#16A34A';
  if (p >= 50) return '#D97706';
  return '#DC2626';
}

/// Printable HTML for the monthly attendance report.
String buildAttendanceReportHtml(AttendanceReportData d) {
  final kpis = <List<String>>[
    ['Total Staff', '${d.totalStaff}'],
    ['Present', '${d.presentCount}'],
    ['On Leave', '${d.leaveCount}'],
    ['Avg Attendance', '${d.avgAttendance}%'],
    ['Total Hours', d.totalHours.toStringAsFixed(0)],
    ['New Hires', '${d.newHires}'],
    ['Departments', '${d.departments}'],
  ];

  final kpiHtml = kpis
      .map((k) => '''
        <div class="kpi">
          <div class="kpi-val">${_esc(k[1])}</div>
          <div class="kpi-lbl">${_esc(k[0])}</div>
        </div>''')
      .join();

  final rowsHtml = d.rows.map((r) {
    final c = _attColor(r.attendancePercent);
    final statusBadge = r.status == 'On Leave'
        ? '<span class="badge leave">On Leave</span>'
        : '<span class="badge present">Present</span>';
    return '''
      <tr>
        <td>${_esc(r.name)}</td>
        <td>${_esc(r.department)}</td>
        <td>${_esc(r.designation)}</td>
        <td>$statusBadge</td>
        <td class="num">${r.daysPresent}/${r.expectedDays}</td>
        <td class="num">${r.hoursWorked.toStringAsFixed(1)}</td>
        <td class="num" style="color:$c;font-weight:700">${r.attendancePercent}%</td>
      </tr>''';
  }).join();

  return '''<!doctype html>
<html><head><meta charset="utf-8"><title>Attendance Report · ${_esc(d.periodLabel)}</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; color:#1F2937; margin:0; padding:28px; }
  .head { text-align:center; border-bottom:2px solid #601A29; padding-bottom:12px; margin-bottom:18px; }
  .brand { font-size:22px; font-weight:800; color:#601A29; letter-spacing:.5px; }
  .sub { font-size:11px; color:#6B7280; margin-top:2px; }
  .kpis { display:flex; flex-wrap:wrap; gap:10px; margin-bottom:18px; }
  .kpi { flex:1 1 120px; border:1px solid #E5E7EB; border-radius:8px; padding:10px 12px; }
  .kpi-val { font-size:18px; font-weight:800; color:#601A29; }
  .kpi-lbl { font-size:10px; color:#6B7280; margin-top:2px; text-transform:uppercase; letter-spacing:.4px; }
  table { width:100%; border-collapse:collapse; font-size:11px; }
  th { background:#601A29; color:#fff; text-align:left; padding:7px 8px; font-weight:600; }
  td { padding:6px 8px; border-bottom:1px solid #EEF0F2; }
  td.num, th.num { text-align:right; }
  tr:nth-child(even) td { background:#FAFAFA; }
  .badge { font-size:9px; font-weight:700; padding:2px 7px; border-radius:20px; }
  .badge.present { background:#DCFCE7; color:#166534; }
  .badge.leave { background:#FEF3C7; color:#92400E; }
  .foot { margin-top:16px; font-size:9px; color:#9CA3AF; }
  @media print { body { padding:0; } }
</style></head>
<body>
  <div class="head">
    <div class="brand">TEAM N MAKEOVERS</div>
    <div class="sub">HR · Attendance Report &middot; ${_esc(d.periodLabel)} &middot; ${_esc(d.modeLabel)}</div>
  </div>
  <div class="kpis">$kpiHtml</div>
  <table>
    <thead><tr>
      <th>Name</th><th>Department</th><th>Designation</th><th>Status</th>
      <th class="num">Days</th><th class="num">Hours</th><th class="num">Attendance</th>
    </tr></thead>
    <tbody>$rowsHtml</tbody>
  </table>
  <div class="foot">Source: Timebox attendance software. Attendance % = days present / expected working days for the month.</div>
</body></html>''';
}

/// CSV of the same rows, for spreadsheet download.
String buildAttendanceCsv(AttendanceReportData d) {
  final rows = <List<dynamic>>[
    ['Name', 'Department', 'Designation', 'Status', 'Days Present', 'Expected Days', 'Attendance %', 'Hours Worked', 'No-logout Days'],
    for (final r in d.rows)
      [r.name, r.department, r.designation, r.status, r.daysPresent, r.expectedDays, r.attendancePercent, r.hoursWorked.toStringAsFixed(1), r.daysNoLogout],
  ];
  return const CsvEncoder().convert(rows);
}
