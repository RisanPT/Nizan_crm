import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/widgets/employee_multi_picker.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// Who is on a project — its manager and its team members — on the project's Overview, and changing them after the project
// was created ("Edit team"). The manager and the members can open the project and are the people its tasks are given to.

/// Everyone who can be on the team of a project run by [departments] (the owning department first): each person once, by name.
List<Employee> projectPeoplePool(List<Employee> Function(String department) staffOf, Iterable<String> departments) {
  final seen = <String>{};
  final names = <String>[];
  for (final d in departments) {
    final t = d.trim();
    if (t.isNotEmpty && seen.add(t.toLowerCase())) names.add(t);
  }
  final pool = <String, Employee>{
    for (final d in names)
      for (final e in staffOf(d)) e.id: e,
  }.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return pool;
}

/// The names the project already knows its members by (so someone who left the pool still shows by name).
Map<String, String> memberNamesOf(Project p) => {
      for (var i = 0; i < p.memberIds.length; i++)
        if (i < p.memberNames.length && p.memberNames[i].trim().isNotEmpty) p.memberIds[i]: p.memberNames[i].trim(),
    };

/// The note under a team picker: who can be picked and how to reach someone from another department.
String teamPoolNote(String owner, Iterable<String> others) {
  final seen = <String>{};
  final names = [
    for (final d in [owner, ...others])
      if (d.trim().isNotEmpty && seen.add(d.trim().toLowerCase())) d.trim(),
  ];
  if (names.isEmpty) return 'Pick the owning department first — its people (and those of the departments it involves) can be added.';
  return 'People from ${names.join(', ')}. Someone from another department? Add that department to the project first.';
}

/// Is [e] one of [department]'s people — by department or category, with NO "everyone" fallback (a department lead changes only
/// their own department's people; the server applies the same rule).
bool inDepartment(Employee e, String department) {
  final d = department.trim().toLowerCase();
  return d.isNotEmpty && ((e.department ?? '').trim().toLowerCase() == d || e.category.trim().toLowerCase() == d);
}

// ── someone taken off who still has work on the project ─────────────────────

/// One person the server asked about before taking them off: their open tasks and an HR placement still running.
class TeamWork {
  const TeamWork({required this.id, required this.name, this.openTasks = 0, this.placementTo, this.placementPercent});
  final String id;
  final String name;
  final int openTasks;
  final DateTime? placementTo;
  final int? placementPercent;
  bool get placed => placementTo != null;

  factory TeamWork.fromJson(Map<String, dynamic> j) {
    final p = j['placement'];
    return TeamWork(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      openTasks: (j['openTasks'] as num?)?.toInt() ?? 0,
      placementTo: p is Map ? DateTime.tryParse('${p['to'] ?? ''}')?.toLocal() : null,
      placementPercent: p is Map ? (p['percent'] as num?)?.toInt() : null,
    );
  }

  /// "1 open task · HR placement (50%) until 24 Dec"
  String get what => [
        if (openTasks > 0) '$openTasks open task${openTasks == 1 ? '' : 's'}',
        if (placed) 'HR placement${placementPercent == null ? '' : ' ($placementPercent%)'} until ${DateFormat('d MMM').format(placementTo!)}',
      ].join(' · ');
}

/// The server's 409 TEAM_REMOVAL_HAS_WORK: who would be taken off with work still on the project. Null for any other error.
class TeamRemovalConflict {
  const TeamRemovalConflict(this.message, this.people);
  final String message;
  final List<TeamWork> people;

  static TeamRemovalConflict? of(Object? error) {
    final cause = error is AppException ? error.cause : error;
    if (cause is! DioException || cause.response?.statusCode != 409) return null;
    final data = cause.response?.data;
    if (data is! Map || data['code'] != 'TEAM_REMOVAL_HAS_WORK') return null;
    return TeamRemovalConflict('${data['message'] ?? ''}', [
      for (final p in (data['people'] as List? ?? const [])) TeamWork.fromJson((p as Map).cast<String, dynamic>()),
    ]);
  }
}

