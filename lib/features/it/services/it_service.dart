import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/data/project_spend.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';

// ── IT department staff ───────────────────────────────────────────────────────
/// True when an employee belongs to the IT department. Robust to however the
/// admin tagged them: the structured `category` enum ('it'), a free-text `role`
/// of 'it', or a department name of 'IT' / 'Information Technology'.
bool isItEmployee(Employee e) {
  final cat = e.category.toLowerCase().trim();
  final role = (e.role ?? '').toLowerCase().trim();
  final dept = (e.department ?? '').toLowerCase().trim();
  return cat == 'it' || role == 'it' || dept == 'it' || dept == 'information technology';
}

/// Active IT-department staff only — used by cross-project assignment pickers
/// (e.g. creating/editing projects in the Projects screen).
final itEmployeesProvider = Provider<List<Employee>>((ref) {
  final all = ref.watch(employeesProvider).value ?? const <Employee>[];
  return all.where((e) => e.status.toLowerCase() == 'active' && isItEmployee(e)).toList()..sort((a, b) => a.name.compareTo(b.name));
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
  final allowedIds = <String>{if (project.managerId.isNotEmpty) project.managerId, ...project.memberIds};
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
  return all.where((e) => e.status.toLowerCase() == 'active').toList()..sort((a, b) => a.name.compareTo(b.name));
});

/// Active employees scoped to a department (by Employee.department name or
/// category, case-insensitive). Falls back to everyone if none are tagged to
/// that department, so the picker is never empty.
final departmentEmployeesProvider = Provider.family<List<Employee>, String?>((ref, dept) {
  final all = ref.watch(activeEmployeesProvider);
  final d = (dept ?? '').toLowerCase().trim();
  if (d.isEmpty || d == 'all') return all;
  final scoped = all.where((e) => (e.department ?? '').toLowerCase().trim() == d || e.category.toLowerCase().trim() == d).toList();
  return scoped.isNotEmpty ? scoped : all;
});

// ── Projects ─────────────────────────────────────────────────────────────────
final projectServiceProvider = Provider((ref) => ProjectService(ref.watch(dioProvider)));

final projectsProvider = FutureProvider<List<Project>>((ref) => ref.watch(projectServiceProvider).getProjects());

/// Company-wide projects, optionally filtered to one department (the top-level
/// Company Projects portfolio). Server scopes what each user may see.
final companyProjectsProvider = FutureProvider.family<List<Project>, String?>(
  (ref, department) => ref.watch(projectServiceProvider).getProjects(department: department),
);

/// One project from the full accessible list (null while loading / if not visible).
final projectByIdProvider = Provider.family<Project?, String>((ref, id) {
  final list = ref.watch(projectsProvider).value;
  return list?.where((p) => p.id == id).firstOrNull;
});

/// What has happened to one project (created, invited, joined, moved, reminded …), oldest first. Only the single
/// project's endpoint carries it. It reloads whenever the project list does, and every change to a project
/// already reloads that list.
final projectActivityProvider = FutureProvider.autoDispose.family<List<ProjectActivity>, String>(
  (ref, id) async {
    ref.watch(projectsProvider);
    return (await ref.watch(projectServiceProvider).getProject(id)).activity;
  },
  // A side panel: when it fails say so (with a Retry button) rather than spin through automatic retries.
  retry: (_, _) => null,
);

/// The department key that identifies IT projects. Case-insensitive on the
/// server, so it matches both legacy 'it' and normalized 'IT'.
const kItDepartment = 'IT';

/// IT-department projects ONLY — powers the IT-branded views (the IT Projects
/// list and the IT Roadmap). The top-level Company Projects portfolio uses
/// [companyProjectsProvider] and shows every department (IT included).
/// Distinct from [projectsProvider], which stays unfiltered because task/detail
/// screens and pickers look projects up by id from the full accessible set.
///
/// `ownerOnly`: a project that merely INVOLVES IT (another department owns it and
/// invited IT) belongs in the Company Projects portfolio, not in IT's own list.
final itProjectsProvider = FutureProvider<List<Project>>(
  (ref) => ref.watch(projectServiceProvider).getProjects(department: kItDepartment, ownerOnly: true),
);

