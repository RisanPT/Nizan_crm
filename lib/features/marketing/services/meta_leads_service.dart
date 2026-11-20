import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/meta_leads_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Meta Lead Ads screen (backend /api/meta).
class MetaLeadsService {
  MetaLeadsService(this._dio);
  final Dio _dio;

  Map<String, dynamic> _map(Response<dynamic> res) => (res.data as Map).cast<String, dynamic>();

  Future<MetaLeadsStatus> status() async {
    try {
      return MetaLeadsStatus.fromJson(_map(await _dio.get('/meta/status')));
    } catch (e) {
      throw AppException(e, action: 'load Meta Lead Ads');
    }
  }

  /// [status]: all | created | existing | failed | waiting.
  Future<MetaEventPage> events({String status = 'all', int page = 1, int limit = 25}) async {
    try {
      return MetaEventPage.fromJson(_map(await _dio.get('/meta/events', queryParameters: {'status': status, 'page': page, 'limit': limit})));
    } catch (e) {
      throw AppException(e, action: 'load the Meta leads');
    }
  }

  Future<MetaTestResult> test() async {
    try {
      return MetaTestResult.fromJson(_map(await _dio.post('/meta/test')));
    } catch (e) {
      throw AppException(e, action: 'test the Meta connection');
    }
  }

  /// [mode] none = new leads wait for a manager; rotate = the chosen Sales people take turns.
  Future<MetaLeadsStatus> saveAssignment(String mode, List<String> userIds) async {
    try {
      return MetaLeadsStatus.fromJson(_map(await _dio.put('/meta/settings', data: {'assignMode': mode, 'rotateUserIds': userIds})));
    } catch (e) {
      throw AppException(e, action: 'save who gets Meta leads');
    }
  }

  Future<MetaLeadEvent> retry(String id) async {
    try {
      return MetaLeadEvent.fromJson(_map(await _dio.post('/meta/events/$id/retry')));
    } catch (e) {
      throw AppException(e, action: 'try the lead again');
    }
  }

  Future<MetaCheckResult> checkMissed(int days) async {
    try {
      return MetaCheckResult.fromJson(_map(await _dio.post('/meta/check', data: {'days': days})));
    } catch (e) {
      throw AppException(e, action: 'check Meta for missed leads');
    }
  }
}

final metaLeadsServiceProvider = Provider<MetaLeadsService>((ref) => MetaLeadsService(ref.watch(dioProvider)));

final metaLeadsStatusProvider = FutureProvider.autoDispose<MetaLeadsStatus>((ref) => ref.watch(metaLeadsServiceProvider).status(), retry: (_, _) => null);

/// The list's filter and page.
final metaEventsFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');
final metaEventsPageProvider = StateProvider.autoDispose<int>((ref) => 1);

final metaEventsProvider = FutureProvider.autoDispose<MetaEventPage>(
  (ref) => ref.watch(metaLeadsServiceProvider).events(status: ref.watch(metaEventsFilterProvider), page: ref.watch(metaEventsPageProvider)),
  retry: (_, _) => null,
);
