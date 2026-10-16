// ExpenseClaim model — mirrors backend/models/ExpenseClaim.js.

const kClaimCategories = <String>['travel', 'food', 'supplies', 'medical', 'communication', 'other'];

String claimCategoryLabel(String c) => c.isEmpty ? 'Other' : c[0].toUpperCase() + c.substring(1);

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
DateTime? _date(dynamic v) => (v == null) ? null : DateTime.tryParse(v.toString());

class ExpenseClaim {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String category;
  final String title;
  final double amount;
  final DateTime? date;
  final String description;
  final String receiptUrl;
  final String status; // pending | approved | rejected | cancelled | paid
  final String paymentMethod;
  final String decisionNote;

  const ExpenseClaim({
    required this.id,
    this.employeeId = '',
    this.employeeName = '',
    this.department = '',
    this.category = 'other',
    this.title = '',
    this.amount = 0,
    this.date,
    this.description = '',
    this.receiptUrl = '',
    this.status = 'pending',
    this.paymentMethod = 'bank',
    this.decisionNote = '',
  });

  factory ExpenseClaim.fromJson(Map<String, dynamic> j) {
    final emp = j['employeeId'];
    final empMap = emp is Map<String, dynamic> ? emp : null;
    return ExpenseClaim(
      id: j['_id'] as String? ?? j['id'] as String? ?? '',
      employeeId: empMap != null ? (empMap['_id'] as String? ?? '') : (emp as String? ?? ''),
      employeeName: empMap?['name'] as String? ?? j['employeeName'] as String? ?? '',
      department: empMap?['department'] as String? ?? j['department'] as String? ?? '',
      category: j['category'] as String? ?? 'other',
      title: j['title'] as String? ?? '',
      amount: _d(j['amount']),
      date: _date(j['date']),
      description: j['description'] as String? ?? '',
      receiptUrl: j['receiptUrl'] as String? ?? '',
      status: j['status'] as String? ?? 'pending',
      paymentMethod: j['paymentMethod'] as String? ?? 'bank',
      decisionNote: j['decisionNote'] as String? ?? '',
    );
  }
}
