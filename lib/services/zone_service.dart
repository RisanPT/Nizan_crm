import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../core/models/zone.dart';
import '../providers/dio_provider.dart';

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
    } on DioException catch (e) {
      throw Exception('Failed to load zones: ${e.message}');
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
    } on DioException catch (e) {
      throw Exception('Failed to load zones: ${e.message}');
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
    } on DioException catch (e) {
      throw Exception('Failed to save zone: ${e.message}');
    }
  }

  Future<void> deleteZone(String id) async {
    try {
      await _dio.delete('/zones/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete zone: ${e.message}');
    }
  }
}
