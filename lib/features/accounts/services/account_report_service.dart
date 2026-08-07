import 'package:dio/dio.dart';
import 'package:nizan_crm/features/accounts/data/account_report.dart';

class AccountReportService {
  final Dio _dio;

  AccountReportService(this._dio);

  Future<List<AccountReport>> getReports() async {
    final response = await _dio.get('/account-reports');
    final data = response.data as List;
    return data.map((e) => AccountReport.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AccountReport> uploadReport({
    required String title,
    String? filePath,
    List<int>? bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'title': title,
    });
    
    if (bytes != null) {
      formData.files.add(MapEntry(
        'file',
        MultipartFile.fromBytes(bytes, filename: filename),
      ));
    } else if (filePath != null) {
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(filePath, filename: filename),
      ));
    }

    final response = await _dio.post(
      '/account-reports',
      data: formData,
    );
    return AccountReport.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteReport(String id) async {
    await _dio.delete('/account-reports/$id');
  }
}
