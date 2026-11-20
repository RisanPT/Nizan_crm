import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Coordinations' API (backend routes/marketingCoordinationsRoutes.js, /api/marketing/coordinations). Every read carries the shared date
/// range and brand ([teamFilterProvider]) and the Departments pill ([coordDeptProvider]).
class MarketingCoordinationService {
  MarketingCoordinationService(this._dio);
  final Dio _dio;

  static const _base = '/marketing/coordinations';

  Future<T> _get<T>(String action, String path, T Function(Map<String, dynamic>) parse, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get('$_base$path', queryParameters: query);
      return parse(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  static Map<String, dynamic> _range(TeamFilter f, String dept) => {'from': f.fromDay, 'to': f.toDay, 'brand': f.brand.wire, if (dept != 'all') 'dept': dept};

  Future<CoordSetup> setup() => _get('open the form', '/setup', CoordSetup.fromJson);
  Future<CoordOverview> overview(TeamFilter f, String dept, OverviewOptions o) => _get('load the coordinations overview', '/overview', CoordOverview.fromJson, query: {..._range(f, dept), 'by': o.by, 'upcoming': o.upcoming});
  Future<RequestList> requests(TeamFilter f, String dept, RequestQuery q) => _get('load the requests', '/requests', RequestList.fromJson, query: {
        ..._range(f, dept),
        'scope': q.scope,
        if (q.status != 'all') 'status': q.status,
        if (q.priority != 'all') 'priority': q.priority,
        if (q.q.trim().isNotEmpty) 'q': q.q.trim(),
        'page': q.page,
      });
  Future<HandoverBoard> board(TeamFilter f, String dept) => _get('load the handover board', '/interdepartment', HandoverBoard.fromJson, query: _range(f, dept));
  Future<ApprovalList> approvals(TeamFilter f, String dept, ApprovalQuery q) => _get('load the approvals', '/approvals', ApprovalList.fromJson, query: {..._range(f, dept), 'status': q.status, if (q.q.trim().isNotEmpty) 'q': q.q.trim(), 'page': q.page});
  Future<MeetingList> meetings(TeamFilter f, String dept, MeetingQuery q) => _get('load the meetings', '/meetings', MeetingList.fromJson, query: {..._range(f, dept), if (q.status != 'all') 'status': q.status, if (q.q.trim().isNotEmpty) 'q': q.q.trim()});
  Future<MeetingRow> meeting(String id) => _get('open the meeting', '/meetings/$id', MeetingRow.fromJson);
  Future<FollowUpList> followUps(TeamFilter f, String dept, FollowUpQuery q) => _get('load the follow-ups', '/followups', FollowUpList.fromJson, query: {
        ..._range(f, dept),
        if (q.status != 'all') 'status': q.status,
        if (q.ownerId != null) 'ownerId': q.ownerId,
        if (q.q.trim().isNotEmpty) 'q': q.q.trim(),
        'page': q.page,
      });
  Future<FollowUpCalendar> followUpCalendar(TeamFilter f, String dept, String month, {String? ownerId}) => _get('load the follow-up calendar', '/followups/calendar', FollowUpCalendar.fromJson, query: {..._range(f, dept), 'month': month, 'ownerId': ?ownerId});

  /// The rows of a tab's CSV: `type` is requests, approvals, meetings or followups — cut the way the tab is.
  Future<CoordExport> export(String type, TeamFilter f, String dept, {Map<String, dynamic>? extra}) => _get('build the report', '/export/$type', CoordExport.fromJson, query: {..._range(f, dept), ...?extra});

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

  Future<CoordRequestRow> saveRequest(Map<String, dynamic> body, {String? id}) => _write('save the request', () => id == null ? _dio.post('$_base/requests', data: body) : _dio.put('$_base/requests/$id', data: body), CoordRequestRow.fromJson);
  Future<CoordRequestRow> moveRequest(String id, String stage) => _write('move the handover', () => _dio.post('$_base/requests/$id/move', data: {'stage': stage}), CoordRequestRow.fromJson);
  Future<void> deleteRequest(String id) => _write('delete the request', () => _dio.delete('$_base/requests/$id'), (_) {});

  Future<ApprovalRow> saveApproval(Map<String, dynamic> body, {String? id}) => _write('save the approval', () => id == null ? _dio.post('$_base/approvals', data: body) : _dio.put('$_base/approvals/$id', data: body), ApprovalRow.fromJson);
  Future<ApprovalRow> decideApproval(String id, String decision, {String note = ''}) => _write('record the decision', () => _dio.post('$_base/approvals/$id/decide', data: {'decision': decision, if (note.trim().isNotEmpty) 'note': note.trim()}), ApprovalRow.fromJson);
  Future<void> deleteApproval(String id) => _write('delete the approval', () => _dio.delete('$_base/approvals/$id'), (_) {});

  Future<MeetingRow> saveMeeting(Map<String, dynamic> body, {String? id}) => _write('save the meeting', () => id == null ? _dio.post('$_base/meetings', data: body) : _dio.put('$_base/meetings/$id', data: body), MeetingRow.fromJson);
  Future<void> deleteMeeting(String id) => _write('delete the meeting', () => _dio.delete('$_base/meetings/$id'), (_) {});
  Future<FollowUpRow> actionItemToFollowUp(String meetingId, String itemId) =>
      _write('make the follow-up', () => _dio.post('$_base/meetings/$meetingId/action-items/$itemId/follow-up'), (j) => FollowUpRow.fromJson(Map<String, dynamic>.from(j['followUp'] as Map)));

  Future<FollowUpRow> saveFollowUp(Map<String, dynamic> body, {String? id}) => _write('save the follow-up', () => id == null ? _dio.post('$_base/followups', data: body) : _dio.put('$_base/followups/$id', data: body), FollowUpRow.fromJson);
  Future<void> deleteFollowUp(String id) => _write('delete the follow-up', () => _dio.delete('$_base/followups/$id'), (_) {});
}

final marketingCoordinationServiceProvider = Provider<MarketingCoordinationService>((ref) => MarketingCoordinationService(ref.watch(dioProvider)));

/// The Departments pill ("All Departments") — one choice for every Coordinations tab.
final coordDeptProvider = StateProvider<String>((ref) => 'all');

/// Each tab's own cuts: the Overview's grouping and period, the request table, the approvals tab, the meeting list, the follow-up list, and the open meeting / calendar month.
final coordOverviewOptionsProvider = StateProvider<OverviewOptions>((ref) => const OverviewOptions());
final coordRequestQueryProvider = StateProvider<RequestQuery>((ref) => const RequestQuery());
final coordApprovalQueryProvider = StateProvider<ApprovalQuery>((ref) => const ApprovalQuery());
final coordMeetingQueryProvider = StateProvider<MeetingQuery>((ref) => const MeetingQuery());
final coordSelectedMeetingProvider = StateProvider<String?>((ref) => null);
final coordFollowUpQueryProvider = StateProvider<FollowUpQuery>((ref) => const FollowUpQuery());
final coordCalendarMonthProvider = StateProvider<DateTime>((ref) => DateTime(DateTime.now().year, DateTime.now().month));

final coordSetupProvider = FutureProvider.autoDispose<CoordSetup>((ref) => ref.watch(marketingCoordinationServiceProvider).setup(), retry: (_, _) => null);
final coordOverviewProvider = FutureProvider.autoDispose<CoordOverview>((ref) => ref.watch(marketingCoordinationServiceProvider).overview(ref.watch(teamFilterProvider), ref.watch(coordDeptProvider), ref.watch(coordOverviewOptionsProvider)), retry: (_, _) => null);
final coordRequestsProvider = FutureProvider.autoDispose<RequestList>((ref) => ref.watch(marketingCoordinationServiceProvider).requests(ref.watch(teamFilterProvider), ref.watch(coordDeptProvider), ref.watch(coordRequestQueryProvider)), retry: (_, _) => null);
final coordBoardProvider = FutureProvider.autoDispose<HandoverBoard>((ref) => ref.watch(marketingCoordinationServiceProvider).board(ref.watch(teamFilterProvider), ref.watch(coordDeptProvider)), retry: (_, _) => null);
final coordApprovalsProvider = FutureProvider.autoDispose<ApprovalList>((ref) => ref.watch(marketingCoordinationServiceProvider).approvals(ref.watch(teamFilterProvider), ref.watch(coordDeptProvider), ref.watch(coordApprovalQueryProvider)), retry: (_, _) => null);
final coordMeetingsProvider = FutureProvider.autoDispose<MeetingList>((ref) => ref.watch(marketingCoordinationServiceProvider).meetings(ref.watch(teamFilterProvider), ref.watch(coordDeptProvider), ref.watch(coordMeetingQueryProvider)), retry: (_, _) => null);
final coordMeetingProvider = FutureProvider.autoDispose.family<MeetingRow, String>((ref, id) => ref.watch(marketingCoordinationServiceProvider).meeting(id), retry: (_, _) => null);
final coordFollowUpsProvider = FutureProvider.autoDispose<FollowUpList>((ref) => ref.watch(marketingCoordinationServiceProvider).followUps(ref.watch(teamFilterProvider), ref.watch(coordDeptProvider), ref.watch(coordFollowUpQueryProvider)), retry: (_, _) => null);
final coordCalendarProvider = FutureProvider.autoDispose<FollowUpCalendar>((ref) {
  final m = ref.watch(coordCalendarMonthProvider);
  final month = '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
  return ref.watch(marketingCoordinationServiceProvider).followUpCalendar(ref.watch(teamFilterProvider), ref.watch(coordDeptProvider), month, ownerId: ref.watch(coordFollowUpQueryProvider).ownerId);
}, retry: (_, _) => null);

/// After a request, an approval, a meeting or a follow-up changes: every Coordinations read starts again (they all read the same records).
void refreshCoordinations(WidgetRef ref) {
  ref.invalidate(coordOverviewProvider);
  ref.invalidate(coordRequestsProvider);
  ref.invalidate(coordBoardProvider);
  ref.invalidate(coordApprovalsProvider);
  ref.invalidate(coordMeetingsProvider);
  ref.invalidate(coordMeetingProvider);
  ref.invalidate(coordFollowUpsProvider);
  ref.invalidate(coordCalendarProvider);
  ref.invalidate(coordSetupProvider);
}
