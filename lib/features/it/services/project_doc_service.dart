import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/it/domain/models/project_doc_model.dart';

final projectDocServiceProvider = Provider((ref) => ProjectDocService(ref.watch(dioProvider)));

class ProjectDocService {
  final Dio _dio;
  ProjectDocService(this._dio);

  /// Runs an API call and rethrows any failure as an [AppException].
  Future<T> _guard<T>(String action, Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  Future<List<ProjectDocModel>> getDocs(String projectId) => _guard('load documents', () async {
        final res = await _dio.get('/project-docs', queryParameters: {'projectId': projectId});
        return (res.data as List).map((e) => ProjectDocModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      });

  Future<ProjectDocModel> createDoc(Map<String, dynamic> body) => _guard('create the document', () async {
        final res = await _dio.post('/project-docs', data: body);
        return ProjectDocModel.fromJson(Map<String, dynamic>.from(res.data as Map));
      });
  Future<void> updateDoc(String id, Map<String, dynamic> body) =>
      _guard('update the document', () => _dio.put('/project-docs/$id', data: body));
  Future<void> deleteDoc(String id) => _guard('delete the document', () => _dio.delete('/project-docs/$id'));
  Future<void> deleteVersion(String id, int version) =>
      _guard('delete the version', () => _dio.delete('/project-docs/$id/versions/$version'));

  /// Upload a new version bundling a PDF and/or a DOC. Pass bytes (web) or a
  /// path (mobile) for each file that's present.
  Future<void> uploadVersion(
    String id, {
    String? pdfPath,
    List<int>? pdfBytes,
    String? pdfName,
    String? docPath,
    List<int>? docBytes,
    String? docName,
    String notes = '',
  }) =>
      _guard('upload the version', () async {
        final form = FormData.fromMap({'notes': notes});
        if (pdfBytes != null) {
          form.files.add(MapEntry('pdf', MultipartFile.fromBytes(pdfBytes, filename: pdfName ?? 'document.pdf')));
        } else if (pdfPath != null) {
          form.files.add(MapEntry('pdf', await MultipartFile.fromFile(pdfPath, filename: pdfName)));
        }
        if (docBytes != null) {
          form.files.add(MapEntry('doc', MultipartFile.fromBytes(docBytes, filename: docName ?? 'document.docx')));
        } else if (docPath != null) {
          form.files.add(MapEntry('doc', await MultipartFile.fromFile(docPath, filename: docName)));
        }
        await _dio.post('/project-docs/$id/versions', data: form);
      });

  Future<List<int>> downloadBytes(String id, int version, String fmt) => _guard('download the file', () async {
        final res = await _dio.get<List<int>>(
          '/project-docs/$id/versions/$version/download',
          queryParameters: {'fmt': fmt},
          options: Options(responseType: ResponseType.bytes),
        );
        return res.data ?? const <int>[];
      });
}
