import 'package:dio/dio.dart';
import 'package:nizan_crm/features/accounts/data/budget.dart';

class BudgetService {
  final Dio _dio;

  BudgetService(this._dio);

  Future<List<Budget>> getBudgets({int? month, int? year, String? category}) async {
    try {
      final Map<String, dynamic> query = {};
      if (month != null) query['month'] = month;
      if (year != null) query['year'] = year;
      if (category != null) query['category'] = category;

      final response = await _dio.get(
        '/budgets',
        queryParameters: query.isNotEmpty ? query : null,
      );
      final data = response.data as List;
      return data.map((item) => Budget.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load budgets: ${e.message}');
    }
  }

  Future<Budget> setBudget({
    required int month,
    required int year,
    String category = 'General',
    required double amount,
  }) async {
    try {
      final payload = {
        'month': month,
        'year': year,
        'category': category,
        'amount': amount,
      };
      final response = await _dio.post('/budgets', data: payload);
      return Budget.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to set budget: ${e.message}',
      );
    }
  }
}
