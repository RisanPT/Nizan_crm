import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../providers/dio_provider.dart';
import '../models/customer.dart';

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
    ) {
      final service = ref.watch(customerServiceProvider);
      return service.getPaginatedCustomers(
        page: params.page,
        limit: params.limit,
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
  }) async {
    try {
      final response = await _dio.get(
        '/customers',
        queryParameters: {'page': page, 'limit': limit},
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
