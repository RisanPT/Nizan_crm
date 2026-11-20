import 'dart:typed_data';

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

  /// Every report row that matches (the Export button) — not one page.
  Future<ShootReports> allReports(TeamFilter f, ReportQuery q) => _get('export the shoot reports', '/reports', ShootReports.fromJson, query: {..._range(f), if (q.filter != 'all') 'filter': q.filter, if (q.q.trim().isNotEmpty) 'q': q.q.trim(), 'all': 1});

  /// Works (CRM bookings) a shoot can be linked to: those matching [q], or with an event within 30 days of [around].
  Future<List<BookingBrief>> bookingOptions({String q = '', String? around}) =>
      _get('load the bookings', '/booking-options', (j) => ((j['items'] as List?) ?? const []).map((e) => BookingBrief.fromJson(Map<String, dynamic>.from(e as Map))).toList(), query: {if (q.trim().isNotEmpty) 'q': q.trim(), 'around': ?around});

  /// Shoots a post or an asset can be attached to (not cancelled, newest first).
  Future<List<ShootOption>> shootOptions({String q = ''}) =>
      _get('load the shoots', '/shoot-options', (j) => ((j['items'] as List?) ?? const []).map((e) => ShootOption.fromJson(Map<String, dynamic>.from(e as Map))).toList(), query: {if (q.trim().isNotEmpty) 'q': q.trim()});

  /// A booking's linked shoots with their content checklist.
  Future<BookingContent> bookingContent(String bookingId) => _get('load the booking\'s content', '/bookings/$bookingId/content', BookingContent.fromJson);

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

  /// Pictures and links onto the shoot's moodboard ([items]: {url, label}); returns how many were added (a link already there is not).
  Future<int> addMoodboard(String shootId, List<Map<String, dynamic>> items) =>
      _write('add to the moodboard', () => _dio.post('/marketing/portfolio/shoots/$shootId/moodboard', data: {'items': items}), (j) => (j['added'] as num?)?.toInt() ?? 0);
  Future<void> renameMoodboardItem(String shootId, String url, String label) =>
      _write('rename the moodboard item', () => _dio.patch('/marketing/portfolio/shoots/$shootId/moodboard', data: {'url': url, 'label': label}), (_) {});
  Future<void> removeMoodboardItem(String shootId, String url) =>
      _write('remove the moodboard item', () => _dio.delete('/marketing/portfolio/shoots/$shootId/moodboard', queryParameters: {'url': url}), (_) {});

  /// Crew & Logistics: call time, map link, checklist ([{text, done}]), notes — only what is sent changes.
  /// One checklist line ticked or unticked — that line alone (a tick never undoes another person's).
  Future<void> tickChecklist(String shootId, String text, bool done) =>
      _write('tick the line', () => _dio.patch('/marketing/portfolio/shoots/$shootId/logistics/check', data: {'text': text, 'done': done}), (_) {});

  /// A storyboard frame ticked as filmed (or not) on the shoot day — that frame alone.
  Future<void> markFrameShot(String shootId, String frameKey, bool shot) =>
      _write('tick the frame', () => _dio.patch('/marketing/portfolio/shoots/$shootId/storyboard/${Uri.encodeComponent(frameKey)}', data: {'shot': shot}), (_) {});

  /// A PDF onto the moodboard or the storyboard ([part]) → the added document.
  Future<ShootDocument> uploadDocument(String shootId, String part, {required String fileName, required List<int> bytes, String label = ''}) => _write(
        'upload the PDF',
        () => _dio.post('/marketing/portfolio/shoots/$shootId/documents', data: FormData.fromMap({'part': part, if (label.isNotEmpty) 'label': label, 'file': MultipartFile.fromBytes(bytes, filename: fileName)})),
        (j) => ShootDocument.fromJson(Map<String, dynamic>.from(j['added'] as Map? ?? const {})),
      );

  /// The PDF itself (fetched with the login, never by a public link).
  Future<Uint8List> documentBytes(String shootId, String key) async {
    try {
      final res = await _dio.get<List<int>>('/marketing/portfolio/shoots/$shootId/documents/${Uri.encodeComponent(key)}', options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(res.data ?? const <int>[]);
    } catch (e) {
      throw AppException(e, action: 'open the PDF');
    }
  }

  Future<void> renameDocument(String shootId, String key, String label) =>
      _write('rename the PDF', () => _dio.patch('/marketing/portfolio/shoots/$shootId/documents/${Uri.encodeComponent(key)}', data: {'label': label}), (_) {});
  Future<void> removeDocument(String shootId, String key) =>
      _write('remove the PDF', () => _dio.delete('/marketing/portfolio/shoots/$shootId/documents/${Uri.encodeComponent(key)}'), (_) {});

  Future<void> saveLogistics(String shootId, Map<String, dynamic> body) => _write('save the logistics', () => _dio.put('/marketing/portfolio/shoots/$shootId/logistics', data: body), (_) {});
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
final shootOptionsProvider = FutureProvider.autoDispose.family<List<ShootOption>, String>((ref, q) => ref.watch(marketingPortfolioServiceProvider).shootOptions(q: q), retry: (_, _) => null);
final bookingOptionsProvider = FutureProvider.autoDispose.family<List<BookingBrief>, ({String q, String? around})>((ref, k) => ref.watch(marketingPortfolioServiceProvider).bookingOptions(q: k.q, around: k.around), retry: (_, _) => null);
final bookingContentProvider = FutureProvider.autoDispose.family<BookingContent, String>((ref, id) => ref.watch(marketingPortfolioServiceProvider).bookingContent(id), retry: (_, _) => null);

/// After a shoot, an asset or a log changes: every Creative Portfolio read starts again (and the Socials library the Gallery shares).
void refreshPortfolio(WidgetRef ref) {
  ref.invalidate(plannerProvider);
  ref.invalidate(shootDetailProvider);
  ref.invalidate(productionCalendarProvider);
  ref.invalidate(shootReportsProvider);
  ref.invalidate(shootSetupProvider);
  ref.invalidate(shootOptionsProvider);
  ref.invalidate(bookingContentProvider);
  refreshSocials(ref);
}
