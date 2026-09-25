import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';

class ITTaskRepositoryImpl implements IITTaskRepository {
  final Dio _dio;
  ITTaskRepositoryImpl(this._dio);

  /// Runs an API call and rethrows any failure as an [AppException] (keeps the
  /// original error so the UI can tell offline / permission / server message).
  Future<T> _guard<T>(String action, Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw AppException(e, action: action);
    }
  }

  @override
  Future<List<ITTaskModel>> getTasks({
    String? projectId,
    String? status,
    String? assignedTo,
    String? ticketType,
    String? severity,
    String? subTeam,
    String? search,
    bool mine = false,
  }) =>
      _guard('load tasks', () async {
        final res = await _dio.get('/it-tasks', queryParameters: {
          if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (ticketType != null && ticketType.isNotEmpty) 'ticketType': ticketType,
          if (severity != null && severity.isNotEmpty) 'severity': severity,
          if (subTeam != null && subTeam.isNotEmpty) 'subTeam': subTeam,
          if (search != null && search.isNotEmpty) 'search': search,
          if (mine) 'mine': 'true',
          if (!mine && assignedTo != null && assignedTo.isNotEmpty) 'assignedTo': assignedTo,
        });

        final list = res.data as List;
        return list
            .map((e) => ITTaskModel.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      });

  @override
  Future<ITTaskModel> createTask(Map<String, dynamic> data) => _guard('create the task', () async {
        final res = await _dio.post('/it-tasks', data: data);
        return ITTaskModel.fromJson((res.data as Map).cast<String, dynamic>());
      });

  @override
  Future<ITTaskModel> updateTask(String id, Map<String, dynamic> data) => _guard('update the task', () async {
        final res = await _dio.put('/it-tasks/$id', data: data);
        return ITTaskModel.fromJson((res.data as Map).cast<String, dynamic>());
      });

  @override
  Future<void> deleteTask(String id) => _guard('delete the task', () async {
        await _dio.delete('/it-tasks/$id');
      });

  @override
  Future<List<ITTaskModel>> bulkUpdateTasks({
    required List<String> taskIds,
    required Map<String, dynamic> updates,
  }) =>
      _guard('update the selected tasks', () async {
        final res = await _dio.post('/it-tasks/bulk-update', data: {
          'taskIds': taskIds,
          'updates': updates,
        });
        final list = (res.data['tasks'] as List?) ?? [];
        return list
            .map((e) => ITTaskModel.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      });

  @override
  Future<void> shiftTaskSchedule({
    required String taskId,
    required DateTime newStartDate,
    required DateTime newDueDate,
    bool cascadeSuccessors = false,
  }) async {
    await updateTask(taskId, {
      'startDate': newStartDate.toIso8601String(),
      'deadline': newDueDate.toIso8601String(),
      'dueDate': newDueDate.toIso8601String(),
    });
  }
}
