import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';

/// What the signed-in person may do to ONE task — the same rules the server applies
/// (backend `taskRights`), so the app hides what would be refused.
///
///  * [plan]     change anything: title, dates, assignee, department, place in the plan
///  * [progress] change how it is going: status, % complete, hours, sub-tasks, notes
///  * [delete]   remove it
class TaskRights {
  const TaskRights({this.plan = false, this.progress = false, this.delete = false});

  final bool plan;
  final bool progress;
  final bool delete;

  static const all = TaskRights(plan: true, progress: true, delete: true);
  static const none = TaskRights();

  /// Can change something, but only how it is going.
  bool get progressOnly => progress && !plan;
  bool get readOnly => !plan && !progress;
}

/// [project] null = still loading / unknown: nothing is hidden (the server still decides).
TaskRights taskRightsFor(Project? project, ITTask task, {required String myEmployeeId}) {
  if (project == null) return TaskRights.all;
  final a = project.access;
  if (!a.isManaged || a.canManage) return TaskRights.all;

  final dept = task.departmentName.trim().isEmpty ? project.targetDepartment : task.departmentName;
  if (a.leadDepartments.any((d) => d.toLowerCase() == dept.trim().toLowerCase())) return TaskRights.all;

  final mine = myEmployeeId.isNotEmpty && task.assigneeId == myEmployeeId;
  return TaskRights(progress: mine);
}

/// Task fields only a plan-changer may send. Everything else on the task form is progress.
const planOnlyTaskFields = {
  'title',
  'description',
  'ticketType',
  'category',
  'severity',
  'priority',
  'subTeam',
  'assignedTo',
  'startDate',
  'deadline',
  'dueDate',
  'estimatedHours',
  'order',
  'departmentName',
  'predecessorIds',
  'parentTaskId',
};
