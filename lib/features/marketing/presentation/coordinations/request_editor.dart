import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart' show TeamFilter;

/// Raise a request (or a handover, from the Inter-Department board) or change [request]: who it is from and for, who is given it, how
/// urgent, when it is due. Typed once — the Overview, the tables, the board and the CSV all read this record.
Future<void> showRequestEditor(BuildContext context, WidgetRef ref, {CoordRequestRow? request, String kind = 'request'}) =>
    showCoordForm<void>(context, _RequestForm(request: request, kind: request?.kind ?? kind));

class _RequestForm extends ConsumerStatefulWidget {
  const _RequestForm({this.request, required this.kind});
  final CoordRequestRow? request;
  final String kind;

  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
  late final _title = TextEditingController(text: widget.request?.title ?? '');
  late final _detail = TextEditingController(text: widget.request?.detail ?? '');
  late final _outsider = TextEditingController(text: widget.request != null && widget.request!.assigneeId == null ? widget.request!.assignee : '');
  late String _from = widget.request?.fromDept.isNotEmpty == true ? widget.request!.fromDept : 'Marketing';
  late String? _to = widget.request?.toDept.isNotEmpty == true ? widget.request!.toDept : null;
  late String _priority = widget.request?.priority ?? 'medium';
  late String _brand = widget.request?.brand ?? 'main';
  late String _assignee = widget.request?.assigneeId ?? '';
  late String? _requester = widget.request?.requestedById;
  late String _status = widget.request?.status ?? 'open';
  late double _progress = (widget.request?.progress ?? 0).toDouble();
  bool _progressTouched = false;
  late DateTime? _due = DateTime.tryParse(widget.request?.dueDate ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    _outsider.dispose();
    super.dispose();
  }

  Future<void> _save(CoordSetup setup) async {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Give the request a title.');
      return;
    }
    if (_to == null) {
      setState(() => _error = 'Choose the team the request is for.');
      return;
    }
    final editing = widget.request != null;
    final body = <String, dynamic>{
      if (!editing) 'kind': widget.kind,
      'title': _title.text.trim(),
      'detail': _detail.text.trim(),
      'fromDept': _from,
      'toDept': _to,
      'priority': _priority,
      'brand': _brand,
      'dueDate': _due == null ? null : TeamFilter.day(_due!),
      'assigneeId': _assignee.isEmpty ? null : _assignee,
      if (_assignee.isEmpty) 'assigneeName': _outsider.text.trim(),
      if (setup.isManager && _requester != (editing ? widget.request!.requestedById : setup.meId) && _requester != null) 'requestedById': _requester,
      if (editing && _status != widget.request!.status) 'status': _status,
      if (editing && _progressTouched) 'progress': _progress.round(),
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await coordWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).saveRequest(body, id: widget.request?.id));
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
    final editing = widget.request != null;
    final handover = widget.kind == 'handover';
    final statuses = editing ? [widget.request!.status, ...widget.request!.nextStatuses] : const <String>[];
    return CoordFormFrame(
      title: editing ? (handover ? 'Edit handover' : 'Edit request') : (handover ? 'New handover' : 'New request'),
      keyPrefix: 'co_req',
      saving: _saving,
      error: _error,
      saveLabel: editing ? 'Save' : (handover ? 'Create handover' : 'Create request'),
      onSave: () => _save(setup),
      children: [
        TextField(key: const Key('co_req_title'), controller: _title, decoration: coordDec(handover ? 'What is being handed over' : 'Request or task')),
        const SizedBox(height: 10),
        CoordPair(
          DropdownButtonFormField<String>(key: const Key('co_req_from'), isExpanded: true, initialValue: _from, decoration: coordDec('From team'), items: [for (final d in setup.departments) DropdownMenuItem(value: d, child: Text(d))], onChanged: (v) => setState(() => _from = v ?? _from)),
          DropdownButtonFormField<String>(key: const Key('co_req_to'), isExpanded: true, initialValue: _to, decoration: coordDec('To team'), items: [for (final d in setup.departments) DropdownMenuItem(value: d, child: Text(d))], onChanged: (v) => setState(() => _to = v)),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const Key('co_req_assignee'),
          isExpanded: true,
          initialValue: setup.members.any((m) => m.id == _assignee) || _assignee.isEmpty ? _assignee : null,
          decoration: coordDec('Given to'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Someone outside Marketing / not decided')),
            for (final m in setup.members) DropdownMenuItem(value: m.id, child: Text(m.role.isEmpty ? m.name : '${m.name} · ${m.role}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _assignee = v ?? ''),
        ),
        if (_assignee.isEmpty) ...[const SizedBox(height: 10), TextField(key: const Key('co_req_outsider'), controller: _outsider, decoration: coordDec('Their name (optional)', hint: 'Someone in Production'))],
        const SizedBox(height: 10),
        CoordPair(
          DropdownButtonFormField<String>(key: const Key('co_req_priority'), isExpanded: true, initialValue: _priority, decoration: coordDec('Priority'), items: [for (final p in kPriorities) DropdownMenuItem(value: p.$1, child: Text(p.$2))], onChanged: (v) => setState(() => _priority = v ?? _priority)),
          DropdownButtonFormField<String>(key: const Key('co_req_brand'), isExpanded: true, initialValue: _brand, decoration: coordDec('Brand'), items: const [DropdownMenuItem(value: 'main', child: Text('Main')), DropdownMenuItem(value: 'kerala', child: Text('Kerala'))], onChanged: (v) => setState(() => _brand = v ?? _brand)),
        ),
        const SizedBox(height: 10),
        DatePill(pillKey: const Key('co_req_due'), label: 'Due date', value: _due, onPick: (d) => setState(() => _due = d), onClear: () => setState(() => _due = null)),
        if (setup.isManager) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: const Key('co_req_requester'),
            isExpanded: true,
            initialValue: setup.members.any((m) => m.id == _requester) ? _requester : null,
            decoration: coordDec('Raised by'),
            items: [for (final m in setup.members) DropdownMenuItem(value: m.id, child: Text(m.name))],
            onChanged: (v) => setState(() => _requester = v),
          ),
        ],
        if (editing) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(key: const Key('co_req_status'), isExpanded: true, initialValue: _status, decoration: coordDec('Status'), items: [for (final s in statuses) DropdownMenuItem(value: s, child: Text(requestStatusLabel(s)))], onChanged: (v) => setState(() => _status = v ?? _status)),
          const SizedBox(height: 6),
          Row(children: [
            Text('Progress', style: mktText(12, color: Mkt.inkSoft)),
            Expanded(
              child: Slider(
                key: const Key('co_req_progress'),
                value: _progress.clamp(0, 100),
                min: 0,
                max: 100,
                divisions: 20,
                label: '${_progress.round()}%',
                onChanged: (v) => setState(() {
                  _progress = v;
                  _progressTouched = true;
                }),
              ),
            ),
            SizedBox(width: 40, child: Text('${_progress.round()}%', textAlign: TextAlign.right, style: mktText(12, weight: FontWeight.w700))),
          ]),
        ],
        const SizedBox(height: 6),
        TextField(key: const Key('co_req_detail'), controller: _detail, minLines: 2, maxLines: 4, decoration: coordDec('Details (optional)')),
      ],
    );
  }
}

