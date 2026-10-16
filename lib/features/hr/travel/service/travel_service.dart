import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/travel/data/travel_models.dart';

class TravelService {
  final Dio _dio;
  TravelService(this._dio);

  List<TravelRequest> _list(dynamic data) {
    final raw = data is List ? data : const [];
    return raw.map((e) => TravelRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TravelRequest>> getMine() async {
    try {
      final res = await _dio.get('/travel/mine');
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load my travel');
    }
  }

  Future<List<TravelRequest>> getRequests({String? status}) async {
    try {
      final res = await _dio.get('/travel/requests', queryParameters: {'status': ?status});
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load travel requests');
    }
  }

  Future<void> apply({
    required String destination,
    String purpose = '',
    String mode = 'flight',
    DateTime? fromDate,
    DateTime? toDate,
    double estimatedCost = 0,
    bool advanceRequested = false,
    double advanceAmount = 0,
  }) async {
    try {
      await _dio.post('/travel', data: {
        'destination': destination,
        'purpose': purpose,
        'mode': mode,
        if (fromDate != null) 'fromDate': fromDate.toIso8601String(),
        if (toDate != null) 'toDate': toDate.toIso8601String(),
        'estimatedCost': estimatedCost,
        'advanceRequested': advanceRequested,
        'advanceAmount': advanceAmount,
      });
    } catch (e) {
      throw AppException(e, action: 'submit travel request');
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _dio.post('/travel/$id/cancel');
    } catch (e) {
      throw AppException(e, action: 'cancel travel request');
    }
  }
}

final travelServiceProvider = Provider<TravelService>((ref) => TravelService(ref.watch(dioProvider)));

final myTravelProvider = FutureProvider<List<TravelRequest>>((ref) => ref.watch(travelServiceProvider).getMine());

final travelRequestsProvider =
    FutureProvider<List<TravelRequest>>((ref) => ref.watch(travelServiceProvider).getRequests());
