import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/budget.dart';
import '../providers/dio_provider.dart';

final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService(ref.watch(dioProvider));
});

final currentBudgetProvider = FutureProvider<Budget?>((ref) async {
  final service = ref.watch(budgetServiceProvider);
  final now = DateTime.now();
  final budgets = await service.getBudgets(month: now.month, year: now.year);
  if (budgets.isNotEmpty) {
    return budgets.first; // Returning 'General' or first budget found
  }
  return null;
});

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
