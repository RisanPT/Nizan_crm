import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/allocation_sheet.dart';
import 'package:nizan_crm/features/allocation/services/allocation_service.dart';

/// THE ALLOCATION BOARD — one day: four cards (slots booked, extras, new works to allocate, extras waiting) with the week's line; each
/// in-house team's slots (2 morning + 1 evening, and any EXTRA), every taken slot naming its client, time and place; the new works with
/// no artist yet, each with the ERP's suggestion, under the filters (place, half, within 30 minutes of a team — the deck's "Method B");
/// the extras waiting for the Artist Head.
class AllocationBoardScreen extends ConsumerStatefulWidget {
  const AllocationBoardScreen({super.key, this.initialDay, this.now});
  final String? initialDay;
  final DateTime? now;

  @override
  ConsumerState<AllocationBoardScreen> createState() => _AllocationBoardScreenState();
}

const _evening = Color(0xFF7C4DFF);
const _gold = Color(0xFFD99A06);
const _teal = Color(0xFF16A37F);

class _AllocationBoardScreenState extends ConsumerState<AllocationBoardScreen> {
  late String _day = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(widget.initialDay ?? '') ? widget.initialDay! : istDayIso(widget.now ?? DateTime.now());
  String _place = ''; // a place label, '' = all
  String _half = 'all';
  String? _nearTeam;
  bool _busy = false;
  bool _queueTab = false; // a phone: Teams | To allocate
  final Set<String> _open = {}; // teams showing their day in full

  void _shift(int days) {
    final d = DateTime.parse(_day).add(Duration(days: days));
    setState(() => _day = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.parse(_day), firstDate: DateTime(2024), lastDate: DateTime(2100));
    if (picked != null) setState(() => _day = istDayIso(DateTime(picked.year, picked.month, picked.day, 12)));
  }

  List<BoardQueueItem> _filtered(DayBoard b) => b.queue.where((q) {
        if (_place.isNotEmpty && q.placeLabel != _place) return false;
        if (_half != 'all' && q.half != _half) return false;
        if (_nearTeam != null && !q.nearTeams.any((n) => n.teamId == _nearTeam && n.minutes <= b.travelLimitMin)) return false;
        return true;
      }).toList();

