import 'package:dio/dio.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';
import 'package:nizan_crm/features/inventory/data/purchase.dart';
import 'package:nizan_crm/features/inventory/data/staff_kit.dart';
import 'package:nizan_crm/features/inventory/data/vendor.dart';
import 'package:nizan_crm/features/inventory/data/inventory_category.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/money_account_picker.dart';

/// Sentinel for optional 'clear vs leave unchanged' update params.
const Object _unset = Object();

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
    } catch (e) {
      throw AppException(e, action: 'load inventory');
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
    } catch (e) {
      throw AppException(e, action: 'save product');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _dio.delete('/inventory/products/$id');
    } catch (e) {
      throw AppException(e, action: 'delete product');
    }
  }

  /// Bulk-import products (e.g. from an uploaded Excel/CSV of existing stock).
  /// Each map is one product row; the backend cleans + validates each. Returns
  /// the number of rows actually inserted.
  Future<int> bulkCreateProducts(List<Map<String, dynamic>> items) async {
    try {
      final res = await _dio.post(
        '/inventory/products/bulk',
        data: {'items': items},
      );
      final data = res.data as Map<String, dynamic>;
      return (data['inserted'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw AppException(e, action: 'import products');
    }
  }

  /// Look up a product by scanned barcode. Returns null when not registered.
  Future<InventoryProduct?> lookupBarcode(String code) async {
    try {
      final res = await _dio.get(
        '/inventory/products/barcode/${Uri.encodeComponent(code)}',
      );
      return InventoryProduct.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw AppException(e, action: 'look up the barcode');
    }
  }

  /// Enrich a barcode we don't have from public product databases (Open Beauty
  /// Facts / UPCitemdb). Returns null when no public record exists (HTTP 404);
  /// throws on a real failure (no connection, server error) so the UI can tell
  /// "not in the databases" apart from "couldn't reach the lookup service".
  Future<ExternalProduct?> lookupExternal(String code) async {
    try {
      final res = await _dio.get(
        '/inventory/products/external/${Uri.encodeComponent(code)}',
      );
      final ext = ExternalProduct.fromJson(res.data as Map<String, dynamic>);
      return ext.isEmpty ? null : ext;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null; // no public data (normal)
      throw AppException(e, action: 'reach the barcode lookup service');
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
    } catch (e) {
      throw AppException(e, action: 'load purchases');
    }
  }

  Future<Purchase> createPurchase({
    String supplier = '',
    String vendorId = '',
    String invoiceNo = '',
    String billImage = '',
    DateTime? date,
    DateTime? dueDate,
    required List<PurchaseItem> items,
    bool paid = false,
    String notes = '',
    bool gstEnabled = false,
    String gstin = '',
    double gstRate = 0,
    double gstAmount = 0,
    bool interState = false,
  }) async {
    try {
      final res = await _dio.post(
        '/inventory/purchases',
        data: {
          'supplier': supplier,
          if (vendorId.isNotEmpty) 'vendorId': vendorId,
          'invoiceNo': invoiceNo,
          if (billImage.isNotEmpty) 'billImage': billImage,
          'date': (date ?? DateTime.now()).toIso8601String(),
          if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
          'items': items.map((e) => e.toJson()).toList(),
          'paid': paid,
          'notes': notes,
          'gstEnabled': gstEnabled,
          if (gstin.isNotEmpty) 'gstin': gstin,
          'gstRate': gstRate,
          'gstAmount': gstAmount,
          'interState': interState,
        },
      );
      return Purchase.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'record purchase');
    }
  }

  /// Record a payment (full or partial) against a vendor bill.
  Future<Purchase> recordPurchasePayment(
    String id, {
    required double amount,
    DateTime? date,
    String mode = 'cash',
    String note = '',
    MoneyChoice? money, // bank / cash account it was paid from
  }) async {
    try {
      final res = await _dio.post(
        '/inventory/purchases/$id/payments',
        data: {
          'amount': amount,
          'date': (date ?? DateTime.now()).toIso8601String(),
          'mode': money?.paymentMode ?? mode,
          'note': note,
          if (money != null) 'moneyAccountId': money.moneyAccountId,
          if (money != null) 'paymentRef': money.paymentRef,
        },
      );
      return Purchase.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'record payment');
    }
  }

  /// Edit a bill's billing / GST metadata (no stock changes).
  Future<Purchase> updatePurchaseBilling(
    String id, {
    String? invoiceNo,
    String? billImage,
    String? notes,
    DateTime? date,
    Object? dueDate = _unset, // pass null to clear, DateTime to set
    bool? gstEnabled,
    String? gstin,
    double? gstRate,
    double? gstAmount,
    bool? interState,
    String? vendorId,
    String? supplier,
  }) async {
    try {
      final res = await _dio.put(
        '/inventory/purchases/$id',
        data: {
          'invoiceNo': ?invoiceNo,
          'billImage': ?billImage,
          'notes': ?notes,
          'date': ?date?.toIso8601String(),
          if (!identical(dueDate, _unset))
            'dueDate': (dueDate as DateTime?)?.toIso8601String(),
          'gstEnabled': ?gstEnabled,
          'gstin': ?gstin,
          'gstRate': ?gstRate,
          'gstAmount': ?gstAmount,
          'interState': ?interState,
          'vendorId': ?vendorId,
          'supplier': ?supplier,
        },
      );
      return Purchase.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update bill');
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
    } catch (e) {
      throw AppException(e, action: 'load vendors');
    }
  }

  Future<Vendor> saveVendor(Vendor vendor) async {
    try {
      final res = vendor.id.isEmpty
          ? await _dio.post('/inventory/vendors', data: vendor.toJson())
          : await _dio.put(
              '/inventory/vendors/${vendor.id}',
              data: vendor.toJson(),
            );
      return Vendor.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save vendor');
    }
  }

  Future<void> deleteVendor(String id) async {
    try {
      await _dio.delete('/inventory/vendors/$id');
    } catch (e) {
      throw AppException(e, action: 'delete vendor');
    }
  }

  // ── Categories ─────────────────────────────────────────────────────────

  Future<List<InventoryCategory>> getCategories() async {
    try {
      final res = await _dio.get('/inventory/categories');
      return (res.data as List)
          .map((e) => InventoryCategory.fromJson(e as Map<String, dynamic>))
          .where((c) => c.name.isNotEmpty)
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load categories');
    }
  }

  Future<InventoryCategory> createCategory(String name) async {
    try {
      final res = await _dio.post(
        '/inventory/categories',
        data: {'name': name},
      );
      return InventoryCategory.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'add category');
    }
  }

  Future<InventoryCategory> renameCategory(String id, String name) async {
    try {
      final res = await _dio.put(
        '/inventory/categories/$id',
        data: {'name': name},
      );
      return InventoryCategory.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'rename category');
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _dio.delete('/inventory/categories/$id');
    } catch (e) {
      throw AppException(e, action: 'delete category');
    }
  }

  /// Remove a purchase from the ledger.
  Future<void> deletePurchase(String id) async {
    try {
      await _dio.delete('/inventory/purchases/$id');
    } catch (e) {
      throw AppException(e, action: 'delete purchase');
    }
  }

  /// Toggle a purchase's ledger payment status (Paid / Not Paid).
  /// Marking paid settles the balance as one payment from [money]'s account.
  Future<Purchase> setPurchasePaid(String id, bool paid, {MoneyChoice? money}) async {
    try {
      final res = await _dio.patch(
        '/inventory/purchases/$id/paid',
        data: {
          'paid': paid,
          if (money != null) 'mode': money.paymentMode,
          if (money != null) 'moneyAccountId': money.moneyAccountId,
          if (money != null) 'paymentRef': money.paymentRef,
        },
      );
      return Purchase.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update payment status');
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
    } catch (e) {
      throw AppException(e, action: 'import inventory');
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
    } catch (e) {
      throw AppException(e, action: 'load staff kits');
    }
  }

  /// Saves the kit's full item list. The server deducts newly assigned units
  /// of studio products from studio stock; units removed from the kit go back
  /// to studio stock when [returnToStudio], otherwise they're written off as
  /// used up.
  Future<StaffKit> saveKit({
    String? id,
    required String name,
    String employeeId = '',
    required List<KitItem> items,
    String notes = '',
    bool returnToStudio = false,
  }) async {
    final body = {
      'name': name,
      if (employeeId.isNotEmpty) 'employeeId': employeeId,
      'items': items.map((e) => e.toJson()).toList(),
      'notes': notes,
      if (returnToStudio) 'returnToStudio': true,
    };
    try {
      final res = id == null
          ? await _dio.post('/inventory/kits', data: body)
          : await _dio.put('/inventory/kits/$id', data: body);
      return StaffKit.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save kit');
    }
  }

  Future<void> deleteKit(String id, {bool returnToStudio = false}) async {
    try {
      await _dio.delete(
        '/inventory/kits/$id',
        queryParameters: {if (returnToStudio) 'returnToStudio': 'true'},
      );
    } catch (e) {
      throw AppException(e, action: 'delete kit');
    }
  }

  /// Assignment history, newest first (optionally for one kit / product).
  Future<List<KitMovement>> getKitMovements({
    String? kitId,
    String? productId,
  }) async {
    try {
      final res = await _dio.get(
        '/inventory/kits/movements',
        queryParameters: {
          if (kitId != null && kitId.isNotEmpty) 'kitId': kitId,
          if (productId != null && productId.isNotEmpty) 'productId': productId,
        },
      );
      return (res.data as List)
          .map((e) => KitMovement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load assignment history');
    }
  }
}
