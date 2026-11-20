import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The CRM team's work — backend /api/crm (routes/crmRoutes.js). Who may do what is decided by the server; the screens only hide what
/// would be refused anyway.
class CrmService {
  final Dio _dio;
  CrmService(this._dio);

  Map<String, dynamic> _body(Response res) => (res.data as Map).cast<String, dynamic>();

  Future<CrmMe> me() async {
    try {
      return CrmMe.fromJson(_body(await _dio.get('/crm/me')));
    } catch (e) {
      throw AppException(e, action: 'load your CRM access');
    }
  }

  static Map<String, dynamic> periodParams(ReportRange range, {String? memberId}) => {
    if (range.fromIso != null) 'from': range.fromIso,
    if (range.toIso != null) 'to': range.toIso,
    if (memberId != null && memberId.isNotEmpty) 'memberId': memberId,
  };

  Future<CrmOverview> overview(ReportRange range, {String? memberId}) async {
    try {
      return CrmOverview.fromJson(_body(await _dio.get('/crm/overview', queryParameters: periodParams(range, memberId: memberId))));
    } catch (e) {
      throw AppException(e, action: 'load the CRM figures');
    }
  }

  Future<CrmQueue> queue({String? scope, String? memberId, List<String>? types}) async {
    try {
      final res = await _dio.get('/crm/queue', queryParameters: {
        'scope': ?scope,
        if (memberId != null && memberId.isNotEmpty) 'memberId': memberId,
        if (types != null && types.isNotEmpty) 'types': types.join(','),
      });
      return CrmQueue.fromJson(_body(res));
    } catch (e) {
      throw AppException(e, action: 'load the CRM work');
    }
  }

  Future<CrmTeam> team() async {
    try {
      return CrmTeam.fromJson(_body(await _dio.get('/crm/team')));
    } catch (e) {
      throw AppException(e, action: 'load the CRM team');
    }
  }

  /// Gives [items] (type + id) to [ownerId] — or, with null, takes them back to Unassigned (the head only).
  Future<CrmAssignResult> assign(List<({String type, String id})> items, String? ownerId) async {
    try {
      final res = await _dio.post('/crm/assign', data: {
        'items': [for (final i in items) {'type': i.type, 'id': i.id}],
        'ownerId': ownerId ?? '',
      });
      return CrmAssignResult.fromJson(_body(res));
    } catch (e) {
      throw AppException(e, action: 'assign the work');
    }
  }

  Future<CrmCasePage> cases({String? status, String? kind, String? ownerId, bool overdue = false, String search = '', String? reviewId, int page = 1, int limit = 25}) async {
    try {
      final res = await _dio.get('/crm/cases', queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        if (ownerId != null && ownerId.isNotEmpty) 'ownerId': ownerId,
        if (overdue) 'overdue': '1',
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'reviewId': ?reviewId,
        'page': page,
        'limit': limit,
      });
      return CrmCasePage.fromJson(_body(res));
    } catch (e) {
      throw AppException(e, action: 'load the cases');
    }
  }

  Future<CrmCase> getCase(String id) async {
    try {
      return CrmCase.fromJson(_body(await _dio.get('/crm/cases/$id')));
    } catch (e) {
      throw AppException(e, action: 'load the case');
    }
  }

  Future<CrmCase> createCase(Map<String, dynamic> body) async {
    try {
      return CrmCase.fromJson(_body(await _dio.post('/crm/cases', data: body)));
    } catch (e) {
      throw AppException(e, action: 'open the case');
    }
  }

  Future<CrmCase> updateCase(String id, Map<String, dynamic> body) async {
    try {
      return CrmCase.fromJson(_body(await _dio.patch('/crm/cases/$id', data: body)));
    } catch (e) {
      throw AppException(e, action: 'update the case');
    }
  }

  Future<CrmCase> logActivity(String id, {required String type, String text = '', String outcome = ''}) async {
    try {
      return CrmCase.fromJson(_body(await _dio.post('/crm/cases/$id/activities', data: {'type': type, 'text': text, 'outcome': outcome})));
    } catch (e) {
      throw AppException(e, action: 'add to the case');
    }
  }

  Future<List<ReEngagementClient>> reEngagement({int months = 6}) async {
    try {
      final res = await _dio.get('/crm/re-engagement', queryParameters: {'months': months});
      return ((_body(res)['clients'] as List?) ?? const []).whereType<Map>().map((e) => ReEngagementClient.fromJson(e.cast<String, dynamic>())).toList();
    } catch (e) {
      throw AppException(e, action: 'load the clients to call');
    }
  }

  /// Opens a call case for each of [clients]; → (opened, skipped).
  Future<(int, int)> createCallCases(List<ReEngagementClient> clients, {String? ownerId}) async {
    try {
      final res = await _dio.post('/crm/re-engagement/cases', data: {
        'clients': [for (final c in clients) c.toRequest()],
        'ownerId': ?ownerId,
      });
      final b = _body(res);
      return ((b['created'] as List?)?.length ?? 0, (b['skipped'] as List?)?.length ?? 0);
    } catch (e) {
      throw AppException(e, action: 'make the call list');
    }
  }

  Future<CrmSettings> settings() async {
    try {
      return CrmSettings.fromJson(_body(await _dio.get('/crm/settings')));
    } catch (e) {
      throw AppException(e, action: 'load the CRM settings');
    }
  }

  Future<CrmSettings> saveSettings(Map<String, dynamic> body) async {
    try {
      return CrmSettings.fromJson(_body(await _dio.put('/crm/settings', data: body)));
    } catch (e) {
      throw AppException(e, action: 'save the CRM settings');
    }
  }

  /// The CRM report as a file — downloaded with the login header (the token never goes in the address). → (file name, bytes).
  Future<(String, List<int>)> downloadReport(ReportRange range, {required String format, String? memberId}) async {
    try {
      final res = await _dio.get<List<int>>(
        '/crm/report',
        queryParameters: {...periodParams(range, memberId: memberId), 'format': format},
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(minutes: 2)),
      );
      final disposition = res.headers.value('content-disposition') ?? '';
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
      return (m?.group(1) ?? 'CRM_Report_${range.fileTag}.$format', res.data ?? const <int>[]);
    } catch (e) {
      throw AppException(e, action: 'download the CRM report');
    }
  }
}

