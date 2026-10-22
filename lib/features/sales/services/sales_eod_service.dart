import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/sales/data/sales_eod_report.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

typedef SalesEodQuery = ({
  String? date,
  String? from,
  String? to,
  String? salesPersonId,
});

class SalesEodService {
  final Dio _dio;
  SalesEodService(this._dio);

  Future<SalesEodReport> getEodReport({
    String? date,
    String? from,
    String? to,
    String? salesPersonId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null && date.trim().isNotEmpty) {
        queryParams['date'] = date.trim();
      }
      if (from != null && from.trim().isNotEmpty) {
        queryParams['from'] = from.trim();
      }
      if (to != null && to.trim().isNotEmpty) {
        queryParams['to'] = to.trim();
      }
      if (salesPersonId != null && salesPersonId.trim().isNotEmpty) {
        queryParams['salesPersonId'] = salesPersonId.trim();
      }

      final res = await _dio.get(
        '/sales-reports/eod',
        queryParameters: queryParams,
      );

      final data = (res.data as Map).cast<String, dynamic>();
      return SalesEodReport.fromJson(data);
    } catch (e) {
      throw AppException(e, action: 'load End of Day (EOD) report');
    }
  }
}

final salesEodServiceProvider = Provider<SalesEodService>((ref) {
  return SalesEodService(ref.watch(dioProvider));
});

final salesEodReportProvider =
    FutureProvider.family<SalesEodReport, SalesEodQuery>((ref, query) async {
  final service = ref.watch(salesEodServiceProvider);
  return service.getEodReport(
    date: query.date,
    from: query.from,
    to: query.to,
    salesPersonId: query.salesPersonId,
  );
});
