import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/leave/data/leave_models.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';

class LeaveService {
  final Dio _dio;
  LeaveService(this._dio);

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) f) {
    final raw = data is List ? data : const [];
    return raw.map((e) => f(e as Map<String, dynamic>)).toList();
  }

  Future<List<LeaveType>> getTypes() async {
    try {
      final res = await _dio.get('/leave/types');
      return _list(res.data, LeaveType.fromJson);
    } catch (e) {
      throw AppException(e, action: 'load leave types');
    }
  }

  /// Whether the caller may edit leave types / holidays (HR-wide users only).
  Future<bool> canEditMaster() async => (await _access())['canEdit'] == true;

  /// Leave desk (admin + hr role): sees everyone's leave requests and
  /// approves/rejects them. The server decides.
  Future<bool> canDecide() async => (await _access())['canDecide'] == true;

  Future<Map> _access() async {
    try {
      final res = await _dio.get('/leave/types/access');
      final data = res.data;
      return data is Map ? data : const {};
    } catch (_) {
      return const {};
    }
  }

  /// Create (id empty) or update a leave type.
  Future<LeaveType> saveType({
    String id = '',
    required String name,
    String code = '',
    double annualQuota = 0,
    bool paid = true,
    bool carryForward = false,
    double carryForwardMax = 0,
    bool active = true,
  }) async {
    final body = {
      'name': name,
      'code': code,
      'annualQuota': annualQuota,
      'paid': paid,
      'carryForward': carryForward,
      'carryForwardMax': carryForwardMax,
      'active': active,
    };
    try {
      final res = id.isEmpty
          ? await _dio.post('/leave/types', data: body)
          : await _dio.put('/leave/types/$id', data: body);
      return LeaveType.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save leave type');
    }
  }

  Future<void> seedTypes() async {
    try {
      await _dio.post('/leave/types/seed');
    } catch (e) {
      throw AppException(e, action: 'seed leave types');
    }
  }

  Future<List<LeaveBalance>> getBalances({String? employeeId, int? year}) async {
    try {
      final res = await _dio.get('/leave/balances', queryParameters: {
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        'year': ?year,
      });
      return _list(res.data, LeaveBalance.fromJson);
    } catch (e) {
      throw AppException(e, action: 'load leave balances');
    }
  }

  Future<List<LeaveRequest>> getMyLeave({int? year}) async {
    try {
      final res = await _dio.get('/leave/mine', queryParameters: {
        'year': ?year,
      });
      return _list(res.data, LeaveRequest.fromJson);
    } catch (e) {
      throw AppException(e, action: 'load my leave');
    }
  }

  Future<List<LeaveRequest>> getRequests({int? month, int? year, String? status}) async {
    try {
      final res = await _dio.get('/leave/requests', queryParameters: {
        'month': ?month,
        'year': ?year,
        if (status != null && status.isNotEmpty && status != 'all') 'status': status,
      });
      return _list(res.data, LeaveRequest.fromJson);
    } catch (e) {
      throw AppException(e, action: 'load leave requests');
    }
  }

  Future<LeaveRequest> apply({
    String? employeeId,
    String? leaveTypeId,
    required DateTime from,
    required DateTime to,
    String halfDay = 'none',
    String reason = '',
  }) async {
    try {
      final res = await _dio.post('/leave/apply', data: {
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        if (leaveTypeId != null && leaveTypeId.isNotEmpty) 'leaveTypeId': leaveTypeId,
        'fromDate': '${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}',
        'toDate': '${to.year.toString().padLeft(4, '0')}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}',
        'halfDay': halfDay,
        'reason': reason,
      });
      return LeaveRequest.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'apply for leave');
    }
  }

  /// Cancel a pending request, or an approved one (owner before it starts;
  /// a manager in scope any time).
  Future<void> cancel(String id, {String reason = ''}) async {
    try {
      await _dio.post('/leave/$id/cancel', data: {if (reason.isNotEmpty) 'reason': reason});
    } catch (e) {
      throw AppException(e, action: 'cancel leave');
    }
  }

  Future<List<Holiday>> getHolidays({int? year}) async {
    try {
      final res = await _dio.get('/leave/holidays', queryParameters: {
        'year': ?year,
      });
      return _list(res.data, Holiday.fromJson);
    } catch (e) {
      throw AppException(e, action: 'load holidays');
    }
  }

  Future<Holiday> createHoliday({
    required String name,
    required DateTime date,
    String type = 'national',
  }) async {
    try {
      final res = await _dio.post('/leave/holidays', data: {
        'name': name,
        'date': date.toIso8601String(),
        'type': type,
      });
      return Holiday.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'add holiday');
    }
  }

  Future<void> deleteHoliday(String id) async {
    try {
      await _dio.delete('/leave/holidays/$id');
    } catch (e) {
      throw AppException(e, action: 'delete holiday');
    }
  }

  Future<List<CompOff>> getCompOffs({String? employeeId}) async {
    try {
      final res = await _dio.get('/leave/comp-offs', queryParameters: {
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
      });
      return _list(res.data, CompOff.fromJson);
    } catch (e) {
      throw AppException(e, action: 'load comp-offs');
    }
  }

  /// Re-send an approved/rejected Timebox leave's decision to Timebox.
  /// Returns true when Timebox accepted it.
  Future<bool> retryCallback(String id) async {
    try {
      final res = await _dio.post('/leave/$id/retry-callback');
      final data = res.data;
      return data is Map && data['result'] is Map && data['result']['sent'] == true;
    } catch (e) {
      throw AppException(e, action: 'send the decision to Timebox');
    }
  }
}


