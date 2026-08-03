class SalaryStats {
  final double totalAdministrative;
  final double totalOperations;
  final double totalPaid;
  final double totalPending;
  final double totalNet;
  final int count;

  const SalaryStats({
    this.totalAdministrative = 0,
    this.totalOperations = 0,
    this.totalPaid = 0,
    this.totalPending = 0,
    this.totalNet = 0,
    this.count = 0,
  });

  factory SalaryStats.fromJson(Map<String, dynamic> json) {
    return SalaryStats(
      totalAdministrative: (json['totalAdministrative'] as num?)?.toDouble() ?? 0,
      totalOperations: (json['totalOperations'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0,
      totalPending: (json['totalPending'] as num?)?.toDouble() ?? 0,
      totalNet: (json['totalNet'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class Salary {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeCategory; // 'administrative' | 'operations'
  final String department;
  final String role;
  final int month;
  final int year;
  final String salaryType;
  final double baseSalary;
  final double allowances;
  final double bonus;
  final double deductions;
  final double netAmount;
  final String status; // 'draft' | 'approved_by_hr' | 'paid' | 'cancelled'
  final DateTime? paymentDate;
  final String paymentMethod;
  final String transactionRef;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String upiId;
  final String notes;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? paidByName;
  final DateTime? paidAt;
  final String? employeePhone;
  final String? employeeEmail;
  final String? employeeAvatar;
  final DateTime? createdAt;

  const Salary({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCategory,
    this.department = 'General',
    this.role = 'Staff',
    required this.month,
    required this.year,
    this.salaryType = 'fixed_monthly',
    this.baseSalary = 0,
    this.allowances = 0,
    this.bonus = 0,
    this.deductions = 0,
    required this.netAmount,
    this.status = 'approved_by_hr',
    this.paymentDate,
    this.paymentMethod = 'bank_transfer',
    this.transactionRef = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.upiId = '',
    this.notes = '',
    this.approvedByName,
    this.approvedAt,
    this.paidByName,
    this.paidAt,
    this.employeePhone,
    this.employeeEmail,
    this.employeeAvatar,
    this.createdAt,
  });

  bool get isPaid => status == 'paid';
  bool get isOps => employeeCategory == 'operations';
  bool get isAdmin => !isOps;

  factory Salary.fromJson(Map<String, dynamic> json) {
    final emp = json['employeeId'];
    final approvedBy = json['approvedBy'];
    final paidBy = json['paidBy'];
    final bank = json['bankDetails'] as Map<String, dynamic>? ?? {};

    String empId = '';
    String? phone;
    String? email;
    String? avatar;

    if (emp is Map<String, dynamic>) {
      empId = emp['_id'] as String? ?? emp['id'] as String? ?? '';
      phone = emp['phone'] as String?;
      email = emp['email'] as String?;
      avatar = emp['profileImage'] as String?;
    } else if (emp is String) {
      empId = emp;
    }

    return Salary(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      employeeId: empId,
      employeeName: json['employeeName'] as String? ?? '',
      employeeCategory: json['employeeCategory'] as String? ?? 'administrative',
      department: json['department'] as String? ?? 'General',
      role: json['role'] as String? ?? 'Staff',
      month: (json['month'] as num?)?.toInt() ?? 1,
      year: (json['year'] as num?)?.toInt() ?? 2026,
      salaryType: json['salaryType'] as String? ?? 'fixed_monthly',
      baseSalary: (json['baseSalary'] as num?)?.toDouble() ?? 0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0,
      bonus: (json['bonus'] as num?)?.toDouble() ?? 0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'approved_by_hr',
      paymentDate: json['paymentDate'] != null
          ? DateTime.tryParse(json['paymentDate'].toString())
          : null,
      paymentMethod: json['paymentMethod'] as String? ?? 'bank_transfer',
      transactionRef: json['transactionRef'] as String? ?? '',
      bankName: bank['bankName'] as String? ?? '',
      accountNumber: bank['accountNumber'] as String? ?? '',
      ifscCode: bank['ifscCode'] as String? ?? '',
      upiId: bank['upiId'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      approvedByName: approvedBy is Map<String, dynamic>
          ? approvedBy['name'] as String?
          : null,
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : null,
      paidByName: paidBy is Map<String, dynamic>
          ? paidBy['name'] as String?
          : null,
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'].toString())
          : null,
      employeePhone: phone,
      employeeEmail: email,
      employeeAvatar: avatar,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'month': month,
      'year': year,
      'salaryType': salaryType,
      'baseSalary': baseSalary,
      'allowances': allowances,
      'bonus': bonus,
      'deductions': deductions,
      'status': status,
      'notes': notes,
      if (department.isNotEmpty) 'department': department,
      if (role.isNotEmpty) 'role': role,
    };
  }
}
