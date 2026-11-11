import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_projects_screen.dart' show priorityColor;
import 'package:nizan_crm/features/it/presentation/screens/widgets/manpower_widgets.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_cost_widgets.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_departments.dart' show answerInvitation;
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_tabs.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// The first tab of a project: where it stands (progress, phases, tasks, departments, due date), which
// departments have yet to answer their invitation, the project's details and activity, and its phases
// at a glance. Everything is read from the project and its tasks; "Resend" is the only thing it does.

const double _wideAt = 980;
const double _midAt = 640;
const int _activityShown = 4;

/// The work-breakdown table shows every column from this width (its fixed columns take about 670px).
const double _fullTableAt = 880;

String _date(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy').format(d);
String _dateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);

class ProjectOverview extends ConsumerStatefulWidget {
  const ProjectOverview({
    super.key,
    required this.projectId,
    required this.project,
    required this.tasks,
    required this.onOpenTab,
  });

  final String projectId;

  /// null while the project list is still loading: the parts that need it wait, the rest is worked out from the tasks.
  final Project? project;
  final List<ITTask> tasks;

  /// Switch the screen to another tab (the WBS link goes to [ProjectTab.wbs]).
  final ValueChanged<int> onOpenTab;

  @override
  ConsumerState<ProjectOverview> createState() => _ProjectOverviewState();
}

class _ProjectOverviewState extends ConsumerState<ProjectOverview> {
  final Set<String> _resending = {};
  final Set<String> _open = {};

  Project? get _p => widget.project;
  bool get _canAddTasks => _p?.access.canCreateTasks ?? true;

  void _refreshIf(bool? saved) {
    if (saved == true) {
      getITTasksNotifier(ref, widget.projectId).refresh();
      ref.invalidate(projectsProvider);
    }
  }

