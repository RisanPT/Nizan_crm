import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/accounts/data/expense_category.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class ExpenseCategoryService {
  final Dio _dio;
  ExpenseCategoryService(this._dio);

  Future<List<ExpenseCategory>> list({String? department}) async {
    try {
      final res = await _dio.get(
        '/expense-categories',
        queryParameters: {
          if (department != null && department.isNotEmpty && department != 'All')
            'department': department,
        },
      );
      return (res.data as List)
          .map((e) => ExpenseCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load categories'));
    }
  }

  Future<ExpenseCategory> create({required String name, String? department}) async {
    try {
      final res = await _dio.post('/expense-categories', data: {
        'name': name,
        if (department != null && department.isNotEmpty) 'department': department,
      });
      return ExpenseCategory.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to add category'));
    }
  }

  Future<ExpenseCategory> update(String id, {String? name, bool? active}) async {
    try {
      final res = await _dio.put('/expense-categories/$id', data: {
        'name': ?name,
        'active': ?active,
      });
      return ExpenseCategory.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to update category'));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/expense-categories/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to delete category'));
    }
  }

  String _msg(DioException e, String fallback) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    return '$fallback: ${e.message ?? ''}'.trim();
  }
}

final expenseCategoryServiceProvider = Provider<ExpenseCategoryService>(
  (ref) => ExpenseCategoryService(ref.watch(dioProvider)),
);

/// Categories for a department. Pass the department name; an empty string lets
/// the backend infer the caller's own department (a department head).
final expenseCategoriesProvider =
    FutureProvider.family<List<ExpenseCategory>, String>((ref, department) async {
  final service = ref.watch(expenseCategoryServiceProvider);
  return service.list(department: department);
});
