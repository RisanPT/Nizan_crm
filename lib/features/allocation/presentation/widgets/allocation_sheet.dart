import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/artist_conflict_dialog.dart';
import 'package:nizan_crm/features/allocation/services/allocation_service.dart';

// WHO TAKES THIS WORK — the smart booking allocation's sheet. The in-house teams ranked for each package of a NEW booking: the same artist
// while the venue is on her route (her clock + 30 minutes' drive), else the next free one in the rotation — each with the reason in
// plain words. The coordinator confirms (the server re-checks and holds the slot), or, in Manage Booking, picks a team for the form.

const kOverrideReasons = ['Client asked for her', 'Better route', 'Artist request', 'Other'];

/// What the coordinator chose for a package (Manage Booking fills its form with it, then saves).
class AllocationPick {
  const AllocationPick({required this.unitKey, required this.teamId, required this.teamName, required this.lead, this.assistants = const [], this.chosenRank = 1, this.topTeamId, this.tier = '', this.overrideReason = ''});
  final String unitKey, teamId, teamName, tier, overrideReason;
  final TeamPerson lead;
  final List<TeamPerson> assistants;
  final int chosenRank;
  final String? topTeamId;

  /// Sent with the booking save, so the server records the suggestion vs the choice.
  Map<String, dynamic> toIntent() => {'unitKey': unitKey, 'teamId': teamId, 'chosenRank': chosenRank, 'topTeamId': ?topTeamId, 'tier': tier, 'overrideReason': overrideReason};
}

/// The sheet for [bookingId]: confirm mode. [beforeConfirm] runs first (Booking Requests: the status change); false stops. [secondaryLabel]
/// + [onSecondary]: the other way out ("Confirm without artist", "Later"). → true allocated, false the secondary way, null closed.
Future<bool?> showAllocationSheet(
  BuildContext context, {
  required String bookingId,
  String source = 'requests',
  String primaryLabel = 'Allocate',
  String? secondaryLabel,
  Future<bool> Function()? beforeConfirm,
  Future<void> Function()? onSecondary,
}) {
  final body = AllocationSheet(bookingId: bookingId, source: source, primaryLabel: primaryLabel, secondaryLabel: secondaryLabel, beforeConfirm: beforeConfirm, onSecondary: onSecondary);
  return _present<bool>(context, body);
}

/// Pick mode (Manage Booking): the teams for one package; → the coordinator's pick, or null.
Future<AllocationPick?> pickTeamFor(BuildContext context, {required String bookingId, required String unitKey}) =>
    _present<AllocationPick>(context, AllocationSheet(bookingId: bookingId, unitKey: unitKey, pickMode: true, primaryLabel: 'Use this team'));

Future<T?> _present<T>(BuildContext context, Widget body) {
  if (MediaQuery.sizeOf(context).width >= 760) {
    return showDialog<T>(context: context, builder: (_) => Dialog(clipBehavior: Clip.antiAlias, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 760, maxHeight: MediaQuery.sizeOf(context).height * 0.9), child: body)));
  }
  return showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: body));
}

class AllocationSheet extends ConsumerStatefulWidget {
  const AllocationSheet({super.key, required this.bookingId, this.unitKey, this.pickMode = false, this.source = 'requests', this.primaryLabel = 'Allocate', this.secondaryLabel, this.beforeConfirm, this.onSecondary});
  final String bookingId;
  final String? unitKey;
  final bool pickMode;
  final String source, primaryLabel;
  final String? secondaryLabel;
  final Future<bool> Function()? beforeConfirm;
  final Future<void> Function()? onSecondary;

  @override
  ConsumerState<AllocationSheet> createState() => _AllocationSheetState();
}

class _AllocationSheetState extends ConsumerState<AllocationSheet> {
  final _selected = <String, String>{}; // unitKey → teamId
  final _dropped = <String, Set<String>>{}; // unitKey → assistant ids taken off
  final _reason = <String, String>{}; // unitKey → override reason
  final _showAll = <String>{};
  bool _seeded = false;
  bool _busy = false;
  bool _statusDone = false;
  String? _error;

  void _seed(BookingAllocation a) {
    if (_seeded) return;
    _seeded = true;
    for (final u in _units(a)) {
      final top = u.recommended;
      if (top != null) _selected[u.unitKey] = top.teamId;
    }
  }

  List<AllocUnit> _units(BookingAllocation a) => widget.unitKey == null ? a.units : a.units.where((u) => u.unitKey == widget.unitKey).toList();

