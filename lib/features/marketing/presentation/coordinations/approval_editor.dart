import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart' show TeamFilter;

/// Raise an approval (what, a category, an amount and what it affects) or change [approval] while it is still open. The amount is only
/// recorded for the decision — nothing is posted to accounts from here.
Future<void> showApprovalEditor(BuildContext context, WidgetRef ref, {ApprovalRow? approval}) => showCoordForm<void>(context, _ApprovalForm(approval: approval));

class _ApprovalForm extends ConsumerStatefulWidget {
  const _ApprovalForm({this.approval});
  final ApprovalRow? approval;

  @override
  ConsumerState<_ApprovalForm> createState() => _ApprovalFormState();
}

class _ApprovalFormState extends ConsumerState<_ApprovalForm> {
  late final _title = TextEditingController(text: widget.approval?.title ?? '');
  late final _amount = TextEditingController(text: widget.approval == null || widget.approval!.amount == 0 ? '' : (widget.approval!.amount == widget.approval!.amount.roundToDouble() ? '${widget.approval!.amount.round()}' : '${widget.approval!.amount}'));
  late final _impact = TextEditingController(text: widget.approval?.impact ?? '');
  late String? _category = widget.approval?.category.isNotEmpty == true ? widget.approval!.category : null;
  late String _brand = widget.approval?.brand ?? 'main';
  late String _request = widget.approval?.requestId ?? '';
  late String? _requester = widget.approval?.requestedById;
  late DateTime? _due = DateTime.tryParse(widget.approval?.dueDate ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _impact.dispose();
    super.dispose();
  }

  Future<void> _save(CoordSetup setup) async {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Say what needs approving.');
      return;
    }
    if (_category == null) {
      setState(() => _error = 'Choose a category.');
      return;
    }
    final raw = _amount.text.trim().replaceAll(',', '');
    final amount = raw.isEmpty ? 0.0 : double.tryParse(raw);
    if (amount == null) {
      setState(() => _error = 'The amount must be a number.');
      return;
    }
    final editing = widget.approval != null;
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'category': _category,
      'amount': amount,
      'impact': _impact.text.trim(),
      'dueDate': _due == null ? null : TeamFilter.day(_due!),
      'brand': _brand,
      'requestId': _request.isEmpty ? null : _request,
      if (setup.isManager && _requester != null && _requester != (editing ? widget.approval!.requestedById : setup.meId)) 'requestedById': _requester,
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await coordWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).saveApproval(body, id: widget.approval?.id));
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _error = err;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(coordSetupProvider).maybeWhen(data: (s) => s, orElse: () => const CoordSetup());
    final editing = widget.approval != null;
    final waiting = [...setup.waitingRequests];
    if (_request.isNotEmpty && !waiting.any((w) => w.id == _request)) waiting.add((id: _request, title: 'The linked request'));
    return CoordFormFrame(
      title: editing ? 'Edit approval' : 'New approval',
      keyPrefix: 'co_ap',
      saving: _saving,
      error: _error,
      saveLabel: editing ? 'Save' : 'Raise approval',
      onSave: () => _save(setup),
      children: [
        TextField(key: const Key('co_ap_title'), controller: _title, decoration: coordDec('What needs approving', hint: 'Campaign ad budget – Nov')),
        const SizedBox(height: 10),
        CoordPair(
          DropdownButtonFormField<String>(key: const Key('co_ap_category'), isExpanded: true, initialValue: _category, decoration: coordDec('Category'), items: [for (final c in kApprovalCategories) DropdownMenuItem(value: c, child: Text(c))], onChanged: (v) => setState(() => _category = v)),
          TextField(key: const Key('co_ap_amount'), controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: coordDec('Amount (₹)', hint: '20000')),
        ),
        const SizedBox(height: 10),
        TextField(key: const Key('co_ap_impact'), controller: _impact, minLines: 2, maxLines: 4, decoration: coordDec('Impact — what this affects')),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DatePill(pillKey: const Key('co_ap_due'), label: 'Needed by', value: _due, onPick: (d) => setState(() => _due = d), onClear: () => setState(() => _due = null)),
          SizedBox(width: 150, child: DropdownButtonFormField<String>(key: const Key('co_ap_brand'), isExpanded: true, initialValue: _brand, decoration: coordDec('Brand'), items: const [DropdownMenuItem(value: 'main', child: Text('Main')), DropdownMenuItem(value: 'kerala', child: Text('Kerala'))], onChanged: (v) => setState(() => _brand = v ?? _brand))),
        ]),
        if (waiting.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const Key('co_ap_request'),
            isExpanded: true,
            initialValue: _request,
            decoration: coordDec('Unblocks this request (optional)'),
            items: [const DropdownMenuItem(value: '', child: Text('None')), for (final w in waiting) DropdownMenuItem(value: w.id, child: Text(w.title, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _request = v ?? ''),
          ),
        ],
        if (setup.isManager) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const Key('co_ap_requester'),
            isExpanded: true,
            initialValue: setup.members.any((m) => m.id == _requester) ? _requester : null,
            decoration: coordDec('Raised by'),
            items: [for (final m in setup.members) DropdownMenuItem(value: m.id, child: Text(m.name))],
            onChanged: (v) => setState(() => _requester = v),
          ),
        ],
        const SizedBox(height: 8),
        Text('Only the Marketing Manager decides. The amount is recorded for the decision — nothing is posted to accounts.', style: mktText(11, color: Mkt.inkSoft)),
      ],
    );
  }
}

