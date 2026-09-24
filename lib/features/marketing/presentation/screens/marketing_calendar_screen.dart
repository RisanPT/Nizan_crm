import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';
import 'package:nizan_crm/features/slots/data/slot_models.dart';
import 'package:nizan_crm/features/slots/services/slot_service.dart';

/// Sales Calendar — a year-over-year booking comparison for the marketing team.
/// A navigable month grid where each day is heat-mapped by booking volume and,
/// on hover (or tap), shows this year's bookings/revenue beside the EXACT same
/// date one year earlier, with the delta. Plus YoY summary cards and a 12-month
/// this-year-vs-last-year strip. Built on `bookingDate` (the real event date).
/// One "prodate" — a peak event day (>= the threshold bookings) for the list.
class _Prodate {
  final DateTime date;
  final int bookings;
  final double revenue;
  const _Prodate({required this.date, required this.bookings, required this.revenue});
}

class MarketingCalendarScreen extends ConsumerStatefulWidget {
  const MarketingCalendarScreen({super.key});

  @override
  ConsumerState<MarketingCalendarScreen> createState() =>
      _MarketingCalendarScreenState();
}

class _MarketingCalendarScreenState
    extends ConsumerState<MarketingCalendarScreen> {
  int _month = DateTime.now().month - 1; // 0-11, displayed month
  bool _revenue = false; // metric: bookings ⇄ revenue

  // Prodate finder: an EVENT date with >= [_minProdate] bookings is a "prodate"
  // (a productive/peak day). Default 16 == "more than 15". Adjustable in the UI.
  int _minProdate = 16;
  bool _prodatesOnly = false; // dim non-prodate days so the peaks stand out

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final year = ref.watch(calendarYearProvider);
    final basis = ref.watch(calendarBasisProvider);
    final async = ref.watch(bookingCalendarProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(bookingCalendarProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding:
              EdgeInsets.fromLTRB(isMobile ? 14 : 24, 18, isMobile ? 14 : 24, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sales Calendar',
                          style: TextStyle(
                              fontSize: isMobile ? 22 : 27,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      Text('Year-over-year booking comparison',
                          style:
                              TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
                _yearButton(crm, year),
              ],
            ),
            14.hg,
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: Text(e.toString().replaceFirst('Exception: ', ''),
                      style: TextStyle(color: crm.textSecondary)),
                ),
              ),
              data: (d) {
                // Clamp displayed month if it somehow drifted out of range.
                final m = _month.clamp(0, 11);

                // Slot-availability overlay — only in EVENT-date mode, since
                // slots are event-day capacity (meaningless against sales dates).
                final slotsByDay = <String, DaySlot>{};
                if (basis == 'event') {
                  final ma = ref
                      .watch(monthAvailabilityProvider((year: d.year, month: m + 1)))
                      .value;
                  if (ma != null) {
                    for (final day in ma.days) {
                      slotsByDay[_ymd(day.date)] = day;
                    }
                  }
                }

                // Prodate finder — EVENT-date mode only (a prodate is a peak
                // EVENT day). Days this year with >= _minProdate bookings.
                final prodateActive = basis == 'event';
                final prodateDays = <String>{};
                final prodates = <_Prodate>[];
                if (prodateActive) {
                  d.current.forEach((key, v) {
                    if (v.bookings >= _minProdate) {
                      prodateDays.add(key);
                      final dt = DateTime.tryParse(key);
                      if (dt != null) {
                        prodates.add(_Prodate(
                            date: dt, bookings: v.bookings, revenue: v.revenue));
                      }
                    }
                  });
                  prodates.sort((a, b) => a.date.compareTo(b.date));
                }

                final calSubtitle = basis == 'sales'
                    ? 'By SALES date (when the booking was made) — hover or tap a day to compare with ${d.prevYear}'
                    : 'By EVENT date — hover or tap a day for details, slots left, and the same date in ${d.prevYear}';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _controlsRow(crm, basis, prodateActive ? prodates : null),
                    12.hg,
                    _summaryCard(crm, isMobile, d),
                    14.hg,
                    _card(
                      crm,
                      'Calendar',
                      _calendarBody(context, crm, isMobile, d, m, slotsByDay,
                          prodateDays, prodateActive && _prodatesOnly),
                      subtitle: calSubtitle,
                    ),
                    14.hg,
                    _card(crm, 'Monthly comparison — ${d.year} vs ${d.prevYear}',
                        _MonthStrip(crm: crm, data: d, revenue: _revenue),
                        subtitle: _revenue
                            ? 'Revenue by month, both years'
                            : 'Bookings by month, both years'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary: this year vs last year, like-for-like ──
  Widget _summaryCard(CrmTheme crm, bool isMobile, CalendarComparison d) {
    final isCurrentYear = d.year == DateTime.now().year;

    // For the running year, compare against last year up to the SAME point in
    // the year (a fair YoY), not last year's full total.
    int prevCmpB = d.prevTotalBookings;
    double prevCmpR = d.prevTotalRevenue;
    if (isCurrentYear) {
      final now = DateTime.now();
      int b = 0;
      double r = 0;
      d.previous.forEach((k, v) {
        final p = k.split('-');
        if (p.length < 3) return;
        final mm = int.tryParse(p[1]) ?? 13;
        final dd = int.tryParse(p[2]) ?? 32;
        if (mm < now.month || (mm == now.month && dd <= now.day)) {
          b += v.bookings;
          r += v.revenue;
        }
      });
      prevCmpB = b;
      prevCmpR = r;
    }

    final curB = d.curTotalBookings, curR = d.curTotalRevenue;
    final bDelta = _pct(curB.toDouble(), prevCmpB.toDouble());
    final rDelta = _pct(curR, prevCmpR);
    final periodNote = isCurrentYear
        ? 'vs ${d.prevYear} to date (same point in the year)'
        : 'vs full ${d.prevYear}';

    final tiles = [
      _statTile(crm, '${d.year} bookings', curB.toString(),
          '$prevCmpB in ${d.prevYear}', bDelta),
      _statTile(crm, '${d.year} revenue', _money(curR),
          '${_money(prevCmpR)} in ${d.prevYear}', rDelta),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  children: [
                    tiles[0],
                    12.hg,
                    Divider(color: crm.border, height: 1),
                    12.hg,
                    tiles[1],
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tiles[0]),
                      VerticalDivider(color: crm.border, width: 32),
                      Expanded(child: tiles[1]),
                    ],
                  ),
                ),
          10.hg,
          Text(periodNote,
              style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        ],
      ),
    );
  }

  Widget _statTile(
      CrmTheme crm, String label, String value, String sub, double? deltaPct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: crm.textSecondary)),
        6.hg,
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: crm.textPrimary)),
            8.wg,
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _deltaChip(deltaPct),
            ),
          ],
        ),
        4.hg,
        Text(sub, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
      ],
    );
  }

  // ── Calendar body: month nav + weekday header + day grid + legend ──
  Widget _calendarBody(BuildContext context, CrmTheme crm, bool isMobile,
      CalendarComparison d, int m, Map<String, DaySlot> slotsByDay,
      Set<String> prodateDays, bool dimNonProdate) {
    final year = d.year;
    final first = DateTime(year, m + 1, 1);
    final daysInMonth = DateTime(year, m + 2, 0).day;
    final leadingBlanks = first.weekday % 7; // Sun-first grid (Sun=0)

    // Heatmap scale = the month's busiest day (by the active metric).
    double monthMax = 1;
    for (var day = 1; day <= daysInMonth; day++) {
      final v = _cellVal(d.curFor(DateTime(year, m + 1, day)));
      if (v > monthMax) monthMax = v;
    }

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _dayCell(context, crm, DateTime(year, m + 1, day), d, monthMax,
            slotsByDay[_ymd(DateTime(year, m + 1, day))],
            prodateDays.contains(_ymd(DateTime(year, m + 1, day))), dimNonProdate),
    ];

    const week = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month navigator
        Row(
          children: [
            _navBtn(crm, Icons.chevron_left, () => _stepMonth(-1)),
            8.wg,
            _navBtn(crm, Icons.chevron_right, () => _stepMonth(1)),
            10.wg,
            Expanded(
              child: Text('${_monthName(m)} $year',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
            ),
            if (!_isViewingCurrentMonth())
              TextButton.icon(
                onPressed: _goToToday,
                icon: const Icon(Icons.today_outlined, size: 16),
                label: const Text('Today'),
                style: TextButton.styleFrom(
                  foregroundColor: crm.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        12.hg,
        // Weekday header
        Row(
          children: [
            for (final w in week)
              Expanded(
                child: Center(
                  child: Text(isMobile ? w[0] : w,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: crm.textSecondary)),
                ),
              ),
          ],
        ),
        8.hg,
        // Fixed cell HEIGHT (not aspect-ratio) so the month stays compact on
        // wide screens instead of ballooning into a huge, scroll-heavy grid.
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            mainAxisExtent: isMobile ? 60 : 82,
          ),
          children: cells,
        ),
        14.hg,
        _legend(crm, slotsByDay.isNotEmpty, prodateDays.isNotEmpty || dimNonProdate),
      ],
    );
  }

  Widget _dayCell(BuildContext context, CrmTheme crm, DateTime date,
      CalendarComparison d, double monthMax, DaySlot? slot, bool isProdate,
      bool dimNonProdate) {
    final cur = d.curFor(date);
    final prev = d.prevSameDay(date);
    final curV = _cellVal(cur);
    final prevV = _cellVal(prev);

    // Discrete heat level: absolute booking-count buckets (so the same colour
    // always means the same volume, month to month) — or, in revenue mode,
    // quartiles of the busiest day this month.
    final hasData = cur.bookings > 0;
    final level = _revenue
        ? _relLevel(cur.revenue, monthMax)
        : _bookingLevel(cur.bookings);
    final bg = level == 0 ? crm.background : _heatScale[level - 1];
    final darkCell = level >= 3; // top two levels need light text
    final numColor = darkCell ? Colors.white : crm.textPrimary;
    final isToday = _isToday(date);

    final centerLabel = hasData
        ? (_revenue ? _compact(cur.revenue) : '${cur.bookings}')
        : '';

    // Prodate = a peak EVENT day (>= _minProdate bookings). Gold ring + 🔥.
    final borderColor = isToday
        ? crm.primary
        : (isProdate ? _prodateColor : crm.border);
    final borderWidth = isToday ? 1.6 : (isProdate ? 2.2 : 1.0);

    Widget cell = Tooltip(
      richMessage: _tooltipSpan(crm, date, cur, prev, slot, isProdate),
      waitDuration: const Duration(milliseconds: 150),
      preferBelow: false,
      decoration: BoxDecoration(
        color: crm.textPrimary,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        onTap: () => _showDayDetail(context, crm, date, cur, prev, slot, isProdate),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isProdate) ...[
                    const Text('🔥', style: TextStyle(fontSize: 10)),
                    2.wg,
                  ],
                  Text('${date.day}',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: darkCell
                              ? Colors.white.withValues(alpha: 0.9)
                              : crm.textSecondary)),
                  const Spacer(),
                  if (slot != null && _isFutureOrToday(date)) _slotChip(slot, darkCell),
                ],
              ),
              Expanded(
                child: Center(
                  child: Text(centerLabel,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: numColor)),
                ),
              ),
              if (curV > 0 || prevV > 0)
                _yoyMini(crm, curV - prevV, darkCell),
            ],
          ),
        ),
      ),
    );
    // "Prodates only" → fade the rest so the peaks pop.
    if (dimNonProdate && !isProdate) {
      cell = Opacity(opacity: 0.3, child: cell);
    }
    return cell;
  }

  // Tiny YoY indicator inside a day cell.
  Widget _yoyMini(CrmTheme crm, double delta, bool darkCell) {
    final up = delta >= 0;
    final flat = delta == 0;
    // On deep-green cells, use bright tints so the ▲/▼ stays legible.
    final Color onHeat = flat
        ? Colors.white.withValues(alpha: 0.85)
        : darkCell
            ? (up ? const Color(0xFFB9F6CA) : const Color(0xFFFFCDD2))
            : (up ? const Color(0xFF15803D) : const Color(0xFFDC2626));
    final label = flat
        ? '='
        : '${up ? '▲' : '▼'}${_compact(delta.abs())}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 8.5, fontWeight: FontWeight.w800, color: onHeat)),
      ],
    );
  }

  InlineSpan _tooltipSpan(
      CrmTheme crm, DateTime date, DayStat cur, DayStat prev, DaySlot? slot,
      bool isProdate) {
    final white = const TextStyle(color: Colors.white, fontSize: 11.5);
    final whiteBold = const TextStyle(
        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800);
    final dim = TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11);
    final dB = cur.bookings - prev.bookings;
    final dcolor = dB > 0
        ? const Color(0xFF4ADE80)
        : (dB < 0 ? const Color(0xFFFF8A80) : Colors.white);
    final showSlot = slot != null && _isFutureOrToday(date);
    return TextSpan(children: [
      TextSpan(text: '${_dow(date)}, ${date.day} ${_monShort(date.month)} ${date.year}\n', style: whiteBold),
      TextSpan(
          text: '${cur.bookings} booking${cur.bookings == 1 ? '' : 's'}'
              '${cur.revenue > 0 ? ' · ${_money(cur.revenue)}' : ''}\n',
          style: white),
      TextSpan(
          text: 'Last year (${date.day} ${_monShort(date.month)} ${date.year - 1}): '
              '${prev.bookings} booking${prev.bookings == 1 ? '' : 's'}'
              '${prev.revenue > 0 ? ' · ${_money(prev.revenue)}' : ''}\n',
          style: dim),
      TextSpan(
          text: 'Δ ${dB >= 0 ? '+' : ''}$dB booking${dB.abs() == 1 ? '' : 's'} YoY'
              '${showSlot ? '\n' : ''}',
          style: TextStyle(
              color: dcolor, fontSize: 11.5, fontWeight: FontWeight.w700)),
      if (showSlot)
        TextSpan(
          text: slot.blocked
              ? 'Slots: blocked by HR'
              : slot.unavailable
                  ? 'Slots: FULL (${slot.total.booked}/${slot.total.capacity})'
                  : 'Slots left: ${slot.available}/${slot.total.capacity}'
                      '  ·  AM ${slot.morning.available}/${slot.morning.capacity}'
                      ' · PM ${slot.evening.available}/${slot.evening.capacity}',
          style: TextStyle(
              color: slot.unavailable
                  ? const Color(0xFFFF8A80)
                  : const Color(0xFF7DD3FC),
              fontSize: 11,
              fontWeight: FontWeight.w700),
        ),
      if (isProdate)
        TextSpan(
          text: '\n🔥 Prodate — ${cur.bookings} bookings (≥ $_minProdate)',
          style: const TextStyle(
              color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w800),
        ),
    ]);
  }

  void _showDayDetail(BuildContext context, CrmTheme crm, DateTime date,
      DayStat cur, DayStat prev, DaySlot? slot, bool isProdate) {
    final dB = cur.bookings - prev.bookings;
    final dR = cur.revenue - prev.revenue;
    showDialog<void>(
      context: context,
      // Keep the dialog's own context: closing with the outer page context
      // resolves to the shell Navigator and pops the whole route instead of
      // just this dialog. Matches the other dialogs in this file.
      builder: (dctx) => AlertDialog(
        backgroundColor: crm.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${_dow(date)}, ${date.day} ${_monShort(date.month)} ${date.year}',
            style: TextStyle(
                color: crm.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isProdate) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _prodateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _prodateColor.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  8.wg,
                  Expanded(
                    child: Text(
                      'Prodate — ${cur.bookings} bookings (≥ $_minProdate). A peak event day.',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _prodateColor),
                    ),
                  ),
                ]),
              ),
              12.hg,
            ],
            _detailRow(crm, '${date.year}', cur, highlight: true),
            10.hg,
            _detailRow(
                crm, '${date.year - 1} (same date)', prev,
                highlight: false),
            12.hg,
            Divider(color: crm.border, height: 1),
            12.hg,
            Row(
              children: [
                Expanded(
                  child: _deltaLine(crm, 'Bookings',
                      '${dB >= 0 ? '+' : ''}$dB', _pct(cur.bookings.toDouble(), prev.bookings.toDouble())),
                ),
                Expanded(
                  child: _deltaLine(crm, 'Revenue',
                      '${dR >= 0 ? '+' : ''}${_money(dR)}', _pct(cur.revenue, prev.revenue)),
                ),
              ],
            ),
            if (slot != null && _isFutureOrToday(date)) ...[
              12.hg,
              Divider(color: crm.border, height: 1),
              12.hg,
              _slotDetail(crm, slot),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(CrmTheme crm, String label, DayStat s,
      {required bool highlight}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? crm.primary.withValues(alpha: 0.08)
            : crm.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: crm.textPrimary)),
          ),
          Text('${s.bookings} booking${s.bookings == 1 ? '' : 's'}',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: crm.textPrimary)),
          if (s.revenue > 0) ...[
            8.wg,
            Text(_money(s.revenue),
                style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _deltaLine(CrmTheme crm, String label, String delta, double? pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        4.hg,
        Row(
          children: [
            Text(delta,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: crm.textPrimary)),
            6.wg,
            _deltaChip(pct),
          ],
        ),
      ],
    );
  }

  Widget _legend(CrmTheme crm, bool showSlots, bool showProdate) {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: crm.border),
              ),
            ),
            5.wg,
            Text(label,
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ],
        );
    final labels =
        _revenue ? ['Low', 'Fair', 'High', 'Top'] : ['1–2', '3–5', '6–9', '10+'];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(_revenue ? 'Revenue/day:' : 'Bookings/day:',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: crm.textSecondary)),
        for (var i = 0; i < _heatScale.length; i++)
          item(_heatScale[i], labels[i]),
        16.wg,
        Text('▲/▼ vs same day last year',
            style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        if (showSlots) ...[
          16.wg,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_seat_outlined, size: 13, color: crm.textSecondary),
            5.wg,
            Text('N = slots left (blue) · full (red), today & later',
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ]),
        ],
        if (showProdate) ...[
          16.wg,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _prodateColor, width: 2),
              ),
            ),
            5.wg,
            Text('🔥 prodate (≥ $_minProdate bookings)',
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ]),
        ],
      ],
    );
  }

  // Compact per-cell "slots left" badge (event-date mode, today & future).
  Widget _slotChip(DaySlot slot, bool darkCell) {
    final full = slot.unavailable;
    final base = full ? const Color(0xFFDC2626) : const Color(0xFF0369A1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
      decoration: BoxDecoration(
        color: base.withValues(alpha: darkCell ? 0.35 : 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text('${slot.available}',
          style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: darkCell ? Colors.white : base)),
    );
  }

  // Full slot-availability breakdown for the day-detail dialog.
  Widget _slotDetail(CrmTheme crm, DaySlot slot) {
    final full = slot.unavailable;
    Widget half(String label, SlotHalf h) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            4.hg,
            Text('${h.available} left',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: h.isFull ? const Color(0xFFDC2626) : crm.textPrimary)),
            Text('${h.booked}/${h.capacity} booked',
                style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.event_seat_outlined, size: 15, color: crm.textSecondary),
        6.wg,
        Text('Slot availability',
            style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (full ? const Color(0xFFDC2626) : const Color(0xFF16A34A))
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            slot.blocked
                ? 'Blocked by HR'
                : (full ? 'Full' : '${slot.available} slots left'),
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: full ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
          ),
        ),
      ]),
      10.hg,
      Row(children: [half('Morning', slot.morning), 12.wg, half('Evening', slot.evening)]),
    ]);
  }

  // ── Controls: metric (Bookings|Revenue) + date basis (Event|Sales) ──
  // [prodates] non-null (event mode) → show the Prodate Finder controls.
  Widget _controlsRow(CrmTheme crm, String basis, List<_Prodate>? prodates) {
    Widget seg(String label, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: active ? crm.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : crm.textSecondary)),
          ),
        );
    Widget group(List<Widget> children) => Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: crm.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        );
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        group([
          seg('Bookings', !_revenue, () => setState(() => _revenue = false)),
          seg('Revenue', _revenue, () => setState(() => _revenue = true)),
        ]),
        group([
          seg('Event date', basis == 'event',
              () => ref.read(calendarBasisProvider.notifier).state = 'event'),
          seg('Sales date', basis == 'sales',
              () => ref.read(calendarBasisProvider.notifier).state = 'sales'),
        ]),
        // Two small pills (not one wide one) so they wrap cleanly on phones.
        if (prodates != null) ...[
          _prodateThresholdPill(crm),
          _prodateViewPill(crm, prodates),
        ],
      ],
    );
  }

  BoxDecoration get _prodatePillDeco => BoxDecoration(
        color: _prodateColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _prodateColor.withValues(alpha: 0.45)),
      );

  // Pill 1: adjustable "Prodate ≥ N" threshold with −/+ steppers.
  Widget _prodateThresholdPill(CrmTheme crm) {
    Widget stepBtn(IconData icon, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(icon, size: 16, color: _prodateColor),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: _prodatePillDeco,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🔥', style: TextStyle(fontSize: 12)),
        4.wg,
        Text('Prodate ≥',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _prodateColor)),
        4.wg,
        stepBtn(Icons.remove_circle_outline,
            () => setState(() => _minProdate = (_minProdate - 1).clamp(2, 200))),
        SizedBox(
          width: 22,
          child: Text('$_minProdate',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: crm.textPrimary)),
        ),
        stepBtn(Icons.add_circle_outline,
            () => setState(() => _minProdate = (_minProdate + 1).clamp(2, 200))),
      ]),
    );
  }

  // Pill 2: "Only" toggle + tappable "N this year" opening the year list.
  Widget _prodateViewPill(CrmTheme crm, List<_Prodate> prodates) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: _prodatePillDeco,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: () => setState(() => _prodatesOnly = !_prodatesOnly),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_prodatesOnly ? Icons.check_box : Icons.check_box_outline_blank,
                size: 16, color: _prodateColor),
            3.wg,
            Text('Only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _prodateColor)),
          ]),
        ),
        6.wg,
        Container(width: 1, height: 18, color: _prodateColor.withValues(alpha: 0.3)),
        6.wg,
        // Tap → the whole-year prodate list (no month navigation needed).
        InkWell(
          onTap: () => _showProdatesDialog(crm, prodates),
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${prodates.length} this year',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800, color: _prodateColor)),
              2.wg,
              Icon(Icons.format_list_bulleted_rounded, size: 14, color: _prodateColor),
            ]),
          ),
        ),
      ]),
    );
  }

  // The whole-year prodate list in one dialog — every peak event date, grouped
  // by month, so the team sees them all without paging the calendar.
  void _showProdatesDialog(CrmTheme crm, List<_Prodate> prodates) {
    final year = ref.read(calendarYearProvider);
    showDialog<void>(
      context: context,
      builder: (dctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('🔥', style: TextStyle(fontSize: 18)),
                8.wg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prodates in $year',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: crm.textPrimary)),
                      2.hg,
                      Text('${prodates.length} peak day${prodates.length == 1 ? '' : 's'} · ≥ $_minProdate bookings',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(dctx),
                  icon: Icon(Icons.close, size: 18, color: crm.textSecondary),
                ),
              ]),
              14.hg,
              if (prodates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text('No prodates at ≥ $_minProdate bookings this year.',
                        style: TextStyle(color: crm.textSecondary)),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _prodateRows(dctx, crm, prodates),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Prodate rows grouped under month headers (chronological).
  List<Widget> _prodateRows(BuildContext dctx, CrmTheme crm, List<_Prodate> prodates) {
    final rows = <Widget>[];
    int? lastMonth;
    for (final p in prodates) {
      if (p.date.month != lastMonth) {
        lastMonth = p.date.month;
        rows.add(Padding(
          padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 14, bottom: 6),
          child: Text('${_monthName(p.date.month - 1)} ${p.date.year}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: crm.textSecondary,
                  letterSpacing: 0.3)),
        ));
      }
      rows.add(InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // Jump the calendar to that month (optional convenience).
          setState(() => _month = p.date.month - 1);
          Navigator.pop(dctx);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _prodateColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _prodateColor.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: _prodateColor, shape: BoxShape.circle),
            ),
            10.wg,
            Expanded(
              child: Text('${_dow(p.date)}, ${p.date.day} ${_monShort(p.date.month)} ${p.date.year}',
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            ),
            Text('${p.bookings} bookings',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900, color: _prodateColor)),
            if (p.revenue > 0) ...[
              8.wg,
              Text(_money(p.revenue),
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ],
            4.wg,
            Icon(Icons.chevron_right, size: 16, color: crm.textSecondary),
          ]),
        ),
      ));
    }
    return rows;
  }

  // Calendar-year range for the picker: a few past years for history through
  // 2035 for forward planning (future events + slot capacity).
  static const int _minYear = 2021;
  static const int _maxYear = 2035;

  // Trigger button that opens the year-grid picker.
  Widget _yearButton(CrmTheme crm, int value) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _pickYear(crm, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined, size: 16, color: crm.primary),
            8.wg,
            Text('$value',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary)),
            2.wg,
            Icon(Icons.keyboard_arrow_down, size: 18, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }

  // A calendar-style year picker: a grid of years, current selection filled,
  // "this year" ringed. Nicer + far more scannable than a long dropdown.
  Future<void> _pickYear(CrmTheme crm, int selected) async {
    final now = DateTime.now().year;
    final years = [for (var y = _minYear; y <= _maxYear; y++) y];

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: crm.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.calendar_month_outlined, size: 18, color: crm.primary),
                  8.wg,
                  Text('Select year',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary)),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, size: 18, color: crm.textSecondary),
                  ),
                ]),
                14.hg,
                Flexible(
                  child: SingleChildScrollView(
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: [
                        for (final y in years)
                          _yearTile(crm, y, y == selected, y == now,
                              () => Navigator.pop(ctx, y)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (picked != null && picked != ref.read(calendarYearProvider)) {
      ref.read(calendarYearProvider.notifier).state = picked;
      ref.invalidate(bookingCalendarProvider);
    }
  }

  Widget _yearTile(
      CrmTheme crm, int year, bool selected, bool isNow, VoidCallback onTap) {
    final borderColor = selected
        ? crm.primary
        : (isNow ? crm.primary.withValues(alpha: 0.55) : crm.border);
    return Material(
      color: selected ? crm.primary : crm.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: borderColor, width: (isNow && !selected) ? 1.5 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$year',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : crm.textPrimary)),
              if (isNow)
                Text('this year',
                    style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.85)
                            : crm.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(CrmTheme crm, IconData icon, VoidCallback onTap) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: crm.textPrimary),
        style: IconButton.styleFrom(
          backgroundColor: crm.background,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: crm.border)),
        ),
      );

  bool _isViewingCurrentMonth() {
    final now = DateTime.now();
    return ref.read(calendarYearProvider) == now.year && _month == now.month - 1;
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() => _month = now.month - 1);
    if (ref.read(calendarYearProvider) != now.year) {
      ref.read(calendarYearProvider.notifier).state = now.year;
      ref.invalidate(bookingCalendarProvider);
    }
  }

  void _stepMonth(int delta) {
    setState(() {
      var m = _month + delta;
      var year = ref.read(calendarYearProvider);
      if (m < 0) {
        m = 11;
        year -= 1;
      } else if (m > 11) {
        m = 0;
        year += 1;
      }
      _month = m;
      if (year != ref.read(calendarYearProvider)) {
        ref.read(calendarYearProvider.notifier).state = year;
        ref.invalidate(bookingCalendarProvider);
      }
    });
  }

  Widget _deltaChip(double? pct) {
    if (pct == null) {
      return const SizedBox.shrink();
    }
    final up = pct >= 0;
    final color = pct == 0
        ? const Color(0xFF6B7280)
        : (up ? const Color(0xFF16A34A) : const Color(0xFFDC2626));
    final label = pct == 0
        ? '0%'
        : '${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _card(CrmTheme crm, String title, Widget child, {String? subtitle}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: crm.textPrimary)),
            if (subtitle != null) ...[
              2.hg,
              Text(subtitle,
                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ],
            14.hg,
            child,
          ],
        ),
      );

  // ── helpers ──
  double _cellVal(DayStat s) => _revenue ? s.revenue : s.bookings.toDouble();

  // Sequential "more bookings = greener" heat scale — 4 filled levels (level 0 =
  // no bookings, drawn in the card background). Discrete, well-separated steps
  // read far more clearly than a single-hue fade, and green reads as "busy/good"
  // for a sales calendar.
  static const List<Color> _heatScale = [
    Color(0xFFDCF3DD), // 1 — lightest
    Color(0xFF9BD9A2), // 2
    Color(0xFF4BAE68), // 3 (light text)
    Color(0xFF1F7A44), // 4 — busiest (light text)
  ];

  // Amber ring/marker for "prodates" (peak event days) — distinct from the
  // green booking heat so peaks pop against it.
  static const Color _prodateColor = Color(0xFFB45309);

  // Absolute booking-count → level (0 empty, 1..4). Absolute (not per-month)
  // buckets mean the same colour always represents the same day volume.
  int _bookingLevel(int n) {
    if (n <= 0) return 0;
    if (n <= 2) return 1;
    if (n <= 5) return 2;
    if (n <= 9) return 3;
    return 4;
  }

  // Revenue → level by quartile of the month's busiest day (revenue scales vary
  // too much for absolute rupee buckets to be meaningful).
  int _relLevel(double v, double max) {
    if (v <= 0) return 0;
    final t = max > 0 ? (v / max).clamp(0.0, 1.0) : 0.0;
    if (t <= 0.25) return 1;
    if (t <= 0.5) return 2;
    if (t <= 0.75) return 3;
    return 4;
  }

  /// Percentage change from [prev] to [cur]. null when there is no basis
  /// (prev == 0 and cur == 0 → no change to show).
  double? _pct(double cur, double prev) {
    if (prev == 0) return cur == 0 ? null : 100.0;
    return ((cur - prev) / prev) * 100.0;
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  // Slot availability only makes sense for days you can still sell into.
  bool _isFutureOrToday(DateTime d) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return !DateTime(d.year, d.month, d.day).isBefore(today);
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December'
  ];
  static const _monShorts = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
    'Nov', 'Dec'
  ];
  static const _dows = [
    '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  String _monthName(int m0) => _months[m0.clamp(0, 11)];
  String _monShort(int m1) => _monShorts[m1.clamp(0, 12)];
  String _dow(DateTime d) => _dows[d.weekday.clamp(1, 7)];

  static String _money(double v) {
    final neg = v < 0;
    final a = v.abs();
    String s;
    if (a >= 10000000) {
      s = '₹${(a / 10000000).toStringAsFixed(1)}Cr';
    } else if (a >= 100000) {
      s = '₹${(a / 100000).toStringAsFixed(1)}L';
    } else if (a >= 1000) {
      s = '₹${(a / 1000).toStringAsFixed(0)}k';
    } else {
      s = '₹${a.toStringAsFixed(0)}';
    }
    return neg ? '-$s' : s;
  }

  static String _compact(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toInt().toString();
  }
}

