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

/// Active IT-department staff only — used by cross-project assignment pickers
/// (e.g. creating/editing projects in the Projects screen).
final itEmployeesProvider = Provider<List<Employee>>((ref) {
  final all = ref.watch(employeesProvider).value ?? const <Employee>[];
  return all
      .where((e) => e.status.toLowerCase() == 'active' && isItEmployee(e))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

/// The assignable employees for a specific project (task assignee dropdowns,
/// PlutoGrid, task details, OKR Project Head).
///
/// Projects are now company-wide and department-scoped, so the pool is drawn
/// from ALL active employees — not IT only — in priority order:
/// 1. If the project names an explicit team (manager + members), that team IS
///    the pool, whatever department each person is in.
/// 2. Otherwise, everyone in the project's own department (`targetDepartment`,
///    e.g. Finance/Sales/IT).
/// 3. Fallback to all active employees so the picker is never empty.
final projectEmployeesProvider = Provider.family<List<Employee>, String?>((ref, projectId) {
  final allActive = ref.watch(activeEmployeesProvider);
  if (projectId == null || projectId.isEmpty) {
    return allActive;
  }

  final projects = ref.watch(projectsProvider).value ?? const <Project>[];
  final project = projects.where((p) => p.id == projectId).firstOrNull;
  if (project == null) {
    return allActive;
  }

  // 1. Explicit team (manager + members), across any department.
  final allowedIds = <String>{
    if (project.managerId.isNotEmpty) project.managerId,
    ...project.memberIds,
  };
  if (allowedIds.isNotEmpty) {
    final team = allActive.where((e) => allowedIds.contains(e.id)).toList();
    if (team.isNotEmpty) return team;
  }

  // 2/3. Scope to the project's department, falling back to everyone.
  return ref.watch(departmentEmployeesProvider(project.targetDepartment));
});

// ── Company-wide employee pickers (for cross-department project creation) ──────
/// All active employees, sorted by name.
final activeEmployeesProvider = Provider<List<Employee>>((ref) {
  final all = ref.watch(employeesProvider).value ?? const <Employee>[];
  return all.where((e) => e.status.toLowerCase() == 'active').toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

/// Active employees scoped to a department (by Employee.department name or
/// category, case-insensitive). Falls back to everyone if none are tagged to
/// that department, so the picker is never empty.
final departmentEmployeesProvider = Provider.family<List<Employee>, String?>((ref, dept) {
  final all = ref.watch(activeEmployeesProvider);
  final d = (dept ?? '').toLowerCase().trim();
  if (d.isEmpty || d == 'all') return all;
  final scoped = all
      .where((e) => (e.department ?? '').toLowerCase().trim() == d || e.category.toLowerCase().trim() == d)
      .toList();
  return scoped.isNotEmpty ? scoped : all;
});

// ── Projects ─────────────────────────────────────────────────────────────────
final projectServiceProvider = Provider((ref) => ProjectService(ref.watch(dioProvider)));

final projectsProvider = FutureProvider<List<Project>>(
    (ref) => ref.watch(projectServiceProvider).getProjects());

/// Company-wide projects, optionally filtered to one department (the top-level
/// Company Projects portfolio). Server scopes what each user may see.
final companyProjectsProvider = FutureProvider.family<List<Project>, String?>(
    (ref, department) => ref.watch(projectServiceProvider).getProjects(department: department));

/// The department key that identifies IT projects. Case-insensitive on the
/// server, so it matches both legacy 'it' and normalized 'IT'.
const kItDepartment = 'IT';

/// IT-department projects ONLY — powers the IT-branded views (the IT Projects
/// list and the IT Roadmap). The top-level Company Projects portfolio uses
/// [companyProjectsProvider] and shows every department (IT included).
/// Distinct from [projectsProvider], which stays unfiltered because task/detail
/// screens and pickers look projects up by id from the full accessible set.
final itProjectsProvider = companyProjectsProvider(kItDepartment);

class ProjectService {
  final Dio _dio;
  ProjectService(this._dio);

  Future<List<Project>> getProjects({String? status, String? priority, String? search, String? department}) async {
    final res = await _dio.get('/projects', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (priority != null && priority.isNotEmpty) 'priority': priority,
      if (search != null && search.isNotEmpty) 'search': search,
      if (department != null && department.isNotEmpty && department != 'all') 'department': department,
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
