import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/services/role_service.dart';
import 'package:nizan_crm/services/state_service.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/services/zone_service.dart';

/// Settings → Departments: the org structure. Admin creates/edits departments
/// (grouped Administrative / Creative), assigns a head, sets the roles the head
/// may delegate, and the geography the department covers.
class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(departmentsProvider);
    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add department'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(departmentsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(departmentsProvider)),
          data: (depts) => depts.isEmpty
              ? _empty(context, ref, crm)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                  children: [
                    _syncBar(context, ref, crm),
                    12.h,
                    for (final div in kDivisions) ...[
                      _divisionHeader(crm, div, depts.where((d) => d.division == div).length),
                      for (final d in depts.where((x) => x.division == div)) _card(context, ref, crm, d),
                      12.h,
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref, CrmTheme crm) {
    return ListView(children: [
      80.h,
      Icon(Icons.apartment_outlined, size: 56, color: crm.border),
      16.h,
      Center(child: Text('No departments yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary))),
      6.h,
      Center(child: Text('Seed the 9 default departments to get started.', style: TextStyle(color: crm.textSecondary))),
      16.h,
      Center(
        child: FilledButton.icon(
          onPressed: () async {
            try {
              final n = await ref.read(departmentServiceProvider).seed();
              ref.invalidate(departmentsProvider);
              if (context.mounted) showSuccessSnackBar(context, 'Created $n departments');
            } catch (e) {
              if (context.mounted) showErrorSnackBar(context, e);
            }
          },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Seed default departments'),
        ),
      ),
    ]);
  }

  Widget _syncBar(BuildContext context, WidgetRef ref, CrmTheme crm) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(Icons.sync, size: 20, color: crm.primary),
        10.w,
        Expanded(
          child: Text('Import Timebox staff and slot artists → Artist, drivers → Fleet into their departments.',
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        ),
        8.w,
        FilledButton(
          onPressed: () => _sync(context, ref),
          child: const Text('Sync staff'),
        ),
      ]),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing staff into departments…')));
    try {
      final svc = ref.read(departmentServiceProvider);
      final tb = await svc.syncFromTimebox(); // administrative staff from Timebox
      final creative = await svc.assignByRole(); // artists → Artist, drivers → Fleet
      ref.invalidate(departmentsProvider);
      if (context.mounted) showSuccessSnackBar(context, '$tb $creative');
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  void _showMembers(BuildContext context, WidgetRef ref, Department d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MembersSheet(dept: d),
    );
  }

  Widget _divisionHeader(CrmTheme crm, String div, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 8),
      child: Row(children: [
        Icon(div == 'creative' ? Icons.palette_outlined : Icons.business_center_outlined, size: 16, color: crm.primary),
        8.w,
        Text('${divisionLabel(div).toUpperCase()} · $count',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
      ]),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, CrmTheme crm, Department d) {
    final creative = d.division == 'creative';
    final accent = creative ? const Color(0xFF7C3AED) : crm.primary;
    final hasHead = d.head != null && d.head!.name.isNotEmpty;
    final geoCount = d.zoneIds.length + d.stateIds.length + d.regionIds.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _edit(context, ref, d),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: crm.border.withValues(alpha: d.active ? 0.7 : 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
                  child: Icon(creative ? Icons.brush_outlined : Icons.business_center_outlined, color: accent, size: 23),
                ),
                12.w,
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
                      if (!d.active) ...[8.w, _pill(crm, 'Inactive', crm.textSecondary)],
                      if (d.isSystem) ...[6.w, _pill(crm, 'Default', accent)],
                    ]),
                    5.h,
                    if (hasHead)
                      Row(children: [
                        CircleAvatar(radius: 9, backgroundColor: accent.withValues(alpha: 0.15), child: Text(d.head!.name[0].toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: accent))),
                        6.w,
                        Flexible(child: Text('${d.head!.name} · Head', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textPrimary, fontWeight: FontWeight.w600))),
                      ])
                    else
                      Row(children: [
                        Icon(Icons.person_add_alt_1_outlined, size: 14, color: crm.warning),
                        4.w,
                        Text('No head assigned', style: TextStyle(fontSize: 12.5, color: crm.warning)),
                      ]),
                  ]),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') { _edit(context, ref, d); return; }
                    if (v == 'members') { _showMembers(context, ref, d); return; }
                    if (v == 'delete') {
                      try {
                        await ref.read(departmentServiceProvider).delete(d.id);
                        ref.invalidate(departmentsProvider);
                        if (context.mounted) showSuccessSnackBar(context, 'Deleted');
                      } catch (e) {
                        if (context.mounted) showErrorSnackBar(context, e);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (d.memberCount > 0) const PopupMenuItem(value: 'members', child: Text('View members')),
                    if (!d.isSystem) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ]),
              10.h,
              Padding(
                padding: const EdgeInsets.only(left: 2, right: 6),
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  _metaChip(crm, Icons.people_alt_outlined, '${d.memberCount} member${d.memberCount == 1 ? '' : 's'}',
                      color: d.memberCount > 0 ? accent : null,
                      onTap: d.memberCount > 0 ? () => _showMembers(context, ref, d) : null),
                  _metaChip(crm, Icons.verified_user_outlined, '${d.allowedRoleKeys.length} delegable role${d.allowedRoleKeys.length == 1 ? '' : 's'}'),
                  _metaChip(crm, Icons.public, geoCount == 0 ? 'PAN-India' : '$geoCount region${geoCount == 1 ? '' : 's'}'),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _metaChip(CrmTheme crm, IconData icon, String text, {VoidCallback? onTap, Color? color}) {
    final c = color ?? crm.textSecondary;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? crm.border).withValues(alpha: color != null ? 0.1 : 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c),
        5.w,
        Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color != null ? c : crm.textPrimary)),
        if (onTap != null) Icon(Icons.chevron_right, size: 14, color: c),
      ]),
    );
    return onTap == null ? chip : InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: chip);
  }

  Widget _pill(CrmTheme crm, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
      );

  Future<void> _edit(BuildContext context, WidgetRef ref, Department? existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DepartmentForm(existing: existing),
    );
    if (saved == true) ref.invalidate(departmentsProvider);
  }
}

