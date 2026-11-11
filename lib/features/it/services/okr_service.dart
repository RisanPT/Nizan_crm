import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';

final okrServiceProvider = Provider((ref) => OKRService(ref.watch(dioProvider)));

final projectOKRsProvider = FutureProvider.family<List<OKRModel>, String?>((ref, projectId) async {
  final service = ref.watch(okrServiceProvider);
  return service.getOKRs(projectId: projectId);
});

/// Planning & Project OKRs viewable by the current user — powers
/// the Company Planning Dashboard.
final planningOkrsProvider = FutureProvider<List<OKRModel>>((ref) async {
  return ref.watch(okrServiceProvider).getOKRs();
});

class OKRService {
  final Dio _dio;
  OKRService(this._dio);

  Future<List<OKRModel>> getOKRs({
    String? projectId,
    String? department,
    String? status,
    bool? completed,
    String? search,
    bool companyScope = false,
  }) async {
    final query = <String, dynamic>{};
    if (companyScope) {
      query['scope'] = 'company';
    } else if (projectId != null && projectId.isNotEmpty && projectId != 'all') {
      query['projectId'] = projectId;
    }
    if (department != null && department.isNotEmpty) {
      query['department'] = department;
    }
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }
    if (completed != null) {
      query['completed'] = completed.toString();
    }
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }

    try {
      final res = await _dio.get('/okrs', queryParameters: query);
      return (res.data as List)
          .map((e) => OKRModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load OKRs');
    }
  }

  Future<OKRModel> getOKRById(String id) async {
    try {
      final res = await _dio.get('/okrs/$id');
      return OKRModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'load the OKR');
    }
  }

  Future<OKRModel> createOKR(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/okrs', data: data);
      return OKRModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'create the OKR');
    }
  }

  Future<OKRModel> updateOKR(String id, Map<String, dynamic> updates) async {
    try {
      final res = await _dio.put('/okrs/$id', data: updates);
      return OKRModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'update the OKR');
    }
  }

  /// Reports on ONE key result without rewriting the objective, so two people updating
  /// different key results never undo each other. [patch] is `{currentValue, completed}`
  /// for anyone who may report progress; `{title, metric, targetValue, unit}` only for
  /// those who manage the objective.
  Future<OKRModel> updateKeyResult(String okrId, String krId, Map<String, dynamic> patch) async {
    try {
      final res = await _dio.patch('/okrs/$okrId/key-results/$krId', data: patch);
      return OKRModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'update the key result');
    }
  }

  /// Deletes the objective; the ones that contributed to it move up a level. Returns how
  /// many moved.
  Future<int> deleteOKR(String id) async {
    try {
      final res = await _dio.delete('/okrs/$id');
      final data = res.data;
      return data is Map ? (data['reparented'] as num?)?.toInt() ?? 0 : 0;
    } catch (e) {
      throw AppException(e, action: 'delete the OKR');
    }
  }
}
