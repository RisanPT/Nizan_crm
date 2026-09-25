import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';

class AdminExpenseStats {
  final int totalCount;
  final double totalAmount;
  final double thisMonthAmount;
  final int pendingCount;
  final double pendingAmount;
  final double approvedAmount;
  final Map<String, double> departmentBreakdown;

  const AdminExpenseStats({
    required this.totalCount,
    required this.totalAmount,
    required this.thisMonthAmount,
    required this.pendingCount,
    required this.pendingAmount,
    required this.approvedAmount,
    required this.departmentBreakdown,
  });

  factory AdminExpenseStats.fromJson(Map<String, dynamic> json) {
    final rawDept = json['departmentBreakdown'] as Map<String, dynamic>? ?? {};
    final deptMap = rawDept.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return AdminExpenseStats(
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      thisMonthAmount: (json['thisMonthAmount'] as num?)?.toDouble() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      pendingAmount: (json['pendingAmount'] as num?)?.toDouble() ?? 0,
      approvedAmount: (json['approvedAmount'] as num?)?.toDouble() ?? 0,
      departmentBreakdown: deptMap,
    );
  }
}

class AdminExpenseService {
  final Dio _dio;

  AdminExpenseService(this._dio);

  Future<List<AdminExpense>> getAdminExpenses({
    String? department,
    String? category,
    String? status,
    String? search,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final Map<String, dynamic> query = {};
      if (department != null && department.isNotEmpty && department != 'All') {
        query['department'] = department;
      }
      if (category != null && category.isNotEmpty && category != 'All') {
        query['category'] = category;
      }
      if (status != null && status.isNotEmpty && status != 'All' && status != 'all') {
        query['status'] = status;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (startDate != null) {
        query['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        query['endDate'] = endDate.toIso8601String();
      }

      final response = await _dio.get(
        '/admin-expenses',
        queryParameters: query.isNotEmpty ? query : null,
      );

      final list = response.data as List;
      return list
          .map((item) => AdminExpense.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load administrative expenses');
    }
  }

  Future<AdminExpenseStats> getStats() async {
    try {
      final response = await _dio.get('/admin-expenses/stats');
      return AdminExpenseStats.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load administrative expense statistics');
    }
  }

  Future<AdminExpense> createAdminExpense(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/admin-expenses', data: payload);
      return AdminExpense.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'create administrative expense');
    }
  }

  Future<AdminExpense> updateAdminExpense(
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.put('/admin-expenses/$id', data: payload);
      return AdminExpense.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update administrative expense');
    }
  }

  Future<AdminExpense> verifyAdminExpense(String id, String status) async {
    try {
      final response = await _dio.put(
        '/admin-expenses/$id/verify',
        data: {'status': status},
      );
      return AdminExpense.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update expense status');
    }
  }

  Future<void> deleteAdminExpense(String id) async {
    try {
      await _dio.delete('/admin-expenses/$id');
    } catch (e) {
      throw AppException(e, action: 'delete administrative expense');
    }
  }
}
