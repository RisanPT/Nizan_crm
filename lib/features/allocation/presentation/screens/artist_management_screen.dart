import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/allocation_settings_dialog.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/team_edit_dialog.dart';
import 'package:nizan_crm/features/allocation/services/allocation_service.dart';

/// ARTIST MANAGEMENT (CRM) — the in-house teams new works are shared between: each team's main artist, her assistants, her preferred
/// places, her slots, and her place in the rotation (drag to reorder). Shows each team's load on a chosen day. The Artist Head, the CRM
/// Head and managers change it; the CRM team reads it.
class ArtistManagementScreen extends ConsumerStatefulWidget {
  const ArtistManagementScreen({super.key, this.now});
  final DateTime? now;

  @override
  ConsumerState<ArtistManagementScreen> createState() => _ArtistManagementScreenState();
}

class _ArtistManagementScreenState extends ConsumerState<ArtistManagementScreen> {
  late DateTime _day = widget.now ?? DateTime.now();
  List<ArtistTeamView>? _order; // the rotation as dragged, until saved

  String get _dayIso => istDayIso(_day);

  Future<void> _reorder(List<ArtistTeamView> active, int from, int to) async {
    // (onReorderItem has already allowed for the item taken out)
    final list = [...active];
    list.insert(to, list.removeAt(from));
    setState(() => _order = list);
    try {
      await ref.read(allocationServiceProvider).reorderTeams(list.map((t) => t.id).toList());
      refreshAllocation(ref);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _order = null);
    }
  }

  Future<void> _setActive(ArtistTeamView t, bool active) async {
    try {
      final svc = ref.read(allocationServiceProvider);
      active ? await svc.updateTeam(t.id, {'active': true}) : await svc.deactivateTeam(t.id);
      refreshAllocation(ref);
    } on AllocationRefusal catch (r) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final page = ref.watch(artistTeamsProvider(_dayIso));
    final settings = ref.watch(allocationSettingsProvider);
    return Scaffold(
      backgroundColor: crm.background,
      body: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => refreshAllocation(ref)),
        data: (p) {
          final active = _order ?? p.teams.where((t) => t.active).toList();
          final inactive = p.teams.where((t) => !t.active).toList();
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
            _header(crm, p, settings.value),
            const SizedBox(height: 12),
            if (settings.value != null) _rules(crm, settings.value!),
            const SizedBox(height: 12),
            if (active.isEmpty)
              Container(
                key: const Key('am_empty'),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
                child: Column(children: [
                  Icon(Icons.groups_outlined, size: 40, color: crm.textSecondary),
                  const SizedBox(height: 8),
                  Text('No artist teams yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                  Text('Set up your in-house teams — each main artist, her assistants and where she prefers to work — to turn on suggestions.', textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
                ]),
              )
            else if (p.canManage)
              ReorderableListView(
                key: const Key('am_rotation'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (a, b) => _reorder(active, a, b),
                children: [for (final (i, t) in active.indexed) _card(crm, t, i, canManage: true, key: ValueKey(t.id))],
              )
            else
              for (final (i, t) in active.indexed) _card(crm, t, i, canManage: false, key: ValueKey(t.id)),
            if (inactive.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Not in the rotation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textSecondary)),
              const SizedBox(height: 6),
              for (final t in inactive) _card(crm, t, -1, canManage: p.canManage, key: ValueKey('off-${t.id}')),
            ],
          ]);
        },
      ),
    );
  }

  Widget _header(CrmTheme crm, TeamsPage p, AllocationSettings? s) => LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Artist Management', style: TextStyle(fontSize: wide ? 28 : 22, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          Text('The in-house teams new works are shared between — top to bottom is the rotation.', style: TextStyle(fontSize: 13, color: crm.textSecondary)),
        ]);
        final actions = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(
            key: const Key('am_day'),
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2024), lastDate: DateTime(2100));
              if (picked != null) setState(() => _day = picked);
            },
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text('Load on ${DateFormat('EEE, d MMM').format(_day)}'),
          ),
          if (s?.canEdit ?? false) OutlinedButton.icon(key: const Key('am_settings'), onPressed: () => showAllocationSettingsDialog(context, s!), icon: const Icon(Icons.tune_rounded, size: 18), label: const Text('Rules')),
          if (p.canManage) FilledButton.icon(key: const Key('am_add'), style: FilledButton.styleFrom(backgroundColor: crm.primary), onPressed: () => showTeamEditDialog(context), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add team')),
        ]);
        return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), actions]) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 10), actions]);
      });

  Widget _rules(CrmTheme crm, AllocationSettings s) {
    final (label, color) = switch (s.mode) { 'suggest' => ('On', crm.success), 'shadow' => ('On trial', crm.warning), _ => ('Off', crm.textSecondary) };
    return Container(
      key: const Key('am_rules'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Text('Suggestions: $label', key: const Key('am_mode'), style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 12.5))),
        Text('Evening from ${fmtHHMM(s.eveningCutoff)}', style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
        Text('Same area = ≤ ${s.travelLimitMin} min drive', style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
        Text('${s.extrasPerDay} extra slots a day (Artist Head OKs)', style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
        if (s.guardOn) Text('Clash check on', style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
      ]),
    );
  }

  Widget _chip(CrmTheme crm, String text, {IconData? icon, Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: (color ?? crm.textSecondary).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color ?? crm.textSecondary), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? crm.textPrimary)),
        ]),
      );

  Widget _card(CrmTheme crm, ArtistTeamView t, int index, {required bool canManage, required Key key}) {
    final load = t.load;
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        key: Key('am_team_${t.id}'),
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (index >= 0)
              CircleAvatar(radius: 16, backgroundColor: crm.primary.withValues(alpha: 0.12), child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(t.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: t.active ? crm.textPrimary : crm.textSecondary))),
                  if (canManage) IconButton(key: Key('am_edit_${t.id}'), tooltip: 'Edit', onPressed: () => showTeamEditDialog(context, team: t), icon: const Icon(Icons.edit_outlined, size: 19)),
                  if (canManage)
                    PopupMenuButton<String>(
                      key: Key('am_menu_${t.id}'),
                      onSelected: (v) => _setActive(t, v == 'on'),
                      itemBuilder: (_) => [t.active ? const PopupMenuItem(value: 'off', child: Text('Take off the rotation')) : const PopupMenuItem(value: 'on', child: Text('Put back in the rotation'))],
                    ),
                  if (canManage && index >= 0) ReorderableDragStartListener(index: index, child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.drag_indicator_rounded, color: crm.textSecondary))),
                ]),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip(crm, t.lead.name, icon: Icons.star_rounded, color: crm.primary),
                  for (final a in t.assistants) _chip(crm, a.name, icon: Icons.person_outline_rounded),
                  _chip(crm, '${t.morningSlots} morning + ${t.eveningSlots} evening', icon: Icons.event_seat_outlined),
                  if (!t.extraAllowed) _chip(crm, 'No extras', icon: Icons.block_rounded),
                ]),
                if (t.preferredDistricts.isNotEmpty || t.preferredPincodes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final d in t.preferredDistricts) _chip(crm, d.name, icon: Icons.place_outlined, color: crm.success),
                      for (final p in t.preferredPincodes) _chip(crm, p, icon: Icons.pin_drop_outlined, color: crm.success),
                    ]),
                  ),
                if (load != null && t.active)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      load.onLeave
                          ? 'On leave on ${DateFormat('d MMM').format(_day)}'
                          : [
                              '${load.used}/${load.of} booked',
                              if (load.jobs.isNotEmpty) load.jobs.map((j) => '${fmtHHMM(j.start)}${j.label.isEmpty ? '' : ' ${j.label}'}').join(', '),
                              if (load.freeFromText.isNotEmpty) load.freeFromText,
                              if (load.halfLeave) 'half-day leave',
                            ].join(' · '),
                      key: Key('am_load_${t.id}'),
                      style: TextStyle(fontSize: 12.5, color: load.onLeave ? crm.warning : crm.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                for (final w in t.warnings) Padding(padding: const EdgeInsets.only(top: 4), child: Text(w, style: TextStyle(fontSize: 12, color: crm.warning))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
