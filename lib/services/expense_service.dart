import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/artist_expense.dart';
import '../providers/dio_provider.dart';

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(ref.watch(dioProvider));
});

/// All artist expenses (accounts-team view).
final expensesProvider = FutureProvider<List<ArtistExpense>>((ref) async {
  return ref.watch(expenseServiceProvider).getExpenses();
});

/// Expenses scoped to a single artist.
final artistExpensesProvider =
    FutureProvider.family<List<ArtistExpense>, String>((ref, employeeId) async {
  return ref
      .watch(expenseServiceProvider)
      .getExpenses(employeeId: employeeId);
});

class ExpenseService {
  final Dio _dio;

  ExpenseService(this._dio);

  Future<List<ArtistExpense>> getExpenses({
    String? status,
    String? employeeId,
    String? bookingId,
  }) async {
    try {
      final Map<String, dynamic> query = {};
      if (status != null) query['status'] = status;
      if (employeeId != null) query['employeeId'] = employeeId;
      if (bookingId != null) query['bookingId'] = bookingId;

      final response = await _dio.get(
        '/expenses',
        queryParameters: query.isNotEmpty ? query : null,
      );
      final data = response.data as List;
      return data
          .map((item) => ArtistExpense.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load expenses: ${e.message}');
    }
  }

  Future<ArtistExpense> createExpense({
    required String employeeId,
    String? bookingId,
    required String category,
    required double amount,
    required DateTime date,
    String notes = '',
    String receiptImage = '',
  }) async {
    try {
      final payload = {
        'employeeId': employeeId,
        if (bookingId != null && bookingId.isNotEmpty) 'bookingId': bookingId,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
        'receiptImage': receiptImage,
      };
      final response = await _dio.post('/expenses', data: payload);
      return ArtistExpense.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to create expense: ${e.message}',
      );
    }
  }

  Future<ArtistExpense> verifyExpense({
    required String id,
    required String status, // 'verified' | 'rejected'
    required String verifiedBy,
  }) async {
    try {
      final response = await _dio.put(
        '/expenses/$id/verify',
        data: {'status': status, 'verifiedBy': verifiedBy},
      );
      return ArtistExpense.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to verify expense: ${e.message}');
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _dio.delete('/expenses/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete expense: ${e.message}');
    }
  }
}
