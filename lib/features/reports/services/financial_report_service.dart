import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/reports/data/financial_analyst_report.dart';

class FinancialReportService {
  final Dio _dio;
  FinancialReportService(this._dio);

  /// [key] is 'YYYY-MM' (a month), or two days 'YYYY-MM-DD..YYYY-MM-DD' (see [analystKeyFor]). Empty → current month (server default).
  Future<FinancialAnalystReport> getAnalystReport(String key) async {
    try {
      final days = key.split('..');
      final res = await _dio.get('/reports/financial-analyst', queryParameters: {
        if (days.length == 2) ...{'from': days[0], 'to': days[1]} else if (key.isNotEmpty) 'month': key,
      });
      return FinancialAnalystReport.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load the report');
    }
  }
}

final financialReportServiceProvider = Provider<FinancialReportService>((ref) {
  return FinancialReportService(ref.watch(dioProvider));
});

/// The key of a stretch of days for [financialAnalystReportProvider]; a month's key is just 'YYYY-MM'.
String analystKeyFor(ReportRange range) => '${range.fromIso}..${range.toIso}';

/// Family keyed by 'YYYY-MM', or by two days (see [analystKeyFor]).
final financialAnalystReportProvider = FutureProvider.autoDispose
    .family<FinancialAnalystReport, String>((ref, month) async {
  return ref.watch(financialReportServiceProvider).getAnalystReport(month);
});
