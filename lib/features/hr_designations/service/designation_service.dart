import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr_designations/data/designation_models.dart';

class DesignationService {
  final Dio _dio;
  DesignationService(this._dio);

  List<Designation> _list(dynamic data) {
    final raw = data is List ? data : const [];
    return raw.map((e) => Designation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Designation>> getAll({String? departmentId}) async {
    try {
      final res = await _dio.get('/designations', queryParameters: {
        'departmentId': ?departmentId,
      });
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load designations');
    }
  }

  Future<Designation> create({
    required String name,
    String code = '',
    String? departmentId,
    int level = 1,
    String description = '',
  }) async {
    try {
      final res = await _dio.post('/designations', data: {
        'name': name,
        'code': code,
        'departmentId': departmentId,
        'level': level,
        'description': description,
      });
      return Designation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'create designation');
    }
  }

  Future<Designation> update(String id, Map<String, dynamic> changes) async {
    try {
      final res = await _dio.put('/designations/$id', data: changes);
      return Designation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update designation');
    }
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete('/designations/$id');
    } catch (e) {
      throw AppException(e, action: 'delete designation');
    }
  }
}

final designationServiceProvider =
    Provider<DesignationService>((ref) => DesignationService(ref.watch(dioProvider)));

final designationsProvider =
    FutureProvider<List<Designation>>((ref) => ref.watch(designationServiceProvider).getAll());
