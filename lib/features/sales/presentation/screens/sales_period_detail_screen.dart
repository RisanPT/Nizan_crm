import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/space_extension.dart';
import '../../../../core/models/booking.dart';
import '../../../../core/models/crm_user.dart';
import '../../../../core/models/lead.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/responsive_builder.dart';
import '../../../../services/lead_service.dart';
import '../../../../services/user_service.dart';

const _cLeads = Color(0xFF6366F1);
const _cGreen = Color(0xFF10B981);
const _cAmber = Color(0xFFF59E0B);
const _cBlue = Color(0xFF3B82F6);

/// Drill-down from the Sales Dashboard into a single day or the current week.
class SalesPeriodDetailScreen extends ConsumerWidget {
  /// 'today' for a single day, 'week' for the trailing 7 days, 'day' for the
  /// specific [date] passed in (used when drilling into the day-wise report).
  final String mode;

  /// Only used when [mode] is 'day'.
  final DateTime? date;

  const SalesPeriodDetailScreen({super.key, required this.mode, this.date});

  bool get _isWeek => mode == 'week';
  bool get _isSpecificDay => mode == 'day' && date != null;

  static final _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static String _money(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    return _inr.format(v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    final asyncBookings = ref.watch(bookingProvider);
    final asyncLeads = ref.watch(leadsProvider);
    final asyncUsers = ref.watch(crmUsersProvider);

    if (asyncBookings.isLoading ||
        asyncLeads.isLoading ||
        asyncUsers.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final failure = asyncBookings.error ?? asyncLeads.error ?? asyncUsers.error;
    if (failure != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 36, color: crm.textSecondary),
              12.h,
              Text('$failure',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final anchor = _isSpecificDay
        ? DateTime(date!.year, date!.month, date!.day)
        : DateTime(now.year, now.month, now.day);
    final today = anchor;
    final from = _isWeek ? anchor.subtract(const Duration(days: 6)) : anchor;

    bool within(DateTime? d, DateTime a, DateTime b) {
      if (d == null) return false;
      final x = DateTime(d.year, d.month, d.day);
      return !x.isBefore(a) && !x.isAfter(b);
    }

    final leads = (asyncLeads.value ?? const <Lead>[])
        .where((l) => within(l.leadDate, from, today))
        .toList()
      ..sort((a, b) => b.leadDate.compareTo(a.leadDate));

    final bookings = (asyncBookings.value ?? const <Booking>[])
        .where((b) => within(b.createdAt ?? b.bookingDate, from, today))
        .toList()
      ..sort((a, b) => (b.createdAt ?? b.bookingDate)
          .compareTo(a.createdAt ?? a.bookingDate));

    final people = (asyncUsers.value ?? const <CrmUser>[])
        .where((u) => u.role == 'sales' || u.role == 'sales_manager')
        .toList();
    final nameById = {for (final u in people) u.id: u.name};

    bool isConverted(Lead l) => l.status.toLowerCase() == 'converted';
    final converted = leads.where(isConverted).length;
    final revenue = bookings.fold<double>(
        0, (s, b) => s + (b.totalPrice - b.discountAmount));
    final collected =
        bookings.fold<double>(0, (s, b) => s + b.advanceAmount + b.collectedAmount);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 14 : 24, 16, isMobile ? 14 : 24, 32),
      children: [
        _header(context, crm, isMobile, from, today),
        18.h,
        _kpis(crm, isMobile,
            leads: leads.length,
            converted: converted,
            bookings: bookings.length,
            revenue: revenue,
            collected: collected),
        18.h,
        if (_isWeek) ...[
          _weekChart(crm, leads, bookings, from),
          18.h,
        ],
        _byPerson(crm, leads, people),
        18.h,
        _leadList(crm, leads, nameById, isMobile),
        18.h,
        _bookingList(crm, bookings, isMobile),
      ],
    );
  }

  Widget _card(CrmTheme crm, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: child,
      );

  Widget _title(CrmTheme crm, String t) => Text(t,
      style: TextStyle(
          fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary));

  Widget _header(BuildContext context, CrmTheme crm, bool isMobile,
      DateTime from, DateTime to) {
    final label = _isWeek
        ? '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM yyyy').format(to)}'
        : DateFormat('EEEE, d MMMM yyyy').format(to);
    final heading = _isWeek
        ? 'This Week'
        : (_isSpecificDay ? DateFormat('d MMMM yyyy').format(to) : "Today's Sales");

