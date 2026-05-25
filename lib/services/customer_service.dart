import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../providers/dio_provider.dart';
import '../models/customer.dart';

import '../core/auth/app_role.dart';
import '../core/providers/auth_provider.dart';

part 'customer_service.g.dart';

@riverpod
CustomerService customerService(Ref ref) {
  return CustomerService(ref.watch(dioProvider));
}

final customersProvider = FutureProvider<List<Customer>>((ref) {
  final service = ref.watch(customerServiceProvider);
  return service.getCustomers();
});

final paginatedCustomersProvider =
    FutureProvider.family<PaginatedListResponse<Customer>, ListPageParams>((
      ref,
      params,
    ) async {
      final authSession = ref.watch(authControllerProvider).session;
      final role = AppRole.fromString(authSession?.role);

      var zoneId = params.zoneId;
      var stateId = params.stateId;
      var regionId = params.regionId;
      var districtId = params.districtId;
      var pincodeId = params.pincodeId;

      if (!role.isFullAccess) {
        if (authSession != null) {
          if (authSession.zoneId.isNotEmpty) zoneId = authSession.zoneId;
          if (authSession.stateId.isNotEmpty) stateId = authSession.stateId;
          if (authSession.regionId.isNotEmpty) regionId = authSession.regionId;
          if (authSession.districtId.isNotEmpty) districtId = authSession.districtId;
          if (authSession.pincodeId.isNotEmpty) pincodeId = authSession.pincodeId;
        }
      }

      return ref.watch(customerServiceProvider).getPaginatedCustomers(
            page: params.page,
            limit: params.limit,
            zoneId: zoneId,
            stateId: stateId,
            regionId: regionId,
            districtId: districtId,
            pincodeId: pincodeId,
          );
    });

class CustomerService {
  final Dio _dio;

  CustomerService(this._dio);

  Future<List<Customer>> getCustomers() async {
    try {
      final response = await _dio.get('/customers');
      final data = response.data as List;
      return data.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load customers: ${e.message}');
    }
  }

  Future<PaginatedListResponse<Customer>> getPaginatedCustomers({
    int page = 1,
    int limit = 20,
    String? zoneId,
    String? stateId,
    String? regionId,
    String? districtId,
    String? pincodeId,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
        if (zoneId != null && zoneId.isNotEmpty) 'zoneId': zoneId,
        if (stateId != null && stateId.isNotEmpty) 'stateId': stateId,
        if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
        if (districtId != null && districtId.isNotEmpty) 'districtId': districtId,
        if (pincodeId != null && pincodeId.isNotEmpty) 'pincodeId': pincodeId,
      };
      final response = await _dio.get(
        '/customers',
        queryParameters: queryParams,
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        Customer.fromJson,
      );
    } on DioException catch (e) {
      throw Exception('Failed to load customers: ${e.message}');
    }
  }

  Future<Customer> createCustomer(Customer customer) async {
    try {
      final response = await _dio.post(
        '/customers',
        data: customer.toJson(),
      );
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to create customer: ${e.message}');
    }
  }

  Future<Customer> updateCustomer(String id, Customer customer) async {
    try {
      final response = await _dio.put(
        '/customers/$id',
        data: customer.toJson(),
      );
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to update customer: ${e.message}');
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _dio.delete('/customers/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete customer: ${e.message}');
    }
  }
}