/// What one project has spent. Reloads whenever the projects do (an expense moves it).
final projectSpendProvider = FutureProvider.autoDispose.family<ProjectSpend, String>((ref, id) {
  ref.watch(projectsProvider);
  return ref.watch(projectServiceProvider).getSpend(id);
});

/// The projects an expense can be charged to.
final chargeableProjectsProvider = FutureProvider.autoDispose<List<ChargeableProject>>((ref) => ref.watch(projectServiceProvider).chargeableProjects());

/// The costs waiting for the finance head. Reloads whenever the projects do.
final pendingProjectCostsProvider = FutureProvider.autoDispose<List<PendingProjectCost>>((ref) {
  ref.watch(projectsProvider);
  return ref.watch(projectServiceProvider).pendingCosts();
});

class ProjectService {
  final Dio _dio;
  ProjectService(this._dio);

  Future<List<Project>> getProjects({String? status, String? priority, String? search, String? department, bool ownerOnly = false}) =>
      _guard('load projects', () async {
        final res = await _dio.get(
          '/projects',
          queryParameters: {
            if (ownerOnly) 'ownerOnly': '1',
            if (status != null && status.isNotEmpty) 'status': status,
            if (priority != null && priority.isNotEmpty) 'priority': priority,
            if (search != null && search.isNotEmpty) 'search': search,
            if (department != null && department.isNotEmpty && department != 'all') 'department': department,
          },
        );
        return (res.data as List).map((e) => Project.fromJson((e as Map).cast<String, dynamic>())).toList();
      });

  /// One project, with its activity feed (the list does not carry that).
  Future<Project> getProject(String id) => _guard('load the project', () async {
    final res = await _dio.get('/projects/$id');
    return Project.fromJson((res.data as Map).cast<String, dynamic>());
  });

  /// Saves and returns the project as the server now has it (a proposal comes back
  /// with status `proposed`, not the one the form asked for).
  Future<Project> saveProject(Map<String, dynamic> body, {String? id}) => _guard('save the project', () async {
    final res = (id == null || id.isEmpty) ? await _dio.post('/projects', data: body) : await _dio.put('/projects/$id', data: body);
    return Project.fromJson((res.data as Map).cast<String, dynamic>());
  });

  /// A department head accepts or declines the invitation to join a project.
  Future<Project> respondToInvitation(String projectId, String department, {required bool accept}) =>
      _guard(accept ? 'accept the invitation' : 'decline the invitation', () async {
        final res = await _dio.post('/projects/$projectId/departments/${Uri.encodeComponent(department)}/respond', data: {'accept': accept});
        return Project.fromJson((res.data as Map).cast<String, dynamic>());
      });

  /// The manager (or the owning head / an admin) reminds a department whose head has not answered yet.
  /// The server allows one reminder per department every half hour and says so when it is too soon.
  Future<Project> resendInvitation(String projectId, String department) => _guard('resend the invitation', () async {
    final res = await _dio.post('/projects/$projectId/departments/${Uri.encodeComponent(department)}/resend');
    return Project.fromJson((res.data as Map).cast<String, dynamic>());
  });

  /// The owning department's head (or an admin) approves or rejects a proposed project.
  Future<Project> decideProposal(String projectId, {required bool approve, String note = ''}) =>
      _guard(approve ? 'approve the project' : 'reject the project', () async {
        final res = await _dio.post('/projects/$projectId/${approve ? 'approve' : 'reject'}', data: {'note': note});
        return Project.fromJson((res.data as Map).cast<String, dynamic>());
      });

