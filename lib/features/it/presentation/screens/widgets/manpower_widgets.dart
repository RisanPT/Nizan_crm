import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/error_message.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/rupees.dart';
import 'package:nizan_crm/features/it/data/manpower.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/services/manpower_service.dart';

// MANPOWER in the app: a project asks HR for more people (the dialog), and the project's page shows who is on its team and
// where its requests stand. HR's own screen is manpower_screen.dart; the rules are the server's (backend utils/manpower.js).

final _dayFormat = DateFormat('d MMM yyyy');

/// A stored day ("2026-12-01T00:00:00Z" reads as a UTC date) as the day it names, wherever the reader is: the date's own year,
/// month and day, never shifted into the reader's time zone.
String manpowerDay(DateTime? d) => d == null ? '' : _dayFormat.format(d);

/// "1 Dec 2026 → 28 Feb 2027".
String manpowerSpan(DateTime? from, DateTime? to) => from == null || to == null ? '' : '${manpowerDay(from)} → ${manpowerDay(to)}';

const _freeColor = Color(0xFF15803D);
const _tightColor = Color(0xFFB45309);
const _busyColor = Color(0xFFB91C1C);

Color manpowerLevelColor(String level) => switch (level) {
  'busy' => _busyColor,
  'tight' => _tightColor,
  _ => _freeColor,
};

/// Free / Tight / Busy next to a person HR may choose.
class ManpowerLevelChip extends StatelessWidget {
  const ManpowerLevelChip(this.level, {super.key});
  final String level;

