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

class Purchase {
  final String id;
  final String supplier;
  final String invoiceNo;
  final DateTime date;
  final List<PurchaseItem> items;
  final double total;
  final bool paid;
  final String notes;

  const Purchase({
    required this.id,
    this.supplier = '',
    this.invoiceNo = '',
    required this.date,
    this.items = const [],
    this.total = 0,
    this.paid = false,
    this.notes = '',
  });

  int get unitCount => items.fold(0, (a, i) => a + i.quantity);

  /// Units that actually entered stock (excludes expense-only lines).
  int get stockedUnitCount =>
      items.where((i) => i.stockIn).fold(0, (a, i) => a + i.quantity);

  factory Purchase.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return Purchase(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      supplier: json['supplier'] as String? ?? '',
      invoiceNo: json['invoiceNo'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      items: rawItems
          .map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      paid: json['paid'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
    );
  }
}
