class SalaryIncrement {
  final String id;
  final String employeeId;
  final double previousSalary;
  final double newSalary;
  final String reason;
  final DateTime effectiveDate;
  final String? appliedByName;
  final DateTime createdAt;

  const SalaryIncrement({
    required this.id,
    required this.employeeId,
    required this.previousSalary,
    required this.newSalary,
    required this.reason,
    required this.effectiveDate,
    this.appliedByName,
    required this.createdAt,
  });

  factory SalaryIncrement.fromJson(Map<String, dynamic> json) {
    final appliedBy = json['appliedBy'];
    return SalaryIncrement(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      previousSalary: (json['previousSalary'] as num?)?.toDouble() ?? 0,
      newSalary: (json['newSalary'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
      effectiveDate: json['effectiveDate'] != null
          ? DateTime.tryParse(json['effectiveDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      appliedByName: appliedBy is Map<String, dynamic>
          ? appliedBy['name'] as String?
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
