import 'package:dio/dio.dart';
import '../core/models/auth_session.dart';
import '../providers/dio_provider.dart';

class AuthService {
  AuthService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: apiBaseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

  final Dio _dio;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      return AuthSession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      final message = _extractMessage(error) ?? 'Failed to sign in';
      throw Exception(message);
    }
  }

  Future<AuthSession> getCurrentUser(String token) async {
    try {
      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return AuthSession.fromJson({
        'token': token,
        'user': data['user'],
      });
    } on DioException catch (error) {
      final message = _extractMessage(error) ?? 'Failed to restore session';
      throw Exception(message);
    }
  }

  String? _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? data['details'] as String?;
    }
    return error.message;
  }
}
