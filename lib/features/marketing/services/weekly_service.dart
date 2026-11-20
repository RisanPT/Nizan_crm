import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/weekly_models.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The Marketing Weekly Report's API (backend routes/marketingWeeklyRoutes.js, /api/marketing/weekly). READ-ONLY: one call returns the whole
/// page. It filters by the same shared date range and brand as the rest of Marketing ([teamFilterProvider]).
class MarketingWeeklyService {
  MarketingWeeklyService(this._dio);
  final Dio _dio;

  Future<WeeklyReport> report(TeamFilter f) async {
    try {
      final res = await _dio.get('/marketing/weekly', queryParameters: {'from': f.fromDay, 'to': f.toDay, 'brand': f.brand.wire});
      return WeeklyReport.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'load the weekly report');
    }
  }
}

final marketingWeeklyServiceProvider = Provider<MarketingWeeklyService>((ref) => MarketingWeeklyService(ref.watch(dioProvider)));

final weeklyReportProvider = FutureProvider.autoDispose<WeeklyReport>((ref) => ref.watch(marketingWeeklyServiceProvider).report(ref.watch(teamFilterProvider)), retry: (_, _) => null);

/// After a lead, booking, log, shoot or ad record changes elsewhere: the report reads again.
void refreshWeekly(WidgetRef ref) => ref.invalidate(weeklyReportProvider);
