import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/district.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/features/allocation/services/allocation_service.dart';
import 'package:nizan_crm/services/district_service.dart';

/// Add or edit an artist team: the main artist, her assistants, where she prefers to work (districts — a whole region at once — and
/// pincode areas), her slots a day and whether she may take an EXTRA slot. → true when saved.
Future<bool?> showTeamEditDialog(BuildContext context, {ArtistTeamView? team}) {
  final body = _TeamEditForm(team: team);
  if (MediaQuery.sizeOf(context).width >= 760) {
    return showDialog<bool>(context: context, builder: (_) => Dialog(clipBehavior: Clip.antiAlias, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780), child: body)));
  }
  return showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => FractionallySizedBox(heightFactor: 0.94, child: body));
}

class _TeamEditForm extends ConsumerStatefulWidget {
  const _TeamEditForm({this.team});
  final ArtistTeamView? team;
  @override
  ConsumerState<_TeamEditForm> createState() => _TeamEditFormState();
}

class _TeamEditFormState extends ConsumerState<_TeamEditForm> {
  late String? _lead = widget.team?.lead.id;
  late final Set<String> _assistants = {...?widget.team?.assistants.map((a) => a.id)};
  late final Set<String> _districts = {...?widget.team?.preferredDistricts.map((d) => d.id)};
  late final TextEditingController _pins = TextEditingController(text: widget.team?.preferredPincodes.join(', ') ?? '');
  late final TextEditingController _notes = TextEditingController(text: widget.team?.notes ?? '');
  late int _morning = widget.team?.morningSlots ?? 2;
  late int _evening = widget.team?.eveningSlots ?? 1;
  late bool _extra = widget.team?.extraAllowed ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pins.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_lead == null) {
      setState(() => _error = 'Choose the main artist.');
      return;
    }
    final pins = _pins.text.split(RegExp(r'[,\s]+')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (pins.any((p) => !RegExp(r'^[1-9]\d{5}$').hasMatch(p))) {
      setState(() => _error = 'A pincode is 6 digits, like 673001.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'leadEmployeeId': _lead,
      'assistantEmployeeIds': _assistants.where((a) => a != _lead).toList(),
      'preferredDistrictIds': _districts.toList(),
      'preferredPincodes': pins,
      'slots': {'morning': _morning, 'evening': _evening},
      'extraAllowed': _extra,
      'notes': _notes.text.trim(),
    };
    try {
      final svc = ref.read(allocationServiceProvider);
      widget.team == null ? await svc.createTeam(body) : await svc.updateTeam(widget.team!.id, body);
      refreshAllocation(ref);
      if (mounted) Navigator.pop(context, true);
    } on AllocationRefusal catch (r) {
      if (mounted) setState(() => _error = r.message);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _stepper(CrmTheme crm, String label, int value, ValueChanged<int> onChanged, String keyName) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 13.5, color: crm.textPrimary)),
        IconButton(key: Key('${keyName}_minus'), visualDensity: VisualDensity.compact, onPressed: value > 0 ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
        Text('$value', key: Key('${keyName}_value'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        IconButton(key: Key('${keyName}_plus'), visualDensity: VisualDensity.compact, onPressed: value < 4 ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_circle_outline_rounded)),
      ]);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final people = ref.watch(teamCandidatesProvider);
    final districts = ref.watch(districtsProvider);
    final mine = widget.team?.id;
    return Material(
      key: const Key('team_edit'),
      color: crm.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
          child: Row(children: [
            Expanded(child: Text(widget.team == null ? 'New artist team' : 'Edit ${widget.team!.name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        Expanded(
          child: people.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyErrorMessage(e))),
            data: (list) {
              // a main artist: an artist who leads no other team; an assistant: anyone else not leading a team
              final leads = list.where((p) => p.artistRole == 'artist' && (p.leadsTeamId == null || p.leadsTeamId == mine)).toList();
              final helpers = list.where((p) => p.id != _lead && (p.leadsTeamId == null || p.leadsTeamId == mine)).toList();
              return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), children: [
                Text('Main artist', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: const Key('team_lead'),
                  initialValue: leads.any((p) => p.id == _lead) ? _lead : null,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, hintText: 'Choose the main artist'),
                  items: [for (final p in leads) DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setState(() {
                    _lead = v;
                    _assistants.remove(v);
                  }),
                ),
                const SizedBox(height: 16),
                Text('Assistants (they go with her to each work)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textSecondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final p in helpers)
                    FilterChip(
                      key: Key('team_asst_${p.id}'),
                      label: Text(p.assistsTeams.where((t) => t != widget.team?.name).isEmpty ? p.name : '${p.name} · also ${p.assistsTeams.where((t) => t != widget.team?.name).join(', ')}'),
                      selected: _assistants.contains(p.id),
                      onSelected: (on) => setState(() => on ? _assistants.add(p.id) : _assistants.remove(p.id)),
                    ),
                  if (helpers.isEmpty) Text('No one else is free to add.', style: TextStyle(color: crm.textSecondary)),
                ]),
                const SizedBox(height: 16),
                Text('Preferred places — a new route there goes to her first', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textSecondary)),
                const SizedBox(height: 6),
                districts.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(friendlyErrorMessage(e)),
                  data: (all) => _districtPicker(crm, all),
                ),
                const SizedBox(height: 8),
                TextField(key: const Key('team_pins'), controller: _pins, decoration: const InputDecoration(labelText: 'Pincode areas (optional, comma-separated)', hintText: '673001, 673014', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 16),
                Text('Her slots a day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textSecondary)),
                Wrap(spacing: 16, children: [
                  _stepper(crm, 'Morning', _morning, (v) => setState(() => _morning = v), 'team_morning'),
                  _stepper(crm, 'Evening', _evening, (v) => setState(() => _evening = v), 'team_evening'),
                ]),
                SwitchListTile(
                  key: const Key('team_extra'),
                  contentPadding: EdgeInsets.zero,
                  value: _extra,
                  onChanged: (v) => setState(() => _extra = v),
                  title: const Text('May take an EXTRA slot on a peak day'),
                  subtitle: const Text('Only when every slot is full and the work is on her route — the Artist Head OKs it.'),
                ),
                TextField(key: const Key('team_notes'), controller: _notes, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder(), isDense: true)),
              ]);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const Key('team_error'), style: TextStyle(color: crm.destructive, fontWeight: FontWeight.w600))),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: _saving ? null : () => Navigator.maybePop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(key: const Key('team_save'), style: FilledButton.styleFrom(backgroundColor: crm.primary), onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save team')),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _districtPicker(CrmTheme crm, List<District> all) {
    final byRegion = <String, List<District>>{};
    for (final d in all) {
      (byRegion[d.regionName.isEmpty ? 'Other' : d.regionName] ??= []).add(d);
    }
    final regions = byRegion.keys.toList()..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final r in regions)
        ExpansionTile(
          key: Key('team_region_$r'),
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: byRegion[r]!.any((d) => _districts.contains(d.id)),
          title: Text('$r${byRegion[r]!.where((d) => _districts.contains(d.id)).isEmpty ? '' : ' · ${byRegion[r]!.where((d) => _districts.contains(d.id)).length} chosen'}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: Key('team_whole_region_$r'),
                onPressed: () => setState(() {
                  final ids = byRegion[r]!.map((d) => d.id);
                  ids.every(_districts.contains) ? _districts.removeAll(ids) : _districts.addAll(ids);
                }),
                child: Text(byRegion[r]!.every((d) => _districts.contains(d.id)) ? 'Clear the whole region' : 'Add the whole region'),
              ),
            ),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final d in byRegion[r]!)
                FilterChip(key: Key('team_district_${d.id}'), label: Text(d.name), selected: _districts.contains(d.id), onSelected: (on) => setState(() => on ? _districts.add(d.id) : _districts.remove(d.id))),
            ]),
            const SizedBox(height: 8),
          ],
        ),
    ]);
  }
}
