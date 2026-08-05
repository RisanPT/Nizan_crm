// Models for the PHP HR bridge integration.
// These types mirror the JSON returned by /api/hr/* endpoints in the backend.

// ── Helpers ───────────────────────────────────────────────────────────────────

int _asInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
int? _asIntN(dynamic v) =>
    v == null ? null : ((v is num) ? v.toInt() : int.tryParse('$v'));

// ── Staff ─────────────────────────────────────────────────────────────────────

/// A single HR staff member returned by GET /api/hr/staff.
class HrStaffMember {
  final int id;
  final String name;
  final String email;
  final String designation;
  final String department;
  final String role;
  final bool active;

  const HrStaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.designation,
    required this.department,
    required this.role,
    required this.active,
  });

  factory HrStaffMember.fromJson(Map<String, dynamic> j) => HrStaffMember(
        id: _asInt(j['id']),
        name: j['name'] as String? ?? j['full_name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        designation: j['designation'] as String? ?? '',
        department: j['department'] as String? ?? '',
        role: j['role'] as String? ?? '',
        active: j['active'] as bool? ?? true,
      );
}

// ── Attendance ────────────────────────────────────────────────────────────────

/// A single attendance entry within an [HrAttendanceResponse].
class HrAttendanceEntry {
  final String date; // YYYY-MM-DD
  final String? checkIn;
  final String? checkOut;
  final String status; // present | absent | leave | holiday
  final int? workedMinutes;

  const HrAttendanceEntry({
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    required this.workedMinutes,
  });

  factory HrAttendanceEntry.fromJson(Map<String, dynamic> j) =>
      HrAttendanceEntry(
        date: j['date'] as String? ?? '',
        checkIn: j['check_in'] as String?,
        checkOut: j['check_out'] as String?,
        status: j['status'] as String? ?? 'absent',
        workedMinutes: _asIntN(j['worked_minutes']),
      );
}

/// Full attendance response returned by GET /api/hr/attendance.
class HrAttendanceResponse {
  final int userId;
  final int year;
  final int month;
  final List<HrAttendanceEntry> records;

  const HrAttendanceResponse({
    required this.userId,
    required this.year,
    required this.month,
    required this.records,
  });

  factory HrAttendanceResponse.fromJson(Map<String, dynamic> j) =>
      HrAttendanceResponse(
        userId: _asInt(j['user_id']),
        year: _asInt(j['year']),
        month: _asInt(j['month']),
        records: (j['records'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(HrAttendanceEntry.fromJson)
            .toList(),
      );
}

// ── Leaves ────────────────────────────────────────────────────────────────────

/// A single leave record returned by GET /api/hr/leaves.
class HrLeave {
  final int id;
  final String type; // casual | sick | earned | etc.
  final String fromDate; // YYYY-MM-DD
  final String toDate; // YYYY-MM-DD
  final int? totalDays;
  final String status; // approved | pending | rejected
  final String? reason;

  const HrLeave({
    required this.id,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.totalDays,
    required this.status,
    required this.reason,
  });

  factory HrLeave.fromJson(Map<String, dynamic> j) => HrLeave(
        id: _asInt(j['id']),
        type: j['type'] as String? ?? j['leave_type'] as String? ?? '',
        fromDate: j['from_date'] as String? ?? j['start_date'] as String? ?? '',
        toDate: j['to_date'] as String? ?? j['end_date'] as String? ?? '',
        totalDays: _asIntN(j['total_days']),
        status: j['status'] as String? ?? 'pending',
        reason: j['reason'] as String?,
      );
}

// ── Holidays ──────────────────────────────────────────────────────────────────

/// A single holiday returned by GET /api/hr/holidays.
class HrHoliday {
  final int id;
  final String name;
  final String date; // YYYY-MM-DD
  final String? description;

  const HrHoliday({
    required this.id,
    required this.name,
    required this.date,
    required this.description,
  });

  factory HrHoliday.fromJson(Map<String, dynamic> j) => HrHoliday(
        id: _asInt(j['id']),
        name: j['name'] as String? ?? j['holiday_name'] as String? ?? '',
        date: j['date'] as String? ?? '',
        description: j['description'] as String?,
      );
}
