import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/crm_user.dart';
import '../providers/dio_provider.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(dioProvider));
});

final crmUsersProvider = FutureProvider<List<CrmUser>>((ref) async {
  return ref.watch(userServiceProvider).getUsers();
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

  Future<CrmUser> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    required bool active,
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
        },
      );

      return CrmUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_message(e, 'Failed to update user'));
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