  @override
  Widget build(BuildContext context) {
    final color = manpowerLevelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(switch (level) { 'busy' => 'Busy', 'tight' => 'Tight', _ => 'Free' }, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Where a request stands, as a small pill.
class ManpowerStatusPill extends StatelessWidget {
  const ManpowerStatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'fulfilled' => _freeColor,
      'in_progress' => const Color(0xFF1D4ED8),
      'declined' => _busyColor,
      'cancelled' => const Color(0xFF6B7280),
      _ => _tightColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(manpowerStatusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── asking ───────────────────────────────────────────────────────────────────

const _percentChoices = [10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 100];

/// "Ask HR for people": the role, how many, from when to when, how much of their time, and why. Returns the request as the
/// server filed it, or null when cancelled.
Future<ManpowerRequest?> showManpowerRequestDialog(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required String projectName,
  String department = '',
  DateTime? suggestedStart,
  DateTime? suggestedEnd,
}) {
  final role = TextEditingController();
  final skills = TextEditingController();
  final reason = TextEditingController();
  final cost = TextEditingController();
  var headcount = 1;
  var percent = 100;
  var urgent = false;
  DateTime? start = suggestedStart == null ? null : DateTime(suggestedStart.year, suggestedStart.month, suggestedStart.day);
  DateTime? end = suggestedEnd == null ? null : DateTime(suggestedEnd.year, suggestedEnd.month, suggestedEnd.day);
  String? error;
  var busy = false;

  return showDialog<ManpowerRequest>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        Future<void> pick(bool isStart) async {
          final now = DateTime.now();
          final initial = (isStart ? start : end) ?? start ?? now;
          final d = await showDatePicker(
            context: ctx,
            initialDate: initial,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 5),
          );
          if (d == null) return;
          setD(() {
            if (isStart) {
              start = d;
              if (end != null && end!.isBefore(d)) end = d;
            } else {
              end = d;
            }
            error = null;
          });
        }

        Widget dateButton(String key, String label, DateTime? value, bool isStart) => OutlinedButton.icon(
          key: Key(key),
          onPressed: busy ? null : () => pick(isStart),
          icon: const Icon(Icons.event_outlined, size: 16),
          label: Text(value == null ? label : _dayFormat.format(value), overflow: TextOverflow.ellipsis),
        );

        return AlertDialog(
          title: const Text('Ask HR for people'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    department.isEmpty ? projectName : '$projectName · $department',
                    style: TextStyle(fontSize: 12.5, color: Theme.of(ctx).hintColor),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('mp_role'),
                    controller: role,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Role needed *', hintText: 'UI designer, video editor…'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(child: Text('How many people', style: TextStyle(fontSize: 13.5))),
                      IconButton(
                        key: const Key('mp_less'),
                        onPressed: busy || headcount <= 1 ? null : () => setD(() => headcount -= 1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text('$headcount', key: const Key('mp_headcount'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        key: const Key('mp_more'),
                        onPressed: busy || headcount >= 20 ? null : () => setD(() => headcount += 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      dateButton('mp_start', 'Needed from *', start, true),
                      const Text('to'),
                      dateButton('mp_end', 'Needed until *', end, false),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: const Key('mp_percent'),
                    initialValue: percent,
                    decoration: const InputDecoration(labelText: 'How much of their time', helperText: '100% is full time on this project'),
                    items: [for (final p in _percentChoices) DropdownMenuItem(value: p, child: Text('$p%'))],
                    onChanged: busy ? null : (v) => setD(() => percent = v ?? percent),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('mp_skills'),
                    controller: skills,
                    decoration: const InputDecoration(labelText: 'Skills wanted (optional)', hintText: 'Figma, Premiere…'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('mp_reason'),
                    controller: reason,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Why more people are needed *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('mp_cost'),
                    controller: cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(
                      labelText: 'Estimated cost (optional)',
                      prefixText: '₹ ',
                      helperText: 'Only if this means a hire or a contractor — it has to fit the project\'s approved budget',
                      helperMaxLines: 2,
                    ),
                  ),
                  SwitchListTile(
                    key: const Key('mp_urgent'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Urgent', style: TextStyle(fontSize: 13.5)),
                    subtitle: const Text('HR sees it first', style: TextStyle(fontSize: 12)),
                    value: urgent,
                    onChanged: busy ? null : (v) => setD(() => urgent = v),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(error!, key: const Key('mp_error'), style: const TextStyle(fontSize: 12.5, color: _busyColor, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(key: const Key('mp_cancel'), onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              key: const Key('mp_submit'),
              onPressed: busy
                  ? null
                  : () async {
                      String? problem;
                      if (role.text.trim().length < 2) {
                        problem = 'Say what role is needed.';
                      } else if (start == null || end == null) {
                        problem = 'Give the dates the people are needed from and to.';
                      } else if (end!.isBefore(start!)) {
                        problem = 'The end date is before the start date.';
                      } else if (reason.text.trim().length < 3) {
                        problem = 'Say why more people are needed.';
                      } else if (cost.text.trim().isNotEmpty && parseAmount(cost.text) == null) {
                        problem = 'The estimated cost must be a number.';
                      }
                      if (problem != null) {
                        setD(() => error = problem);
                        return;
                      }
                      setD(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final saved = await ref
                            .read(manpowerServiceProvider)
                            .raise(
                              projectId,
                              roleTitle: role.text,
                              headcount: headcount,
                              startDate: start!,
                              endDate: end!,
                              allocationPercent: percent,
                              reason: reason.text,
                              skills: skills.text,
                              urgent: urgent,
                              estimatedCost: parseAmount(cost.text),
                            );
                        if (ctx.mounted) Navigator.pop(ctx, saved);
                      } catch (e) {
                        setD(() {
                          busy = false;
                          error = friendlyErrorMessage(e);
                        });
                      }
                    },
              child: Text(busy ? 'Sending…' : 'Send to HR'),
            ),
          ],
        );
      },
    ),
  );
}

/// What to tell the asker after a request went in: that it is with HR, and — when the estimate named a cost that does not
/// fit — that the project's cost has to be raised first.
String manpowerSentMessage(ManpowerRequest r) {
  final b = r.budget;
  final base = 'Sent to HR: ${r.what}';
  if (b == null || !b.short) return base;
  return '$base. The estimate is ${rupees(b.shortfall)} more than the project has left (${rupees(b.available)}) — raise the project\'s cost before HR can commit it.';
}

// ── the project's team ───────────────────────────────────────────────────────

/// "Team & manpower" on the project's Overview: who HR has put on the project (and for how much of their time), where the
/// project's requests for more people stand, and — for those who run it — the button to ask for more. Nothing is shown to
/// someone who has no part in it and nothing to show.
class ProjectTeamCard extends ConsumerWidget {
  const ProjectTeamCard({super.key, required this.project});
  final Project project;

  /// Who may ask HR for people: those who run the project and the lead of a department on it (the server checks too).
  static bool canRequest(Project p) => !{'proposed', 'cancelled'}.contains(p.status) && (p.access.canManage || p.access.leadDepartments.isNotEmpty);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final may = canRequest(project);
    final team = ref.watch(projectTeamProvider(project.id)).value ?? const <TeamMember>[];
    final requests = ref.watch(manpowerRequestsProvider(project.id)).value ?? const <ManpowerRequest>[];
    final open = requests.where((r) => r.isOpen).toList();
    final here = team.where((t) => t.state != 'ended').toList();
    final earlier = team.length - here.length;
    if (!may && here.isEmpty && open.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        key: const Key('project_team_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_2_outlined, size: 18, color: crm.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Team & manpower', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary))),
                if (requests.isNotEmpty)
                  TextButton(key: const Key('team_all_requests'), onPressed: () => context.go('/manpower'), child: const Text('All requests')),
              ],
            ),
            const SizedBox(height: 8),
            if (here.isEmpty)
              Text(
                'HR has not put anyone on this project yet.',
                key: const Key('team_empty'),
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
              )
            else
              for (final t in here)
                Padding(
                  key: Key('team_${t.id}'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.employeeName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                            Text(
                              [if (t.role.isNotEmpty) t.role, '${t.percent}% of their time', manpowerSpan(t.from, t.to)].where((s) => s.isNotEmpty).join(' · '),
                              style: TextStyle(fontSize: 12, color: crm.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (t.state == 'upcoming')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text('Starts soon', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.primary)),
                        ),
                    ],
                  ),
                ),
            if (earlier > 0)
              Text('$earlier earlier ${earlier == 1 ? 'member' : 'members'} not shown', key: const Key('team_earlier'), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            if (open.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Asked of HR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary)),
              const SizedBox(height: 4),
              for (final r in open)
                Padding(
                  key: Key('team_request_${r.id}'),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r.what}${r.isUrgent ? ' · urgent' : ''} · ${r.seatsLeft} ${r.seatsLeft == 1 ? 'seat' : 'seats'} open',
                          style: TextStyle(fontSize: 13, color: crm.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ManpowerStatusPill(r.status),
                    ],
                  ),
                ),
            ],
            if (may) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('team_request'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final sent = await showManpowerRequestDialog(
                      context,
                      ref,
                      projectId: project.id,
                      projectName: project.name,
                      department: project.targetDepartment,
                      suggestedStart: project.startDate,
                      suggestedEnd: project.endDate,
                    );
                    if (sent == null) return;
                    ref.invalidate(manpowerRequestsProvider(project.id));
                    messenger.showSnackBar(SnackBar(content: Text(manpowerSentMessage(sent))));
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  label: const Text('Ask HR for people'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
