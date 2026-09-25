import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/blocked_date.dart';
import 'package:nizan_crm/services/blocked_date_service.dart';
import 'package:nizan_crm/features/slots/data/slot_models.dart';
import 'package:nizan_crm/features/slots/services/slot_service.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

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
    // Every month (not just the visible one), defaults and blocked dates —
    // the booking forms read other months' availability too.
    ref.refreshData.slots();
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthYearPicker(initial: _month),
    );
    if (picked != null && mounted) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
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
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        title: const Text('Booking Slot Capacity'),
        backgroundColor: crm.surface,
        foregroundColor: crm.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: Icon(Icons.refresh_rounded, color: crm.textSecondary),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: _manageBlockedDates,
              icon: const Icon(Icons.event_busy_outlined, size: 18),
              label: const Text('Blocked Dates'),
              style: OutlinedButton.styleFrom(
                foregroundColor: crm.destructive,
                side: BorderSide(color: crm.destructive.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 1000;
        final pad = box.maxWidth < 600 ? 14.0 : 22.0;

        final monthNav = Row(
          children: [
            _NavButton(icon: Icons.chevron_left_rounded, onTap: () => _shift(-1)),
            Expanded(
              child: Column(
                children: [
                  // Tap the title to jump straight to any month / year.
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _pickMonth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_outlined,
                                size: 18, color: crm.primary),
                            const SizedBox(width: 8),
                            Text('${_monthNames[_month.month]} ${_month.year}',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: crm.textPrimary)),
                            const SizedBox(width: 4),
                            Icon(Icons.expand_more_rounded,
                                size: 20, color: crm.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isCurrentMonth)
                    InkWell(
                      onTap: () => setState(
                          () => _month = DateTime(now.year, now.month)),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Back to this month',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: crm.primary)),
                      ),
                    ),
                ],
              ),
            ),
            _NavButton(icon: Icons.chevron_right_rounded, onTap: () => _shift(1)),
          ],
        );

        final calendarCard = _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              monthNav,
              const SizedBox(height: 4),
              Text('Tap a day to set a custom limit for that date.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              const SizedBox(height: 14),
              monthAsync.when(
                loading: () => const SizedBox(
                    height: 320,
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => AppErrorView(
                    error: e,
                    compact: true,
                    onRetry: () =>
                        ref.invalidate(monthAvailabilityProvider(_key))),
                data: (m) => _MonthGrid(
                  month: _month,
                  days: m.days,
                  onTapDay: _editDay,
                ),
              ),
              const SizedBox(height: 14),
              const _Legend(),
            ],
          ),
        );

        final defaultsCard = defaultsAsync.when(
          loading: () => const _Panel(
              child: SizedBox(
                  height: 160, child: Center(child: CircularProgressIndicator()))),
          error: (e, _) => _Panel(
              child: AppErrorView(
                  error: e,
                  compact: true,
                  onRetry: () => ref.invalidate(slotDefaultsProvider))),
          data: (d) => _DefaultsCard(defaults: d, onSaved: _reload),
        );

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 32),
            children: [
              monthAsync.maybeWhen(
                data: (m) => _SummaryRow(month: m, width: box.maxWidth - pad * 2),
                orElse: () => const SizedBox.shrink(),
              ),
              if (monthAsync.hasValue) const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 340, child: defaultsCard),
                    const SizedBox(width: 16),
                    Expanded(child: calendarCard),
                  ],
                )
              else ...[
                calendarCard,
                const SizedBox(height: 16),
                defaultsCard,
              ],
            ],
          ),
        );
      }),
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
                _stepper(context, 'Morning', morning, (v) => setSheet(() => morning = v),
                    icon: Icons.wb_sunny_outlined, color: const Color(0xFFD97706)),
                const SizedBox(height: 12),
                _stepper(context, 'Evening', evening, (v) => setSheet(() => evening = v),
                    icon: Icons.nights_stay_outlined, color: const Color(0xFF6E1423)),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (d.isOverride)
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await ref.read(slotServiceProvider).clearDay(d.date);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            // Keep the sheet open so the user can retry.
                            if (ctx.mounted) showErrorSnackBar(ctx, e);
                          }
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset to default'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await ref.read(slotServiceProvider)
                              .setDay(date: d.date, morning: morning, evening: evening);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          // Keep the sheet open so the user can retry.
                          if (ctx.mounted) showErrorSnackBar(ctx, e);
                        }
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
  void didUpdateWidget(covariant _DefaultsCard old) {
    super.didUpdateWidget(old);
    // Pick up the saved values after a reload.
    if (old.defaults.morning != widget.defaults.morning ||
        old.defaults.evening != widget.defaults.evening) {
      _morning = widget.defaults.morning;
      _evening = widget.defaults.evening;
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final dirty =
        _morning != widget.defaults.morning || _evening != widget.defaults.evening;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.tune_rounded, size: 19, color: crm.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Default capacity',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary)),
                  Text('Every day without a custom limit',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _stepper(context, 'Morning', _morning,
              (v) => setState(() => _morning = v),
              icon: Icons.wb_sunny_outlined, color: const Color(0xFFD97706)),
          const SizedBox(height: 10),
          _stepper(context, 'Evening', _evening,
              (v) => setState(() => _evening = v),
              icon: Icons.nights_stay_outlined, color: const Color(0xFF6E1423)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bookings allowed per day',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary)),
                      const SizedBox(height: 2),
                      Text('A day closes once it reaches this.',
                          style: TextStyle(
                              fontSize: 11.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
                Text('${_morning + _evening}',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: crm.primary)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (dirty)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _morning = widget.defaults.morning;
                            _evening = widget.defaults.evening;
                          }),
                  child: const Text('Undo'),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: (!dirty || _saving)
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await ref
                              .read(slotServiceProvider)
                              .updateDefaults(morning: _morning, evening: _evening);
                          await widget.onSaved();
                          if (context.mounted) {
                            showSuccessSnackBar(context, 'Default capacity saved');
                          }
                        } catch (e) {
                          if (context.mounted) showErrorSnackBar(context, e);
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save default'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A labelled − value + stepper (0..99) in a soft tile.
Widget _stepper(
  BuildContext context,
  String label,
  int value,
  ValueChanged<int> onChanged, {
  IconData icon = Icons.schedule_rounded,
  Color? color,
}) {
  final crm = context.crmColors;
  final c = color ?? crm.primary;
  Widget btn(IconData i, VoidCallback? onTap) => Material(
        color: onTap == null ? crm.input : c.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(i,
                size: 18,
                color: onTap == null
                    ? crm.textSecondary.withValues(alpha: 0.5)
                    : c),
          ),
        ),
      );
  return Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      border: Border.all(color: crm.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 10),
        Expanded(
            child: Text('$label slots',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: crm.textPrimary))),
        btn(Icons.remove_rounded, value <= 0 ? null : () => onChanged(value - 1)),
        SizedBox(
          width: 40,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary)),
        ),
        btn(Icons.add_rounded, value >= 99 ? null : () => onChanged(value + 1)),
      ],
    ),
  );
}