/// Tap on a request: the form when you may change it, otherwise its facts to read.
Future<void> openRequest(BuildContext context, WidgetRef ref, CoordRequestRow r) => r.isTask ? showRequestDetail(context, r) : r.canEdit ? showRequestEditor(context, ref, request: r) : showRequestDetail(context, r);

Future<void> showRequestDetail(BuildContext context, CoordRequestRow r) {
  Widget row(String k, Widget v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 96, child: Text(k, style: mktText(11.5, color: Mkt.inkSoft))), Expanded(child: Align(alignment: Alignment.centerLeft, child: v))]));
  Widget text(String s) => Text(orDash(s), style: mktText(12.5, weight: FontWeight.w600));
  return showCoordForm<void>(
    context,
    Padding(
      key: const Key('co_req_detail_view'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(r.title, style: mktText(18, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          row('Teams', FromTo(r.fromDept, r.toDept)),
          row('Raised by', text(r.requestedBy)),
          row('Given to', text(r.assignee)),
          row('Priority', MktChip(priorityLabel(r.priority), color: priorityColor(r.priority))),
          row('Due', DueText(r.dueDate, overdue: r.overdue)),
          row('Status', MktChip(rowStatusLabel(r), color: requestStatusColor(r.status))),
          row('Progress', SizedBox(width: 160, child: MktProgress(pct: r.progress, color: Mkt.primaryLight))),
          if (r.detail.isNotEmpty) row('Details', text(r.detail)),
          const SizedBox(height: 8),
          if (r.isTask) ...[
            Text('A Team Dashboard task: it is the same record there, so closing it in either place closes it in both.', style: mktText(11, color: Mkt.inkSoft)),
            const SizedBox(height: 8),
            Builder(builder: (c) => FilledButton(key: const Key('co_task_open_team'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: () { Navigator.pop(c); GoRouter.maybeOf(context)?.go(r.link ?? '/marketing/team?tab=tasks'); }, child: const Text('Open in Team Dashboard'))),
          ] else
            Text('You can change the requests you raised or were given. Ask the Marketing Manager for others.', style: mktText(11, color: Mkt.inkSoft)),
        ]),
      ),
    ),
    maxWidth: 520,
  );
}
