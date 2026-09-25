import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../core/models/zone.dart';
import '../providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';

final zoneServiceProvider = Provider<ZoneService>((ref) {
  return ZoneService(ref.watch(dioProvider));
});

final zonesProvider = FutureProvider<List<ZoneModel>>((ref) async {
  return ref.watch(zoneServiceProvider).getZones(activeOnly: true);
});

final paginatedZonesProvider = FutureProvider.family<
    PaginatedListResponse<ZoneModel>, ListPageParams>((ref, params) async {
  return ref.watch(zoneServiceProvider).getPaginatedZones(
        page: params.page,
        limit: params.limit,
      );
});

class ZoneService {
  final Dio _dio;

  ZoneService(this._dio);

  Future<List<ZoneModel>> getZones({bool activeOnly = false}) async {
    try {
      final response = await _dio.get(
        '/zones',
        queryParameters: activeOnly ? {'active': 'true'} : null,
      );
      final data = response.data as List;
      return data
          .map((item) => ZoneModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load zones');
    }
  }

  Future<PaginatedListResponse<ZoneModel>> getPaginatedZones({
    int page = 1,
    int limit = 20,
    bool activeOnly = false,
  }) async {
    try {
      final response = await _dio.get(
        '/zones',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (activeOnly) 'active': 'true',
        },
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        ZoneModel.fromJson,
      );
    } catch (e) {
      throw AppException(e, action: 'load zones');
    }
  }

  Future<ZoneModel> saveZone({
    String? id,
    required String name,
    required String status,
  }) async {
    try {
      final payload = {
        if (id != null && id.isNotEmpty) 'id': id,
        'name': name,
        'status': status,
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/zones/$id', data: payload)
          : await _dio.post('/zones', data: payload);

      return ZoneModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save zone');
    }
  }

  Future<void> deleteZone(String id) async {
    try {
      await _dio.delete('/zones/$id');
    } catch (e) {
      throw AppException(e, action: 'delete zone');
    }
  }
}
