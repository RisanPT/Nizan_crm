import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/rupees.dart';
import 'package:nizan_crm/features/it/data/manpower.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/manpower_widgets.dart';
import 'package:nizan_crm/features/it/services/manpower_service.dart';

/// "Manpower": the requests projects have made for more people, and what is done about them.
///
///  * HR sees all of them: covers the seats (a person on staff, a new hire or a contractor), places a new hire once they have
///    joined, or declines with a reason.
///  * The head of a department answers the lines that ask to borrow one of their people: let them go, or say no and why.
///  * Whoever asked, the project manager and the owning head see theirs, and may take one back before anyone is placed.
///
/// The server decides who sees what and who may do what; this shows the buttons it allows.
class ManpowerScreen extends ConsumerStatefulWidget {
  const ManpowerScreen({super.key});

  @override
  ConsumerState<ManpowerScreen> createState() => _ManpowerScreenState();
}

class _ManpowerScreenState extends ConsumerState<ManpowerScreen> {
  bool _open = true;

  void _reload([ManpowerRequest? r]) {
    ref.invalidate(manpowerRequestsProvider(null));
    if (r != null) {
      ref.invalidate(manpowerRequestsProvider(r.projectId));
      ref.invalidate(projectTeamProvider(r.projectId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(manpowerRequestsProvider(null));
    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(manpowerRequestsProvider(null)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.groups_2_outlined, color: crm.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manpower', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.4)),
                      Text('Projects asking for more people — and how HR is covering them.', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(manpowerRequestsProvider(null))),
              data: (all) {
                final open = all.where((r) => r.isOpen).toList();
                final done = all.where((r) => !r.isOpen).toList();
                final shown = _open ? open : done;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<bool>(
                      key: const Key('mp_tabs'),
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: true, label: Text('Open (${open.length})', key: const Key('mp_tab_open'))),
                        ButtonSegment(value: false, label: Text('Done (${done.length})', key: const Key('mp_tab_done'))),
                      ],
                      selected: {_open},
                      onSelectionChanged: (v) => setState(() => _open = v.first),
                    ),
                    const SizedBox(height: 14),
                    if (shown.isEmpty)
                      Container(
                        key: const Key('mp_empty'),
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_outlined, size: 32, color: crm.textSecondary.withValues(alpha: 0.6)),
                            const SizedBox(height: 8),
                            Text(_open ? 'No requests are waiting.' : 'Nothing has been closed yet.', style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
                          ],
                        ),
                      )
                    else
                      for (final r in shown) ...[_RequestCard(request: r, onChanged: () => _reload(r)), const SizedBox(height: 12)],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── one request ──────────────────────────────────────────────────────────────

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.onChanged});
  final ManpowerRequest request;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final r = request;
    final meta = [
      if (r.department.isNotEmpty) r.department,
      if (r.requestedByName.isNotEmpty) 'asked by ${r.requestedByName}',
      if (r.requestedAt != null) manpowerDay(r.requestedAt),
    ].join(' · ');
    final staffed = r.lines.any((l) => const {'assigned', 'hiring', 'awaiting_release'}.contains(l.state));

