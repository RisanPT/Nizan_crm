import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/data/repositories/it_task_repository_impl.dart';

enum GanttZoomScale {
  day,
  week,
  month;

  String get label => switch (this) {
        GanttZoomScale.day => 'Day',
        GanttZoomScale.week => 'Week',
        GanttZoomScale.month => 'Month',
      };
}

enum GanttSwimlaneMode {
  bySubTeam,
  byProject,
  flatWbs;

  String get label => switch (this) {
        GanttSwimlaneMode.bySubTeam => 'By Sub-Team',
        GanttSwimlaneMode.byProject => 'By Project',
        GanttSwimlaneMode.flatWbs => 'Work Breakdown (WBS)',
      };
}

class ITFilterState {
  final Set<String> selectedProjectIds;
  final Set<ITTicketType> selectedTicketTypes;
  final Set<ITSeverity> selectedSeverities;
  final Set<ITTaskStatus> selectedStatuses;
  final Set<ITSubTeam> selectedSubTeams;
  final Set<String> selectedAssigneeIds;
  final String searchQuery;
  final GanttZoomScale zoomScale;
  final GanttSwimlaneMode swimlaneMode;

  const ITFilterState({
    this.selectedProjectIds = const {},
    this.selectedTicketTypes = const {},
    this.selectedSeverities = const {},
    this.selectedStatuses = const {},
    this.selectedSubTeams = const {},
    this.selectedAssigneeIds = const {},
    this.searchQuery = '',
    this.zoomScale = GanttZoomScale.week,
    this.swimlaneMode = GanttSwimlaneMode.bySubTeam,
  });

  bool get hasActiveFilters =>
      selectedProjectIds.isNotEmpty ||
      selectedTicketTypes.isNotEmpty ||
      selectedSeverities.isNotEmpty ||
      selectedStatuses.isNotEmpty ||
      selectedSubTeams.isNotEmpty ||
      selectedAssigneeIds.isNotEmpty ||
      searchQuery.isNotEmpty;

  ITFilterState copyWith({
    Set<String>? selectedProjectIds,
    Set<ITTicketType>? selectedTicketTypes,
    Set<ITSeverity>? selectedSeverities,
    Set<ITTaskStatus>? selectedStatuses,
    Set<ITSubTeam>? selectedSubTeams,
    Set<String>? selectedAssigneeIds,
    String? searchQuery,
    GanttZoomScale? zoomScale,
    GanttSwimlaneMode? swimlaneMode,
  }) {
    return ITFilterState(
      selectedProjectIds: selectedProjectIds ?? this.selectedProjectIds,
      selectedTicketTypes: selectedTicketTypes ?? this.selectedTicketTypes,
      selectedSeverities: selectedSeverities ?? this.selectedSeverities,
      selectedStatuses: selectedStatuses ?? this.selectedStatuses,
      selectedSubTeams: selectedSubTeams ?? this.selectedSubTeams,
      selectedAssigneeIds: selectedAssigneeIds ?? this.selectedAssigneeIds,
      searchQuery: searchQuery ?? this.searchQuery,
      zoomScale: zoomScale ?? this.zoomScale,
      swimlaneMode: swimlaneMode ?? this.swimlaneMode,
    );
  }
}

class ITFilterNotifier extends Notifier<ITFilterState> {
  @override
  ITFilterState build() => const ITFilterState();

  void updateState(ITFilterState newState) => state = newState;
  void mutate(ITFilterState Function(ITFilterState prev) updater) => state = updater(state);
  void setZoomScale(GanttZoomScale scale) => state = state.copyWith(zoomScale: scale);
  void setSwimlaneMode(GanttSwimlaneMode mode) => state = state.copyWith(swimlaneMode: mode);
  void setSearchQuery(String q) => state = state.copyWith(searchQuery: q);
  void setSubTeams(Set<ITSubTeam> teams) => state = state.copyWith(selectedSubTeams: teams);
  void setSeverities(Set<ITSeverity> sevs) => state = state.copyWith(selectedSeverities: sevs);
  void setTicketTypes(Set<ITTicketType> types) => state = state.copyWith(selectedTicketTypes: types);
  void setStatuses(Set<ITTaskStatus> statuses) => state = state.copyWith(selectedStatuses: statuses);
  void setProjectIds(Set<String> pids) => state = state.copyWith(selectedProjectIds: pids);
  void reset() => state = const ITFilterState();
}

