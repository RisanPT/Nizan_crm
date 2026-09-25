import 'package:dio/dio.dart';
import 'package:nizan_crm/core/models/paginated_list_response.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/core/error/errors.dart';

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
