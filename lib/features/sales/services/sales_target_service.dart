import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/sales/data/sales_target.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Month key for target providers.
typedef TargetPeriod = ({int month, int year});

class SalesTargetService {
  final Dio _dio;
  SalesTargetService(this._dio);

  Map<String, dynamic> _map(Object? data) => (data as Map).cast<String, dynamic>();

  Future<MyTargetProgress> getMine(TargetPeriod p) async {
    try {
      final res = await _dio.get('/sales-targets/me',
          queryParameters: {'month': p.month, 'year': p.year});
      return MyTargetProgress.fromJson(_map(res.data));
    } catch (e) {
      throw AppException(e, action: 'load your target');
    }
  }

  Future<TeamTargets> getTeam(TargetPeriod p) async {
    try {
      final res = await _dio.get('/sales-targets',
          queryParameters: {'month': p.month, 'year': p.year});
      return TeamTargets.fromJson(_map(res.data));
    } catch (e) {
      throw AppException(e, action: 'load sales targets');
    }
  }

  Future<void> save(TargetPeriod p, List<SalesTargetInput> targets) async {
    try {
      await _dio.put('/sales-targets', data: {
        'month': p.month,
        'year': p.year,
        'targets': [for (final t in targets) t.toJson()],
      });
    } catch (e) {
      throw AppException(e, action: 'save the targets');
    }
  }

  /// Copies last month's targets into [p] for people without one. Returns
  /// how many were copied.
  Future<int> copyLastMonth(TargetPeriod p) async {
    try {
      final res = await _dio.post('/sales-targets/copy',
          data: {'month': p.month, 'year': p.year});
      return (_map(res.data)['copied'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw AppException(e, action: "copy last month's targets");
    }
  }

  /// Combined (pool) targets overlapping the month [p], with progress.
  Future<List<CombinedTarget>> getCombined(TargetPeriod p) async {
    try {
      final res = await _dio.get('/sales-targets/combined',
          queryParameters: {'month': p.month, 'year': p.year});
      return [
        for (final t in (_map(res.data)['targets'] as List? ?? const []))
          CombinedTarget.fromJson((t as Map).cast<String, dynamic>()),
      ];
    } catch (e) {
      throw AppException(e, action: 'load the combined targets');
    }
  }

  /// Creates a combined target, or updates [id] when given.
  Future<void> saveCombined(CombinedTargetInput input, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/sales-targets/combined', data: input.toJson());
      } else {
        await _dio.put('/sales-targets/combined/$id', data: input.toJson());
      }
    } catch (e) {
      throw AppException(e, action: 'save the combined target');
    }
  }

  Future<void> deleteCombined(String id) async {
    try {
      await _dio.delete('/sales-targets/combined/$id');
    } catch (e) {
      throw AppException(e, action: 'delete the combined target');
    }
  }
}

final salesTargetServiceProvider =
    Provider<SalesTargetService>((ref) => SalesTargetService(ref.watch(dioProvider)));

/// The signed-in user's target and progress for a month.
final myTargetProvider = FutureProvider.autoDispose
    .family<MyTargetProgress, TargetPeriod>((ref, p) => ref.watch(salesTargetServiceProvider).getMine(p));

/// Every salesperson's target and progress (sales managers only).
final teamTargetsProvider = FutureProvider.autoDispose
    .family<TeamTargets, TargetPeriod>((ref, p) => ref.watch(salesTargetServiceProvider).getTeam(p));

/// Combined (pool) targets that overlap a month.
final combinedTargetsProvider = FutureProvider.autoDispose
    .family<List<CombinedTarget>, TargetPeriod>((ref, p) => ref.watch(salesTargetServiceProvider).getCombined(p));

/// A sales manager's target is the team total — mirrors the backend
/// `isSalesManagerRole`.
bool isSalesManagerRole(String? role) =>
    RegExp(r'^sales.*manager$', caseSensitive: false).hasMatch((role ?? '').trim());

/// Whether this role may set targets — mirrors the backend `canSetTargets`.
bool canSetSalesTargets(String? role) {
  final r = (role ?? '').trim().toLowerCase();
  return r == 'admin' || r == 'manager' || (r.startsWith('sales') && r.endsWith('manager'));
}
