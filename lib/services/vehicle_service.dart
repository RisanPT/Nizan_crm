import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';

import '../providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';

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
    } catch (e) {
      throw AppException(e, action: 'load vehicles');
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
    } catch (e) {
      throw AppException(e, action: 'load vehicles');
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
    required String ownershipType,
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
        'ownershipType': ownershipType,
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/vehicles/$id', data: payload)
          : await _dio.post('/vehicles', data: payload);

      return Vehicle.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save vehicle');
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      await _dio.delete('/vehicles/$id');
    } catch (e) {
      throw AppException(e, action: 'delete vehicle');
    }
  }
}
