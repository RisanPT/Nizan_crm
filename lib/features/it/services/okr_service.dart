import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';

final okrServiceProvider = Provider((ref) => OKRService(ref.watch(dioProvider)));

final projectOKRsProvider = FutureProvider.family<List<OKRModel>, String?>((ref, projectId) async {
  final service = ref.watch(okrServiceProvider);
  return service.getOKRs(projectId: projectId);
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
  }) async {
    final query = <String, dynamic>{};
    if (projectId != null && projectId.isNotEmpty && projectId != 'all') {
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

    final res = await _dio.get('/okrs', queryParameters: query);
    return (res.data as List)
        .map((e) => OKRModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<OKRModel> getOKRById(String id) async {
    final res = await _dio.get('/okrs/$id');
    return OKRModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<OKRModel> createOKR(Map<String, dynamic> data) async {
    final res = await _dio.post('/okrs', data: data);
    return OKRModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<OKRModel> updateOKR(String id, Map<String, dynamic> updates) async {
    final res = await _dio.put('/okrs/$id', data: updates);
    return OKRModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteOKR(String id) async {
    await _dio.delete('/okrs/$id');
  }
}
