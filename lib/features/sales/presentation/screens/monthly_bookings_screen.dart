import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';

const _months = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

bool _isCancelled(String status) {
  final s = status.toLowerCase();
  return s == 'cancelled' || s == 'rejected' || s == 'canceled';
}

double _balanceOf(Booking b) {
  final v = b.totalPrice - b.advanceAmount - b.discountAmount;
  return v > 0 ? v : 0.0;
}

/// Sales → Monthly Bookings. Shows every booking that falls in the selected
/// month, switchable between EVENT-date basis (`bookingDate`) and BOOKING-date
/// basis (`createdAt`), with month totals and a searchable list.
class MonthlyBookingsScreen extends HookConsumerWidget {
  const MonthlyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final now = DateTime.now();

    final month = useState<DateTime>(DateTime(now.year, now.month));
    final eventBasis = useState<bool>(true); // true = event date, false = booking date
    final query = useState<String>('');

    final bookingsAsync = ref.watch(bookingProvider);

    DateTime basisDate(Booking b) =>
        eventBasis.value ? b.bookingDate : (b.createdAt ?? b.bookingDate);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Monthly Bookings'),
        backgroundColor: crm.sidebar,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(bookingProvider),
          ),
        ],
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off_outlined, size: 48, color: crm.destructive),
              12.h,
              Text('$e', textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
              16.h,
              FilledButton.icon(
                onPressed: () => ref.invalidate(bookingProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ]),
          ),
        ),
        data: (all) {
          final m = month.value;
          // Bookings whose chosen-basis date lands in the selected month.
          var inMonth = all.where((b) {
            final d = basisDate(b);
            return d.year == m.year && d.month == m.month;
          }).toList()
            ..sort((a, b) => basisDate(b).compareTo(basisDate(a)));

          final q = query.value.trim().toLowerCase();
          final visible = q.isEmpty
              ? inMonth
              : inMonth.where((b) =>
                  b.customerName.toLowerCase().contains(q) ||
                  b.phone.toLowerCase().contains(q) ||
                  b.service.toLowerCase().contains(q) ||
                  b.displayBookingNumber.toLowerCase().contains(q)).toList();

          // Totals from the whole month (not the search subset).
          final active = inMonth.where((b) => !_isCancelled(b.status)).toList();
          final revenue = active.fold<double>(0, (s, b) => s + b.totalPrice);
          final advance = active.fold<double>(0, (s, b) => s + b.advanceAmount);
          final balance = active.fold<double>(0, (s, b) => s + _balanceOf(b));
          final cancelled = inMonth.length - active.length;

          return Column(
            children: [
              _Controls(
                month: m,
                crm: crm,
                eventBasis: eventBasis.value,
                onMonth: (v) => month.value = v,
                onBasis: (v) => eventBasis.value = v,
                onSearch: (v) => query.value = v,
              ),
              const Divider(height: 1),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(bookingProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                    children: [
                      _Stats(
                        count: inMonth.length,
                        revenue: revenue,
                        advance: advance,
                        balance: balance,
                        cancelled: cancelled,
                        crm: crm,
                      ),
                      12.h,
                      Row(
                        children: [
                          Text(
                            eventBasis.value ? 'By event date' : 'By booking (created) date',
                            style: TextStyle(fontSize: 12.5, color: crm.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text('${visible.length} shown', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                        ],
                      ),
                      10.h,
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Column(children: [
                              Icon(Icons.event_busy_outlined, size: 48, color: crm.textSecondary.withValues(alpha: 0.5)),
                              10.h,
                              Text('No bookings for ${_months[m.month]} ${m.year}.',
                                  style: TextStyle(color: crm.textSecondary)),
                            ]),
                          ),
                        )
                      else
                        ...visible.map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _BookingCard(booking: b, eventBasis: eventBasis.value, crm: crm),
                            )),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.month,
    required this.crm,
    required this.eventBasis,
    required this.onMonth,
    required this.onBasis,
    required this.onSearch,
  });
  final DateTime month;
  final CrmTheme crm;
  final bool eventBasis;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<bool> onBasis;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final monthBar = Container(
      decoration: BoxDecoration(
        color: crm.sidebar.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_left_rounded, color: crm.accent),
            onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
          ),
          Expanded(
            child: Center(
              child: Text('${_months[month.month]} ${month.year}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary, fontSize: 15)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.keyboard_arrow_right_rounded, color: crm.accent),
            onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );

    final basisToggle = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _seg('Event date', eventBasis, crm, () => onBasis(true)),
        _seg('Booking date', !eventBasis, crm, () => onBasis(false)),
      ]),
    );

    final search = SizedBox(
      height: 44,
      child: TextField(
        onChanged: onSearch,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search customer, phone, package, no…',
          hintStyle: TextStyle(fontSize: 13, color: crm.textSecondary),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: crm.textSecondary),
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: crm.surface,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.border.withValues(alpha: 0.7))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: crm.accent)),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: LayoutBuilder(builder: (ctx, c) {
        if (c.maxWidth >= 720) {
          return Row(children: [
            Expanded(flex: 2, child: monthBar),
            10.w,
            basisToggle,
            10.w,
            Expanded(flex: 2, child: search),
          ]);
        }
        return Column(children: [
          monthBar,
          10.h,
          Row(children: [Expanded(child: basisToggle)]),
          10.h,
          search,
        ]);
      }),
    );
  }

  Widget _seg(String label, bool selected, CrmTheme crm, VoidCallback onTap) {
    // Content-sized (no Expanded) so it can live inside a mainAxisSize.min Row
    // without triggering an unbounded-constraints RenderFlex error.
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? crm.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? crm.primary.withValues(alpha: 0.5) : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? crm.primary : crm.textSecondary)),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.count,
    required this.revenue,
    required this.advance,
    required this.balance,
    required this.cancelled,
    required this.crm,
  });
  final int count;
  final double revenue;
  final double advance;
  final double balance;
  final int cancelled;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _tile('Bookings', '$count', Icons.event_note_rounded, crm.accent),
      _tile('Revenue', _money(revenue), Icons.payments_rounded, crm.success),
      _tile('Advance', _money(advance), Icons.savings_rounded, crm.primary),
      _tile('Balance', _money(balance), Icons.account_balance_wallet_rounded, crm.warning),
      if (cancelled > 0) _tile('Cancelled', '$cancelled', Icons.cancel_outlined, crm.destructive),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      final perRow = c.maxWidth >= 900 ? tiles.length : (c.maxWidth >= 520 ? 3 : 2);
      const gap = 10.0;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: tiles.map((t) => SizedBox(width: w, child: t)).toList());
    });
  }

  Widget _tile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          10.h,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary, letterSpacing: -0.4)),
          ),
          3.h,
          Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.eventBasis, required this.crm});
  final Booking booking;
  final bool eventBasis;
  final CrmTheme crm;

  Color get _statusColor {
    final s = booking.status.toLowerCase();
    if (_isCancelled(s)) return crm.destructive;
    if (s == 'completed' || s == 'confirmed') return crm.success;
    return crm.warning;
  }

  @override
  Widget build(BuildContext context) {
    final balance = _balanceOf(booking);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.customerName.trim().isEmpty ? 'Unknown' : booking.customerName.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    2.h,
                    Text(
                      '${booking.displayBookingNumber} · ${booking.service.isEmpty ? 'Package' : booking.service}',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              8.w,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(booking.status.toUpperCase(),
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _statusColor)),
              ),
            ],
          ),
          10.h,
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(Icons.celebration_outlined, 'Event: ${_fmtDate(booking.bookingDate)}', crm.accent, highlight: eventBasis),
            _chip(Icons.bookmark_added_outlined, 'Booked: ${_fmtDate(booking.createdAt ?? booking.bookingDate)}', crm.primary, highlight: !eventBasis),
          ]),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(child: _kv('Total', _money(booking.totalPrice), crm.textPrimary)),
              Expanded(child: _kv('Advance', _money(booking.advanceAmount), crm.success)),
              Expanded(child: _kv('Balance', _money(balance), balance > 0 ? crm.warning : crm.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: highlight ? 0.5 : 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        5.w,
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  Widget _kv(String k, String v, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
        2.h,
        Text(v, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
