// Shift + ShiftAssignment models — mirror backend/models/Shift.js & ShiftAssignment.js.

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

String _idOf(dynamic v) {
  if (v is Map) return (v['_id'] as String?) ?? '';
  return (v as String?) ?? '';
}

String _nameOf(dynamic v) {
  if (v is Map) return (v['name'] as String?) ?? '';
  return '';
}

class Shift {
  final String id;
  final String name;
  final String code;
  final String startTime;
  final String endTime;
  final int graceInMin;
  final int graceOutMin;
  final List<int> workingDays;
  final String color;
  final bool active;

  const Shift({
    required this.id,
    this.name = '',
    this.code = '',
    this.startTime = '09:00',
    this.endTime = '18:00',
    this.graceInMin = 0,
    this.graceOutMin = 0,
    this.workingDays = const [1, 2, 3, 4, 5, 6],
    this.color = '#601A29',
    this.active = true,
  });

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        code: j['code'] as String? ?? '',
        startTime: j['startTime'] as String? ?? '09:00',
        endTime: j['endTime'] as String? ?? '18:00',
        graceInMin: _i(j['graceInMin']),
        graceOutMin: _i(j['graceOutMin']),
        workingDays: ((j['workingDays'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        color: j['color'] as String? ?? '#601A29',
        active: j['active'] as bool? ?? true,
      );
}

class ShiftAssignment {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String shiftId;
  final String shiftName;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String note;

  const ShiftAssignment({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.department = '',
    this.shiftId = '',
    this.shiftName = '',
    this.fromDate,
    this.toDate,
    this.note = '',
  });

  factory ShiftAssignment.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return ShiftAssignment(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      shiftId: _idOf(j['shiftId']),
      shiftName: _nameOf(j['shiftId']).isNotEmpty ? _nameOf(j['shiftId']) : (j['shiftName'] as String? ?? ''),
      fromDate: _date(j['fromDate']),
      toDate: _date(j['toDate']),
      note: j['note'] as String? ?? '',
    );
  }
}
