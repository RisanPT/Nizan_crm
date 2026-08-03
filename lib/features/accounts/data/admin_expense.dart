import 'package:nizan_crm/core/models/employee.dart';

class AdminExpense {
  final String id;
  final String title;
  final String department; // CRM | Finance | Accounts | IT | Sales | Marketing | HR | Operations | General
  final String category; // office_supplies | rent_utilities | travel_transport | food_beverage | hardware_equipment | marketing_ads | professional_services | maintenance | training | other
  final double amount;
  final DateTime date;
  final String paymentMethod; // bank_transfer | upi | credit_card | debit_card | cash | petty_cash | other
  final Employee? paidBy;
  final String paidByName;
  final String receiptImage;
  final String invoiceNumber;
  final String status; // pending | approved | rejected
  final String? approvedByName;
  final DateTime? approvedAt;
  final String notes;
  final String? createdByName;
  final DateTime createdAt;

  const AdminExpense({
    required this.id,
    required this.title,
    required this.department,
    required this.category,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.paidBy,
    this.paidByName = '',
    this.receiptImage = '',
    this.invoiceNumber = '',
    this.status = 'pending',
    this.approvedByName,
    this.approvedAt,
    this.notes = '',
    this.createdByName,
    required this.createdAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  String get categoryLabel {
    switch (category) {
      case 'office_supplies':
        return 'Office Supplies';
      case 'rent_utilities':
        return 'Rent & Utilities';
      case 'travel_transport':
        return 'Travel & Transport';
      case 'food_beverage':
        return 'Food & Refreshments';
      case 'staff_mess':
        return 'Staff Mess';
      case 'hardware_equipment':
        return 'Hardware & Equipment';
      case 'marketing_ads':
        return 'Marketing & Ads';
      case 'professional_services':
        return 'Professional Services';
      case 'maintenance':
        return 'Repairs & Maintenance';
      case 'training':
        return 'Training & Development';
      case 'staff_welfare':
        return 'Staff Welfare';
      default:
        return 'Other Expense';
    }
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'bank_transfer':
        return 'Bank Transfer / NEFT';
      case 'upi':
        return 'UPI / GPay / PhonePe';
      case 'credit_card':
        return 'Corporate Credit Card';
      case 'debit_card':
        return 'Debit Card';
      case 'cash':
        return 'Cash';
      case 'petty_cash':
        return 'Petty Cash';
      default:
        return 'Other';
    }
  }

  factory AdminExpense.fromJson(Map<String, dynamic> json) {
    final paidByJson = json['paidBy'];
    final approvedByJson = json['approvedBy'];
    final createdByJson = json['createdBy'];

    return AdminExpense(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Administrative Expense',
      department: json['department'] as String? ?? 'General',
      category: json['category'] as String? ?? 'other',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      paymentMethod: json['paymentMethod'] as String? ?? 'bank_transfer',
      paidBy: paidByJson is Map<String, dynamic>
          ? Employee.fromJson(paidByJson)
          : null,
      paidByName: json['paidByName'] as String? ??
          (paidByJson is Map<String, dynamic> ? (paidByJson['name'] as String? ?? '') : ''),
      receiptImage: json['receiptImage'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      approvedByName: approvedByJson is Map<String, dynamic>
          ? approvedByJson['name'] as String?
          : null,
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : null,
      notes: json['notes'] as String? ?? '',
      createdByName: createdByJson is Map<String, dynamic>
          ? createdByJson['name'] as String?
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'department': department,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      if (paidBy != null) 'paidBy': paidBy!.id,
      'paidByName': paidByName,
      'receiptImage': receiptImage,
      'invoiceNumber': invoiceNumber,
      'notes': notes,
    };
  }
}