  Future<void> _resend(String department) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _resending.add(department));
    try {
      await ref.read(projectServiceProvider).resendInvitation(widget.projectId, department);
      ref.invalidate(projectsProvider); // the reminder is a new line of the activity, which reloads with the list
      messenger.showSnackBar(SnackBar(content: Text('Reminder sent to $department')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _resending.remove(department));
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final p = _p;
    final forest = buildWbsForest(widget.tasks);
    final participants = p?.departments.where((d) => !d.isOwner).toList() ?? const <ProjectDepartment>[];

    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final wide = w >= _wideAt;
      final mid = w >= _midAt;

      final hero = _hero(crm);
      final stats = _stats(crm, forest.length, inRow: mid, bounded: wide);
      final invitations = participants.isEmpty || p == null ? null : _invitations(crm, p, participants);
      final details = p == null ? null : _details(crm, p);
      final activity = p == null ? null : _activity(crm);

      return SingleChildScrollView(
        padding: EdgeInsets.all(w < _midAt ? 12 : 20),
        child: Column(children: [
          if (wide)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 11, child: hero),
                const SizedBox(width: 16),
                Expanded(flex: 14, child: stats),
              ]),
            )
          else ...[
            hero,
            const SizedBox(height: 12),
            stats,
          ],
          const SizedBox(height: 16),
          // what the project is expected to cost, and where the finance head's approval stands
          if (p != null && ProjectCostCard.shows(p)) ...[ProjectCostCard(project: p), const SizedBox(height: 16)],
          // who HR has put on the project, where its requests for more people stand, and the button to ask for more
          if (p != null && p.status != 'proposed') ProjectTeamCard(project: p),
          if (wide && invitations != null)
            // invitations on the left; details over activity on the right
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 6, child: invitations),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(children: [
                  ?details,
                  if (details != null && activity != null) const SizedBox(height: 16),
                  ?activity,
                ]),
              ),
            ])
          else if (wide)
            // nobody was invited: details and activity side by side
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (details != null) Expanded(child: details),
              if (details != null && activity != null) const SizedBox(width: 16),
              if (activity != null) Expanded(child: activity),
            ])
          else
            Column(children: [
              if (invitations != null) ...[invitations, const SizedBox(height: 16)],
              if (details != null) ...[details, const SizedBox(height: 16)],
              ?activity,
            ]),
          const SizedBox(height: 16),
          _wbs(crm, forest),
        ]),
      );
    });
  }

  // ── progress + the four numbers ───────────────────────────────────────────

  Widget _hero(CrmTheme crm) {
    final p = _p;
    final tasks = widget.tasks;
    final total = p?.totalTasks ?? tasks.length;
    final done = p?.completedTasks ?? tasks.where((t) => t.percentComplete >= 100).length;
    final pct = p?.progress ?? _leafAverage(tasks);
    final dark = Color.lerp(crm.primary, Colors.black, 0.22)!;
    final light = Color.lerp(crm.primary, Colors.white, 0.12)!;

    return Container(
      key: const Key('overview_hero'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [dark, light]),
      ),
      child: Stack(children: [
        const Positioned.fill(child: CustomPaint(painter: _WavePainter())),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Expanded(
                child: Text('Project Progress', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              if (p != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(20)),
                  child: Text(cap(p.status), style: TextStyle(color: crm.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 6),
            Text('$pct%', style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1)),
            const SizedBox(height: 4),
            Text('$done of $total tasks completed', style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 14)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.28),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  int _leafAverage(List<ITTask> tasks) {
    final leaves = tasks.where((t) => !tasks.any((o) => o.parentTaskId == t.id)).toList();
    if (leaves.isEmpty) return 0;
    return (leaves.map((t) => t.percentComplete.clamp(0, 100)).reduce((a, b) => a + b) / leaves.length).round();
  }

  /// [bounded]: the parent fixes the height (the wide layout's row), so the cards just fill it; otherwise the
  /// cards of a row are made as tall as the tallest, which a list cannot do by itself.
  Widget _stats(CrmTheme crm, int phases, {required bool inRow, required bool bounded}) {
    final p = _p;
    final departments = p == null ? 0 : p.departments.where((d) => !d.isDeclined).length;
    final due = p?.endDate;
    final overdue = due != null && due.isBefore(DateTime.now()) && p != null && p.status != 'completed' && p.status != 'cancelled';

    final cards = [
      _stat(crm, const Key('overview_stat_phases'), Icons.assignment_outlined, '$phases', 'Phases'),
      _stat(crm, const Key('overview_stat_tasks'), Icons.checklist_rounded, '${p?.totalTasks ?? widget.tasks.length}', 'Tasks'),
      _stat(crm, const Key('overview_stat_departments'), Icons.groups_outlined, '$departments', 'Departments'),
      _stat(
        crm,
        const Key('overview_stat_due'),
        Icons.event_outlined,
        _date(due),
        overdue ? 'Overdue' : 'Due Date',
        valueColor: overdue ? crm.destructive : null,
      ),
    ];
    Widget cardRow(List<Widget> items) {
      final row = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: items[i]),
        ],
      ]);
      return bounded ? row : IntrinsicHeight(child: row);
    }

    if (inRow) return cardRow(cards);
    return Column(children: [cardRow(cards.sublist(0, 2)), const SizedBox(height: 12), cardRow(cards.sublist(2))]);
  }

  Widget _stat(CrmTheme crm, Key key, IconData icon, String value, String label, {Color? valueColor}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(crm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _IconTile(icon: icon, size: 40),
        const SizedBox(height: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: valueColor ?? crm.textPrimary, height: 1.1)),
          ),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: valueColor ?? crm.textSecondary)),
        ]),
      ]),
    );
  }

  // ── department invitations ────────────────────────────────────────────────

  Widget _invitations(CrmTheme crm, Project p, List<ProjectDepartment> participants) {
    final pending = participants.where((d) => d.isInvited).length;
    final canResend = p.access.canManage;

    return _Card(
      key: const Key('overview_invitations'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
          icon: Icons.groups_2_outlined,
          title: 'Project Departments',
          subtitle: pending > 0
              ? 'Departments collaborating on this project.'
              : 'Every participating department is active on this project.',
          trailing: pending > 0
              ? _Pill(label: '$pending Pending', color: crm.primary, key: const Key('invitations_pending'))
              : _Pill(label: '${participants.length} Active', color: crm.success),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < participants.length; i++) ...[
          if (i > 0) Divider(height: 1, color: crm.border.faded(0.8)),
          _invitationRow(crm, p, participants[i], canResend: canResend),
        ],
      ]),
    );
  }

  Widget _invitationRow(CrmTheme crm, Project p, ProjectDepartment d, {required bool canResend}) {
    final (icon, color, text) = d.isInvited
        ? (Icons.schedule_rounded, crm.warning, 'Awaiting approval')
        : d.isDeclined
            ? (Icons.cancel_outlined, crm.destructive, 'Declined')
            : (Icons.check_circle_outline_rounded, crm.success, 'Joined');
    final sending = _resending.contains(d.name);
    final canAnswer = p.access.pendingInvitations.any((name) => name.toLowerCase() == d.name.toLowerCase()) || p.access.role == 'admin';

    return Padding(
      key: Key('invitation_${d.name}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(builder: (context, box) {
        final narrow = box.maxWidth < 440;
        final status = Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: crm.textSecondary))),
        ]);
        return Row(children: [
          _IconTile(icon: _deptIcon(d.name), size: 38),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              if (narrow) Padding(padding: const EdgeInsets.only(top: 3), child: status),
            ]),
          ),
          if (!narrow) Expanded(flex: 3, child: status),
          if (d.isInvited && canAnswer) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => answerInvitation(context, ref, p, d.name, accept: false),
              style: OutlinedButton.styleFrom(
                foregroundColor: crm.destructive,
                side: BorderSide(color: crm.destructive.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Decline', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: () => answerInvitation(context, ref, p, d.name, accept: true),
              icon: const Icon(Icons.check, size: 14),
              label: const Text('Join', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: crm.success,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else if (d.isInvited && canResend) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              key: Key('resend_${d.name}'),
              onPressed: sending ? null : () => _resend(d.name),
              style: OutlinedButton.styleFrom(
                foregroundColor: crm.textPrimary,
                side: BorderSide(color: crm.border.faded(2.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: sending
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Resend', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ]);
      }),
    );
  }

  static IconData _deptIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('account')) return Icons.groups_2_outlined;
    if (n.contains('financ')) return Icons.account_balance_outlined;
    if (n.contains('hr') || n.contains('human')) return Icons.groups_outlined;
    if (n == 'it' || n.contains('tech')) return Icons.computer_outlined;
    if (n.contains('market')) return Icons.campaign_outlined;
    if (n.contains('sale')) return Icons.person_outline_rounded;
    if (n.contains('crm')) return Icons.analytics_outlined;
    if (n.contains('fleet') || n.contains('transport')) return Icons.local_shipping_outlined;
    return Icons.apartment_outlined;
  }

  // ── project details ───────────────────────────────────────────────────────

  Widget _details(CrmTheme crm, Project p) {
    final a = p.access;
    final note = switch ((a.isManaged, a.canManage, a.leadDepartments.isNotEmpty)) {
      (true, true, _) => null,
      (true, false, true) => 'You lead ${a.leadDepartments.join(', ')}: you plan its tickets. Others on the project update their own.',
      (true, false, false) => 'The project manager plans the tickets. You can update how your own are going.',
      _ => null,
    };

    Widget row(IconData icon, String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Icon(icon, size: 17, color: crm.textSecondary),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
            const SizedBox(width: 12),
            Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
          ]),
        );
    Widget text(String v) => Text(v, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary));

    return _Card(
      key: const Key('overview_details'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _CardHeader(icon: Icons.info_outline_rounded, title: 'Project Details', compact: true),
        const SizedBox(height: 6),
        row(Icons.person_outline_rounded, 'Manager', text(p.managerName.isEmpty ? '—' : p.managerName)),
        if (p.targetDepartment.isNotEmpty) row(Icons.apartment_outlined, 'Department', text(p.targetDepartment)),
        row(Icons.calendar_today_outlined, 'Start Date', text(_date(p.startDate))),
        row(Icons.event_outlined, 'Due Date', text(_date(p.endDate))),
        row(Icons.flag_outlined, 'Phase', _Pill(label: cap(p.phase), color: crm.primary)),
        row(Icons.track_changes_outlined, 'Priority', _Pill(label: cap(p.priority), color: priorityColor(p.priority))),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lock_outline, size: 14, color: crm.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(note, style: TextStyle(fontSize: 11.5, color: crm.textSecondary, height: 1.3))),
            ]),
          ),
      ]),
    );
  }

  // ── activity ──────────────────────────────────────────────────────────────

  Widget _activity(CrmTheme crm) {
    final feed = ref.watch(projectActivityProvider(widget.projectId));
    final events = feed.value ?? const <ProjectActivity>[];
    final latest = events.length > _activityShown ? events.sublist(events.length - _activityShown) : events;

    return _Card(
      key: const Key('overview_activity'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
          icon: Icons.monitor_heart_outlined,
          title: 'Project Activity',
          compact: true,
          trailing: events.length > _activityShown
              ? TextButton(
                  key: const Key('activity_view_all'),
                  onPressed: () => showProjectActivity(context, events),
                  style: TextButton.styleFrom(foregroundColor: crm.primary, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
                  child: const Text('View all →', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                )
              : null,
        ),
        const SizedBox(height: 14),
        if (feed.isLoading && events.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
        else if (feed.hasError && events.isEmpty)
          Row(children: [
            Expanded(child: Text("Couldn't load the activity.", style: TextStyle(fontSize: 13, color: crm.textSecondary))),
            TextButton(onPressed: () => ref.invalidate(projectActivityProvider(widget.projectId)), child: const Text('Retry')),
          ])
        else if (events.isEmpty)
          Text('No activity yet.', style: TextStyle(fontSize: 13, color: crm.textSecondary))
        else
          _ActivityTimeline(events: latest),
      ]),
    );
  }

  // ── work breakdown ────────────────────────────────────────────────────────

  List<(WbsNode, int)> _visibleRows(List<WbsNode> forest) {
    final rows = <(WbsNode, int)>[];
    void add(WbsNode n, int phase) {
      rows.add((n, phase));
      if (_open.contains(n.task.id)) {
        for (final c in n.children) {
          add(c, phase);
        }
      }
    }

    for (var i = 0; i < forest.length; i++) {
      add(forest[i], i);
    }
    return rows;
  }

  Widget _wbs(CrmTheme crm, List<WbsNode> forest) {
    final rows = _visibleRows(forest);
    return _Card(
      key: const Key('overview_wbs'),
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: _CardHeader(
            icon: Icons.layers_outlined,
            title: 'Work Breakdown (WBS)',
            compact: true,
            trailing: _canAddTasks
                ? OutlinedButton.icon(
                    key: const Key('wbs_add_phase'),
                    onPressed: () => showTaskEditor(context, ref, widget.projectId, allTasks: widget.tasks).then(_refreshIf),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Add Phase', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: crm.textPrimary,
                      side: BorderSide(color: crm.border.faded(2.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : null,
          ),
        ),
        if (forest.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.account_tree_outlined, size: 40, color: crm.textSecondary),
                const SizedBox(height: 8),
                Text('No phases yet', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  _canAddTasks ? 'Add a phase, then break it into tasks.' : 'The project manager adds the work to this project.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                ),
              ]),
            ),
          )
        else ...[
          // all seven columns need room: with less, it is the number, the title and the progress
          LayoutBuilder(builder: (context, box) {
            final compact = box.maxWidth < _fullTableAt;
            return Column(children: [
              _wbsHeaderRow(crm, compact),
              for (final (node, phase) in rows) _wbsRow(crm, node, phase, compact),
            ]);
          }),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextButton(
                key: const Key('wbs_open_full'),
                onPressed: () => widget.onOpenTab(ProjectTab.wbs.index),
                style: TextButton.styleFrom(foregroundColor: crm.primary),
                child: const Text('Open the full work breakdown →', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  static const double _wNo = 56;
  static const double _wOwner = 130;
  static const double _wDate = 104;
  static const double _wDur = 84;
  static const double _wProgress = 190;

  Widget _wbsHeaderRow(CrmTheme crm, bool compact) {
    TextStyle h() => TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary);
    return Container(
      color: crm.background,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: compact
          ? Row(children: [
              SizedBox(width: _wNo - 8, child: Text('#', style: h())),
              Expanded(child: Text('Phase / Task', style: h())),
              SizedBox(width: 96, child: Text('Progress', style: h(), textAlign: TextAlign.right)),
            ])
          : Row(children: [
              SizedBox(width: _wNo, child: Text('#', style: h())),
              Expanded(child: Text('Phase / Task', style: h())),
              SizedBox(width: _wOwner, child: Text('Owner', style: h())),
              SizedBox(width: _wDate, child: Text('Start', style: h())),
              SizedBox(width: _wDate, child: Text('Due', style: h())),
              SizedBox(width: _wDur, child: Text('Dur (Days)', style: h())),
              SizedBox(width: _wProgress, child: Text('Progress', style: h())),
            ]),
    );
  }

  Widget _wbsRow(CrmTheme crm, WbsNode node, int phase, bool compact) {
    final t = node.task;
    final isPhase = node.depth == 0;
    final open = _open.contains(t.id);
    final pct = rolledUpPercent(node);
    final accent = crm.primary; // the design's maroon chip for every phase (the WBS tab keeps its own colours)
    final dur = durationDays(t);
    final owner = t.assignedToName.isEmpty ? '—' : t.assignedToName;

    final number = isPhase
        ? Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
            child: Text(node.wbs, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          )
        : Text(node.wbs, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textSecondary));

    final title = Row(children: [
      SizedBox(
        width: 22,
        child: node.isGroup
            ? Icon(open ? Icons.expand_more : Icons.chevron_right, size: 20, color: crm.textSecondary)
            : (isPhase ? null : Center(child: Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: t.status.color)))),
      ),
      Expanded(
        child: Text(
          t.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: isPhase ? FontWeight.w700 : FontWeight.w500, color: crm.textPrimary),
        ),
      ),
    ]);

    return InkWell(
      key: Key('wbs_row_${t.id}'),
      onTap: node.isGroup
          ? () => setState(() => open ? _open.remove(t.id) : _open.add(t.id))
          : () => showITTaskDetailSheet(context, ref, task: t, allTasks: widget.tasks).then(_refreshIf),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: EdgeInsets.fromLTRB(18, 8, 18, 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: crm.border.faded(0.8)))),
        child: compact
            ? Row(children: [
                SizedBox(width: _wNo - 8, child: Align(alignment: Alignment.centerLeft, child: number)),
                Expanded(child: Padding(padding: EdgeInsets.only(left: math.max(0, node.depth - 1) * 12.0), child: title)),
                SizedBox(width: 96, child: _ProgressBar(pct: pct, barWidth: 38)),
              ])
            : Row(children: [
                SizedBox(width: _wNo, child: Align(alignment: Alignment.centerLeft, child: number)),
                Expanded(child: Padding(padding: EdgeInsets.only(left: math.max(0, node.depth - 1) * 16.0), child: title)),
                SizedBox(width: _wOwner, child: Text(owner, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: crm.textSecondary))),
                SizedBox(width: _wDate, child: Text(_date(t.startDate), style: TextStyle(fontSize: 13, color: crm.textSecondary))),
                SizedBox(width: _wDate, child: Text(_date(t.deadline), style: TextStyle(fontSize: 13, color: crm.textSecondary))),
                SizedBox(width: _wDur, child: Text(dur?.toString() ?? '—', style: TextStyle(fontSize: 13, color: crm.textSecondary))),
                SizedBox(width: _wProgress, child: _ProgressBar(pct: pct)),
              ]),
      ),
    );
  }
}

