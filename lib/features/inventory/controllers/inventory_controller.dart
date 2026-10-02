import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';
import 'package:nizan_crm/features/inventory/data/purchase.dart';
import 'package:nizan_crm/features/inventory/data/staff_kit.dart';
import 'package:nizan_crm/features/inventory/data/vendor.dart';
import 'package:nizan_crm/features/inventory/data/inventory_category.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/inventory/services/inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(ref.watch(dioProvider));
});

/// Products the current user may see (studio inventory for managers, own
/// inventory for artists — scoped server-side).
final inventoryProductsProvider = FutureProvider<List<InventoryProduct>>((
  ref,
) async {
  return ref.watch(inventoryServiceProvider).getProducts();
});

final staffKitsProvider = FutureProvider<List<StaffKit>>((ref) async {
  return ref.watch(inventoryServiceProvider).getKits();
});

final purchasesProvider = FutureProvider<List<Purchase>>((ref) async {
  return ref.watch(inventoryServiceProvider).getPurchases();
});

final vendorsProvider = FutureProvider<List<Vendor>>((ref) async {
  return ref.watch(inventoryServiceProvider).getVendors();
});

/// Inventory categories (built-in + in-use + custom). Falls back to the
/// built-in list if the server can't be reached or predates categories.
final inventoryCategoriesProvider = FutureProvider<List<InventoryCategory>>((
  ref,
) async {
  try {
    final list = await ref.watch(inventoryServiceProvider).getCategories();
    return list.isEmpty ? InventoryCategory.builtins() : list;
  } catch (_) {
    return InventoryCategory.builtins();
  }
});

/// Category names for pickers. Always includes [include] (a product's current
/// category) so editing a product never silently swaps its category.
List<String> inventoryCategoryOptions(WidgetRef ref, {String? include}) {
  final names = <String>[
    // read (not watch): called from dialog builders. The Stock List watches
    // the provider, so it is already loaded by the time a form opens.
    for (final c
        in ref.read(inventoryCategoriesProvider).value ??
            InventoryCategory.builtins())
      c.name,
  ];
  final extra = include?.trim() ?? '';
  // Exact match on purpose: the dropdown value must equal an item, and we keep
  // the product's own spelling rather than "correcting" it (which would
  // change its stored category on save).
  if (extra.isNotEmpty && !names.contains(extra)) names.add(extra);
  return names;
}

/// A product suggestion resolved from a public barcode database.
