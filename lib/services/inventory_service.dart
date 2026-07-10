import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/inventory_product.dart';
import '../core/models/purchase.dart';
import '../core/models/staff_kit.dart';
import '../core/models/vendor.dart';
import '../providers/dio_provider.dart';

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
class ExternalProduct {
  final String name;
  final String brand;
  final String imageUrl;
  const ExternalProduct({this.name = '', this.brand = '', this.imageUrl = ''});

  factory ExternalProduct.fromJson(Map<String, dynamic> j) => ExternalProduct(
        name: j['name'] as String? ?? '',
        brand: j['brand'] as String? ?? '',
        imageUrl: j['imageUrl'] as String? ?? '',
      );

  bool get isEmpty => name.isEmpty && brand.isEmpty;
}

class InventoryService {
  InventoryService(this._dio);
  final Dio _dio;

  // ── Products ───────────────────────────────────────────────────────────

  Future<List<InventoryProduct>> getProducts() async {
    try {
      final res = await _dio.get('/inventory/products');
      final data = res.data as List;
      return data
          .map((e) => InventoryProduct.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load inventory'));
    }
  }

  Future<InventoryProduct> saveProduct({
    String? id,
    required String name,
    required String brand,
    required String shade,
    required int quantity,
    required double price,
    required String category,
    String productType = '',
    String barcode = '',
    int? fillLevel,
    int? usagePerWork,
    DateTime? expiry,
    int? lowStockThreshold,
    String notes = '',
  }) async {
    final body = {
      'name': name,
      'brand': brand,
      'shade': shade,
      'barcode': barcode,
      'quantity': quantity,
      'fillLevel': ?fillLevel,
      'usagePerWork': ?usagePerWork,
      'price': price,
      'category': category,
      'productType': productType,
      'expiry': expiry?.toIso8601String(),
      'lowStockThreshold': ?lowStockThreshold,
      'notes': notes,
    };
    try {
      final res = id == null
          ? await _dio.post('/inventory/products', data: body)
          : await _dio.put('/inventory/products/$id', data: body);
      return InventoryProduct.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to save product'));
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _dio.delete('/inventory/products/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to delete product'));
    }
  }

  /// Look up a product by scanned barcode. Returns null when not registered.
  Future<InventoryProduct?> lookupBarcode(String code) async {
    try {
      final res = await _dio.get(
          '/inventory/products/barcode/${Uri.encodeComponent(code)}');
      return InventoryProduct.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(_msg(e, 'Barcode lookup failed'));
    }
  }

  /// Enrich a barcode we don't have from public product databases (Open Beauty
  /// Facts / UPCitemdb). Returns null when no public record exists (HTTP 404);
  /// throws on a real failure (no connection, server error) so the UI can tell
  /// "not in the databases" apart from "couldn't reach the lookup service".
  Future<ExternalProduct?> lookupExternal(String code) async {
    try {
      final res = await _dio.get(
          '/inventory/products/external/${Uri.encodeComponent(code)}');
      final ext = ExternalProduct.fromJson(res.data as Map<String, dynamic>);
      return ext.isEmpty ? null : ext;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null; // no public data (normal)
      throw Exception(_msg(e, 'Barcode lookup service unavailable'));
    }
  }

  // ── Tube consumption ─────────────────────────────────────────────────────

  /// Manually update a product's open-tube fill level (0..100) and, optionally,
  /// its tube count (quantity). Used by the artist stock/tube adjuster.
  Future<InventoryProduct> setFill(String id, int fillLevel,
      {int? quantity}) async {
    try {
      final res = await _dio.patch(
        '/inventory/products/$id/fill',
        data: {
          'fillLevel': fillLevel,
          'quantity': ?quantity,
        },
      );
      return InventoryProduct.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to update stock'));
    }
  }

  /// Deplete tubes for a completed work. With no arguments, the backend
  /// depletes every product linked in the completing artist's kit(s) by each
  /// product's usagePerWork%. Returns the number of products updated.
  Future<int> consumeForWork({String? employeeId}) async {
    try {
      final res = await _dio.post('/inventory/consume', data: {
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
      });
      final data = res.data as Map<String, dynamic>;
      final updated = data['updated'];
      if (updated is num) return updated.toInt();
      if (updated is List) return updated.length;
      return 0;
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to update stock'));
    }
  }

