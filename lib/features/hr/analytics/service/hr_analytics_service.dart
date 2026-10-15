import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';

class DeptCount {
  final String department;
  final int count;
  const DeptCount(this.department, this.count);
}

class HrAnalyticsSummary {
  final int active;
  final int inactive;
  final int total;
  final List<DeptCount> byDepartment;
  final int newHiresThisMonth;
  final int onboardingInProgress;
  final int exitsInProgress;
  final int pendingApprovals;
  final int pendingLeave;
  final int openGrievances;

  const HrAnalyticsSummary({
    this.active = 0,
    this.inactive = 0,
    this.total = 0,
    this.byDepartment = const [],
    this.newHiresThisMonth = 0,
    this.onboardingInProgress = 0,
    this.exitsInProgress = 0,
    this.pendingApprovals = 0,
    this.pendingLeave = 0,
    this.openGrievances = 0,
  });

  factory HrAnalyticsSummary.fromJson(Map<String, dynamic> j) {
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    final hc = (j['headcount'] as Map<String, dynamic>?) ?? const {};
    final depts = (j['byDepartment'] as List?) ?? const [];
    return HrAnalyticsSummary(
      active: i(hc['active']),
      inactive: i(hc['inactive']),
      total: i(hc['total']),
      byDepartment: depts
          .map((e) => DeptCount((e as Map)['department'] as String? ?? 'Unassigned', i(e['count'])))
          .toList(),
      newHiresThisMonth: i(j['newHiresThisMonth']),
      onboardingInProgress: i(j['onboardingInProgress']),
      exitsInProgress: i(j['exitsInProgress']),
      pendingApprovals: i(j['pendingApprovals']),
      pendingLeave: i(j['pendingLeave']),
      openGrievances: i(j['openGrievances']),
    );
  }
}

class HrAnalyticsService {
  final Dio _dio;
  HrAnalyticsService(this._dio);

  Future<HrAnalyticsSummary> getSummary() async {
    try {
      final res = await _dio.get('/hr-analytics/summary');
      return HrAnalyticsSummary.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load HR analytics');
    }
  }
}

final hrAnalyticsServiceProvider =
    Provider<HrAnalyticsService>((ref) => HrAnalyticsService(ref.watch(dioProvider)));

final hrAnalyticsSummaryProvider =
    FutureProvider<HrAnalyticsSummary>((ref) => ref.watch(hrAnalyticsServiceProvider).getSummary());