    return Container(
      key: Key('mp_card_${r.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: r.isUrgent && r.isOpen ? const Color(0xFFB91C1C).withValues(alpha: 0.5) : crm.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: r.projectId.isEmpty ? null : () => context.go('/projects/${r.projectId}'),
                      child: Text(r.projectName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(r.what, key: Key('mp_what_${r.id}'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.primary)),
                    ),
                    if (meta.isNotEmpty) Text(meta, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ManpowerStatusPill(r.status),
                  if (r.isUrgent && r.isOpen)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Urgent', key: Key('mp_urgent_${r.id}'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C))),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            [manpowerSpan(r.startDate, r.endDate), '${r.allocationPercent}% of their time', if (r.estimatedCost > 0) 'about ${rupees(r.estimatedCost)}'].where((s) => s.isNotEmpty).join(' · '),
            style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
          ),
          if (r.skills.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Skills: ${r.skills}', style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          if (r.reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.reason, style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: crm.textSecondary))),
          if (r.lines.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final l in r.lines) _LineRow(request: r, line: l, onChanged: onChanged),
          ],
          if (r.isOpen) ...[
            const SizedBox(height: 4),
            Text(
              r.seatsLeft == 0 ? 'Every seat is covered' : '${r.seatsLeft} ${r.seatsLeft == 1 ? 'seat' : 'seats'} still to cover',
              key: Key('mp_left_${r.id}'),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
            ),
          ],
          if (r.decisionNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                key: Key('mp_note_${r.id}'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(8)),
                child: Text(r.decisionNote, style: const TextStyle(fontSize: 12.5)),
              ),
            ),
          if (r.isOpen && (r.access.canHandle || r.access.canCancel)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r.access.canHandle && r.seatsLeft > 0)
                  FilledButton.icon(
                    key: Key('mp_cover_${r.id}'),
                    onPressed: () async {
                      final done = await showCoverSeatsSheet(context, ref, r);
                      if (done) onChanged();
                    },
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                    label: const Text('Cover seats'),
                  ),
                if (r.access.canHandle && !staffed)
                  OutlinedButton(
                    key: Key('mp_decline_${r.id}'),
                    onPressed: () async {
                      if (await _declineDialog(context, ref, r)) onChanged();
                    },
                    child: const Text('Decline'),
                  ),
                if (r.access.canCancel)
                  TextButton(
                    key: Key('mp_cancel_${r.id}'),
                    onPressed: () async {
                      if (await _cancelDialog(context, ref, r)) onChanged();
                    },
                    child: const Text('Take it back'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LineRow extends ConsumerWidget {
  const _LineRow({required this.request, required this.line, required this.onChanged});
  final ManpowerRequest request;
  final ManpowerLine line;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final l = line;
    final stateColor = switch (l.state) {
      'assigned' => const Color(0xFF15803D),
      'refused' => const Color(0xFFB91C1C),
      _ => const Color(0xFFB45309),
    };
    final mine = request.access.releasable.contains(l.id) && l.state == 'awaiting_release';
    final detail = [
      if (l.type == 'internal' && l.employeeDept.isNotEmpty) l.employeeDept,
      if (l.type == 'internal' && l.percent > 0) '${l.percent}% of their time',
      if (l.type == 'internal') manpowerSpan(l.from, l.to),
      if (l.type != 'internal' && l.seats > 1) '${l.seats} seats',
      if (l.type != 'internal' && l.cost > 0) rupees(l.cost),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      key: Key('mp_line_${l.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                    if (detail.isNotEmpty) Text(detail, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(manpowerLineLabel(l), key: Key('mp_line_state_${l.id}'), textAlign: TextAlign.end, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: stateColor)),
              ),
            ],
          ),
          if (l.releaseNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('“${l.releaseNote}”', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: crm.textSecondary))),
          if (mine) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton(
                  key: Key('mp_release_yes_${l.id}'),
                  onPressed: () async {
                    if (await _releaseYes(context, ref, request, l)) onChanged();
                  },
                  child: const Text('Let them go'),
                ),
                OutlinedButton(
                  key: Key('mp_release_no_${l.id}'),
                  onPressed: () async {
                    if (await _releaseNo(context, ref, request, l)) onChanged();
                  },
                  child: const Text('Not now'),
                ),
              ],
            ),
          ],
          if (l.type == 'hire' && l.state == 'hiring' && request.access.canHandle) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: Key('mp_joined_${l.id}'),
              onPressed: () async {
                if (await showAllocateHireSheet(context, ref, request, l)) onChanged();
              },
              icon: const Icon(Icons.how_to_reg_outlined, size: 16),
              label: const Text('Someone joined'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── answers: release, decline, take back ─────────────────────────────────────

Future<bool> _releaseYes(BuildContext context, WidgetRef ref, ManpowerRequest r, ManpowerLine l) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(manpowerServiceProvider).release(r.id, l.id, approve: true);
    messenger.showSnackBar(SnackBar(content: Text('${l.employeeName} can join ${r.projectName}')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    return false;
  }
}

Future<bool> _releaseNo(BuildContext context, WidgetRef ref, ManpowerRequest r, ManpowerLine l) async {
  final note = await _askReason(
    context,
    title: 'Why can ${l.employeeName.isEmpty ? 'they' : l.employeeName} not go?',
    hint: 'HR will look for someone else',
    fieldKey: 'mp_release_reason',
    confirmKey: 'mp_release_confirm',
    confirmLabel: 'Say no',
  );
  if (note == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(manpowerServiceProvider).release(r.id, l.id, approve: false, note: note);
    messenger.showSnackBar(const SnackBar(content: Text('HR has been told — the seat is open again')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    return false;
  }
}

Future<bool> _declineDialog(BuildContext context, WidgetRef ref, ManpowerRequest r) async {
  final note = await _askReason(
    context,
    title: 'Why can HR not cover this?',
    hint: 'The project manager is told',
    fieldKey: 'mp_decline_reason',
    confirmKey: 'mp_decline_confirm',
    confirmLabel: 'Decline',
  );
  if (note == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(manpowerServiceProvider).decline(r.id, note);
    messenger.showSnackBar(const SnackBar(content: Text('Request declined')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    return false;
  }
}

Future<bool> _cancelDialog(BuildContext context, WidgetRef ref, ManpowerRequest r) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('mp_cancel_dialog'),
      title: const Text('Take this request back?'),
      content: Text('HR will no longer look for ${r.what} for ${r.projectName}.'),
      actions: [
        TextButton(key: const Key('mp_cancel_keep'), onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
        FilledButton(key: const Key('mp_cancel_confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Take it back')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(manpowerServiceProvider).cancel(r.id);
    messenger.showSnackBar(const SnackBar(content: Text('Request taken back')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    return false;
  }
}

/// Asks for a short reason (at least three letters). Null when cancelled.
Future<String?> _askReason(BuildContext context, {required String title, required String hint, required String fieldKey, required String confirmKey, required String confirmLabel}) {
  final c = TextEditingController();
  var tooShort = false;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: TextField(
            key: Key(fieldKey),
            controller: c,
            maxLines: 2,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Reason *', hintText: hint, errorText: tooShort ? 'Say why' : null),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            key: Key(confirmKey),
            onPressed: () {
              if (c.text.trim().length < 3) {
                setD(() => tooShort = true);
                return;
              }
              Navigator.pop(ctx, c.text.trim());
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
}

// ── covering seats ───────────────────────────────────────────────────────────

/// What the server asked back, put to HR: a person who is busy (go ahead anyway?) or a cost that does not fit the budget.
/// Returns true when HR says to go ahead anyway.
Future<bool> _askAboutRefusal(BuildContext context, ManpowerRefusal refusal) async {
  if (refusal.needsBudget) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('mp_budget_dialog'),
        title: const Text('Not enough budget'),
        content: Text(refusal.message),
        actions: [TextButton(key: const Key('mp_budget_ok'), onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    return false;
  }
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('mp_conflict_dialog'),
      title: Text(refusal.onLeave ? 'On leave then' : 'Already busy then'),
      content: Text(refusal.message),
      actions: [
        TextButton(key: const Key('mp_conflict_no'), onPressed: () => Navigator.pop(ctx, false), child: const Text('Choose someone else')),
        FilledButton(key: const Key('mp_conflict_yes'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Assign anyway')),
      ],
    ),
  );
  return go == true;
}

/// The stored day as a plain local date (the same year, month and day), for the staff search.
DateTime? _localDay(DateTime? d) => d == null ? null : DateTime(d.year, d.month, d.day);

/// HR covers the open seats of [r]. True once something was saved.
Future<bool> showCoverSeatsSheet(BuildContext context, WidgetRef ref, ManpowerRequest r) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _CoverSheet(request: r),
  );
  return done == true;
}

/// HR puts a new hire who has joined onto the project. True once placed.
Future<bool> showAllocateHireSheet(BuildContext context, WidgetRef ref, ManpowerRequest r, ManpowerLine line) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AllocateSheet(request: r, line: line),
  );
  return done == true;
}

/// The staff, with how much of their time is taken in the window — free ones first — to choose from. [selected] holds the
/// chosen ids; at most [maxPick] of them.
class _PersonPicker extends ConsumerStatefulWidget {
  const _PersonPicker({required this.request, required this.selected, required this.maxPick, required this.onChanged});
  final ManpowerRequest request;
  final Set<String> selected;
  final int maxPick;
  final ValueChanged<Set<String>> onChanged;

  @override
  ConsumerState<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends ConsumerState<_PersonPicker> {
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = widget.request;
    final query = AvailabilityQuery(from: _localDay(r.startDate), to: _localDay(r.endDate), percent: r.allocationPercent, search: _search);
    final async = ref.watch(manpowerAvailabilityProvider(query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('mp_search'),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search the staff by name', isDense: true),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _search = v);
            });
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Shown for ${manpowerSpan(r.startDate, r.endDate)} at ${r.allocationPercent}% of their time',
          style: TextStyle(fontSize: 12, color: crm.textSecondary),
        ),
        const SizedBox(height: 8),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(manpowerAvailabilityProvider(query))),
          data: (people) => people.isEmpty
              ? Padding(padding: const EdgeInsets.all(16), child: Text('Nobody matches.', key: const Key('mp_nobody'), style: TextStyle(color: crm.textSecondary)))
              : Column(
                  children: [
                    for (final p in people)
                      CheckboxListTile(
                        key: Key('mp_person_${p.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: widget.selected.contains(p.id),
                        onChanged: (v) {
                          final next = {...widget.selected};
                          if (v == true) {
                            if (widget.maxPick == 1) next.clear();
                            if (next.length < widget.maxPick) next.add(p.id);
                          } else {
                            next.remove(p.id);
                          }
                          widget.onChanged(next);
                        },
                        title: Row(
                          children: [
                            Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                            const SizedBox(width: 8),
                            ManpowerLevelChip(p.level),
                          ],
                        ),
                        subtitle: Text(
                          [if (p.department.isNotEmpty) p.department, if (p.role.isNotEmpty) p.role, p.loadLabel, if (p.openTasks > 0) '${p.openTasks} open tasks'].join(' · '),
                          style: TextStyle(fontSize: 12, color: crm.textSecondary),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CoverSheet extends ConsumerStatefulWidget {
  const _CoverSheet({required this.request});
  final ManpowerRequest request;

  @override
  ConsumerState<_CoverSheet> createState() => _CoverSheetState();
}

class _CoverSheetState extends ConsumerState<_CoverSheet> {
  String _type = 'internal';
  Set<String> _picked = {};
  int _seats = 1;
  final _vendor = TextEditingController();
  final _cost = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _vendor.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _submit({bool anyway = false}) async {
    final r = widget.request;
    final List<ManpowerChoice> choices;
    if (_type == 'internal') {
      if (_picked.isEmpty) {
        setState(() => _error = 'Choose who to put on the project.');
        return;
      }
      choices = [for (final id in _picked) ManpowerChoice.person(id)];
    } else {
      final cost = parseAmount(_cost.text);
      if (_cost.text.trim().isNotEmpty && cost == null) {
        setState(() => _error = 'The cost must be a number.');
        return;
      }
      if (_type == 'contract' && _vendor.text.trim().length < 2) {
        setState(() => _error = 'Say who the contractor is.');
        return;
      }
      choices = [_type == 'hire' ? ManpowerChoice.hire(seats: _seats, cost: cost) : ManpowerChoice.contractor(vendorName: _vendor.text.trim(), seats: _seats, cost: cost)];
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(manpowerServiceProvider).handle(r.id, choices, assignAnyway: anyway);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final refusal = ManpowerRefusal.of(e);
      if (refusal == null) {
        setState(() => _error = friendlyErrorMessage(e));
        return;
      }
      final go = await _askAboutRefusal(context, refusal);
      if (go && mounted) await _submit(anyway: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = widget.request;
    final left = r.seatsLeft;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cover ${r.what}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            Text('${r.projectName} · $left ${left == 1 ? 'seat' : 'seats'} to cover', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              key: const Key('mp_cover_type'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'internal', label: Text('On staff'), icon: Icon(Icons.badge_outlined, size: 16)),
                ButtonSegment(value: 'hire', label: Text('New hire'), icon: Icon(Icons.person_add_outlined, size: 16)),
                ButtonSegment(value: 'contract', label: Text('Contractor'), icon: Icon(Icons.handshake_outlined, size: 16)),
              ],
              selected: {_type},
              onSelectionChanged: _busy ? null : (v) => setState(() {
                _type = v.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            if (_type == 'internal') ...[
              _PersonPicker(request: r, selected: _picked, maxPick: left, onChanged: (s) => setState(() => _picked = s)),
              if (_picked.length >= left && left > 0)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('That fills every seat.', style: TextStyle(fontSize: 12, color: crm.textSecondary))),
            ] else ...[
              if (_type == 'contract')
                TextField(key: const Key('mp_vendor'), controller: _vendor, decoration: const InputDecoration(labelText: 'Contractor or agency *')),
              if (_type == 'hire')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('A hiring plan is raised for ${r.department.isEmpty ? 'the department' : r.department}. Place the person here once they have joined.', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                ),
              Row(
                children: [
                  const Expanded(child: Text('Seats this covers', style: TextStyle(fontSize: 13.5))),
                  IconButton(key: const Key('mp_seats_less'), onPressed: _busy || _seats <= 1 ? null : () => setState(() => _seats -= 1), icon: const Icon(Icons.remove_circle_outline)),
                  SizedBox(width: 28, child: Text('$_seats', key: const Key('mp_seats'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(key: const Key('mp_seats_more'), onPressed: _busy || _seats >= left ? null : () => setState(() => _seats += 1), icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
              TextField(
                key: const Key('mp_cover_cost'),
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(labelText: 'What it costs the project (₹, optional)', prefixText: '₹ ', helperText: 'Has to fit what is left of the approved budget', helperMaxLines: 2),
              ),
            ],
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('mp_cover_error'), style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600))),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(key: const Key('mp_cover_cancel'), onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(key: const Key('mp_cover_submit'), onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving…' : 'Confirm')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocateSheet extends ConsumerStatefulWidget {
  const _AllocateSheet({required this.request, required this.line});
  final ManpowerRequest request;
  final ManpowerLine line;

  @override
  ConsumerState<_AllocateSheet> createState() => _AllocateSheetState();
}

class _AllocateSheetState extends ConsumerState<_AllocateSheet> {
  Set<String> _picked = {};
  bool _busy = false;
  String? _error;

  Future<void> _submit({bool anyway = false}) async {
    if (_picked.isEmpty) {
      setState(() => _error = 'Choose who joined.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(manpowerServiceProvider).allocateHire(widget.request.id, widget.line.id, _picked.first, assignAnyway: anyway);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final refusal = ManpowerRefusal.of(e);
      if (refusal == null) {
        setState(() => _error = friendlyErrorMessage(e));
        return;
      }
      final go = await _askAboutRefusal(context, refusal);
      if (go && mounted) await _submit(anyway: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final r = widget.request;
    final remaining = widget.line.seats - widget.line.filled;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Who joined?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            Text('${r.roleTitle} for ${r.projectName} · $remaining still to join', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            const SizedBox(height: 12),
            _PersonPicker(request: r, selected: _picked, maxPick: 1, onChanged: (s) => setState(() => _picked = s)),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('mp_allocate_error'), style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600))),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(key: const Key('mp_allocate_cancel'), onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(key: const Key('mp_allocate_submit'), onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving…' : 'Put on the project')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