final itFilterProvider =
    NotifierProvider<ITFilterNotifier, ITFilterState>(ITFilterNotifier.new);

final itTaskRepositoryProvider = Provider<IITTaskRepository>((ref) {
  return ITTaskRepositoryImpl(ref.watch(dioProvider));
});

abstract class IITTasksNotifier {
  Future<void> refresh();
  Future<void> updateTaskField(String taskId, Map<String, dynamic> updates);
  Future<void> shiftTaskDates(String taskId, DateTime newStart, DateTime newDue);
  Future<void> bulkUpdateStatus(List<String> taskIds, ITTaskStatus status);
  Future<void> bulkReassign(List<String> taskIds, String assigneeId);
  Future<void> bulkDelete(List<String> taskIds);
  Future<void> addSubtask(String taskId, String title);
  Future<void> toggleSubtask(String taskId, String subtaskId, bool isCompleted);
  Future<void> removeSubtask(String taskId, String subtaskId);
  Future<void> addActivityComment(String taskId, String message, {String authorName = 'Current User'});
  Future<void> deleteTask(String taskId);
}

/// AsyncNotifier for cross-project IT tasks
class ITAllTasksNotifier extends AsyncNotifier<List<ITTaskModel>> implements IITTasksNotifier {
  @override
  Future<List<ITTaskModel>> build() async {
    final repo = ref.watch(itTaskRepositoryProvider);
    return repo.getTasks();
  }

