import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/data/manpower.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final manpowerServiceProvider = Provider((ref) => ManpowerService(ref.watch(dioProvider)));

/// Manpower requests: all of them for HR; for everyone else the ones they asked, run, own or have to answer. [projectId]
/// narrows it to one project. Reloaded by [ManpowerService] callers with `ref.invalidate`.
final manpowerRequestsProvider = FutureProvider.autoDispose.family<List<ManpowerRequest>, String?>(
  (ref, projectId) => ref.watch(manpowerServiceProvider).list(projectId: projectId),
  retry: (_, _) => null,
);

/// Who is on a project, for how much of their time and when.
final projectTeamProvider = FutureProvider.autoDispose.family<List<TeamMember>, String>(
  (ref, projectId) => ref.watch(manpowerServiceProvider).team(projectId),
  retry: (_, _) => null,
);

/// The staff with how much of their time is spoken for in a window (HR only).
final manpowerAvailabilityProvider = FutureProvider.autoDispose.family<List<AvailablePerson>, AvailabilityQuery>(
  (ref, q) => ref.watch(manpowerServiceProvider).availability(q),
  retry: (_, _) => null,
);

String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ManpowerService {
  final Dio _dio;
  ManpowerService(this._dio);

  Future<List<ManpowerRequest>> list({String? projectId, String scope = 'all'}) => _guard('load the manpower requests', () async {
    final res = await _dio.get('/manpower', queryParameters: {'scope': scope, 'projectId': ?projectId});
    return [for (final e in (res.data as List)) ManpowerRequest.fromJson((e as Map).cast<String, dynamic>())];
  });

  /// A project asks HR for people. Dates are days (no time).
  Future<ManpowerRequest> raise(
    String projectId, {
    required String roleTitle,
    required int headcount,
    required DateTime startDate,
    required DateTime endDate,
    required int allocationPercent,
    required String reason,
    String skills = '',
    bool urgent = false,
    double? estimatedCost,
  }) => _guard('ask for more people', () async {
    final res = await _dio.post(
      '/projects/$projectId/manpower',
      data: {
        'roleTitle': roleTitle.trim(),
        'headcount': headcount,
        'startDate': _day(startDate),
        'endDate': _day(endDate),
        'allocationPercent': allocationPercent,
        'reason': reason.trim(),
        if (skills.trim().isNotEmpty) 'skills': skills.trim(),
        'urgency': urgent ? 'urgent' : 'normal',
        if (estimatedCost != null && estimatedCost > 0) 'estimatedCost': estimatedCost,
      },
    );
    return ManpowerRequest.fromJson((res.data as Map).cast<String, dynamic>());
  });

  /// HR covers seats. A [ManpowerRefusal] (conflict / needs budget) comes back as the cause of the thrown error.
  Future<ManpowerRequest> handle(String id, List<ManpowerChoice> choices, {bool assignAnyway = false}) => _guard('cover the seats', () async {
    final res = await _dio.post('/manpower/$id/handle', data: {'lines': [for (final c in choices) c.toJson()], if (assignAnyway) 'assignAnyway': true});
    return ManpowerRequest.fromJson((res.data as Map).cast<String, dynamic>());
  });

  /// The head of a person's department lets them go ([approve]) or says no (with a reason in [note]).
  Future<ManpowerRequest> release(String id, String lineId, {required bool approve, String note = ''}) =>
      _guard(approve ? 'let them go' : 'say no', () async {
        final res = await _dio.post('/manpower/$id/lines/$lineId/release', data: {'approve': approve, if (note.trim().isNotEmpty) 'note': note.trim()});
        return ManpowerRequest.fromJson((res.data as Map).cast<String, dynamic>());
      });

  /// HR puts a new hire on the project once they have joined.
  Future<ManpowerRequest> allocateHire(String id, String lineId, String employeeId, {int? percent, bool assignAnyway = false}) =>
      _guard('place the new hire', () async {
        final res = await _dio.post(
          '/manpower/$id/lines/$lineId/allocate',
          data: {'employeeId': employeeId, 'percent': ?percent, if (assignAnyway) 'assignAnyway': true},
        );
        return ManpowerRequest.fromJson((res.data as Map).cast<String, dynamic>());
      });

  Future<ManpowerRequest> decline(String id, String note) => _guard('decline the request', () async {
    final res = await _dio.post('/manpower/$id/decline', data: {'note': note.trim()});
    return ManpowerRequest.fromJson((res.data as Map).cast<String, dynamic>());
  });

  Future<ManpowerRequest> cancel(String id, {String note = ''}) => _guard('take the request back', () async {
    final res = await _dio.post('/manpower/$id/cancel', data: {if (note.trim().isNotEmpty) 'note': note.trim()});
    return ManpowerRequest.fromJson((res.data as Map).cast<String, dynamic>());
  });

  Future<List<AvailablePerson>> availability(AvailabilityQuery q) => _guard('load the staff', () async {
    final res = await _dio.get(
      '/manpower/availability',
      queryParameters: {
        if (q.from != null) 'from': _day(q.from!),
        if (q.to != null) 'to': _day(q.to!),
        'percent': q.percent,
        if (q.search.trim().isNotEmpty) 'q': q.search.trim(),
      },
    );
    return [for (final e in (res.data as List)) AvailablePerson.fromJson((e as Map).cast<String, dynamic>())];
  });

  Future<List<TeamMember>> team(String projectId) => _guard('load the team', () async {
    final res = await _dio.get('/projects/$projectId/team');
    return [for (final e in (res.data as List)) TeamMember.fromJson((e as Map).cast<String, dynamic>())];
  });
}

Future<T> _guard<T>(String action, Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    throw AppException(e, action: action);
  }
}