  Future<void> _allocateAll(DayBoard b) async {
    final items = [
      for (final q in _filtered(b))
        if (q.topTeamId != null && q.topTier != 'extra') {'bookingId': q.bookingId, 'picks': [{'unitKey': q.unitKey, 'teamId': q.topTeamId}]},
    ];
    if (items.isEmpty) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Allocate ${items.length} work${items.length == 1 ? '' : 's'}?'),
        content: const Text('Each goes to the team suggested on the board (extras are left for you to decide one by one).'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(key: const Key('board_allocate_all_ok'), onPressed: () => Navigator.pop(context, true), child: const Text('Allocate'))],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(allocationServiceProvider).confirmMany(items);
      final ok = res.where((r) => r['ok'] == true).length;
      refreshAllocation(ref);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$ok allocated${res.length > ok ? ' · ${res.length - ok} need a decision' : ''}')));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(PendingExtra x, bool approve) async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(allocationServiceProvider);
      approve ? await svc.approveExtra(x.id) : await svc.rejectExtra(x.id);
      refreshAllocation(ref);
    } on AllocationRefusal catch (r) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "New Allocation": a work of the day with no artist yet → its allocation; several → choose one; none → a new booking.
  Future<void> _newAllocation(DayBoard b) async {
    if (b.queue.isEmpty) {
      context.push('/booking/add');
      return;
    }
    BoardQueueItem? q = b.queue.length == 1 ? b.queue.first : null;
    q ??= await showModalBottomSheet<BoardQueueItem>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final crm = context.crmColors;
        return SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            Text('Which work?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            const SizedBox(height: 8),
            for (final w in b.queue)
              ListTile(
                key: Key('board_pick_${w.bookingId}_${w.unitKey}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_note_outlined, color: crm.primary),
                title: Text('${fmtHHMM(w.start)} · ${w.customerName}${w.label.isEmpty ? '' : ' · ${w.label}'}'),
                subtitle: Text(['#${w.bookingNumber}', if (w.placeLabel.isNotEmpty) w.placeLabel, if (w.topTeamName.isNotEmpty) 'suggested ${w.topTeamName}'].join(' · ')),
                onTap: () => Navigator.pop(context, w),
              ),
          ]),
        );
      },
    );
    if (q != null && mounted) await showAllocationSheet(context, bookingId: q.bookingId, source: 'board', primaryLabel: 'Allocate');
  }

  void _learnMore(DayBoard b) => showDialog<void>(
        context: context,
        builder: (context) {
          final crm = context.crmColors;
          Widget point(IconData icon, String text) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: crm.primary), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: crm.textPrimary)))]),
              );
          return AlertDialog(
            key: const Key('board_learn_more_dialog'),
            title: const Text('How Smart Allocation works'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  point(Icons.view_week_outlined, 'Each team has its slots a day — 2 morning and 1 evening, as set on Artist Management.'),
                  point(Icons.alt_route_rounded, 'The same artist takes the next work when its venue is within ${b.travelLimitMin} min of her job and she can be ready on time — her route stays connected.'),
                  point(Icons.autorenew_rounded, 'Otherwise the next free artist in the rotation starts a new route — artists who prefer that place first.'),
                  point(Icons.more_time_rounded, 'When every slot of a half is full, the best-fit team can take an EXTRA slot — the Artist Head approves; ${b.extrasPerDay} a day at most.'),
                  point(Icons.bolt_rounded, 'With "Assign automatically" on (Rules), a clean match gets its team the moment a new booking is confirmed; the rest wait here for CRM.'),
                ]),
              ),
            ),
            actions: [FilledButton(style: FilledButton.styleFrom(backgroundColor: crm.primary), onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final board = ref.watch(dayBoardProvider(_day));
    return Scaffold(
      backgroundColor: crm.background,
      body: board.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(dayBoardProvider(_day))),
        data: (b) => LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 1000;
          final pad = wide ? 20.0 : 12.0;
          if (wide) {
            return ListView(padding: EdgeInsets.fromLTRB(pad, 14, pad, 24), children: [
              _header(crm, b, true),
              const SizedBox(height: 14),
              _kpis(crm, b, true),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _allocations(crm, b, true)),
                const SizedBox(width: 14),
                SizedBox(
                  width: c.maxWidth >= 1250 ? 290 : 270,
                  child: Column(children: [_filters(crm, b, true), const SizedBox(height: 14), _smart(crm, b)]),
                ),
              ]),
            ]);
          }
          return ListView(padding: EdgeInsets.fromLTRB(pad, 12, pad, 24), children: [
            _header(crm, b, false),
            const SizedBox(height: 12),
            _kpis(crm, b, false),
            const SizedBox(height: 12),
            _tabs(crm, b),
            const SizedBox(height: 10),
            if (_queueTab) _filters(crm, b, false) else _allocations(crm, b, false),
            const SizedBox(height: 12),
            _smart(crm, b),
          ]);
        }),
      ),
    );
  }

  // ── the parts ───────────────────────────────────────────────────────────────

  BoxDecoration _cardDeco(CrmTheme crm) => BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 10, offset: const Offset(0, 3))],
      );

  Widget _header(CrmTheme crm, DayBoard b, bool wide) {
    final modeText = switch (b.mode) { 'suggest' => null, 'shadow' => 'On trial — the ERP shows what it would suggest; nothing is allocated from here yet.', _ => 'The allocation is off — switch it on in Rules (Artist Management).' };
    final title = Row(children: [
      Container(
        width: wide ? 44 : 38,
        height: wide ? 44 : 38,
        decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.event_available_rounded, color: crm.primary, size: wide ? 23 : 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Allocation Board', style: TextStyle(fontSize: wide ? 21 : 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          Text('Manage bookings, artist allocation and schedules efficiently.', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ]),
      ),
    ]);
    final dateText = Text(DateFormat('EEE, d MMM yyyy').format(DateTime.parse(_day)), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary));
    final dateButton = InkWell(
      key: const Key('board_day'),
      borderRadius: BorderRadius.circular(20),
      onTap: _pickDay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.calendar_month_outlined, size: 16, color: crm.primary),
          const SizedBox(width: 6),
          // a desktop gives the pill its natural width; a phone stretches it and the date may shorten
          if (wide) dateText else Flexible(child: dateText),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: crm.textPrimary),
        ]),
      ),
    );
    final dayPill = Container(
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: crm.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max, children: [
        IconButton(key: const Key('board_prev'), tooltip: 'The day before', visualDensity: VisualDensity.compact, iconSize: 20, onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
        if (wide) dateButton else Expanded(child: dateButton),
        IconButton(key: const Key('board_next'), tooltip: 'The day after', visualDensity: VisualDensity.compact, iconSize: 20, onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
    );
    final refresh = Material(
      color: crm.surface,
      shape: CircleBorder(side: BorderSide(color: crm.border)),
      child: IconButton(key: const Key('board_refresh'), tooltip: 'Refresh', visualDensity: VisualDensity.compact, iconSize: 19, onPressed: () => ref.invalidate(dayBoardProvider(_day)), icon: Icon(Icons.refresh_rounded, color: crm.textPrimary)),
    );
    final controls = Row(mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max, children: [if (wide) dayPill else Expanded(child: dayPill), const SizedBox(width: 10), refresh]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (wide) Row(children: [Expanded(child: title), const SizedBox(width: 16), controls]) else ...[title, const SizedBox(height: 12), controls],
      if (modeText != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(modeText, key: const Key('board_mode_note'), style: TextStyle(fontSize: 12, color: crm.warning, fontWeight: FontWeight.w600))),
    ]);
  }

  Widget _kpis(CrmTheme crm, DayBoard b, bool wide) {
    final at = b.week.indexWhere((w) => w.day == b.day);
    final cards = [
      _kpi(crm, key: 'board_booked', icon: Icons.event_available_rounded, color: crm.primary, value: '${b.booked}/${b.planned}', label: 'Booked', series: [for (final w in b.week) w.booked], at: at, wide: wide),
      _kpi(crm, key: 'board_extras', icon: Icons.star_border_rounded, color: _gold, value: '${b.extrasUsed}/${b.extrasPerDay}', label: 'Extras', series: [for (final w in b.week) w.extras], at: at, wide: wide),
      _kpi(crm, key: 'board_unallocated', icon: Icons.pie_chart_rounded, color: _evening, value: '${b.unallocated}', label: 'To Allocate', series: [for (final w in b.week) w.toAllocate], at: at, wide: wide),
      _kpi(crm, key: 'board_pending', icon: Icons.groups_rounded, color: _teal, value: '${b.extrasPending}', label: 'Pending', series: [for (final w in b.week) w.pending], at: at, wide: wide),
    ];
    if (wide) {
      return Row(children: [
        for (final (i, k) in cards.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: k)],
      ]);
    }
    return Column(children: [
      Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3])]),
    ]);
  }

  Widget _kpi(CrmTheme crm, {required String key, required IconData icon, required Color color, required String value, required String label, required List<int> series, required int at, required bool wide}) {
    final tile = Container(
      width: wide ? 38 : 32,
      height: wide ? 38 : 32,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: wide ? 20 : 17),
    );
    final figures = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: wide ? 19 : 17, height: 1.15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
    ]);
    final spark = Tooltip(
      message: 'This week, Mon–Sun',
      child: SizedBox(height: wide ? 32 : 22, child: CustomPaint(painter: _Spark(series, color, at), size: Size.infinite)),
    );
    return Container(
      key: Key(key),
      padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 10, vertical: wide ? 10 : 9),
      decoration: _cardDeco(crm),
      child: wide
          // the figures at their own width (capped, so a narrow card shortens the label, never overflows); the week's line takes the rest
          ? Row(children: [tile, const SizedBox(width: 10), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 92), child: figures), const SizedBox(width: 8), Expanded(child: spark)])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [tile, const SizedBox(width: 8), Expanded(child: figures)]),
              const SizedBox(height: 6),
              spark,
            ]),
    );
  }

  Widget _tabs(CrmTheme crm, DayBoard b) {
    Widget tab(String key, String text, bool on, VoidCallback tap) => Expanded(
          child: InkWell(
            key: Key(key),
            borderRadius: BorderRadius.circular(26),
            onTap: tap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: on ? crm.primary : Colors.transparent, borderRadius: BorderRadius.circular(26)),
              child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : crm.textPrimary)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: crm.border)),
      child: Row(children: [
        tab('board_tab_teams', 'Teams', !_queueTab, () => setState(() => _queueTab = false)),
        tab('board_tab_queue', 'To allocate (${b.queue.length})', _queueTab, () => setState(() => _queueTab = true)),
      ]),
    );
  }

  Widget _newAllocationButton(CrmTheme crm, DayBoard b, {bool filled = false, bool iconOnly = false}) {
    if (iconOnly) {
      return IconButton.filledTonal(key: const Key('board_new_allocation'), tooltip: 'New Allocation', visualDensity: VisualDensity.compact, onPressed: _busy ? null : () => _newAllocation(b), icon: const Icon(Icons.add_rounded));
    }
    final child = Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.add_rounded, size: 16), const SizedBox(width: 5), const Text('New Allocation')]);
    return filled
        ? FilledButton(key: const Key('board_new_allocation_empty'), style: FilledButton.styleFrom(backgroundColor: crm.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), elevation: 1), onPressed: _busy ? null : () => _newAllocation(b), child: child)
        : TextButton(
            key: const Key('board_new_allocation'),
            style: TextButton.styleFrom(foregroundColor: crm.primary, backgroundColor: crm.primary.withValues(alpha: 0.10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), visualDensity: VisualDensity.compact, shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            onPressed: _busy ? null : () => _newAllocation(b),
            child: child,
          );
  }

  Widget _allocations(CrmTheme crm, DayBoard b, bool wide) {
    final day = DateTime.parse(b.day.isEmpty ? _day : b.day);
    return Container(
      key: const Key('board_allocations'),
      padding: EdgeInsets.all(wide ? 16 : 12),
      decoration: _cardDeco(crm),
      child: LayoutBuilder(builder: (context, c) {
        final rowWide = c.maxWidth >= 600; // room for the team, its three slots side by side and the status
        final infoW = (c.maxWidth * 0.26).clamp(140.0, 200.0).toDouble(); // the team's name / day / place column
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.groups_rounded, color: crm.primary, size: 21),
            const SizedBox(width: 8),
            Expanded(child: Text('Allocations', style: TextStyle(fontSize: wide ? 16 : 15, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            if (b.canAllocate) _newAllocationButton(crm, b, iconOnly: c.maxWidth < 330),
          ]),
          if (b.outsourced > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${b.outsourced} work${b.outsourced == 1 ? '' : 's'} of the day ${b.outsourced == 1 ? 'is' : 'are'} with other (associate) artists.', key: const Key('board_outsourced'), style: TextStyle(fontSize: 12, color: crm.textSecondary))),
          const SizedBox(height: 6),
          ..._extras(crm, b),
          if (b.teams.isEmpty)
            Padding(padding: const EdgeInsets.all(20), child: Text('No artist teams yet — set them up on Artist Management.', key: const Key('board_no_teams'), style: TextStyle(color: crm.textSecondary)))
          else
            for (final (i, t) in b.teams.indexed) ...[if (i > 0) Divider(height: 1, color: crm.border), _team(crm, t, i, day, rowWide, infoW: infoW)],
          if (b.teams.isNotEmpty && b.queue.isEmpty) _allDone(crm, b),
        ]);
      }),
    );
  }

  Widget _allDone(CrmTheme crm, DayBoard b) => Padding(
        key: const Key('board_all_done'),
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.07), shape: BoxShape.circle),
            child: Icon(Icons.event_available_outlined, size: 26, color: crm.primary.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 8),
          Text('No more allocations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(height: 4),
          Text(b.canAllocate ? 'Every new work of the day has its artist. A new booking starts the next one.' : 'Every new work of the day has its artist.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          if (b.canAllocate) ...[const SizedBox(height: 10), _newAllocationButton(crm, b, filled: true)],
        ]),
      );

  List<Widget> _extras(CrmTheme crm, DayBoard b) {
    if (b.pendingExtras.isEmpty) return const [];
    return [
      Container(
        key: const Key('board_pending_extras'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _gold.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _gold.withValues(alpha: 0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.more_time_rounded, color: _gold, size: 17), const SizedBox(width: 6), Expanded(child: Text('Extra slots waiting for the Artist Head', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary)))]),
          for (final x in b.pendingExtras)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${x.bookingNumber} ${x.customerName} · ${fmtHHMM(x.start)} · wants ${x.teamName}${x.askedBy.isEmpty ? '' : ' (asked by ${x.askedBy})'}', style: TextStyle(fontSize: 12, color: crm.textPrimary)),
                if (b.canApproveExtra)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 8, runSpacing: 6, children: [
                      FilledButton(key: Key('board_approve_${x.id}'), style: FilledButton.styleFrom(backgroundColor: crm.success, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 14), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), onPressed: _busy ? null : () => _decide(x, true), child: const Text('Approve')),
                      OutlinedButton(key: Key('board_reject_${x.id}'), style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 14), textStyle: const TextStyle(fontSize: 12)), onPressed: _busy ? null : () => _decide(x, false), child: const Text('Turn down')),
                    ]),
                  ),
              ]),
            ),
        ]),
      ),
    ];
  }

  Widget _team(CrmTheme crm, BoardTeam t, int i, DateTime day, bool wide, {double infoW = 190}) {
    final (statusText, statusColor) = switch (t.status) {
      'free' => ('Free all day', crm.success),
      'has_room' => ('${t.of - t.used} slot${t.of - t.used == 1 ? '' : 's'} left', crm.primary),
      'full' => ('Full', crm.destructive),
      'on_leave' => ('On leave', crm.warning),
      _ => ('Half-day leave', crm.warning),
    };
    final jobs = [...t.jobs]..sort((a, b) => a.start.compareTo(b.start));
    final first = jobs.isEmpty ? null : jobs.first;
    final open = _open.contains(t.id);
    final muted = TextStyle(fontSize: 11.5, color: crm.textSecondary);
    final body = TextStyle(fontSize: 12, color: crm.textPrimary);

    final badge = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(9)),
      child: Text('${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.primary)),
    );
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
      if (t.assistants.isNotEmpty) Text('with ${t.assistants.map((a) => a.name).join(', ')}', style: muted),
      const SizedBox(height: 4),
      Row(children: [
        Icon(Icons.calendar_today_outlined, size: 12.5, color: crm.primary),
        const SizedBox(width: 5),
        Flexible(child: Text('${DateFormat(wide ? 'EEE, d MMM yyyy' : 'EEE, d MMM').format(day)} • ${t.onLeave ? 'on leave' : first == null ? 'free all day' : fmtHHMM(first.start)}', style: body)),
      ]),
      if (first != null && first.label.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(children: [Icon(Icons.place_outlined, size: 13.5, color: crm.primary), const SizedBox(width: 4), Flexible(child: Text(first.label, style: body))]),
        ),
    ]);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Text(statusText, key: Key('board_status_${t.id}'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
    );
    final chevron = Material(
      color: crm.surface,
      shape: CircleBorder(side: BorderSide(color: crm.border)),
      child: IconButton(
        key: Key('board_expand_${t.id}'),
        tooltip: open ? 'Hide the day' : 'The day in full',
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        padding: EdgeInsets.zero,
        onPressed: () => setState(() => open ? _open.remove(t.id) : _open.add(t.id)),
        icon: Icon(open ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, color: crm.textPrimary),
      ),
    );
    final slots = LayoutBuilder(
      builder: (context, c) {
        // three slots to a row (M1 M2 E1) wherever they fit — an EXTRA goes under them
        final w = ((c.maxWidth - 12) / 3).clamp(84.0, 116.0).toDouble();
        return Wrap(spacing: 6, runSpacing: 6, children: [for (final s in t.slots) _slot(crm, s, away: !s.taken && t.awayFor(s.half), width: w)]);
      },
    );
    final free = (t.jobs.isNotEmpty && t.freeFromText.isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [Icon(Icons.schedule_rounded, size: 13, color: crm.textSecondary), const SizedBox(width: 4), Flexible(child: Text(t.freeFromText.replaceFirst('free', 'Free'), style: muted))]),
          )
        : const SizedBox.shrink();
    final dayInFull = !open
        ? const SizedBox.shrink()
        : Container(
            key: Key('board_day_${t.id}'),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(10)),
            child: jobs.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t.onLeave ? 'On leave today.' : 'No work yet today.', style: muted))
                : Column(children: [
                    for (final j in jobs)
                      InkWell(
                        onTap: () => context.push('/booking/manage/${j.bookingId}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            SizedBox(width: wide ? 130 : 104, child: Text('${fmtHHMM(j.start)}–${fmtHHMM(j.end)}', style: body.copyWith(fontWeight: FontWeight.w700))),
                            Expanded(child: Text([j.customerName, '#${j.bookingNumber}', if (j.label.isNotEmpty) j.label].where((x) => x.isNotEmpty).join(' · '), style: body)),
                            Icon(Icons.open_in_new_rounded, size: 14, color: crm.textSecondary),
                          ]),
                        ),
                      ),
                  ]),
          );

    return Container(
      key: Key('board_team_${t.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: wide
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                badge,
                const SizedBox(width: 10),
                SizedBox(width: infoW, child: info),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [slots, free])),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [pill, const SizedBox(height: 6), chevron]),
              ]),
              dayInFull,
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [badge, const SizedBox(width: 10), Expanded(child: info), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [pill, const SizedBox(height: 6), chevron])]),
              const SizedBox(height: 8),
              slots,
              free,
              dayInFull,
            ]),
    );
  }

  /// One slot: its key (M1 / E1 / EXTRA X1), and — when taken — the time, the CLIENT and the place.
  Widget _slot(CrmTheme crm, BoardSlot s, {bool away = false, double width = 116}) {
    final color = s.extra ? _gold : s.half == 'morning' ? crm.primary : _evening;
    final head = '${s.extra ? 'EXTRA ' : ''}${s.key}${s.over ? ' (over)' : ''}';
    final waiting = s.extra && s.approval == 'pending';
    final card = Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
      decoration: BoxDecoration(
        color: s.taken ? color.withValues(alpha: 0.07) : crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.taken ? color.withValues(alpha: 0.35) : crm.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(head, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 1),
        if (s.taken) ...[
          Text(fmtHHMM(s.start), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          if (s.customerName.isNotEmpty) Text(s.customerName, key: Key('board_slot_client_${s.key}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w600, color: crm.textPrimary)),
          if (s.label.isNotEmpty) Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: color.withValues(alpha: 0.9))),
          if (waiting) Text('waiting for OK', key: Key('board_slot_waiting_${s.key}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _gold)),
        ] else
          Text(away ? 'On leave' : 'Free', key: away ? Key('board_slot_away_${s.key}') : null, style: TextStyle(fontSize: 12, color: away ? crm.warning : crm.textSecondary, fontWeight: away ? FontWeight.w600 : FontWeight.w500)),
      ]),
    );
    if (!s.taken) return card;
    final tip = [
      '#${s.bookingNumber}',
      if (s.customerName.isNotEmpty) s.customerName,
      '${fmtHHMM(s.start)}${s.end.isEmpty ? '' : '–${fmtHHMM(s.end)}'}',
      if (s.label.isNotEmpty) s.label,
    ].join(' · ');
    return Tooltip(
      message: tip,
      child: InkWell(key: Key('board_slot_${s.key}_${s.bookingNumber}'), borderRadius: BorderRadius.circular(10), onTap: s.bookingId == null ? null : () => context.push('/booking/manage/${s.bookingId}'), child: card),
    );
  }

  Widget _filters(CrmTheme crm, DayBoard b, bool wide) {
    final places = {for (final q in b.queue) if (q.placeLabel.isNotEmpty) q.placeLabel}.toList()..sort();
    final list = _filtered(b);
    final suggested = list.where((q) => q.topTeamId != null && q.topTier != 'extra').length;
    final label = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary);
    // controlled (the value always one of today's choices — a day with other places never trips it)
    Widget box<T>(Key key, T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
          child: DropdownButtonHideUnderline(child: DropdownButton<T>(key: key, isExpanded: true, isDense: true, iconSize: 20, style: TextStyle(fontSize: 12.5, color: crm.textPrimary), value: value, items: items, onChanged: onChanged, borderRadius: BorderRadius.circular(10))),
        );
    return Container(
      key: const Key('board_filters'),
      padding: EdgeInsets.all(wide ? 14 : 12),
      decoration: _cardDeco(crm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Icon(Icons.filter_alt_outlined, color: crm.primary, size: 19), const SizedBox(width: 6), Flexible(child: Text('Filters', style: TextStyle(fontSize: wide ? 16 : 15, fontWeight: FontWeight.w800, color: crm.textPrimary)))]),
        const SizedBox(height: 10),
        Text('New works to allocate', style: label),
        const SizedBox(height: 6),
        // Method B: filter the day's works — the backup view on the busiest days
        box<String>(
          const Key('board_filter_place'),
          places.contains(_place) ? _place : '',
          [const DropdownMenuItem(value: '', child: Text('Every place')), for (final p in places) DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))],
          (v) => setState(() => _place = v ?? ''),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final h in const [('all', 'All day'), ('morning', 'Morning'), ('evening', 'Evening')])
            ChoiceChip(
              key: Key('board_filter_half_${h.$1}'),
              // a small tick of its own (the chip's checkmark grows with the theme, too big beside 12 px text)
              label: Row(mainAxisSize: MainAxisSize.min, children: [if (_half == h.$1) ...[const Icon(Icons.check_rounded, size: 13, color: Colors.white), const SizedBox(width: 3)], Text(h.$2)]),
              selected: _half == h.$1,
              onSelected: (_) => setState(() => _half = h.$1),
              showCheckmark: false,
              selectedColor: crm.primary,
              backgroundColor: crm.surface,
              shape: StadiumBorder(side: BorderSide(color: _half == h.$1 ? crm.primary : crm.border)),
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _half == h.$1 ? Colors.white : crm.textPrimary),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ]),
        const SizedBox(height: 10),
        Text('Within', style: label),
        const SizedBox(height: 6),
        box<String?>(
          const Key('board_filter_near'),
          b.teams.any((t) => t.id == _nearTeam) ? _nearTeam : null,
          [
            DropdownMenuItem<String?>(value: null, child: Text('${b.travelLimitMin} min of anyone', overflow: TextOverflow.ellipsis)),
            for (final t in b.teams) DropdownMenuItem<String?>(value: t.id, child: Text('${b.travelLimitMin} min of ${t.name}', overflow: TextOverflow.ellipsis)),
          ],
          (v) => setState(() => _nearTeam = v),
        ),
        const SizedBox(height: 10),
        if (b.canAllocate && suggested > 0) ...[
          FilledButton.icon(key: const Key('board_allocate_all'), style: FilledButton.styleFrom(backgroundColor: crm.primary, padding: const EdgeInsets.symmetric(vertical: 10), textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)), onPressed: _busy ? null : () => _allocateAll(b), icon: const Icon(Icons.done_all_rounded, size: 16), label: Text('Allocate $suggested as suggested')),
          const SizedBox(height: 8),
        ],
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: crm.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(b.queue.isEmpty ? 'Every new work of the day has its artist.' : 'Nothing matches these filters.', key: const Key('board_queue_empty'), style: TextStyle(fontSize: 11.5, color: crm.textSecondary))),
            ]),
          ),
        for (final q in list) _queueItem(crm, b, q),
      ]),
    );
  }

  Widget _queueItem(CrmTheme crm, DayBoard b, BoardQueueItem q) => Container(
        key: Key('board_queue_${q.bookingId}_${q.unitKey}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${fmtHHMM(q.start)}–${fmtHHMM(q.end)} · ${q.customerName}${q.label.isEmpty ? '' : ' · ${q.label}'}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          Text('#${q.bookingNumber}${q.placeLabel.isEmpty ? '' : ' · ${q.placeLabel}'}${q.timeSet ? '' : ' · time not set'}${q.precision == 'unknown' ? ' · no map pin' : ''}', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          const SizedBox(height: 4),
          if (q.topTeamId != null)
            Text('Suggested: ${q.topTeamName} — ${q.topReason}', key: Key('board_top_${q.bookingId}'), style: TextStyle(fontSize: 11.5, color: q.topTier == 'extra' ? _gold : crm.textPrimary))
          else
            Text('No team is free for it — every slot is taken or clashes.', style: TextStyle(fontSize: 11.5, color: crm.destructive)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (b.canAllocate)
              FilledButton(
                key: Key('board_allocate_${q.bookingId}'),
                style: FilledButton.styleFrom(backgroundColor: crm.primary, visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: _busy ? null : () => showAllocationSheet(context, bookingId: q.bookingId, source: 'board', primaryLabel: 'Allocate'),
                child: const Text('Allocate'),
              ),
            OutlinedButton(key: Key('board_open_${q.bookingId}'), style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 12), padding: const EdgeInsets.symmetric(horizontal: 12)), onPressed: () => context.push('/booking/manage/${q.bookingId}'), child: const Text('Open booking')),
          ]),
        ]),
      );

  Widget _smart(CrmTheme crm, DayBoard b) => Container(
        key: const Key('board_smart'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [crm.primary.withValues(alpha: 0.06), crm.primary.withValues(alpha: 0.16)]),
          border: Border.all(color: crm.primary.withValues(alpha: 0.12)),
        ),
        child: Stack(children: [
          Positioned(right: -10, bottom: -10, child: Opacity(opacity: 0.16, child: Image.asset('assets/images/nizan_monogram.png', width: 96, height: 96, errorBuilder: (_, _, _) => Icon(Icons.auto_awesome_rounded, size: 80, color: crm.primary)))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.auto_awesome_rounded, size: 16, color: crm.primary), const SizedBox(width: 6), Flexible(child: Text('Smart Allocation', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary)))]),
              const SizedBox(height: 4),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: Text('Assign works quickly and manage your schedule better.', style: TextStyle(fontSize: 12, color: crm.textSecondary))),
              const SizedBox(height: 10),
              FilledButton(
                key: const Key('board_learn_more'),
                style: FilledButton.styleFrom(backgroundColor: crm.primary, shape: const StadiumBorder(), visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 14), textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                onPressed: () => _learnMore(b),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Learn more'), SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, size: 15)]),
              ),
            ]),
          ),
        ]),
      );
}

