import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';

/// Department choices for HR forms (2026-11-24): the active departments in the
/// HR Departments master. This replaces the hard-coded lists ('Bridal Styling',
/// 'Executive / Governance', …). A record's current department is always kept
/// as an option, so opening and saving a form never silently changes it.
List<String> hrDepartmentOptions(List<Department> departments, {String current = ''}) {
  final names = <String>[];
  for (final d in departments) {
    final n = d.name.trim();
    if (n.isEmpty || (!d.active && n.toLowerCase() != current.trim().toLowerCase())) continue;
    if (!names.any((x) => x.toLowerCase() == n.toLowerCase())) names.add(n);
  }
  names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final cur = current.trim();
  if (cur.isNotEmpty && !names.any((x) => x.toLowerCase() == cur.toLowerCase())) {
    names.insert(0, cur);
  }
  return names;
}

/// The option matching [current] (case-insensitive), or '' when there is none.
String hrDepartmentValue(List<String> options, String current) {
  final cur = current.trim().toLowerCase();
  if (cur.isEmpty) return '';
  return options.firstWhere((x) => x.toLowerCase() == cur, orElse: () => '');
}

/// Loads the departments for a dialog opened from an event handler. An error
/// gives an empty list (the form still keeps the record's own department).
Future<List<Department>> readHrDepartments(WidgetRef ref) async {
  try {
    return await ref.read(departmentsProvider.future);
  } catch (_) {
    return const [];
  }
}
