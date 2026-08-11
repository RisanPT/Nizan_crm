import 'package:nizan_crm/core/models/employee.dart';

/// One controlled administrative expense head (ledger) from the Accounts
/// "Expense Heads" chart. `jobLinked` heads need a bride/event cost tag;
/// `recurring` heads can be flagged as monthly bills; `foreign` heads
/// (subscriptions) commonly attract GST reverse-charge (RCM).
class ExpenseHead {
  final String code;
  final String label;
  final String group;
  final bool jobLinked;
  final bool recurring;
  final bool foreign;

  const ExpenseHead(
    this.code,
    this.label,
    this.group, {
    this.jobLinked = false,
    this.recurring = false,
    this.foreign = false,
  });

  String get display => '$code · $label';
}

/// The controlled chart of expense heads (must match the backend EXPENSE_HEADS).
const List<ExpenseHead> kExpenseHeads = [
  ExpenseHead('FUE-01', 'Fuel Expense', 'Operating Expense'),
  ExpenseHead('FOO-01', 'Food Expense', 'Operating Expense'),
  ExpenseHead('TRP-01', 'Transportation Expenses', 'Operating Expense'),
  ExpenseHead('TRV-01', 'Travel Expenses', 'Operating Expense'),
  ExpenseHead('MES-01', 'Staff Mess Expenses', 'Employee Benefit'),
  ExpenseHead('TEL-01', 'Telephone & Internet', 'Operating Expense', recurring: true),
  ExpenseHead('ELE-01', 'Electricity Charges', 'Utilities', recurring: true),
  ExpenseHead('SUB-01', 'Subscription Charge', 'Software / IT', foreign: true),
  ExpenseHead('PRN-01', 'Printing & Stationery', 'Operating Expense'),
  ExpenseHead('TRN-01', 'Training & Recruitment', 'Employee / Operating'),
  ExpenseHead('WEL-01', 'Staff Welfare', 'Employee Benefit'),
  ExpenseHead('PRD-01', 'Product Purchase', 'COGS / Direct Purchase', jobLinked: true),
  ExpenseHead('SRT-01', 'Sales Return – Credit Note', 'Contra-Revenue', jobLinked: true),
  ExpenseHead('OFF-01', 'Office Expense', 'Operating Expense'),
  ExpenseHead('RNT-01', 'Rent – Office', 'Rent', recurring: true),
  ExpenseHead('RNT-02', 'Additional Rent', 'Rent', recurring: true),
  ExpenseHead('DRP-01', 'Drapist Expenses', 'Direct / Job Expense', jobLinked: true),
  ExpenseHead('ASC-01', 'Associate Expenses', 'Direct / Job Expense', jobLinked: true),
  ExpenseHead('SAL-01', 'Salary & Allowance', 'Payroll'),
  ExpenseHead('REP-01', 'Repairs & Maintenance', 'Operating Expense'),
];

ExpenseHead? expenseHeadByCode(String? code) {
  if (code == null || code.isEmpty) return null;
  for (final h in kExpenseHeads) {
    if (h.code == code) return h;
  }
  return null;
}

class AdminExpense {
  final String id;
  final String title;
  final String department;
  final String category;
  final String expenseHead; // controlled head code (e.g. 'FUE-01')
  final String vendor; // vendor / payee
  final String costTag; // bride / event cost tag (job-linked heads)
  final bool isRecurring;
  final String gstType; // none | gst | rcm
  final double gstAmount;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final Employee? paidBy;
  final String paidByName;
  final String receiptImage;
  final String invoiceNumber;
  final String status; // pending | approved | rejected
  final String source; // manual | hra
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
    this.expenseHead = '',
    this.vendor = '',
    this.costTag = '',
    this.isRecurring = false,
    this.gstType = 'none',
    this.gstAmount = 0,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.paidBy,
    this.paidByName = '',
    this.receiptImage = '',
    this.invoiceNumber = '',
    this.status = 'pending',
    this.source = 'manual',
    this.approvedByName,
    this.approvedAt,
    this.notes = '',
    this.createdByName,
    required this.createdAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  ExpenseHead? get head => expenseHeadByCode(expenseHead);

  /// Prefer the controlled head label; fall back to the legacy category label.
  String get headLabel => head?.label ?? categoryLabel;

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
      expenseHead: json['expenseHead'] as String? ?? '',
      vendor: json['vendor'] as String? ?? '',
      costTag: json['costTag'] as String? ?? '',
      isRecurring: json['isRecurring'] as bool? ?? false,
      gstType: json['gstType'] as String? ?? 'none',
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0,
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
      source: json['source'] as String? ?? 'manual',
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
      'expenseHead': expenseHead,
      'vendor': vendor,
      'costTag': costTag,
      'isRecurring': isRecurring,
      'gstType': gstType,
      'gstAmount': gstAmount,
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
