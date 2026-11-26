import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/whatsapp_service.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/features/crm/presentation/screens/crm_cases_screen.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_widgets.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';

/// One CRM case (/crm/cases/:id): who it is for, who owns it, when it is due, everything done on it — and the actions: call or WhatsApp
/// the client (and log it), add a note, start / resolve / close it (a note is needed), and for the head, reassign or reopen it.
class CrmCaseScreen extends ConsumerWidget {
  const CrmCaseScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(crmCaseProvider(caseId));
    final me = ref.watch(crmMeProvider).value;
    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back to the cases', onPressed: () => context.canPop() ? context.pop() : context.go('/crm/cases')),
        title: Text(async.value?.caseNumber ?? 'Case'),
        actions: [IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(crmCaseProvider(caseId)), icon: const Icon(Icons.refresh))],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(crmCaseProvider(caseId))),
        data: (c) => _CaseBody(c: c, me: me),
      ),
    );
  }
}

class _CaseBody extends ConsumerWidget {
  const _CaseBody({required this.c, required this.me});
  final CrmCase c;
  final CrmMe? me;

  bool get _head => me?.canAssign ?? false;
  bool get _mine => me != null && c.ownerId == me!.userId;
  bool get _canWork => (me?.canWrite ?? false) && (_head || _mine);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final color = crmCaseStatusColor(crm, c);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final details = _detailsCard(context, ref, crm, color);
        final timeline = _timelineCard(crm);
        return ListView(
          padding: EdgeInsets.all(wide ? 24 : 16),
          children: [
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: details), const SizedBox(width: 16), Expanded(flex: 4, child: timeline)])
            else ...[
              details,
              const SizedBox(height: 14),
              timeline,
            ],
          ],
        );
      },
    );
  }

  Widget _detailsCard(BuildContext context, WidgetRef ref, CrmTheme crm, Color color) {
    final rows = <(String, String)>[
      ('Kind', c.kindLabel),
      ('Priority', '${c.priority[0].toUpperCase()}${c.priority.substring(1)}'),
      ('Opened', crmWhen(c.createdAt)),
      ('Due', c.isOpen ? '${crmWhen(c.dueAt)}  (${crmDueText(c.dueAt)})' : crmWhen(c.dueAt)),
      if (c.resolvedAt != null) ('Resolved', '${crmWhen(c.resolvedAt)}${c.resolvedByName.isEmpty ? '' : ' by ${c.resolvedByName}'}'),
      if (c.closedAt != null) ('Closed', crmWhen(c.closedAt)),
      if (c.outcome.isNotEmpty) ('Outcome', crmOutcomeLabel(c.outcome)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(c.displayName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary))),
              Container(
                key: const Key('crmCaseStatus'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(c.overdue ? 'Overdue · ${c.statusLabel}' : c.statusLabel, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
          if (c.title.isNotEmpty && c.title != c.displayName) Text(c.title, style: TextStyle(color: crm.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              CrmOwnerChip(name: c.ownerName, assigned: c.ownerId != null),
              if (_head && c.isOpen) ...[
                const SizedBox(width: 6),
                TextButton(
                  key: const Key('crmCaseReassign'),
                  onPressed: () async {
                    final owner = await showCrmAssignDialog(context, count: 1, title: 'Give the case to');
                    if (owner == null || !context.mounted) return;
                    await crmAssign(context, ref, [CrmQueueItem(type: 'case', id: c.id, ownerId: c.ownerId)], owner);
                  },
                  child: Text(c.ownerId == null ? 'Assign' : 'Reassign'),
                ),
              ] else if (c.ownerId == null && c.isOpen && (me?.canWrite ?? false)) ...[
                const SizedBox(width: 6),
                TextButton(
                  key: const Key('crmCaseTake'),
                  onPressed: () => crmAssign(context, ref, [CrmQueueItem(type: 'case', id: c.id)], me!.userId),
                  child: const Text('Take it'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 90, child: Text(k, style: TextStyle(fontSize: 13, color: crm.textSecondary))),
                Expanded(child: Text(v, style: TextStyle(fontSize: 13.5, color: crm.textPrimary))),
              ]),
            ),
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(c.description, style: TextStyle(fontSize: 13.5, color: crm.textPrimary)),
          ],
          if (c.resolutionNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: crm.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Text('What was done: ${c.resolutionNote}', style: TextStyle(fontSize: 13, color: crm.textPrimary)),
            ),
          ],
          const SizedBox(height: 14),
          if (c.phone.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                key: const Key('crmCaseCall'),
                icon: const Icon(Icons.call_outlined, size: 18),
                label: Text('Call ${c.phone}'),
                onPressed: () async {
                  await launchUrl(Uri.parse('tel:${c.phone}'));
                  if (context.mounted && _canWork) await _logDialog(context, ref, 'call');
                },
              ),
              OutlinedButton.icon(
                key: const Key('crmCaseWhatsApp'),
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('WhatsApp'),
                onPressed: () async {
                  await WhatsAppService.openChat(c.phone, 'Hello ${c.customerName.isEmpty ? '' : c.customerName}, this is Team N.');
                  if (context.mounted && _canWork) await _logDialog(context, ref, 'whatsapp');
                },
              ),
            ]),
          if (c.bookingId != null)
            TextButton.icon(onPressed: () => context.go('/booking/manage/${c.bookingId}'), icon: const Icon(Icons.receipt_long_outlined, size: 18), label: const Text('Open the booking')),
          if (_canWork) ...[
            const Divider(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(key: const Key('crmCaseNote'), onPressed: () => _logDialog(context, ref, 'note'), icon: const Icon(Icons.edit_note, size: 18), label: const Text('Add a note')),
                if (c.status == 'open')
                  OutlinedButton(key: const Key('crmCaseStart'), onPressed: () => _update(context, ref, {'status': 'in_progress'}), child: const Text('Start working on it')),
                if (c.isOpen) ...[
                  FilledButton.icon(key: const Key('crmCaseResolve'), onPressed: () => _finishDialog(context, ref, 'resolved'), icon: const Icon(Icons.check, size: 18), label: const Text('Resolve')),
                  TextButton(key: const Key('crmCaseClose'), onPressed: () => _finishDialog(context, ref, 'closed'), child: const Text('Close without resolving')),
                ],
                if (!c.isOpen && _head)
                  OutlinedButton.icon(key: const Key('crmCaseReopen'), onPressed: () => _update(context, ref, {'status': 'open', 'reason': 'Reopened'}), icon: const Icon(Icons.replay, size: 18), label: const Text('Reopen')),
              ],
            ),
          ] else if (me != null && !(me!.canWrite))
            Padding(padding: const EdgeInsets.only(top: 12), child: Text('View only.', style: TextStyle(color: crm.textSecondary))),
        ],
      ),
    );
  }

  Widget _timelineCard(CrmTheme crm) {
    final acts = c.activities.reversed.toList();
    IconData icon(String t) => switch (t) {
      'call' => Icons.call_outlined,
      'whatsapp' => Icons.chat_outlined,
      'status' => Icons.flag_outlined,
      'assign' => Icons.person_outline,
      _ => Icons.notes,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What happened', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(height: 10),
          if (acts.isEmpty) Text('Nothing yet.', style: TextStyle(color: crm.textSecondary)),
          for (final a in acts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon(a.type), size: 18, color: crm.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [if (a.type == 'call') 'Call', if (a.type == 'whatsapp') 'WhatsApp', if (a.outcome.isNotEmpty) crmOutcomeLabel(a.outcome), if (a.text.isNotEmpty) a.text].join(' — '),
                          style: TextStyle(fontSize: 13.5, color: crm.textPrimary),
                        ),
                        Text('${a.byName.isEmpty ? 'System' : a.byName} · ${crmWhen(a.at)}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _update(BuildContext context, WidgetRef ref, Map<String, dynamic> body) async {
    try {
      await ref.read(crmServiceProvider).updateCase(c.id, body);
      refreshCrm(ref);
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  /// Logs a call / WhatsApp (with how it went) or a note.
  Future<void> _logDialog(BuildContext context, WidgetRef ref, String type) async {
    final r = await showDialog<({String text, String outcome})>(context: context, builder: (_) => _LogDialog(type: type));
    if (r == null || !context.mounted) return;
    try {
      await ref.read(crmServiceProvider).logActivity(c.id, type: type, text: r.text, outcome: r.outcome);
      refreshCrm(ref);
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  /// Resolve / close: what was done is required, the outcome optional.
  Future<void> _finishDialog(BuildContext context, WidgetRef ref, String status) async {
    final r = await showDialog<({String note, String outcome})>(context: context, builder: (_) => _FinishDialog(status: status, note: c.resolutionNote, outcome: c.outcome));
    if (r == null || !context.mounted) return;
    await _update(context, ref, {'status': status, 'resolutionNote': r.note, if (r.outcome.isNotEmpty) 'outcome': r.outcome});
  }
}

/// "How did the call go?" — an outcome (for a call / WhatsApp) and a note. Owns its text box, so it is freed only when the dialog is gone.
class _LogDialog extends StatefulWidget {
  const _LogDialog({required this.type});
  final String type;
  @override
  State<_LogDialog> createState() => _LogDialogState();
}

class _LogDialogState extends State<_LogDialog> {
  final _text = TextEditingController();
  String _outcome = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    return AlertDialog(
      title: Text(switch (type) { 'call' => 'How did the call go?', 'whatsapp' => 'WhatsApp sent — anything to note?', _ => 'Add a note' }),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type != 'note')
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (k, l) in const [('reached', 'Reached'), ('no_answer', 'No answer'), ('call_back', 'Call back later'), ('interested', 'Interested'), ('not_interested', 'Not interested')])
                  ChoiceChip(label: Text(l), selected: _outcome == k, onSelected: (_) => setState(() => _outcome = _outcome == k ? '' : k)),
              ]),
            TextField(key: const Key('crmLogText'), controller: _text, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Note')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(type == 'note' ? 'Cancel' : 'Don\'t log it')),
        FilledButton(key: const Key('crmLogSave'), onPressed: () => Navigator.pop(context, (text: _text.text.trim(), outcome: _outcome)), child: const Text('Save')),
      ],
    );
  }
}

