import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/reports/data/financial_analyst_report.dart';

class FinancialReportService {
  final Dio _dio;
  FinancialReportService(this._dio);

  /// [month] is 'YYYY-MM'. Empty → current month (server default).
  Future<FinancialAnalystReport> getAnalystReport(String month) async {
    try {
      final res = await _dio.get('/reports/financial-analyst',
          queryParameters: {if (month.isNotEmpty) 'month': month});
      return FinancialAnalystReport.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to load report: ${e.message}');
    }
  }
}

final financialReportServiceProvider = Provider<FinancialReportService>((ref) {
  return FinancialReportService(ref.watch(dioProvider));
});

/// Family keyed by 'YYYY-MM'.
final financialAnalystReportProvider = FutureProvider.autoDispose
    .family<FinancialAnalystReport, String>((ref, month) async {
  return ref.watch(financialReportServiceProvider).getAnalystReport(month);
});
