import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart' show TeamFilter;

/// Schedule a meeting, or change [meeting] (read one by one, so it carries its agenda, attendees and action items). With [complete] the
/// form opens ready to close it: Completed, the discussion notes and the action items.
Future<void> showMeetingEditor(BuildContext context, WidgetRef ref, {MeetingRow? meeting, bool complete = false}) => showCoordForm<void>(context, _MeetingForm(meeting: meeting, complete: complete), maxWidth: 700);

class _ItemDraft {
  _ItemDraft({this.id, String text = '', this.ownerId, this.ownerName = '', this.due, this.done = false, this.followUpId}) : text = TextEditingController(text: text);
  final String? id, followUpId;
  final TextEditingController text;
  String? ownerId;
  String ownerName;
  DateTime? due;
  bool done;
}

class _MeetingForm extends ConsumerStatefulWidget {
  const _MeetingForm({this.meeting, required this.complete});
  final MeetingRow? meeting;
  final bool complete;

  @override
  ConsumerState<_MeetingForm> createState() => _MeetingFormState();
}

class _MeetingFormState extends ConsumerState<_MeetingForm> {
  late final _title = TextEditingController(text: widget.meeting?.title ?? '');
  late final _location = TextEditingController(text: widget.meeting?.location ?? '');
  late final _link = TextEditingController(text: widget.meeting?.link ?? '');
  late final _agenda = TextEditingController(text: (widget.meeting?.agenda ?? const []).join('\n'));
  late final _others = TextEditingController(text: (widget.meeting?.attendees ?? const []).where((a) => a.memberId == null).map((a) => a.name).join(', '));
  late final _notes = TextEditingController(text: widget.meeting?.notes ?? '');
  late DateTime _day = DateTime.tryParse(widget.meeting?.day ?? '') ?? DateTime.now();
  late TimeOfDay _start = _parse(widget.meeting?.time) ?? const TimeOfDay(hour: 10, minute: 0);
  late TimeOfDay _end = _parse(widget.meeting?.endTime) ?? const TimeOfDay(hour: 11, minute: 0);
  late final Set<String> _depts = {...?widget.meeting?.departments};
  late final Set<String> _members = {for (final a in widget.meeting?.attendees ?? const <Attendee>[]) if (a.memberId != null) a.memberId!};
  late String _brand = widget.meeting?.brand ?? 'main';
  late String _status = widget.complete ? 'completed' : (widget.meeting?.status ?? 'upcoming');
  late final List<_ItemDraft> _items = [for (final i in widget.meeting?.actionItems ?? const <ActionItemRow>[]) _ItemDraft(id: i.id, text: i.text, ownerId: i.ownerId, ownerName: i.ownerId == null ? i.owner : '', due: DateTime.tryParse(i.due ?? ''), done: i.done, followUpId: i.followUpId)];
  bool _saving = false;
  String? _error;

  static TimeOfDay? _parse(String? s) => s != null && s.length == 5 ? TimeOfDay(hour: int.tryParse(s.substring(0, 2)) ?? 0, minute: int.tryParse(s.substring(3)) ?? 0) : null;

