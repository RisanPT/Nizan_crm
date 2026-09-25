import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/it/data/ticket.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/services/ticket_service.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/presentation/screens/helpdesk_screen.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';

class TicketDetailScreen extends HookConsumerWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(ticketProvider(ticketId));
    final isIT = ref.watch(effectiveAccessProvider).canSeeIt;
    final myId = ref.watch(authSessionProvider)?.userId ?? '';
    final comment = useTextEditingController();
    final sending = useState(false);

    Future<void> reload() async {
      ref.refreshData.tickets(); // this ticket + lists + stats
    }

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        backgroundColor: crm.surface,
        foregroundColor: crm.primary,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/helpdesk')),
        title: async.maybeWhen(
          data: (t) => Text(t.ticketNumber.isEmpty ? 'Ticket' : t.ticketNumber,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          orElse: () => const Text('Ticket'),
        ),
        actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: reload),
        data: (t) => SelectionArea(
          child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                _headerCard(context, crm, t),
                if (isIT) ...[
                  const SizedBox(height: 12),
                  _TriagePanel(ticket: t, onSaved: reload),
                ],
                const SizedBox(height: 16),
                Text('Activity', style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary)),
                const SizedBox(height: 8),
                if (t.activity.isEmpty)
                  Text('No activity yet.', style: TextStyle(color: crm.textSecondary, fontSize: 12.5))
                else
                  for (final a in t.activity) _activityTile(crm, a, myId),
              ],
            ),
          ),
          _composer(context, ref, crm, comment, sending),
        ])),
      ),
    );
  }

  Widget _headerCard(BuildContext context, CrmTheme crm, Ticket t) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ticketTypeIcon(t.type), size: 18, color: ticketPriorityColor(t.priority)),
            const SizedBox(width: 8),
            Expanded(child: Text(t.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            const SizedBox(width: 4),
            // One-tap copy of the whole ticket (number, title, description).
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                final buf = StringBuffer();
                if (t.ticketNumber.isNotEmpty) buf.writeln(t.ticketNumber);
                buf.write(t.title);
                if (t.description.isNotEmpty) buf.write('\n\n${t.description}');
                Clipboard.setData(ClipboardData(text: buf.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ticket copied'),
                      duration: Duration(seconds: 1)),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.copy_rounded, size: 18, color: crm.textSecondary),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip(ticketStatusLabel(t.status), ticketStatusColor(t.status)),
            _chip(ticketTypeLabel(t.type), crm.textSecondary),
            _chip('${_cap(t.priority)} priority', ticketPriorityColor(t.priority)),
            if (t.module.isNotEmpty) _chip(t.module, crm.textSecondary),
          ]),
          if (t.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(t.description, style: TextStyle(fontSize: 13.5, color: crm.textPrimary, height: 1.4)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.person_outline, size: 14, color: crm.textSecondary),
            const SizedBox(width: 4),
            Text('Raised by ${t.raisedByName.isEmpty ? 'someone' : t.raisedByName}',
                style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            const Spacer(),
            Text(ticketAgo(t.createdAt), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          ]),
          if (t.assignedToName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.engineering_outlined, size: 14, color: crm.textSecondary),
              const SizedBox(width: 4),
              Text('Assigned to ${t.assignedToName}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ]),
          ],
          if (t.resolution.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2E8B57).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2E8B57).withValues(alpha: 0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Resolution', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF2E8B57))),
                const SizedBox(height: 3),
                Text(t.resolution, style: TextStyle(fontSize: 13, color: crm.textPrimary)),
              ]),
            ),
          ],
          if (t.screenshots.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: t.screenshots.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _viewImage(context, t.screenshots[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(t.screenshots[i], width: 84, height: 84, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                            width: 84, height: 84, color: crm.border, child: const Icon(Icons.broken_image_outlined))),
                  ),
                ),
              ),
            ),
          ],
        ]),
      );

  Widget _activityTile(CrmTheme crm, TicketActivity a, String myId) {
    final isComment = a.kind == 'comment';
    if (!isComment) {
      // System line (created / status / assign).
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(a.kind == 'created' ? Icons.flag_outlined : Icons.sync_alt, size: 14, color: crm.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${a.byName.isEmpty ? 'System' : a.byName} · ${a.text}',
                style: TextStyle(fontSize: 12, color: crm.textSecondary, fontStyle: FontStyle.italic)),
          ),
          Text(ticketAgo(a.at), style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        ]),
      );
    }
    final mine = a.byId == myId && myId.isNotEmpty;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: mine ? crm.primary.withValues(alpha: 0.12) : crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.byName.isEmpty ? 'User' : a.byName,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: mine ? crm.primary : crm.textSecondary)),
          const SizedBox(height: 3),
          Text(a.text, style: const TextStyle(fontSize: 13.5, height: 1.35)),
          const SizedBox(height: 3),
          Align(alignment: Alignment.bottomRight, child: Text(ticketAgo(a.at), style: TextStyle(fontSize: 10, color: crm.textSecondary))),
        ]),
      ),
    );
  }

  Widget _composer(BuildContext context, WidgetRef ref, CrmTheme crm, TextEditingController comment, ValueNotifier<bool> sending) => Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: comment,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                isDense: true,
                filled: true,
                fillColor: crm.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: crm.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: crm.primary),
            onPressed: sending.value
                ? null
                : () async {
                    final text = comment.text.trim();
                    if (text.isEmpty) return;
                    sending.value = true;
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(ticketServiceProvider).addComment(ticketId, text);
                      comment.clear();
                      ref.refreshData.tickets();
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                    } finally {
                      sending.value = false;
                    }
                  },
            icon: sending.value
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, color: Colors.white),
          ),
        ]),
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  void _viewImage(BuildContext context, String url) => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(padding: EdgeInsets.all(40), child: Icon(Icons.broken_image, color: Colors.white))),
          ),
        ),
      );
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// IT-only triage controls: status, priority, assignee, resolution.
class _TriagePanel extends HookConsumerWidget {
  final Ticket ticket;
  final Future<void> Function() onSaved;
  const _TriagePanel({required this.ticket, required this.onSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final status = useState(ticket.status);
    final priority = useState(ticket.priority);
    final assigneeId = useState<String?>(ticket.assignedToId.isEmpty ? null : ticket.assignedToId);
    final resolution = useTextEditingController(text: ticket.resolution);
    final busy = useState(false);

    final employees = ref.watch(itEmployeesProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.primary.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tune, size: 16, color: crm.primary),
          const SizedBox(width: 6),
          Text('IT Triage', style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: status.value,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status', isDense: true),
              items: [for (final s in ticketStatuses) DropdownMenuItem(value: s, child: Text(ticketStatusLabel(s)))],
              onChanged: (v) => status.value = v ?? status.value,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: priority.value,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Priority', isDense: true),
              items: [for (final p in ticketPriorities) DropdownMenuItem(value: p, child: Text(_cap(p)))],
              onChanged: (v) => priority.value = v ?? priority.value,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        EmployeePickerField(
          employees: employees,
          selectedId: assigneeId.value,
          selectedName: ticket.assignedToName,
          label: 'Assign to',
          icon: Icons.engineering_outlined,
          onChanged: (e) => assigneeId.value = e?.id,
        ),
        if (status.value == 'resolved' || status.value == 'closed') ...[
          const SizedBox(height: 10),
          TextField(
            controller: resolution,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Resolution note', alignLabelWithHint: true, isDense: true),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy.value
                ? null
                : () async {
                    busy.value = true;
                    final messenger = ScaffoldMessenger.of(context);
                    final name = assigneeId.value == null
                        ? ''
                        : employees.firstWhere((e) => e.id == assigneeId.value, orElse: () => employees.first).name;
                    try {
                      await ref.read(ticketServiceProvider).updateTicket(ticket.id, {
                        'status': status.value,
                        'priority': priority.value,
                        'assignedTo': assigneeId.value,
                        'assignedToName': name,
                        'resolution': resolution.text.trim(),
                      });
                      await onSaved();
                      messenger.showSnackBar(const SnackBar(content: Text('Ticket updated')));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                    } finally {
                      busy.value = false;
                    }
                  },
            icon: busy.value
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(busy.value ? 'Saving…' : 'Save triage'),
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: crm.border),
        const SizedBox(height: 4),
        if (ticket.linkedTaskId.isNotEmpty)
          Row(children: [
            Icon(Icons.link, size: 16, color: crm.textSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text('Converted to an IT task', style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
            TextButton(onPressed: () => context.go('/it/projects'), child: const Text('IT Projects')),
          ])
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _convertToTask(context, ref, employees),
              icon: const Icon(Icons.playlist_add_check, size: 18),
              label: const Text('Convert to IT task'),
            ),
          ),
      ]),
    );
  }

