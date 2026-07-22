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
import '../../../../core/utils/lead_priority.dart';
import '../../../../core/utils/responsive_builder.dart';
import '../../../../services/lead_service.dart';
import '../../../../services/user_service.dart';

// ── Chart palette ───────────────────────────────────────────────────────────
const _cLeads = Color(0xFF6366F1); // indigo — leads
const _cConverted = Color(0xFF34D399); // green — converted
const _cRate = Color(0xFFF59E0B); // amber — conversion rate line
const _cBlue = Color(0xFF3B82F6);
const _cPink = Color(0xFFEC4899);
const _cGrey = Color(0xFFCBD5E1);

/// Sales Manager dashboard — leads, conversion and revenue in one view,
/// with day-wise trends and per-salesperson performance.
class SalesDashboardScreen extends ConsumerStatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  ConsumerState<SalesDashboardScreen> createState() =>
      _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends ConsumerState<SalesDashboardScreen> {
  /// Indian financial year start (2026 => FY 2026-27, Apr 2026 – Mar 2027).
  // ignore: prefer_final_fields — mutated by the FY picker.
  int _fyStartYear = _currentFyStartYear();
  /// Calendar month being reported on; null shows the whole financial year.
  // ignore: prefer_final_fields — mutated by the month picker.
  int? _month = DateTime.now().month;

  static int _currentFyStartYear() {
    final n = DateTime.now();
    return n.month >= 4 ? n.year : n.year - 1;
  }

  /// Months in Indian FY order, April first.
  static const _fyMonths = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// Calendar year a month belongs to inside the selected FY.
  int _yearForMonth(int month) =>
      month >= 4 ? _fyStartYear : _fyStartYear + 1;

  static final _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  String _money(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    return _inr.format(v);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isWide = MediaQuery.of(context).size.width >= 1250;

    final asyncBookings = ref.watch(bookingProvider);
    final asyncLeads = ref.watch(leadsProvider);
    final asyncUsers = ref.watch(crmUsersProvider);

    if (asyncBookings.isLoading || asyncLeads.isLoading || asyncUsers.isLoading) {
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
              Icon(Icons.error_outline, size: 40, color: crm.textSecondary),
              12.h,
              Text('Could not load the sales dashboard',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: crm.textPrimary)),
              8.h,
              Text('$failure',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              16.h,
              FilledButton.icon(
                onPressed: () {
                  ref.invalidate(bookingProvider);
                  ref.invalidate(leadsProvider);
                  ref.invalidate(crmUsersProvider);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final bookings = asyncBookings.value ?? const <Booking>[];
    final leads = asyncLeads.value ?? const <Lead>[];
    final people = (asyncUsers.value ?? const <CrmUser>[])
        .where((u) => u.role == 'sales' || u.role == 'sales_manager')
        .toList();

    final data = _DashboardData.build(
      leads: leads,
      bookings: bookings,
      people: people,
      fyStartYear: _fyStartYear,
      month: _month,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 14 : 24, 16, isMobile ? 14 : 24, 32),
      children: [
        _header(crm, isMobile, data),
        16.h,
        _quickPeriods(crm, isMobile, leads, bookings),
        16.h,
        _kpiRow(crm, isMobile, data),
        16.h,
        // Row 1 — day-wise trend + source donut + activities
        _responsiveRow(isWide, isMobile, [
          (5, _leadConversionChart(crm, data)),
          (3, _leadsBySource(crm, data)),
          (3, _todaysActivities(crm, data)),
        ]),
        16.h,
        // Row 2 — region + lead type + status + top performers
        _responsiveRow(isWide, isMobile, [
          (3, _leadsByRegion(crm, data)),
          (3, _leadTypeDonut(crm, data)),
          (3, _priorityCard(crm, data)),
          (3, _leadStatus(crm, data)),
        ]),
        16.h,
        _responsiveRow(isWide, isMobile, [
          (4, _topPerformers(crm, data)),
          (8, _achievement(crm, data)),
        ]),
        16.h,
        _reportTableAnchor(crm, data, isMobile),
      ],
    );
  }

  /// Lays children out side by side on wide screens and stacked otherwise.
  Widget _responsiveRow(
      bool isWide, bool isMobile, List<(int, Widget)> children) {
    if (!isWide) {
      return Column(
        children: [
          for (final c in children) ...[
            c.$2,
            if (c != children.last) 16.h,
          ],
        ],
      );
    }
    // Deliberately NOT IntrinsicHeight: these cards contain scrollables
    // (the recent-leads table) and charts, and scrollables cannot report
    // intrinsic dimensions — asking them to throws during layout.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in children) ...[
          Expanded(flex: c.$1, child: c.$2),
          if (c != children.last) 16.w,
        ],
      ],
    );
  }

  // ── Shell ─────────────────────────────────────────────────────────────────
  Widget _card(CrmTheme crm, {required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: child,
    );
  }

  Widget _cardTitle(CrmTheme crm, String title, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary)),
        ),
        ?trailing,
      ],
    );
  }

  Widget _picker(CrmTheme crm,
      {required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: crm.textSecondary),
          8.w,
          child,
        ],
      ),
    );
  }

  Widget _header(CrmTheme crm, bool isMobile, _DashboardData d) {
    return Flex(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: isMobile ? 0 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales Manager Dashboard',
                  style: TextStyle(
                      fontSize: isMobile ? 21 : 26,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
              4.h,
              Text(d.rangeLabel,
                  style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            ],
          ),
        ),
        if (isMobile) 12.h,
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Financial year (Indian FY, April–March).
            _picker(
              crm,
              icon: Icons.calendar_today_outlined,
              child: DropdownButton<int>(
                value: _fyStartYear,
                underline: const SizedBox.shrink(),
                isDense: true,
                items: [
                  for (var y = _currentFyStartYear() - 4;
                      y <= _currentFyStartYear() + 1;
                      y++)
                    DropdownMenuItem(
                      value: y,
                      child: Text('FY $y-${(y + 1) % 100}'),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _fyStartYear = v ?? _fyStartYear),
              ),
            ),
            // Month within that FY, or the whole year.
            _picker(
              crm,
              icon: Icons.date_range_outlined,
              child: DropdownButton<int>(
                value: _month ?? 0,
                underline: const SizedBox.shrink(),
                isDense: true,
                items: [
                  const DropdownMenuItem(
                      value: 0, child: Text('Full Year')),
                  for (final m in _fyMonths)
                    DropdownMenuItem(
                      value: m,
                      child: Text(
                          '${_monthNames[m - 1]} ${_yearForMonth(m)}'),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _month = (v == null || v == 0) ? null : v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Today / This week shortcuts ───────────────────────────────────────────
  /// Live totals for today and the trailing week, independent of the FY/month
  /// filter above, each opening a detailed drill-down page.
  Widget _quickPeriods(
      CrmTheme crm, bool isMobile, List<Lead> leads, List<Booking> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekFrom = today.subtract(const Duration(days: 6));

    bool inRange(DateTime? d, DateTime a, DateTime b) {
      if (d == null) return false;
      final x = DateTime(d.year, d.month, d.day);
      return !x.isBefore(a) && !x.isAfter(b);
    }

    ({int leads, int bookings, double revenue}) stats(DateTime a, DateTime b) {
      final ls = leads.where((l) => inRange(l.leadDate, a, b)).length;
      final bs =
          bookings.where((x) => inRange(x.createdAt ?? x.bookingDate, a, b));
      return (
        leads: ls,
        bookings: bs.length,
        revenue:
            bs.fold<double>(0, (s, x) => s + (x.totalPrice - x.discountAmount)),
      );
    }

    final t = stats(today, today);
    final w = stats(weekFrom, today);

    Widget tile({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required ({int leads, int bookings, double revenue}) v,
      required String route,
    }) {
      return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go(route),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.10),
                  color.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 17, color: color),
                    ),
                    10.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: crm.textPrimary)),
                          Text(subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: color),
                  ],
                ),
                12.h,
                Row(
                  children: [
                    _miniStat(crm, '${v.leads}', 'leads'),
                    16.w,
                    _miniStat(crm, '${v.bookings}', 'bookings'),
                    16.w,
                    Flexible(child: _miniStat(crm, _money(v.revenue), 'revenue')),
                  ],
                ),
              ],
            ),
          ),
      );
    }

    final todayTile = tile(
        title: 'Today',
        subtitle: DateFormat('EEEE, d MMM').format(today),
        icon: Icons.today_outlined,
        color: _cLeads,
        v: t,
        route: '/sales/dashboard/today',
    );
    final weekTile = tile(
        title: 'This Week',
        subtitle:
            '${DateFormat('d MMM').format(weekFrom)} – ${DateFormat('d MMM').format(today)}',
        icon: Icons.date_range_outlined,
        color: _cBlue,
        v: w,
        route: '/sales/dashboard/week',
    );

    // Expanded is only valid inside the Row; stacked mode uses plain children.
    return isMobile
        ? Column(children: [todayTile, 12.h, weekTile])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: todayTile),
              16.w,
              Expanded(child: weekTile),
            ],
          );
  }

  Widget _miniStat(CrmTheme crm, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: crm.textPrimary)),
        ),
        Text(label,
            style: TextStyle(fontSize: 10, color: crm.textSecondary)),
      ],
    );
  }

  // ── KPI row ───────────────────────────────────────────────────────────────
  Widget _kpiRow(CrmTheme crm, bool isMobile, _DashboardData d) {
    final tiles = <_Kpi>[
      _Kpi('Total Leads', '${d.totalLeads}', Icons.groups_outlined, _cLeads,
          d.leadsTrend),
      _Kpi('New Leads', '${d.newLeads}', Icons.person_add_alt_1_outlined,
          _cConverted, d.newLeadsTrend),
      _Kpi('Converted Leads', '${d.converted}', Icons.trending_up, _cRate,
          d.convertedTrend),
      _Kpi('Bookings Created', '${d.bookingsCreated}',
          Icons.event_available_outlined, _cBlue, d.bookingsTrend),
      _Kpi('Revenue', _money(d.revenue), Icons.payments_outlined,
          const Color(0xFF10B981), d.revenueTrend),
      // Only the part traceable to a converted lead — the sales team's own
      // contribution, as opposed to walk-ins booked without a lead.
      _Kpi(
        'From Leads',
        _money(d.attributedRevenue),
        Icons.link_outlined,
        _cLeads,
        double.nan,
        note: d.revenue <= 0
            ? 'no revenue yet'
            : '${((d.attributedRevenue / d.revenue) * 100).toStringAsFixed(0)}% of revenue',
      ),
    ];

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      // Six narrow columns make each cell short, so keep the ratio low enough
      // that the icon + value + trend line always fit.
      childAspectRatio: isMobile ? 1.4 : 1.25,
      children: [for (final t in tiles) _kpiCard(crm, t)],
    );
  }

  Widget _kpiCard(CrmTheme crm, _Kpi t) {
    final up = t.trend >= 0;
    return _card(
      crm,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: t.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(t.icon, size: 15, color: t.color),
              ),
              8.w,
              Expanded(
                child: Text(t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ),
            ],
          ),
          8.h,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(t.value,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: crm.textPrimary)),
          ),
          4.h,
          if (t.note != null)
            Text(
              t.note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
            )
          else if (t.trend.isFinite)
            Row(
              children: [
                Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 11,
                    color: up ? const Color(0xFF10B981) : Colors.red.shade600),
                2.w,
                Flexible(
                  child: Text(
                    '${t.trend.abs().toStringAsFixed(1)}% vs previous',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: up
                            ? const Color(0xFF10B981)
                            : Colors.red.shade600),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Day-wise leads / converted / conversion-rate chart ────────────────────
  Widget _leadConversionChart(CrmTheme crm, _DashboardData d) {
    final maxCount = d.daily.fold<int>(
        1, (m, p) => [m, p.leads, p.converted].reduce((a, b) => a > b ? a : b));
    final maxY = (maxCount * 1.25).ceilToDouble();
    // Reserved axis sizes are shared by both charts so the bar and line plot
    // areas line up exactly when stacked.
    const leftRes = 34.0;
    const rightRes = 42.0;
    const bottomRes = 28.0;

    Widget hiddenAxis(double size) => const SizedBox.shrink();

    return _card(
      crm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(crm, 'Lead & Conversion Overview'),
          10.h,
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legendDot(crm, 'Leads', _cLeads),
              _legendDot(crm, 'Converted', _cConverted),
              _legendDot(crm, 'Conversion Rate (%)', _cRate),
            ],
          ),
          14.h,
          SizedBox(
            height: 240,
            child: d.daily.isEmpty
                ? _empty(crm, 'No leads in this period')
                : Stack(
                    children: [
                      BarChart(
                        BarChartData(
                          maxY: maxY,
                          minY: 0,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, _, rod, rodIndex) {
                                final p = d.daily[group.x];
                                return BarTooltipItem(
                                  '${p.label}\n',
                                  const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11),
                                  children: [
                                    TextSpan(
                                      text: rodIndex == 0
                                          ? '${p.leads} leads'
                                          : '${p.converted} converted',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                                color: crm.border.withValues(alpha: 0.6),
                                strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: leftRes,
                                getTitlesWidget: (v, meta) => Text(
                                  v.toInt().toString(),
                                  style: TextStyle(
                                      fontSize: 10, color: crm.textSecondary),
                                ),
                              ),
                            ),
                            // Right axis is the 0–100% scale for the rate line.
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: rightRes,
                                interval: maxY / 5,
                                getTitlesWidget: (v, meta) {
                                  final pct = (v / maxY) * 100;
                                  return Text('${pct.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: crm.textSecondary));
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: bottomRes,
                                getTitlesWidget: (v, meta) {
                                  final i = v.toInt();
                                  if (i < 0 || i >= d.daily.length) {
                                    return const SizedBox.shrink();
                                  }
                                  // Thin out labels on long ranges.
                                  final step = (d.daily.length / 8).ceil();
                                  if (step > 1 && i % step != 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(d.daily[i].label,
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            color: crm.textSecondary)),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            for (var i = 0; i < d.daily.length; i++)
                              BarChartGroupData(
                                x: i,
                                barsSpace: 3,
                                barRods: [
                                  BarChartRodData(
                                    toY: d.daily[i].leads.toDouble(),
                                    color: _cLeads,
                                    width: d.daily.length > 20 ? 4 : 11,
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(3)),
                                  ),
                                  BarChartRodData(
                                    toY: d.daily[i].converted.toDouble(),
                                    color: _cConverted,
                                    width: d.daily.length > 20 ? 4 : 11,
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(3)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      // Conversion-rate line, scaled onto the same 0..maxY axis.
                      IgnorePointer(
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            maxY: maxY,
                            minX: -0.5,
                            maxX: d.daily.length - 0.5,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            lineTouchData:
                                const LineTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: leftRes,
                                    getTitlesWidget: (_, _) =>
                                        hiddenAxis(leftRes)),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: rightRes,
                                    getTitlesWidget: (_, _) =>
                                        hiddenAxis(rightRes)),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: bottomRes,
                                    getTitlesWidget: (_, _) =>
                                        hiddenAxis(bottomRes)),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < d.daily.length; i++)
                                    FlSpot(i.toDouble(),
                                        (d.daily[i].rate / 100) * maxY),
                                ],
                                isCurved: true,
                                curveSmoothness: 0.25,
                                color: _cRate,
                                barWidth: 2.4,
                                dotData: FlDotData(
                                  show: d.daily.length <= 20,
                                  getDotPainter: (_, _, _, _) =>
                                      FlDotCirclePainter(
                                    radius: 3,
                                    color: Colors.white,
                                    strokeWidth: 2,
                                    strokeColor: _cRate,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(CrmTheme crm, String label, Color c) => Row(
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

  Widget _empty(CrmTheme crm, String msg) => Center(
        child: Text(msg,
            style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
      );

  // ── Donut: leads by source ────────────────────────────────────────────────
  Widget _leadsBySource(CrmTheme crm, _DashboardData d) =>
      _donutCard(crm, 'Leads by Source', d.bySource, d.totalLeads, 'Total Leads');

  Widget _leadTypeDonut(CrmTheme crm, _DashboardData d) => _donutCard(
      crm, 'Pincode Based Leads', d.byPincode, d.totalLeads, 'Total');

  Widget _donutCard(CrmTheme crm, String title, List<_Slice> slices, int total,
      String centreLabel) {
    return _card(
      crm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(crm, title),
          14.h,
          if (slices.isEmpty)
            SizedBox(height: 150, child: _empty(crm, 'No data'))
          else ...[
            SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 44,
                      startDegreeOffset: -90,
                      sections: [
                        for (final s in slices)
                          PieChartSectionData(
                            value: s.count.toDouble(),
                            color: s.color,
                            radius: 20,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$total',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: crm.textPrimary)),
                      Text(centreLabel,
                          style: TextStyle(
                              fontSize: 10, color: crm.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            14.h,
            for (final s in slices)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: s.color, shape: BoxShape.circle)),
                    8.w,
                    Expanded(
                      child: Text(s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: crm.textPrimary)),
                    ),
                    Text('${s.pct.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                    6.w,
                    Text('(${s.count})',
                        style: TextStyle(
                            fontSize: 11, color: crm.textSecondary)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Horizontal bar lists ──────────────────────────────────────────────────
  
  Widget _leadsByRegion(CrmTheme crm, _DashboardData d) =>
      _barListCard(crm, 'Leads by District', d.byRegion, d.totalLeads);

  /// Hot / Warm / Cold split, with a call-out for hot leads still open.
  Widget _priorityCard(CrmTheme crm, _DashboardData d) {
    return _card(
      crm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(crm, 'Lead Priority'),
          12.h,
          if (d.hotOpen > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LeadPriority.hot.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: LeadPriority.hot.color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(LeadPriority.hot.icon,
                      size: 16, color: LeadPriority.hot.color),
                  8.w,
                  Expanded(
                    child: Text(
                      '${d.hotOpen} hot lead${d.hotOpen == 1 ? '' : 's'} still open',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: LeadPriority.hot.color),
                    ),
                  ),
                ],
              ),
            ),
            12.h,
          ],
          for (final p in d.byPriority)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(p.label,
                            style: TextStyle(
                                fontSize: 12, color: crm.textPrimary)),
                      ),
                      Text('${p.count}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                      5.w,
                      Text('(${p.pct.toStringAsFixed(0)}%)',
                          style: TextStyle(
                              fontSize: 11, color: crm.textSecondary)),
                    ],
                  ),
                  6.h,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: d.totalLeads == 0 ? 0 : p.count / d.totalLeads,
                      minHeight: 7,
                      backgroundColor:
                          crm.textSecondary.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation(p.color),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _leadStatus(CrmTheme crm, _DashboardData d) =>
      _barListCard(crm, 'Lead Status', d.byStatus, d.totalLeads);

  Widget _barListCard(
      CrmTheme crm, String title, List<_Slice> rows, int total) {
    return _card(
      crm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(crm, title),
          14.h,
          if (rows.isEmpty)
            _empty(crm, 'No data')
          else
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: crm.textPrimary)),
                        ),
                        Text('${r.count}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800)),
                        5.w,
                        Text('(${r.pct.toStringAsFixed(0)}%)',
                            style: TextStyle(
                                fontSize: 11, color: crm.textSecondary)),
                      ],
                    ),
                    6.h,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : r.count / total,
                        minHeight: 7,
                        backgroundColor:
                            crm.textSecondary.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation(r.color),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ── Today's activities (follow-ups due today) ─────────────────────────────
  Widget _todaysActivities(CrmTheme crm, _DashboardData d) {
    return _card(
      crm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(crm, "Today's Follow-ups",
              trailing: TextButton(
                onPressed: () => context.go('/sales/leads'),
                child: const Text('View All'),
              )),
          6.h,
          if (d.todayFollowUps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: _empty(crm, 'Nothing due today 🎉'),
            )
          else
            for (final l in d.todayFollowUps.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _statusColor(l.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.phone_in_talk_outlined,
                          size: 15, color: _statusColor(l.status)),
                    ),
                    10.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                          2.h,
                          Text('${l.status} · ${l.source}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                    8.w,
                    Text(
                      l.followUpDate == null
                          ? ''
                          : DateFormat('h:mm a').format(l.followUpDate!),
                      style:
                          TextStyle(fontSize: 11, color: crm.textSecondary),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ── Top performers ────────────────────────────────────────────────────────
  Widget _topPerformers(CrmTheme crm, _DashboardData d) {
    const medals = [Color(0xFFF59E0B), Color(0xFF94A3B8), Color(0xFFB45309)];
    return _card(
      crm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(crm, 'Top Performers'),
          10.h,
          if (d.performers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: _empty(crm, 'No salespeople yet'),
            )
          else
            for (var i = 0; i < d.performers.length && i < 6; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text('${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: i < 3 ? medals[i] : crm.textSecondary,
                          )),
                    ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: _cLeads.withValues(alpha: 0.12),
                      child: Text(
                        d.performers[i].name.isEmpty
                            ? '?'
                            : d.performers[i].name[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _cLeads),
                      ),
                    ),
                    9.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.performers[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                          2.h,
                          Text(
                              '${d.performers[i].leads} leads · ${d.performers[i].converted} won'
                              '${d.performers[i].revenue > 0 ? ' · ${_money(d.performers[i].revenue)}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: crm.textSecondary)),
                        ],
                      ),
                    ),
                    Text('${d.performers[i].rate.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: d.performers[i].rate >= 50
                                ? const Color(0xFF10B981)
                                : crm.textPrimary)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// Recent leads sit next to the period report at the foot of the page.
  Widget _reportTableAnchor(CrmTheme crm, _DashboardData d, bool isMobile) {
    return Column(
      children: [
        _reportTable(crm, d),
        16.h,
        _recentLeads(crm, d, isMobile),
      ],
    );
  }

  // ── Period report: one row per day (or per month for a full FY) ───────────
  Widget _reportTable(CrmTheme crm, _DashboardData d) {
    final rows = d.daily;
    final totLeads = rows.fold<int>(0, (a, r) => a + r.leads);
    final totConv = rows.fold<int>(0, (a, r) => a + r.converted);
    final totBook = rows.fold<int>(0, (a, r) => a + r.bookings);
    final totRev = rows.fold<double>(0, (a, r) => a + r.revenue);

    Widget cell(String text, int flex,
            {bool bold = false, Color? color, TextAlign align = TextAlign.right}) =>
        Expanded(
          flex: flex,
          child: Text(text,
              textAlign: align,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
                  color: color ?? crm.textPrimary)),
        );

    Widget head(String text, int flex, {TextAlign align = TextAlign.right}) =>
        Expanded(
          flex: flex,
          child: Text(text,
              textAlign: align,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: crm.textSecondary)),
        );

    return _card(
      crm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            crm,
            d.monthly ? 'Day-wise Report' : 'Month-wise Report',
            trailing: Text(
                d.monthly
                    ? '${d.rangeLabel}  ·  tap a day for detail'
                    : '${d.rangeLabel}  ·  tap a month to open it',
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ),
          12.h,
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth.isFinite && constraints.maxWidth > 620
                  ? constraints.maxWidth
                  : 620.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: w,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            head(d.monthly ? 'DATE' : 'MONTH', 3,
                                align: TextAlign.left),
                            head('LEADS', 2),
                            head('CONVERTED', 2),
                            head('CONV %', 2),
                            head('BOOKINGS', 2),
                            head('REVENUE', 3),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: crm.border),
                      // Rows with no activity are skipped so the report stays
                      // readable across a 31-day month.
                      for (final r in rows.where((r) =>
                          r.leads > 0 || r.bookings > 0 || r.revenue > 0))
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          // A day opens its own detail page; a month row
                          // re-scopes the whole dashboard to that month.
                          onTap: () {
                            if (d.monthly) {
                              final ymd =
                                  DateFormat('yyyy-MM-dd').format(r.date);
                              context.go('/sales/dashboard/day?date=$ymd');
                            } else {
                              setState(() => _month = r.date.month);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 7, horizontal: 4),
                            child: Row(
                              children: [
                                cell(r.label, 3,
                                    bold: true, align: TextAlign.left),
                                cell('${r.leads}', 2),
                                cell('${r.converted}', 2,
                                    color: r.converted > 0
                                        ? const Color(0xFF10B981)
                                        : null),
                                cell('${r.rate.toStringAsFixed(0)}%', 2),
                                cell('${r.bookings}', 2),
                                cell(_money(r.revenue), 3),
                              ],
                            ),
                          ),
                        ),
                      if (!rows.any((r) =>
                          r.leads > 0 || r.bookings > 0 || r.revenue > 0))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          child: _empty(crm, 'No activity in this period'),
                        ),
                      Divider(height: 1, color: crm.border),
                      Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Row(
                          children: [
                            cell('TOTAL', 3, bold: true, align: TextAlign.left),
                            cell('$totLeads', 2, bold: true),
                            cell('$totConv', 2, bold: true),
                            cell(
                                totLeads == 0
                                    ? '0%'
                                    : '${((totConv / totLeads) * 100).toStringAsFixed(0)}%',
                                2,
                                bold: true),
                            cell('$totBook', 2, bold: true),
                            cell(_money(totRev), 3, bold: true),
                          ],
                        ),
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

  // ── Recent leads table ────────────────────────────────────────────────────
  Widget _recentLeads(CrmTheme crm, _DashboardData d, bool isMobile) {
    return _card(
      crm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(crm, 'Recent Leads',
              trailing: TextButton(
                onPressed: () => context.go('/sales/leads'),
                child: const Text('View All'),
              )),
          8.h,
          if (d.recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: _empty(crm, 'No leads yet'),
            )
          else
            // The rows use Expanded, which needs a BOUNDED width. A horizontal
            // scroll view supplies unbounded width, so pin a concrete width:
            // at least 640 so columns stay readable, otherwise the full width.
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth =
                    constraints.maxWidth.isFinite && constraints.maxWidth > 640
                        ? constraints.maxWidth
                        : 640.0;
                return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _th(crm, 'LEAD NAME', 3),
                          _th(crm, 'SOURCE', 2),
                          _th(crm, 'REGION', 2),
                          _th(crm, 'ASSIGNED TO', 2),
                          _th(crm, 'STATUS', 2),
                          _th(crm, 'FOLLOW UP', 2),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: crm.border),
                    for (final r in d.recent)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            _td(crm, r.lead.name, 3, bold: true),
                            _td(crm, r.lead.source, 2),
                            _td(crm, r.lead.location, 2),
                            _td(crm, r.assignee, 2),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(r.lead.status)
                                        .withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(r.lead.status,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              _statusColor(r.lead.status))),
                                ),
                              ),
                            ),
                            _td(
                                crm,
                                r.lead.followUpDate == null
                                    ? '—'
                                    : DateFormat('d MMM yyyy')
                                        .format(r.lead.followUpDate!),
                                2),
                          ],
                        ),
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

  // ── Achievement vs previous period ────────────────────────────────────────
  Widget _achievement(CrmTheme crm, _DashboardData d) {
    final pct = d.prevRevenue <= 0
        ? (d.revenue > 0 ? 100.0 : 0.0)
        : (d.revenue / d.prevRevenue) * 100;

    Widget stat(String label, String value, String sub, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: crm.textSecondary)),
                6.h,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: crm.textPrimary)),
                ),
                2.h,
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: c)),
              ],
            ),
          ),
        );

    return _card(
      crm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(crm,
              _month == null ? 'This FY vs Previous FY' : 'This Month vs Last Month'),
          14.h,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_month == null ? 'Previous FY' : 'Previous month',
                        style: TextStyle(
                            fontSize: 11, color: crm.textSecondary)),
                    4.h,
                    Text(_money(d.prevRevenue),
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: crm.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Achieved',
                      style:
                          TextStyle(fontSize: 11, color: crm.textSecondary)),
                  4.h,
                  Text(_money(d.revenue),
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981))),
                ],
              ),
            ],
          ),
          12.h,
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: crm.textSecondary.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(
                  pct >= 100 ? const Color(0xFF10B981) : _cLeads),
            ),
          ),
          6.h,
          Text('${pct.toStringAsFixed(0)}% of previous period',
              style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          16.h,
          Row(
            children: [
              stat('Bookings', '${d.bookingsCreated}',
                  '${d.prevBookings} before', _cBlue),
              stat('Converted', '${d.converted}', '${d.prevConverted} before',
                  const Color(0xFF10B981)),
              stat('Conversion', '${d.conversionRate.toStringAsFixed(1)}%',
                  'of ${d.totalLeads} leads', _cRate),
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'converted':
        return const Color(0xFF10B981);
      case 'lost':
        return const Color(0xFFEF4444);
      case 'qualified':
        return const Color(0xFF8B5CF6);
      case 'follow-up':
      case 'in discussion':
        return const Color(0xFFF59E0B);
      case 'contacted':
        return _cBlue;
      default:
        return _cLeads;
    }
  }
}

