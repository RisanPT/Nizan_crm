// Models for the Timebox attendance software integration.
// Timebox employees have integer ids (not MongoDB ObjectIds).

int _asInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
double _asDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
int? _asIntN(dynamic v) => v == null ? null : ((v is num) ? v.toInt() : int.tryParse('$v'));
double? _asDoubleN(dynamic v) =>
    v == null ? null : ((v is num) ? v.toDouble() : double.tryParse('$v'));

/// A single employee record from Timebox.
class TimeboxEmployee {
  final int id;
  final String fullName;
  final String email;
  final String designation;
  final String department;
  final String role;
  final bool active;
  final bool worksSaturday;
  final bool hasTimebox;
  final String createdAt; // ISO date the employee joined

  const TimeboxEmployee({
    required this.id,
    required this.fullName,
    required this.email,
    required this.designation,
    required this.department,
    required this.role,
    required this.active,
    required this.worksSaturday,
    required this.hasTimebox,
    required this.createdAt,
  });

  factory TimeboxEmployee.fromJson(Map<String, dynamic> j) => TimeboxEmployee(
        id: _asInt(j['id']),
        fullName: j['full_name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        designation: j['designation'] as String? ?? '',
        department: j['department'] as String? ?? '',
        role: j['role'] as String? ?? '',
        active: j['active'] as bool? ?? true,
        worksSaturday: j['works_saturday'] as bool? ?? false,
        hasTimebox: j['has_timebox'] as bool? ?? false,
        createdAt: j['created_at'] as String? ?? '',
      );
}

/// A per-employee monthly attendance summary.
class AttendanceSummaryRow {
  final int employeeId;
  final String employeeName;
  final String department;
  final int expectedDays;
  final int workingDaysGross;
  final int excusedLeaveDays;
  final int daysPresent;
  final int daysWithLogout;
  final int daysNoLogout;
  final int daysHoursEstimated;
  final double hoursWorked;
  final int attendancePercent;

  const AttendanceSummaryRow({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.expectedDays,
    required this.workingDaysGross,
    required this.excusedLeaveDays,
    required this.daysPresent,
    required this.daysWithLogout,
    required this.daysNoLogout,
    required this.daysHoursEstimated,
    required this.hoursWorked,
    required this.attendancePercent,
  });

  factory AttendanceSummaryRow.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'] as Map<String, dynamic>? ?? const {};
    return AttendanceSummaryRow(
      employeeId: _asInt(emp['id']),
      employeeName: emp['name'] as String? ?? '',
      department: j['department'] as String? ?? '',
      expectedDays: _asInt(j['expected_days']),
      workingDaysGross: _asInt(j['working_days_gross']),
      excusedLeaveDays: _asInt(j['excused_leave_days']),
      daysPresent: _asInt(j['days_present']),
      daysWithLogout: _asInt(j['days_with_logout']),
      daysNoLogout: _asInt(j['days_no_logout']),
      daysHoursEstimated: _asInt(j['days_hours_estimated']),
      hoursWorked: _asDouble(j['hours_worked']),
      attendancePercent: _asInt(j['attendance_percent']),
    );
  }
}

/// A single day's attendance (login / logout / worked hours).
class AttendanceRecord {
  final int id;
  final int employeeId;
  final String employeeName;
  final String department;
  final String date; // YYYY-MM-DD
  final String status; // active | completed
  final String? loginTime;
  final String? logoutTime;
  final bool logoutEstimated;
  final int? lunchMinutes;
  final int? workedMinutes;
  final double? workedHours;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.date,
    required this.status,
    required this.loginTime,
    required this.logoutTime,
    required this.logoutEstimated,
    required this.lunchMinutes,
    required this.workedMinutes,
    required this.workedHours,
  });

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'] as Map<String, dynamic>? ?? const {};
    return AttendanceRecord(
      id: _asInt(j['id']),
      employeeId: _asInt(emp['id']),
      employeeName: emp['name'] as String? ?? '',
      department: j['department'] as String? ?? '',
      date: j['date'] as String? ?? '',
      status: j['status'] as String? ?? '',
      loginTime: j['login_time'] as String?,
      logoutTime: j['logout_time'] as String?,
      logoutEstimated: j['logout_estimated'] as bool? ?? false,
      lunchMinutes: _asIntN(j['lunch_minutes']),
      workedMinutes: _asIntN(j['worked_minutes']),
      workedHours: _asDoubleN(j['worked_hours']),
    );
  }
}

class TimeboxItem {
  final int slot;
  final String content;
  final bool done;
  const TimeboxItem({required this.slot, required this.content, required this.done});
  factory TimeboxItem.fromJson(Map<String, dynamic> j) => TimeboxItem(
        slot: _asInt(j['slot']),
        content: j['content'] as String? ?? '',
        done: j['done'] as bool? ?? false,
      );
}