/// The whole activity of a project, newest first.
Future<void> showProjectActivity(BuildContext context, List<ProjectActivity> events) {
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Project activity'),
      content: SizedBox(
        width: 440,
        child: events.isEmpty
            ? const Text('No activity yet.')
            : SingleChildScrollView(child: _ActivityTimeline(events: events.reversed.toList(), newestFirst: true)),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
    ),
  );
}

BoxDecoration _cardDecoration(CrmTheme crm) => BoxDecoration(
      color: crm.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: crm.border),
    );

class _Card extends StatelessWidget {
  const _Card({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) =>
      Container(width: double.infinity, padding: padding, decoration: _cardDecoration(context.crmColors), child: child);
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.size});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, size: size * 0.5, color: crm.primary),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title, this.subtitle, this.trailing, this.compact = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Details / activity / WBS: a smaller tile, no subtitle.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      _IconTile(icon: icon, size: compact ? 36 : 44),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 16 : 17, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            ),
        ]),
      ),
      if (trailing != null) ...[const SizedBox(width: 10), trailing!],
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
      );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.pct, this.barWidth});
  final int pct;

  /// The width of the "%" text (the bar takes the rest).
  final double? barWidth;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 6,
            backgroundColor: crm.border.faded(1.6),
            valueColor: AlwaysStoppedAnimation(pct >= 100 ? crm.success : crm.primary),
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(width: barWidth ?? 40, child: Text('$pct%', textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textSecondary))),
    ]);
  }
}

