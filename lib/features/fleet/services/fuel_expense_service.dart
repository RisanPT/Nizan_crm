import 'package:dio/dio.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/core/models/paginated_list_response.dart';

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
    } on DioException catch (e) {
      throw Exception('Failed to load fuel expenses: ${e.message}');
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
    } on DioException catch (e) {
      throw Exception('Failed to load fuel expenses: ${e.message}');
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
    } on DioException catch (e) {
      String errorMessage = 'Failed to save fuel expense: ${e.message}';
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        errorMessage = data['message'].toString();
      }
      throw Exception(errorMessage);
    }
  }

  /// Fleet-manager review action (approve / reject / pending).
  Future<FuelExpense> setStatus(String id, String status) async {
    try {
      final response =
          await _dio.put('/fuel-expenses/$id', data: {'status': status});
      return FuelExpense.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception((data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'Failed to update status: ${e.message}');
    }
  }

  Future<void> deleteFuelExpense(String id) async {
    try {
      await _dio.delete('/fuel-expenses/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete fuel expense: ${e.message}');
    }
  }
}
