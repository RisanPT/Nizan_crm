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
}

final salesTargetServiceProvider =
    Provider<SalesTargetService>((ref) => SalesTargetService(ref.watch(dioProvider)));

/// The signed-in user's target and progress for a month.
final myTargetProvider = FutureProvider.autoDispose
    .family<MyTargetProgress, TargetPeriod>((ref, p) => ref.watch(salesTargetServiceProvider).getMine(p));

/// Every salesperson's target and progress (sales managers only).
final teamTargetsProvider = FutureProvider.autoDispose
    .family<TeamTargets, TargetPeriod>((ref, p) => ref.watch(salesTargetServiceProvider).getTeam(p));

/// Whether this role may set targets — mirrors the backend `canSetTargets`.
bool canSetSalesTargets(String? role) {
  final r = (role ?? '').trim().toLowerCase();
  return r == 'admin' || r == 'manager' || (r.startsWith('sales') && r.endsWith('manager'));
}
