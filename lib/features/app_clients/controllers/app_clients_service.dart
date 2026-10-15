import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/app_clients/data/app_client.dart';

/// Staff-side access to the bridal app's clients (brides) — profile,
/// preferences, saved looks and their bookings. Behind the `/api/app-clients`
/// staff guard on the backend.
class AppClientsService {
  final Dio _dio;
  AppClientsService(this._dio);

  Future<List<AppClient>> getClients({String search = ''}) async {
    try {
      final qp = <String, dynamic>{};
      if (search.trim().isNotEmpty) qp['search'] = search.trim();
      final res = await _dio.get('/app-clients',
          queryParameters: qp.isEmpty ? null : qp);
      return (res.data as List)
          .map((e) => AppClient.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load app clients');
    }
  }

  Future<AppClientDetail> getClient(String id) async {
    try {
      final res = await _dio.get('/app-clients/$id');
      return AppClientDetail.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load this client');
    }
  }
}

final appClientsServiceProvider = Provider<AppClientsService>(
    (ref) => AppClientsService(ref.watch(dioProvider)));

final appClientsSearchProvider = StateProvider<String>((ref) => '');

final appClientsProvider =
    FutureProvider.autoDispose<List<AppClient>>((ref) async {
  final search = ref.watch(appClientsSearchProvider);
  return ref.watch(appClientsServiceProvider).getClients(search: search);
});

final appClientDetailProvider =
    FutureProvider.autoDispose.family<AppClientDetail, String>((ref, id) async {
  return ref.watch(appClientsServiceProvider).getClient(id);
});
