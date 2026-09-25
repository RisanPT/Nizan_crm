import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
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
    } catch (e) {
      throw AppException(e, action: 'load categories');
    }
  }

  Future<ExpenseCategory> create({required String name, String? department}) async {
    try {
      final res = await _dio.post('/expense-categories', data: {
        'name': name,
        if (department != null && department.isNotEmpty) 'department': department,
      });
      return ExpenseCategory.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'add category');
    }
  }

  Future<ExpenseCategory> update(String id, {String? name, bool? active}) async {
    try {
      final res = await _dio.put('/expense-categories/$id', data: {
        'name': ?name,
        'active': ?active,
      });
      return ExpenseCategory.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update category');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/expense-categories/$id');
    } catch (e) {
      throw AppException(e, action: 'delete category');
    }
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