/// A decision on an approval — approve, reject (a reason is needed), escalate or mark in review — shown with what is being decided.
Future<void> showDecisionDialog(BuildContext context, WidgetRef ref, ApprovalRow a, String decision) => showCoordForm<void>(context, _DecisionForm(approval: a, decision: decision), maxWidth: 480);

class _DecisionForm extends ConsumerStatefulWidget {
  const _DecisionForm({required this.approval, required this.decision});
  final ApprovalRow approval;
  final String decision;

  @override
  ConsumerState<_DecisionForm> createState() => _DecisionFormState();
}

class _DecisionFormState extends ConsumerState<_DecisionForm> {
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  static const _titles = {'approve': 'Approve', 'reject': 'Reject', 'escalate': 'Escalate', 'review': 'Mark in review'};

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (widget.decision == 'reject' && _note.text.trim().length < 3) {
      setState(() => _error = 'Say why it is rejected, so the requester knows.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await coordWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).decideApproval(widget.approval.id, widget.decision, note: _note.text));
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _error = err;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.approval;
    return CoordFormFrame(
      title: '${_titles[widget.decision] ?? 'Decide'}: ${a.title}',
      keyPrefix: 'co_decide',
      saving: _saving,
      error: _error,
      saveLabel: _titles[widget.decision] ?? 'Confirm',
      onSave: _go,
      children: [
        Wrap(spacing: 8, runSpacing: 6, children: [MktChip(a.category, color: Mkt.primary), MktChip(inr(a.amount), color: Mkt.warn), if (a.requestedBy.isNotEmpty) MktChip('Raised by ${a.requestedBy}', color: Mkt.blue)]),
        if (a.impact.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Impact: ${a.impact}', style: mktText(12, color: Mkt.inkSoft))),
        const SizedBox(height: 12),
        TextField(key: const Key('co_decide_note'), controller: _note, minLines: 2, maxLines: 4, decoration: coordDec(widget.decision == 'reject' ? 'Reason (required)' : 'Note (optional)')),
      ],
    );
  }
}

/// An approval you may not change: its facts and the decision, to read.
Future<void> showApprovalDetail(BuildContext context, ApprovalRow a) {
  Widget row(String k, Widget v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 100, child: Text(k, style: mktText(11.5, color: Mkt.inkSoft))), Expanded(child: Align(alignment: Alignment.centerLeft, child: v))]));
  Widget text(String s) => Text(orDash(s), style: mktText(12.5, weight: FontWeight.w600));
  return showCoordForm<void>(
    context,
    Padding(
      key: const Key('co_ap_detail_view'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(a.title, style: mktText(18, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          row('Category', text(a.category)),
          row('Amount', text(inr(a.amount))),
          row('Impact', text(a.impact)),
          row('Raised by', text(a.requestedBy)),
          row('Needed by', DueText(a.dueDate, overdue: a.overdue)),
          row('Status', MktChip(approvalStatusLabel(a.status), color: approvalStatusColor(a.status))),
          if (a.escalatedToLabel.isNotEmpty) row('Escalation', text('${a.escalatedToLabel}${a.escalatedBy.isEmpty ? '' : ' (by ${a.escalatedBy})'}')),
          if (a.decidedBy.isNotEmpty) row('Decided by', text(a.decidedBy)),
          if (a.decisionNote.isNotEmpty) row('Note', text(a.decisionNote)),
        ]),
      ),
    ),
    maxWidth: 520,
  );
}
