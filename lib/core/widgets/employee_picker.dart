import 'package:flutter/material.dart';

import '../models/employee.dart';
import '../theme/crm_theme.dart';

/// Opens a searchable / filterable employee picker sheet.
///
/// The caller pre-filters [employees] (active-only, role-scoped, IT-only, …);
/// this widget adds live search (name / role / department) and — when the list
/// spans more than one department — quick department filter chips. Returns the
/// chosen [Employee], or null if dismissed.
Future<Employee?> showEmployeePicker(
  BuildContext context, {
  required List<Employee> employees,
  String? selectedId,
  String title = 'Select employee',
}) {
  return showModalBottomSheet<Employee>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EmployeePickerSheet(
      employees: employees,
      selectedId: selectedId,
      title: title,
    ),
  );
}

class _EmployeePickerSheet extends StatefulWidget {
  final List<Employee> employees;
  final String? selectedId;
  final String title;
  const _EmployeePickerSheet({
    required this.employees,
    required this.selectedId,
    required this.title,
  });

  @override
  State<_EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _dept = ''; // '' = all

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _departments {
    final set = <String>{};
    for (final e in widget.employees) {
      final d = (e.department ?? '').trim();
      if (d.isNotEmpty) set.add(d);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Employee> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.employees.where((e) {
      if (_dept.isNotEmpty && (e.department ?? '').trim() != _dept) return false;
      if (q.isEmpty) return true;
      final hay = '${e.name} ${e.role ?? ''} ${e.artistRole} ${e.department ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final depts = _departments;
    final results = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: crm.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(children: [
                Icon(Icons.groups_outlined, color: crm.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                Text('${results.length}', style: TextStyle(color: crm.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ]),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, role or department…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() { _searchCtrl.clear(); _query = ''; }),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: crm.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.border)),
                ),
              ),
            ),
            // Department filter chips (only when the list spans multiple depts)
            if (depts.length > 1)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  children: [
                    _deptChip(crm, 'All', _dept.isEmpty, () => setState(() => _dept = '')),
                    for (final d in depts) _deptChip(crm, d, _dept == d, () => setState(() => _dept = d)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Divider(height: 1, color: crm.border),
            // Results
            Expanded(
              child: results.isEmpty
                  ? Center(child: Text('No matching employees.', style: TextStyle(color: crm.textSecondary)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: results.length,
                      itemBuilder: (ctx, i) {
                        final e = results[i];
                        final isSel = e.id == widget.selectedId;
                        final subtitle = [
                          if ((e.role ?? '').trim().isNotEmpty) e.role!.trim(),
                          if ((e.department ?? '').trim().isNotEmpty) e.department!.trim(),
                        ].join(' · ');
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: crm.primary.withValues(alpha: 0.12),
                            child: Text(
                              e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                              style: TextStyle(color: crm.primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: subtitle.isEmpty ? null : Text(subtitle, style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                          trailing: isSel ? Icon(Icons.check_circle, color: crm.primary) : null,
                          selected: isSel,
                          selectedTileColor: crm.primary.withValues(alpha: 0.06),
                          onTap: () => Navigator.pop(ctx, e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deptChip(CrmTheme crm, String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: crm.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            fontSize: 12.5,
            color: selected ? crm.primary : crm.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
}

/// A form-field-style employee selector: shows the current selection and opens
/// the searchable [showEmployeePicker] sheet on tap. Drop-in replacement for a
/// `DropdownButtonFormField` of employees.
class EmployeePickerField extends StatelessWidget {
  final List<Employee> employees;
  final String? selectedId;
  final String? selectedName; // fallback label if the id isn't in [employees]
  final String label;
  final IconData icon;
  final bool allowUnassign;
  final ValueChanged<Employee?> onChanged; // null → unassigned (only if allowUnassign)

  const EmployeePickerField({
    super.key,
    required this.employees,
    required this.selectedId,
    required this.onChanged,
    this.selectedName,
    this.label = 'Assign to',
    this.icon = Icons.person_outline,
    this.allowUnassign = true,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Employee? selected;
    for (final e in employees) {
      if (e.id == selectedId) { selected = e; break; }
    }
    final hasSelection = (selectedId ?? '').isNotEmpty;
    final display = selected?.name ??
        (hasSelection ? (selectedName ?? 'Selected') : (allowUnassign ? 'Unassigned' : 'Tap to select'));

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showEmployeePicker(context, employees: employees, selectedId: selectedId, title: label);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: Icon(icon, size: 18),
          suffixIcon: (allowUnassign && hasSelection)
              ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.search, size: 18),
        ),
        child: Text(
          display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: hasSelection ? crm.textPrimary : crm.textSecondary),
        ),
      ),
    );
  }
}