  /// Sets or changes the estimated cost. With a breakdown, its total is the cost. [reason] is needed once the cost was
  /// approved: the change is logged and goes back to the finance head (the amount approved stays the limit meanwhile).
  Future<Project> saveCost(String id, {double? budget, List<CostLine> plan = const [], String reason = ''}) => _guard('save the cost', () async {
    final res = await _dio.put(
      '/projects/$id/cost',
      data: {
        if (plan.isEmpty) 'budget': budget,
        if (plan.isNotEmpty) 'costPlan': [for (final l in plan) l.toJson()],
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return Project.fromJson((res.data as Map).cast<String, dynamic>());
  });

  /// The finance head approves the cost (as asked, or [approvedAmount] with a reason in [note]) or sends it back.
  Future<Project> decideCost(String id, {required bool approve, double? approvedAmount, String note = ''}) =>
      _guard(approve ? 'approve the cost' : 'send the cost back', () async {
        final res = await _dio.post(
          '/projects/$id/cost/decision',
          data: {
            'decision': approve ? 'approve' : 'return',
            if (approve && approvedAmount != null) 'approvedAmount': approvedAmount,
            if (note.trim().isNotEmpty) 'note': note.trim(),
          },
        );
        return Project.fromJson((res.data as Map).cast<String, dynamic>());
      });

  /// What the project has spent against its approved cost, and where it went (those who may see money).
  Future<ProjectSpend> getSpend(String id) => _guard('load what the project has spent', () async {
    final res = await _dio.get('/projects/$id/spend');
    return ProjectSpend.fromJson((res.data as Map).cast<String, dynamic>());
  });

  /// The projects an expense can be charged to by this person.
  Future<List<ChargeableProject>> chargeableProjects() => _guard('load the projects', () async {
    final res = await _dio.get('/projects/chargeable');
    return [for (final e in (res.data as List)) ChargeableProject.fromJson((e as Map).cast<String, dynamic>())];
  });

  /// The projects whose cost waits for the finance head (Finance only).
  Future<List<PendingProjectCost>> pendingCosts() => _guard('load the project budgets', () async {
    final res = await _dio.get('/projects/cost/pending');
    return [for (final e in (res.data as List)) PendingProjectCost.fromJson((e as Map).cast<String, dynamic>())];
  });

  Future<void> deleteProject(String id) => _guard('delete the project', () => _dio.delete('/projects/$id'));
}

/// Runs an API call and rethrows any failure as an [AppException] (keeps the
/// original error so the UI can tell offline / permission / server message).
Future<T> _guard<T>(String action, Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    throw AppException(e, action: action);
  }
}

// ── Tasks (Kanban) ───────────────────────────────────────────────────────────
final itTaskServiceProvider = Provider((ref) => ITTaskService(ref.watch(dioProvider)));

final tasksProvider = FutureProvider.family<List<ITTask>, String>(
  (ref, projectId) => ref.watch(itTaskServiceProvider).getTasks(projectId: projectId),
);

/// Every IT task across all projects (for the cross-project Roadmap).
final allTasksProvider = FutureProvider<List<ITTask>>((ref) => ref.watch(itTaskServiceProvider).getTasks());

/// Tasks assigned to the logged-in user across all projects (My Tasks).
final myTasksProvider = FutureProvider<List<ITTask>>((ref) => ref.watch(itTaskServiceProvider).getTasks(mine: true));

class ITTaskService {
  final Dio _dio;
  ITTaskService(this._dio);

  Future<List<ITTask>> getTasks({String? projectId, String? status, String? assignedTo, bool mine = false}) => _guard('load tasks', () async {
    final res = await _dio.get(
      '/it-tasks',
      queryParameters: {
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (mine) 'mine': 'true',
        if (!mine && assignedTo != null && assignedTo.isNotEmpty) 'assignedTo': assignedTo,
      },
    );
    return (res.data as List).map((e) => ITTask.fromJson((e as Map).cast<String, dynamic>())).toList();
  });

  Future<void> createTask(Map<String, dynamic> body) => _guard('create the task', () => _dio.post('/it-tasks', data: body));
  Future<void> updateTask(String id, Map<String, dynamic> body) => _guard('update the task', () => _dio.put('/it-tasks/$id', data: body));
  Future<void> deleteTask(String id) => _guard('delete the task', () => _dio.delete('/it-tasks/$id'));
}
