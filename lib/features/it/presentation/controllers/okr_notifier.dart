import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';

class OKRFilterState {
  final String searchQuery;
  final OKRStatus? status;
  final bool? completedOnly;
  final DateTime? startDate;

  const OKRFilterState({
    this.searchQuery = '',
    this.status,
    this.completedOnly,
    this.startDate,
  });

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty || status != null || completedOnly != null || startDate != null;

  OKRFilterState copyWith({
    String? searchQuery,
    OKRStatus? status,
    bool? completedOnly,
    DateTime? startDate,
    bool clearStatus = false,
    bool clearCompleted = false,
    bool clearStartDate = false,
  }) {
    return OKRFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      status: clearStatus ? null : (status ?? this.status),
      completedOnly: clearCompleted ? null : (completedOnly ?? this.completedOnly),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
    );
  }
}

class OKRFilterNotifier extends Notifier<OKRFilterState> {
  @override
  OKRFilterState build() => const OKRFilterState();

  void setSearchQuery(String q) => state = state.copyWith(searchQuery: q);
  void setStatus(OKRStatus? s) => state = state.copyWith(status: s, clearStatus: s == null);
  void setCompleted(bool? c) => state = state.copyWith(completedOnly: c, clearCompleted: c == null);
  void setStartDate(DateTime? d) => state = state.copyWith(startDate: d, clearStartDate: d == null);
  void reset() => state = const OKRFilterState();
}

final okrFilterProvider = NotifierProvider<OKRFilterNotifier, OKRFilterState>(OKRFilterNotifier.new);

class ProjectOKRsNotifier extends AsyncNotifier<List<OKRModel>> {
  final String? projectId;
  ProjectOKRsNotifier(this.projectId);

  @override
  Future<List<OKRModel>> build() async {
    final service = ref.watch(okrServiceProvider);
    return service.getOKRs(projectId: projectId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(okrServiceProvider);
      return service.getOKRs(projectId: projectId);
    });
  }

  Future<OKRModel> addOKR(Map<String, dynamic> data) async {
    final service = ref.read(okrServiceProvider);
    final payload = Map<String, dynamic>.from(data);
    if (projectId != null && projectId!.isNotEmpty) {
      payload['projectId'] = projectId;
    }
    final created = await service.createOKR(payload);
    ref.refreshData.okrs();
    await refresh();
    return created;
  }

  Future<OKRModel> updateOKRField(String id, Map<String, dynamic> updates) async {
    final service = ref.read(okrServiceProvider);
    final currentList = state.value ?? [];
    final updatedList = currentList.map((item) {
      if (item.id == id) {
        return item.copyWith(
          objective: updates['objective'] as String?,
          status: updates['status'] != null ? OKRStatus.fromString(updates['status'].toString()) : null,
          priority: updates['priority'] != null ? OKRPriority.fromString(updates['priority'].toString()) : null,
          progress: updates['progress'] != null ? (updates['progress'] as num).toInt() : null,
          projectHeadId: updates['projectHeadId'] as String?,
          projectHeadName: updates['projectHeadName'] as String?,
          startDate: updates['startDate'] != null ? DateTime.tryParse(updates['startDate'].toString()) : null,
          deadline: updates['deadline'] != null ? DateTime.tryParse(updates['deadline'].toString()) : null,
        );
      }
      return item;
    }).toList();

    state = AsyncValue.data(updatedList);

    try {
      final saved = await service.updateOKR(id, updates);
      ref.refreshData.okrs();
      await refresh();
      return saved;
    } catch (e) {
      await refresh();
      rethrow;
    }
  }

  Future<void> deleteOKR(String id) async {
    final service = ref.read(okrServiceProvider);
    await service.deleteOKR(id);
    ref.refreshData.okrs();
    await refresh();
  }
}

final projectOKRsNotifierProvider =
    AsyncNotifierProvider.family<ProjectOKRsNotifier, List<OKRModel>, String?>(
  ProjectOKRsNotifier.new,
);
