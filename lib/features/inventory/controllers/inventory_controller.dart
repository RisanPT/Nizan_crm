import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';
import 'package:nizan_crm/features/inventory/data/purchase.dart';
import 'package:nizan_crm/features/inventory/data/staff_kit.dart';
import 'package:nizan_crm/features/inventory/data/vendor.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/inventory/services/inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(ref.watch(dioProvider));
});

/// Products the current user may see (studio inventory for managers, own
/// inventory for artists — scoped server-side).
final inventoryProductsProvider =
    FutureProvider<List<InventoryProduct>>((ref) async {
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

/// A product suggestion resolved from a public barcode database.
