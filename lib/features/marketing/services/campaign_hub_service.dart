import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The Campaigns hub's API (backend routes/marketingCampaignHubRoutes.js, /api/marketing/campaign-hub). It filters by the same shared date
/// range and brand as the rest of Marketing ([teamFilterProvider]). The older Campaigns screen has its own service
/// (`campaign_service.dart`, /api/marketing/campaigns) and is untouched.
class MarketingCampaignHubService {
  MarketingCampaignHubService(this._dio);
  final Dio _dio;

  Future<T> _get<T>(String action, String path, T Function(Map<String, dynamic>) parse, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get('/marketing/campaign-hub$path', queryParameters: query);
      return parse(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  static Map<String, dynamic> _range(TeamFilter f) => {'from': f.fromDay, 'to': f.toDay, 'brand': f.brand.wire};

  Future<OverviewData> overview(TeamFilter f) => _get('load the campaigns overview', '/overview', OverviewData.fromJson, query: _range(f));

  Future<HubCampaignPage> campaigns(TeamFilter f, HubCampaignQuery q) => _get(
        'load the campaigns',
        '/campaigns',
        HubCampaignPage.fromJson,
        query: {..._range(f), if (q.q.trim().isNotEmpty) 'q': q.q.trim(), if (q.status != 'all') 'status': q.status, if (q.platform != 'all') 'platform': q.platform, if (q.objective != 'all') 'objective': q.objective, 'page': q.page},
      );

  Future<HubCampaignDetail> campaign(TeamFilter f, String id) => _get('open the campaign', '/campaigns/$id', HubCampaignDetail.fromJson, query: _range(f));
  Future<HubPerformance> performance(TeamFilter f) => _get('load campaign performance', '/performance', HubPerformance.fromJson, query: _range(f));

  /// The ads of the range and brand: an imported ad's figures are the days of the range; an ad typed by hand keeps its lifetime figures.
  Future<AdsData> ads(TeamFilter f, HubAdQuery q) => _get(
        'load the ads',
        '/ads',
        AdsData.fromJson,
        query: {..._range(f), if (q.filter != 'all') 'filter': q.filter, if (q.q.trim().isNotEmpty) 'q': q.q.trim(), if (q.campaignId != null) 'campaignId': q.campaignId, 'page': q.page},
      );

  /// Audiences & placements of the range (the breakdowns imported from Ads Manager).
  Future<HubAudiences> audiences(TeamFilter f) => _get('load the audiences', '/audiences', HubAudiences.fromJson, query: _range(f));

  Future<BudgetData> budget(TeamFilter f) => _get('load budget and spend', '/budget', BudgetData.fromJson, query: _range(f));
  Future<LeadsData> leads(TeamFilter f) => _get('load leads and conversions', '/leads', LeadsData.fromJson, query: _range(f));
  Future<ReportsData> reports(TeamFilter f) => _get('load the reports', '/reports', ReportsData.fromJson, query: _range(f));
  Future<ReportTable> report(TeamFilter f, String type) => _get('build the report', '/reports/$type', ReportTable.fromJson, query: _range(f));
  Future<HubSetup> setup() => _get('open the form', '/setup', HubSetup.fromJson);

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

  Future<HubCampaign> saveCampaign(Map<String, dynamic> body, {String? id}) =>
      _write('save the campaign', () => id == null ? _dio.post('/marketing/campaign-hub/campaigns', data: body) : _dio.put('/marketing/campaign-hub/campaigns/$id', data: body), HubCampaign.fromJson);
  Future<void> deleteCampaign(String id) => _write('delete the campaign', () => _dio.delete('/marketing/campaign-hub/campaigns/$id'), (_) {});

  Future<HubAdRow> saveAd(Map<String, dynamic> body, {String? id}) => _write('save the ad', () => id == null ? _dio.post('/marketing/campaign-hub/ads', data: body) : _dio.put('/marketing/campaign-hub/ads/$id', data: body), HubAdRow.fromJson);
  Future<void> deleteAd(String id) => _write('delete the ad', () => _dio.delete('/marketing/campaign-hub/ads/$id'), (_) {});

  /// A day's figures for a campaign, typed by hand (the same day again replaces it).
  Future<DayRecord> saveDay(Map<String, dynamic> body) => _write('save the day\'s figures', () => _dio.post('/marketing/campaign-hub/metrics', data: body), DayRecord.fromJson);
  Future<void> deleteDay(String id) => _write('remove the day', () => _dio.delete('/marketing/campaign-hub/metrics/$id'), (_) {});

  /// One request of a Meta Ads Manager import: the rows already read from the file ({campaign, campaignId?, day, spend, reach, impressions,
  /// clicks, results}, plus ad / adId / adSet / adSetId for an ad-level file, or age / gender / platform / position for a breakdown file).
  /// [level] says which: 'campaign' | 'ad' | 'breakdown'. [dryRun] only reports what would match. A big file is sent in several requests
  /// sharing [importId].
  Future<HubImportReport> importRows(List<Map<String, dynamic>> rows, {String level = 'campaign', bool createMissing = false, String brand = 'kerala', bool dryRun = false, String fileName = '', String? importId}) => _write(
        'import the figures',
        () => _dio.post('/marketing/campaign-hub/import', data: {'level': level, 'rows': rows, 'createMissing': createMissing, 'brand': brand, 'dryRun': dryRun, 'fileName': fileName, 'importId': ?importId}),
        HubImportReport.fromJson,
      );
}

final marketingCampaignHubServiceProvider = Provider<MarketingCampaignHubService>((ref) => MarketingCampaignHubService(ref.watch(dioProvider)));

/// The All Campaigns table's own cuts (search, status, platform, objective, page) and the Creatives & Ads table's (chips, search, campaign, page).
final hubCampaignQueryProvider = StateProvider<HubCampaignQuery>((ref) => const HubCampaignQuery());
final hubAdQueryProvider = StateProvider<HubAdQuery>((ref) => const HubAdQuery());

final hubOverviewProvider = FutureProvider.autoDispose<OverviewData>((ref) => ref.watch(marketingCampaignHubServiceProvider).overview(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final hubCampaignsProvider = FutureProvider.autoDispose<HubCampaignPage>((ref) => ref.watch(marketingCampaignHubServiceProvider).campaigns(ref.watch(teamFilterProvider), ref.watch(hubCampaignQueryProvider)), retry: (_, _) => null);
final hubCampaignDetailProvider = FutureProvider.autoDispose.family<HubCampaignDetail, String>((ref, id) => ref.watch(marketingCampaignHubServiceProvider).campaign(ref.watch(teamFilterProvider), id), retry: (_, _) => null);
final hubPerformanceProvider = FutureProvider.autoDispose<HubPerformance>((ref) => ref.watch(marketingCampaignHubServiceProvider).performance(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final hubAdsProvider = FutureProvider.autoDispose<AdsData>((ref) => ref.watch(marketingCampaignHubServiceProvider).ads(ref.watch(teamFilterProvider), ref.watch(hubAdQueryProvider)), retry: (_, _) => null);
final hubAudiencesProvider = FutureProvider.autoDispose<HubAudiences>((ref) => ref.watch(marketingCampaignHubServiceProvider).audiences(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final hubBudgetProvider = FutureProvider.autoDispose<BudgetData>((ref) => ref.watch(marketingCampaignHubServiceProvider).budget(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final hubLeadsProvider = FutureProvider.autoDispose<LeadsData>((ref) => ref.watch(marketingCampaignHubServiceProvider).leads(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final hubReportsProvider = FutureProvider.autoDispose<ReportsData>((ref) => ref.watch(marketingCampaignHubServiceProvider).reports(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final hubSetupProvider = FutureProvider.autoDispose<HubSetup>((ref) => ref.watch(marketingCampaignHubServiceProvider).setup(), retry: (_, _) => null);

/// After a campaign, an ad, a day's figures or an import changes: every Campaigns read starts again.
void refreshCampaignHub(WidgetRef ref) {
  ref.invalidate(hubOverviewProvider);
  ref.invalidate(hubCampaignsProvider);
  ref.invalidate(hubCampaignDetailProvider);
  ref.invalidate(hubPerformanceProvider);
  ref.invalidate(hubAdsProvider);
  ref.invalidate(hubAudiencesProvider);
  ref.invalidate(hubBudgetProvider);
  ref.invalidate(hubLeadsProvider);
  ref.invalidate(hubReportsProvider);
  ref.invalidate(hubSetupProvider);
}