/// A vertical list of what happened, each with who did it and when; the newest has the filled dot.
class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.events, this.newestFirst = false});
  final List<ProjectActivity> events;
  final bool newestFirst;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Column(children: [
      for (var i = 0; i < events.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 22,
              child: Column(children: [
                const SizedBox(height: 3),
                _dot(crm, filled: newestFirst ? i == 0 : i == events.length - 1),
                if (i < events.length - 1) Expanded(child: Container(width: 1.5, color: crm.border.faded(1.6))),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i < events.length - 1 ? 16 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(events[i].text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    events[i].by.isEmpty ? _dateTime(events[i].at) : 'by ${events[i].by} · ${_dateTime(events[i].at)}',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }

  Widget _dot(CrmTheme crm, {required bool filled}) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? crm.primary : crm.surface,
          border: Border.all(color: filled ? crm.primary : crm.border.faded(2.5), width: 1.8),
        ),
      );
}

/// Two soft waves across the lower right of the progress card.
class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final back = Path()
      ..moveTo(w * 0.30, h)
      ..cubicTo(w * 0.48, h * 0.50, w * 0.70, h * 0.98, w, h * 0.38)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(back, Paint()..color = Colors.white.withValues(alpha: 0.07));
    final front = Path()
      ..moveTo(w * 0.55, h)
      ..cubicTo(w * 0.70, h * 0.62, w * 0.86, h * 1.0, w, h * 0.66)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(front, Paint()..color = Colors.white.withValues(alpha: 0.07));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
