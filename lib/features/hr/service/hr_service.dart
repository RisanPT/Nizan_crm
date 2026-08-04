import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/hr_models.dart';
import '../../../providers/dio_provider.dart';

final hrServiceProvider = Provider<HrService>((ref) {
  return HrService(ref.watch(dioProvider));
});

// ── Riverpod state ─────────────────────────────────────────────────────────

final hrStaffProvider = FutureProvider<List<HrStaffMember>>((ref) {
  return ref.watch(hrServiceProvider).getStaff();
});

/// Filter state — selected user + month/year
class HrFilter {
  final int? userId;
  final int year;
  final int month;

  const HrFilter({this.userId, required this.year, required this.month});

  HrFilter copyWith({int? userId, int? year, int? month}) => HrFilter(
        userId: userId ?? this.userId,
        year:   year   ?? this.year,
        month:  month  ?? this.month,
      );
}

final hrFilterProvider = StateProvider<HrFilter>((ref) {
  final now = DateTime.now();
  return HrFilter(year: now.year, month: now.month);
});

final hrAttendanceProvider =
    FutureProvider.autoDispose<HrAttendanceResponse?>((ref) async {
  final filter = ref.watch(hrFilterProvider);
  if (filter.userId == null) return null;
  return ref.watch(hrServiceProvider).getAttendance(
        userId: filter.userId!,
        year:   filter.year,
        month:  filter.month,
      );
});

final hrLeavesProvider =
    FutureProvider.autoDispose<List<HrLeave>>((ref) async {
  final filter = ref.watch(hrFilterProvider);
  if (filter.userId == null) return [];
  return ref.watch(hrServiceProvider).getLeaves(
        userId: filter.userId!,
        year:   filter.year,
        month:  filter.month,
      );
});

final hrHolidaysProvider =
    FutureProvider.autoDispose<List<HrHoliday>>((ref) async {
  final filter = ref.watch(hrFilterProvider);
  return ref.watch(hrServiceProvider).getHolidays(
        year:  filter.year,
        month: filter.month,
      );
});

// ── Service class ──────────────────────────────────────────────────────────

class HrService {
  HrService(this._dio);
  final Dio _dio;

  Future<List<HrStaffMember>> getStaff() async {
    try {
      final response = await _dio.get('/hr/staff');
      final json = response.data as Map<String, dynamic>;
      final list = json['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => HrStaffMember.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load HR staff'));
    }
  }

  Future<HrAttendanceResponse> getAttendance({
    required int userId,
    required int year,
    required int month,
  }) async {
    try {
      final response = await _dio.get(
        '/hr/attendance',
        queryParameters: {
          'user_id': userId,
          'year':    year,
          'month':   month,
        },
      );
      return HrAttendanceResponse.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load attendance'));
    }
  }

  Future<List<HrLeave>> getLeaves({
    required int userId,
    required int year,
    required int month,
  }) async {
    try {
      final response = await _dio.get(
        '/hr/leaves',
        queryParameters: {
          'user_id': userId,
          'year':    year,
          'month':   month,
        },
      );
      final json = response.data as Map<String, dynamic>;
      final list = json['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => HrLeave.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load leaves'));
    }
  }

  Future<List<HrHoliday>> getHolidays({
    required int year,
    required int month,
  }) async {
    try {
      final response = await _dio.get(
        '/hr/holidays',
        queryParameters: {'year': year, 'month': month},
      );
      final json = response.data as Map<String, dynamic>;
      final list = json['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => HrHoliday.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load holidays'));
    }
  }

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? fallback;
    }
    return e.message ?? fallback;
  }
}
