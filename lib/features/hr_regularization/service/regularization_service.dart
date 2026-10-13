import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr_regularization/data/regularization_models.dart';

class RegularizationService {
  final Dio _dio;
  RegularizationService(this._dio);

  List<Regularization> _list(dynamic data) {
    final raw = data is List ? data : const [];
    return raw.map((e) => Regularization.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Regularization>> getMine() async {
    try {
      final res = await _dio.get('/regularizations/mine');
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load my requests');
    }
  }

  Future<List<Regularization>> getRequests({String? status}) async {
    try {
      final res = await _dio.get('/regularizations/requests', queryParameters: {
        'status': ?status,
      });
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load regularizations');
    }
  }

  Future<void> apply({
    required DateTime date,
    required String type,
    String requestedInTime = '',
    String requestedOutTime = '',
    String reason = '',
  }) async {
    try {
      await _dio.post('/regularizations', data: {
        'date': date.toIso8601String(),
        'type': type,
        'requestedInTime': requestedInTime,
        'requestedOutTime': requestedOutTime,
        'reason': reason,
      });
    } catch (e) {
      throw AppException(e, action: 'submit regularization');
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _dio.post('/regularizations/$id/cancel');
    } catch (e) {
      throw AppException(e, action: 'cancel request');
    }
  }
}

final regularizationServiceProvider =
    Provider<RegularizationService>((ref) => RegularizationService(ref.watch(dioProvider)));

final myRegularizationsProvider =
    FutureProvider<List<Regularization>>((ref) => ref.watch(regularizationServiceProvider).getMine());

final regularizationRequestsProvider =
    FutureProvider<List<Regularization>>((ref) => ref.watch(regularizationServiceProvider).getRequests());
