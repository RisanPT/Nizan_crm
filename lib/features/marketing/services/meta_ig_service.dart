import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/meta_ig_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The Instagram insights sync (backend /api/meta/ig).
class MetaIgService {
  MetaIgService(this._dio);
  final Dio _dio;

  Map<String, dynamic> _map(Response<dynamic> res) => (res.data as Map).cast<String, dynamic>();

  Future<MetaIgStatus> status() async {
    try {
      return MetaIgStatus.fromJson(_map(await _dio.get('/meta/ig/status')));
    } catch (e) {
      throw AppException(e, action: 'load the Instagram sync');
    }
  }

  Future<MetaIgRun> syncNow(int days) async {
    try {
      return MetaIgRun.fromJson(((_map(await _dio.post('/meta/ig/sync', data: {'days': days})))['run'] as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException(e, action: 'sync with Instagram');
    }
  }

  Future<MetaIgStatus> setAutoSync(bool on) async {
    try {
      return MetaIgStatus.fromJson(_map(await _dio.put('/meta/ig/settings', data: {'autoSync': on})));
    } catch (e) {
      throw AppException(e, action: 'switch the automatic sync');
    }
  }

  Future<List<MetaIgFound>> find() async {
    try {
      final b = _map(await _dio.post('/meta/ig/find'));
      return (b['accounts'] as List? ?? const []).whereType<Map>().map((e) => MetaIgFound.fromJson(e.cast<String, dynamic>())).toList();
    } catch (e) {
      throw AppException(e, action: 'find the Instagram accounts');
    }
  }

  Future<int> add(String mediaId) async {
    try {
      return ((_map(await _dio.post('/meta/ig/unmatched/$mediaId/add')))['added'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw AppException(e, action: 'add the Instagram post');
    }
  }

  Future<int> addAll() async {
    try {
      return ((_map(await _dio.post('/meta/ig/unmatched/add-all')))['added'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw AppException(e, action: 'add the Instagram posts');
    }
  }

  Future<void> link(String mediaId, String contentId) async {
    try {
      await _dio.post('/meta/ig/unmatched/$mediaId/link', data: {'contentId': contentId});
    } catch (e) {
      throw AppException(e, action: 'link the Instagram post');
    }
  }

  Future<void> ignore(String mediaId) async {
    try {
      await _dio.post('/meta/ig/unmatched/$mediaId/ignore');
    } catch (e) {
      throw AppException(e, action: 'hide the Instagram post');
    }
  }

  Future<void> restore(String mediaId) async {
    try {
      await _dio.post('/meta/ig/ignored/$mediaId/restore');
    } catch (e) {
      throw AppException(e, action: 'show the Instagram post again');
    }
  }
}

final metaIgServiceProvider = Provider<MetaIgService>((ref) => MetaIgService(ref.watch(dioProvider)));

final metaIgStatusProvider = FutureProvider.autoDispose<MetaIgStatus>((ref) => ref.watch(metaIgServiceProvider).status(), retry: (_, _) => null);
