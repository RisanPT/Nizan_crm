import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../core/models/service_package.dart';
import '../providers/dio_provider.dart';

final packageServiceProvider = Provider<PackageService>((ref) {
  return PackageService(ref.watch(dioProvider));
});

final packagesProvider = FutureProvider<List<ServicePackage>>((ref) async {
  return ref.watch(packageServiceProvider).getPackages();
});

final paginatedPackagesProvider = FutureProvider.family<
    PaginatedListResponse<ServicePackage>, ListPageParams>((ref, params) async {
  return ref.watch(packageServiceProvider).getPaginatedPackages(
        page: params.page,
        limit: params.limit,
      );
});

class PackageService {
  final Dio _dio;

  PackageService(this._dio);

  Future<List<ServicePackage>> getPackages() async {
    try {
      final response = await _dio.get('/packages');
      final data = response.data as List;
      return data
          .map((item) => ServicePackage.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load packages: ${e.message}');
    }
  }

  Future<PaginatedListResponse<ServicePackage>> getPaginatedPackages({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/packages',
        queryParameters: {'page': page, 'limit': limit},
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        ServicePackage.fromJson,
      );
    } on DioException catch (e) {
      throw Exception('Failed to load packages: ${e.message}');
    }
  }

  Future<ServicePackage> savePackage({
    String? id,
    required String name,
    required double price,
    required double advanceAmount,
    required String description,
    required List<RegionalPrice> regionPrices,
  }) async {
    try {
      final payload = {
        if (id != null && id.isNotEmpty) 'id': id,
        'name': name,
        'price': price,
        'advanceAmount': advanceAmount,
        'description': description,
        'regionPrices': regionPrices.map((item) => item.toJson()).toList(),
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/packages/$id', data: payload)
          : await _dio.post('/packages', data: payload);

      return ServicePackage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to save package: ${e.message}');
    }
  }

  Future<void> deletePackage(String id) async {
    try {
      await _dio.delete('/packages/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete package: ${e.message}');
    }
  }
}
