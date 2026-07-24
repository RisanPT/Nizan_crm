class Budget {
  final String id;
  final int month;
  final int year;
  final String category;
  final double amount;
  final DateTime createdAt;

  Budget({
    required this.id,
    required this.month,
    required this.year,
    required this.category,
    required this.amount,
    required this.createdAt,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['_id'] ?? '',
      month: json['month'] ?? 1,
      year: json['year'] ?? 2026,
      category: json['category'] ?? 'General',
      amount: (json['amount'] ?? 0).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'year': year,
      'category': category,
      'amount': amount,
    };
  }
}