  @override
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(itTaskRepositoryProvider);
      return repo.getTasks();
    });
  }

  @override
  Future<void> updateTaskField(String taskId, Map<String, dynamic> updates) async {
    final current = state.value;
    if (current == null) return;

    final index = current.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final oldTask = current[index];
    final updatedList = List<ITTaskModel>.from(current);

    var mod = oldTask;
    if (updates.containsKey('status')) {
      mod = mod.copyWith(status: ITTaskStatus.fromString(updates['status']));
      if (mod.status == ITTaskStatus.closed || mod.status == ITTaskStatus.deployed) {
        mod = mod.copyWith(percentComplete: 100);
      }
    }
    if (updates.containsKey('severity')) {
      mod = mod.copyWith(severity: ITSeverity.fromString(updates['severity']));
    }
    if (updates.containsKey('ticketType')) {
      mod = mod.copyWith(ticketType: ITTicketType.fromString(updates['ticketType']));
    }
    if (updates.containsKey('subTeam')) {
      mod = mod.copyWith(subTeam: ITSubTeam.fromString(updates['subTeam']));
    }
    if (updates.containsKey('startDate')) {
      mod = mod.copyWith(startDate: DateTime.tryParse(updates['startDate'].toString()));
    }
    if (updates.containsKey('deadline') || updates.containsKey('dueDate')) {
      mod = mod.copyWith(dueDate: DateTime.tryParse((updates['dueDate'] ?? updates['deadline']).toString()));
    }
    if (updates.containsKey('percentComplete')) {
      mod = mod.copyWith(percentComplete: (updates['percentComplete'] as num).toInt());
    }

    updatedList[index] = mod;
    state = AsyncValue.data(updatedList);

    try {
      final repo = ref.read(itTaskRepositoryProvider);
      final saved = await repo.updateTask(taskId, updates);
      final refreshed = List<ITTaskModel>.from(state.value ?? updatedList);
      final rIdx = refreshed.indexWhere((t) => t.id == taskId);
      if (rIdx != -1) {
        refreshed[rIdx] = saved;
        state = AsyncValue.data(refreshed);
      }
      _syncOtherTaskViews(ref, fromAll: true);
    } catch (e) {
      final reverted = List<ITTaskModel>.from(state.value ?? updatedList);
      final rIdx = reverted.indexWhere((t) => t.id == taskId);
      if (rIdx != -1) {
        reverted[rIdx] = oldTask;
        state = AsyncValue.data(reverted);
      }
      rethrow;
    }
  }

  @override
  Future<void> shiftTaskDates(String taskId, DateTime newStart, DateTime newDue) async {
    final current = state.value;
    if (current == null) return;

    final index = current.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final oldTask = current[index];
    final updatedList = List<ITTaskModel>.from(current);
    updatedList[index] = oldTask.copyWith(startDate: newStart, dueDate: newDue);
    state = AsyncValue.data(updatedList);

    try {
      final repo = ref.read(itTaskRepositoryProvider);
      await repo.shiftTaskSchedule(
        taskId: taskId,
        newStartDate: newStart,
        newDueDate: newDue,
      );
      _syncOtherTaskViews(ref, fromAll: true);
    } catch (e) {
      updatedList[index] = oldTask;
      state = AsyncValue.data(updatedList);
      rethrow;
    }
  }

  @override
  Future<void> bulkUpdateStatus(List<String> taskIds, ITTaskStatus status) async {
    final current = state.value;
    if (current == null || taskIds.isEmpty) return;

    final repo = ref.read(itTaskRepositoryProvider);
    final updated = await repo.bulkUpdateTasks(
      taskIds: taskIds,
      updates: {'status': status.slug},
    );

    final map = {for (final t in updated) t.id: t};
    final list = (state.value ?? []).map((t) => map[t.id] ?? t).toList();
    state = AsyncValue.data(list);
    _syncOtherTaskViews(ref, fromAll: true);
  }

  @override
  Future<void> bulkReassign(List<String> taskIds, String assigneeId) async {
    final current = state.value;
    if (current == null || taskIds.isEmpty) return;

    final repo = ref.read(itTaskRepositoryProvider);
    final updated = await repo.bulkUpdateTasks(
      taskIds: taskIds,
      updates: {'assignedTo': assigneeId},
    );

    final map = {for (final t in updated) t.id: t};
    final list = (state.value ?? []).map((t) => map[t.id] ?? t).toList();
    state = AsyncValue.data(list);
    _syncOtherTaskViews(ref, fromAll: true);
  }

  @override
  Future<void> bulkDelete(List<String> taskIds) async {
    final current = state.value;
    if (current == null || taskIds.isEmpty) return;

    final repo = ref.read(itTaskRepositoryProvider);
    final deleted = <String>{};
    try {
      for (final id in taskIds) {
        await repo.deleteTask(id);
        deleted.add(id);
      }
    } finally {
      // Drop whatever was actually deleted, even if a later delete failed, so
      // the grid never keeps showing rows that are already gone.
      final remaining = (state.value ?? current).where((t) => !deleted.contains(t.id)).toList();
      state = AsyncValue.data(remaining);
      if (deleted.isNotEmpty) _syncOtherTaskViews(ref, fromAll: true);
    }
  }

  @override
  Future<void> addSubtask(String taskId, String title) async {
    final current = state.value;
    if (current == null) return;
    final task = current.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;

    final newSubtask = ITSubtask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      isCompleted: false,
    );
    final updatedSubs = [...task.subtasks, newSubtask];

    await updateTaskField(taskId, {
      'subtasks': updatedSubs.map((s) => s.toJson()).toList(),
    });
  }

  @override
  Future<void> toggleSubtask(String taskId, String subtaskId, bool isCompleted) async {
    final current = state.value;
    if (current == null) return;
    final task = current.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;

    final updatedSubs = task.subtasks.map((s) {
      if (s.id == subtaskId) return s.copyWith(isCompleted: isCompleted);
      return s;
    }).toList();

    final completedCount = updatedSubs.where((s) => s.isCompleted).length;
    final pct = updatedSubs.isEmpty ? task.percentComplete : ((completedCount / updatedSubs.length) * 100).round();

    await updateTaskField(taskId, {
      'subtasks': updatedSubs.map((s) => s.toJson()).toList(),
      'percentComplete': pct,
    });
  }

  @override
  Future<void> removeSubtask(String taskId, String subtaskId) async {
    final current = state.value;
    if (current == null) return;
    final task = current.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;

    final updatedSubs = task.subtasks.where((s) => s.id != subtaskId).toList();
    await updateTaskField(taskId, {
      'subtasks': updatedSubs.map((s) => s.toJson()).toList(),
    });
  }

  @override
  Future<void> addActivityComment(String taskId, String message, {String authorName = 'Current User'}) async {
    final current = state.value;
    if (current == null) return;
    final task = current.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;

    final log = ITActivityLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      authorName: authorName,
      type: 'note',
      timestamp: DateTime.now(),
    );

    final updatedLogs = [log, ...task.activityLogs];
    await updateTaskField(taskId, {
      'activityLogs': updatedLogs.map((l) => l.toJson()).toList(),
    });
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final repo = ref.read(itTaskRepositoryProvider);
    await repo.deleteTask(taskId);
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.where((t) => t.id != taskId).toList());
    }
    _syncOtherTaskViews(ref, fromAll: true);
  }
}

