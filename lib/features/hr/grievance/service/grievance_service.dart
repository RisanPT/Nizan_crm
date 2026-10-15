import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/grievance/data/grievance_models.dart';

class GrievanceService {
  final Dio _dio;
  GrievanceService(this._dio);

  List<Grievance> _list(dynamic data) {
    final raw = data is List ? data : const [];
    return raw.map((e) => Grievance.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Grievance>> getMine() async {
    try {
      final res = await _dio.get('/grievances/mine');
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load my cases');
    }
  }

  Future<List<Grievance>> getAll({String? status}) async {
    try {
      final res = await _dio.get('/grievances', queryParameters: {'status': ?status});
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load grievances');
    }
  }

  Future<void> raise({
    required String subject,
    required String category,
    String description = '',
    bool confidential = false,
  }) async {
    try {
      await _dio.post('/grievances', data: {
        'subject': subject,
        'category': category,
        'description': description,
        'confidential': confidential,
      });
    } catch (e) {
      throw AppException(e, action: 'raise grievance');
    }
  }

  Future<void> update(String id, {String? status, String? resolutionNote}) async {
    try {
      final data = <String, dynamic>{};
      if (status != null) data['status'] = status;
      if (resolutionNote != null) data['resolutionNote'] = resolutionNote;
      await _dio.put('/grievances/$id', data: data);
    } catch (e) {
      throw AppException(e, action: 'update grievance');
    }
  }

  Future<void> withdraw(String id) async {
    try {
      await _dio.post('/grievances/$id/withdraw');
    } catch (e) {
      throw AppException(e, action: 'withdraw grievance');
    }
  }
}

final grievanceServiceProvider =
    Provider<GrievanceService>((ref) => GrievanceService(ref.watch(dioProvider)));

final myGrievancesProvider = FutureProvider<List<Grievance>>((ref) => ref.watch(grievanceServiceProvider).getMine());

final grievanceQueueProvider = FutureProvider<List<Grievance>>((ref) => ref.watch(grievanceServiceProvider).getAll());
