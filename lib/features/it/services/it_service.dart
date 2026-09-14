import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';

// ── IT department staff ───────────────────────────────────────────────────────
/// True when an employee belongs to the IT department. Robust to however the
/// admin tagged them: the structured `category` enum ('it'), a free-text `role`
/// of 'it', or a department name of 'IT' / 'Information Technology'.
bool isItEmployee(Employee e) {
  final cat = e.category.toLowerCase().trim();
  final role = (e.role ?? '').toLowerCase().trim();
  final dept = (e.department ?? '').toLowerCase().trim();
  return cat == 'it' ||
      role == 'it' ||
      dept == 'it' ||
      dept == 'information technology';
}

/// Active IT-department staff only — used by every IT assignment picker
/// (project manager, task assignee, ticket triage / promote-to-task).
final itEmployeesProvider = Provider<List<Employee>>((ref) {
  final all = ref.watch(employeesProvider).value ?? const <Employee>[];
  return all
      .where((e) => e.status.toLowerCase() == 'active' && isItEmployee(e))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

// ── Projects ─────────────────────────────────────────────────────────────────
final projectServiceProvider = Provider((ref) => ProjectService(ref.watch(dioProvider)));

final projectsProvider = FutureProvider<List<Project>>(
    (ref) => ref.watch(projectServiceProvider).getProjects());

class ProjectService {
  final Dio _dio;
  ProjectService(this._dio);

  Future<List<Project>> getProjects({String? status, String? priority, String? search}) async {
    final res = await _dio.get('/projects', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (priority != null && priority.isNotEmpty) 'priority': priority,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (res.data as List).map((e) => Project.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> saveProject(Map<String, dynamic> body, {String? id}) =>
      (id == null || id.isEmpty) ? _dio.post('/projects', data: body) : _dio.put('/projects/$id', data: body);

  Future<void> deleteProject(String id) => _dio.delete('/projects/$id');
}

// ── Tasks (Kanban) ───────────────────────────────────────────────────────────
final itTaskServiceProvider = Provider((ref) => ITTaskService(ref.watch(dioProvider)));

final tasksProvider = FutureProvider.family<List<ITTask>, String>(
    (ref, projectId) => ref.watch(itTaskServiceProvider).getTasks(projectId: projectId));

/// Every IT task across all projects (for the cross-project Roadmap).
final allTasksProvider = FutureProvider<List<ITTask>>(
    (ref) => ref.watch(itTaskServiceProvider).getTasks());

/// Tasks assigned to the logged-in user across all projects (My Tasks).
final myTasksProvider = FutureProvider<List<ITTask>>(
    (ref) => ref.watch(itTaskServiceProvider).getTasks(mine: true));

class ITTaskService {
  final Dio _dio;
  ITTaskService(this._dio);

  Future<List<ITTask>> getTasks({String? projectId, String? status, String? assignedTo, bool mine = false}) async {
    final res = await _dio.get('/it-tasks', queryParameters: {
      if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (mine) 'mine': 'true',
      if (!mine && assignedTo != null && assignedTo.isNotEmpty) 'assignedTo': assignedTo,
    });
    return (res.data as List).map((e) => ITTask.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> createTask(Map<String, dynamic> body) => _dio.post('/it-tasks', data: body);
  Future<void> updateTask(String id, Map<String, dynamic> body) => _dio.put('/it-tasks/$id', data: body);
  Future<void> deleteTask(String id) => _dio.delete('/it-tasks/$id');
}
