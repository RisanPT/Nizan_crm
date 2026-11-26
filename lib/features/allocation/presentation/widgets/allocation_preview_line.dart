import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/features/allocation/services/allocation_service.dart';

/// Add Booking, while it is filled in: which artist team covers the venue's area (their preferred locations), and — once the event
/// days and times are in — who would take each package, or why CRM would decide. Asked again (after a short pause) whenever the
/// pincode or the programme changes. Shown only with the allocation On, to the people who read it (sales included). Nothing is saved.
class AllocationPreviewLine extends ConsumerStatefulWidget {
  const AllocationPreviewLine({super.key, required this.pincodeCtrl, this.items = const [], this.debounce = const Duration(milliseconds: 500)});

  final TextEditingController pincodeCtrl;

  /// The packages as the booking will send them: { service, eventSlot, selectedDates: ['YYYY-MM-DD'], startTime, endTime, districtId }.
  final List<Map<String, dynamic>> items;
  final Duration debounce;

  @override
  ConsumerState<AllocationPreviewLine> createState() => _AllocationPreviewLineState();
}

class _AllocationPreviewLineState extends ConsumerState<AllocationPreviewLine> {
  Timer? _timer;
  String _asked = '';
  int _ask = 0;
  AllocationPreview? _data;

  @override
  void initState() {
    super.initState();
    widget.pincodeCtrl.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  @override
  void didUpdateWidget(covariant AllocationPreviewLine old) {
    super.didUpdateWidget(old);
    if (old.pincodeCtrl != widget.pincodeCtrl) {
      old.pincodeCtrl.removeListener(_changed);
      widget.pincodeCtrl.addListener(_changed);
    }
    _changed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.pincodeCtrl.removeListener(_changed);
    super.dispose();
  }

  Map<String, dynamic> get _draft {
    final dates = <String>{for (final i in widget.items) ...((i['selectedDates'] as List?) ?? const []).map((d) => d.toString())}.toList()..sort();
    return {'pincode': widget.pincodeCtrl.text.trim(), 'selectedDates': dates, 'bookingItems': widget.items};
  }

  void _changed() {
    if (!mounted || !Access.of(ref.read(authSessionProvider)).canSeeBookingAllocation) return;
    final draft = _draft;
    final key = jsonEncode(draft);
    if (key == _asked) return;
    _asked = key;
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => _fetch(draft));
  }

  Future<void> _fetch(Map<String, dynamic> draft) async {
    final ask = ++_ask;
    try {
      final r = await ref.read(allocationServiceProvider).preview(draft);
      if (mounted && ask == _ask) setState(() => _data = r);
    } catch (_) {
      if (mounted && ask == _ask) setState(() => _data = null); // can't be asked: the form goes on without it
    }
  }

  String _when(PreviewUnit u) {
    final d = u.days.isEmpty ? null : u.days.first;
    final day = d == null ? null : DateTime.tryParse(d.day);
    return [
      if (u.label.isNotEmpty) u.label,
      if (day != null) '${DateFormat('EEE d MMM').format(day)}${d!.start.isEmpty ? '' : ', ${fmtHHMM(d.start)}'}',
    ].join(' · ');
  }