/// Project-scoped AsyncNotifier
class ITProjectTasksNotifier extends AsyncNotifier<List<ITTaskModel>> implements IITTasksNotifier {
  final String projectId;
  ITProjectTasksNotifier(this.projectId);

  @override
  Future<List<ITTaskModel>> build() async {
    final repo = ref.watch(itTaskRepositoryProvider);
    return repo.getTasks(projectId: projectId);
  }

  @override
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(itTaskRepositoryProvider);
      return repo.getTasks(projectId: projectId);
    });
  }

  @override
  Future<void> updateTaskField(String taskId, Map<String, dynamic> updates) async {
    final current = state.value;
    if (current == null) return;

    final index = current.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final oldTask = current[index];
    final updatedList = List<ITTaskModel>.from(current);

    var mod = oldTask;
    if (updates.containsKey('status')) {
      mod = mod.copyWith(status: ITTaskStatus.fromString(updates['status']));
      if (mod.status == ITTaskStatus.closed || mod.status == ITTaskStatus.deployed) {
        mod = mod.copyWith(percentComplete: 100);
      }
    }
    if (updates.containsKey('severity')) {
      mod = mod.copyWith(severity: ITSeverity.fromString(updates['severity']));
    }
    if (updates.containsKey('ticketType')) {
      mod = mod.copyWith(ticketType: ITTicketType.fromString(updates['ticketType']));
    }
    if (updates.containsKey('subTeam')) {
      mod = mod.copyWith(subTeam: ITSubTeam.fromString(updates['subTeam']));
    }
    if (updates.containsKey('startDate')) {
      mod = mod.copyWith(startDate: DateTime.tryParse(updates['startDate'].toString()));
    }
    if (updates.containsKey('deadline') || updates.containsKey('dueDate')) {
      mod = mod.copyWith(dueDate: DateTime.tryParse((updates['dueDate'] ?? updates['deadline']).toString()));
    }
    if (updates.containsKey('percentComplete')) {
      mod = mod.copyWith(percentComplete: (updates['percentComplete'] as num).toInt());
    }

    updatedList[index] = mod;
    state = AsyncValue.data(updatedList);

    try {
      final repo = ref.read(itTaskRepositoryProvider);
      final saved = await repo.updateTask(taskId, updates);
      final refreshed = List<ITTaskModel>.from(state.value ?? updatedList);
      final rIdx = refreshed.indexWhere((t) => t.id == taskId);
      if (rIdx != -1) {
        refreshed[rIdx] = saved;
        state = AsyncValue.data(refreshed);
      }
      _syncOtherTaskViews(ref, fromAll: false);
    } catch (e) {
      final reverted = List<ITTaskModel>.from(state.value ?? updatedList);
      final rIdx = reverted.indexWhere((t) => t.id == taskId);
      if (rIdx != -1) {
        reverted[rIdx] = oldTask;
        state = AsyncValue.data(reverted);
      }
      rethrow;
    }
  }

  @override
  Future<void> shiftTaskDates(String taskId, DateTime newStart, DateTime newDue) async {
    final current = state.value;
    if (current == null) return;

    final index = current.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final oldTask = current[index];
    final updatedList = List<ITTaskModel>.from(current);
    updatedList[index] = oldTask.copyWith(startDate: newStart, dueDate: newDue);
    state = AsyncValue.data(updatedList);

    try {
      final repo = ref.read(itTaskRepositoryProvider);
      await repo.shiftTaskSchedule(
        taskId: taskId,
        newStartDate: newStart,
        newDueDate: newDue,
      );
      _syncOtherTaskViews(ref, fromAll: false);
    } catch (e) {
      updatedList[index] = oldTask;
      state = AsyncValue.data(updatedList);
      rethrow;
    }
  }

  @override
  Future<void> bulkUpdateStatus(List<String> taskIds, ITTaskStatus status) async {
    final current = state.value;
    if (current == null || taskIds.isEmpty) return;

    final repo = ref.read(itTaskRepositoryProvider);
    final updated = await repo.bulkUpdateTasks(
      taskIds: taskIds,
      updates: {'status': status.slug},
    );

    final map = {for (final t in updated) t.id: t};
    final list = (state.value ?? []).map((t) => map[t.id] ?? t).toList();
    state = AsyncValue.data(list);
    _syncOtherTaskViews(ref, fromAll: false);
  }

  @override
  Future<void> bulkReassign(List<String> taskIds, String assigneeId) async {
    final current = state.value;
    if (current == null || taskIds.isEmpty) return;

    final repo = ref.read(itTaskRepositoryProvider);
    final updated = await repo.bulkUpdateTasks(
      taskIds: taskIds,
      updates: {'assignedTo': assigneeId},
    );

    final map = {for (final t in updated) t.id: t};
    final list = (state.value ?? []).map((t) => map[t.id] ?? t).toList();
    state = AsyncValue.data(list);
    _syncOtherTaskViews(ref, fromAll: false);
  }

  @override
  Future<void> bulkDelete(List<String> taskIds) async {
    final current = state.value;
    if (current == null || taskIds.isEmpty) return;

    final repo = ref.read(itTaskRepositoryProvider);
    final deleted = <String>{};
    try {
      for (final id in taskIds) {
        await repo.deleteTask(id);
        deleted.add(id);
      }
    } finally {
      // Drop whatever was actually deleted, even if a later delete failed, so
      // the grid never keeps showing rows that are already gone.
      final remaining = (state.value ?? current).where((t) => !deleted.contains(t.id)).toList();
      state = AsyncValue.data(remaining);
      if (deleted.isNotEmpty) _syncOtherTaskViews(ref, fromAll: false);
    }
  }

  @override
  Future<void> addSubtask(String taskId, String title) async {
    final current = state.value;
    if (current == null) return;
    final task = current.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;

    final newSubtask = ITSubtask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      isCompleted: false,
    );
    final updatedSubs = [...task.subtasks, newSubtask];

    await updateTaskField(taskId, {
      'subtasks': updatedSubs.map((s) => s.toJson()).toList(),
    });
  }

  @override
  Future<void> toggleSubtask(String taskId, String subtaskId, bool isCompleted) async {
    final current = state.value;
    if (current == null) return;
    final task = current.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;

    final updatedSubs = task.subtasks.map((s) {
      if (s.id == subtaskId) return s.copyWith(isCompleted: isCompleted);
      return s;
    }).toList();

    final completedCount = updatedSubs.where((s) => s.isCompleted).length;
    final pct = updatedSubs.isEmpty ? task.percentComplete : ((completedCount / updatedSubs.length) * 100).round();

    await updateTaskField(taskId, {
      'subtasks': updatedSubs.map((s) => s.toJson()).toList(),
      'percentComplete': pct,
    });
  }

  @override
  Future<void> removeSubtask(String taskId, String subtaskId) async {
    final current = state.value;
    if (current == null) return;
    final task = current.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;

    final updatedSubs = task.subtasks.where((s) => s.id != subtaskId).toList();
    await updateTaskField(taskId, {
      'subtasks': updatedSubs.map((s) => s.toJson()).toList(),
    });
  }

  @override
  Future<void> addActivityComment(String taskId, String message, {String authorName = 'Current User'}) async {
    final current = state.value;
    if (current == null) return;
    final task = current.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;

    final log = ITActivityLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      authorName: authorName,
      type: 'note',
      timestamp: DateTime.now(),
    );

    final updatedLogs = [log, ...task.activityLogs];
    await updateTaskField(taskId, {
      'activityLogs': updatedLogs.map((l) => l.toJson()).toList(),
    });
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final repo = ref.read(itTaskRepositoryProvider);
    await repo.deleteTask(taskId);
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.where((t) => t.id != taskId).toList());
    }
    _syncOtherTaskViews(ref, fromAll: false);
  }
}

