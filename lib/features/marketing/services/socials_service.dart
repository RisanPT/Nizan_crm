import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/asset_search.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The Socials module's API (backend routes/marketingSocialsRoutes.js, /api/marketing/socials). It filters by the same shared date
/// range and brand as the rest of Marketing ([teamFilterProvider]).
class MarketingSocialsService {
  MarketingSocialsService(this._dio);
  final Dio _dio;

  Future<T> _get<T>(String action, String path, T Function(Map<String, dynamic>) parse, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get('/marketing/socials$path', queryParameters: query);
      return parse(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  static Map<String, dynamic> _range(TeamFilter f) => {'from': f.fromDay, 'to': f.toDay, 'brand': f.brand.wire};

  Future<SocialsOverview> overview(TeamFilter f) => _get('load Socials', '/overview', SocialsOverview.fromJson, query: _range(f));
  Future<SocialsCalendar> calendar(TeamFilter f, {String platform = 'all'}) => _get('load the content calendar', '/calendar', SocialsCalendar.fromJson, query: {..._range(f), if (platform != 'all') 'platform': platform});
  Future<AssetList> assets(AssetQuery q) => _get('load the assets', '/assets', AssetList.fromJson, query: q.query);

  /// One page of the gallery's search (several values per filter, keywords, the words searched, sort).
  Future<AssetPage> searchAssets(AssetSearch s, {int pageNo = 1, int limit = kGalleryPageSize}) => _get('search the gallery', '/assets', AssetPage.fromJson, query: s.query(pageNo: pageNo, limit: limit));

  /// The library's keywords: suggestions for what is typed ([q]), or the whole list (a large [limit]).
  Future<KeywordList> keywords({String q = '', int limit = 12}) => _get('load the keywords', '/assets/keywords', KeywordList.fromJson, query: {if (q.trim().isNotEmpty) 'q': q.trim(), 'limit': limit});
  /// The accounts, and the queue and published posts of the shared date range.
  Future<PublishingData> publishing(TeamFilter f) => _get('load publishing', '/publishing', PublishingData.fromJson, query: {'from': f.fromDay, 'to': f.toDay, if (f.brand != TeamBrand.all) 'brand': f.brand.wire});
  Future<Asset> asset(String id) => _get('load the asset', '/assets/$id', Asset.fromJson);
  Future<SocialsPerformance> performance(TeamFilter f, {String platform = 'all'}) => _get('load performance', '/performance', SocialsPerformance.fromJson, query: {..._range(f), if (platform != 'all') 'platform': platform});
  Future<SocialsReports> reports(TeamFilter f) => _get('load reports', '/reports', SocialsReports.fromJson, query: _range(f));
  Future<TargetsData> targets(TeamFilter f) => _get('load the targets', '/targets', TargetsData.fromJson, query: _range(f));

  Future<T> _write<T>(String action, Future<Response<dynamic>> Function() call, T Function(Map<String, dynamic>) parse) async {
    try {
      final res = await call();
      return parse(res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{});
    } on DioException catch (e) {
      throw _refusal(e) ?? AppException(e, action: action);
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  Future<void> saveTargets({required String brand, required String week, required Map<String, double> values}) => _write(
        'save the targets',
        () => _dio.put('/marketing/socials/targets', data: {'brand': brand, 'period': week, 'values': [for (final e in values.entries) {'metricId': e.key, 'target': e.value}]}),
        (_) {},
      );

  Future<Asset> saveAsset(Map<String, dynamic> body, {String? id}) => _write(
        'save the asset',
        () => id == null ? _dio.post('/marketing/socials/assets', data: body) : _dio.put('/marketing/socials/assets/$id', data: body),
        Asset.fromJson,
      );

  Future<void> deleteAsset(String id) => _write('delete the asset', () => _dio.delete('/marketing/socials/assets/$id'), (_) {});

  /// Rename a keyword on every asset; into one that exists = merged. Marketing Manager.
  Future<KeywordRename> renameKeyword(String from, String to) => _write('rename the keyword', () => _dio.post('/marketing/socials/assets/keywords/rename', data: {'from': from, 'to': to}), KeywordRename.fromJson);

  /// Take a keyword off every asset; returns how many it was on. Marketing Manager.
  Future<int> removeKeyword(String keyword) => _write('remove the keyword', () => _dio.post('/marketing/socials/assets/keywords/remove', data: {'keyword': keyword}), (j) => (j['updated'] as num?)?.toInt() ?? 0);

  /// Add and/or remove keywords on the chosen assets.
  Future<BulkKeywordResult> bulkKeywords(List<String> ids, {List<String> add = const [], List<String> remove = const []}) =>
      _write('change the keywords', () => _dio.post('/marketing/socials/assets/bulk-keywords', data: {'ids': ids, 'add': add, 'remove': remove}), BulkKeywordResult.fromJson);

  Future<SocialAccount> saveAccount(Map<String, dynamic> body, {String? id}) => _write(
        'save the account',
        () => id == null ? _dio.post('/marketing/socials/accounts', data: body) : _dio.put('/marketing/socials/accounts/$id', data: body),
        SocialAccount.fromJson,
      );

  Future<void> deleteAccount(String id) => _write('remove the account', () => _dio.delete('/marketing/socials/accounts/$id'), (_) {});

  /// Create or change a post (the Content record the calendar and pipeline are built from).
  Future<void> savePost(Map<String, dynamic> body, {String? id}) => _write(
        'save the post',
        () => id == null ? _dio.post('/content', data: body) : _dio.put('/content/$id', data: body),
        (_) {},
      );

  Future<void> deletePost(String id) => _write('delete the post', () => _dio.delete('/content/$id'), (_) {});
}

TeamRefusal? _refusal(DioException e) {
  final status = e.response?.statusCode;
  final data = e.response?.data;
  if (status == null || ![400, 403, 404, 409].contains(status) || data is! Map || data['message'] == null) return null;
  return TeamRefusal(data['message'].toString(), field: data['field']?.toString(), status: status);
}

final marketingSocialsServiceProvider = Provider<MarketingSocialsService>((ref) => MarketingSocialsService(ref.watch(dioProvider)));

final socialsOverviewProvider = FutureProvider.autoDispose<SocialsOverview>((ref) => ref.watch(marketingSocialsServiceProvider).overview(ref.watch(teamFilterProvider)), retry: (_, _) => null);
/// What the Content Calendar asks the server for: a window of days (and a platform); the brand comes from the shared filter.
typedef CalKey = ({String from, String to, String platform});

/// The Content Calendar's window (a month grid, a week, a list) — refreshed with every Socials save (refreshSocials).
final socialsWindowProvider = FutureProvider.autoDispose.family<SocialsCalendar, CalKey>((ref, k) {
  final f = ref.watch(teamFilterProvider);
  final window = TeamFilter(from: DateTime.parse(k.from), to: DateTime.parse(k.to), brand: f.brand);
  return ref.watch(marketingSocialsServiceProvider).calendar(window, platform: k.platform);
}, retry: (_, _) => null);
final socialsAssetsProvider = FutureProvider.autoDispose.family<AssetList, AssetQuery>((ref, q) => ref.watch(marketingSocialsServiceProvider).assets(q), retry: (_, _) => null);

/// One page of the gallery's search: (the search, the page number).
final galleryPageProvider = FutureProvider.autoDispose.family<AssetPage, (AssetSearch, int)>((ref, k) => ref.watch(marketingSocialsServiceProvider).searchAssets(k.$1, pageNo: k.$2), retry: (_, _) => null);

/// Keyword suggestions for what is typed ('' = the most used).
final keywordSuggestProvider = FutureProvider.autoDispose.family<KeywordList, String>((ref, q) => ref.watch(marketingSocialsServiceProvider).keywords(q: q, limit: 10), retry: (_, _) => null);

/// Every keyword in the library, for managing them.
final keywordLibraryProvider = FutureProvider.autoDispose<KeywordList>((ref) => ref.watch(marketingSocialsServiceProvider).keywords(limit: 1000), retry: (_, _) => null);

/// One asset (the post form shows the one a post is made from).
final socialsAssetProvider = FutureProvider.autoDispose.family<Asset, String>((ref, id) => ref.watch(marketingSocialsServiceProvider).asset(id), retry: (_, _) => null);
final socialsPublishingProvider = FutureProvider.autoDispose<PublishingData>((ref) => ref.watch(marketingSocialsServiceProvider).publishing(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final socialsPerformanceProvider = FutureProvider.autoDispose.family<SocialsPerformance, String>((ref, platform) => ref.watch(marketingSocialsServiceProvider).performance(ref.watch(teamFilterProvider), platform: platform), retry: (_, _) => null);
final socialsReportsProvider = FutureProvider.autoDispose<SocialsReports>((ref) => ref.watch(marketingSocialsServiceProvider).reports(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final socialsTargetsProvider = FutureProvider.autoDispose<TargetsData>((ref) => ref.watch(marketingSocialsServiceProvider).targets(ref.watch(teamFilterProvider)), retry: (_, _) => null);

/// After anything on Socials is saved: every Socials read starts again (and Marketing's other screens that read the same posts).
void refreshSocials(WidgetRef ref) {
  ref.invalidate(socialsOverviewProvider);
  ref.invalidate(socialsWindowProvider);
  ref.invalidate(socialsAssetsProvider);
  ref.invalidate(galleryPageProvider);
  ref.invalidate(keywordSuggestProvider);
  ref.invalidate(keywordLibraryProvider);
  ref.invalidate(socialsAssetProvider);
  ref.invalidate(socialsPublishingProvider);
  ref.invalidate(socialsPerformanceProvider);
  ref.invalidate(socialsReportsProvider);
  ref.invalidate(socialsTargetsProvider);
}
