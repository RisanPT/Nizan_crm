import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/link_pickers.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_widgets.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Plan a shoot (on [day]) or change [shoot]: the brand, content pillar, date, crew (the team and makeup artists), the work (CRM booking)
/// it covers and what it should produce — typed once. The planned outputs are what Shoot Reports compare the delivered assets against.
/// [booking] opens a new plan for that work: the work is linked and its day and client fill the plan.
Future<void> showShootEditor(BuildContext context, WidgetRef ref, {ShootDetail? shoot, DateTime? day, BookingBrief? booking}) {
  final form = _ShootForm(shoot: shoot, day: day, booking: booking);
  if (MediaQuery.sizeOf(context).width >= 760) {
    return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: form)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: form));
}

class _ShootForm extends ConsumerStatefulWidget {
  const _ShootForm({this.shoot, this.day, this.booking});
  final ShootDetail? shoot;
  final DateTime? day;
  final BookingBrief? booking;

  @override
  ConsumerState<_ShootForm> createState() => _ShootFormState();
}

class _ShootFormState extends ConsumerState<_ShootForm> {
  late final _title = TextEditingController(text: widget.shoot?.summary.title ?? (widget.booking == null ? '' : [widget.booking!.customerName, widget.booking!.service].where((x) => x.isNotEmpty).join(' – ')));
  late final _category = TextEditingController(text: widget.shoot?.summary.category ?? '');
  late final _pillar = TextEditingController(text: widget.shoot?.pillar ?? '');
  late final _location = TextEditingController(text: widget.shoot?.summary.location ?? '');
  late final _cover = TextEditingController(text: widget.shoot?.summary.coverUrl ?? '');
  late final _objective = TextEditingController(text: widget.shoot?.objective ?? '');
  late final _audience = TextEditingController(text: widget.shoot?.audience ?? '');
  late final _notes = TextEditingController(text: widget.shoot?.notes ?? '');
  late final _otherCrew = TextEditingController(text: (widget.shoot?.crew ?? const []).where((c) => c.memberId == null && c.employeeId == null).map((c) => c.role.isEmpty ? c.name : '${c.name} – ${c.role}').join(', '));
  late final Map<String, TextEditingController> _planned = {for (final o in kOutputKeys) o.$1: TextEditingController(text: (widget.shoot?.summary.planned[o.$1] ?? 0) == 0 ? '' : '${widget.shoot!.summary.planned[o.$1]}')};
  late String _brand = widget.shoot?.summary.brand ?? 'main';
  late String _type = widget.shoot?.summary.shootType.isNotEmpty == true ? widget.shoot!.summary.shootType : 'Full Shoot';
  late String _status = widget.shoot?.summary.status ?? 'planned';
  late DateTime _date = DateTime.tryParse(widget.shoot?.summary.shootDate ?? '') ?? widget.day ?? DateTime.tryParse(widget.booking?.eventDate ?? '') ?? DateTime.now();
  // the work the shoot covers; a saved shoot's link may only be known by its id
  late BookingBrief? _booking = widget.shoot?.booking ?? widget.booking;
  late String? _bookingId = widget.shoot?.summary.bookingId ?? widget.booking?.id;
  // the makeup artists on the crew, with the name and role saved on the plan
  late final Map<String, CrewMember> _artists = {for (final c in widget.shoot?.crew ?? const <CrewMember>[]) if (c.employeeId != null && c.memberId == null) c.employeeId!: c};
  TimeOfDay? _start, _end;
  late final Set<String> _crew = {for (final c in widget.shoot?.crew ?? const <CrewMember>[]) if (c.memberId != null) c.memberId!};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    TimeOfDay? parse(String s) => s.length == 5 ? TimeOfDay(hour: int.tryParse(s.substring(0, 2)) ?? 0, minute: int.tryParse(s.substring(3)) ?? 0) : null;
    _start = parse(widget.shoot?.summary.startTime ?? '');
    _end = parse(widget.shoot?.summary.endTime ?? '');
  }

  @override
  void dispose() {
    for (final c in [_title, _category, _pillar, _location, _cover, _objective, _audience, _notes, _otherCrew, ..._planned.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 2));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(context: context, initialTime: (start ? _start : _end) ?? const TimeOfDay(hour: 9, minute: 0));
    if (t != null) setState(() => start ? _start = t : _end = t);
  }

  Future<void> _pickBooking() async {
    final r = await pickBooking(context, selectedId: _bookingId, around: TeamFilter.day(_date));
    if (r == null || !mounted) return;
    setState(() {
      _booking = r.value;
      _bookingId = r.value?.id;
    });
  }

  Future<void> _save(ShootSetup setup) async {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Give the shoot a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final crew = <CrewMember>[
      for (final m in setup.members) if (_crew.contains(m.id)) CrewMember(memberId: m.id, name: m.name, role: m.role),
      // a team member on the plan who is not in the list just now (it has not loaded, or they are no longer active) stays on it as saved
      for (final c in widget.shoot?.crew ?? const <CrewMember>[])
        if (c.memberId != null && _crew.contains(c.memberId) && !setup.members.any((m) => m.id == c.memberId)) CrewMember(memberId: c.memberId, name: c.name, role: c.role),
      for (final a in _artists.values) CrewMember(employeeId: a.employeeId, name: a.name, role: a.role),
      for (final part in _otherCrew.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty))
        CrewMember(name: part.split(RegExp(r'\s[–-]\s')).first.trim(), role: part.contains(RegExp(r'\s[–-]\s')) ? part.split(RegExp(r'\s[–-]\s')).last.trim() : ''),
    ];
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'brand': _brand,
      'category': _category.text.trim(),
      'pillar': _pillar.text.trim(),
      'shootType': _type,
      'shootDate': TeamFilter.day(_date),
      'startTime': _start == null ? '' : hhmm(_start!),
      'endTime': _end == null ? '' : hhmm(_end!),
      'location': _location.text.trim(),
      'coverUrl': _cover.text.trim(),
      'brief': {'objective': _objective.text.trim(), 'audience': _audience.text.trim(), 'notes': _notes.text.trim()},
      'planned': {for (final e in _planned.entries) e.key: int.tryParse(e.value.text.trim()) ?? (e.value.text.trim().isEmpty ? 0 : -1)},
      'crew': [for (final c in crew) c.toJson()],
      'bookingId': _bookingId,
      if (widget.shoot != null) 'status': _status,
    };
    try {
      await ref.read(marketingPortfolioServiceProvider).saveShoot(body, id: widget.shoot?.summary.id);
      refreshPortfolio(ref);
      if (mounted) Navigator.pop(context);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() { _error = r.message; _saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(shootSetupProvider).maybeWhen(data: (s) => s, orElse: () => const ShootSetup());
    final editing = widget.shoot != null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(editing ? 'Edit shoot plan' : 'New shoot plan', style: mktText(19, weight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(key: const Key('shoot_title'), controller: _title, decoration: _dec('Shoot title')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(key: const Key('shoot_brand'), isExpanded: true, initialValue: _brand, decoration: _dec('Brand'), items: const [DropdownMenuItem(value: 'main', child: Text('Main')), DropdownMenuItem(value: 'kerala', child: Text('Kerala'))], onChanged: (v) => setState(() => _brand = v ?? _brand))),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(key: const Key('shoot_type'), isExpanded: true, initialValue: setup.shootTypes.contains(_type) ? _type : null, decoration: _dec('Shoot type'), items: [for (final t in {...setup.shootTypes, _type}) DropdownMenuItem(value: t, child: Text(t))], onChanged: (v) => setState(() => _type = v ?? _type))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(key: const Key('shoot_category'), controller: _category, decoration: _dec('Category', hint: 'Bridal Makeup'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(key: const Key('shoot_pillar'), controller: _pillar, decoration: _dec('Content pillar', hint: 'Bridal · Trust'))),
            ]),
            if (setup.categories.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 4, children: [for (final c in setup.categories.take(8)) ActionChip(label: Text(c, style: mktText(11)), visualDensity: VisualDensity.compact, onPressed: () => setState(() => _category.text = c))])),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              MktPill(key: const Key('shoot_date'), label: shootDay(TeamFilter.day(_date), pattern: 'EEE d MMM yyyy'), icon: Icons.calendar_today_outlined, trailing: false, onTap: _pickDate),
              MktPill(key: const Key('shoot_start'), label: _start == null ? 'Start time' : _start!.format(context), icon: Icons.schedule_rounded, trailing: false, onTap: () => _pickTime(true)),
              MktPill(key: const Key('shoot_end'), label: _end == null ? 'End time' : _end!.format(context), icon: Icons.schedule_rounded, trailing: false, onTap: () => _pickTime(false)),
            ]),
            const SizedBox(height: 10),
            TextField(key: const Key('shoot_location'), controller: _location, decoration: _dec('Location', hint: 'Studio 1, Kozhikode')),
            const SizedBox(height: 10),
            LinkField(
              key: const Key('shoot_booking'),
              label: 'Work (booking) this shoot covers',
              icon: Icons.event_note_outlined,
              hint: 'None — a brand shoot',
              value: _bookingId == null ? null : (_booking == null ? 'A linked booking' : '${_booking!.label}${_booking!.eventDate == null ? '' : ' · ${shootDay(_booking!.eventDate!, pattern: 'd MMM')}'}'),
              onTap: _pickBooking,
              onClear: () => setState(() {
                _booking = null;
                _bookingId = null;
              }),
            ),
            if (editing) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(key: const Key('shoot_status'), isExpanded: true, initialValue: _status, decoration: _dec('Status'), items: [for (final s in kShootStatuses) DropdownMenuItem(value: s.$1, child: Text(s.$2))], onChanged: (v) => setState(() => _status = v ?? _status)),
            ],
            const SizedBox(height: 14),
            Text('Crew', style: mktText(13, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (setup.members.isEmpty) Text('The team list loads here.', style: mktText(11.5, color: Mkt.inkSoft)) else Wrap(spacing: 6, runSpacing: 6, children: [for (final m in setup.members) MktFilterChip(key: Key('shoot_crew_${m.id}'), label: m.role.isEmpty ? m.name : '${m.name} · ${m.role}', selected: _crew.contains(m.id), onTap: () => setState(() => _crew.contains(m.id) ? _crew.remove(m.id) : _crew.add(m.id)))]),
            const SizedBox(height: 10),
            Text('Makeup artists', style: mktText(12, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final a in _artists.values) InputChip(key: Key('shoot_artist_${a.employeeId}'), label: Text(a.role.isEmpty ? a.name : '${a.name} · ${a.role}', style: mktText(11.5)), onDeleted: () => setState(() => _artists.remove(a.employeeId)), visualDensity: VisualDensity.compact),
              if (setup.artists.any((a) => !_artists.containsKey(a.id)))
                PopupMenuButton<String>(
                  key: const Key('shoot_artist_add'),
                  tooltip: 'Add a makeup artist',
                  onSelected: (id) {
                    final a = setup.artists.firstWhere((x) => x.id == id);
                    setState(() => _artists[id] = CrewMember(employeeId: a.id, name: a.name, role: a.role));
                  },
                  itemBuilder: (_) => [for (final a in setup.artists) if (!_artists.containsKey(a.id)) PopupMenuItem(value: a.id, child: Text(a.role.isEmpty ? a.name : '${a.name} · ${a.role}'))],
                  child: Chip(avatar: const Icon(Icons.add_rounded, size: 16, color: Mkt.primary), label: Text('Add a makeup artist', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.primary)), visualDensity: VisualDensity.compact),
                )
              else if (_artists.isEmpty)
                Text('No makeup artists on the staff list.', style: mktText(11.5, color: Mkt.inkSoft)),
            ]),
            const SizedBox(height: 8),
            TextField(key: const Key('shoot_other_crew'), controller: _otherCrew, decoration: _dec('Others (name – role, comma separated)', hint: 'Makeup artist – Makeup, Model')),
            const SizedBox(height: 14),
            Text('Planned outputs', style: mktText(13, weight: FontWeight.w800)),
            Text('Shoot Reports compare what is delivered against these.', style: mktText(11.5, color: Mkt.inkSoft)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final o in kOutputKeys) SizedBox(width: 118, child: TextField(key: Key('shoot_planned_${o.$1}'), controller: _planned[o.$1], keyboardType: TextInputType.number, decoration: _dec(o.$2)))]),
            const SizedBox(height: 14),
            TextField(key: const Key('shoot_objective'), controller: _objective, minLines: 2, maxLines: 3, decoration: _dec('Objective')),
            const SizedBox(height: 10),
            TextField(key: const Key('shoot_audience'), controller: _audience, decoration: _dec('Audience')),
            const SizedBox(height: 10),
            TextField(key: const Key('shoot_notes'), controller: _notes, minLines: 2, maxLines: 4, decoration: _dec('Notes')),
            const SizedBox(height: 10),
            TextField(key: const Key('shoot_cover'), controller: _cover, decoration: _dec('Cover picture link (optional)', hint: 'https://…')),
            const SizedBox(height: 6),
            // the moodboard is built in its own tab (pictures from the phone or computer, and links) — an edit here never touches it
            Text('Moodboard pictures and links are added in the plan\'s Moodboard tab.', key: const Key('shoot_moodboard_note'), style: mktText(11.5, color: Mkt.inkSoft)),
          ]),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Mkt.border))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const Key('shoot_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(key: const Key('shoot_cancel'), onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 10),
            FilledButton(key: const Key('shoot_save'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: _saving ? null : () => _save(setup), child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(editing ? 'Save' : 'Create plan')),
          ]),
        ]),
      ),
    ]);
  }
}