/// Resolve or close a case: what was done (needed) and the outcome.
class _FinishDialog extends StatefulWidget {
  const _FinishDialog({required this.status, required this.note, required this.outcome});
  final String status;
  final String note;
  final String outcome;
  @override
  State<_FinishDialog> createState() => _FinishDialogState();
}

class _FinishDialogState extends State<_FinishDialog> {
  late final _note = TextEditingController(text: widget.note);
  late String _outcome = widget.outcome;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolving = widget.status == 'resolved';
    return AlertDialog(
      title: Text(resolving ? 'Resolve the case' : 'Close without resolving'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('crmResolveNote'),
              controller: _note,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(labelText: resolving ? 'What was done (needed)' : 'Why it is closed (needed)', errorText: _error),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _outcome.isEmpty ? null : _outcome,
              decoration: const InputDecoration(labelText: 'Outcome'),
              items: [for (final o in crmCaseOutcomes) DropdownMenuItem(value: o, child: Text(crmOutcomeLabel(o)))],
              onChanged: (v) => setState(() => _outcome = v ?? ''),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('crmResolveSave'),
          onPressed: () {
            if (_note.text.trim().length < 3) {
              setState(() => _error = 'Write what was done first.');
              return;
            }
            Navigator.pop(context, (note: _note.text.trim(), outcome: _outcome));
          },
          child: Text(resolving ? 'Resolve' : 'Close'),
        ),
      ],
    );
  }
}
