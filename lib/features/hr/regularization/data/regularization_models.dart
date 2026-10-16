// AttendanceRegularization model — mirrors backend/models/AttendanceRegularization.js.

const kRegularizationTypes = <String>['missing_punch', 'wrong_time', 'wfh', 'on_duty', 'other'];

String regularizationTypeLabel(String t) {
  switch (t) {
    case 'missing_punch':
      return 'Missing punch';
    case 'wrong_time':
      return 'Wrong time';
    case 'wfh':
      return 'Work from home';
    case 'on_duty':
      return 'On duty';
    default:
      return 'Other';
  }
}

DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class Regularization {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final DateTime? date;
  final String type;
  final String requestedInTime;
  final String requestedOutTime;
  final String reason;
  final String status; // pending | approved | rejected | cancelled
  final String approvalId;
  final String decisionNote;

  const Regularization({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.department = '',
    this.date,
    this.type = 'missing_punch',
    this.requestedInTime = '',
    this.requestedOutTime = '',
    this.reason = '',
    this.status = 'pending',
    this.approvalId = '',
    this.decisionNote = '',
  });

  factory Regularization.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return Regularization(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      date: _date(j['date']),
      type: j['type'] as String? ?? 'missing_punch',
      requestedInTime: j['requestedInTime'] as String? ?? '',
      requestedOutTime: j['requestedOutTime'] as String? ?? '',
      reason: j['reason'] as String? ?? '',
      status: j['status'] as String? ?? 'pending',
      approvalId: (j['approvalId'] is Map ? (j['approvalId']['_id'] ?? '') : (j['approvalId'] ?? '')).toString(),
      decisionNote: j['decisionNote'] as String? ?? '',
    );
  }
}
