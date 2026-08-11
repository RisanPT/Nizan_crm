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

  /// Modify a report: rename its title and/or replace the file. Pass [bytes]
  /// (web) or [filePath] (mobile) + [filename] only when replacing the file.
  Future<AccountReport> updateReport({
    required String id,
    required String title,
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    final formData = FormData.fromMap({'title': title});

    if (bytes != null && filename != null) {
      formData.files.add(MapEntry(
        'file',
        MultipartFile.fromBytes(bytes, filename: filename),
      ));
    } else if (filePath != null && filename != null) {
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(filePath, filename: filename),
      ));
    }

    final response = await _dio.put('/account-reports/$id', data: formData);
    return AccountReport.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetch the raw file bytes via the API (streams from Cloudinary server-side
  /// with the correct content-type), so the client can save a valid file.
  Future<List<int>> downloadBytes(String id) async {
    final res = await _dio.get<List<int>>(
      '/account-reports/$id/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? const <int>[];
  }

  Future<void> deleteReport(String id) async {
    await _dio.delete('/account-reports/$id');
  }
}