  /// A date at HR's day limit: who can still take it as a 4th work (her works that day close together, her gap fits), or the times it
  /// would fit — sales ask CRM; CRM / the Artist Head can save it.
  List<Widget> _fullDay(CrmTheme crm, FullDay d, Widget Function(IconData, Color, List<Widget>, {Key? key}) row, TextStyle muted, TextStyle strong) {
    final dt = DateTime.tryParse(d.day);
    final dayText = dt == null ? 'This date' : DateFormat('EEE d MMM').format(dt);
    final out = <Widget>[
      row(Icons.event_busy_outlined, crm.warning, [
        Text('$dayText is fully booked${d.blocked ? ' (blocked by HR)' : ' (${d.booked}/${d.capacity})'}', key: const Key('alloc_full_title'), style: strong),
        if (d.blocked || d.left <= 0 || (!d.anyFit && !d.anyOption)) Text(d.message.replaceFirst(RegExp(r'^That date is fully booked \([^)]*\)\. ?'), ''), key: const Key('alloc_full_none'), style: muted),
      ], key: const Key('alloc_full')),
    ];
    if (d.blocked || d.left <= 0) return out;
    for (final u in d.units) {
      final when = '${fmtHHMM(u.start)}–${fmtHHMM(u.end)}${d.units.length > 1 && u.label.isNotEmpty ? ' · ${u.label}' : ''}';
      final f = u.fit;
      if (f != null) {
        final with_ = f.assistants.where((a) => a.isNotEmpty).join(', ');
        out.add(row(Icons.check_circle_outline_rounded, crm.success, [
          Text('4th work possible: ${f.teamName}', style: strong),
          Text([if (f.lead.isNotEmpty) f.lead, if (with_.isNotEmpty) 'with $with_'].join(', '), style: TextStyle(fontSize: 13, color: crm.textPrimary)),
          Text('$when fits her day${f.reason.isEmpty ? '' : ' — ${f.reason}'}', style: muted),
        ], key: Key('alloc_full_fit_${u.unitKey}')));
      } else if (u.options.isNotEmpty) {
        out.add(row(Icons.schedule_rounded, crm.primary, [
          Text('Not at ${fmtHHMM(u.start)} — a 4th work fits at:', style: strong),
          for (final o in u.options)
            for (final w in o.windows) Text('${o.teamName} · ${fmtHHMM(w.from)}–${fmtHHMM(w.to)} (${w.reason})', style: TextStyle(fontSize: 13, color: crm.textPrimary)),
        ], key: Key('alloc_full_options_${u.unitKey}')));
      }
    }
    if (d.anyFit || d.anyOption) {
      final text = d.canBook
          ? (d.allFit ? "You can save it — it goes to her as a 4th work; the Artist Head OKs it." : 'Change the time to one of these to save it.')
          : 'Contact CRM to book this 4th work${d.allFit ? '' : ' at one of these times'}.';
      out.add(Padding(padding: const EdgeInsets.only(left: 26, top: 2), child: Text(text, key: const Key('alloc_full_footer'), style: muted.copyWith(fontStyle: FontStyle.italic))));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = _data;
    if (p == null || !p.on || !Access.of(ref.watch(authSessionProvider)).canSeeBookingAllocation) return const SizedBox.shrink();
    final crm = context.crmColors;
    final muted = TextStyle(fontSize: 12.5, color: crm.textSecondary);
    final strong = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary);

    Widget row(IconData icon, Color color, List<Widget> lines, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: color)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines)),
          ]),
        );

    final children = <Widget>[];
    final full = p.day;
    if (full != null && full.full) {
      children.addAll(_fullDay(crm, full, row, muted, strong));
    } else if (p.pincode.isEmpty && p.districtName.isEmpty) {
      children.add(row(Icons.person_pin_circle_outlined, crm.textSecondary, [Text('Artist: enter the 6-digit pincode to see who covers this area.', style: muted)], key: const Key('alloc_preview_hint')));
    } else if (p.units.isEmpty) {
      if (p.preferredTeams.isNotEmpty) {
        final t = p.preferredTeams.first;
        final with_ = t.assistants.where((a) => a.isNotEmpty).join(', ');
        final more = p.preferredTeams.length > 1 ? ' (also ${p.preferredTeams.skip(1).map((x) => x.teamName).join(', ')})' : '';
        children.add(row(Icons.person_pin_circle_outlined, crm.primary, [
          Text('Preferred artist for ${p.areaName}: ${t.teamName}$more', style: strong),
          Text([if (t.lead.isNotEmpty) t.lead, if (with_.isNotEmpty) 'with $with_'].join(', '), style: TextStyle(fontSize: 13, color: crm.textPrimary)),
          Text('Add the event day and time to check she is free.', style: muted),
        ], key: const Key('alloc_preview_area')));
      } else {
        children.add(row(Icons.person_search_outlined, crm.warning, [
          Text(p.teams == 0 ? 'No artist teams are set up yet — CRM assigns the artist after you save.' : 'No artist team has ${p.areaName} as a preferred location — CRM assigns the artist after you save.', style: TextStyle(fontSize: 13, color: crm.textPrimary)),
        ], key: const Key('alloc_preview_area')));
      }
    } else {
      for (final u in p.units) {
        final when = p.units.length > 1 ? _when(u) : '';
        if (u.ok) {
          children.add(row(Icons.check_circle_outline_rounded, crm.success, [
            if (when.isNotEmpty) Text(when, style: muted),
            Text('Likely artist: ${u.teamName}', style: strong),
            if (u.people.isNotEmpty) Text(u.people, style: TextStyle(fontSize: 13, color: crm.textPrimary)),
            Text(u.reason, style: muted),
          ], key: Key('alloc_preview_${u.unitKey}')));
        } else {
          children.add(row(Icons.hourglass_top_rounded, crm.warning, [
            if (when.isNotEmpty) Text(when, style: muted),
            Text('CRM assigns the artist after you save', style: strong),
            Text(u.reason, style: muted),
          ], key: Key('alloc_preview_${u.unitKey}')));
        }
      }
      if (p.units.any((u) => u.ok)) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 26, top: 2),
          child: Text(p.auto ? 'Assigned automatically when you save.' : 'CRM confirms the artist after you save.', key: const Key('alloc_preview_footer'), style: muted.copyWith(fontStyle: FontStyle.italic)),
        ));
      }
    }
    return Container(
      key: const Key('alloc_preview'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
