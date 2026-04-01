import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/addon_service.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../providers/dio_provider.dart';

final addonServiceServiceProvider = Provider<AddonServiceService>((ref) {
  return AddonServiceService(ref.watch(dioProvider));
});

final addonServicesProvider = FutureProvider<List<AddonService>>((ref) async {
  return ref.watch(addonServiceServiceProvider).getAddonServices();
});

final paginatedAddonServicesProvider = FutureProvider.family<
    PaginatedListResponse<AddonService>, ListPageParams>((ref, params) async {
  return ref.watch(addonServiceServiceProvider).getPaginatedAddonServices(
        page: params.page,
        limit: params.limit,
      );
});

class AddonServiceService {
  final Dio _dio;

  AddonServiceService(this._dio);

  Future<List<AddonService>> getAddonServices() async {
    try {
      final response = await _dio.get('/addon-services');
      final data = response.data as List;
      return data
          .map((item) => AddonService.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load add-on services: ${e.message}');
    }
  }

  Future<PaginatedListResponse<AddonService>> getPaginatedAddonServices({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/addon-services',
        queryParameters: {'page': page, 'limit': limit},
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        AddonService.fromJson,
      );
    } on DioException catch (e) {
      throw Exception('Failed to load add-on services: ${e.message}');
    }
  }

  Future<AddonService> saveAddonService({
    String? id,
    required String name,
    required double price,
    required String description,
    required String status,
  }) async {
    try {
      final payload = {
        if (id != null && id.isNotEmpty) 'id': id,
        'name': name,
        'price': price,
        'description': description,
        'status': status,
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/addon-services/$id', data: payload)
          : await _dio.post('/addon-services', data: payload);

      return AddonService.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to save add-on service: ${e.message}');
    }
  }

  Future<void> deleteAddonService(String id) async {
    try {
      await _dio.delete('/addon-services/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete add-on service: ${e.message}');
    }
  }
}
