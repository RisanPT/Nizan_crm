import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../core/models/service_region.dart';
import '../providers/dio_provider.dart';

final regionServiceProvider = Provider<RegionService>((ref) {
  return RegionService(ref.watch(dioProvider));
});

final regionsProvider = FutureProvider<List<ServiceRegion>>((ref) async {
  return ref.watch(regionServiceProvider).getRegions(activeOnly: true);
});

final paginatedRegionsProvider = FutureProvider.family<
    PaginatedListResponse<ServiceRegion>, ListPageParams>((ref, params) async {
  return ref.watch(regionServiceProvider).getPaginatedRegions(
        page: params.page,
        limit: params.limit,
      );
});

class RegionService {
  final Dio _dio;

  RegionService(this._dio);

  Future<List<ServiceRegion>> getRegions({bool activeOnly = false}) async {
    try {
      final response = await _dio.get(
        '/regions',
        queryParameters: activeOnly ? {'active': 'true'} : null,
      );
      final data = response.data as List;
      return data
          .map((item) => ServiceRegion.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load regions: ${e.message}');
    }
  }

  Future<PaginatedListResponse<ServiceRegion>> getPaginatedRegions({
    int page = 1,
    int limit = 20,
    bool activeOnly = false,
  }) async {
    try {
      final response = await _dio.get(
        '/regions',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (activeOnly) 'active': 'true',
        },
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        ServiceRegion.fromJson,
      );
    } on DioException catch (e) {
      throw Exception('Failed to load regions: ${e.message}');
    }
  }

  Future<ServiceRegion> saveRegion({
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
          ? await _dio.put('/regions/$id', data: payload)
          : await _dio.post('/regions', data: payload);

      return ServiceRegion.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to save region: ${e.message}');
    }
  }

  Future<void> deleteRegion(String id) async {
    try {
      await _dio.delete('/regions/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete region: ${e.message}');
    }
  }
}
