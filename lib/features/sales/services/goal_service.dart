import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/features/sales/data/goal_report.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// (granularity day|week|month, anchor day yyyy-MM-dd, basis added|event). Any stretch of days instead: granularity 'range' and the
/// date 'from..to' — build it with [goalRangeQuery].
typedef GoalQuery = ({String granularity, String date, String basis});

/// The report for the days in [range] (both ends needed, at most a year — the server says so otherwise).
GoalQuery goalRangeQuery(ReportRange range, String basis) => (granularity: 'range', date: '${range.fromIso}..${range.toIso}', basis: basis);

class GoalService {
  final Dio _dio;
  GoalService(this._dio);

  Map<String, dynamic> _map(Object? data) => (data as Map).cast<String, dynamic>();

  Future<GoalReport> getReport(GoalQuery q) async {
    try {
      final days = q.granularity == 'range' ? q.date.split('..') : const <String>[];
      final res = await _dio.get('/goals/report',
          queryParameters: days.length == 2
              ? {'from': days[0], 'to': days[1], 'basis': q.basis}
              : {'granularity': q.granularity, 'date': q.date, 'basis': q.basis});
      return GoalReport.fromJson(_map(res.data));
    } catch (e) {
      throw AppException(e, action: 'load the report');
    }
  }

  Future<MtdReport> getMtd(GoalQuery q) async {
    try {
      // month to date as of the last day of a chosen stretch
      final asOf = q.granularity == 'range' ? q.date.split('..').last : q.date;
      final res = await _dio.get('/goals/mtd', queryParameters: {'date': asOf, 'basis': q.basis});
      return MtdReport.fromJson(_map(res.data));
    } catch (e) {
      throw AppException(e, action: 'load month-to-date');
    }
  }

  Future<GoalSet> getGoals(String periodType, String date) async {
    try {
      final res = await _dio.get('/goals', queryParameters: {'periodType': periodType, 'date': date});
      return GoalSet.fromJson(_map(res.data));
    } catch (e) {
      throw AppException(e, action: 'load goals');
    }
  }

  /// A number sets a goal; null clears it. Other periods are never touched.
  Future<GoalSet> saveGoals(String periodType, String date, Map<String, double?> goals) async {
    try {
      final res = await _dio.put('/goals', data: {'periodType': periodType, 'date': date, 'goals': goals});
      return GoalSet.fromJson({..._map(res.data), 'canEdit': true});
    } catch (e) {
      throw AppException(e, action: 'save goals');
    }
  }
}

final goalServiceProvider = Provider<GoalService>((ref) => GoalService(ref.watch(dioProvider)));

final goalReportProvider = FutureProvider.autoDispose
    .family<GoalReport, GoalQuery>((ref, q) => ref.watch(goalServiceProvider).getReport(q));

final mtdReportProvider = FutureProvider.autoDispose
    .family<MtdReport, GoalQuery>((ref, q) => ref.watch(goalServiceProvider).getMtd(q));

final goalSetProvider = FutureProvider.autoDispose
    .family<GoalSet, ({String periodType, String date})>(
        (ref, q) => ref.watch(goalServiceProvider).getGoals(q.periodType, q.date));

/// Who sees the Report & Goals screen — mirrors the backend `NO_REPORT_ROLES`
/// (company goals don't fit a salesperson's own figures; field staff skip it).
bool canViewGoalReport(String? role) =>
    !const ['artist', 'driver', 'sales', 'sales_executive'].contains((role ?? '').trim().toLowerCase());

/// Whether this role may set goals — mirrors the backend `canSetGoals`
/// (admin, manager, sales / marketing managers and admins).
bool canSetGoals(String? role) {
  final r = (role ?? '').trim().toLowerCase();
  return r == 'admin' ||
      r == 'manager' ||
      RegExp(r'^(sales|marketing)_?.*(manager|admin|head)$').hasMatch(r);
}
