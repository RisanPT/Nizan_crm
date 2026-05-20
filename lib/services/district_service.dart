import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/district.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../providers/dio_provider.dart';

final districtServiceProvider = Provider<DistrictService>((ref) {
  return DistrictService(ref.watch(dioProvider));
});

final districtsProvider = FutureProvider<List<District>>((ref) async {
  return ref.watch(districtServiceProvider).getDistricts(activeOnly: true);
});

final paginatedDistrictsProvider = FutureProvider.family<
    PaginatedListResponse<District>, ListPageParams>((ref, params) async {
  return ref.watch(districtServiceProvider).getPaginatedDistricts(
        page: params.page,
        limit: params.limit,
      );
});

class DistrictService {
  final Dio _dio;

  DistrictService(this._dio);

  Future<List<District>> getDistricts({
    bool activeOnly = false,
    String? regionId,
  }) async {
    try {
      final response = await _dio.get(
        '/districts',
        queryParameters: {
          if (activeOnly) 'active': 'true',
          if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
        },
      );
      final data = response.data as List;
      return data
          .map((item) => District.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load districts: ${e.message}');
    }
  }

  Future<PaginatedListResponse<District>> getPaginatedDistricts({
    int page = 1,
    int limit = 20,
    bool activeOnly = false,
    String? regionId,
  }) async {
    try {
      final response = await _dio.get(
        '/districts',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (activeOnly) 'active': 'true',
          if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
        },
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        District.fromJson,
      );
    } on DioException catch (e) {
      throw Exception('Failed to load districts: ${e.message}');
    }
  }

  Future<District> saveDistrict({
    String? id,
    required String name,
    required String regionId,
    required String status,
  }) async {
    try {
      final payload = {
        if (id != null && id.isNotEmpty) 'id': id,
        'name': name,
        'regionId': regionId,
        'status': status,
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/districts/$id', data: payload)
          : await _dio.post('/districts', data: payload);

      return District.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to save district: ${e.message}');
    }
  }

  Future<void> deleteDistrict(String id) async {
    try {
      await _dio.delete('/districts/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete district: ${e.message}');
    }
  }
}
