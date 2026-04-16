import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/fuel_expense.dart';
import '../core/models/list_page_params.dart';
import '../core/models/paginated_list_response.dart';
import '../providers/dio_provider.dart';

final fuelExpenseServiceProvider = Provider<FuelExpenseService>((ref) {
  return FuelExpenseService(ref.watch(dioProvider));
});

final fuelExpensesProvider = FutureProvider<List<FuelExpense>>((ref) async {
  return ref.watch(fuelExpenseServiceProvider).getFuelExpenses();
});

final paginatedFuelExpensesProvider =
    FutureProvider.family<PaginatedListResponse<FuelExpense>, ListPageParams>((
      ref,
      params,
    ) async {
      return ref.watch(fuelExpenseServiceProvider).getPaginatedFuelExpenses(
            page: params.page,
            limit: params.limit,
          );
    });

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

  Future<void> deleteFuelExpense(String id) async {
    try {
      await _dio.delete('/fuel-expenses/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete fuel expense: ${e.message}');
    }
  }
}
