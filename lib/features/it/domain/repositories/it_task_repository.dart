import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';

abstract class IITTaskRepository {
  Future<List<ITTaskModel>> getTasks({
    String? projectId,
    String? status,
    String? assignedTo,
    String? ticketType,
    String? severity,
    String? subTeam,
    String? search,
    bool mine = false,
  });

  Future<ITTaskModel> createTask(Map<String, dynamic> data);

  Future<ITTaskModel> updateTask(String id, Map<String, dynamic> data);

  Future<void> deleteTask(String id);

  Future<List<ITTaskModel>> bulkUpdateTasks({
    required List<String> taskIds,
    required Map<String, dynamic> updates,
  });

  Future<void> shiftTaskSchedule({
    required String taskId,
    required DateTime newStartDate,
    required DateTime newDueDate,
    bool cascadeSuccessors = false,
  });
}
