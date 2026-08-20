import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/blocked_date.dart';
import 'package:nizan_crm/services/blocked_date_service.dart';
import 'package:nizan_crm/features/slots/data/slot_models.dart';
import 'package:nizan_crm/features/slots/services/slot_service.dart';

const _monthNames = ['', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];
const _weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// HR screen to set the day-wise booking slot capacity (morning / evening),
/// with a company-wide default and per-date overrides. When a day+half is full,
/// salespeople are blocked from booking it (enforced on the server).
class SlotCapacityScreen extends ConsumerStatefulWidget {
  const SlotCapacityScreen({super.key});

  @override
  ConsumerState<SlotCapacityScreen> createState() => _SlotCapacityScreenState();
}

class _SlotCapacityScreenState extends ConsumerState<SlotCapacityScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  ({int year, int month}) get _key => (year: _month.year, month: _month.month);

  Future<void> _reload() async {
    ref.invalidate(monthAvailabilityProvider(_key));
    ref.invalidate(slotDefaultsProvider);
  }

  Future<void> _manageBlockedDates() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BlockedDatesSheet(),
    );
    _reload(); // blocked days may have changed → refresh the month view
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final defaultsAsync = ref.watch(slotDefaultsProvider);
    final monthAsync = ref.watch(monthAvailabilityProvider(_key));

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        title: const Text('Booking Slot Capacity'),
        backgroundColor: crm.surface,
        foregroundColor: crm.textPrimary,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _manageBlockedDates,
            icon: const Icon(Icons.event_busy_outlined, size: 18),
            label: const Text('Blocked Dates'),
            style: TextButton.styleFrom(foregroundColor: crm.destructive),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            defaultsAsync.when(
              loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(slotDefaultsProvider)),
              data: (d) => _DefaultsCard(defaults: d, onSaved: _reload),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text('${_monthNames[_month.month]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
            Text('Tap a day to override its limit for that date.',
                style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            const SizedBox(height: 10),
            monthAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(monthAvailabilityProvider(_key))),
              data: (m) => Column(children: [for (final day in m.days) _dayTile(context, day)]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayTile(BuildContext context, DaySlot d) {
    final crm = context.crmColors;
    return InkWell(
      onTap: () => _editDay(d),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: d.blocked ? crm.destructive.withValues(alpha: 0.06) : crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: d.blocked
                  ? crm.destructive.withValues(alpha: 0.45)
                  : (d.isOverride ? crm.primary.withValues(alpha: 0.5) : crm.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${d.date.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(_weekdays[d.date.weekday], style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.blocked
                        ? 'BLOCKED'
                        : (d.total.isFull
                            ? 'FULL · ${d.total.booked}/${d.total.capacity}'
                            : '${d.total.booked}/${d.total.capacity} booked'),
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: (d.blocked || d.total.isFull) ? crm.destructive : crm.textPrimary),
                  ),
                  Text(
                    d.blocked
                        ? 'No bookings allowed'
                        : 'AM ${d.morning.booked}/${d.morning.capacity} · PM ${d.evening.booked}/${d.evening.capacity}',
                    style: TextStyle(fontSize: 11, color: crm.textSecondary),
                  ),
                ],
              ),
            ),
            if (d.blocked)
              Icon(Icons.block, size: 16, color: crm.destructive)
            else if (d.isOverride)
              Icon(Icons.push_pin, size: 15, color: crm.primary),
            Icon(Icons.chevron_right, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _editDay(DaySlot d) async {
    var morning = d.morning.capacity;
    var evening = d.evening.capacity;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final crm = ctx.crmColors;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_weekdays[d.date.weekday]}, ${_monthNames[d.date.month]} ${d.date.day}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Booked so far: ${d.morning.booked} AM · ${d.evening.booked} PM',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                if (d.blocked) ...[
                  const SizedBox(height: 8),
                  Text('This date is in the Blocked Dates list — no bookings allowed. Use "Blocked Dates" above to unblock.',
                      style: TextStyle(fontSize: 12, color: crm.destructive, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 18),
                _stepper(context, 'Morning slots', morning, (v) => setSheet(() => morning = v)),
                const SizedBox(height: 12),
                _stepper(context, 'Evening slots', evening, (v) => setSheet(() => evening = v)),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (d.isOverride)
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(slotServiceProvider).clearDay(d.date);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset to default'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await ref.read(slotServiceProvider)
                            .setDay(date: d.date, morning: morning, evening: evening);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (saved == true) {
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Slot capacity updated')),
        );
      }
    }
  }
}

