import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/files/data/employee_document_models.dart';

class EmployeeDocumentService {
  final Dio _dio;
  EmployeeDocumentService(this._dio);

  List<EmployeeDocument> _list(dynamic data) {
    final raw = data is List ? data : const [];
    return raw.map((e) => EmployeeDocument.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<EmployeeDocument>> getForEmployee(String? employeeId) async {
    try {
      final res = await _dio.get('/employee-documents', queryParameters: {
        'employeeId': ?employeeId,
      });
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load documents');
    }
  }

  Future<void> upload({
    required String employeeId,
    required String title,
    String category = 'other',
    String description = '',
    DateTime? expiresOn,
    List<int>? bytes,
    String? filePath,
    required String filename,
  }) async {
    try {
      final form = FormData.fromMap({
        'employeeId': employeeId,
        'title': title,
        'category': category,
        'description': description,
        if (expiresOn != null) 'expiresOn': expiresOn.toIso8601String(),
      });
      if (bytes != null) {
        form.files.add(MapEntry('file', MultipartFile.fromBytes(bytes, filename: filename)));
      } else if (filePath != null) {
        form.files.add(MapEntry('file', await MultipartFile.fromFile(filePath, filename: filename)));
      }
      await _dio.post('/employee-documents', data: form);
    } catch (e) {
      throw AppException(e, action: 'upload document');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/employee-documents/$id');
    } catch (e) {
      throw AppException(e, action: 'delete document');
    }
  }
}

final employeeDocumentServiceProvider =
    Provider<EmployeeDocumentService>((ref) => EmployeeDocumentService(ref.watch(dioProvider)));

/// Documents for an employee id (empty string → the caller's own, as the
/// backend scopes non-HR users to themselves regardless of the query).
final employeeDocumentsProvider =
    FutureProvider.family<List<EmployeeDocument>, String>((ref, employeeId) {
  return ref.watch(employeeDocumentServiceProvider).getForEmployee(employeeId.isEmpty ? null : employeeId);
});