final crmServiceProvider = Provider<CrmService>((ref) => CrmService(ref.watch(dioProvider)));

final crmMeProvider = FutureProvider.autoDispose<CrmMe>((ref) => ref.watch(crmServiceProvider).me());

/// Which figures: a period, and one member (null = the whole team, or "me" for a member — the server decides).
class CrmOverviewQuery {
  final ReportRange range;
  final String? memberId;
  const CrmOverviewQuery(this.range, {this.memberId});
  @override
  bool operator ==(Object other) => other is CrmOverviewQuery && other.range == range && other.memberId == memberId;
  @override
  int get hashCode => Object.hash(range, memberId);
}

final crmOverviewProvider = FutureProvider.autoDispose.family<CrmOverview, CrmOverviewQuery>(
  (ref, q) => ref.watch(crmServiceProvider).overview(q.range, memberId: q.memberId),
);

class CrmQueueQuery {
  final String? scope;
  final String? memberId;
  final String? types;
  const CrmQueueQuery({this.scope, this.memberId, this.types});
  @override
  bool operator ==(Object other) => other is CrmQueueQuery && other.scope == scope && other.memberId == memberId && other.types == types;
  @override
  int get hashCode => Object.hash(scope, memberId, types);
}

final crmQueueProvider = FutureProvider.autoDispose.family<CrmQueue, CrmQueueQuery>(
  (ref, q) => ref.watch(crmServiceProvider).queue(scope: q.scope, memberId: q.memberId, types: q.types?.split(',')),
);

final crmTeamProvider = FutureProvider.autoDispose<CrmTeam>((ref) => ref.watch(crmServiceProvider).team());

class CrmCaseQuery {
  final String status; // active | open | in_progress | resolved | closed | '' (all)
  final bool overdue;
  final String? kind;
  final String? ownerId;
  final String search;
  final int page;
  const CrmCaseQuery({this.status = 'active', this.overdue = false, this.kind, this.ownerId, this.search = '', this.page = 1});
  CrmCaseQuery copyWith({String? status, bool? overdue, String? kind, bool clearKind = false, String? ownerId, bool clearOwner = false, String? search, int? page}) => CrmCaseQuery(
    status: status ?? this.status,
    overdue: overdue ?? this.overdue,
    kind: clearKind ? null : (kind ?? this.kind),
    ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
    search: search ?? this.search,
    page: page ?? this.page,
  );
  @override
  bool operator ==(Object other) =>
      other is CrmCaseQuery && other.status == status && other.overdue == overdue && other.kind == kind && other.ownerId == ownerId && other.search == search && other.page == page;
  @override
  int get hashCode => Object.hash(status, overdue, kind, ownerId, search, page);
}

final crmCasesProvider = FutureProvider.autoDispose.family<CrmCasePage, CrmCaseQuery>(
  (ref, q) => ref.watch(crmServiceProvider).cases(status: q.status, overdue: q.overdue, kind: q.kind, ownerId: q.ownerId, search: q.search, page: q.page),
);

final crmCaseProvider = FutureProvider.autoDispose.family<CrmCase, String>((ref, id) => ref.watch(crmServiceProvider).getCase(id));

/// The case(s) a review opened — for "View case" on the review.
final crmCasesForReviewProvider = FutureProvider.autoDispose.family<List<CrmCase>, String>(
  (ref, reviewId) async => (await ref.watch(crmServiceProvider).cases(status: '', reviewId: reviewId, limit: 10)).items,
);

final crmReEngagementProvider = FutureProvider.autoDispose.family<List<ReEngagementClient>, int>(
  (ref, months) => ref.watch(crmServiceProvider).reEngagement(months: months),
);

/// Overdue cases (for the sidebar badge): the count only.
final crmOverdueCasesProvider = FutureProvider.autoDispose<int>((ref) async {
  final page = await ref.watch(crmServiceProvider).cases(status: 'active', limit: 1);
  return page.counts['overdue'] ?? 0;
});

/// Who owns each pending booking request (booking id → owner) — for the Booking Requests screen. A member sees their own and the
/// unassigned; anything else is someone else's.
final crmBookingOwnersProvider = FutureProvider.autoDispose<Map<String, CrmQueueItem>>((ref) async {
  final svc = ref.watch(crmServiceProvider);
  final me = await ref.watch(crmMeProvider.future);
  final lists = me.seesTeam
      ? [await svc.queue(scope: 'all', types: const ['booking'])]
      : [await svc.queue(scope: 'mine', types: const ['booking']), await svc.queue(scope: 'unassigned', types: const ['booking'])];
  return {for (final q in lists) for (final i in q.items) i.id: i};
});

/// After anything changes CRM work: everything that shows it reloads.
void refreshCrm(WidgetRef ref) {
  ref.invalidate(crmOverviewProvider);
  ref.invalidate(crmQueueProvider);
  ref.invalidate(crmTeamProvider);
  ref.invalidate(crmCasesProvider);
  ref.invalidate(crmCaseProvider);
  ref.invalidate(crmCasesForReviewProvider);
  ref.invalidate(crmReEngagementProvider);
  ref.invalidate(crmOverdueCasesProvider);
  ref.invalidate(crmBookingOwnersProvider);
}
