import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The Creative Portfolio's API (backend routes/marketingPortfolioRoutes.js, /api/marketing/portfolio). It filters by the same shared
/// date range and brand as the rest of Marketing ([teamFilterProvider]). The Gallery reads the shared asset library
/// ([marketingSocialsServiceProvider]).
class MarketingPortfolioService {
  MarketingPortfolioService(this._dio);
  final Dio _dio;

  Future<T> _get<T>(String action, String path, T Function(Map<String, dynamic>) parse, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get('/marketing/portfolio$path', queryParameters: query);
      return parse(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  static Map<String, dynamic> _range(TeamFilter f) => {'from': f.fromDay, 'to': f.toDay, 'brand': f.brand.wire};

  Future<PlannerData> planner(TeamFilter f, PlannerQuery q) => _get('load the shoot planner', '/shoots', PlannerData.fromJson, query: {..._range(f), if (q.status != 'all') 'status': q.status, if (q.q.trim().isNotEmpty) 'q': q.q.trim(), 'page': q.page});
  Future<ShootDetail> shoot(String id) => _get('open the shoot', '/shoots/$id', ShootDetail.fromJson);
  Future<ProductionCalendar> calendar(TeamFilter f, {String? day}) => _get('load the production calendar', '/calendar', ProductionCalendar.fromJson, query: {..._range(f), 'day': ?day});
  Future<ShootReports> reports(TeamFilter f, ReportQuery q) => _get('load the shoot reports', '/reports', ShootReports.fromJson, query: {..._range(f), if (q.filter != 'all') 'filter': q.filter, if (q.q.trim().isNotEmpty) 'q': q.q.trim(), 'page': q.page});
  Future<ShootSetup> setup() => _get('open the shoot form', '/setup', ShootSetup.fromJson);

  Future<T> _write<T>(String action, Future<Response<dynamic>> Function() call, T Function(Map<String, dynamic>) parse) async {
    try {
      final res = await call();
      return parse(res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{});
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if (status != null && [400, 403, 404, 409].contains(status) && data is Map && data['message'] != null) throw TeamRefusal(data['message'].toString(), field: data['field']?.toString(), status: status);
      throw AppException(e, action: action);
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  Future<ShootSummary> saveShoot(Map<String, dynamic> body, {String? id}) => _write('save the shoot', () => id == null ? _dio.post('/marketing/portfolio/shoots', data: body) : _dio.put('/marketing/portfolio/shoots/$id', data: body), ShootSummary.fromJson);
  Future<void> deleteShoot(String id) => _write('delete the shoot', () => _dio.delete('/marketing/portfolio/shoots/$id'), (_) {});
}

final marketingPortfolioServiceProvider = Provider<MarketingPortfolioService>((ref) => MarketingPortfolioService(ref.watch(dioProvider)));

/// The planner's own cuts (status chips, search, page) and which shoot is open on the right.
final plannerQueryProvider = StateProvider<PlannerQuery>((ref) => const PlannerQuery());
final selectedShootProvider = StateProvider<String?>((ref) => null);
final reportQueryProvider = StateProvider<ReportQuery>((ref) => const ReportQuery());
final selectedReportShootProvider = StateProvider<String?>((ref) => null);

final plannerProvider = FutureProvider.autoDispose<PlannerData>((ref) => ref.watch(marketingPortfolioServiceProvider).planner(ref.watch(teamFilterProvider), ref.watch(plannerQueryProvider)), retry: (_, _) => null);
final shootDetailProvider = FutureProvider.autoDispose.family<ShootDetail, String>((ref, id) => ref.watch(marketingPortfolioServiceProvider).shoot(id), retry: (_, _) => null);
final productionCalendarProvider = FutureProvider.autoDispose.family<ProductionCalendar, ({String from, String to, String? day})>((ref, k) {
  final f = ref.watch(teamFilterProvider);
  return ref.watch(marketingPortfolioServiceProvider).calendar(TeamFilter(from: DateTime.parse(k.from), to: DateTime.parse(k.to), brand: f.brand), day: k.day);
}, retry: (_, _) => null);
final shootReportsProvider = FutureProvider.autoDispose<ShootReports>((ref) => ref.watch(marketingPortfolioServiceProvider).reports(ref.watch(teamFilterProvider), ref.watch(reportQueryProvider)), retry: (_, _) => null);
final shootSetupProvider = FutureProvider.autoDispose<ShootSetup>((ref) => ref.watch(marketingPortfolioServiceProvider).setup(), retry: (_, _) => null);

/// After a shoot, an asset or a log changes: every Creative Portfolio read starts again (and the Socials library the Gallery shares).
void refreshPortfolio(WidgetRef ref) {
  ref.invalidate(plannerProvider);
  ref.invalidate(shootDetailProvider);
  ref.invalidate(productionCalendarProvider);
  ref.invalidate(shootReportsProvider);
  ref.invalidate(shootSetupProvider);
  refreshSocials(ref);
}
