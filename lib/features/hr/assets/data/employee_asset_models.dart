// Employee asset models — mirror backend/models/EmployeeAsset.js.
// (Not the finance fixed-asset register.)

const kEmployeeAssetCategories = <String>['laptop', 'phone', 'kit', 'uniform', 'id_card', 'sim', 'other'];
const kEmployeeAssetStatuses = <String>['issued', 'returned', 'lost'];

String employeeAssetCategoryLabel(String c) {
  switch (c) {
    case 'laptop':
      return 'Laptop';
    case 'phone':
      return 'Phone';
    case 'kit':
      return 'Kit';
    case 'uniform':
      return 'Uniform';
    case 'id_card':
      return 'ID card';
    case 'sim':
      return 'SIM';
    default:
      return 'Other';
  }
}

String employeeAssetStatusLabel(String s) {
  switch (s) {
    case 'issued':
      return 'Issued';
    case 'returned':
      return 'Returned';
    case 'lost':
      return 'Lost';
    default:
      return s;
  }
}

DateTime? _date(dynamic v) => (v == null || v == '') ? null : DateTime.tryParse(v.toString())?.toLocal();
String _s(dynamic v) => v?.toString() ?? '';

class EmployeeAsset {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String item;
  final String category;
  final String serialNo;
  final DateTime? issuedOn;
  final String issuedByName;
  final String condition;
  final DateTime? returnedOn;
  final String returnedToName;
  final String returnCondition;
  final String notes;
  final String status; // issued | returned | lost

  const EmployeeAsset({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.department = '',
    this.item = '',
    this.category = 'other',
    this.serialNo = '',
    this.issuedOn,
    this.issuedByName = '',
    this.condition = '',
    this.returnedOn,
    this.returnedToName = '',
    this.returnCondition = '',
    this.notes = '',
    this.status = 'issued',
  });

  bool get isIssued => status == 'issued';

  factory EmployeeAsset.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return EmployeeAsset(
      id: _s(j['_id'] ?? j['id']),
      employeeId: empMap != null ? _s(empMap['_id']) : _s(emp),
      employeeName: _s(empMap?['name'] ?? j['employeeName']),
      department: _s(empMap?['department'] ?? j['department']),
      item: _s(j['item']),
      category: j['category'] as String? ?? 'other',
      serialNo: _s(j['serialNo']),
      issuedOn: _date(j['issuedOn']),
      issuedByName: _s(j['issuedByName']),
      condition: _s(j['condition']),
      returnedOn: _date(j['returnedOn']),
      returnedToName: _s(j['returnedToName']),
      returnCondition: _s(j['returnCondition']),
      notes: _s(j['notes']),
      status: j['status'] as String? ?? 'issued',
    );
  }
}