  Future<void> _secondary() async {
    setState(() => _busy = true);
    try {
      await widget.onSecondary?.call();
      if (mounted) Navigator.pop(context, false);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  AllocCandidate? _cand(AllocUnit u) => u.candidates.where((c) => c.teamId == _selected[u.unitKey]).firstOrNull;

  Future<void> _confirm(BookingAllocation a, {bool confirmConflicts = false}) async {
    final units = _units(a).where((u) => _selected[u.unitKey] != null).toList();
    if (units.isEmpty) return;
    for (final u in units) {
      final c = _cand(u)!;
      if (!c.recommended && (_reason[u.unitKey] ?? '').isEmpty) {
        setState(() => _error = 'Say why ${c.teamName} rather than the suggestion — pick a reason.');
        return;
      }
    }
    if (widget.pickMode) {
      final u = units.first;
      final c = _cand(u)!;
      Navigator.pop(
        context,
        AllocationPick(unitKey: u.unitKey, teamId: c.teamId, teamName: c.teamName, lead: c.lead ?? TeamPerson(id: '', name: c.teamName), assistants: c.assistants.where((x) => !(_dropped[u.unitKey]?.contains(x.id) ?? false)).toList(), chosenRank: c.rank, topTeamId: u.recommended?.teamId, tier: c.tier, overrideReason: c.recommended ? '' : _reason[u.unitKey] ?? ''),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.beforeConfirm != null && !_statusDone) {
        if (!await widget.beforeConfirm!()) return;
        _statusDone = true;
      }
      final picks = [
        for (final u in units)
          {
            'unitKey': u.unitKey,
            'teamId': _selected[u.unitKey],
            'assistantIds': [for (final x in _cand(u)!.assistants) if (!(_dropped[u.unitKey]?.contains(x.id) ?? false)) x.id],
            if (!_cand(u)!.recommended) 'overrideReason': _reason[u.unitKey],
          },
      ];
      final res = await ref.read(allocationServiceProvider).confirm(bookingId: widget.bookingId, updatedAt: widget.beforeConfirm == null ? a.updatedAt : null, picks: picks, source: widget.source, confirmConflicts: confirmConflicts);
      refreshAllocation(ref);
      if (!mounted) return;
      final results = (res['results'] as List? ?? const []).cast<Map>();
      final waiting = results.any((r) => r['pending'] == true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(waiting ? 'Asked the Artist Head to OK the extra slot — the team is put on once she agrees.' : 'Allocated · ${results.map((r) => r['teamName']).toSet().join(', ')}')));
      Navigator.pop(context, true);
    } on AllocationRefusal catch (r) {
      if (!mounted) return;
      if (r.isConflict && !confirmConflicts) {
        setState(() => _busy = false);
        if (await showArtistConflictDialog(context, r) && mounted) await _confirm(a, confirmConflicts: true);
        return;
      }
      // a slot just taken, the booking just changed: read the suggestions again
      setState(() {
        _error = r.message;
        _seeded = false;
        _selected.clear();
      });
      ref.invalidate(bookingAllocationProvider(widget.bookingId));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(bookingAllocationProvider(widget.bookingId));
    return Material(
      key: const Key('alloc_sheet'),
      color: crm.surface,
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => _frame(crm, title: 'Who takes this work?', body: Padding(padding: const EdgeInsets.all(20), child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary))), footer: _closeOnly(crm)),
        data: (a) {
          final ready = a.mode == 'suggest' && a.eligible && (a.canConfirm || widget.pickMode);
          if (!ready) {
            return _frame(
              crm,
              title: 'Who takes this work?',
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(a.message.isNotEmpty ? a.message : a.mode == 'shadow' ? 'The allocation is on trial — it only notes what it would suggest.' : 'You can\'t allocate artists here.', key: const Key('alloc_not_ready'), style: TextStyle(fontSize: 14, color: crm.textSecondary)),
              ),
              footer: _footer(crm, a, ready: false),
            );
          }
          _seed(a);
          final units = _units(a);
          return _frame(
            crm,
            title: 'Who takes ${a.bookingNumber.isEmpty ? 'this work' : '#${a.bookingNumber}'}${a.customerName.isEmpty ? '' : ' · ${a.customerName}'}?',
            subtitle: 'Ranked by her route: the same artist while the venue is close, else the next free one in the rotation.',
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              children: [for (final u in units) _unit(crm, u)],
            ),
            footer: _footer(crm, a, ready: true),
          );
        },
      ),
    );
  }

  Widget _frame(CrmTheme crm, {required String title, String? subtitle, required Widget body, required Widget footer}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, key: const Key('alloc_title'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
              ]),
            ),
            IconButton(key: const Key('alloc_close'), tooltip: 'Close', onPressed: _busy ? null : () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        Flexible(child: body),
        footer,
      ]);

  Widget _closeOnly(CrmTheme crm) => Padding(padding: const EdgeInsets.all(12), child: Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.maybePop(context), child: const Text('Close'))));

  Widget _footer(CrmTheme crm, BookingAllocation a, {required bool ready}) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const Key('alloc_error'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.destructive))),
          Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
            if (widget.secondaryLabel != null) OutlinedButton(key: const Key('alloc_secondary'), onPressed: _busy ? null : _secondary, child: Text(widget.secondaryLabel!)),
            if (ready)
              FilledButton(
                key: const Key('alloc_confirm'),
                style: FilledButton.styleFrom(backgroundColor: crm.primary),
                onPressed: _busy || _selected.isEmpty ? null : () => _confirm(a),
                child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.primaryLabel),
              ),
          ]),
        ]),
      );

  String _dayLine(AllocUnitDay d) => '${_day(d.day)} · ${fmtHHMM(d.start)}–${fmtHHMM(d.end)}${d.placeLabel.isEmpty ? '' : ' · ${d.placeLabel}'}';
  String _day(String iso) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${int.tryParse(p[2]) ?? p[2]} ${months[(int.tryParse(p[1]) ?? 1) - 1]}';
  }

  Widget _unit(CrmTheme crm, AllocUnit u) {
    final shown = _showAll.contains(u.unitKey) ? u.candidates : u.candidates.where((c) => !c.blocked).take(4).toList();
    final hidden = u.candidates.length - shown.length;
    final chosen = _cand(u);
    return Container(
      key: Key('alloc_unit_${u.unitKey}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(u.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        for (final d in u.days) Text(_dayLine(d), style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        if (u.currentLead.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Now: ${u.currentLead}${u.slotKey.isEmpty ? '' : ' (slot ${u.slotKey})'}', style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w600))),
        if (u.days.any((d) => !d.timeSet)) _note(crm, Icons.schedule_rounded, 'Start time not set — the ERP assumed one. Add the time for a sharper suggestion.', key: Key('alloc_time_not_set_${u.unitKey}')),
        if (u.days.any((d) => d.precision == 'unknown')) _note(crm, Icons.location_off_outlined, 'The venue can\'t be placed (no map pin or pincode) — "same area" can\'t be checked.', key: Key('alloc_no_place_${u.unitKey}')),
        const SizedBox(height: 8),
        if (u.candidates.every((c) => c.blocked)) _note(crm, Icons.block_rounded, 'No team is free for this work — every slot is taken or clashes.', key: Key('alloc_none_${u.unitKey}')),
        for (final c in shown) _candidate(crm, u, c),
        if (hidden > 0 || _showAll.contains(u.unitKey))
          TextButton(
            key: Key('alloc_show_all_${u.unitKey}'),
            onPressed: () => setState(() => _showAll.contains(u.unitKey) ? _showAll.remove(u.unitKey) : _showAll.add(u.unitKey)),
            child: Text(_showAll.contains(u.unitKey) ? 'Show fewer' : 'Show every team ($hidden more)'),
          ),
        if (chosen != null && chosen.assistants.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Assistants with ${chosen.lead?.name ?? chosen.teamName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in chosen.assistants)
              FilterChip(
                key: Key('alloc_asst_${a.id}'),
                label: Text(a.name),
                selected: !(_dropped[u.unitKey]?.contains(a.id) ?? false),
                onSelected: (on) => setState(() => on ? _dropped[u.unitKey]?.remove(a.id) : (_dropped[u.unitKey] ??= {}).add(a.id)),
              ),
          ]),
        ],
        if (chosen != null && !chosen.recommended) ...[
          const SizedBox(height: 8),
          Text('Why ${chosen.teamName} rather than the suggestion?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (i, r) in kOverrideReasons.indexed)
              ChoiceChip(key: Key('alloc_reason_$i'), label: Text(r), selected: _reason[u.unitKey] == r, onSelected: (_) => setState(() => _reason[u.unitKey] = r)),
          ]),
        ],
      ]),
    );
  }

  Widget _note(CrmTheme crm, IconData icon, String text, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: crm.warning),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: crm.textPrimary))),
        ]),
      );

  ({String label, Color color}) _tier(CrmTheme crm, String tier) => switch (tier) {
        'continue' => (label: 'Same route', color: crm.success),
        'new_route' => (label: 'New route', color: crm.primary),
        'far' => (label: 'Far', color: crm.warning),
        'extra' => (label: 'EXTRA slot', color: crm.warning),
        _ => (label: 'Not free', color: crm.textSecondary),
      };

  Widget _candidate(CrmTheme crm, AllocUnit u, AllocCandidate c) {
    final selected = _selected[u.unitKey] == c.teamId;
    final t = _tier(crm, c.tier);
    final slot = c.slots.isEmpty ? null : c.slots.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? crm.primary.withValues(alpha: 0.07) : crm.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('alloc_cand_${u.unitKey}_${c.teamId}'),
          borderRadius: BorderRadius.circular(12),
          onTap: c.blocked || _busy ? null : () => setState(() => _selected[u.unitKey] = c.teamId),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? crm.primary : crm.border, width: selected ? 1.6 : 1)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: c.blocked ? crm.border : selected ? crm.primary : crm.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(c.teamName, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.blocked ? crm.textSecondary : crm.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: t.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(t.label, key: Key('alloc_tier_${c.teamId}'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.color)),
                    ),
                    if (c.recommended) Text('Suggested', key: Key('alloc_suggested_${c.teamId}'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.primary)),
                    if (slot != null && slot.of != null && !c.blocked) Text('${slot.half == 'morning' ? 'Morning' : 'Evening'} ${slot.used ?? 0}/${slot.of}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  ]),
                  const SizedBox(height: 2),
                  Text(c.reason, key: Key('alloc_reason_text_${c.teamId}'), style: TextStyle(fontSize: 12.5, color: c.blocked ? crm.textSecondary : crm.textPrimary)),
                  for (final d in c.details) Text(d, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  for (final w in c.warnings) Text(w, style: TextStyle(fontSize: 11.5, color: crm.warning)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
