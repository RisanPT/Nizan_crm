import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/crm_user.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../providers/dio_provider.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(dioProvider));
});

final crmUsersProvider = FutureProvider<List<CrmUser>>((ref) async {
  return ref.watch(userServiceProvider).getUsers();
});

final paginatedCrmUsersProvider =
    FutureProvider.family<PaginatedListResponse<CrmUser>, ListPageParams>((
      ref,
      params,
    ) async {
      return ref.watch(userServiceProvider).getPaginatedUsers(
            page: params.page,
            limit: params.limit,
          );
    });

class UserService {
  UserService(this._dio);

  final Dio _dio;

  Future<List<CrmUser>> getUsers() async {
    try {
      final response = await _dio.get('/auth/users');
      final data = response.data as List;
      return data
          .map((item) => CrmUser.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to load users'));
    }
  }

  Future<PaginatedListResponse<CrmUser>> getPaginatedUsers({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/auth/users',
        queryParameters: {'page': page, 'limit': limit},
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        CrmUser.fromJson,
      );
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to load users'));
    }
  }

  Future<CrmUser> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    required bool active,
    String? employeeId,
    String? zoneId,
    String? stateId,
    String? regionId,
    String? districtId,
    String? pincodeId,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/users',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'active': active,
          if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
          if (zoneId != null && zoneId.isNotEmpty) 'zoneId': zoneId,
          if (stateId != null && stateId.isNotEmpty) 'stateId': stateId,
          if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
          if (districtId != null && districtId.isNotEmpty) 'districtId': districtId,
          if (pincodeId != null && pincodeId.isNotEmpty) 'pincodeId': pincodeId,
        },
      );

      return CrmUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to create user'));
    }
  }

  Future<CrmUser> updateUser({
    required String id,
    required String name,
    required String email,
    required String role,
    required bool active,
    String? password,
    String? employeeId,
    String? zoneId,
    String? stateId,
    String? regionId,
    String? districtId,
    String? pincodeId,
  }) async {
    try {
      final response = await _dio.put(
        '/auth/users/$id',
        data: {
          'name': name,
          'email': email,
          'role': role,
          'active': active,
          if (password != null && password.trim().isNotEmpty) 'password': password,
          'employeeId': (employeeId != null && employeeId.isNotEmpty) ? employeeId : null,
          'zoneId': (zoneId != null && zoneId.isNotEmpty) ? zoneId : null,
          'stateId': (stateId != null && stateId.isNotEmpty) ? stateId : null,
          'regionId': (regionId != null && regionId.isNotEmpty) ? regionId : null,
          'districtId': (districtId != null && districtId.isNotEmpty) ? districtId : null,
          'pincodeId': (pincodeId != null && pincodeId.isNotEmpty) ? pincodeId : null,
        },
      );

      return CrmUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to update user'));
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _dio.delete('/auth/users/$id');
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to delete user'));
    }
  }

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? fallback;
    }
    return e.message ?? fallback;
  }
}
