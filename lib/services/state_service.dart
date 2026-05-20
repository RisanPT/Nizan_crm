import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/geographic_state.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../providers/dio_provider.dart';

final stateServiceProvider = Provider<StateService>((ref) {
  return StateService(ref.watch(dioProvider));
});

final statesProvider = FutureProvider<List<GeographicState>>((ref) async {
  return ref.watch(stateServiceProvider).getStates(activeOnly: true);
});

final paginatedStatesProvider = FutureProvider.family<
    PaginatedListResponse<GeographicState>, ListPageParams>((ref, params) async {
  return ref.watch(stateServiceProvider).getPaginatedStates(
        page: params.page,
        limit: params.limit,
      );
});

class StateService {
  final Dio _dio;

  StateService(this._dio);

  Future<List<GeographicState>> getStates({
    bool activeOnly = false,
    String? zoneId,
  }) async {
    try {
      final response = await _dio.get(
        '/states',
        queryParameters: {
          if (activeOnly) 'active': 'true',
          if (zoneId != null && zoneId.isNotEmpty) 'zoneId': zoneId,
        },
      );
      final data = response.data as List;
      return data
          .map((item) => GeographicState.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load states: ${e.message}');
    }
  }

  Future<PaginatedListResponse<GeographicState>> getPaginatedStates({
    int page = 1,
    int limit = 20,
    bool activeOnly = false,
    String? zoneId,
  }) async {
    try {
      final response = await _dio.get(
        '/states',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (activeOnly) 'active': 'true',
          if (zoneId != null && zoneId.isNotEmpty) 'zoneId': zoneId,
        },
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        GeographicState.fromJson,
      );
    } on DioException catch (e) {
      throw Exception('Failed to load states: ${e.message}');
    }
  }

  Future<GeographicState> saveState({
    String? id,
    required String name,
    required String zoneId,
    required String status,
  }) async {
    try {
      final payload = {
        if (id != null && id.isNotEmpty) 'id': id,
        'name': name,
        'zoneId': zoneId,
        'status': status,
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/states/$id', data: payload)
          : await _dio.post('/states', data: payload);

      return GeographicState.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to save state: ${e.message}');
    }
  }

  Future<void> deleteState(String id) async {
    try {
      await _dio.delete('/states/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete state: ${e.message}');
    }
  }
}