/// Asks before taking people off who still have work: their open tasks can lose their assignee (ticked by default), an HR
/// placement ends today and HR is told. Returns whether to unassign, or null to keep them on.
Future<bool?> askTeamRemoval(BuildContext context, TeamRemovalConflict c) {
  final hasTasks = c.people.any((p) => p.openTasks > 0);
  final placed = c.people.any((p) => p.placed);
  var unassign = true;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final crm = ctx.crmColors;
        return AlertDialog(
          key: const Key('team_removal_dialog'),
          title: Text(c.people.length == 1 ? 'Take ${c.people.first.name} off the project?' : 'Take ${c.people.length} people off the project?'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('They still have work on it:', style: TextStyle(color: crm.textSecondary)),
              const SizedBox(height: 8),
              for (final p in c.people)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.person_outline, size: 16, color: crm.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: ' — ${p.what}'),
                      ])),
                    ),
                  ]),
                ),
              if (hasTasks)
                CheckboxListTile(
                  key: const Key('team_removal_unassign'),
                  value: unassign,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setLocal(() => unassign = v ?? false),
                  title: const Text('Unassign their open tasks'),
                  subtitle: Text(unassign ? 'Give them to someone else afterwards.' : 'They stay assigned to them.'),
                ),
              if (placed)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Their HR placement on this project ends today, and HR is told.', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep them')),
            FilledButton(
              key: const Key('team_removal_confirm'),
              onPressed: () => Navigator.pop(ctx, hasTasks && unassign),
              child: const Text('Take off'),
            ),
          ],
        );
      },
    ),
  );
}

/// Saves with [save] (the extra body fields); when the server says someone taken off still has work, asks and — once confirmed —
/// saves again. Null when the person chose to keep them; any other error is thrown as it came.
Future<Project?> saveTeamChecked(BuildContext context, Future<Project> Function(Map<String, dynamic> extra) save) async {
  try {
    return await save(const {});
  } catch (e) {
    final conflict = TeamRemovalConflict.of(e);
    if (conflict == null || !context.mounted) rethrow;
    final unassign = await askTeamRemoval(context, conflict);
    if (unassign == null) return null;
    return save({'confirmRemoval': true, 'unassignTasks': unassign});
  }
}

// ── the card ─────────────────────────────────────────────────────────────────

class ProjectPeopleCard extends ConsumerWidget {
  const ProjectPeopleCard({super.key, required this.project});
  final Project project;

  /// Who may change the people (the server checks too), while it is not closed: those who run the project, and the lead of a
  /// department working on it (their own department's people).
  static bool canEdit(Project p) => (p.access.canManage || p.access.leadDepartments.isNotEmpty) && p.status != 'cancelled';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final p = project;
    final names = memberNamesOf(p);
    final staff = {for (final e in ref.watch(activeEmployeesProvider)) e.id: e.name};
    final members = [
      for (final id in p.memberIds)
        if (id.isNotEmpty && id != p.managerId) (id: id, name: staff[id] ?? names[id] ?? 'Unknown person'),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final may = canEdit(p);

    Widget person(String id, String name, {bool lead = false}) => Container(
          key: Key('people_chip_${lead ? 'manager' : id}'),
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(
            color: lead ? crm.primary.withValues(alpha: 0.08) : crm.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: lead ? crm.primary.withValues(alpha: 0.35) : crm.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: crm.primary.withValues(alpha: lead ? 0.9 : 0.12),
              child: Text(
                name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: lead ? Colors.white : crm.primary),
              ),
            ),
            const SizedBox(width: 6),
            Text(name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary)),
            if (lead) ...[
              const SizedBox(width: 6),
              Text('Manager', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.primary)),
            ],
          ]),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        key: const Key('project_people_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.groups_outlined, size: 18, color: crm.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Project team · ${members.length + (p.managerId.isEmpty ? 0 : 1)}',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
            ),
            if (may)
              TextButton.icon(
                key: const Key('people_edit'),
                onPressed: () => showProjectPeopleSheet(context, ref, p),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit team'),
              ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (p.managerId.isNotEmpty) person(p.managerId, staff[p.managerId] ?? (p.managerName.isEmpty ? 'Manager' : p.managerName), lead: true),
            for (final m in members) person(m.id, m.name),
          ]),
          const SizedBox(height: 8),
          Text(
            members.isEmpty
                ? (may ? 'No team members yet. Add the people who work on it — they can open the project and be given tasks.' : 'No team members yet.')
                : 'The manager and the team can open the project and be given its tasks.',
            key: const Key('people_note'),
            style: TextStyle(fontSize: 12, color: crm.textSecondary),
          ),
        ]),
      ),
    );
  }
}

// ── changing them ────────────────────────────────────────────────────────────

