import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/error_message.dart';
import 'package:nizan_crm/features/reports/data/company_report.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class CompanyReportService {
  final Dio _dio;
  CompanyReportService(this._dio);

  Future<List<CompanyReport>> getReports({String? department, String? scope}) async {
    try {
      final qp = <String, dynamic>{};
      if (department != null && department != 'All') qp['department'] = department;
      if (scope != null && scope.isNotEmpty) qp['scope'] = scope;
      final res = await _dio.get('/company-reports', queryParameters: qp.isEmpty ? null : qp);
      return (res.data as List).map((e) => CompanyReport.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load reports'));
    }
  }

  Future<void> upload({
    required String title,
    required String department,
    String description = '',
    String period = '',
    String? filePath,
    List<int>? bytes,
    required String filename,
    List<String> visibleToRoles = const [],
  }) async {
    try {
      final form = FormData.fromMap({
        'title': title,
        'department': department,
        'description': description,
        'period': period,
      });
      for (final r in visibleToRoles) {
        form.fields.add(MapEntry('visibleToRoles', r));
      }
      if (bytes != null) {
        form.files.add(MapEntry('file', MultipartFile.fromBytes(bytes, filename: filename)));
      } else if (filePath != null) {
        form.files.add(MapEntry('file', await MultipartFile.fromFile(filePath, filename: filename)));
      }
      await _dio.post('/company-reports', data: form);
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to upload the report'));
    }
  }

  Future<List<int>> downloadBytes(String id) async {
    try {
      final res = await _dio.get<List<int>>('/company-reports/$id/download',
          options: Options(responseType: ResponseType.bytes));
      return res.data ?? const <int>[];
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to download the report'));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/company-reports/$id');
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to delete the report'));
    }
  }
}

final companyReportServiceProvider =
    Provider<CompanyReportService>((ref) => CompanyReportService(ref.watch(dioProvider)));

/// All reports the current user may see (server-filtered by department/role).
final companyReportsProvider = FutureProvider<List<CompanyReport>>((ref) async {
  return ref.watch(companyReportServiceProvider).getReports();
});

/// A department head's view of everything their team members uploaded.
final teamReportsProvider = FutureProvider<List<CompanyReport>>((ref) async {
  return ref.watch(companyReportServiceProvider).getReports(scope: 'team');
});
