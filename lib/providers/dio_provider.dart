import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/network/connectivity.dart';
import '../core/providers/auth_provider.dart';

part 'dio_provider.g.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:5001/api',
);

@riverpod
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      // Fail fast when the server can't be reached at all, so the user sees
      // "can't connect" in seconds rather than after a minute.
      connectTimeout: const Duration(seconds: 20),
      // Heavy reports/exports can legitimately take a while to answer.
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: kIsWeb ? null : const Duration(seconds: 60),
    ),
  );

  // Lets the offline banner probe the server (`GET /api`, unauthenticated).
  final connectivity = ref.read(connectivityProvider.notifier);
  connectivity.ping = () => dio.get<dynamic>('');

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = ref.read(authSessionProvider);
        final token = session?.token;

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await ref.read(authControllerProvider).logout();
        }
        handler.next(error);
      },
    ),
  );
  dio.interceptors
      .add(ConnectivityInterceptor(() => ref.read(connectivityProvider.notifier)));

  return dio;
}