final leaveServiceProvider =
    Provider<LeaveService>((ref) => LeaveService(ref.watch(dioProvider)));

/// The signed-in user. Every leave provider watches it, so logging in as
/// someone else reloads leave data and access instead of showing the last
/// user's cached lists.
String? _who(Ref ref) => ref.watch(authSessionProvider.select((s) => s?.userId));

/// Selected year across the Leave screen.
final leaveYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// When the Leave screen last reloaded its data (drives "Updated … ago").
final leaveLastSyncProvider = StateProvider<DateTime?>((ref) => null);

final leaveTypesProvider = FutureProvider<List<LeaveType>>((ref) {
  _who(ref);
  return ref.watch(leaveServiceProvider).getTypes();
});

/// True for HR-wide users, who may edit leave types and holidays.
final leaveMasterAccessProvider = FutureProvider<bool>((ref) {
  _who(ref);
  return ref.watch(leaveServiceProvider).canEditMaster();
});

/// Leave desk: admin + hr role. Sees everyone's leave and decides it.
final leaveDeskAccessProvider = FutureProvider<bool>((ref) {
  _who(ref);
  return ref.watch(leaveServiceProvider).canDecide();
});

final myLeaveProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  _who(ref);
  final y = ref.watch(leaveYearProvider);
  return ref.watch(leaveServiceProvider).getMyLeave(year: y);
});

final myBalancesProvider = FutureProvider<List<LeaveBalance>>((ref) async {
  _who(ref);
  final y = ref.watch(leaveYearProvider);
  return ref.watch(leaveServiceProvider).getBalances(year: y);
});

/// One employee's balances (leave desk: shown next to a pending request).
final employeeBalancesProvider =
    FutureProvider.family<List<LeaveBalance>, String>((ref, employeeId) async {
  _who(ref);
  final y = ref.watch(leaveYearProvider);
  return ref.watch(leaveServiceProvider).getBalances(employeeId: employeeId, year: y);
});

final leaveRequestsProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  _who(ref);
  final y = ref.watch(leaveYearProvider);
  return ref.watch(leaveServiceProvider).getRequests(year: y);
});

final holidaysProvider = FutureProvider<List<Holiday>>((ref) async {
  _who(ref);
  final y = ref.watch(leaveYearProvider);
  return ref.watch(leaveServiceProvider).getHolidays(year: y);
});