// ── 12-month this-year vs last-year grouped bars ──────────────────────────────
class _MonthStrip extends StatelessWidget {
  final CrmTheme crm;
  final CalendarComparison data;
  final bool revenue;
  const _MonthStrip(
      {required this.crm, required this.data, required this.revenue});

  double _cur(MonthYoY m) => revenue ? m.curRevenue : m.curBookings.toDouble();
  double _prev(MonthYoY m) => revenue ? m.prevRevenue : m.prevBookings.toDouble();

  static const _letters = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
  ];

  @override
  Widget build(BuildContext context) {
    final months = data.byMonth;
    if (months.isEmpty) {
      return Text('No data.',
          style: TextStyle(color: crm.textSecondary, fontSize: 13));
    }
    double maxV = 1;
    for (final m in months) {
      maxV = [maxV, _cur(m), _prev(m)].reduce((a, b) => a > b ? a : b);
    }
    final prevColor = crm.textSecondary.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(crm.primary, '${data.year}'),
            16.wg,
            _legendDot(prevColor, '${data.prevYear}'),
          ],
        ),
        14.hg,
        SizedBox(
          height: 180,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxV * 1.15,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => crm.textPrimary,
                getTooltipItem: (group, _, rod, rodIndex) {
                  final m = months[group.x];
                  final isCur = rodIndex == 0;
                  final year = isCur ? data.year : data.prevYear;
                  final val = isCur ? _cur(m) : _prev(m);
                  return BarTooltipItem(
                    '${_MonthStrip._letters[group.x]} · $year\n',
                    const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11),
                    children: [
                      TextSpan(
                        text: revenue
                            ? _fmtMoney(val)
                            : '${val.toInt()} bookings',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ],
                  );
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: crm.border, strokeWidth: 0.6),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (v, _) => Text(
                    revenue ? _fmtCompact(v) : v.toInt().toString(),
                    style: TextStyle(fontSize: 9, color: crm.textSecondary),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= 12) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_MonthStrip._letters[i],
                          style: TextStyle(
                              fontSize: 9.5, color: crm.textSecondary)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < months.length && i < 12; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    BarChartRodData(
                      toY: _cur(months[i]),
                      width: 7,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2)),
                      color: crm.primary,
                    ),
                    BarChartRodData(
                      toY: _prev(months[i]),
                      width: 7,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2)),
                      color: prevColor,
                    ),
                  ],
                ),
            ],
          )),
        ),
      ],
    );
  }

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11,
            height: 11,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
          ),
          6.wg,
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: crm.textPrimary)),
        ],
      );

  static String _fmtMoney(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  static String _fmtCompact(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(0)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(0)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toInt().toString();
  }
}

extension _Gap on num {
  Widget get hg => SizedBox(height: toDouble());
  Widget get wg => SizedBox(width: toDouble());
}