final itAllTasksControllerProvider =
    AsyncNotifierProvider<ITAllTasksNotifier, List<ITTaskModel>>(ITAllTasksNotifier.new);

final itProjectTasksControllerProvider =
    AsyncNotifierProvider.family<ITProjectTasksNotifier, List<ITTaskModel>, String>(
        (projectId) => ITProjectTasksNotifier(projectId));

/// After a successful task change, refreshes every OTHER view of IT tasks: the
/// sibling controller (cross-project <-> per-project), the FutureProvider task
/// lists (My Tasks, roadmap) and project progress/counters. The calling
/// notifier has already updated its own in-memory state, so it is not
/// invalidated here.
void _syncOtherTaskViews(Ref ref, {required bool fromAll}) {
  if (fromAll) {
    ref.invalidate(itProjectTasksControllerProvider);
  } else {
    ref.invalidate(itAllTasksControllerProvider);
  }
  ref.refreshData.tasks();
  ref.refreshData.projects();
}

/// For screens that change tasks outside the controllers (direct service calls,
/// ticket promotion, project deletion): refreshes BOTH task controllers, the
/// FutureProvider task lists and project progress/counters.
/// (The central `refreshData.tasks()` doesn't know the two controllers.)
void refreshAllItTaskViews(WidgetRef ref) {
  ref.invalidate(itAllTasksControllerProvider);
  ref.invalidate(itProjectTasksControllerProvider);
  ref.refreshData.tasks();
  ref.refreshData.projects();
}

