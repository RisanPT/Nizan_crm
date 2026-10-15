// Compensation models — mirror SalaryBand.js & CompensationRevision.js.

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class SalaryBand {
  final String id;
  final String name;
  final int level;
  final double minSalary;
  final double maxSalary;
  final String currency;
  final String notes;
  final bool active;

  const SalaryBand({
    required this.id,
    this.name = '',
    this.level = 1,
    this.minSalary = 0,
    this.maxSalary = 0,
    this.currency = 'INR',
    this.notes = '',
    this.active = true,
  });

  factory SalaryBand.fromJson(Map<String, dynamic> j) => SalaryBand(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        level: j['level'] == null ? 1 : _i(j['level']),
        minSalary: _d(j['minSalary']),
        maxSalary: _d(j['maxSalary']),
        currency: j['currency'] as String? ?? 'INR',
        notes: j['notes'] as String? ?? '',
        active: j['active'] as bool? ?? true,
      );
}

class CompensationRevision {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final double currentSalary;
  final double proposedSalary;
  final DateTime? effectiveDate;
  final String reason;
  final String status; // pending | approved | rejected | cancelled
  final String decisionNote;

  const CompensationRevision({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.department = '',
    this.currentSalary = 0,
    this.proposedSalary = 0,
    this.effectiveDate,
    this.reason = '',
    this.status = 'pending',
    this.decisionNote = '',
  });

  factory CompensationRevision.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return CompensationRevision(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      currentSalary: _d(j['currentSalary']),
      proposedSalary: _d(j['proposedSalary']),
      effectiveDate: _date(j['effectiveDate']),
      reason: j['reason'] as String? ?? '',
      status: j['status'] as String? ?? 'pending',
      decisionNote: j['decisionNote'] as String? ?? '',
    );
  }
}
