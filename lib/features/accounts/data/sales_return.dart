/// A Sales Return / Credit Note (SRT-01). Reduces revenue rather than adding
/// to expenses; the bride name and reason are mandatory narration fields.
class SalesReturn {
  final String id;
  final String creditNoteNumber;
  final String brideName;
  final double amount;
  final DateTime date;
  final String reason;
  final String originalInvoiceRef;
  final String paymentMode; // cash | upi | bank_transfer | cheque | other
  final String status; // draft | approved | processed | cancelled
  final String notes;
  final String? createdByName;
  final DateTime createdAt;

  const SalesReturn({
    required this.id,
    required this.creditNoteNumber,
    required this.brideName,
    required this.amount,
    required this.date,
    required this.reason,
    this.originalInvoiceRef = '',
    this.paymentMode = 'bank_transfer',
    this.status = 'draft',
    this.notes = '',
    this.createdByName,
    required this.createdAt,
  });

  bool get isDraft => status == 'draft';
  bool get isApproved => status == 'approved';
  bool get isProcessed => status == 'processed';
  bool get isCancelled => status == 'cancelled';

  /// Approved + processed credit notes actually reduce revenue.
  bool get reducesRevenue => isApproved || isProcessed;

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'processed':
        return 'Processed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Draft';
    }
  }

  String get paymentModeLabel {
    switch (paymentMode) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'cheque':
        return 'Cheque';
      case 'other':
        return 'Other';
      default:
        return 'Bank Transfer';
    }
  }

  factory SalesReturn.fromJson(Map<String, dynamic> json) {
    final createdByJson = json['createdBy'];
    return SalesReturn(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      creditNoteNumber: json['creditNoteNumber'] as String? ?? '',
      brideName: json['brideName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      reason: json['reason'] as String? ?? '',
      originalInvoiceRef: json['originalInvoiceRef'] as String? ?? '',
      paymentMode: json['paymentMode'] as String? ?? 'bank_transfer',
      status: json['status'] as String? ?? 'draft',
      notes: json['notes'] as String? ?? '',
      createdByName: createdByJson is Map<String, dynamic>
          ? createdByJson['name'] as String?
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Month-to-date + all-time totals for the credit-note dashboard.
class SalesReturnStats {
  final int totalCount;
  final double totalAmount;
  final double thisMonthAmount;
  final int pendingCount;
  final double processedAmount;

  const SalesReturnStats({
    this.totalCount = 0,
    this.totalAmount = 0,
    this.thisMonthAmount = 0,
    this.pendingCount = 0,
    this.processedAmount = 0,
  });

  factory SalesReturnStats.fromJson(Map<String, dynamic> j) => SalesReturnStats(
        totalCount: (j['totalCount'] as num?)?.toInt() ?? 0,
        totalAmount: (j['totalAmount'] as num?)?.toDouble() ?? 0,
        thisMonthAmount: (j['thisMonthAmount'] as num?)?.toDouble() ?? 0,
        pendingCount: (j['pendingCount'] as num?)?.toInt() ?? 0,
        processedAmount: (j['processedAmount'] as num?)?.toDouble() ?? 0,
      );
}
