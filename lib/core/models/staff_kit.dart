class KitItem {
  final String productId; // linked studio product ('' = custom, untracked)
  final String name;
  final String brand;
  final String shade;
  final int quantity; // tubes allocated to the artist (total, incl. the open one)
  final int fillLevel; // 0..100, remaining fill of the open tube

  const KitItem({
    this.productId = '',
    required this.name,
    this.brand = '',
    this.shade = '',
    this.quantity = 1,
    this.fillLevel = 100,
  });

  bool get isOut => quantity <= 0;
  bool get isTubeLow => quantity > 0 && fillLevel <= 20;
  double get fillFraction => fillLevel.clamp(0, 100) / 100.0;

  /// Full, unopened spare tubes (the open one is tracked by [fillLevel]).
  int get spareTubes => quantity > 0 ? quantity - 1 : 0;

  factory KitItem.fromJson(Map<String, dynamic> json) => KitItem(
        productId: StaffKit._asId(json['productId']),
        name: json['name'] as String? ?? '',
        brand: json['brand'] as String? ?? '',
        shade: json['shade'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        fillLevel: (json['fillLevel'] as num?)?.toInt() ?? 100,
      );

  Map<String, dynamic> toJson() => {
        if (productId.isNotEmpty) 'productId': productId,
        'name': name,
        'brand': brand,
        'shade': shade,
        'quantity': quantity,
        'fillLevel': fillLevel,
      };
}

class StaffKit {
  final String id;
  final String name;
  final String employeeId;
  final List<KitItem> items;
  final String notes;

  const StaffKit({
    required this.id,
    required this.name,
    this.employeeId = '',
    this.items = const [],
    this.notes = '',
  });

  factory StaffKit.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return StaffKit(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      employeeId: _asId(json['employeeId']),
      items: rawItems
          .map((e) => KitItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (employeeId.isNotEmpty) 'employeeId': employeeId,
        'items': items.map((e) => e.toJson()).toList(),
        'notes': notes,
      };

  static String _asId(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) return (v['_id'] ?? v['id'] ?? '').toString();
    return v.toString();
  }
}
