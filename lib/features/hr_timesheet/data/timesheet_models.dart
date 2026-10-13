// Timesheet + entry models — mirror backend/models/Timesheet.js.

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class TimesheetEntry {
  final DateTime? date;
  final String project;
  final double hours;
  final String note;

  const TimesheetEntry({this.date, this.project = '', this.hours = 0, this.note = ''});

  factory TimesheetEntry.fromJson(Map<String, dynamic> j) => TimesheetEntry(
        date: _date(j['date']),
        project: j['project'] as String? ?? '',
        hours: _d(j['hours']),
        note: j['note'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'date': date?.toIso8601String(),
        'project': project,
        'hours': hours,
        'note': note,
      };
}

class Timesheet {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String periodType;
  final DateTime? periodStart;
  final String periodLabel;
  final List<TimesheetEntry> entries;
  final double totalHours;
  final String status; // draft | pending | approved | rejected
  final String approvalId;
  final String decisionNote;

  const Timesheet({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.department = '',
    this.periodType = 'weekly',
    this.periodStart,
    this.periodLabel = '',
    this.entries = const [],
    this.totalHours = 0,
    this.status = 'draft',
    this.approvalId = '',
    this.decisionNote = '',
  });

  factory Timesheet.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return Timesheet(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      periodType: j['periodType'] as String? ?? 'weekly',
      periodStart: _date(j['periodStart']),
      periodLabel: j['periodLabel'] as String? ?? '',
      entries: ((j['entries'] as List?) ?? const [])
          .map((e) => TimesheetEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalHours: _d(j['totalHours']),
      status: j['status'] as String? ?? 'draft',
      approvalId: (j['approvalId'] is Map ? (j['approvalId']['_id'] ?? '') : (j['approvalId'] ?? '')).toString(),
      decisionNote: j['decisionNote'] as String? ?? '',
    );
  }
}
