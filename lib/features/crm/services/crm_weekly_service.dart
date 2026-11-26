import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/crm/data/crm_weekly_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// A booking's CRM care and the CRM weekly report — backend /api/crm/care*, /api/crm/weekly* (routes/crmRoutes.js).
class CrmWeeklyService {
  final Dio _dio;
  CrmWeeklyService(this._dio);

  Map<String, dynamic> _body(Response res) => (res.data as Map).cast<String, dynamic>();

  Future<CrmCare> care(String bookingId) async {
    try {
      return CrmCare.fromJson(_body(await _dio.get('/crm/care/$bookingId')));
    } catch (e) {
      throw AppException(e, action: 'load the client\'s care notes');
    }
  }

  /// Ticks (or, with [done] false, unticks) "verified with the client" for a work day.
  Future<CrmCare> verify(String bookingId, String day, {bool done = true, String note = ''}) async {
    try {
      return CrmCare.fromJson(_body(await _dio.put('/crm/care/$bookingId/verify', data: {'day': day, 'done': done, 'note': note})));
    } catch (e) {
      throw AppException(e, action: 'mark the work verified');
    }
  }

  /// Ticks (or unticks) "photos collected" for a work day that has happened.
  Future<CrmCare> photos(String bookingId, String day, {bool done = true}) async {
    try {
      return CrmCare.fromJson(_body(await _dio.put('/crm/care/$bookingId/photos', data: {'day': day, 'done': done})));
    } catch (e) {
      throw AppException(e, action: 'mark the photos collected');
    }
  }

  Future<CrmCare> setMedical(String bookingId, List<String> conditions, String note) async {
    try {
      return CrmCare.fromJson(_body(await _dio.put('/crm/care/$bookingId/medical', data: {'conditions': conditions, 'note': note})));
    } catch (e) {
      throw AppException(e, action: 'save the medical notes');
    }
  }

  Future<CrmCare> addEmergency(String bookingId, {required String day, required String what, String action = ''}) async {
    try {
      return CrmCare.fromJson(_body(await _dio.post('/crm/care/$bookingId/emergencies', data: {'day': day, 'what': what, 'action': action})));
    } catch (e) {
      throw AppException(e, action: 'log the emergency');
    }
  }

  /// kind: verify (the coming 7 days) | photos (the last 14 days).
  Future<CrmCareList> careList(String kind) async {
    try {
      return CrmCareList.fromJson(_body(await _dio.get('/crm/care-list', queryParameters: {'kind': kind})));
    } catch (e) {
      throw AppException(e, action: 'load the works');
    }
  }

  Future<CrmWeeklyReport> weekly({String? week}) async {
    try {
      return CrmWeeklyReport.fromJson(_body(await _dio.get('/crm/weekly', queryParameters: {'week': ?week})));
    } catch (e) {
      throw AppException(e, action: 'load the weekly report');
    }
  }

  Future<List<CrmWeekStatus>> weeks() async {
    try {
      final res = await _dio.get('/crm/weekly/list');
      return (res.data as List).whereType<Map>().map((e) => CrmWeekStatus.fromJson(e.cast<String, dynamic>())).toList();
    } catch (e) {
      throw AppException(e, action: 'load the weeks');
    }
  }

  /// Saves what the CRM Head typed (only the fields given).
  Future<CrmWeeklyReport> save(String week, Map<String, dynamic> typed) async {
    try {
      return CrmWeeklyReport.fromJson(_body(await _dio.put('/crm/weekly', data: {...typed, 'week': week})));
    } catch (e) {
      throw AppException(e, action: 'save the weekly report');
    }
  }

  Future<CrmWeeklyReport> submit(String week) async {
    try {
      return CrmWeeklyReport.fromJson(_body(await _dio.post('/crm/weekly/submit', data: {'week': week})));
    } catch (e) {
      throw AppException(e, action: 'hand in the weekly report');
    }
  }

  Future<CrmWeeklyReport> reopen(String week) async {
    try {
      return CrmWeeklyReport.fromJson(_body(await _dio.post('/crm/weekly/reopen', data: {'week': week})));
    } catch (e) {
      throw AppException(e, action: 'reopen the weekly report');
    }
  }

  /// The report as a file, with the login header (never the token in the address). → (file name, bytes).
  Future<(String, List<int>)> file(String week, String format) async {
    try {
      final res = await _dio.get<List<int>>(
        '/crm/weekly/file',
        queryParameters: {'week': week, 'format': format},
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(minutes: 2)),
      );
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(res.headers.value('content-disposition') ?? '');
      return (m?.group(1) ?? 'CRM_Weekly_Report_$week.$format', res.data ?? const <int>[]);
    } catch (e) {
      throw AppException(e, action: 'download the weekly report');
    }
  }
}

final crmWeeklyServiceProvider = Provider<CrmWeeklyService>((ref) => CrmWeeklyService(ref.watch(dioProvider)));

final crmCareProvider = FutureProvider.autoDispose.family<CrmCare, String>((ref, bookingId) => ref.watch(crmWeeklyServiceProvider).care(bookingId));

final crmCareListProvider = FutureProvider.autoDispose.family<CrmCareList, String>((ref, kind) => ref.watch(crmWeeklyServiceProvider).careList(kind));

/// The report of a week ('' = last week).
final crmWeeklyProvider = FutureProvider.autoDispose.family<CrmWeeklyReport, String>(
  (ref, week) => ref.watch(crmWeeklyServiceProvider).weekly(week: week.isEmpty ? null : week),
);

final crmWeeksProvider = FutureProvider.autoDispose<List<CrmWeekStatus>>((ref) => ref.watch(crmWeeklyServiceProvider).weeks());