IITTasksNotifier getITTasksNotifier(WidgetRef ref, String? projectId) {
  if (projectId != null && projectId.isNotEmpty) {
    return ref.read(itProjectTasksControllerProvider(projectId).notifier);
  } else {
    return ref.read(itAllTasksControllerProvider.notifier);
  }
}

/// Filtered tasks provider that applies active filters from [itFilterProvider]
final filteredTasksProvider = Provider.family<List<ITTaskModel>, List<ITTaskModel>>((ref, allTasks) {
  final filter = ref.watch(itFilterProvider);

  return allTasks.where((task) {
    if (filter.selectedProjectIds.isNotEmpty &&
        !filter.selectedProjectIds.contains(task.projectId)) {
      return false;
    }
    if (filter.selectedTicketTypes.isNotEmpty &&
        !filter.selectedTicketTypes.contains(task.ticketType)) {
      return false;
    }
    if (filter.selectedSeverities.isNotEmpty &&
        !filter.selectedSeverities.contains(task.severity)) {
      return false;
    }
    if (filter.selectedStatuses.isNotEmpty &&
        !filter.selectedStatuses.contains(task.status)) {
      return false;
    }
    if (filter.selectedSubTeams.isNotEmpty &&
        !filter.selectedSubTeams.contains(task.subTeam)) {
      return false;
    }
    if (filter.selectedAssigneeIds.isNotEmpty &&
        !filter.selectedAssigneeIds.contains(task.assigneeId)) {
      return false;
    }
    if (filter.searchQuery.isNotEmpty) {
      final q = filter.searchQuery.toLowerCase();
      final matchesTitle = task.title.toLowerCase().contains(q);
      final matchesKey = task.ticketKey.toLowerCase().contains(q);
      final matchesAssignee = task.assigneeName.toLowerCase().contains(q);
      if (!matchesTitle && !matchesKey && !matchesAssignee) return false;
    }
    return true;
  }).toList();
});
