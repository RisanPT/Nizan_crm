import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/dashboard/data/dashboard_analytics.dart';

/// Client for GET /api/dashboard/* (server-side dashboard aggregates).
class DashboardAnalyticsService {
  final Dio _dio;
  DashboardAnalyticsService(this._dio);

  Future<Map<String, dynamic>> _get(String path, DashboardQuery q) async {
    try {
      final res = await _dio.get('/dashboard/$path', queryParameters: q.toParams());
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw AppException(e, action: 'load the dashboard');
    }
  }

  Future<SalesDashboard> sales(DashboardQuery q) async =>
      SalesDashboard.fromJson(await _get('sales', q));
  Future<MarketingDashboard> marketing(DashboardQuery q) async =>
      MarketingDashboard.fromJson(await _get('marketing', q));
  Future<FinanceDashboard> finance(DashboardQuery q) async =>
      FinanceDashboard.fromJson(await _get('finance', q));
}

final dashboardAnalyticsServiceProvider = Provider<DashboardAnalyticsService>(
    (ref) => DashboardAnalyticsService(ref.watch(dioProvider)));

final salesDashboardProvider = FutureProvider.autoDispose
    .family<SalesDashboard, DashboardQuery>(
        (ref, q) => ref.watch(dashboardAnalyticsServiceProvider).sales(q));

final marketingDashboardProvider = FutureProvider.autoDispose
    .family<MarketingDashboard, DashboardQuery>(
        (ref, q) => ref.watch(dashboardAnalyticsServiceProvider).marketing(q));

final financeDashboardProvider = FutureProvider.autoDispose
    .family<FinanceDashboard, DashboardQuery>(
        (ref, q) => ref.watch(dashboardAnalyticsServiceProvider).finance(q));
