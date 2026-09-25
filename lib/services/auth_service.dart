import 'package:dio/dio.dart';
import '../core/models/auth_session.dart';
import '../providers/dio_provider.dart';
import '../core/error/errors.dart';

class AuthService {
  AuthService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
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
    } catch (error) {
      // Keep the original error: the backend's own message (e.g. invalid email
      // or password) is shown as-is, and a network failure reads as
      // "can't reach the server" instead of a generic failure.
      throw AppException(error, action: 'sign in');
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
    } catch (error) {
      throw AppException(error, action: 'restore your session');
    }
  }
}
