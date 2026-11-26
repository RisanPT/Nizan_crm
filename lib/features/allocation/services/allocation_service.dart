import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// The smart booking allocation — backend /api/allocation and /api/artist-teams. The server decides who may do what; refusals come
/// back as [AllocationRefusal] (in the server's words), anything else as [AppException].
class AllocationService {
  AllocationService(this._dio);
  final Dio _dio;

  Map<String, dynamic> _body(Response<dynamic> res) => (res.data as Map).cast<String, dynamic>();

  Future<T> _call<T>(String action, Future<Response<dynamic>> Function() call, T Function(Map<String, dynamic>) parse) async {
    try {
      return parse(_body(await call()));
    } catch (e) {
      final refusal = AllocationRefusal.of(e);
      if (refusal != null) throw refusal;
      throw AppException(e, action: action);
    }
  }

  Future<AllocationSettings> settings() => _call('load the allocation settings', () => _dio.get('/allocation/settings'), AllocationSettings.fromJson);
  Future<AllocationSettings> saveSettings(Map<String, dynamic> body) => _call('save the allocation settings', () => _dio.put('/allocation/settings', data: body), AllocationSettings.fromJson);

  Future<TeamsPage> teams({String? day, bool inactive = false}) =>
      _call('load the artist teams', () => _dio.get('/artist-teams', queryParameters: {'day': ?day, if (inactive) 'inactive': '1'}), TeamsPage.fromJson);
  Future<List<TeamCandidate>> candidates() => _call('load the artists', () => _dio.get('/artist-teams/candidates'), (j) => [for (final p in (j['people'] as List? ?? const [])) TeamCandidate.fromJson((p as Map).cast<String, dynamic>())]);
  Future<void> createTeam(Map<String, dynamic> body) => _call('add the team', () => _dio.post('/artist-teams', data: body), (_) {});
  Future<void> updateTeam(String id, Map<String, dynamic> body) => _call('save the team', () => _dio.put('/artist-teams/$id', data: body), (_) {});
  Future<void> reorderTeams(List<String> ids) => _call('save the rotation', () => _dio.put('/artist-teams/order', data: {'ids': ids}), (_) {});
  Future<void> deactivateTeam(String id) => _call('take the team off the rotation', () => _dio.delete('/artist-teams/$id'), (_) {});

  /// Who has each package of a booking, or why it waits — for the salespeople too.
  Future<BookingAllocationStatus> bookingStatus(String bookingId) => _call('load the artist allocation', () => _dio.get('/allocation/booking/$bookingId/status'), BookingAllocationStatus.fromJson);
  /// Add Booking, before saving: who would take this booking (nothing is saved).
  Future<AllocationPreview> preview(Map<String, dynamic> draft) => _call('check the artist', () => _dio.post('/allocation/preview', data: draft), AllocationPreview.fromJson);
  Future<BookingAllocation> forBooking(String bookingId) => _call('load the suggestions', () => _dio.get('/allocation/booking/$bookingId'), BookingAllocation.fromJson);

  /// Gives packages of a booking to teams. [picks]: unitKey → (teamId, assistantIds?, overrideReason?). [confirmConflicts] answers
  /// "assign anyway" to a clash the server reported.
  Future<Map<String, dynamic>> confirm({required String bookingId, String? updatedAt, required List<Map<String, dynamic>> picks, String source = 'requests', bool confirmConflicts = false}) => _call(
        'allocate the artist',
        () => _dio.post('/allocation/confirm', data: {'bookingId': bookingId, 'bookingUpdatedAt': ?updatedAt, 'picks': picks, 'source': source}, options: confirmConflicts ? Options(headers: {'X-Confirm-Artist-Conflict': '1'}) : null),
        (j) => j,
      );
  Future<List<Map<String, dynamic>>> plan(List<String> bookingIds) => _call('suggest the teams', () => _dio.post('/allocation/plan', data: {'bookingIds': bookingIds}), (j) => [for (final x in (j['items'] as List? ?? const [])) (x as Map).cast<String, dynamic>()]);
  Future<List<Map<String, dynamic>>> confirmMany(List<Map<String, dynamic>> items) => _call('allocate the artists', () => _dio.post('/allocation/confirm-many', data: {'items': items}), (j) => [for (final x in (j['results'] as List? ?? const [])) (x as Map).cast<String, dynamic>()]);
  Future<void> approveExtra(String allocationId) => _call('approve the extra slot', () => _dio.post('/allocation/$allocationId/approve'), (_) {});
  Future<void> rejectExtra(String allocationId, {String note = ''}) => _call('turn down the extra slot', () => _dio.post('/allocation/$allocationId/reject', data: {'note': note}), (_) {});

  Future<DayBoard> day(String dayIso) => _call('load the allocation board', () => _dio.get('/allocation/day', queryParameters: {'date': dayIso}), DayBoard.fromJson);
  Future<AllocationMetrics> metrics({String? from, String? to}) => _call('load the allocation figures', () => _dio.get('/allocation/metrics', queryParameters: {'from': ?from, 'to': ?to}), AllocationMetrics.fromJson);
}

final allocationServiceProvider = Provider<AllocationService>((ref) => AllocationService(ref.watch(dioProvider)));

final allocationSettingsProvider = FutureProvider.autoDispose<AllocationSettings>((ref) => ref.watch(allocationServiceProvider).settings(), retry: (_, _) => null);
final artistTeamsProvider = FutureProvider.autoDispose.family<TeamsPage, String>((ref, day) => ref.watch(allocationServiceProvider).teams(day: day, inactive: true), retry: (_, _) => null);
final teamCandidatesProvider = FutureProvider.autoDispose<List<TeamCandidate>>((ref) => ref.watch(allocationServiceProvider).candidates(), retry: (_, _) => null);
final bookingAllocationProvider = FutureProvider.autoDispose.family<BookingAllocation, String>((ref, id) => ref.watch(allocationServiceProvider).forBooking(id), retry: (_, _) => null);
final dayBoardProvider = FutureProvider.autoDispose.family<DayBoard, String>((ref, day) => ref.watch(allocationServiceProvider).day(day), retry: (_, _) => null);
final allocationMetricsProvider = FutureProvider.autoDispose<AllocationMetrics>((ref) => ref.watch(allocationServiceProvider).metrics(), retry: (_, _) => null);

/// After a change: the teams, the board, the suggestions and the settings read again.
void refreshAllocation(WidgetRef ref) {
  ref.invalidate(allocationSettingsProvider);
  ref.invalidate(artistTeamsProvider);
  ref.invalidate(teamCandidatesProvider);
  ref.invalidate(bookingAllocationProvider);
  ref.invalidate(dayBoardProvider);
  ref.invalidate(allocationMetricsProvider);
}

/// An India-time day as 'YYYY-MM-DD'.
String istDayIso(DateTime d) {
  final t = d.toUtc().add(const Duration(hours: 5, minutes: 30));
  return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
final bookingAllocationStatusProvider = FutureProvider.autoDispose.family<BookingAllocationStatus, String>((ref, id) => ref.watch(allocationServiceProvider).bookingStatus(id), retry: (_, _) => null);
