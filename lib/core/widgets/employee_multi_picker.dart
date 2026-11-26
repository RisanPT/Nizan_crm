import 'package:flutter/material.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

// Picking SEVERAL people (a project's team): a search box (name, role, department, employee code), quick group chips, a tick per
// person and "Done". [EmployeeMultiPickerField] is the form field around it: the people picked as removable chips, and "Add people".

/// What a person is described by in the list: their department, else their role / specialisation.
String employeeDescriptor(Employee e) {
  for (final v in [e.department, e.role, e.designation, e.specialization, e.artistRole, e.category]) {
    final s = (v ?? '').trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

/// Does [e] match the search [query]? Every word must appear in their name, code, role, department or phone.
bool employeeMatches(Employee e, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final hay = [e.name, e.employeeCode, e.role ?? '', e.designation, e.specialization, e.artistRole, e.category, e.department ?? '', e.phone]
      .join(' ')
      .toLowerCase();
  return words.every(hay.contains);
}

/// Opens the picker; returns the ids ticked when "Done" is pressed, or null when it is closed without.
Future<Set<String>?> showEmployeeMultiPicker(
  BuildContext context, {
  required List<Employee> employees,
  required Set<String> selected,
  String title = 'Add people',
  String? subtitle,
}) {
  final body = _MultiPicker(employees: employees, selected: selected, title: title, subtitle: subtitle);
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: body),
    );
  }
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680), child: body),
    ),
  );
}

class _MultiPicker extends StatefulWidget {
  const _MultiPicker({required this.employees, required this.selected, required this.title, this.subtitle});

  final List<Employee> employees;
  final Set<String> selected;
  final String title;
  final String? subtitle;

  @override
  State<_MultiPicker> createState() => _MultiPickerState();
}

class _MultiPickerState extends State<_MultiPicker> {
  final _search = TextEditingController();
  late final Set<String> _picked = {...widget.selected};
  String _query = '';
  String _group = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _groups {
    final set = {for (final e in widget.employees) employeeDescriptor(e)}..remove('');
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<Employee> get _shown => widget.employees
      .where((e) => (_group.isEmpty || employeeDescriptor(e) == _group) && employeeMatches(e, _query))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final shown = _shown;
    final groups = _groups;
    final pickedHere = widget.employees.where((e) => _picked.contains(e.id)).length;
    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                  if (widget.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(widget.subtitle!, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ),
                ]),
              ),
              IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: TextField(
              key: const Key('emp_multi_search'),
              controller: _search,
              autofocus: MediaQuery.sizeOf(context).width >= 600,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search name, role, department or code',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          if (groups.length > 1)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  for (final g in ['', ...groups])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: Key('emp_multi_group_${g.isEmpty ? 'all' : g}'),
                        label: Text(g.isEmpty ? 'All' : g, style: const TextStyle(fontSize: 12)),
                        selected: _group == g,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _group = g),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.employees.isEmpty ? 'No staff to pick from yet.' : 'Nobody matches "${_query.trim()}".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: crm.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final e = shown[i];
                      final on = _picked.contains(e.id);
                      final about = [employeeDescriptor(e), if (e.employeeCode.trim().isNotEmpty) e.employeeCode.trim()]
                          .where((s) => s.isNotEmpty)
                          .join(' · ');
                      return CheckboxListTile(
                        key: Key('emp_multi_${e.id}'),
                        value: on,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.trailing,
                        onChanged: (v) => setState(() => v == true ? _picked.add(e.id) : _picked.remove(e.id)),
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundColor: crm.primary.withValues(alpha: on ? 0.9 : 0.1),
                          child: Text(_initials(e.name),
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: on ? Colors.white : crm.primary)),
                        ),
                        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: about.isEmpty ? null : Text(about, maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(children: [
              Expanded(
                child: Text(
                  '${_picked.length} picked',
                  key: const Key('emp_multi_count'),
                  style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
              ),
              if (pickedHere > 0)
                TextButton(
                  key: const Key('emp_multi_clear'),
                  onPressed: () => setState(() => _picked.removeWhere((id) => widget.employees.any((e) => e.id == id))),
                  child: const Text('Clear'),
                ),
              const SizedBox(width: 6),
              FilledButton(
                key: const Key('emp_multi_done'),
                onPressed: () => Navigator.pop(context, _picked),
                child: const Text('Done'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// The form field: the people picked as chips (× removes one) and "Add people", which opens the searchable picker.
/// [knownNames] names people who are picked but not in [employees] (they left, or their department is no longer on the
/// project) so they still show — and can be removed — instead of staying on the team unseen.
class EmployeeMultiPickerField extends StatelessWidget {
  const EmployeeMultiPickerField({
    super.key,
    required this.employees,
    required this.selectedIds,
    required this.onChanged,
    this.knownNames = const {},
    this.lockedIds = const {},
    this.lockedNote = '',
    this.label = 'Team members',
    this.helper,
    this.pickerTitle = 'Add team members',
  });

  final List<Employee> employees;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final Map<String, String> knownNames;

  /// People shown but not removable here (e.g. another department's people, for a department lead), with [lockedNote] as the reason.
  final Set<String> lockedIds;
  final String lockedNote;
  final String label;
  final String? helper;
  final String pickerTitle;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final byId = {for (final e in employees) e.id: e};
    final picked = [
      for (final id in selectedIds)
        if (id.isNotEmpty) (id: id, name: byId[id]?.name ?? knownNames[id] ?? 'Unknown person', inPool: byId.containsKey(id)),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    Future<void> add() async {
      final got = await showEmployeeMultiPicker(
        context,
        employees: employees,
        selected: selectedIds,
        title: pickerTitle,
        subtitle: helper,
      );
      if (got != null) onChanged(got);
    }

    return Column(
      key: const Key('emp_multi_field'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              picked.isEmpty ? label : '$label (${picked.length})',
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            key: const Key('emp_multi_add'),
            onPressed: add,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: Text(picked.isEmpty ? 'Add people' : 'Add or remove'),
          ),
        ]),
        if (picked.isEmpty)
          InkWell(
            onTap: add,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
              child: Row(children: [
                Icon(Icons.search, size: 18, color: crm.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text('Nobody yet — search and add people', style: TextStyle(fontSize: 13, color: crm.textSecondary))),
              ]),
            ),
          )
        else
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in picked)
              Tooltip(
                message: lockedIds.contains(p.id) ? lockedNote : (p.inPool ? '' : 'Not in the departments on this project any more'),
                child: InputChip(
                  key: Key('emp_multi_chip_${p.id}'),
                  label: Text(p.name, style: TextStyle(fontSize: 12, color: p.inPool ? null : crm.textSecondary)),
                  avatar: lockedIds.contains(p.id)
                      ? Icon(Icons.lock_outline, size: 14, color: crm.textSecondary)
                      : (p.inPool ? null : Icon(Icons.info_outline, size: 15, color: crm.textSecondary)),
                  onDeleted: lockedIds.contains(p.id) ? null : () => onChanged({...selectedIds}..remove(p.id)),
                  deleteButtonTooltipMessage: 'Remove ${p.name}',
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ]),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(helper!, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ),
      ],
    );
  }
}
