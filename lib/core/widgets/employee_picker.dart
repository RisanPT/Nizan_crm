import 'package:flutter/material.dart';

import '../models/employee.dart';

/// Opens a searchable / filterable employee picker sheet or centered dialog.
///
/// The caller pre-filters [employees] (active-only, role-scoped, IT-only, …);
/// this widget adds live search (name / role / department) and quick department
/// filter chips with rich department badges. Returns the chosen [Employee], or
/// null if dismissed.
Future<Employee?> showEmployeePicker(
  BuildContext context, {
  required List<Employee> employees,
  String? selectedId,
  String title = 'Employee Profile (Optional)',
  String? subtitle,
}) {
  final isMobile = MediaQuery.sizeOf(context).width < 600;
  if (isMobile) {
    return showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmployeePickerSheet(
        employees: employees,
        selectedId: selectedId,
        title: title,
        subtitle: subtitle,
        isDialog: false,
      ),
    );
  }

  return showDialog<Employee>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: _EmployeePickerSheet(
          employees: employees,
          selectedId: selectedId,
          title: title,
          subtitle: subtitle,
          isDialog: true,
        ),
      ),
    ),
  );
}

class _EmployeePickerSheet extends StatefulWidget {
  final List<Employee> employees;
  final String? selectedId;
  final String title;
  final String? subtitle;
  final bool isDialog;

  const _EmployeePickerSheet({
    required this.employees,
    required this.selectedId,
    required this.title,
    this.subtitle,
    this.isDialog = false,
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

  // Best short descriptor when department isn't set — the role/makeup label
  // the rest of the app shows (MUA, Hair And Saree, Fleet Driver, …).
  String _descriptor(Employee e) {
    for (final v in [e.role, e.specialization, e.artistRole, e.category]) {
      final s = (v ?? '').trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  late final bool _useDept = () {
    final set = <String>{};
    for (final e in widget.employees) {
      final d = (e.department ?? '').trim();
      if (d.isNotEmpty) set.add(d);
    }
    return set.length > 1;
  }();

  String _groupOf(Employee e) =>
      _useDept ? (e.department ?? '').trim() : _descriptor(e);

  List<String> get _groups {
    final set = <String>{};
    for (final e in widget.employees) {
      final g = _groupOf(e).trim();
      if (g.isNotEmpty) set.add(g);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Employee> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.employees.where((e) {
      if (_dept.isNotEmpty && _groupOf(e).trim().toLowerCase() != _dept.toLowerCase()) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay =
          '${e.name} ${e.role ?? ''} ${e.specialization} ${e.artistRole} ${e.category} ${e.department ?? ''}'
              .toLowerCase();
      return hay.contains(q);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'[\s@._-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  (IconData icon, Color bg, Color fg) _deptMeta(String dept) {
    switch (dept.toLowerCase().trim()) {
      case 'management':
        return (
          Icons.workspace_premium_outlined,
          const Color(0xFFFEF3C7),
          const Color(0xFFD97706),
        );
      case 'marketing':
        return (
          Icons.campaign_outlined,
          const Color(0xFFFCE4EC),
          const Color(0xFFE05A6F),
        );
      case 'sales':
        return (
          Icons.bar_chart_outlined,
          const Color(0xFFE8F5E9),
          const Color(0xFF059669),
        );
      case 'operations':
        return (
          Icons.layers_outlined,
          const Color(0xFFE0F2FE),
          const Color(0xFF0284C7),
        );
      case 'it':
      case 'technology':
        return (
          Icons.laptop_mac_outlined,
          const Color(0xFFEDE9FE),
          const Color(0xFF7C3AED),
        );
      case 'general':
        return (
          Icons.apartment_outlined,
          const Color(0xFFF3F4F6),
          const Color(0xFF4B5563),
        );
      case 'accounts':
      case 'finance':
        return (
          Icons.account_balance_outlined,
          const Color(0xFFE0F2F1),
          const Color(0xFF00897B),
        );
      case 'hr':
        return (
          Icons.people_outline,
          const Color(0xFFF3E8FF),
          const Color(0xFF9333EA),
        );
      case 'crm':
        return (
          Icons.headset_mic_outlined,
          const Color(0xFFE0F7FA),
          const Color(0xFF00838F),
        );
      default:
        return (
          Icons.domain_outlined,
          const Color(0xFFF5F5F5),
          const Color(0xFF616161),
        );
    }
  }

  Widget _buildContent(BuildContext context, ScrollController? scrollCtrl) {
    final groups = _groups;
    final results = _filtered;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle for bottom sheet
          if (!widget.isDialog) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE4EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: Color(0xFF7B1E3B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1B1D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle ??
                            'Select an employee from existing profiles to link with this user.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE4EC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${results.length} Employees',
                    style: const TextStyle(
                      color: Color(0xFF7B1E3B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, role or department...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF6B7280)),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                        }),
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7B1E3B), width: 1.5),
                ),
              ),
            ),
          ),

          // Department Filter Chips (Matching 2-row / Wrap layout in reference image)
          if (groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _deptChip(
                      label: 'All',
                      selected: _dept.isEmpty,
                      icon: _dept.isEmpty ? Icons.check : null,
                      onTap: () => setState(() => _dept = ''),
                    ),
                    for (final g in groups)
                      _deptChip(
                        label: g,
                        selected: _dept.toLowerCase() == g.toLowerCase(),
                        icon: _deptMeta(g).$1,
                        onTap: () => setState(() => _dept = g),
                      ),
                  ],
                ),
              ),
            ),

          const Divider(height: 16, color: Color(0xFFEDE7E9)),

          // Results List
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.search_off_rounded,
                              size: 40, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 10),
                          Text(
                            'No matching employees found.',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: results.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 68, color: Color(0xFFF3F4F6)),
                    itemBuilder: (ctx, i) {
                      final e = results[i];
                      final isSel = e.id == widget.selectedId;
                      final dept = (e.department ?? '').trim();
                      final meta = _deptMeta(dept);

                      final subtitleParts = [
                        if (_descriptor(e).isNotEmpty) _descriptor(e),
                        if (dept.isNotEmpty) dept,
                      ];
                      final subtitle = subtitleParts.join(' · ');

                      return InkWell(
                        onTap: () => Navigator.pop(ctx, e),
                        hoverColor: const Color(0xFFFCE4EC).withValues(alpha: 0.3),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // 2-Letter Initials Circular Avatar
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFCE4EC),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _getInitials(e.name),
                                  style: const TextStyle(
                                    color: Color(0xFF7B1E3B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Name + Role · Department
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                        color: Color(0xFF1E1B1D),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle.isEmpty ? 'Staff' : subtitle,
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 11.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Department Badge with Icon
                              if (dept.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: meta.$2,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(meta.$1, size: 12, color: meta.$3),
                                      const SizedBox(width: 4),
                                      Text(
                                        dept,
                                        style: TextStyle(
                                          color: meta.$3,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 8),

                              // Trailing indicator (check if selected, else chevron)
                              Icon(
                                isSel ? Icons.check_circle : Icons.chevron_right,
                                color: isSel
                                    ? const Color(0xFF7B1E3B)
                                    : const Color(0xFF9CA3AF),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _deptChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7B1E3B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF7B1E3B) : const Color(0xFFE5E7EB),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7B1E3B).withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : const Color(0xFF4B5563),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) {
      return _buildContent(context, null);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scrollCtrl) => _buildContent(ctx, scrollCtrl),
    );
  }
}

