import 'package:dio/dio.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense_page.dart';
import 'package:nizan_crm/core/models/paginated_list_response.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/money_account_picker.dart';

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

  /// ACCOUNTS: one filtered, sorted page, with totals for the whole filtered set
  /// and each expense's day works (client, artist, share) + km check. The fleet
  /// screens use [getFuelExpenses] and never get artist details.
  Future<FuelExpensePage> getFuelExpensePage(FuelExpenseQuery query) async {
    try {
      final response = await _dio.get('/fuel-expenses', queryParameters: query.toParams());
      return FuelExpensePage.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load fuel expenses');
    }
  }

  /// ACCOUNTS: every expense matching [query] (the server caps it), for the export.
  Future<FuelExpenseExport> exportFuelExpenses(FuelExpenseQuery query) async {
    try {
      final response = await _dio.get('/fuel-expenses', queryParameters: query.toParams(export: true));
      final data = response.data as Map<String, dynamic>;
      return FuelExpenseExport(
        [for (final e in (data['items'] as List? ?? const [])) FuelExpense.fromJson((e as Map).cast<String, dynamic>())],
        (data['totalItems'] as num?)?.toInt() ?? 0,
        data['truncated'] == true,
      );
    } catch (e) {
      throw AppException(e, action: 'export fuel expenses');
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
    // The work this expense was for. Leave both alone to keep an existing link;
    // [clearWork] turns it into a whole-day expense (shared across the day's works).
    String? bookingId,
    bool clearWork = false,
  }) async {
    try {
      final payload = <String, dynamic>{
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
        ...(clearWork
            ? {'bookingId': null}
            : bookingId != null
                ? {'bookingId': bookingId}
                : const <String, dynamic>{}),
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
  /// [money] = which bank / cash account paid it (approval popup).
  Future<FuelExpense> setStatus(String id, String status, {MoneyChoice? money}) async {
    try {
      final response = await _dio
          .put('/fuel-expenses/$id', data: {'status': status, ...?money?.toJson()});
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