// ── View model ──────────────────────────────────────────────────────────────

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double trend;
  /// Shown instead of the trend line when set.
  final String? note;
  const _Kpi(this.label, this.value, this.icon, this.color, this.trend,
      {this.note});
}

class _Slice {
  final String label;
  final int count;
  final double pct;
  final Color color;
  const _Slice(this.label, this.count, this.pct, this.color);
}

class _DayPoint {
  final String label;
  final int leads;
  final int converted;
  final double rate;
  final int bookings;
  final double revenue;
  /// First date in this bucket — the day itself, or the 1st for a month.
  final DateTime date;
  const _DayPoint(this.label, this.leads, this.converted, this.rate,
      {this.bookings = 0, this.revenue = 0, required this.date});
}

class _Performer {
  final String name;
  final int leads;
  final int converted;
  final double rate;
  /// Revenue from bookings linked to this person's converted leads.
  final double revenue;
  const _Performer(this.name, this.leads, this.converted, this.rate,
      {this.revenue = 0});
}

class _RecentLead {
  final Lead lead;
  final String assignee;
  const _RecentLead(this.lead, this.assignee);
}

/// All dashboard figures derived in one pass, keeping the widgets declarative.
class _DashboardData {
  final int totalLeads;
  final int newLeads;
  final int converted;
  final int bookingsCreated;
  final double revenue;
  /// Portion of [revenue] traceable to a converted lead (Lead.bookingId).
  final double attributedRevenue;
  final double conversionRate;

