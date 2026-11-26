import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/strategy_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Strategies & Developments' API (backend routes/marketingStrategiesRoutes.js, /api/marketing/strategies). It filters by the same shared
/// date range and brand as the rest of Marketing ([teamFilterProvider]).
class MarketingStrategyService {
  MarketingStrategyService(this._dio);
  final Dio _dio;

  Future<T> _get<T>(String action, String path, T Function(Map<String, dynamic>) parse, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get('/marketing/strategies$path', queryParameters: query);
      return parse(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  static Map<String, dynamic> _range(TeamFilter f) => {'from': f.fromDay, 'to': f.toDay, 'brand': f.brand.wire};

  Future<StrategySetup> setup() => _get('open the form', '/setup', StrategySetup.fromJson);
  Future<StrategyOverview> overview(TeamFilter f) => _get('load the overview', '/overview', StrategyOverview.fromJson, query: _range(f));
  Future<PlansData> plans(TeamFilter f) => _get('load the strategic plans', '/plans', PlansData.fromJson, query: _range(f));

  Map<String, dynamic> _workQuery(TeamFilter f, WorkQuery q, int? limit) => {
        ..._range(f),
        if (q.status != 'all') 'status': q.status,
        if (q.focusArea.isNotEmpty) 'focusArea': q.focusArea,
        if (q.q.trim().isNotEmpty) 'q': q.q.trim(),
        'page': q.page,
        'limit': ?limit,
      };

  Future<WorkList> initiatives(TeamFilter f, WorkQuery q, {int? limit}) => _get('load the initiatives', '/initiatives', WorkList.fromJson, query: _workQuery(f, q, limit));
  Future<WorkList> projects(TeamFilter f, WorkQuery q, {int? limit}) => _get('load the development projects', '/projects', WorkList.fromJson, query: _workQuery(f, q, limit));
  Future<WorkDetail> initiative(String id) => _get('open the initiative', '/initiatives/$id', WorkDetail.fromJson);
  Future<WorkDetail> project(String id) => _get('open the project', '/projects/$id', WorkDetail.fromJson);
  Future<RoadmapData> roadmap(TeamFilter f, {int? year}) => _get('load the roadmap', '/roadmap', RoadmapData.fromJson, query: {..._range(f), 'year': ?year});
  Future<ResearchData> research(TeamFilter f, ResearchQuery q, {int? limit}) => _get('load research and insights', '/research', ResearchData.fromJson, query: {..._range(f), if (q.kind != 'all') 'kind': q.kind, if (q.q.trim().isNotEmpty) 'q': q.q.trim(), 'page': q.page, 'limit': ?limit});
  Future<ReviewsData> reviews(TeamFilter f, ReviewQuery q) => _get('load the reviews', '/reviews', ReviewsData.fromJson, query: {..._range(f), if (q.type != 'all') 'type': q.type});

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

  static const _base = '/marketing/strategies';
  Future<PlanItem> savePlan(Map<String, dynamic> body, {String? id}) => _write('save the plan', () => id == null ? _dio.post('$_base/plans', data: body) : _dio.put('$_base/plans/$id', data: body), PlanItem.fromJson);
  Future<void> deletePlan(String id) => _write('delete the plan', () => _dio.delete('$_base/plans/$id'), (_) {});
  Future<WorkItem> saveInitiative(Map<String, dynamic> body, {String? id}) => _write('save the initiative', () => id == null ? _dio.post('$_base/initiatives', data: body) : _dio.put('$_base/initiatives/$id', data: body), WorkItem.fromJson);
  Future<void> deleteInitiative(String id) => _write('delete the initiative', () => _dio.delete('$_base/initiatives/$id'), (_) {});
  Future<WorkItem> saveProject(Map<String, dynamic> body, {String? id}) => _write('save the project', () => id == null ? _dio.post('$_base/projects', data: body) : _dio.put('$_base/projects/$id', data: body), WorkItem.fromJson);
  Future<void> deleteProject(String id) => _write('delete the project', () => _dio.delete('$_base/projects/$id'), (_) {});
  Future<RoadmapLine> saveRoadmapLine(Map<String, dynamic> body, {String? id}) => _write('save the roadmap line', () => id == null ? _dio.post('$_base/roadmap', data: body) : _dio.put('$_base/roadmap/$id', data: body), RoadmapLine.fromJson);
  Future<void> deleteRoadmapLine(String id) => _write('delete the roadmap line', () => _dio.delete('$_base/roadmap/$id'), (_) {});
  Future<RoadmapLine> tickRoadmapLine(String id, {required bool done}) => _write('tick the roadmap line', () => _dio.post('$_base/roadmap/$id/tick', data: {'done': done}), RoadmapLine.fromJson);
  Future<Finding> saveFinding(Map<String, dynamic> body, {String? id}) => _write('save the finding', () => id == null ? _dio.post('$_base/research', data: body) : _dio.put('$_base/research/$id', data: body), Finding.fromJson);
  Future<void> deleteFinding(String id) => _write('delete the finding', () => _dio.delete('$_base/research/$id'), (_) {});
  Future<StrategyReview> saveReview(Map<String, dynamic> body, {String? id}) => _write('save the review', () => id == null ? _dio.post('$_base/reviews', data: body) : _dio.put('$_base/reviews/$id', data: body), StrategyReview.fromJson);
  Future<void> deleteReview(String id) => _write('delete the review', () => _dio.delete('$_base/reviews/$id'), (_) {});
  Future<StrategyReview> setActionStatus(String reviewId, String actionId, String status) => _write('update the action item', () => _dio.patch('$_base/reviews/$reviewId/actions/$actionId', data: {'status': status}), StrategyReview.fromJson);
}

final marketingStrategyServiceProvider = Provider<MarketingStrategyService>((ref) => MarketingStrategyService(ref.watch(dioProvider)));

/// How the Reviews tab is cut: the type tab (the document's Strategy / Project / Campaign / Quarterly review).
class ReviewQuery {
  const ReviewQuery({this.type = 'strategy'});
  final String type;
  @override
  bool operator ==(Object other) => other is ReviewQuery && other.type == type;
  @override
  int get hashCode => type.hashCode;
}

/// The tables' own cuts (status chips, focus area, search, page), the open review and the roadmap's year / view.
final initiativeQueryProvider = StateProvider<WorkQuery>((ref) => const WorkQuery());
final projectQueryProvider = StateProvider<WorkQuery>((ref) => const WorkQuery());
final researchQueryProvider = StateProvider<ResearchQuery>((ref) => const ResearchQuery());
final reviewQueryProvider = StateProvider<ReviewQuery>((ref) => const ReviewQuery());
final selectedReviewProvider = StateProvider<String?>((ref) => null);

/// The roadmap's year (null = the year of the range's end) and its view: 'timeline' or 'quarterly'.
final roadmapYearProvider = StateProvider<int?>((ref) => null);
final roadmapViewProvider = StateProvider<String>((ref) => 'timeline');

final strategySetupProvider = FutureProvider.autoDispose<StrategySetup>((ref) => ref.watch(marketingStrategyServiceProvider).setup(), retry: (_, _) => null);
final strategyOverviewProvider = FutureProvider.autoDispose<StrategyOverview>((ref) => ref.watch(marketingStrategyServiceProvider).overview(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final strategyPlansProvider = FutureProvider.autoDispose<PlansData>((ref) => ref.watch(marketingStrategyServiceProvider).plans(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final initiativesProvider = FutureProvider.autoDispose<WorkList>((ref) => ref.watch(marketingStrategyServiceProvider).initiatives(ref.watch(teamFilterProvider), ref.watch(initiativeQueryProvider)), retry: (_, _) => null);
final projectsProvider = FutureProvider.autoDispose<WorkList>((ref) => ref.watch(marketingStrategyServiceProvider).projects(ref.watch(teamFilterProvider), ref.watch(projectQueryProvider)), retry: (_, _) => null);
final workDetailProvider = FutureProvider.autoDispose.family<WorkDetail, ({String kind, String id})>((ref, k) => k.kind == 'project' ? ref.watch(marketingStrategyServiceProvider).project(k.id) : ref.watch(marketingStrategyServiceProvider).initiative(k.id), retry: (_, _) => null);
final strategyRoadmapProvider = FutureProvider.autoDispose<RoadmapData>((ref) => ref.watch(marketingStrategyServiceProvider).roadmap(ref.watch(teamFilterProvider), year: ref.watch(roadmapYearProvider)), retry: (_, _) => null);
final strategyResearchProvider = FutureProvider.autoDispose<ResearchData>((ref) => ref.watch(marketingStrategyServiceProvider).research(ref.watch(teamFilterProvider), ref.watch(researchQueryProvider)), retry: (_, _) => null);
final strategyReviewsProvider = FutureProvider.autoDispose<ReviewsData>((ref) => ref.watch(marketingStrategyServiceProvider).reviews(ref.watch(teamFilterProvider), ref.watch(reviewQueryProvider)), retry: (_, _) => null);

/// After anything on these screens changes — and after a task or a log tied to an initiative changes — every read starts again.
void refreshStrategies(WidgetRef ref) {
  ref.invalidate(strategySetupProvider);
  ref.invalidate(strategyOverviewProvider);
  ref.invalidate(strategyPlansProvider);
  ref.invalidate(initiativesProvider);
  ref.invalidate(projectsProvider);
  ref.invalidate(workDetailProvider);
  ref.invalidate(strategyRoadmapProvider);
  ref.invalidate(strategyResearchProvider);
  ref.invalidate(strategyReviewsProvider);
}
