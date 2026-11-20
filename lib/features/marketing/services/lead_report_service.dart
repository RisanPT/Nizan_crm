import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/lead_speed_models.dart';
import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The Lead Report's API (backend routes/marketingLeadReportRoutes.js, /api/marketing/lead-report). READ-ONLY: the leads are the CRM's
/// own. It filters by the same shared date range and brand as the rest of Marketing ([teamFilterProvider]).
class LeadReportService {
  LeadReportService(this._dio);
  final Dio _dio;

  Future<T> _get<T>(String action, String path, T Function(Map<String, dynamic>) parse, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get('/marketing/lead-report$path', queryParameters: query);
      return parse(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  static Map<String, dynamic> _range(TeamFilter f) => {'from': f.fromDay, 'to': f.toDay, 'brand': f.brand.wire};

  Future<LeadOverview> overview(TeamFilter f) => _get('load the Lead Report', '/overview', LeadOverview.fromJson, query: _range(f));

  Future<LeadList> leads(TeamFilter f, LeadListQuery q) => _get('load the leads', '/leads', LeadList.fromJson, query: {
        ..._range(f),
        if (q.stage != 'all') 'stage': q.stage,
        if (q.source != 'all') 'source': q.source,
        if (q.assignee != 'all') 'assignee': q.assignee,
        if (q.campaign != 'all') 'campaign': q.campaign,
        if (q.q.trim().isNotEmpty) 'q': q.q.trim(),
        if (q.sort != 'created') 'sort': q.sort,
        if (q.dir.isNotEmpty) 'dir': q.dir,
        'page': q.page,
      });

  Future<LeadDetail> lead(String id) => _get('open the lead', '/leads/$id', LeadDetail.fromJson);
  Future<StagesData> stages(TeamFilter f) => _get('load the lead stages', '/stages', StagesData.fromJson, query: _range(f));
  Future<SourcesData> sources(TeamFilter f) => _get('load the lead sources', '/sources', SourcesData.fromJson, query: _range(f));

  Future<FollowUpList> followUps(TeamFilter f, FollowUpQuery q) =>
      _get('load the follow-ups', '/followups', FollowUpList.fromJson, query: {..._range(f), if (q.filter != 'all') 'filter': q.filter, 'page': q.page});

  Future<ConversionData> conversion(TeamFilter f) => _get('load the conversion figures', '/conversion', ConversionData.fromJson, query: _range(f));

  /// One report as a table for the range and brand (the screen previews it and downloads it as a CSV).
  /// Speed to lead: [scope] 'auto' (leads that came in on their own) or 'all'.
  Future<LeadSpeed> speed(TeamFilter f, {String scope = 'auto'}) => _get('load speed to lead', '/speed', LeadSpeed.fromJson, query: {..._range(f), if (scope != 'auto') 'scope': scope});
  Future<SpeedSettings> speedSettings() => _get('load the speed-to-lead settings', '/speed/settings', SpeedSettings.fromJson);

  /// A manager's change to the target, the alert time, the working hours or the alert switch. A refusal comes back as [TeamRefusal].
  Future<SpeedSettings> saveSpeedSettings(Map<String, dynamic> body) async {
    try {
      final res = await _dio.put('/marketing/lead-report/speed/settings', data: body);
      return SpeedSettings.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null && [400, 403].contains(e.response?.statusCode)) throw TeamRefusal(data['message'].toString(), field: data['field']?.toString(), status: e.response?.statusCode ?? 400);
      throw AppException(e, action: 'save the speed-to-lead settings');
    } catch (e) {
      throw AppException(e, action: 'save the speed-to-lead settings');
    }
  }

  Future<LeadReportTable> report(String type, TeamFilter f) => _get('build the report', '/reports/$type', LeadReportTable.fromJson, query: _range(f));
}

final leadReportServiceProvider = Provider<LeadReportService>((ref) => LeadReportService(ref.watch(dioProvider)));

final leadOverviewProvider = FutureProvider.autoDispose<LeadOverview>((ref) => ref.watch(leadReportServiceProvider).overview(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final leadListProvider = FutureProvider.autoDispose.family<LeadList, LeadListQuery>((ref, q) => ref.watch(leadReportServiceProvider).leads(ref.watch(teamFilterProvider), q), retry: (_, _) => null);
final leadDetailProvider = FutureProvider.autoDispose.family<LeadDetail, String>((ref, id) => ref.watch(leadReportServiceProvider).lead(id), retry: (_, _) => null);
final leadStagesProvider = FutureProvider.autoDispose<StagesData>((ref) => ref.watch(leadReportServiceProvider).stages(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final leadSourcesProvider = FutureProvider.autoDispose<SourcesData>((ref) => ref.watch(leadReportServiceProvider).sources(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final leadFollowUpsProvider = FutureProvider.autoDispose.family<FollowUpList, FollowUpQuery>((ref, q) => ref.watch(leadReportServiceProvider).followUps(ref.watch(teamFilterProvider), q), retry: (_, _) => null);
final leadConversionProvider = FutureProvider.autoDispose<ConversionData>((ref) => ref.watch(leadReportServiceProvider).conversion(ref.watch(teamFilterProvider)), retry: (_, _) => null);
final leadSpeedProvider = FutureProvider.autoDispose.family<LeadSpeed, String>((ref, scope) => ref.watch(leadReportServiceProvider).speed(ref.watch(teamFilterProvider), scope: scope), retry: (_, _) => null);
final leadReportTableProvider = FutureProvider.autoDispose.family<LeadReportTable, String>((ref, type) => ref.watch(leadReportServiceProvider).report(type, ref.watch(teamFilterProvider)), retry: (_, _) => null);

/// The All Leads cuts (stage chip, source, assigned to, campaign, search, sort, page), the Follow-ups chip and page, and the report open on
/// the Reports tab.
final leadListQueryProvider = StateProvider<LeadListQuery>((ref) => const LeadListQuery());
final leadFollowUpQueryProvider = StateProvider<FollowUpQuery>((ref) => const FollowUpQuery());
final selectedLeadReportProvider = StateProvider<String>((ref) => kLeadReportCards.first.$1);

/// Opens a link (the call and WhatsApp buttons). A provider so a test can see what was opened instead of launching anything.
typedef LinkOpener = Future<bool> Function(Uri uri);
final leadLinkOpenerProvider = Provider<LinkOpener>((ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

/// After anything changes (pull to refresh, Try again): every Lead Report read starts again.
void refreshLeadReport(WidgetRef ref) {
  ref.invalidate(leadOverviewProvider);
  ref.invalidate(leadListProvider);
  ref.invalidate(leadDetailProvider);
  ref.invalidate(leadStagesProvider);
  ref.invalidate(leadSourcesProvider);
  ref.invalidate(leadFollowUpsProvider);
  ref.invalidate(leadConversionProvider);
  ref.invalidate(leadReportTableProvider);
  ref.invalidate(leadSpeedProvider);
}
