// Data models for the HR Leave module. Hand-written fromJson (matches the
// evaluation-feature style). The backend populates `employeeId` with a {name,
// department} map on list endpoints, so parsing handles both shapes.

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(dynamic v) =>
    (v == null) ? null : DateTime.tryParse(v.toString());

String _idOf(dynamic v) {
  if (v is Map) return (v['_id'] as String?) ?? '';
  return (v as String?) ?? '';
}

class LeaveType {
  final String id;
  final String name;
  final String code;
  final double annualQuota;
  final bool paid;
  final bool carryForward;
  final double carryForwardMax;
  final String docRequired;
  final String color;
  final int order;
  final bool active;

  const LeaveType({
    required this.id,
    required this.name,
    this.code = '',
    this.annualQuota = 0,
    this.paid = true,
    this.carryForward = false,
    this.carryForwardMax = 0,
    this.docRequired = 'Not required',
    this.color = '#601A29',
    this.order = 0,
    this.active = true,
  });

  factory LeaveType.fromJson(Map<String, dynamic> j) => LeaveType(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        code: j['code'] as String? ?? '',
        annualQuota: _d(j['annualQuota']),
        paid: j['paid'] as bool? ?? true,
        carryForward: j['carryForward'] as bool? ?? false,
        carryForwardMax: _d(j['carryForwardMax']),
        docRequired: j['docRequired'] as String? ?? 'Not required',
        color: j['color'] as String? ?? '#601A29',
        order: _i(j['order']),
        active: j['active'] as bool? ?? true,
      );
}

class LeaveBalance {
  final String leaveTypeId;
  final String name;
  final String color;
  final bool paid;
  final double allocated;
  final double used;
  final double available;

  const LeaveBalance({
    required this.leaveTypeId,
    required this.name,
    this.color = '#601A29',
    this.paid = true,
    this.allocated = 0,
    this.used = 0,
    this.available = 0,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> j) => LeaveBalance(
        leaveTypeId: _idOf(j['leaveTypeId']),
        name: j['name'] as String? ?? '',
        color: j['color'] as String? ?? '#601A29',
        paid: j['paid'] as bool? ?? true,
        allocated: _d(j['allocated']),
        used: _d(j['used']),
        available: _d(j['available']),
      );
}

class LeaveRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String leaveTypeId;
  final String leaveTypeName;
  final DateTime? fromDate;
  final DateTime? toDate;
  final double days;
  final String halfDay;
  final String reason;
  final String status; // pending | approved | rejected | cancelled
  final String approvalId;
  final String decisionNote;
  final DateTime? decidedAt;

  const LeaveRequest({
    required this.id,
    required this.employeeId,
    this.employeeName = '',
    this.department = '',
    this.leaveTypeId = '',
    this.leaveTypeName = '',
    this.fromDate,
    this.toDate,
    this.days = 0,
    this.halfDay = 'none',
    this.reason = '',
    this.status = 'pending',
    this.approvalId = '',
    this.decisionNote = '',
    this.decidedAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return LeaveRequest(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      leaveTypeId: _idOf(j['leaveTypeId']),
      leaveTypeName: j['leaveTypeName'] as String? ?? '',
      fromDate: _date(j['fromDate']),
      toDate: _date(j['toDate']),
      days: _d(j['days']),
      halfDay: j['halfDay'] as String? ?? 'none',
      reason: j['reason'] as String? ?? '',
      status: j['status'] as String? ?? 'pending',
      approvalId: _idOf(j['approvalId']),
      decisionNote: j['decisionNote'] as String? ?? '',
      decidedAt: _date(j['decidedAt']),
    );
  }
}

class Holiday {
  final String id;
  final String name;
  final DateTime? date;
  final int year;
  final String type;
  final String notes;

  const Holiday({
    required this.id,
    required this.name,
    this.date,
    this.year = 0,
    this.type = 'national',
    this.notes = '',
  });

  factory Holiday.fromJson(Map<String, dynamic> j) => Holiday(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        date: _date(j['date']),
        year: _i(j['year']),
        type: j['type'] as String? ?? 'national',
        notes: j['notes'] as String? ?? '',
      );
}

class CompOff {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime? workedOn;
  final DateTime? expiresOn;
  final double grantedDays;
  final String status; // available | used | expired
  final String reason;

  const CompOff({
    required this.id,
    required this.employeeId,
    this.employeeName = '',
    this.workedOn,
    this.expiresOn,
    this.grantedDays = 1,
    this.status = 'available',
    this.reason = '',
  });

  factory CompOff.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return CompOff(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      workedOn: _date(j['workedOn']),
      expiresOn: _date(j['expiresOn']),
      grantedDays: _d(j['grantedDays']),
      status: j['status'] as String? ?? 'available',
      reason: j['reason'] as String? ?? '',
    );
  }
}
