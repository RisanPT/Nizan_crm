import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../core/models/vehicle.dart';
import '../providers/dio_provider.dart';

final vehicleServiceProvider = Provider<VehicleService>((ref) {
  return VehicleService(ref.watch(dioProvider));
});

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  return ref.watch(vehicleServiceProvider).getVehicles();
});

final paginatedVehiclesProvider =
    FutureProvider.family<PaginatedListResponse<Vehicle>, ListPageParams>((
      ref,
      params,
    ) async {
      return ref.watch(vehicleServiceProvider).getPaginatedVehicles(
            page: params.page,
            limit: params.limit,
          );
    });

class VehicleService {
  final Dio _dio;

  VehicleService(this._dio);

  Future<List<Vehicle>> getVehicles() async {
    try {
      final response = await _dio.get('/vehicles');
      final data = response.data as List;
      return data
          .map((item) => Vehicle.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load vehicles: ${e.message}');
    }
  }

  Future<PaginatedListResponse<Vehicle>> getPaginatedVehicles({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/vehicles',
        queryParameters: {'page': page, 'limit': limit},
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        Vehicle.fromJson,
      );
    } on DioException catch (e) {
      throw Exception('Failed to load vehicles: ${e.message}');
    }
  }

  Future<Vehicle> saveVehicle({
    String? id,
    required String name,
    required String registrationNumber,
    required String type,
    required String brand,
    required String fuelType,
    required String status,
    required String notes,
    String? driverId,
  }) async {
    try {
      final payload = {
        'name': name,
        'registrationNumber': registrationNumber,
        'type': type,
        'brand': brand,
        'fuelType': fuelType,
        'status': status,
        'notes': notes,
        'driverId': (driverId?.trim().isEmpty ?? true) ? null : driverId,
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/vehicles/$id', data: payload)
          : await _dio.post('/vehicles', data: payload);

      return Vehicle.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      String errorMessage = 'Failed to save vehicle: ${e.message}';
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        errorMessage = data['message'].toString();
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      await _dio.delete('/vehicles/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete vehicle: ${e.message}');
    }
  }
}
