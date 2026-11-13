import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/ceo/data/decision_models.dart';
import 'package:nizan_crm/features/ceo/services/ceo_service.dart';
import 'package:nizan_crm/features/ceo/services/decision_service.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart' show inr, kDashBad, kDashGood;

/// What a leader typed when approving / rejecting / deferring.
typedef DecisionInput = ({String note, DateTime? until});

/// Re-read everything that shows the desk (the home, the Decisions tabs, the badge).
void refreshDesk(WidgetRef ref) {
  ref.invalidate(ceoInboxProvider);
  ref.invalidate(decisionQueueProvider);
}

const _quickReasons = ['Not in the budget', 'Not the right time', 'Need more detail', 'Too expensive for what it is'];

/// Ask for the note (a bottom sheet on a phone, a dialog on a laptop). → the note and date, or null if the leader backed out.
Future<DecisionInput?> askDecisionNote(BuildContext context, DecisionRequest request, DecisionAction action) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  final form = DecisionNoteForm(request: request, action: action);
  if (wide) {
    return showDialog<DecisionInput>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: form)));
  }
  return showModalBottomSheet<DecisionInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: form),
  );
}

/// Ask, then record the decision. Handles "somebody else decided first": the message names who, when and why, and the desk is
/// re-read so the card turns into a decided one. → true when the leader's own decision was recorded.
Future<bool> runDecision(BuildContext context, WidgetRef ref, DecisionRequest request, DecisionAction action) async {
  final input = await askDecisionNote(context, request, action);
  if (input == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(decisionServiceProvider).decide(request.id, action, note: input.note, until: input.until);
    refreshDesk(ref);
    final done = switch (action) {
      DecisionAction.approve => 'Approved: ${request.title}',
      DecisionAction.reject => 'Rejected: ${request.title}',
      DecisionAction.defer => 'Put off: ${request.title}',
    };
    messenger.showSnackBar(SnackBar(key: const Key('ceo_decision_done'), content: Text(done)));
    return true;
  } on DecisionConflict catch (c) {
    refreshDesk(ref);
    messenger.showSnackBar(SnackBar(key: const Key('ceo_decision_conflict'), duration: const Duration(seconds: 6), content: Text(c.message)));
    return false;
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return false;
  }
}

class DecisionNoteForm extends StatefulWidget {
  const DecisionNoteForm({super.key, required this.request, required this.action});

  final DecisionRequest request;
  final DecisionAction action;

  @override
  State<DecisionNoteForm> createState() => _DecisionNoteFormState();
}

class _DecisionNoteFormState extends State<DecisionNoteForm> {
  final _note = TextEditingController();
  DateTime? _until;
  String _deferChoice = 'tomorrow';

  @override
  void initState() {
    super.initState();
    if (widget.action == DecisionAction.defer) _until = _atNine(DateTime.now().add(const Duration(days: 1)));
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime _atNine(DateTime d) => DateTime(d.year, d.month, d.day, 9);

  bool get _isReject => widget.action == DecisionAction.reject;
  bool get _canSubmit => !_isReject || _note.text.trim().length >= 3;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 2)), firstDate: now.add(const Duration(days: 1)), lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    setState(() {
      _deferChoice = 'pick';
      _until = _atNine(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = widget.request;
    final (verb, color) = switch (widget.action) {
      DecisionAction.approve => ('Approve', kDashGood),
      DecisionAction.reject => ('Reject', kDashBad),
      DecisionAction.defer => ('Decide later', crm.primary),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$verb: ${r.title}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        if (r.amount != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(inr(r.amount!), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textSecondary))),
        const SizedBox(height: 14),
        if (widget.action == DecisionAction.defer) ...[
          Wrap(spacing: 8, runSpacing: 4, children: [
            ChoiceChip(
              key: const Key('ceo_defer_tomorrow'),
              label: const Text('Tomorrow'),
              selected: _deferChoice == 'tomorrow',
              onSelected: (_) => setState(() {
                _deferChoice = 'tomorrow';
                _until = _atNine(DateTime.now().add(const Duration(days: 1)));
              }),
            ),
            ChoiceChip(
              key: const Key('ceo_defer_week'),
              label: const Text('In a week'),
              selected: _deferChoice == 'week',
              onSelected: (_) => setState(() {
                _deferChoice = 'week';
                _until = _atNine(DateTime.now().add(const Duration(days: 7)));
              }),
            ),
            ChoiceChip(
              key: const Key('ceo_defer_pick'),
              label: Text(_deferChoice == 'pick' && _until != null ? DateFormat('d MMM').format(_until!) : 'Pick a date'),
              selected: _deferChoice == 'pick',
              onSelected: (_) => _pickDate(),
            ),
          ]),
          const SizedBox(height: 4),
          Text('It stays on both your desks and comes back on that day.', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          const SizedBox(height: 12),
        ],
        if (_isReject) ...[
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (var i = 0; i < _quickReasons.length; i++)
              ActionChip(key: Key('ceo_reason_$i'), label: Text(_quickReasons[i]), onPressed: () => _note.text = _quickReasons[i]),
          ]),
          const SizedBox(height: 10),
        ],
        TextField(
          key: const Key('ceo_note_field'),
          controller: _note,
          maxLines: 3,
          minLines: 2,
          maxLength: 500,
          autofocus: _isReject,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _isReject ? 'Why? (the team will see this)' : 'Note (optional)',
            border: const OutlineInputBorder(),
            helperText: _isReject && !_canSubmit ? 'A reason is needed to reject.' : null,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: OutlinedButton(key: const Key('ceo_note_cancel'), onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const Key('ceo_note_submit'),
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: _canSubmit ? () => Navigator.pop<DecisionInput>(context, (note: _note.text.trim(), until: _until)) : null,
              child: Text(verb),
            ),
          ),
        ]),
      ]),
    );
  }
}
