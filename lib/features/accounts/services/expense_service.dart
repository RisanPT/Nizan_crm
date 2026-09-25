import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';

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
    } catch (e) {
      throw AppException(e, action: 'load expenses');
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
    String workType = 'bridal',
  }) async {
    try {
      final payload = {
        'employeeId': employeeId,
        if (bookingId != null && bookingId.isNotEmpty) 'bookingId': bookingId,
        'category': category,
        'workType': workType,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
        'receiptImage': receiptImage,
      };
      final response = await _dio.post('/expenses', data: payload);
      return ArtistExpense.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'create expense');
    }
  }

  /// Edits an existing expense. The backend rejects this for an artist once
  /// Accounts has verified or rejected the entry.
  Future<ArtistExpense> updateExpense({
    required String id,
    String? bookingId,
    String? category,
    double? amount,
    DateTime? date,
    String? notes,
    String? receiptImage,
    String? workType,
  }) async {
    try {
      final response = await _dio.put('/expenses/$id', data: {
        'workType': ?workType,
        'bookingId': ?bookingId,
        'category': ?category,
        'amount': ?amount,
        'date': ?date?.toIso8601String(),
        'notes': ?notes,
        'receiptImage': ?receiptImage,
      });
      return ArtistExpense.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update expense');
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
    } catch (e) {
      throw AppException(e, action: 'verify expense');
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _dio.delete('/expenses/$id');
    } catch (e) {
      throw AppException(e, action: 'delete expense');
    }
  }
}
