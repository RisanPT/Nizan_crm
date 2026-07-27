class InventoryProduct {
  final String id;
  final String name;
  final String brand;
  final String shade;
  final String barcode;
  final int quantity;
  final int fillLevel; // 0..100, the currently-open tube's remaining fill
  final int usagePerWork; // % of a tube consumed per completed work
  final double price;
  final String category;
  final String productType;
  final DateTime? expiry;
  final int lowStockThreshold;
  final String owner; // employeeId, or '' for studio inventory
  final String notes;

  const InventoryProduct({
    required this.id,
    required this.name,
    this.brand = '',
    this.shade = '',
    this.barcode = '',
    this.quantity = 0,
    this.fillLevel = 100,
    this.usagePerWork = 10,
    this.price = 0,
    this.category = 'Other',
    this.productType = '',
    this.expiry,
    this.lowStockThreshold = 2,
    this.owner = '',
    this.notes = '',
  });

  bool get isOut => quantity == 0;
  bool get isLow => quantity > 0 && quantity <= lowStockThreshold;

  /// Open-tube fill as a 0..1 fraction (for gauges).
  double get fillFraction => fillLevel.clamp(0, 100) / 100.0;

  /// The open tube is nearly empty (≤ 20%) but not out of stock.
  bool get isTubeLow => quantity > 0 && fillLevel <= 20;

  /// Total remaining measured in tube-equivalents: sealed spares + open tube.
  double get tubesRemaining =>
      quantity <= 0 ? 0 : (quantity - 1) + fillFraction;

  /// The design's canonical category list.
  static const categories = <String>[
    'Prep', 'Eye', 'Base', 'Highlighting', 'Setting', 'Fixing',
    'Lip', 'Cheek', 'Contour', 'Hair', 'Application', 'Cleaner', 'Other',
  ];

  factory InventoryProduct.fromJson(Map<String, dynamic> json) {
    return InventoryProduct(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      shade: json['shade'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      fillLevel: (json['fillLevel'] as num?)?.toInt() ?? 100,
      usagePerWork: (json['usagePerWork'] as num?)?.toInt() ?? 10,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? 'Other',
      productType: json['productType'] as String? ?? '',
      expiry: _parseDate(json['expiry']),
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 2,
      owner: _asId(json['owner']),
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'brand': brand,
        'shade': shade,
        'barcode': barcode,
        'quantity': quantity,
        'fillLevel': fillLevel,
        'usagePerWork': usagePerWork,
        'price': price,
        'category': category,
        'productType': productType,
        'expiry': expiry?.toIso8601String(),
        'lowStockThreshold': lowStockThreshold,
        'notes': notes,
      };

  static String _asId(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) return (v['_id'] ?? v['id'] ?? '').toString();
    return v.toString();
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }
}
