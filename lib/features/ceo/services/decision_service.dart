import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/ceo/data/decision_models.dart';
import 'package:nizan_crm/features/ceo/services/ceo_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Which part of the desk: what is waiting, or what was decided.
class DecisionFilter {
  const DecisionFilter({this.decided = false, this.kind, this.status});
  final bool decided;
  final DecisionKind? kind;

  /// For the decided tab: only this outcome (approved / rejected).
  final DecisionStatus? status;

  @override
  bool operator ==(Object other) => other is DecisionFilter && other.decided == decided && other.kind == kind && other.status == status;

  @override
  int get hashCode => Object.hash(decided, kind, status);
}

class DecisionService {
  DecisionService(this._dio);
  final Dio _dio;

  Future<DecisionQueue> queue(DecisionFilter f, {String? cursor}) async {
    try {
      final res = await _dio.get('/decisions/queue', queryParameters: {
        'scope': f.decided ? 'decided' : 'open',
        if (f.kind != null) 'kind': f.kind!.wire,
        if (f.status != null) 'status': f.status!.name,
        'cursor': ?cursor,
      });
      return DecisionQueue.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'load the decisions');
    }
  }

  Future<DecisionRequest> one(String id) async {
    try {
      final res = await _dio.get('/decisions/$id');
      return DecisionRequest.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'load this decision');
    }
  }

  /// Approve / reject / defer. Throws [DecisionConflict] when the server refuses with something to say (somebody else decided
  /// first, the item changed, a reason is missing); any other failure is an [AppException].
  Future<DecisionRequest> decide(String id, DecisionAction action, {String note = '', DateTime? until}) async {
    try {
      final res = await _dio.post('/decisions/$id/decide', data: {
        'action': action.wire,
        if (note.trim().isNotEmpty) 'note': note.trim(),
        if (until != null) 'until': until.toUtc().toIso8601String(),
      });
      return DecisionRequest.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      final conflict = conflictFrom(e);
      if (conflict != null) throw conflict;
      throw AppException(e, action: 'record your decision');
    } catch (e) {
      throw AppException(e, action: 'record your decision');
    }
  }

  Future<DecisionPolicy> policy() async {
    try {
      final res = await _dio.get('/decision-policy');
      return DecisionPolicy.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'load the decision rules');
    }
  }

  /// Save all three limits (null = off) and the hiring switch. Throws [DecisionConflict] for what the server explains
  /// (NO_LEADERSHIP_ACCOUNT, a limit out of range).
  Future<DecisionPolicy> savePolicy({double? expense, double? payout, double? projectBudget, required bool hiring}) async {
    try {
      final res = await _dio.put('/decision-policy', data: {
        'spendLimits': {'expense': expense, 'payout': payout, 'projectBudget': projectBudget},
        'hiringPlansNeedLeadership': hiring,
      });
      return DecisionPolicy.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      final conflict = conflictFrom(e);
      if (conflict != null) throw conflict;
      throw AppException(e, action: 'save the decision rules');
    } catch (e) {
      throw AppException(e, action: 'save the decision rules');
    }
  }
}

/// The server's own explanation of a refusal (409 / 400 with a `code`), or null when it is not one.
DecisionConflict? conflictFrom(DioException e) {
  final status = e.response?.statusCode;
  final data = e.response?.data;
  if ((status != 409 && status != 400) || data is! Map || data['code'] == null) return null;
  final d = data['decision'];
  return DecisionConflict(
    code: data['code'].toString(),
    message: data['message']?.toString() ?? 'This could not be done.',
    status: status!,
    decision: d is Map ? DecisionOutcome.fromJson(Map<String, dynamic>.from(d)) : null,
    field: data['field']?.toString(),
  );
}

final decisionServiceProvider = Provider<DecisionService>((ref) => DecisionService(ref.watch(dioProvider)));

final decisionQueueProvider = FutureProvider.autoDispose.family<DecisionQueue, DecisionFilter>(
  (ref, f) => ref.watch(decisionServiceProvider).queue(f),
  retry: (_, _) => null,
);

/// One request with its history (the detail sheet).
final decisionDetailProvider = FutureProvider.autoDispose.family<DecisionRequest, String>(
  (ref, id) => ref.watch(decisionServiceProvider).one(id),
  retry: (_, _) => null,
);

final decisionPolicyProvider = FutureProvider.autoDispose<DecisionPolicy>((ref) => ref.watch(decisionServiceProvider).policy(), retry: (_, _) => null);

/// How many things wait for the leaders — the badge on the Decisions tab. Read from the inbox the home already loads.
final leadershipOpenCountProvider = Provider.autoDispose<int>((ref) {
  final inbox = ref.watch(ceoInboxProvider);
  return inbox.maybeWhen(data: (i) => i.needsYou, orElse: () => 0);
});
