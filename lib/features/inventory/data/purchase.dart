class PurchaseItem {
  final String productId; // '' when it's a new product
  final String name;
  final String brand;
  final String shade;
  final String barcode;
  final String category;
  final int quantity;
  final double unitCost;
  final bool stockIn; // false => expense-only line (not added to inventory)
  final DateTime? expiry;

  const PurchaseItem({
    this.productId = '',
    required this.name,
    this.brand = '',
    this.shade = '',
    this.barcode = '',
    this.category = 'Other',
    this.quantity = 1,
    this.unitCost = 0,
    this.stockIn = true,
    this.expiry,
  });

  double get subtotal => quantity * unitCost;

  PurchaseItem copyWith({int? quantity, double? unitCost, bool? stockIn}) =>
      PurchaseItem(
        productId: productId,
        name: name,
        brand: brand,
        shade: shade,
        barcode: barcode,
        category: category,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost ?? this.unitCost,
        stockIn: stockIn ?? this.stockIn,
        expiry: expiry,
      );

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        productId: (json['product'] is Map)
            ? (json['product']['_id'] ?? '').toString()
            : (json['product'] ?? '').toString(),
        name: json['name'] as String? ?? '',
        brand: json['brand'] as String? ?? '',
        shade: json['shade'] as String? ?? '',
        barcode: json['barcode'] as String? ?? '',
        category: json['category'] as String? ?? 'Other',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0,
        stockIn: json['stockIn'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (productId.isNotEmpty) 'productId': productId,
        'name': name,
        'brand': brand,
        'shade': shade,
        'barcode': barcode,
        'category': category,
        'quantity': quantity,
        'unitCost': unitCost,
        'stockIn': stockIn,
        'expiry': ?expiry?.toIso8601String(),
      };
}

/// One payment made against a vendor bill (Zoho "Payments Made").
class PurchasePayment {
  final double amount;
  final DateTime date;
  final String mode; // cash / upi / bank_transfer / cheque / card / other
  final String note;

  const PurchasePayment({
    required this.amount,
    required this.date,
    this.mode = 'cash',
    this.note = '',
  });

  factory PurchasePayment.fromJson(Map<String, dynamic> json) =>
      PurchasePayment(
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        mode: json['mode'] as String? ?? 'cash',
        note: json['note'] as String? ?? '',
      );
}

class Purchase {
  final String id;
  final String supplier;
  final String vendorId;
  final String invoiceNo;
  final String billImage;
  final DateTime date;
  final DateTime? dueDate;
  final List<PurchaseItem> items;
  final double total; // taxable base (sum of line items)
  final bool paid;
  final String notes;
  // GST (input tax) on the vendor bill.
  final bool gstEnabled;
  final String gstin;
  final double gstRate; // percentage e.g. 18
  final double gstAmount; // tax value in currency
  final bool interState; // true => IGST, false => CGST + SGST
  // Payments made against grandTotal.
  final double amountPaid;
  final List<PurchasePayment> payments;

  const Purchase({
    required this.id,
    this.supplier = '',
    this.vendorId = '',
    this.invoiceNo = '',
    this.billImage = '',
    required this.date,
    this.dueDate,
    this.items = const [],
    this.total = 0,
    this.paid = false,
    this.notes = '',
    this.gstEnabled = false,
    this.gstin = '',
    this.gstRate = 0,
    this.gstAmount = 0,
    this.interState = false,
    this.amountPaid = 0,
    this.payments = const [],
  });

  int get unitCount => items.fold(0, (a, i) => a + i.quantity);

  /// Units that actually entered stock (excludes expense-only lines).
  int get stockedUnitCount =>
      items.where((i) => i.stockIn).fold(0, (a, i) => a + i.quantity);

  /// Amount payable to the vendor = taxable base + GST.
  double get grandTotal => total + gstAmount;

  /// Effective amount paid. Legacy bills only carry the `paid` flag with no
  /// amountPaid — treat those as fully settled.
  double get paidAmount =>
      (paid && amountPaid < grandTotal) ? grandTotal : amountPaid;

  /// Outstanding amount still owed on this bill.
  double get balance {
    final b = grandTotal - paidAmount;
    return b < 0 ? 0 : b;
  }

  bool get isFullyPaid =>
      paid || (grandTotal > 0 && amountPaid >= grandTotal - 0.01);
  bool get isPartiallyPaid => paidAmount > 0.01 && !isFullyPaid;
  bool get isUnpaid => paidAmount <= 0.01 && !paid;

  /// GST split (equal CGST/SGST for intra-state, full IGST for inter-state).
  double get cgst => interState ? 0 : gstAmount / 2;
  double get sgst => interState ? 0 : gstAmount / 2;
  double get igst => interState ? gstAmount : 0;

  bool get isOverdue =>
      !isFullyPaid && dueDate != null && dueDate!.isBefore(DateTime.now());

  /// 'paid' | 'partial' | 'overdue' | 'unpaid'
  String get status {
    if (isFullyPaid || paid) return 'paid';
    if (isPartiallyPaid) return 'partial';
    if (isOverdue) return 'overdue';
    return 'unpaid';
  }

  factory Purchase.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    final rawPayments = json['payments'] as List? ?? const [];
    return Purchase(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      supplier: json['supplier'] as String? ?? '',
      vendorId: (json['vendor'] is Map)
          ? (json['vendor']['_id'] ?? '').toString()
          : (json['vendor'] ?? '').toString(),
      invoiceNo: json['invoiceNo'] as String? ?? '',
      billImage: json['billImage'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
      items: rawItems
          .map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      paid: json['paid'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      gstEnabled: json['gstEnabled'] as bool? ?? false,
      gstin: json['gstin'] as String? ?? '',
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0,
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0,
      interState: json['interState'] as bool? ?? false,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0,
      payments: rawPayments
          .map((e) => PurchasePayment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
