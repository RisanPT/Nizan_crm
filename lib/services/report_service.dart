import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/dio_provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/error/errors.dart';
import '../core/utils/report_range.dart';

final reportServiceProvider = Provider<ReportService>((ref) {
  final dio = ref.watch(dioProvider);
  final session = ref.watch(authSessionProvider);
  return ReportService(dio, session?.token ?? '');
});

class ReportService {
  final Dio _dio;
  final String _token;

  ReportService(this._dio, this._token);

  /// The address of the finance report for the days in [range] (from and to, both inclusive). [range] needs both ends.
  static Uri financeReportUri({
    required String baseUrl,
    required String token,
    required ReportRange range,
    String? employeeId,
    required String format, // 'pdf' | 'xlsx' (Excel) | 'csv'
  }) {
    final from = range.fromIso, to = range.toIso;
    if (from == null || to == null) {
      // the server builds this file from every entry in the range, so it needs both ends
      throw const AppException(null, action: 'make the finance report: choose the dates it is for');
    }
    final queryParams = {
      'from': from,
      'to': to,
      if (employeeId != null && employeeId != 'all') 'employeeId': employeeId,
      'format': format,
      'token': token, // Pass token in query for browser download if needed, or use headers
    };
    return Uri.parse('$baseUrl/reports/finance').replace(queryParameters: queryParams);
  }

  /// Collections and expenses for the days in [range] — as a PDF, an Excel sheet or a CSV. Each expense is on one
  /// row with the work (client, booking number) it belongs to.
  Future<void> downloadFinanceReport({
    required ReportRange range,
    String? employeeId,
    required String format, // 'pdf' | 'xlsx' (Excel) | 'csv'
  }) async {
    final uri = financeReportUri(baseUrl: _dio.options.baseUrl, token: _token, range: range, employeeId: employeeId, format: format);

    // Using url_launcher to open in browser for direct download
    // Ensure the backend can handle token in query if using this, or use a custom download logic
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Don't put the URL in the message: it carries the auth token.
      throw const AppException(null, action: 'open the finance report');
    }
  }
}
