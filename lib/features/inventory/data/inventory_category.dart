import 'inventory_product.dart';

/// One inventory category as returned by `GET /inventory/categories`.
///
/// [source] is `builtin` (the original fixed list), `in_use` (a category an
/// existing product already carries) or `custom` (added from the Stock List).
/// Only an unused custom category is editable ([locked] == false), so renaming
/// or deleting never changes an existing product's category.
class InventoryCategory {
  final String? id;
  final String name;
  final String source;
  final int productCount;
  final int purchaseCount;
  final bool locked;

  const InventoryCategory({
    this.id,
    required this.name,
    this.source = 'builtin',
    this.productCount = 0,
    this.purchaseCount = 0,
    this.locked = true,
  });

  bool get isCustom => source == 'custom';
  bool get isBuiltin => source == 'builtin';
  bool get canEdit => isCustom && !locked && (id ?? '').isNotEmpty;

  /// Why editing is blocked, for tooltips / the manage sheet.
  String get lockReason {
    if (isBuiltin) return 'Built-in category';
    if (productCount > 0) {
      return 'Used by $productCount product${productCount == 1 ? '' : 's'}';
    }
    if (purchaseCount > 0) return 'Used in purchases';
    return 'Already in use';
  }

  factory InventoryCategory.fromJson(Map<String, dynamic> json) =>
      InventoryCategory(
        id: json['id'] as String?,
        name: (json['name'] as String? ?? '').trim(),
        source: json['source'] as String? ?? 'builtin',
        productCount: (json['productCount'] as num?)?.toInt() ?? 0,
        purchaseCount: (json['purchaseCount'] as num?)?.toInt() ?? 0,
        locked: json['locked'] as bool? ?? true,
      );

  /// The original fixed list — used as a fallback if the server is older /
  /// unreachable, so the Stock List still works.
  static List<InventoryCategory> builtins() => [
    for (final c in InventoryProduct.categories)
      InventoryCategory(name: c, source: 'builtin'),
  ];
}