// ── Layout pieces ───────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: child,
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Material(
      color: crm.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: crm.border),
          ),
          child: Icon(icon, color: crm.textPrimary),
        ),
      ),
    );
  }
}

/// Utilisation colour: green → amber → red (full) ; grey for blocked/no cap.
Color _loadColor(CrmTheme crm, DaySlot d) {
  if (d.blocked) return crm.destructive;
  final cap = d.total.capacity;
  if (cap <= 0) return crm.textSecondary;
  final r = d.total.booked / cap;
  if (d.total.isFull) return crm.destructive;
  if (r >= 0.6) return crm.warning;
  return crm.success;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.month, required this.width});
  final MonthAvailability month;
  final double width;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final days = month.days;
    final full = days.where((d) => !d.blocked && d.total.isFull).length;
    final blocked = days.where((d) => d.blocked).length;
    final custom = days.where((d) => d.isOverride).length;
    final cap = month.totalCapacity;
    final util = cap <= 0 ? 0 : (month.totalBooked / cap * 100).round();

    final items = [
      ('Capacity', '$cap', 'bookings this month', Icons.event_seat_outlined, crm.primary),
      ('Booked', '${month.totalBooked}', '$util% utilised', Icons.event_available_outlined, crm.accent),
      ('Available', '${month.totalAvailable}', 'slots left', Icons.event_note_outlined, crm.success),
      ('Full days', '$full', 'no slots left', Icons.do_not_disturb_on_outlined, crm.warning),
      ('Blocked days', '$blocked', 'closed for booking', Icons.block_rounded, crm.destructive),
      ('Custom limits', '$custom', 'days overridden', Icons.push_pin_outlined, const Color(0xFF9E2B43)),
    ];
    final cols = width < 520 ? 2 : (width < 1000 ? 3 : 6);
    const gap = 12.0;
    final w = (width - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final it in items)
          SizedBox(
            width: w,
            child: Container(
              height: 100,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: crm.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(it.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: crm.textSecondary)),
                    ),
                    Icon(it.$4, size: 17, color: it.$5),
                  ]),
                  const Spacer(),
                  Text(it.$2,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: crm.textPrimary)),
                  const SizedBox(height: 4),
                  Text(it.$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: it.$5)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid(
      {required this.month, required this.days, required this.onTapDay});
  final DateTime month;
  final List<DaySlot> days;
  final ValueChanged<DaySlot> onTapDay;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final byDay = {for (final d in days) d.date.day: d};
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday - 1; // Monday-first grid
    final count = DateTime(month.year, month.month + 1, 0).day;
    final cells = lead + count;
    final rows = (cells / 7).ceil();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return LayoutBuilder(builder: (context, box) {
      final cellW = (box.maxWidth - 6 * 6) / 7;
      final compact = cellW < 78;
      final cellH = compact ? 62.0 : 88.0;

      return Column(
        children: [
          Row(
            children: [
              for (var i = 1; i <= 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                        compact ? _weekdays[i].substring(0, 1) : _weekdays[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: i >= 6 ? crm.primary : crm.textSecondary)),
                  ),
                ),
            ],
          ),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++) ...[
                    if (c > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Builder(builder: (_) {
                        final dayNum = r * 7 + c - lead + 1;
                        if (dayNum < 1 || dayNum > count) {
                          return SizedBox(height: cellH);
                        }
                        final d = byDay[dayNum];
                        final date = DateTime(month.year, month.month, dayNum);
                        return _DayCell(
                          day: dayNum,
                          slot: d,
                          height: cellH,
                          compact: compact,
                          isToday: date == today,
                          isPast: date.isBefore(today),
                          onTap: d == null ? null : () => onTapDay(d),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.slot,
    required this.height,
    required this.compact,
    required this.isToday,
    required this.isPast,
    required this.onTap,
  });

  final int day;
  final DaySlot? slot;
  final double height;
  final bool compact;
  final bool isToday;
  final bool isPast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final d = slot;
    final color = d == null ? crm.textSecondary : _loadColor(crm, d);
    final cap = d?.total.capacity ?? 0;
    final booked = d?.total.booked ?? 0;
    final frac = d == null || cap <= 0 ? 0.0 : (booked / cap).clamp(0.0, 1.0);
    final blocked = d?.blocked ?? false;

    final tooltip = d == null
        ? ''
        : blocked
            ? 'Blocked — no bookings'
            : 'AM ${d.morning.booked}/${d.morning.capacity} · PM ${d.evening.booked}/${d.evening.capacity}'
                '${d.isOverride ? ' · custom limit' : ''}';

    return Opacity(
      opacity: isPast ? 0.55 : 1,
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: blocked
              ? crm.destructive.withValues(alpha: 0.07)
              : color.withValues(alpha: d == null ? 0.0 : 0.05),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              height: height,
              padding: EdgeInsets.all(compact ? 5 : 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isToday
                      ? crm.primary
                      : (blocked
                          ? crm.destructive.withValues(alpha: 0.35)
                          : crm.border),
                  width: isToday ? 1.6 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('$day',
                          style: TextStyle(
                              fontSize: compact ? 12.5 : 14,
                              fontWeight: FontWeight.w800,
                              color: isToday ? crm.primary : crm.textPrimary)),
                      const Spacer(),
                      if (blocked)
                        Icon(Icons.block_rounded,
                            size: compact ? 11 : 14, color: crm.destructive)
                      else if (d?.isOverride ?? false)
                        Icon(Icons.push_pin_rounded,
                            size: compact ? 11 : 13, color: crm.primary),
                    ],
                  ),
                  const Spacer(),
                  if (d != null && !blocked) ...[
                    Text(
                      d.total.isFull ? 'Full' : '$booked/$cap',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                          fontSize: compact ? 10.5 : 12,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 1),
                      Text('${d.total.available} left',
                          style: TextStyle(
                              fontSize: 10.5, color: crm.textSecondary)),
                    ],
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: compact ? 3 : 4,
                        backgroundColor: crm.input,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ] else if (blocked)
                    Text(compact ? '—' : 'Blocked',
                        style: TextStyle(
                            fontSize: compact ? 10.5 : 11.5,
                            fontWeight: FontWeight.w700,
                            color: crm.destructive)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ]);
    Widget icon(IconData i, Color c, String label) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 13, color: c),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ]);
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        dot(crm.success, 'Open'),
        dot(crm.warning, 'Filling up (60%+)'),
        dot(crm.destructive, 'Full'),
        icon(Icons.block_rounded, crm.destructive, 'Blocked'),
        icon(Icons.push_pin_rounded, crm.primary, 'Custom limit'),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  border: Border.all(color: crm.primary, width: 1.6),
                  borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text('Today', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ]),
      ],
    );
  }
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
    setState(() => _saving = true);
    try {
      await ref.read(blockedDateServiceProvider)
          .saveBlockedDate(date: _picked!, reason: _reason.text.trim(), active: true);
      ref.refreshData.slots(); // blocked list + month availability
      if (mounted) {
        setState(() {
          _picked = null;
          _reason.clear();
        });
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(blockedDateServiceProvider).deleteBlockedDate(id);
      ref.refreshData.slots(); // blocked list + month availability
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
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

/// Dialog to jump to any month: year stepper + 12-month grid.
class _MonthYearPicker extends StatefulWidget {
  const _MonthYearPicker({required this.initial});
  final DateTime initial;

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int _year = widget.initial.year;

  static const _minYear = 2020;
  static const _maxYear = 2040;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final now = DateTime.now();

    Widget yearBtn(IconData icon, int delta) {
      final next = _year + delta;
      final enabled = next >= _minYear && next <= _maxYear;
      return IconButton(
        onPressed: enabled ? () => setState(() => _year = next) : null,
        icon: Icon(icon),
      );
    }

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  yearBtn(Icons.chevron_left_rounded, -1),
                  Expanded(
                    child: PopupMenuButton<int>(
                      tooltip: 'Choose year',
                      initialValue: _year,
                      onSelected: (y) => setState(() => _year = y),
                      itemBuilder: (_) => [
                        for (var y = _maxYear; y >= _minYear; y--)
                          CheckedPopupMenuItem(
                              value: y, checked: y == _year, child: Text('$y')),
                      ],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$_year',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: crm.textPrimary)),
                          Icon(Icons.expand_more_rounded,
                              color: crm.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  yearBtn(Icons.chevron_right_rounded, 1),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: [
                  for (var m = 1; m <= 12; m++)
                    Builder(builder: (_) {
                      final selected = _year == widget.initial.year &&
                          m == widget.initial.month;
                      final current = _year == now.year && m == now.month;
                      return Material(
                        color: selected ? crm.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () =>
                              Navigator.pop(context, DateTime(_year, m)),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? crm.primary
                                    : (current ? crm.primary : crm.border),
                                width: current && !selected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              _monthNames[m].substring(0, 3),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : (current ? crm.primary : crm.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(
                        context, DateTime(now.year, now.month)),
                    child: const Text('This month'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}