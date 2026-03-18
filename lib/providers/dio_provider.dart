import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_provider.g.dart';

@riverpod
Dio dio( ref) {
  // If you are using Android Emulator, localhost might need to be 10.0.2.2.
  // If you are using real device, use your computer's local IP address.
  return Dio(
    BaseOptions(
      baseUrl: 'http://localhost:5001/api',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );
}