/// Company-wide default capacity editor.
class _DefaultsCard extends ConsumerStatefulWidget {
  const _DefaultsCard({required this.defaults, required this.onSaved});
  final SlotDefaults defaults;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<_DefaultsCard> createState() => _DefaultsCardState();
}

class _DefaultsCardState extends ConsumerState<_DefaultsCard> {
  late int _morning = widget.defaults.morning;
  late int _evening = widget.defaults.evening;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final dirty = _morning != widget.defaults.morning || _evening != widget.defaults.evening;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Default capacity (every day)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          Text('Applies to any day you haven\'t given a custom limit.',
              style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          const SizedBox(height: 14),
          _stepper(context, 'Morning slots', _morning, (v) => setState(() => _morning = v)),
          const SizedBox(height: 12),
          _stepper(context, 'Evening slots', _evening, (v) => setState(() => _evening = v)),
          const SizedBox(height: 6),
          const Divider(),
          Row(
            children: [
              Text('Total bookings allowed per day',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              const Spacer(),
              Text('${_morning + _evening}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: crm.primary)),
            ],
          ),
          const SizedBox(height: 4),
          Text('A day is blocked once its total bookings reach this number.',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (!dirty || _saving)
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _saving = true);
                      try {
                        await ref.read(slotServiceProvider)
                            .updateDefaults(morning: _morning, evening: _evening);
                        await widget.onSaved();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Default capacity saved')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                        );
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: Text(_saving ? 'Saving…' : 'Save default'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled − value + stepper (0..99).
Widget _stepper(BuildContext context, String label, int value, ValueChanged<int> onChanged) {
  final crm = context.crmColors;
  return Row(
    children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: crm.textPrimary))),
      IconButton(
        onPressed: value <= 0 ? null : () => onChanged(value - 1),
        icon: const Icon(Icons.remove_circle_outline),
      ),
      SizedBox(
        width: 34,
        child: Text('$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      IconButton(
        onPressed: value >= 99 ? null : () => onChanged(value + 1),
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}

/// Manage the shared Blocked Dates list (HR). A blocked date takes no bookings —
/// the sales team is refused when they try to book it (enforced on the server).
class _BlockedDatesSheet extends ConsumerStatefulWidget {
  const _BlockedDatesSheet();
  @override
  ConsumerState<_BlockedDatesSheet> createState() => _BlockedDatesSheetState();
}

class _BlockedDatesSheetState extends ConsumerState<_BlockedDatesSheet> {
  DateTime? _picked;
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _picked ?? now,
      firstDate: DateTime(now.year, now.month, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (d != null) setState(() => _picked = d);
  }

  Future<void> _add() async {
    if (_picked == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(blockedDateServiceProvider)
          .saveBlockedDate(date: _picked!, reason: _reason.text.trim(), active: true);
      ref.invalidate(blockedDatesProvider);
      setState(() {
        _picked = null;
        _reason.clear();
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(blockedDateServiceProvider).deleteBlockedDate(id);
      ref.invalidate(blockedDatesProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  String _fmt(DateTime d) => '${d.day} ${_monthNames[d.month]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(blockedDatesProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.event_busy_outlined, color: crm.destructive),
              const SizedBox(width: 10),
              const Text('Blocked Dates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 2),
            Text('A blocked date takes NO bookings — the sales team can\'t book it.',
                style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_picked == null ? 'Pick a date' : _fmt(_picked!)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_picked == null || _saving) ? null : _add,
                icon: const Icon(Icons.block, size: 18),
                label: Text(_saving ? 'Blocking…' : 'Block this date'),
                style: FilledButton.styleFrom(backgroundColor: crm.destructive),
              ),
            ),
            const Divider(height: 26),
            Text('Currently blocked', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
            const SizedBox(height: 4),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(blockedDatesProvider)),
                data: (list) {
                  final active = list.where((b) => b.active).toList()
                    ..sort((a, b) => a.date.compareTo(b.date));
                  if (active.isEmpty) {
                    return Center(child: Text('No blocked dates yet.', style: TextStyle(color: crm.textSecondary)));
                  }
                  return ListView(
                    controller: controller,
                    children: [
                      for (final BlockedDate b in active)
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.block, color: crm.destructive, size: 20),
                          title: Text(_fmt(b.date), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: b.reason.isEmpty ? null : Text(b.reason),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: crm.textSecondary),
                            tooltip: 'Unblock',
                            onPressed: () => _delete(b.id),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
