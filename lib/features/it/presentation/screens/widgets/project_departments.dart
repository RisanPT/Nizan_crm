import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// Everything the app shows about a project that several departments work on: who is
// involved, how far each has got, the invitation a department head answers, and the
// proposal the owning head approves.

Color _deptColor(CrmTheme crm, ProjectDepartment d) {
  if (d.isDeclined) return crm.destructive;
  if (d.isInvited) return crm.warning;
  return d.isOwner ? crm.primary : Colors.blue.shade600;
}

/// The departments on a project as small chips: the owner filled, accepted ones
/// outlined, an unanswered invitation amber, a declined one struck through.
class ProjectDepartmentChips extends StatelessWidget {
  const ProjectDepartmentChips({super.key, required this.project, this.showDeclined = true});

  final Project project;
  final bool showDeclined;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final list = project.departments.isNotEmpty
        ? project.departments.where((d) => showDeclined || !d.isDeclined).toList()
        : [ProjectDepartment(name: project.targetDepartment, role: 'owner')];

    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final d in list)
        if (d.name.isNotEmpty) _chip(crm, d),
    ]);
  }

  Widget _chip(CrmTheme crm, ProjectDepartment d) {
    final color = _deptColor(crm, d);
    final filled = d.isOwner;
    final label = d.isInvited
        ? '${d.name} · invited'
        : d.isDeclined
            ? '${d.name} · declined'
            : d.name;
    return Tooltip(
      message: d.isOwner
          ? '${d.name} owns this project'
          : d.isInvited
              ? '${d.name} — invitation pending head acceptance'
              : d.isDeclined
                  ? '${d.name} — invitation declined'
                  : '${d.name} — active participant',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
        decoration: BoxDecoration(
          color: filled
              ? color
              : d.isInvited
                  ? Colors.amber.withValues(alpha: 0.12)
                  : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: filled
              ? null
              : Border.all(
                  color: d.isInvited ? Colors.amber.shade700 : color.withValues(alpha: 0.45),
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (d.isInvited) ...[
              Icon(Icons.schedule_rounded, size: 12, color: Colors.amber.shade800),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: filled
                    ? Colors.white
                    : d.isInvited
                        ? Colors.amber.shade900
                        : color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                decoration: d.isDeclined ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bar per department — how far its own tasks have got. Shown only when more than
/// one department works on the project (a single bar would repeat the total).
class DepartmentProgressStrip extends StatelessWidget {
  const DepartmentProgressStrip({super.key, required this.project, this.maxRows = 4});

  final Project project;

  /// Rows shown before "+ n more" (cards are short; the detail header passes a large number).
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final rows = project.departmentProgress;
    if (rows.length < 2) return const SizedBox.shrink();

    final shown = rows.take(maxRows).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final r in shown)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            SizedBox(
              width: 92,
              child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: r.tasks == 0 ? 0 : r.progress / 100,
                  minHeight: 6,
                  backgroundColor: crm.background,
                  valueColor: AlwaysStoppedAnimation(r.progress >= 100 ? crm.success : crm.primary),
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                r.tasks == 0 ? 'no tasks' : '${r.progress}% · ${r.done}/${r.tasks}',
                textAlign: TextAlign.right,
                maxLines: 1,
                style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      if (rows.length > shown.length)
        Text('+ ${rows.length - shown.length} more', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
    ]);
  }
}

/// What this project needs from the signed-in person right now, if anything:
/// an invitation to answer, a proposal to decide, or a note on a proposal that was
/// turned down. Renders nothing when there is nothing to do or say.
class ProjectDecisionBanner extends ConsumerWidget {
  const ProjectDecisionBanner({super.key, required this.project, this.compact = false, this.showSentInvitations = true});

  final Project project;
  final bool compact;

  /// The "Invitation sent to X, waiting for their head" line for each department that has not answered. The
  /// project's own screen turns it off: its Overview lists every department and where it stands, which this
  /// would repeat once per department above everything else.
  final bool showSentInvitations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final pending = project.access.pendingInvitations;

    final tiles = <Widget>[
      if (project.isProposed && project.access.canDecide)
        _tile(
          crm,
          icon: Icons.how_to_vote_outlined,
          color: crm.warning,
          text: '${project.managerName.isEmpty ? 'Someone' : project.managerName} proposed this project for ${project.targetDepartment}. It starts once you approve it.',
          actions: [
            OutlinedButton(onPressed: () => decideProposal(context, ref, project, approve: false), child: const Text('Reject')),
            FilledButton(onPressed: () => decideProposal(context, ref, project, approve: true), child: const Text('Approve')),
          ],
        )
      else if (project.isProposed)
        _tile(
          crm,
          icon: Icons.hourglass_top_rounded,
          color: crm.warning,
          text: 'Waiting for the head of ${project.targetDepartment} to approve this project.',
        ),
      if (project.isRejected)
        _tile(crm, icon: Icons.block_outlined, color: crm.destructive, text: 'Not approved: ${project.decisionNote}'),
      for (final dept in pending)
        _tile(
          crm,
          icon: Icons.mail_outline,
          color: Colors.blue.shade600,
          text: '${project.targetDepartment} invited $dept to join "${project.name}". Your people can work on it once you accept.',
          actions: [
            OutlinedButton(onPressed: () => answerInvitation(context, ref, project, dept, accept: false), child: const Text('Decline')),
            FilledButton(onPressed: () => answerInvitation(context, ref, project, dept, accept: true), child: const Text('Accept')),
          ],
        ),
      for (final inv in showSentInvitations ? project.invitedDepartments : const <ProjectDepartment>[])
        if (!pending.any((p) => p.toLowerCase() == inv.name.toLowerCase()))
          _tile(
            crm,
            icon: Icons.hourglass_top_rounded,
            color: Colors.blue.shade700,
            text: 'Invitation sent to ${inv.name}. Waiting for their department head to accept before ${inv.name} can take part in tasks.',
          ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(children: [
      for (final t in tiles) Padding(padding: EdgeInsets.only(bottom: compact ? 8 : 10), child: t),
    ]);
  }

  Widget _tile(CrmTheme crm, {required IconData icon, required Color color, required String text, List<Widget> actions = const []}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.35, color: crm.textPrimary))),
        ]),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.end, children: actions),
          ),
      ]),
    );
  }
}

