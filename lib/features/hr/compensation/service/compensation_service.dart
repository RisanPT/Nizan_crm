import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/compensation/data/compensation_models.dart';

class CompensationService {
  final Dio _dio;
  CompensationService(this._dio);

  Future<List<SalaryBand>> getBands() async {
    try {
      final res = await _dio.get('/compensation/bands');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => SalaryBand.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load salary bands');
    }
  }

  Future<void> saveBand(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/compensation/bands', data: body);
      } else {
        await _dio.put('/compensation/bands/$id', data: body);
      }
    } catch (e) {
      throw AppException(e, action: 'save salary band');
    }
  }

  Future<void> deleteBand(String id) async {
    try {
      await _dio.delete('/compensation/bands/$id');
    } catch (e) {
      throw AppException(e, action: 'delete salary band');
    }
  }

  Future<List<CompensationRevision>> getRevisions({String? status}) async {
    try {
      final res = await _dio.get('/compensation/revisions', queryParameters: {'status': ?status});
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => CompensationRevision.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load revisions');
    }
  }

  Future<void> proposeRevision({
    required String employeeId,
    required double proposedSalary,
    DateTime? effectiveDate,
    String reason = '',
  }) async {
    try {
      await _dio.post('/compensation/revisions', data: {
        'employeeId': employeeId,
        'proposedSalary': proposedSalary,
        if (effectiveDate != null) 'effectiveDate': effectiveDate.toIso8601String(),
        'reason': reason,
      });
    } catch (e) {
      throw AppException(e, action: 'propose revision');
    }
  }

  Future<void> cancelRevision(String id) async {
    try {
      await _dio.post('/compensation/revisions/$id/cancel');
    } catch (e) {
      throw AppException(e, action: 'cancel revision');
    }
  }
}

final compensationServiceProvider =
    Provider<CompensationService>((ref) => CompensationService(ref.watch(dioProvider)));

final salaryBandsProvider = FutureProvider<List<SalaryBand>>((ref) => ref.watch(compensationServiceProvider).getBands());

final revisionsProvider =
    FutureProvider<List<CompensationRevision>>((ref) => ref.watch(compensationServiceProvider).getRevisions());
