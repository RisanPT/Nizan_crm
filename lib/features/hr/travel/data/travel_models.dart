// TravelRequest model — mirrors backend/models/TravelRequest.js.

const kTravelModes = <String>['flight', 'train', 'bus', 'car', 'other'];

String travelModeLabel(String m) => m.isEmpty ? 'Other' : m[0].toUpperCase() + m.substring(1);

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class TravelRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String destination;
  final String purpose;
  final String mode;
  final DateTime? fromDate;
  final DateTime? toDate;
  final double estimatedCost;
  final bool advanceRequested;
  final double advanceAmount;
  final String status;
  final String decisionNote;

  const TravelRequest({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.department = '',
    this.destination = '',
    this.purpose = '',
    this.mode = 'flight',
    this.fromDate,
    this.toDate,
    this.estimatedCost = 0,
    this.advanceRequested = false,
    this.advanceAmount = 0,
    this.status = 'pending',
    this.decisionNote = '',
  });

  factory TravelRequest.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return TravelRequest(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      destination: j['destination'] as String? ?? '',
      purpose: j['purpose'] as String? ?? '',
      mode: j['mode'] as String? ?? 'flight',
      fromDate: _date(j['fromDate']),
      toDate: _date(j['toDate']),
      estimatedCost: _d(j['estimatedCost']),
      advanceRequested: j['advanceRequested'] as bool? ?? false,
      advanceAmount: _d(j['advanceAmount']),
      status: j['status'] as String? ?? 'pending',
      decisionNote: j['decisionNote'] as String? ?? '',
    );
  }
}