    return Row(
      children: [
        IconButton(
          tooltip: 'Back to dashboard',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/sales/dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
        8.w,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading,
                  style: TextStyle(
                      fontSize: isMobile ? 20 : 25,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
              2.h,
              Text(label,
                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            ],
          ),
        ),
        // Jump straight to the other period without going back first.
        OutlinedButton.icon(
          onPressed: () => context.go(
              _isWeek ? '/sales/dashboard/today' : '/sales/dashboard/week'),
          icon: Icon(_isWeek ? Icons.today_outlined : Icons.date_range_outlined,
              size: 16),
          label: Text(_isWeek ? 'Today' : 'This Week'),
        ),
      ],
    );
  }

  Widget _kpis(CrmTheme crm, bool isMobile,
      {required int leads,
      required int converted,
      required int bookings,
      required double revenue,
      required double collected}) {
    final rate = leads == 0 ? 0.0 : (converted / leads) * 100;
    final tiles = <(String, String, IconData, Color)>[
      ('Leads', '$leads', Icons.groups_outlined, _cLeads),
      ('Converted', '$converted', Icons.check_circle_outline, _cGreen),
      ('Conversion', '${rate.toStringAsFixed(1)}%', Icons.percent, _cAmber),
      ('Bookings', '$bookings', Icons.event_available_outlined, _cBlue),
      ('Revenue', _money(revenue), Icons.payments_outlined, _cGreen),
      ('Collected', _money(collected), Icons.savings_outlined, _cLeads),
    ];

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.7 : 2.8,
      children: [
        for (final t in tiles)
          _card(
            crm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: t.$4.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Icon(t.$3, size: 15, color: t.$4),
                  ),
                  8.w,
                  Expanded(
                    child: Text(t.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary)),
                  ),
                ]),
                8.h,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(t.$2,
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: crm.textPrimary)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Seven-day leads vs bookings comparison.
  Widget _weekChart(
      CrmTheme crm, List<Lead> leads, List<Booking> bookings, DateTime from) {
    final days = <(String, int, int)>[];
    for (var i = 0; i < 7; i++) {
      final d = from.add(Duration(days: i));
      bool same(DateTime? x) =>
          x != null && x.year == d.year && x.month == d.month && x.day == d.day;
      days.add((
        DateFormat('E').format(d),
        leads.where((l) => same(l.leadDate)).length,
        bookings.where((b) => same(b.createdAt ?? b.bookingDate)).length,
      ));
    }
    final maxV = days.fold<int>(
        1, (m, e) => [m, e.$2, e.$3].reduce((a, b) => a > b ? a : b));

    return _card(
      crm,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(crm, 'Daily Breakdown'),
          10.h,
          Row(children: [
            _dot(crm, 'Leads', _cLeads),
            16.w,
            _dot(crm, 'Bookings', _cBlue),
          ]),
          14.h,
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: (maxV * 1.3).ceilToDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: crm.border.withValues(alpha: 0.6), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                          style: TextStyle(
                              fontSize: 10, color: crm.textSecondary)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= days.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(days[i].$1,
                              style: TextStyle(
                                  fontSize: 10, color: crm.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i++)
                    BarChartGroupData(x: i, barsSpace: 4, barRods: [
                      BarChartRodData(
                          toY: days[i].$2.toDouble(),
                          color: _cLeads,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3))),
                      BarChartRodData(
                          toY: days[i].$3.toDouble(),
                          color: _cBlue,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3))),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(CrmTheme crm, String label, Color c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          6.w,
          Text(label,
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ],
      );

  Widget _byPerson(CrmTheme crm, List<Lead> leads, List<CrmUser> people) {
    final rows = <(String, int, int)>[];
    for (final u in people) {
      final mine = leads.where((l) => l.assignedTo == u.id).toList();
      if (mine.isEmpty) continue;
      rows.add((
        u.name,
        mine.length,
        mine.where((l) => l.status.toLowerCase() == 'converted').length,
      ));
    }
    final un = leads.where((l) => (l.assignedTo ?? '').isEmpty).toList();
    if (un.isNotEmpty) {
      rows.add(('Unassigned', un.length,
          un.where((l) => l.status.toLowerCase() == 'converted').length));
    }
    rows.sort((a, b) => b.$2.compareTo(a.$2));

    return _card(
      crm,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(crm, 'By Salesperson'),
          12.h,
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('No lead activity in this period',
                    style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
              ),
            )
          else
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(r.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: rows.first.$2 == 0 ? 0 : r.$2 / rows.first.$2,
                          minHeight: 7,
                          backgroundColor:
                              crm.textSecondary.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(
                              r.$1 == 'Unassigned' ? _cAmber : _cLeads),
                        ),
                      ),
                    ),
                    10.w,
                    Text('${r.$2} leads · ${r.$3} won',
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _leadList(CrmTheme crm, List<Lead> leads, Map<String, String> nameById,
      bool isMobile) {
    return _card(
      crm,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _title(crm, 'Leads (${leads.length})')),
              TextButton(
                onPressed: null,
                child: Text('${leads.length} in period',
                    style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              ),
            ],
          ),
          8.h,
          if (leads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text('No leads in this period',
                    style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth.isFinite && c.maxWidth > 620
                    ? c.maxWidth
                    : 620.0;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: w,
                    child: Column(
                      children: [
                        Row(children: [
                          _th(crm, 'NAME', 3),
                          _th(crm, 'PHONE', 2),
                          _th(crm, 'SOURCE', 2),
                          _th(crm, 'ASSIGNED', 2),
                          _th(crm, 'STATUS', 2),
                        ]),
                        8.h,
                        Divider(height: 1, color: crm.border),
                        for (final l in leads.take(25))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              _td(crm, l.name, 3, bold: true),
                              _td(crm, l.phone, 2),
                              _td(crm, l.source, 2),
                              _td(crm, nameById[l.assignedTo] ?? 'Unassigned',
                                  2),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _pill(l.status),
                                ),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _bookingList(CrmTheme crm, List<Booking> bookings, bool isMobile) {
    return _card(
      crm,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(crm, 'Bookings (${bookings.length})'),
          8.h,
          if (bookings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text('No bookings in this period',
                    style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth.isFinite && c.maxWidth > 560
                    ? c.maxWidth
                    : 560.0;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: w,
                    child: Column(
                      children: [
                        Row(children: [
                          _th(crm, 'CLIENT', 3),
                          _th(crm, 'PACKAGE', 3),
                          _th(crm, 'EVENT DATE', 2),
                          _th(crm, 'TOTAL', 2),
                          _th(crm, 'BALANCE', 2),
                        ]),
                        8.h,
                        Divider(height: 1, color: crm.border),
                        for (final b in bookings.take(25))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              _td(crm, b.customerName, 3, bold: true),
                              _td(crm, b.service, 3),
                              _td(
                                  crm,
                                  DateFormat('d MMM yyyy')
                                      .format(b.bookingDate),
                                  2),
                              _td(crm, _money(b.totalPrice), 2),
                              Expanded(
                                flex: 2,
                                child: Text(_money(b.balanceDue),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: b.balanceDue > 0
                                            ? _cAmber
                                            : _cGreen)),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _pill(String status) {
    final c = switch (status.toLowerCase()) {
      'converted' => _cGreen,
      'lost' => const Color(0xFFEF4444),
      'qualified' => const Color(0xFF8B5CF6),
      'follow-up' => _cAmber,
      'contacted' => _cBlue,
      _ => _cLeads,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: c)),
    );
  }

  Widget _th(CrmTheme crm, String s, int flex) => Expanded(
        flex: flex,
        child: Text(s,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: crm.textSecondary)),
      );

  Widget _td(CrmTheme crm, String s, int flex, {bool bold = false}) => Expanded(
        flex: flex,
        child: Text(s.isEmpty ? '—' : s,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                color: crm.textPrimary)),
      );
}
