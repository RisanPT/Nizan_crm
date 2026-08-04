/// Data models for the PHP attendance bridge.
/// PHP users have integer IDs (not MongoDB ObjectId).

class HrStaffMember {
  final int id;
  final String fullName;
  final String role;
  final String department;
  final String email;

  const HrStaffMember({
    required this.id,
    required this.fullName,
    required this.role,
    required this.department,
    required this.email,
  });

  factory HrStaffMember.fromJson(Map<String, dynamic> json) => HrStaffMember(
        id:         (json['id'] as num).toInt(),
        fullName:   json['fullName']   as String? ?? '',
        role:       json['role']       as String? ?? '',
        department: json['department'] as String? ?? '',
        email:      json['email']      as String? ?? '',
      );
}

class HrTimebox {
  final String date;
  final String? clockIn;
  final String? clockOut;
  final String status; // active | completed | missed
  final double? totalHours;

  const HrTimebox({
    required this.date,
    this.clockIn,
    this.clockOut,
    required this.status,
    this.totalHours,
  });

  bool get isPresent   => status != 'missed';
  bool get isCompleted => status == 'completed';
  bool get isMissed    => status == 'missed';

  factory HrTimebox.fromJson(Map<String, dynamic> json) => HrTimebox(
        date:       json['date']       as String? ?? '',
        clockIn:    json['clockIn']    as String?,
        clockOut:   json['clockOut']   as String?,
        status:     json['status']     as String? ?? 'missed',
        totalHours: (json['totalHours'] as num?)?.toDouble(),
      );
}

class HrAttendanceSummary {
  final int present;
  final int completed;
  final int missed;

  const HrAttendanceSummary({
    required this.present,
    required this.completed,
    required this.missed,
  });

  factory HrAttendanceSummary.fromJson(Map<String, dynamic> json) =>
      HrAttendanceSummary(
        present:   (json['present']   as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        missed:    (json['missed']    as num?)?.toInt() ?? 0,
      );
}

class HrAttendanceResponse {
  final int userId;
  final int year;
  final int month;
  final List<HrTimebox> data;
  final HrAttendanceSummary summary;

  const HrAttendanceResponse({
    required this.userId,
    required this.year,
    required this.month,
    required this.data,
    required this.summary,
  });

  factory HrAttendanceResponse.fromJson(Map<String, dynamic> json) =>
      HrAttendanceResponse(
        userId: (json['userId'] as num?)?.toInt() ?? 0,
        year:   (json['year']   as num?)?.toInt() ?? 0,
        month:  (json['month']  as num?)?.toInt() ?? 0,
        data: (json['data'] as List<dynamic>? ?? [])
            .map((e) => HrTimebox.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: HrAttendanceSummary.fromJson(
            json['summary'] as Map<String, dynamic>? ?? {}),
      );
}

class HrLeave {
  final int id;
  final String startDate;
  final String endDate;
  final String leaveType;
  final String reason;

  const HrLeave({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    required this.reason,
  });

  factory HrLeave.fromJson(Map<String, dynamic> json) => HrLeave(
        id:        (json['id'] as num).toInt(),
        startDate: json['startDate'] as String? ?? '',
        endDate:   json['endDate']   as String? ?? '',
        leaveType: json['leaveType'] as String? ?? '',
        reason:    json['reason']    as String? ?? '',
      );
}

class HrHoliday {
  final int id;
  final String date;
  final String name;

  const HrHoliday({
    required this.id,
    required this.date,
    required this.name,
  });

  factory HrHoliday.fromJson(Map<String, dynamic> json) => HrHoliday(
        id:   (json['id'] as num).toInt(),
        date: json['date'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}