  /// Update one kit item's per-artist allocation (its tube fill and/or tube
  /// count). Affects only this artist's kit — never the shared studio stock.
  Future<StaffKit> updateKitItem(
    String kitId,
    int index, {
    int? fillLevel,
    int? quantity,
  }) async {
    try {
      final res = await _dio.patch(
        '/inventory/kits/$kitId/item/$index',
        data: {
          'fillLevel': ?fillLevel,
          'quantity': ?quantity,
        },
      );
      return StaffKit.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to update allocation'));
    }
  }

  // ── Purchases (stock-in) ─────────────────────────────────────────────────

  Future<List<Purchase>> getPurchases() async {
    try {
      final res = await _dio.get('/inventory/purchases');
      final data = res.data as List;
      return data
          .map((e) => Purchase.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load purchases'));
    }
  }

  Future<Purchase> createPurchase({
    String supplier = '',
    String vendorId = '',
    String invoiceNo = '',
    String billImage = '',
    DateTime? date,
    required List<PurchaseItem> items,
    bool paid = false,
    String notes = '',
  }) async {
    try {
      final res = await _dio.post('/inventory/purchases', data: {
        'supplier': supplier,
        if (vendorId.isNotEmpty) 'vendorId': vendorId,
        'invoiceNo': invoiceNo,
        if (billImage.isNotEmpty) 'billImage': billImage,
        'date': (date ?? DateTime.now()).toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'paid': paid,
        'notes': notes,
      });
      return Purchase.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to record purchase'));
    }
  }

  // ── Vendors ────────────────────────────────────────────────────────────

  Future<List<Vendor>> getVendors() async {
    try {
      final res = await _dio.get('/inventory/vendors');
      final data = res.data as List;
      return data
          .map((e) => Vendor.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load vendors'));
    }
  }

  Future<Vendor> saveVendor(Vendor vendor) async {
    try {
      final res = vendor.id.isEmpty
          ? await _dio.post('/inventory/vendors', data: vendor.toJson())
          : await _dio.put('/inventory/vendors/${vendor.id}',
              data: vendor.toJson());
      return Vendor.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to save vendor'));
    }
  }

  Future<void> deleteVendor(String id) async {
    try {
      await _dio.delete('/inventory/vendors/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to delete vendor'));
    }
  }

  /// Remove a purchase from the ledger.
  Future<void> deletePurchase(String id) async {
    try {
      await _dio.delete('/inventory/purchases/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to delete purchase'));
    }
  }

  /// Toggle a purchase's ledger payment status (Paid / Not Paid).
  Future<Purchase> setPurchasePaid(String id, bool paid) async {
    try {
      final res = await _dio.patch(
        '/inventory/purchases/$id/paid',
        data: {'paid': paid},
      );
      return Purchase.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to update payment status'));
    }
  }

  /// Bulk import (artist uploading existing inventory).
  Future<int> bulkImport(List<InventoryProduct> items) async {
    try {
      final res = await _dio.post(
        '/inventory/products/bulk',
        data: {'items': items.map((e) => e.toJson()).toList()},
      );
      final data = res.data as Map<String, dynamic>;
      return (data['inserted'] as num?)?.toInt() ?? items.length;
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to import inventory'));
    }
  }

  // ── Kits ───────────────────────────────────────────────────────────────

  Future<List<StaffKit>> getKits() async {
    try {
      final res = await _dio.get('/inventory/kits');
      final data = res.data as List;
      return data
          .map((e) => StaffKit.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load staff kits'));
    }
  }

  Future<StaffKit> saveKit({
    String? id,
    required String name,
    String employeeId = '',
    required List<KitItem> items,
    String notes = '',
  }) async {
    final body = {
      'name': name,
      if (employeeId.isNotEmpty) 'employeeId': employeeId,
      'items': items.map((e) => e.toJson()).toList(),
      'notes': notes,
    };
    try {
      final res = id == null
          ? await _dio.post('/inventory/kits', data: body)
          : await _dio.put('/inventory/kits/$id', data: body);
      return StaffKit.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to save kit'));
    }
  }

  Future<void> deleteKit(String id) async {
    try {
      await _dio.delete('/inventory/kits/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to delete kit'));
    }
  }

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? fallback;
    }
    return e.message ?? fallback;
  }
}