/// A form-field-style employee selector: shows the current selection and opens
/// the upgraded [showEmployeePicker] popup on tap. Drop-in replacement for a
/// `DropdownButtonFormField` of employees.
class EmployeePickerField extends StatelessWidget {
  final List<Employee> employees;
  final String? selectedId;
  final String? selectedName;
  final String label;
  final IconData icon;
  final bool allowUnassign;
  final ValueChanged<Employee?> onChanged;
  final InputDecoration Function(InputDecoration base)? decorate;

  const EmployeePickerField({
    super.key,
    required this.employees,
    required this.selectedId,
    required this.onChanged,
    this.selectedName,
    this.label = 'Assign to',
    this.icon = Icons.link_outlined,
    this.allowUnassign = true,
    this.decorate,
  });

  InputDecoration _decoration(bool hasSelection) {
    final base = InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
      suffixIcon: (allowUnassign && hasSelection)
          ? IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
              onPressed: () => onChanged(null),
            )
          : const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7B1E3B), width: 1.5),
      ),
    );
    return decorate == null ? base : decorate!(base);
  }

  @override
  Widget build(BuildContext context) {
    Employee? selected;
    for (final e in employees) {
      if (e.id == selectedId) {
        selected = e;
        break;
      }
    }
    final hasSelection = (selectedId ?? '').isNotEmpty;
    final display = selected?.name ??
        (hasSelection
            ? (selectedName ?? 'Selected')
            : (allowUnassign ? 'Unassigned' : 'Tap to select'));

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showEmployeePicker(
          context,
          employees: employees,
          selectedId: selectedId,
          title: label,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: _decoration(hasSelection),
        child: Text(
          display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w400,
            color: hasSelection
                ? const Color(0xFF1E1B1D)
                : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}
