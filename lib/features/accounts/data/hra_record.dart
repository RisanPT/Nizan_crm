/// One House Rent Allowance payment to an employee — recorded separately from
/// the monthly salary run.
class HraRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final double amount;
  final DateTime date;
  final String paymentMethod; // bank_transfer | upi | cash | cheque | other
  final String status; // pending | paid
  final String notes;
  final DateTime createdAt;

  const HraRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.department = 'General',
    required this.amount,
    required this.date,
    this.paymentMethod = 'bank_transfer',
    this.status = 'pending',
    this.notes = '',
    required this.createdAt,
  });

  bool get isPaid => status == 'paid';

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'upi':
        return 'UPI';
      case 'cash':
        return 'Cash';
      case 'cheque':
        return 'Cheque';
      case 'other':
        return 'Other';
      default:
        return 'Bank Transfer';
    }
  }

  factory HraRecord.fromJson(Map<String, dynamic> json) {
    final emp = json['employeeId'];
    String empId = '';
    String? empName;
    String? empDept;
    if (emp is Map<String, dynamic>) {
      empId = emp['_id'] as String? ?? emp['id'] as String? ?? '';
      empName = emp['name'] as String?;
      empDept = emp['department'] as String?;
    } else if (emp is String) {
      empId = emp;
    }
    return HraRecord(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      employeeId: empId,
      employeeName: json['employeeName'] as String? ?? empName ?? 'Unknown',
      department: json['department'] as String? ?? empDept ?? 'General',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      paymentMethod: json['paymentMethod'] as String? ?? 'bank_transfer',
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class HraStats {
  final int totalCount;
  final double totalAmount;
  final double thisMonthAmount;
  final double pendingAmount;
  final int employeeCount;

  const HraStats({
    this.totalCount = 0,
    this.totalAmount = 0,
    this.thisMonthAmount = 0,
    this.pendingAmount = 0,
    this.employeeCount = 0,
  });

  factory HraStats.fromJson(Map<String, dynamic> j) => HraStats(
        totalCount: (j['totalCount'] as num?)?.toInt() ?? 0,
        totalAmount: (j['totalAmount'] as num?)?.toDouble() ?? 0,
        thisMonthAmount: (j['thisMonthAmount'] as num?)?.toDouble() ?? 0,
        pendingAmount: (j['pendingAmount'] as num?)?.toDouble() ?? 0,
        employeeCount: (j['employeeCount'] as num?)?.toInt() ?? 0,
      );
}