  @override
  void dispose() {
    for (final c in [_title, _location, _link, _agenda, _others, _notes]) {
      c.dispose();
    }
    for (final i in _items) {
      i.text.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (t != null) setState(() => start ? _start = t : _end = t);
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Give the meeting a title.');
      return;
    }
    final editing = widget.meeting != null;
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'startAt': istInstant(_day, _start),
      'endAt': istInstant(_day, _end),
      'location': _location.text.trim(),
      'link': _link.text.trim(),
      'departments': _depts.toList(),
      'brand': _brand,
      'agenda': _agenda.text.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList(),
      'attendees': [
        for (final id in _members) {'memberId': id},
        for (final n in _others.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty)) {'name': n},
      ],
      if (editing || widget.complete) 'status': _status,
      if (editing || widget.complete) 'notes': _notes.text.trim(),
      if (editing || widget.complete)
        'actionItems': [
          for (final i in _items.where((i) => i.text.text.trim().isNotEmpty))
            {if (i.id != null) 'id': i.id, 'text': i.text.text.trim(), if (i.ownerId != null) 'ownerId': i.ownerId else 'ownerName': i.ownerName, 'due': i.due == null ? null : TeamFilter.day(i.due!), 'done': i.done},
        ],
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await coordWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).saveMeeting(body, id: widget.meeting?.id));
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
    final editing = widget.meeting != null;
    final closing = editing || widget.complete;
    return CoordFormFrame(
      title: widget.complete ? 'Close the meeting' : (editing ? 'Edit meeting' : 'Schedule meeting'),
      keyPrefix: 'co_mt',
      saving: _saving,
      error: _error,
      saveLabel: editing ? 'Save' : 'Schedule',
      onSave: _save,
      children: [
        TextField(key: const Key('co_mt_title'), controller: _title, decoration: coordDec('Meeting title', hint: 'Marketing Sync')),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          DatePill(pillKey: const Key('co_mt_date'), label: 'Date', value: _day, onPick: (d) => setState(() => _day = d)),
          MktPill(key: const Key('co_mt_start'), label: 'From ${_start.format(context)}', icon: Icons.schedule_rounded, trailing: false, onTap: () => _pickTime(true)),
          MktPill(key: const Key('co_mt_end'), label: 'To ${_end.format(context)}', icon: Icons.schedule_rounded, trailing: false, onTap: () => _pickTime(false)),
        ]),
        const SizedBox(height: 10),
        CoordPair(
          TextField(key: const Key('co_mt_location'), controller: _location, decoration: coordDec('Where', hint: 'Conference Room')),
          TextField(key: const Key('co_mt_link'), controller: _link, decoration: coordDec('Meeting link', hint: 'https://meet.google.com/…')),
        ),
        const SizedBox(height: 12),
        Text('Teams involved', style: mktText(13, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final d in setup.departments) MktFilterChip(key: Key('co_mt_dept_$d'), label: d, selected: _depts.contains(d), onTap: () => setState(() => _depts.contains(d) ? _depts.remove(d) : _depts.add(d)))]),
        const SizedBox(height: 12),
        TextField(key: const Key('co_mt_agenda'), controller: _agenda, minLines: 2, maxLines: 5, decoration: coordDec('Agenda (one point per line)')),
        const SizedBox(height: 12),
        Text('Attendees', style: mktText(13, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (setup.members.isEmpty) Text('The team list loads here.', style: mktText(11.5, color: Mkt.inkSoft)) else Wrap(spacing: 6, runSpacing: 6, children: [for (final m in setup.members) MktFilterChip(key: Key('co_mt_member_${m.id}'), label: m.name, selected: _members.contains(m.id), onTap: () => setState(() => _members.contains(m.id) ? _members.remove(m.id) : _members.add(m.id)))]),
        const SizedBox(height: 8),
        TextField(key: const Key('co_mt_others'), controller: _others, decoration: coordDec('Others (names, comma separated)', hint: 'Client representative')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(key: const Key('co_mt_brand'), isExpanded: true, initialValue: _brand, decoration: coordDec('Brand'), items: const [DropdownMenuItem(value: 'main', child: Text('Main')), DropdownMenuItem(value: 'kerala', child: Text('Kerala'))], onChanged: (v) => setState(() => _brand = v ?? _brand)),
        if (closing) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(key: const Key('co_mt_status'), isExpanded: true, initialValue: _status, decoration: coordDec('Status'), items: const [DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')), DropdownMenuItem(value: 'completed', child: Text('Completed')), DropdownMenuItem(value: 'cancelled', child: Text('Cancelled'))], onChanged: (v) => setState(() => _status = v ?? _status)),
          const SizedBox(height: 10),
          TextField(key: const Key('co_mt_notes'), controller: _notes, minLines: 3, maxLines: 6, decoration: coordDec('Discussion notes')),
          const SizedBox(height: 12),
          Text('Action items', style: mktText(13, weight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (var n = 0; n < _items.length; n++) _itemRow(n, setup),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('co_mt_add_item'), onPressed: () => setState(() => _items.add(_ItemDraft())), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add action item'))),
        ],
      ],
    );
  }

  Widget _itemRow(int n, CoordSetup setup) {
    final i = _items[n];
    return Container(
      key: Key('co_mt_item_$n'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Mkt.border), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: TextField(key: Key('co_mt_item_text_$n'), controller: i.text, decoration: coordDec('What has to be done'))),
          IconButton(key: Key('co_mt_item_remove_$n'), tooltip: 'Remove', visualDensity: VisualDensity.compact, onPressed: () => setState(() => _items.removeAt(n).text.dispose()), icon: const Icon(Icons.close_rounded, size: 18)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              key: Key('co_mt_item_owner_$n'),
              isExpanded: true,
              initialValue: setup.members.any((m) => m.id == i.ownerId) ? i.ownerId : '',
              decoration: coordDec('Owner'),
              items: [DropdownMenuItem(value: '', child: Text(i.ownerId == null && i.ownerName.isNotEmpty ? i.ownerName : 'Not decided', overflow: TextOverflow.ellipsis)), for (final m in setup.members) DropdownMenuItem(value: m.id, child: Text(m.name))],
              onChanged: (v) => setState(() => i.ownerId = (v ?? '').isEmpty ? null : v),
            ),
          ),
          DatePill(pillKey: Key('co_mt_item_due_$n'), label: 'Due date', value: i.due, onPick: (d) => setState(() => i.due = d), onClear: () => setState(() => i.due = null)),
          if (i.followUpId != null) const MktChip('In Follow-ups', color: Mkt.primaryLight),
        ]),
      ]),
    );
  }
}
