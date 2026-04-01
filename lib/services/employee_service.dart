import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/employee.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../providers/dio_provider.dart';

final employeeServiceProvider = Provider<EmployeeService>((ref) {
  return EmployeeService(ref.watch(dioProvider));
});

final employeesProvider = FutureProvider<List<Employee>>((ref) async {
  return ref.watch(employeeServiceProvider).getEmployees();
});

final paginatedEmployeesProvider =
    FutureProvider.family<PaginatedListResponse<Employee>, ListPageParams>((
      ref,
      params,
    ) async {
      return ref.watch(employeeServiceProvider).getPaginatedEmployees(
            page: params.page,
            limit: params.limit,
          );
    });

class EmployeeService {
  final Dio _dio;

  EmployeeService(this._dio);

  Future<List<Employee>> getEmployees() async {
    try {
      final response = await _dio.get('/employees');
      final data = response.data as List;
      return data
          .map((item) => Employee.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load employees: ${e.message}');
    }
  }

  Future<PaginatedListResponse<Employee>> getPaginatedEmployees({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/employees',
        queryParameters: {'page': page, 'limit': limit},
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        Employee.fromJson,
      );
    } on DioException catch (e) {
      throw Exception('Failed to load employees: ${e.message}');
    }
  }

  Future<Employee> saveEmployee({
    String? id,
    required String name,
    required String email,
    required String type,
    required String artistRole,
    required String specialization,
    required String phone,
    required String status,
    required String regionId,
  }) async {
    try {
      final payload = {
        'name': name,
        'email': email,
        'type': type,
        'artistRole': artistRole,
        'specialization': specialization,
        'phone': phone,
        'status': status,
        'regionId': regionId,
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/employees/$id', data: payload)
          : await _dio.post('/employees', data: payload);

      return Employee.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      String errorMessage = 'Failed to save employee: ${e.message}';
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          errorMessage = data['message'].toString();
        }
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteEmployee(String id) async {
    try {
      await _dio.delete('/employees/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete employee: ${e.message}');
    }
  }
}