class _DepartmentForm extends ConsumerStatefulWidget {
  const _DepartmentForm({this.existing});
  final Department? existing;

  @override
  ConsumerState<_DepartmentForm> createState() => _DepartmentFormState();
}

class _DepartmentFormState extends ConsumerState<_DepartmentForm> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late String _division;
  String? _headId;
  String? _headName;
  bool _active = true;
  late Set<String> _roles;
  late Set<String> _zones;
  late Set<String> _states;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _division = e?.division ?? 'administrative';
    _headId = e?.head?.id.isNotEmpty == true ? e!.head!.id : null;
    _headName = e?.head?.name;
    _active = e?.active ?? true;
    _roles = {...?e?.allowedRoleKeys};
    _zones = {...?e?.zoneIds};
    _states = {...?e?.stateIds};
  }

  @override
  void dispose() { _name.dispose(); _desc.dispose(); super.dispose(); }

  Future<void> _pickHead() async {
    final picked = await showModalBottomSheet<({String id, String name})?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _HeadPickerSheet(
        deptName: widget.existing?.name,
        deptKey: widget.existing?.key ?? '',
        deptId: widget.existing?.id ?? '',
        selectedId: _headId,
      ),
    );
    if (picked != null) {
      setState(() {
        _headId = picked.id.isEmpty ? null : picked.id;
        _headName = picked.id.isEmpty ? null : picked.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final rolesAsync = ref.watch(rolesProvider);
    final zonesAsync = ref.watch(zonesProvider);
    final statesAsync = ref.watch(statesProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: crm.border, borderRadius: BorderRadius.circular(2)))),
          Text(widget.existing == null ? 'New department' : 'Edit ${widget.existing!.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          14.h,
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Department name *', border: OutlineInputBorder(), isDense: true)),
          12.h,
          DropdownButtonFormField<String>(
            initialValue: _division,
            decoration: const InputDecoration(labelText: 'Division', border: OutlineInputBorder(), isDense: true),
            items: [for (final d in kDivisions) DropdownMenuItem(value: d, child: Text(divisionLabel(d)))],
            onChanged: (v) => setState(() => _division = v ?? _division),
          ),
          12.h,
          TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), isDense: true)),
          16.h,

          // Head picker → opens a searchable sheet (active users only).
          _label(crm, 'DEPARTMENT HEAD'),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _pickHead,
            child: InputDecorator(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: _headId != null
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() { _headId = null; _headName = null; }),
                      )
                    : const Icon(Icons.search),
              ),
              child: Row(children: [
                if (_headName != null && _headName!.isNotEmpty) ...[
                  CircleAvatar(radius: 12, backgroundColor: crm.primary.withValues(alpha: 0.12), child: Text(_headName![0].toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.primary))),
                  8.w,
                  Expanded(child: Text(_headName!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                ] else
                  Expanded(child: Text('Assign a head…', style: TextStyle(color: crm.textSecondary))),
              ]),
            ),
          ),
          16.h,

          // Delegable roles (the admin-approved set the head may assign).
          _label(crm, 'ROLES THE HEAD MAY ASSIGN'),
          rolesAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive, fontSize: 12)),
            data: (roles) => Wrap(spacing: 8, runSpacing: 4, children: [
              for (final r in roles)
                FilterChip(
                  label: Text(r.label),
                  selected: _roles.contains(r.key),
                  onSelected: (s) => setState(() => s ? _roles.add(r.key) : _roles.remove(r.key)),
                ),
            ]),
          ),
          16.h,

          // Geography scope.
          _label(crm, 'GEOGRAPHY SCOPE (EMPTY = ALL / PAN-INDIA)'),
          zonesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (zones) => Wrap(spacing: 8, runSpacing: 4, children: [
              for (final z in zones)
                FilterChip(
                  label: Text(z.name),
                  selected: _zones.contains(z.id),
                  onSelected: (s) => setState(() => s ? _zones.add(z.id) : _zones.remove(z.id)),
                ),
            ]),
          ),
          8.h,
          statesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (states) => Wrap(spacing: 8, runSpacing: 4, children: [
              for (final st in states)
                FilterChip(
                  label: Text(st.name),
                  selected: _states.contains(st.id),
                  onSelected: (s) => setState(() => s ? _states.add(st.id) : _states.remove(st.id)),
                ),
            ]),
          ),
          14.h,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Active'),
          ),
          8.h,
          SizedBox(
            height: 46, width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save department'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(CrmTheme crm, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
      );

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showErrorSnackBar(context, Exception('A department name is required'));
      return;
    }
    setState(() => _saving = true);
    final dept = Department(
      id: widget.existing?.id ?? '',
      key: widget.existing?.key ?? '',
      name: _name.text.trim(),
      division: _division,
      description: _desc.text.trim(),
      head: _headId == null ? null : DeptHead(id: _headId!),
      allowedRoleKeys: _roles.toList(),
      zoneIds: _zones.toList(),
      stateIds: _states.toList(),
      active: _active,
    );
    try {
      await ref.read(departmentServiceProvider).save(dept);
      if (mounted) { showSuccessSnackBar(context, 'Saved'); Navigator.pop(context, true); }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Bottom sheet listing a department's staff (Employees).
class _MembersSheet extends ConsumerWidget {
  const _MembersSheet({required this.dept});
  final Department dept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(departmentMembersProvider(dept.id));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: crm.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(Icons.apartment_outlined, color: crm.primary),
            10.w,
            Expanded(child: Text('${dept.name} — Staff', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ]),
        ),
        const Divider(),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(departmentMembersProvider(dept.id))),
            data: (members) => members.isEmpty
                ? Center(child: Text('No staff in this department yet.', style: TextStyle(color: crm.textSecondary)))
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = members[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: crm.primary.withValues(alpha: 0.12),
                          child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?', style: TextStyle(color: crm.primary, fontWeight: FontWeight.w800)),
                        ),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([if (m.email.isNotEmpty) m.email, if (m.role.isNotEmpty) m.role].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (m.fromTimebox)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text('Timebox', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: crm.primary))),
                          if (m.status == 'inactive') Text('inactive', style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                        ]),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}


