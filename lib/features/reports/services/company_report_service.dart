import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';

import 'package:nizan_crm/features/reports/data/company_report.dart';
import 'package:nizan_crm/features/reports/data/report_folder.dart';
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
    } catch (e) {
      throw AppException(e, action: 'load reports');
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
    String? folderId,
  }) async {
    try {
      final form = FormData.fromMap({
        'title': title,
        'department': department,
        'description': description,
        'period': period,
        if (folderId != null && folderId.isNotEmpty) 'folder': folderId,
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
    } catch (e) {
      throw AppException(e, action: 'upload the report');
    }
  }

  Future<List<int>> downloadBytes(String id) async {
    try {
      final res = await _dio.get<List<int>>('/company-reports/$id/download',
          options: Options(responseType: ResponseType.bytes));
      return res.data ?? const <int>[];
    } catch (e) {
      throw AppException(e, action: 'download the report');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/company-reports/$id');
    } catch (e) {
      throw AppException(e, action: 'delete the report');
    }
  }

  /// Move a report into a folder ('' / null → Unfiled).
  Future<void> moveToFolder(String id, String? folderId) async {
    try {
      final form = FormData.fromMap({'folder': folderId ?? ''});
      await _dio.put('/company-reports/$id', data: form);
    } catch (e) {
      throw AppException(e, action: 'move the report');
    }
  }

  // ── Folders ────────────────────────────────────────────────────────────────

  Future<List<ReportFolder>> getFolders({String? department}) async {
    try {
      final qp = <String, dynamic>{};
      if (department != null && department.isNotEmpty && department != 'All') {
        qp['department'] = department;
      }
      final res = await _dio.get('/company-reports/folders',
          queryParameters: qp.isEmpty ? null : qp);
      return (res.data as List)
          .map((e) => ReportFolder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load folders');
    }
  }

  Future<ReportFolder> createFolder(String name, {String? department}) async {
    try {
      final res = await _dio.post('/company-reports/folders', data: {
        'name': name,
        if (department != null && department.isNotEmpty) 'department': department,
      });
      return ReportFolder.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'create the folder');
    }
  }

  Future<ReportFolder> renameFolder(String id, String name) async {
    try {
      final res =
          await _dio.put('/company-reports/folders/$id', data: {'name': name});
      return ReportFolder.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'rename the folder');
    }
  }

  Future<void> deleteFolder(String id) async {
    try {
      await _dio.delete('/company-reports/folders/$id');
    } catch (e) {
      throw AppException(e, action: 'delete the folder');
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

/// Folders for a department (empty key → the caller's own department).
final reportFoldersProvider =
    FutureProvider.family<List<ReportFolder>, String>((ref, department) async {
  return ref.watch(companyReportServiceProvider).getFolders(department: department);
});
