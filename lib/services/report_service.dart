import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/dio_provider.dart';
import '../core/providers/auth_provider.dart';

final reportServiceProvider = Provider<ReportService>((ref) {
  final dio = ref.watch(dioProvider);
  final auth = ref.watch(authControllerProvider);
  return ReportService(dio, auth.session?.token ?? '');
});

class ReportService {
  final Dio _dio;
  final String _token;

  ReportService(this._dio, this._token);

  Future<void> downloadFinanceReport({
    required int month,
    required int year,
    String? employeeId,
    required String format, // 'pdf' | 'csv'
  }) async {
    final baseUrl = _dio.options.baseUrl;
    final queryParams = {
      'month': month,
      'year': year,
      if (employeeId != null && employeeId != 'all') 'employeeId': employeeId,
      'format': format,
      'token': _token, // Pass token in query for browser download if needed, or use headers
    };

    // Construct the URL
    final uri = Uri.parse('$baseUrl/reports/finance').replace(
      queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
    );

    // Using url_launcher to open in browser for direct download
    // Ensure the backend can handle token in query if using this, or use a custom download logic
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $uri';
    }
  }
}