  final double leadsTrend;
  final double newLeadsTrend;
  final double convertedTrend;
  final double bookingsTrend;
  final double revenueTrend;

  final double prevRevenue;
  final int prevBookings;
  final int prevConverted;

  final List<_DayPoint> daily;
  final List<_Slice> bySource;
  final List<_Slice> byRegion;
  final List<_Slice> byStatus;
  final List<_Slice> byPriority;
  /// Open (not converted/lost) leads marked Hot — the ones needing action now.
  final int hotOpen;
  final List<_Slice> byPincode;
  final List<_Performer> performers;
  final List<_RecentLead> recent;
  final List<Lead> todayFollowUps;
  final String rangeLabel;
  /// True when reporting a single month (day-wise), false for a full FY.
  final bool monthly;

  const _DashboardData({
    required this.totalLeads,
    required this.newLeads,
    required this.converted,
    required this.bookingsCreated,
    required this.revenue,
    required this.attributedRevenue,
    required this.conversionRate,
    required this.leadsTrend,
    required this.newLeadsTrend,
    required this.convertedTrend,
    required this.bookingsTrend,
    required this.revenueTrend,
    required this.prevRevenue,
    required this.prevBookings,
    required this.prevConverted,
    required this.daily,
    required this.bySource,
    required this.byRegion,
    required this.byStatus,
    required this.byPriority,
    required this.hotOpen,
    required this.byPincode,
    required this.performers,
    required this.recent,
    required this.todayFollowUps,
    required this.rangeLabel,
    required this.monthly,
  });

