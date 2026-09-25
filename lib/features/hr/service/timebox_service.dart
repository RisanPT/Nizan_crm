import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../providers/dio_provider.dart';
import '../data/timebox_models.dart';
import 'package:nizan_crm/core/error/errors.dart';

// ── Service ───────────────────────────────────────────────────────────────────

final timeboxServiceProvider = Provider<TimeboxService>((ref) {
  return TimeboxService(ref.watch(dioProvider));
});

class TimeboxService {
  TimeboxService(this._dio);
  final Dio _dio;


  Future<List<TimeboxEmployee>> getEmployees() async {
    try {
      final res = await _dio.get('/timebox/employees');
      final list = (res.data as Map)['data'] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(TimeboxEmployee.fromJson)
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load employees');
    }
  }

  Future<List<AttendanceSummaryRow>> getSummary(String from, String to) async {
    try {
      final res = await _dio.get('/timebox/attendance-summary',
          queryParameters: {'from': from, 'to': to});
      final list = (res.data as Map)['data'] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AttendanceSummaryRow.fromJson)
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load attendance summary');
    }
  }

  Future<List<AttendanceRecord>> getAttendance({
    required int employeeId,
    required String from,
    required String to,
  }) async {
    try {
      final res = await _dio.get('/timebox/attendance', queryParameters: {
        'employee_id': employeeId,
        'from': from,
        'to': to,
      });
      final list = (res.data as Map)['data'] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AttendanceRecord.fromJson)
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load attendance');
    }
  }

  Future<List<TimeboxDay>> getDays({
    required int employeeId,
    required String from,
    required String to,
  }) async {
    try {
      final res = await _dio.get('/timebox/days', queryParameters: {
        'employee_id': employeeId,
        'from': from,
        'to': to,
      });
      final list = (res.data as Map)['data'] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(TimeboxDay.fromJson)
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load timebox days');
    }
  }

  Future<PayrollPreview> getPayrollPreview(String from, String to) async {
    try {
      final res = await _dio.get('/timebox/payroll-preview',
          queryParameters: {'from': from, 'to': to});
      return PayrollPreview.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load payroll preview');
    }
  }

  Future<String> generatePayroll({
    required String from,
    required String to,
    bool dryRun = false,
  }) async {
    try {
      final res = await _dio.post('/timebox/generate-payroll', data: {
        'from': from,
        'to': to,
        'dryRun': dryRun,
      });
      return (res.data as Map)['message'] as String? ?? 'Done';
    } catch (e) {
      throw AppException(e, action: 'generate payroll');
    }
  }

  /// Sync Timebox employee IDs back onto CRM Employee records so future
  /// payroll matching uses stable integer IDs instead of email/name.
  Future<TimeboxSyncResult> syncEmployees() async {
    try {
      final res = await _dio.post('/timebox/sync-employees');
      return TimeboxSyncResult.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'sync Timebox employees');
    }
  }
}

// ── Month selection state (drives summary + payroll) ──────────────────────────

class TimeboxMonth {
  final int year;
  final int month; // 1-12
  const TimeboxMonth(this.year, this.month);

  /// First day of the month, YYYY-MM-DD.
  String get from =>
      '$year-${month.toString().padLeft(2, '0')}-01';

  /// Last day of the month, YYYY-MM-DD.
  String get to {
    final last = DateTime(year, month + 1, 0).day;
    return '$year-${month.toString().padLeft(2, '0')}-${last.toString().padLeft(2, '0')}';
  }

  TimeboxMonth get prev => month == 1 ? TimeboxMonth(year - 1, 12) : TimeboxMonth(year, month - 1);
  TimeboxMonth get next => month == 12 ? TimeboxMonth(year + 1, 1) : TimeboxMonth(year, month + 1);
}

final timeboxMonthProvider = StateProvider<TimeboxMonth>((ref) {
  final now = DateTime.now();
  return TimeboxMonth(now.year, now.month);
});

// ── Derived providers ─────────────────────────────────────────────────────────

final timeboxEmployeesProvider =
    FutureProvider<List<TimeboxEmployee>>((ref) {
  return ref.watch(timeboxServiceProvider).getEmployees();
});

final attendanceSummaryProvider =
    FutureProvider.autoDispose<List<AttendanceSummaryRow>>((ref) {
  final m = ref.watch(timeboxMonthProvider);
  return ref.watch(timeboxServiceProvider).getSummary(m.from, m.to);
});

final payrollPreviewProvider =
    FutureProvider.autoDispose<PayrollPreview>((ref) {
  final m = ref.watch(timeboxMonthProvider);
  return ref.watch(timeboxServiceProvider).getPayrollPreview(m.from, m.to);
});

/// Per-employee daily attendance for the selected month.
final employeeAttendanceProvider = FutureProvider.autoDispose
    .family<List<AttendanceRecord>, int>((ref, employeeId) {
  final m = ref.watch(timeboxMonthProvider);
  return ref
      .watch(timeboxServiceProvider)
      .getAttendance(employeeId: employeeId, from: m.from, to: m.to);
});

/// Per-employee Timebox planner days for the selected month.
final employeeDaysProvider = FutureProvider.autoDispose
    .family<List<TimeboxDay>, int>((ref, employeeId) {
  final m = ref.watch(timeboxMonthProvider);
  return ref
      .watch(timeboxServiceProvider)
      .getDays(employeeId: employeeId, from: m.from, to: m.to);
});
