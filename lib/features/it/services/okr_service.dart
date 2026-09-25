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

/// Planning OKRs (company + department level, not tied to any project) — powers
/// the Company Planning Dashboard.
final planningOkrsProvider = FutureProvider<List<OKRModel>>((ref) async {
  return ref.watch(okrServiceProvider).getOKRs(companyScope: true);
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

  Future<void> deleteOKR(String id) async {
    try {
      await _dio.delete('/okrs/$id');
    } catch (e) {
      throw AppException(e, action: 'delete the OKR');
    }
  }
}
