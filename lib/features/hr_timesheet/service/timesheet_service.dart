import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr_timesheet/data/timesheet_models.dart';

class TimesheetService {
  final Dio _dio;
  TimesheetService(this._dio);

  List<Timesheet> _list(dynamic data) {
    final raw = data is List ? data : const [];
    return raw.map((e) => Timesheet.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Timesheet>> getMine() async {
    try {
      final res = await _dio.get('/timesheets/mine');
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load my timesheets');
    }
  }

  Future<List<Timesheet>> getRequests({String? status}) async {
    try {
      final res = await _dio.get('/timesheets/requests', queryParameters: {
        'status': ?status,
      });
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load timesheets');
    }
  }

  Future<Timesheet> save({
    required DateTime periodStart,
    required String periodLabel,
    String periodType = 'weekly',
    required List<TimesheetEntry> entries,
  }) async {
    try {
      final res = await _dio.post('/timesheets', data: {
        'periodStart': periodStart.toIso8601String(),
        'periodLabel': periodLabel,
        'periodType': periodType,
        'entries': entries.where((e) => e.hours > 0 || e.project.isNotEmpty).map((e) => e.toJson()).toList(),
      });
      return Timesheet.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save timesheet');
    }
  }

  Future<void> submit(String id) async {
    try {
      await _dio.post('/timesheets/$id/submit');
    } catch (e) {
      throw AppException(e, action: 'submit timesheet');
    }
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete('/timesheets/$id');
    } catch (e) {
      throw AppException(e, action: 'delete timesheet');
    }
  }
}

final timesheetServiceProvider =
    Provider<TimesheetService>((ref) => TimesheetService(ref.watch(dioProvider)));

final myTimesheetsProvider =
    FutureProvider<List<Timesheet>>((ref) => ref.watch(timesheetServiceProvider).getMine());

final timesheetRequestsProvider =
    FutureProvider<List<Timesheet>>((ref) => ref.watch(timesheetServiceProvider).getRequests());
