import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

/// The signed-in user's department NAME, resolved in priority order so a
/// department head is recognised however their record is set up:
///   1. the session's `departmentName` (sent by the backend)
///   2. the session's `departmentId` matched against the departments list
///   3. the linked Employee record's `department`
/// Returns '' when none resolve (the user has no department assigned).
final myDepartmentNameProvider = Provider<String>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session == null) return '';

  var name = session.departmentName.trim();

  if (name.isEmpty && session.departmentId.isNotEmpty) {
    final depts = ref.watch(departmentsProvider).value ?? const <Department>[];
    final match = depts.where((d) => d.id == session.departmentId);
    if (match.isNotEmpty) name = match.first.name.trim();
  }

  if (name.isEmpty && session.employeeId.isNotEmpty) {
    final emps = ref.watch(employeesProvider).value ?? const <Employee>[];
    final me = emps.where((e) => e.id == session.employeeId);
    if (me.isNotEmpty) name = (me.first.department ?? '').trim();
  }

  return name;
});