/// A department head accepts or declines the invitation. Declining asks first — it
/// takes the department off the project.
Future<void> answerInvitation(BuildContext context, WidgetRef ref, Project project, String department, {required bool accept}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!accept) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Decline "${project.name}"?'),
        content: Text('$department will not take part in this project. ${project.targetDepartment} will be told.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Decline')),
        ],
      ),
    );
    if (ok != true) return;
  }
  try {
    await ref.read(projectServiceProvider).respondToInvitation(project.id, department, accept: accept);
    ref.invalidate(projectsProvider);
    ref.invalidate(projectByIdProvider(project.id));
    ref.refreshData.projects();
    messenger.showSnackBar(SnackBar(content: Text(accept ? '$department joined "${project.name}"' : 'Declined "${project.name}"')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
  }
}

/// The owning head (or an admin) approves or rejects a proposal. A rejection takes a
/// reason, which the proposer is shown.
Future<void> decideProposal(BuildContext context, WidgetRef ref, Project project, {required bool approve}) async {
  final messenger = ScaffoldMessenger.of(context);
  var note = '';
  if (!approve) {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Reject "${project.name}"?'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Why not? (shown to the proposer)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null) return; // cancelled
    note = reason;
  }
  try {
    await ref.read(projectServiceProvider).decideProposal(project.id, approve: approve, note: note);
    ref.refreshData.projects();
    messenger.showSnackBar(SnackBar(content: Text(approve ? '"${project.name}" approved' : '"${project.name}" rejected')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
  }
}