/// A single day's Timebox planner (worklist / braindump / schedule).
class TimeboxDay {
  final int id;
  final int employeeId;
  final String date;
  final String status;
  final String? dailyNotes;
  final String? loginTime;
  final String? logoutTime;
  final List<TimeboxItem> worklist;
  final List<TimeboxItem> braindump;
  final List<TimeboxItem> schedule;

  const TimeboxDay({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.status,
    required this.dailyNotes,
    required this.loginTime,
    required this.logoutTime,
    required this.worklist,
    required this.braindump,
    required this.schedule,
  });

  factory TimeboxDay.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'] as Map<String, dynamic>? ?? const {};
    final items = j['items'] as Map<String, dynamic>? ?? const {};
    List<TimeboxItem> parse(String key) => (items[key] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(TimeboxItem.fromJson)
        .toList();
    return TimeboxDay(
      id: _asInt(j['id']),
      employeeId: _asInt(emp['id']),
      date: j['date'] as String? ?? '',
      status: j['status'] as String? ?? '',
      dailyNotes: j['daily_notes'] as String?,
      loginTime: j['login_time'] as String?,
      logoutTime: j['logout_time'] as String?,
      worklist: parse('worklist'),
      braindump: parse('braindump'),
      schedule: parse('schedule'),
    );
  }
}

/// A single attendance-driven payroll row (base × attendance factor).
class PayrollRow {
  final int timeboxId;
  final String name;
  final String email;
  final String department;
  final bool matched;
  final String? crmEmployeeId;
  final double baseSalary;
  final double allowances;
  final double deductions;
  final int expectedDays;
  final int daysPresent;
  final double hoursWorked;
  final int attendancePercent;
  final double attendanceFactor;
  final double proratedBase;
  final double absenceDeduction;
  final double netPayable;

  const PayrollRow({
    required this.timeboxId,
    required this.name,
    required this.email,
    required this.department,
    required this.matched,
    required this.crmEmployeeId,
    required this.baseSalary,
    required this.allowances,
    required this.deductions,
    required this.expectedDays,
    required this.daysPresent,
    required this.hoursWorked,
    required this.attendancePercent,
    required this.attendanceFactor,
    required this.proratedBase,
    required this.absenceDeduction,
    required this.netPayable,
  });

  factory PayrollRow.fromJson(Map<String, dynamic> j) => PayrollRow(
        timeboxId: _asInt(j['timeboxId']),
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        department: j['department'] as String? ?? '',
        matched: j['matched'] as bool? ?? false,
        crmEmployeeId: j['crmEmployeeId'] as String?,
        baseSalary: _asDouble(j['baseSalary']),
        allowances: _asDouble(j['allowances']),
        deductions: _asDouble(j['deductions']),
        expectedDays: _asInt(j['expectedDays']),
        daysPresent: _asInt(j['daysPresent']),
        hoursWorked: _asDouble(j['hoursWorked']),
        attendancePercent: _asInt(j['attendancePercent']),
        attendanceFactor: _asDouble(j['attendanceFactor']),
        proratedBase: _asDouble(j['proratedBase']),
        absenceDeduction: _asDouble(j['absenceDeduction']),
        netPayable: _asDouble(j['netPayable']),
      );
}

class PayrollPreview {
  final String mode;
  final String from;
  final String to;
  final double totalBase;
  final double totalProrated;
  final double totalAbsenceDeduction;
  final double totalNetPayable;
  final int matched;
  final int unmatched;
  final List<PayrollRow> rows;

  const PayrollPreview({
    required this.mode,
    required this.from,
    required this.to,
    required this.totalBase,
    required this.totalProrated,
    required this.totalAbsenceDeduction,
    required this.totalNetPayable,
    required this.matched,
    required this.unmatched,
    required this.rows,
  });

  factory PayrollPreview.fromJson(Map<String, dynamic> j) {
    final range = j['range'] as Map<String, dynamic>? ?? const {};
    final totals = j['totals'] as Map<String, dynamic>? ?? const {};
    return PayrollPreview(
      mode: j['mode'] as String? ?? 'demo',
      from: range['from'] as String? ?? '',
      to: range['to'] as String? ?? '',
      totalBase: _asDouble(totals['baseSalary']),
      totalProrated: _asDouble(totals['proratedBase']),
      totalAbsenceDeduction: _asDouble(totals['absenceDeduction']),
      totalNetPayable: _asDouble(totals['netPayable']),
      matched: _asInt(totals['matched']),
      unmatched: _asInt(totals['unmatched']),
      rows: (j['data'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PayrollRow.fromJson)
          .toList(),
    );
  }
}