  Future<void> _convertToTask(BuildContext context, WidgetRef ref, List<Employee> employees) async {
    final messenger = ScaffoldMessenger.of(context);
    final List<Project> projects;
    try {
      projects = await ref.read(projectsProvider.future);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      return;
    }
    if (projects.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Create an IT project first, then convert the ticket into a task.')));
      return;
    }
    if (!context.mounted) return;

    String? projectId = projects.first.id;
    String? assigneeId = ticket.assignedToId.isEmpty ? null : ticket.assignedToId;

    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('Convert to IT task'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: projectId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Project *'),
                items: [for (final p in projects) DropdownMenuItem(value: p.id, child: Text(p.name))],
                onChanged: (v) => setD(() => projectId = v),
              ),
              const SizedBox(height: 10),
              EmployeePickerField(
                employees: employees,
                selectedId: assigneeId,
                selectedName: ticket.assignedToName,
                label: 'Assign to *',
                icon: Icons.engineering_outlined,
                allowUnassign: false,
                onChanged: (e) => setD(() => assigneeId = e?.id),
              ),
            ]),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (projectId == null) {
                          messenger.showSnackBar(const SnackBar(content: Text('Pick a project')));
                          return;
                        }
                        if (assigneeId == null) {
                          messenger.showSnackBar(const SnackBar(content: Text('Pick an assignee')));
                          return;
                        }
                        setD(() => busy = true);
                        final name = employees.firstWhere((e) => e.id == assigneeId, orElse: () => employees.first).name;
                        try {
                          await ref.read(ticketServiceProvider).promoteToTask(ticket.id, {
                            'projectId': projectId,
                            'assignedTo': assigneeId,
                            'assignedToName': name,
                          });
                          refreshAllItTaskViews(ref); // new task + project progress
                          ref.refreshData.tickets();
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          setD(() => busy = false);
                          messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                        }
                      },
                child: Text(busy ? 'Converting…' : 'Convert'),
              ),
            ],
          ),
        );
      },
    );

    if (done == true) {
      await onSaved();
      messenger.showSnackBar(const SnackBar(content: Text('Ticket converted to an IT task')));
    }
  }
}