/// The week's little line on a Board card (Mon–Sun), the shown day marked.
class _Spark extends CustomPainter {
  _Spark(this.values, this.color, this.at);
  final List<int> values;
  final Color color;
  final int at;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final top = values.reduce(math.max).toDouble();
    final flat = values.every((v) => v == values.first);
    final peak = top <= 0 ? 1.0 : top;
    final h = size.height;
    // a week the same every day lies in the middle (all zero: along the bottom), not pinned to the top
    double y(int v) => flat ? (v == 0 ? h - 4 : h / 2) : h - 4 - (v / peak) * (h - 9);
    final pts = [
      // (4 px in from each side, so the marked day's dot never touches the figures beside it)
      for (var i = 0; i < values.length; i++) Offset(4 + i * (size.width - 8) / (values.length - 1), y(values[i])),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], c = pts[i];
      final mx = (a.dx + c.dx) / 2;
      line.cubicTo(mx, a.dy, mx, c.dy, c.dx, c.dy);
    }
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, h)
      ..lineTo(pts.first.dx, h)
      ..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0.0)]).createShader(Offset.zero & size));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    if (at >= 0 && at < pts.length) {
      canvas.drawCircle(pts[at], 3, Paint()..color = Colors.white);
      canvas.drawCircle(
        pts[at],
        3,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Spark old) => old.color != color || old.at != at || old.values.join(',') != values.join(',');
}
