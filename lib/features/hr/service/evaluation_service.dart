import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/hr/data/evaluation_models.dart';
import 'package:nizan_crm/features/hr/data/timebox_models.dart';
import 'package:nizan_crm/features/hr/service/timebox_service.dart';
import 'package:nizan_crm/core/error/errors.dart';

typedef EvalPeriod = ({int year, int month});

class EvaluationService {
  final Dio _dio;
  EvaluationService(this._dio);

  Future<List<EmployeeEvaluation>> getEvaluations({int? month, int? year}) async {
    try {
      final res = await _dio.get('/performance', queryParameters: {
        'month': ?month,
        'year': ?year,
      });
      return (res.data as List)
          .map((e) => EmployeeEvaluation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load evaluations');
    }
  }

  Future<List<EmployeeEvaluation>> getEmployeeEvaluations(String employeeId) async {
    try {
      final res = await _dio.get('/performance/employee/$employeeId');
      return (res.data as List)
          .map((e) => EmployeeEvaluation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load employee evaluations');
    }
  }

  Future<EmployeeEvaluation> upsert({
    required String employeeId,
    required int month,
    required int year,
    required double learnability,
    required double responsibility,
    required double punctuality,
    required double commitment,
    required double leadership,
    String punctualitySource = 'manual',
    String notes = '',
  }) async {
    try {
      final res = await _dio.post('/performance', data: {
        'employeeId': employeeId,
        'month': month,
        'year': year,
        'learnability': learnability,
        'responsibility': responsibility,
        'punctuality': punctuality,
        'commitment': commitment,
        'leadership': leadership,
        'punctualitySource': punctualitySource,
        'notes': notes,
      });
      return EmployeeEvaluation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save evaluation');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/performance/$id');
    } catch (e) {
      throw AppException(e, action: 'delete evaluation');
    }
  }

}

final evaluationServiceProvider =
    Provider<EvaluationService>((ref) => EvaluationService(ref.watch(dioProvider)));

/// Selected evaluation period for the HR Evaluation screen.
final evalPeriodProvider = StateProvider<EvalPeriod>((ref) {
  final n = DateTime.now();
  return (year: n.year, month: n.month);
});

/// Evaluations for the selected period (whole org / dept — backend scopes).
final evaluationsProvider = FutureProvider<List<EmployeeEvaluation>>((ref) async {
  final p = ref.watch(evalPeriodProvider);
  return ref.watch(evaluationServiceProvider).getEvaluations(month: p.month, year: p.year);
});

/// One employee's evaluation history (for the profile scorecard + trend).
final employeeEvaluationsProvider =
    FutureProvider.family<List<EmployeeEvaluation>, String>((ref, employeeId) async {
  return ref.watch(evaluationServiceProvider).getEmployeeEvaluations(employeeId);
});

/// Attendance summary for a specific period — used to auto-prefill Punctuality
/// in the evaluate dialog (matched to the employee by name).
final periodAttendanceProvider =
    FutureProvider.family<List<AttendanceSummaryRow>, EvalPeriod>((ref, p) async {
  final from = '${p.year}-${p.month.toString().padLeft(2, '0')}-01';
  final last = DateTime(p.year, p.month + 1, 0).day;
  final to =
      '${p.year}-${p.month.toString().padLeft(2, '0')}-${last.toString().padLeft(2, '0')}';
  return ref.watch(timeboxServiceProvider).getSummary(from, to);
});
