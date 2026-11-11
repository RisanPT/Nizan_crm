import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/sales/data/sales_overview.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Inclusive IST day window ('YYYY-MM-DD') + optional salesperson filter.
typedef SalesOverviewQuery = ({String from, String to, String? salesPersonId});

class SalesOverviewService {
  final Dio _dio;
  SalesOverviewService(this._dio);

  Future<SalesOverview> load(SalesOverviewQuery q) async {
    try {
      final res = await _dio.get('/dashboard/sales-overview', queryParameters: {
        'from': q.from,
        'to': q.to,
        if (q.salesPersonId != null && q.salesPersonId!.isNotEmpty) 'salesPersonId': q.salesPersonId,
      });
      return SalesOverview.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException(e, action: 'load the sales dashboard');
    }
  }
}

final salesOverviewServiceProvider = Provider<SalesOverviewService>(
  (ref) => SalesOverviewService(ref.watch(dioProvider)),
);

/// Sales Dashboard data. autoDispose: leaving the screen drops it, so coming
/// back always shows the latest numbers.
final salesOverviewProvider =
    FutureProvider.autoDispose.family<SalesOverview, SalesOverviewQuery>(
  (ref, q) => ref.watch(salesOverviewServiceProvider).load(q),
);
