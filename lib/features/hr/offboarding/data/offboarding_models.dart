// Offboarding models — mirror backend/models/Offboarding.js.

const kOffboardingReasons = <String>['resignation', 'termination', 'retirement', 'end_of_contract', 'other'];

String offboardingReasonLabel(String r) {
  switch (r) {
    case 'resignation':
      return 'Resignation';
    case 'termination':
      return 'Termination';
    case 'retirement':
      return 'Retirement';
    case 'end_of_contract':
      return 'End of contract';
    default:
      return 'Other';
  }
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class ClearanceItem {
  final String label;
  final bool cleared;
  final String owner;
  const ClearanceItem({required this.label, this.cleared = false, this.owner = ''});

  factory ClearanceItem.fromJson(Map<String, dynamic> j) =>
      ClearanceItem(label: j['label'] as String? ?? '', cleared: j['cleared'] as bool? ?? false, owner: j['owner'] as String? ?? '');

  Map<String, dynamic> toJson() => {'label': label, 'cleared': cleared, 'owner': owner};

  ClearanceItem copyWith({bool? cleared}) => ClearanceItem(label: label, cleared: cleared ?? this.cleared, owner: owner);
}

class Offboarding {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String reason;
  final DateTime? lastWorkingDay;
  final String status; // in_progress | completed
  final List<ClearanceItem> clearanceItems;
  final double finalSettlementAmount;
  final bool settlementPaid;
  final bool experienceLetterIssued;
  final String notes;

  const Offboarding({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.department = '',
    this.reason = 'resignation',
    this.lastWorkingDay,
    this.status = 'in_progress',
    this.clearanceItems = const [],
    this.finalSettlementAmount = 0,
    this.settlementPaid = false,
    this.experienceLetterIssued = false,
    this.notes = '',
  });

  int get clearedCount => clearanceItems.where((c) => c.cleared).length;

  factory Offboarding.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return Offboarding(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      reason: j['reason'] as String? ?? 'resignation',
      lastWorkingDay: _date(j['lastWorkingDay']),
      status: j['status'] as String? ?? 'in_progress',
      clearanceItems: ((j['clearanceItems'] as List?) ?? const [])
          .map((e) => ClearanceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      finalSettlementAmount: _d(j['finalSettlementAmount']),
      settlementPaid: j['settlementPaid'] as bool? ?? false,
      experienceLetterIssued: j['experienceLetterIssued'] as bool? ?? false,
      notes: j['notes'] as String? ?? '',
    );
  }
}

const offboardingReasons = kOffboardingReasons;