/// "Edit team". Those who run the project change the manager (from the owning department) and the members (from the departments
/// on the project). The lead of another department on it changes only that department's people: the manager is shown, not picked,
/// and the rest of the team is shown locked. Saves only the people; someone taken off with work still on the project is asked about
/// first. Returns true when saved.
Future<bool> showProjectPeopleSheet(BuildContext context, WidgetRef ref, Project p) async {
  final runs = p.access.canManage;
  final leads = runs ? const <String>[] : p.access.leadDepartments;
  String? managerId = p.managerId.isEmpty ? null : p.managerId;
  final members = <String>{...p.memberIds.where((id) => id.isNotEmpty && id != p.managerId)};
  final names = memberNamesOf(p);
  final departments = [p.targetDepartment, ...p.departmentNames];
  final me = ref.read(authSessionProvider)?.employeeId ?? '';
  final messenger = ScaffoldMessenger.of(context);
  var busy = false;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Consumer(builder: (ctx, cref, _) {
        // the staff list may still be loading when this opens: the pickers fill in once it arrives
        final owners = cref.watch(departmentEmployeesProvider(p.targetDepartment));
        final List<Employee> pool = runs
            ? projectPeoplePool((d) => cref.watch(departmentEmployeesProvider(d)), departments)
            : [for (final e in cref.watch(activeEmployeesProvider)) if (leads.any((d) => inDepartment(e, d))) e];
        final poolIds = {for (final e in pool) e.id};
        // a lead sees the rest of the team, but only their own department's people can be taken off by them
        final locked = runs ? const <String>{} : {for (final id in members) if (!poolIds.contains(id)) id};
        final crm = ctx.crmColors;
        final handingOver = me.isNotEmpty && p.managerId == me && managerId != null && managerId != me;
        final leadNames = leads.join(', ');
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Edit team', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              const SizedBox(height: 2),
              Text(p.name, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              const SizedBox(height: 16),
              if (runs)
                EmployeePickerField(
                  key: const Key('people_manager'),
                  employees: owners,
                  selectedId: managerId,
                  selectedName: p.managerName,
                  label: 'Project Head / Manager *',
                  allowUnassign: false,
                  onChanged: (e) => setSheet(() {
                    managerId = e?.id;
                    if (managerId != null) members.remove(managerId); // the manager is not also a member
                  }),
                )
              else
                Container(
                  key: const Key('people_manager_fixed'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
                  child: Row(children: [
                    Icon(Icons.lock_outline, size: 16, color: crm.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: 'Project manager: ', style: TextStyle(color: crm.textSecondary)),
                        TextSpan(text: p.managerName.isEmpty ? '—' : p.managerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ])),
                    ),
                  ]),
                ),
              if (handingOver)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'You hand the project over: the new manager runs it from now on.',
                    key: const Key('people_handover'),
                    style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800),
                  ),
                ),
              const SizedBox(height: 16),
              EmployeeMultiPickerField(
                employees: [for (final e in pool) if (e.id != managerId) e],
                selectedIds: members,
                knownNames: {
                  ...names,
                  for (final e in cref.watch(activeEmployeesProvider)) e.id: e.name,
                },
                lockedIds: locked,
                lockedNote: 'You lead $leadNames: the project manager changes the rest of the team.',
                pickerTitle: runs ? 'Add team members' : 'Add $leadNames people',
                helper: runs
                    ? teamPoolNote(p.targetDepartment, p.departmentNames)
                    : 'You lead $leadNames on this project: add or take off its people. The manager changes the rest.',
                onChanged: (v) => setSheet(() => members
                  ..clear()
                  ..addAll(v)
                  ..addAll(locked)),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Cancel'))),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('people_save'),
                    onPressed: busy
                        ? null
                        : () async {
                            if (runs && managerId == null) {
                              messenger.showSnackBar(const SnackBar(content: Text('Pick a project manager')));
                              return;
                            }
                            setSheet(() => busy = true);
                            try {
                              final done = await saveTeamChecked(
                                ctx,
                                (extra) => ref.read(projectServiceProvider).saveTeam(p.id, {
                                  if (runs) 'managerId': managerId,
                                  'members': members.toList(),
                                  ...extra,
                                }),
                              );
                              if (done == null) {
                                setSheet(() => busy = false); // kept them on: nothing was saved
                                return;
                              }
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setSheet(() => busy = false);
                              messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                            }
                          },
                    child: Text(busy ? 'Saving…' : 'Save team'),
                  ),
                ),
              ]),
            ]),
          ),
        );
      }),
    ),
  );
  if (saved == true) {
    ref.refreshData.projects();
    messenger.showSnackBar(const SnackBar(content: Text('Team updated')));
    return true;
  }
  return false;
}
