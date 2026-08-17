import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/error_message.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/data/dept_report.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class MonthEndService {
  final Dio _dio;
  MonthEndService(this._dio);

  Future<MonthEndReview> getReview(int month, int year) async {
    try {
      final res = await _dio.get('/reports/month-end',
          queryParameters: {'month': month, 'year': year});
      return MonthEndReview.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load the month-end review'));
    }
  }

  Future<MonthlyTarget> getTarget(int month, int year) async {
    try {
      final res = await _dio.get('/reports/targets',
          queryParameters: {'month': month, 'year': year});
      return MonthlyTarget.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load targets'));
    }
  }

  Future<MonthlyTarget> saveTarget(MonthlyTarget target) async {
    try {
      final res = await _dio.put('/reports/targets', data: target.toJson());
      return MonthlyTarget.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to save targets'));
    }
  }

  // ── CEO decisions / action items ──
  Future<List<CeoDecision>> getDecisions({int? month, int? year, bool openOnly = false}) async {
    try {
      final res = await _dio.get('/reports/decisions', queryParameters: {
        if (openOnly) 'scope': 'open',
        if (!openOnly && month != null) 'month': month,
        if (!openOnly && year != null) 'year': year,
      });
      return (res.data as List).map((e) => CeoDecision.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load decisions'));
    }
  }

  Future<CeoDecision> saveDecision(CeoDecision d) async {
    try {
      final res = d.id.isEmpty
          ? await _dio.post('/reports/decisions', data: d.toJson())
          : await _dio.put('/reports/decisions/${d.id}', data: d.toJson());
      return CeoDecision.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to save decision'));
    }
  }

  Future<void> deleteDecision(String id) async {
    try {
      await _dio.delete('/reports/decisions/$id');
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to delete decision'));
    }
  }

  // ── Departmental month-end reviews ──
  Future<List<DeptInfo>> listDepartments() async {
    try {
      final res = await _dio.get('/reports/departments');
      return (res.data as List).map((e) => DeptInfo.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load departments'));
    }
  }

  Future<DeptReport> getDepartmentReport(String dept, int month, int year) async {
    try {
      final res = await _dio.get('/reports/department/$dept',
          queryParameters: {'month': month, 'year': year});
      return DeptReport.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load the report'));
    }
  }

  Future<void> saveDepartmentReport(
    String dept, {
    required int month,
    required int year,
    required Map<String, dynamic> values,
    required Map<String, dynamic> targets,
    required List<DeptAllocation> allocations,
    required List<DeptActionItem> actionItems,
    required String notes,
  }) async {
    try {
      await _dio.put('/reports/department/$dept', data: {
        'month': month,
        'year': year,
        'values': values,
        'targets': targets,
        'allocations': allocations.map((a) => a.toJson()).toList(),
        'actionItems': actionItems.map((a) => a.toJson()).toList(),
        'notes': notes,
      });
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to save the report'));
    }
  }
}

final monthEndServiceProvider = Provider<MonthEndService>((ref) {
  return MonthEndService(ref.watch(dioProvider));
});

/// Key for the month/year the review + planning screens are viewing.
typedef Period = ({int month, int year});

final monthEndReviewProvider =
    FutureProvider.family<MonthEndReview, Period>((ref, p) async {
  return ref.watch(monthEndServiceProvider).getReview(p.month, p.year);
});

final monthlyTargetProvider =
    FutureProvider.family<MonthlyTarget, Period>((ref, p) async {
  return ref.watch(monthEndServiceProvider).getTarget(p.month, p.year);
});

/// Decisions for a specific meeting month.
final decisionsProvider =
    FutureProvider.family<List<CeoDecision>, Period>((ref, p) async {
  return ref.watch(monthEndServiceProvider).getDecisions(month: p.month, year: p.year);
});

/// Every still-open decision across all months — the running CEO to-do list.
final openDecisionsProvider = FutureProvider<List<CeoDecision>>((ref) async {
  return ref.watch(monthEndServiceProvider).getDecisions(openOnly: true);
});

/// The 7 departments (for the hub / picker).
final departmentsListProvider = FutureProvider<List<DeptInfo>>((ref) async {
  return ref.watch(monthEndServiceProvider).listDepartments();
});

typedef DeptPeriod = ({String dept, int month, int year});

final departmentReportProvider =
    FutureProvider.family<DeptReport, DeptPeriod>((ref, p) async {
  return ref.watch(monthEndServiceProvider).getDepartmentReport(p.dept, p.month, p.year);
});
