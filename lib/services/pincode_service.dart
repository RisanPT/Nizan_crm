import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../core/models/pincode.dart';
import '../providers/dio_provider.dart';

final pincodeServiceProvider = Provider<PincodeService>((ref) {
  return PincodeService(ref.watch(dioProvider));
});

final pincodesProvider = FutureProvider<List<Pincode>>((ref) async {
  return ref.watch(pincodeServiceProvider).getPincodes(activeOnly: true);
});

final paginatedPincodesProvider = FutureProvider.family<
    PaginatedListResponse<Pincode>, ListPageParams>((ref, params) async {
  return ref.watch(pincodeServiceProvider).getPaginatedPincodes(
        page: params.page,
        limit: params.limit,
      );
});

class PincodeService {
  final Dio _dio;

  PincodeService(this._dio);

  Future<List<Pincode>> getPincodes({
    bool activeOnly = false,
    String? districtId,
  }) async {
    try {
      final response = await _dio.get(
        '/pincodes',
        queryParameters: {
          if (activeOnly) 'active': 'true',
          if (districtId != null && districtId.isNotEmpty) 'districtId': districtId,
        },
      );
      final data = response.data as List;
      return data
          .map((item) => Pincode.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load pincodes: ${e.message}');
    }
  }

  Future<PaginatedListResponse<Pincode>> getPaginatedPincodes({
    int page = 1,
    int limit = 20,
    bool activeOnly = false,
    String? districtId,
  }) async {
    try {
      final response = await _dio.get(
        '/pincodes',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (activeOnly) 'active': 'true',
          if (districtId != null && districtId.isNotEmpty) 'districtId': districtId,
        },
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        Pincode.fromJson,
      );
    } on DioException catch (e) {
      throw Exception('Failed to load pincodes: ${e.message}');
    }
  }

  Future<Pincode> savePincode({
    String? id,
    required String code,
    required String districtId,
    required String status,
  }) async {
    try {
      final payload = {
        if (id != null && id.isNotEmpty) 'id': id,
        'code': code,
        'districtId': districtId,
        'status': status,
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/pincodes/$id', data: payload)
          : await _dio.post('/pincodes', data: payload);

      return Pincode.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to save pincode: ${e.message}');
    }
  }

  Future<void> deletePincode(String id) async {
    try {
      await _dio.delete('/pincodes/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete pincode: ${e.message}');
    }
  }
}
