import 'package:dio/dio.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/core/models/paginated_list_response.dart';
import 'package:nizan_crm/core/error/errors.dart';

class FuelExpenseService {
  final Dio _dio;

  FuelExpenseService(this._dio);

  Future<List<FuelExpense>> getFuelExpenses() async {
    try {
      final response = await _dio.get('/fuel-expenses');
      final data = response.data as List;
      return data
          .map((item) => FuelExpense.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load fuel expenses');
    }
  }

  Future<PaginatedListResponse<FuelExpense>> getPaginatedFuelExpenses({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/fuel-expenses',
        queryParameters: {'page': page, 'limit': limit},
      );
      return PaginatedListResponse.fromJson(
        response.data as Map<String, dynamic>,
        FuelExpense.fromJson,
      );
    } catch (e) {
      throw AppException(e, action: 'load fuel expenses');
    }
  }

  Future<FuelExpense> saveFuelExpense({
    String? id,
    required String vehicleId,
    String? driverId,
    required String category,
    required DateTime date,
    required double odometerKm,
    required double liters,
    required double totalAmount,
    required String paymentMode,
    required String station,
    required String notes,
    String billImage = '',
  }) async {
    try {
      final payload = {
        'vehicleId': vehicleId,
        'driverId': (driverId?.trim().isEmpty ?? true) ? null : driverId,
        'category': category,
        'date': date.toIso8601String(),
        'odometerKm': odometerKm,
        'liters': liters,
        'totalAmount': totalAmount,
        'paymentMode': paymentMode,
        'station': station,
        'notes': notes,
        'billImage': billImage,
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/fuel-expenses/$id', data: payload)
          : await _dio.post('/fuel-expenses', data: payload);

      return FuelExpense.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save fuel expense');
    }
  }

  /// Fleet-manager review action (approve / reject / pending).
  Future<FuelExpense> setStatus(String id, String status) async {
    try {
      final response =
          await _dio.put('/fuel-expenses/$id', data: {'status': status});
      return FuelExpense.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update status');
    }
  }

  Future<void> deleteFuelExpense(String id) async {
    try {
      await _dio.delete('/fuel-expenses/$id');
    } catch (e) {
      throw AppException(e, action: 'delete fuel expense');
    }
  }
}
