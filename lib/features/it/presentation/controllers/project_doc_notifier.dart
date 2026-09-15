import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/it/domain/models/project_doc_model.dart';
import 'package:nizan_crm/features/it/services/project_doc_service.dart';

/// Project documents for one project (keyed by projectId). Mirrors the OKR
/// notifier pattern.
class ProjectDocsNotifier extends AsyncNotifier<List<ProjectDocModel>> {
  ProjectDocsNotifier(this.projectId);
  final String projectId;

  @override
  Future<List<ProjectDocModel>> build() async {
    return ref.watch(projectDocServiceProvider).getDocs(projectId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(projectDocServiceProvider).getDocs(projectId));
  }

  Future<ProjectDocModel> addDoc(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data)..['projectId'] = projectId;
    final created = await ref.read(projectDocServiceProvider).createDoc(payload);
    await refresh();
    return created;
  }

  Future<void> updateDoc(String id, Map<String, dynamic> data) async {
    await ref.read(projectDocServiceProvider).updateDoc(id, data);
    await refresh();
  }

  Future<void> deleteDoc(String id) async {
    await ref.read(projectDocServiceProvider).deleteDoc(id);
    await refresh();
  }

  Future<void> deleteVersion(String id, int version) async {
    await ref.read(projectDocServiceProvider).deleteVersion(id, version);
    await refresh();
  }

  Future<void> uploadVersion(
    String id, {
    String? pdfPath,
    List<int>? pdfBytes,
    String? pdfName,
    String? docPath,
    List<int>? docBytes,
    String? docName,
    String notes = '',
  }) async {
    await ref.read(projectDocServiceProvider).uploadVersion(
          id,
          pdfPath: pdfPath,
          pdfBytes: pdfBytes,
          pdfName: pdfName,
          docPath: docPath,
          docBytes: docBytes,
          docName: docName,
          notes: notes,
        );
    await refresh();
  }
}

final projectDocsNotifierProvider =
    AsyncNotifierProvider.family<ProjectDocsNotifier, List<ProjectDocModel>, String>(ProjectDocsNotifier.new);
