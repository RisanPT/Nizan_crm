import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/data/sales_report.dart';

/// Endpoint segments under /api/sales-reports.
const kSalesByCustomer = 'by-customer';
const kSalesByPackage = 'by-package';
const kSalesBySalesperson = 'by-salesperson';
const kSalesSummary = 'summary';
const kPaymentsByMode = 'by-payment-mode';

class SalesReportService {
  final Dio _dio;
  SalesReportService(this._dio);

  Future<SalesReport> get(
    String kind, {
    String? from,
    String? to,
    String? groupBy,
  }) async {
    try {
      final res = await _dio.get('/sales-reports/$kind', queryParameters: {
        'from': ?from,
        'to': ?to,
        'groupBy': ?groupBy,
      });
      return SalesReport.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load the report');
    }
  }
}
