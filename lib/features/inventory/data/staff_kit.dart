class KitItem {
  final String productId; // linked studio product ('' = custom, untracked)
  final String name;
  final String brand;
  final String shade;
  final int quantity; // units currently held in this kit

  // ── Read-only, computed by the server ──
  /// When the product was first handed to this kit's artist.
  final DateTime? assignedAt;

  /// Units issued since [assignedAt], net of returns.
  final int issuedTotal;

  /// Works the artist completed as lead on/after [assignedAt] (usage estimate).
  final int worksDone;

  /// Most recent of those works ('YYYY-MM-DD'), if any.
  final String? lastWorkDate;

  const KitItem({
    this.productId = '',
    required this.name,
    this.brand = '',
    this.shade = '',
    this.quantity = 1,
    this.assignedAt,
    this.issuedTotal = 0,
    this.worksDone = 0,
    this.lastWorkDate,
  });

  bool get isLinked => productId.isNotEmpty;

  /// Units to divide usage by: issued units, falling back to what's held.
  int get _units => issuedTotal > 0 ? issuedTotal : quantity;

  /// Approximate works done per unit issued (null before any unit is issued).
  double? get worksPerUnit => _units > 0 ? worksDone / _units : null;

  KitItem copyWith({int? quantity}) => KitItem(
        productId: productId,
        name: name,
        brand: brand,
        shade: shade,
        quantity: quantity ?? this.quantity,
        assignedAt: assignedAt,
        issuedTotal: issuedTotal,
        worksDone: worksDone,
        lastWorkDate: lastWorkDate,
      );

  factory KitItem.fromJson(Map<String, dynamic> json) => KitItem(
        productId: StaffKit._asId(json['productId']),
        name: json['name'] as String? ?? '',
        brand: json['brand'] as String? ?? '',
        shade: json['shade'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        assignedAt: json['assignedAt'] is String
            ? DateTime.tryParse(json['assignedAt'] as String)?.toLocal()
            : null,
        issuedTotal: (json['issuedTotal'] as num?)?.toInt() ?? 0,
        worksDone: (json['worksDone'] as num?)?.toInt() ?? 0,
        lastWorkDate: json['lastWorkDate'] as String?,
      );

  /// Only the editable fields — assignment dates and usage are server-owned.
  Map<String, dynamic> toJson() => {
        if (productId.isNotEmpty) 'productId': productId,
        'name': name,
        'brand': brand,
        'shade': shade,
        'quantity': quantity,
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

/// One studio-stock movement to or from a kit (assignment history).
class KitMovement {
  final String id;
  final String kitId;
  final String kitName;
  final String productId;
  final String productName;
  final String brand;
  final String shade;

  /// 'assign' (studio → kit), 'return' (kit → studio) or 'used_up'.
  final String type;
  final int quantity;
  final int? studioQtyAfter;
  final String byName;
  final DateTime? createdAt;

  const KitMovement({
    required this.id,
    this.kitId = '',
    this.kitName = '',
    this.productId = '',
    required this.productName,
    this.brand = '',
    this.shade = '',
    required this.type,
    required this.quantity,
    this.studioQtyAfter,
    this.byName = '',
    this.createdAt,
  });

  factory KitMovement.fromJson(Map<String, dynamic> json) => KitMovement(
        id: json['_id'] as String? ?? '',
        kitId: StaffKit._asId(json['kit']),
        kitName: json['kitName'] as String? ?? '',
        productId: StaffKit._asId(json['product']),
        productName: json['productName'] as String? ?? '',
        brand: json['brand'] as String? ?? '',
        shade: json['shade'] as String? ?? '',
        type: json['type'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        studioQtyAfter: (json['studioQtyAfter'] as num?)?.toInt(),
        byName: json['byName'] as String? ?? '',
        createdAt: json['createdAt'] is String
            ? DateTime.tryParse(json['createdAt'] as String)?.toLocal()
            : null,
      );
}
