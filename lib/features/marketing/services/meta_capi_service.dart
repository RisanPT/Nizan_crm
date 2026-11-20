import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/meta_capi_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Lead results back to Meta (backend /api/meta/capi).
class MetaCapiService {
  MetaCapiService(this._dio);
  final Dio _dio;

  Map<String, dynamic> _map(Response<dynamic> res) => (res.data as Map).cast<String, dynamic>();

  Future<MetaCapiStatus> status() async {
    try {
      return MetaCapiStatus.fromJson(_map(await _dio.get('/meta/capi/status')));
    } catch (e) {
      throw AppException(e, action: 'load results to Meta');
    }
  }

  Future<MetaCapiStatus> setEnabled(bool on) async {
    try {
      return MetaCapiStatus.fromJson(_map(await _dio.put('/meta/capi/settings', data: {'enabled': on})));
    } catch (e) {
      throw AppException(e, action: on ? 'switch on results to Meta' : 'switch off results to Meta');
    }
  }

  Future<MetaCapiRun> sendNow() async {
    try {
      return MetaCapiRun.fromJson(((_map(await _dio.post('/meta/capi/send')))['run'] as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException(e, action: 'send results to Meta');
    }
  }
}

final metaCapiServiceProvider = Provider<MetaCapiService>((ref) => MetaCapiService(ref.watch(dioProvider)));

final metaCapiStatusProvider = FutureProvider.autoDispose<MetaCapiStatus>((ref) => ref.watch(metaCapiServiceProvider).status(), retry: (_, _) => null);
