import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr_shift/data/shift_models.dart';

class ShiftService {
  final Dio _dio;
  ShiftService(this._dio);

  Future<List<Shift>> getShifts() async {
    try {
      final res = await _dio.get('/shifts');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => Shift.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load shifts');
    }
  }

  Future<void> createShift(Map<String, dynamic> body) async {
    try {
      await _dio.post('/shifts', data: body);
    } catch (e) {
      throw AppException(e, action: 'create shift');
    }
  }

  Future<void> updateShift(String id, Map<String, dynamic> body) async {
    try {
      await _dio.put('/shifts/$id', data: body);
    } catch (e) {
      throw AppException(e, action: 'update shift');
    }
  }

  Future<void> deleteShift(String id) async {
    try {
      await _dio.delete('/shifts/$id');
    } catch (e) {
      throw AppException(e, action: 'delete shift');
    }
  }

  Future<List<ShiftAssignment>> getAssignments() async {
    try {
      final res = await _dio.get('/shifts/assignments');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => ShiftAssignment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load roster');
    }
  }

  Future<void> createAssignment({
    required String employeeId,
    required String shiftId,
    required DateTime fromDate,
    DateTime? toDate,
    String note = '',
  }) async {
    try {
      await _dio.post('/shifts/assignments', data: {
        'employeeId': employeeId,
        'shiftId': shiftId,
        'fromDate': fromDate.toIso8601String(),
        if (toDate != null) 'toDate': toDate.toIso8601String(),
        'note': note,
      });
    } catch (e) {
      throw AppException(e, action: 'assign shift');
    }
  }

  Future<void> deleteAssignment(String id) async {
    try {
      await _dio.delete('/shifts/assignments/$id');
    } catch (e) {
      throw AppException(e, action: 'remove assignment');
    }
  }
}

final shiftServiceProvider = Provider<ShiftService>((ref) => ShiftService(ref.watch(dioProvider)));

final shiftsProvider = FutureProvider<List<Shift>>((ref) => ref.watch(shiftServiceProvider).getShifts());

final shiftAssignmentsProvider =
    FutureProvider<List<ShiftAssignment>>((ref) => ref.watch(shiftServiceProvider).getAssignments());
