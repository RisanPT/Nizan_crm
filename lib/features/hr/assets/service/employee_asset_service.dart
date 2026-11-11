import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/assets/data/employee_asset_models.dart';

/// Client for /api/employee-assets (backend routes/employeeAssetRoutes.js).
class EmployeeAssetService {
  final Dio _dio;
  EmployeeAssetService(this._dio);

  Future<List<EmployeeAsset>> getAll({String? employeeId, String? status}) async {
    try {
      final res = await _dio.get('/employee-assets', queryParameters: {
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        if (status != null && status.isNotEmpty && status != 'all') 'status': status,
      });
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => EmployeeAsset.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load assets');
    }
  }

  Future<void> issue({
    required String employeeId,
    required String item,
    String category = 'other',
    String serialNo = '',
    DateTime? issuedOn,
    String condition = '',
    String notes = '',
  }) async {
    try {
      await _dio.post('/employee-assets', data: {
        'employeeId': employeeId,
        'item': item,
        'category': category,
        'serialNo': serialNo,
        if (issuedOn != null) 'issuedOn': issuedOn.toIso8601String(),
        'condition': condition,
        'notes': notes,
      });
    } catch (e) {
      throw AppException(e, action: 'issue asset');
    }
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    try {
      await _dio.put('/employee-assets/$id', data: body);
    } catch (e) {
      throw AppException(e, action: 'update asset');
    }
  }

  Future<void> markReturned(String id, {DateTime? returnedOn, String returnCondition = '', String notes = ''}) async {
    try {
      await _dio.post('/employee-assets/$id/return', data: {
        if (returnedOn != null) 'returnedOn': returnedOn.toIso8601String(),
        'returnCondition': returnCondition,
        if (notes.isNotEmpty) 'notes': notes,
      });
    } catch (e) {
      throw AppException(e, action: 'mark asset returned');
    }
  }

  Future<void> markLost(String id, {String notes = ''}) async {
    try {
      await _dio.post('/employee-assets/$id/lost', data: {if (notes.isNotEmpty) 'notes': notes});
    } catch (e) {
      throw AppException(e, action: 'mark asset lost');
    }
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete('/employee-assets/$id');
    } catch (e) {
      throw AppException(e, action: 'delete asset');
    }
  }
}

final employeeAssetServiceProvider =
    Provider<EmployeeAssetService>((ref) => EmployeeAssetService(ref.watch(dioProvider)));

/// All assets visible to the caller (the backend applies department scope).
final employeeAssetsProvider =
    FutureProvider<List<EmployeeAsset>>((ref) => ref.watch(employeeAssetServiceProvider).getAll());

/// Assets of one employee.
final employeeAssetsForProvider = FutureProvider.family<List<EmployeeAsset>, String>(
    (ref, employeeId) => ref.watch(employeeAssetServiceProvider).getAll(employeeId: employeeId));

/// Refreshes every cached asset list after a change.
void invalidateEmployeeAssets(WidgetRef ref, [String? employeeId]) {
  ref.invalidate(employeeAssetsProvider);
  if (employeeId != null && employeeId.isNotEmpty) {
    ref.invalidate(employeeAssetsForProvider(employeeId));
  } else {
    ref.invalidate(employeeAssetsForProvider);
  }
}