/// Searchable department-head picker. The head is a staff member (Employee), so
/// Timebox-imported staff (no login) can be heads too. Fetches ACTIVE employees,
/// can scope to this department's staff, searches by name/email/role. Returns
/// ({id, name}) — id '' means "no head".
class _HeadPickerSheet extends ConsumerStatefulWidget {
  const _HeadPickerSheet({this.deptName, required this.deptKey, required this.deptId, this.selectedId});
  final String? deptName;
  final String deptKey, deptId;
  final String? selectedId;

  @override
  ConsumerState<_HeadPickerSheet> createState() => _HeadPickerSheetState();
}

class _HeadPickerSheetState extends ConsumerState<_HeadPickerSheet> {
  final _search = TextEditingController();
  String _q = '';
  bool _scopeToDept = true;

  @override
  void initState() {
    super.initState();
    _scopeToDept = widget.deptId.isNotEmpty;
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  String _roleOf(Employee e) => (e.role ?? '').isNotEmpty ? e.role! : (e.artistRole.isNotEmpty ? e.artistRole : e.type);

  _Cand _fromMember(DeptMember m) =>
      (id: m.id, name: m.name, email: m.email, role: m.role, active: m.status == 'active', fromTimebox: m.fromTimebox);
  _Cand _fromEmployee(Employee e) =>
      (id: e.id, name: e.name, email: e.email, role: _roleOf(e), active: e.status == 'active', fromTimebox: false);

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final scoped = _scopeToDept && widget.deptId.isNotEmpty;
    final empAsync = ref.watch(employeesProvider);
    final membersAsync =
        widget.deptId.isEmpty ? null : ref.watch(departmentMembersProvider(widget.deptId));
    final memberCount = membersAsync?.asData?.value.length ?? 0;

    // Scoped: source the roster straight from the department-members endpoint so
    // EVERY member shows — including Timebox-imported staff, who are often
    // inactive and would be dropped if we filtered `employeesProvider` by status.
    // Unscoped: browse all employees. Either branch keeps loading/error state.
    final candsAsync = scoped
        ? membersAsync!.whenData((ms) => ms.map(_fromMember).toList())
        : empAsync.whenData((es) => es.map(_fromEmployee).toList());

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: crm.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Icon(Icons.badge_outlined, color: crm.primary),
            10.w,
            Expanded(child: Text('Choose ${widget.deptName ?? 'department'} head', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search staff by name, email or role…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _q.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () { _search.clear(); setState(() => _q = ''); }),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (widget.deptId.isNotEmpty && memberCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              FilterChip(
                label: Text('This department only ($memberCount)'),
                selected: _scopeToDept,
                onSelected: (v) => setState(() => _scopeToDept = v),
              ),
            ]),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: candsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(
              error: e,
              onRetry: () => ref.invalidate(
                  scoped ? departmentMembersProvider(widget.deptId) : employeesProvider),
            ),
            data: (all) {
              var list = all;
              if (_q.isNotEmpty) {
                list = list.where((e) => '${e.name} ${e.email} ${e.role}'.toLowerCase().contains(_q)).toList();
              }
              list.sort((a, b) {
                if (a.active != b.active) return a.active ? -1 : 1; // active first
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
                children: [
                  ListTile(
                    leading: CircleAvatar(backgroundColor: crm.border.withValues(alpha: 0.4), child: Icon(Icons.person_off_outlined, size: 18, color: crm.textSecondary)),
                    title: const Text('No head'),
                    trailing: widget.selectedId == null ? Icon(Icons.check, color: crm.primary) : null,
                    onTap: () => Navigator.pop(context, (id: '', name: '')),
                  ),
                  const Divider(height: 1),
                  if (list.isEmpty)
                    Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(_q.isNotEmpty ? 'No staff match "$_q".' : 'No staff found.', style: TextStyle(color: crm.textSecondary))))
                  else
                    for (final e in list)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (e.active ? crm.primary : crm.textSecondary).withValues(alpha: 0.12),
                          child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?', style: TextStyle(color: e.active ? crm.primary : crm.textSecondary, fontWeight: FontWeight.w800)),
                        ),
                        title: Row(children: [
                          Flexible(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (e.fromTimebox) ...[6.w, _tag('Timebox', crm.primary)],
                          if (!e.active) ...[6.w, _tag('Inactive', crm.textSecondary)],
                        ]),
                        subtitle: Text([if (e.email.isNotEmpty) e.email, if (e.role.isNotEmpty) e.role].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: e.id == widget.selectedId ? Icon(Icons.check, color: crm.primary) : null,
                        onTap: () => Navigator.pop(context, (id: e.id, name: e.name)),
                      ),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// A unified head candidate — one shape for both a department [DeptMember]
/// (scoped roster, includes inactive Timebox staff) and an [Employee]
/// (browse-all mode).
typedef _Cand = ({String id, String name, String email, String role, bool active, bool fromTimebox});
