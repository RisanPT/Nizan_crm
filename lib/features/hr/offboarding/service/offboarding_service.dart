import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/offboarding/data/offboarding_models.dart';

class OffboardingService {
  final Dio _dio;
  OffboardingService(this._dio);

  Future<List<Offboarding>> getAll({String? status}) async {
    try {
      final res = await _dio.get('/offboarding', queryParameters: {'status': ?status});
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => Offboarding.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load offboarding');
    }
  }

  Future<void> create({
    required String employeeId,
    required String reason,
    DateTime? lastWorkingDay,
  }) async {
    try {
      await _dio.post('/offboarding', data: {
        'employeeId': employeeId,
        'reason': reason,
        if (lastWorkingDay != null) 'lastWorkingDay': lastWorkingDay.toIso8601String(),
      });
    } catch (e) {
      throw AppException(e, action: 'start offboarding');
    }
  }

  Future<void> update(
    String id, {
    List<ClearanceItem>? clearanceItems,
    double? finalSettlementAmount,
    bool? settlementPaid,
    bool? experienceLetterIssued,
    String? status,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (clearanceItems != null) data['clearanceItems'] = clearanceItems.map((c) => c.toJson()).toList();
      if (finalSettlementAmount != null) data['finalSettlementAmount'] = finalSettlementAmount;
      if (settlementPaid != null) data['settlementPaid'] = settlementPaid;
      if (experienceLetterIssued != null) data['experienceLetterIssued'] = experienceLetterIssued;
      if (status != null) data['status'] = status;
      await _dio.put('/offboarding/$id', data: data);
    } catch (e) {
      throw AppException(e, action: 'update offboarding');
    }
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete('/offboarding/$id');
    } catch (e) {
      throw AppException(e, action: 'delete offboarding');
    }
  }
}

final offboardingServiceProvider =
    Provider<OffboardingService>((ref) => OffboardingService(ref.watch(dioProvider)));

final offboardingsProvider =
    FutureProvider<List<Offboarding>>((ref) => ref.watch(offboardingServiceProvider).getAll());
