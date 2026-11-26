import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/meta_ads_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The live Meta ad spend sync (backend /api/meta/ads).
class MetaAdsService {
  MetaAdsService(this._dio);
  final Dio _dio;

  Map<String, dynamic> _map(Response<dynamic> res) => (res.data as Map).cast<String, dynamic>();

  Future<MetaAdsStatus> status() async {
    try {
      return MetaAdsStatus.fromJson(_map(await _dio.get('/meta/ads/status')));
    } catch (e) {
      throw AppException(e, action: 'load the Meta sync');
    }
  }

  /// Bring the last [days] days in now. → the run (ok, or why it failed).
  Future<MetaSyncRun> syncNow(int days) async {
    try {
      final b = _map(await _dio.post('/meta/ads/sync', data: {'days': days}));
      return MetaSyncRun.fromJson((b['run'] as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException(e, action: 'sync with Meta');
    }
  }

  Future<MetaAdsStatus> setAutoSync(bool on) async {
    try {
      return MetaAdsStatus.fromJson(_map(await _dio.put('/meta/ads/settings', data: {'autoSync': on})));
    } catch (e) {
      throw AppException(e, action: 'switch the automatic sync');
    }
  }

  Future<MetaLinkResult> link(String metaId, String campaignId) async {
    try {
      return MetaLinkResult.fromJson(_map(await _dio.post('/meta/ads/unlinked/$metaId/link', data: {'campaignId': campaignId})));
    } catch (e) {
      throw AppException(e, action: 'link the Meta campaign');
    }
  }

  Future<MetaLinkResult> add(String metaId) async {
    try {
      return MetaLinkResult.fromJson(_map(await _dio.post('/meta/ads/unlinked/$metaId/add')));
    } catch (e) {
      throw AppException(e, action: 'add the Meta campaign');
    }
  }

  Future<MetaLinkResult> addAll() async {
    try {
      return MetaLinkResult.fromJson(_map(await _dio.post('/meta/ads/unlinked/add-all')));
    } catch (e) {
      throw AppException(e, action: 'add the Meta campaigns');
    }
  }

  Future<MetaAdsStatus> ignore(String metaId) async {
    try {
      return MetaAdsStatus.fromJson(_map(await _dio.post('/meta/ads/unlinked/$metaId/ignore')));
    } catch (e) {
      throw AppException(e, action: 'hide the Meta campaign');
    }
  }

  Future<MetaAdsStatus> restore(String metaId) async {
    try {
      return MetaAdsStatus.fromJson(_map(await _dio.post('/meta/ads/ignored/$metaId/restore')));
    } catch (e) {
      throw AppException(e, action: 'show the Meta campaign again');
    }
  }
}

final metaAdsServiceProvider = Provider<MetaAdsService>((ref) => MetaAdsService(ref.watch(dioProvider)));

final metaAdsStatusProvider = FutureProvider.autoDispose<MetaAdsStatus>((ref) => ref.watch(metaAdsServiceProvider).status(), retry: (_, _) => null);