  static const _palette = [
    _cLeads, _cBlue, _cRate, _cPink, _cConverted, Color(0xFF8B5CF6), _cGrey,
  ];

  static double _trend(num now, num before) {
    if (before == 0) return now == 0 ? 0 : 100;
    return ((now - before) / before) * 100;
  }

  static List<_Slice> _group(
      Iterable<String> values, int total, {int limit = 5}) {
    final counts = <String, int>{};
    for (final raw in values) {
      final k = raw.trim().isEmpty ? 'Others' : raw.trim();
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final out = <_Slice>[];
    var i = 0;
    var otherCount = 0;
    for (final e in entries) {
      if (i < limit) {
        out.add(_Slice(e.key, e.value,
            total == 0 ? 0 : (e.value / total) * 100, _palette[i % _palette.length]));
        i++;
      } else {
        otherCount += e.value;
      }
    }
    if (otherCount > 0) {
      out.add(_Slice('Others', otherCount,
          total == 0 ? 0 : (otherCount / total) * 100, _cGrey));
    }
    return out;
  }

  static _DashboardData build({
    required List<Lead> leads,
    required List<Booking> bookings,
    required List<CrmUser> people,
    required int fyStartYear,
    required int? month,
  }) {
    // A month selection reports that month day-by-day; no month reports the
    // whole Indian financial year (Apr–Mar) month-by-month. The comparison
    // period is the previous month / previous FY respectively.
    final DateTime from, to, prevFrom, prevTo;
    final bool monthly = month != null;
    if (monthly) {
      final year = month >= 4 ? fyStartYear : fyStartYear + 1;
      from = DateTime(year, month, 1);
      to = DateTime(year, month + 1, 0);
      prevFrom = DateTime(year, month - 1, 1);
      prevTo = DateTime(year, month, 0);
    } else {
      from = DateTime(fyStartYear, 4, 1);
      to = DateTime(fyStartYear + 1, 3, 31);
      prevFrom = DateTime(fyStartYear - 1, 4, 1);
      prevTo = DateTime(fyStartYear, 3, 31);
    }
    final today = to;

    bool within(DateTime? d, DateTime a, DateTime b) {
      if (d == null) return false;
      final x = DateTime(d.year, d.month, d.day);
      return !x.isBefore(a) && !x.isAfter(b);
    }

    final windowLeads =
        leads.where((l) => within(l.leadDate, from, today)).toList();
    final prevLeads =
        leads.where((l) => within(l.leadDate, prevFrom, prevTo)).toList();

    bool isConverted(Lead l) => l.status.toLowerCase() == 'converted';

    final converted = windowLeads.where(isConverted).length;
    final prevConverted = prevLeads.where(isConverted).length;

    final windowBookings = bookings
        .where((b) => within(b.createdAt ?? b.bookingDate, from, today))
        .toList();
    final prevBookings = bookings
        .where((b) => within(b.createdAt ?? b.bookingDate, prevFrom, prevTo))
        .toList();

    double rev(List<Booking> bs) =>
        bs.fold(0.0, (s, b) => s + (b.totalPrice - b.discountAmount));

    // Buckets: one per day of the month, or one per month across the FY.
    final daily = <_DayPoint>[];
    final buckets = <(DateTime, DateTime, String)>[];
    if (monthly) {
      final dayCount = to.day;
      for (var i = 0; i < dayCount; i++) {
        final day = DateTime(from.year, from.month, i + 1);
        buckets.add((day, day, DateFormat('d MMM').format(day)));
      }
    } else {
      for (var i = 0; i < 12; i++) {
        final m = DateTime(fyStartYear, 4 + i, 1);
        final last = DateTime(m.year, m.month + 1, 0);
        buckets.add((m, last, DateFormat('MMM').format(m)));
      }
    }

    for (final b in buckets) {
      final dayLeads = windowLeads
          .where((l) => within(l.leadDate, b.$1, b.$2))
          .toList();
      final won = dayLeads.where(isConverted).length;
      final dayBookings = windowBookings
          .where((bk) => within(bk.createdAt ?? bk.bookingDate, b.$1, b.$2))
          .toList();
      daily.add(_DayPoint(
        b.$3,
        dayLeads.length,
        won,
        dayLeads.isEmpty ? 0 : (won / dayLeads.length) * 100,
        bookings: dayBookings.length,
        revenue: rev(dayBookings),
        date: b.$1,
      ));
    }

    // Revenue is attributed through Lead.bookingId, so a salesperson is
    // credited with the actual booking their converted lead produced rather
    // than a share of overall takings.
    final bookingById = {for (final b in bookings) b.id: b};
    double revenueForLeads(Iterable<Lead> ls) {
      var total = 0.0;
      final counted = <String>{};
      for (final l in ls) {
        final id = l.bookingId;
        if (id == null || id.isEmpty || !counted.add(id)) continue;
        final b = bookingById[id];
        if (b == null) continue;
        total += b.totalPrice - b.discountAmount;
      }
      return total;
    }

    final nameById = {for (final u in people) u.id: u.name};
    final performers = <_Performer>[];
    for (final u in people) {
      final mine = windowLeads.where((l) => l.assignedTo == u.id).toList();
      final won = mine.where(isConverted).length;
      performers.add(_Performer(
        u.name,
        mine.length,
        won,
        mine.isEmpty ? 0 : (won / mine.length) * 100,
        revenue: revenueForLeads(mine),
      ));
    }
    performers.sort((a, b) => b.revenue != a.revenue
        ? b.revenue.compareTo(a.revenue)
        : b.converted.compareTo(a.converted));

    // Revenue traceable to a lead, vs all bookings taken in the period.
    final attributedRevenue = revenueForLeads(windowLeads);

    final recentSorted = [...windowLeads]
      ..sort((a, b) => b.leadDate.compareTo(a.leadDate));

    final total = windowLeads.length;

    return _DashboardData(
      totalLeads: total,
      newLeads: windowLeads
          .where((l) => l.status.toLowerCase() == 'new')
          .length,
      converted: converted,
      bookingsCreated: windowBookings.length,
      revenue: rev(windowBookings),
      attributedRevenue: attributedRevenue,
      conversionRate: total == 0 ? 0 : (converted / total) * 100,
      leadsTrend: _trend(total, prevLeads.length),
      newLeadsTrend: _trend(
        windowLeads.where((l) => l.status.toLowerCase() == 'new').length,
        prevLeads.where((l) => l.status.toLowerCase() == 'new').length,
      ),
      convertedTrend: _trend(converted, prevConverted),
      bookingsTrend: _trend(windowBookings.length, prevBookings.length),
      revenueTrend: _trend(rev(windowBookings), rev(prevBookings)),
      prevRevenue: rev(prevBookings),
      prevBookings: prevBookings.length,
      prevConverted: prevConverted,
      daily: daily,
      bySource: _group(windowLeads.map((l) => l.source), total),
      byRegion: _group(
          windowLeads.map((l) =>
              l.district.trim().isNotEmpty ? l.district : l.location),
          total),
      byStatus: _group(windowLeads.map((l) => l.status), total, limit: 6),
      byPriority: [
        for (final p in LeadPriority.all)
          _Slice(
            p.label,
            windowLeads
                .where((l) => LeadPriority.of(l.priority).value == p.value)
                .length,
            total == 0
                ? 0
                : (windowLeads
                            .where((l) =>
                                LeadPriority.of(l.priority).value == p.value)
                            .length /
                        total) *
                    100,
            p.color,
          ),
      ],
      hotOpen: windowLeads.where((l) {
        final st = l.status.toLowerCase();
        return LeadPriority.of(l.priority).value == 'Hot' &&
            st != 'converted' &&
            st != 'lost';
      }).length,
      byPincode: _group(
          windowLeads.map((l) =>
              l.pincode.trim().isEmpty ? 'Not captured' : l.pincode.trim()),
          total,
          limit: 4),
      performers: performers,
      recent: [
        for (final l in recentSorted.take(6))
          _RecentLead(l, nameById[l.assignedTo] ?? 'Unassigned'),
      ],
      todayFollowUps: leads
          .where((l) => within(l.followUpDate, today, today))
          .toList()
        ..sort((a, b) => (a.followUpDate ?? today)
            .compareTo(b.followUpDate ?? today)),
      monthly: monthly,
      rangeLabel: monthly
          ? '${DateFormat('MMMM yyyy').format(from)}  ·  FY $fyStartYear-${(fyStartYear + 1) % 100}'
          : 'FY $fyStartYear-${(fyStartYear + 1) % 100}  ·  Apr $fyStartYear – Mar ${fyStartYear + 1}',
    );
  }
}
