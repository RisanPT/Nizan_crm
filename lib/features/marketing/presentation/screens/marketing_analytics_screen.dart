import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';
import 'package:nizan_crm/features/marketing/presentation/widgets/kerala_bookings_map.dart';

/// Marketing Analytics — a dedicated dashboard for the three booking dimensions:
/// TIMELINE (seasonality by event date), CULTURE / community, and LOCATION
/// (region map + district/pincode where captured). Plus a data-quality panel
/// that surfaces existing bookings missing a proper event date / culture /
/// location so they can be corrected. Reuses `marketingInsightsProvider`.
class MarketingAnalyticsScreen extends ConsumerWidget {
  const MarketingAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(marketingInsightsProvider);
    final selectedFy = ref.watch(marketingFyProvider);
    final nowFy = _currentFyStartYear();

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(marketingInsightsProvider),
        child: ListView(
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
                      Text('Marketing Analytics',
                          style: TextStyle(
                              fontSize: isMobile ? 22 : 27,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      Text('Timeline · Culture · Location',
                          style: TextStyle(
                              fontSize: 12.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
                _fyDropdown(crm, ref, selectedFy ?? nowFy, nowFy),
              ],
            ),
            16.hg,
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(e.toString().replaceFirst('Exception: ', ''),
                      style: TextStyle(color: crm.textSecondary)),
                ),
              ),
              data: (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _card(crm, 'Booking Timeline — Seasonality',
                      _TimelineSection(crm: crm, months: d.byMonth),
                      subtitle:
                          'By event date · ${d.totalBookings} bookings this period'),
                  14.hg,
                  _card(crm, 'By Culture / Community',
                      _cultureSection(crm, d.byCulture)),
                  14.hg,
                  _card(
                    crm,
                    'Location',
                    _locationSection(crm, isMobile, d),
                    subtitle: 'Booking volume across Kerala',
                  ),
                  14.hg,
                  _card(crm, 'Data Quality — event dates, culture & location',
                      _coverageSection(context, crm, d.coverage),
                      subtitle: 'Completeness across all existing bookings'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Culture: donut + ranked list (with revenue) ──
  Widget _cultureSection(CrmTheme crm, List<SegmentRow> rows) {
    final meaningful = rows
        .where((r) => r.name != 'Not specified' && r.bookings > 0)
        .toList();
    if (meaningful.isEmpty) {
      return _muted(crm,
          'No community data yet. Set "Community / Culture" on the Manage Booking screen (or it is inferred from the service) to build this segment.');
    }
    final total =
        meaningful.fold<int>(0, (s, r) => s + r.bookings).clamp(1, 1 << 30);
    final palette = _cultureColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  for (var i = 0; i < meaningful.length; i++)
                    PieChartSectionData(
                      value: meaningful[i].bookings.toDouble(),
                      color: palette[i % palette.length],
                      radius: 20,
                      showTitle: false,
                    ),
                ],
              )),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$total',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: crm.textPrimary)),
                  Text('bookings',
                      style:
                          TextStyle(fontSize: 10, color: crm.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        16.wg,
        Expanded(child: _ranked(crm, meaningful, colored: true)),
      ],
    );
  }

  // ── Location: Kerala region map + district/pincode ranked (where present) ──
  Widget _locationSection(CrmTheme crm, bool isMobile, MarketingInsights d) {
    final hasDistrict = d.byDistrict.isNotEmpty;
    final hasPincode = d.byPincode.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeralaBookingsMap(rows: d.byRegion, height: isMobile ? 280 : 340),
        12.hg,
        _cols(isMobile, [
          _subCard(crm, 'By Region',
              _ranked(crm, d.byRegion, colored: false)),
          if (hasDistrict)
            _subCard(crm, 'By District',
                _ranked(crm, d.byDistrict, colored: false)),
        ]),
        if (hasPincode) ...[
          12.hg,
          _subCard(crm, 'By Pincode', _ranked(crm, d.byPincode, colored: false)),
        ],
        if (!hasDistrict && !hasPincode) ...[
          10.hg,
          _note(crm,
              'District & pincode were not captured for older imported bookings — these breakdowns fill in as new bookings record them.'),
        ],
      ],
    );
  }

  // ── Data-quality / coverage panel ──
  Widget _coverageSection(
      BuildContext context, CrmTheme crm, Coverage c) {
    final knownCulture = c.cultureExplicit + c.cultureInferred;
    final cultureTotal =
        (knownCulture + c.cultureUnknown).clamp(1, 1 << 30);
    final locTotal = c.eventTotal.clamp(1, 1 << 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _meter(crm, 'Event date', c.eventWithDate, c.eventTotal,
            detail: c.eventMissing == 0
                ? 'Every booking has a real event date'
                : '${c.eventMissing} missing an event date'),
        10.hg,
        _meter(crm, 'Culture / community', knownCulture, cultureTotal,
            detail:
                'explicit ${c.cultureExplicit} · inferred ${c.cultureInferred} · unknown ${c.cultureUnknown}'),
        10.hg,
        _meter(crm, 'Location', c.locWithRegion, locTotal,
            detail:
                'region ${c.locWithRegion} · district ${c.locWithDistrict} · pincode ${c.locWithPincode}'),
        if (c.eventMissing == 0) ...[
          12.hg,
          _note(crm,
              '✓ Every booking carries a real event date, so the timeline above reflects actual event seasonality — not entry dates.',
              good: true),
        ],
        14.hg,
        Divider(color: crm.border, height: 1),
        12.hg,
        if (c.worklist.isEmpty)
          _note(crm,
              '✓ No bookings are missing event / culture / location data.',
              good: true)
        else ...[
          Text('Needs attention (${c.worklist.length})',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: crm.textPrimary)),
          6.hg,
          Text('Tap a booking to open it and fill the missing field.',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          8.hg,
          for (final w in c.worklist) _worklistRow(context, crm, w),
        ],
      ],
    );
  }

  Widget _worklistRow(BuildContext context, CrmTheme crm, CoverageItem w) {
    final date = w.bookingDate != null
        ? '${w.bookingDate!.day}/${w.bookingDate!.month}/${w.bookingDate!.year}'
        : 'No date';
    return InkWell(
      onTap: () => context.push('/booking/manage/${w.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.customerName.isEmpty ? 'Unnamed booking' : w.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  Text(date,
                      style:
                          TextStyle(fontSize: 11, color: crm.textSecondary)),
                ],
              ),
            ),
            8.wg,
            Wrap(
              spacing: 4,
              children: [for (final m in w.missing) _missChip(crm, m)],
            ),
            Icon(Icons.chevron_right, size: 18, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _missChip(CrmTheme crm, String key) {
    final label = switch (key) {
      'eventDate' => 'event date',
      'culture' => 'culture',
      'location' => 'location',
      _ => key,
    };
    const c = Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: c)),
    );
  }

  Widget _meter(CrmTheme crm, String label, int have, int total,
      {required String detail}) {
    final pct = total > 0 ? (have / total).clamp(0.0, 1.0) : 0.0;
    final color = pct >= 0.9
        ? const Color(0xFF16A34A)
        : (pct >= 0.5 ? const Color(0xFFF59E0B) : const Color(0xFFDC2626));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: crm.textPrimary)),
            ),
            Text('$have / $total  (${(pct * 100).round()}%)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: crm.textPrimary)),
          ],
        ),
        6.hg,
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 9,
            backgroundColor: crm.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        4.hg,
        Text(detail, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
      ],
    );
  }

  // ── Ranked bars (with revenue subtitle) ──
  Widget _ranked(CrmTheme crm, List<SegmentRow> rows, {required bool colored}) {
    if (rows.isEmpty) return _muted(crm, 'No data yet.');
    final max = rows.fold<int>(1, (m, r) => r.bookings > m ? r.bookings : m);
    final palette = _cultureColors;
    return Column(
      children: [
        for (var i = 0; i < rows.take(8).length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rows[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: crm.textPrimary)),
                      if (rows[i].revenue > 0)
                        Text(_money(rows[i].revenue),
                            style: TextStyle(
                                fontSize: 10, color: crm.textSecondary)),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: (rows[i].bookings / max).clamp(0, 1),
                      minHeight: 9,
                      backgroundColor: crm.border,
                      valueColor: AlwaysStoppedAnimation(colored
                          ? palette[i % palette.length]
                          : crm.primary),
                    ),
                  ),
                ),
                8.wg,
                Text('${rows[i].bookings}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
      ],
    );
  }

  // ── FY selector ──
  Widget _fyDropdown(CrmTheme crm, WidgetRef ref, int value, int nowFy) {
    final years = [nowFy, nowFy - 1, nowFy - 2, nowFy - 3];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          items: [
            for (final y in years)
              DropdownMenuItem(value: y, child: Text('FY ${_fyLabel(y)}')),
          ],
          onChanged: (v) {
            if (v != null) {
              ref.read(marketingFyProvider.notifier).state = v;
              ref.invalidate(marketingInsightsProvider);
            }
          },
        ),
      ),
    );
  }

  // ── layout helpers ──
  Widget _cols(bool isMobile, List<Widget> items) {
    final visible = items;
    if (visible.length == 1) return visible.first;
    return isMobile
        ? Column(
            children: [
              for (final c in visible)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: c)
            ],
          )
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  Expanded(child: visible[i]),
                  if (i < visible.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
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

  Widget _subCard(CrmTheme crm, String title, Widget child) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crm.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: crm.textPrimary)),
            8.hg,
            child,
          ],
        ),
      );

  Widget _muted(CrmTheme crm, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t, style: TextStyle(color: crm.textSecondary, fontSize: 13)),
      );

  Widget _note(CrmTheme crm, String t, {bool good = false}) {
    final c = good ? const Color(0xFF16A34A) : crm.textSecondary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (good ? const Color(0xFF16A34A) : crm.primary)
            .withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(t, style: TextStyle(fontSize: 12, color: c)),
    );
  }

  // ── formatting / FY helpers ──
  static const List<Color> _cultureColors = [
    Color(0xFF6D5DF6),
    Color(0xFF0D9488),
    Color(0xFFF59E0B),
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFFDB2777),
    Color(0xFF65A30D),
    Color(0xFF9333EA),
  ];

  static String _money(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  static int _currentFyStartYear() {
    final n = DateTime.now();
    return n.month >= 4 ? n.year : n.year - 1;
  }

  static String _fyLabel(int startYear) =>
      '$startYear-${((startYear + 1) % 100).toString().padLeft(2, '0')}';
}

// ── Timeline section: bar chart with Bookings ⇄ Revenue toggle + peak ──
class _TimelineSection extends StatefulWidget {
  final CrmTheme crm;
  final List<SegmentRow> months;
  const _TimelineSection({required this.crm, required this.months});

  @override
  State<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<_TimelineSection> {
  bool _revenue = false;

  static const _mon = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
    'Nov', 'Dec'
  ];
  static String _mLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return ym;
    final m = int.tryParse(parts[1]) ?? 0;
    return (m >= 1 && m <= 12) ? _mon[m] : ym;
  }

  double _val(SegmentRow r) => _revenue ? r.revenue : r.bookings.toDouble();

  @override
  Widget build(BuildContext context) {
    final crm = widget.crm;
    final months = widget.months;
    if (months.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('No bookings in this period.',
            style: TextStyle(color: crm.textSecondary, fontSize: 13)),
      );
    }

    var peakIdx = 0;
    for (var i = 1; i < months.length; i++) {
      if (_val(months[i]) > _val(months[peakIdx])) peakIdx = i;
    }
    final maxV = _val(months[peakIdx]).clamp(1, double.infinity).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Peak: ${_mLabel(months[peakIdx].name)} · '
                '${_revenue ? _MoneyFmt.money(months[peakIdx].revenue) : '${months[peakIdx].bookings} bookings'}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: crm.textPrimary),
              ),
            ),
            _toggle(crm),
          ],
        ),
        14.hg,
        SizedBox(
          height: 190,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxV * 1.15,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => crm.textPrimary,
                getTooltipItem: (group, _, rod, _) {
                  final r = months[group.x];
                  return BarTooltipItem(
                    '${_mLabel(r.name)}\n',
                    const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11),
                    children: [
                      TextSpan(
                        text: _revenue
                            ? _MoneyFmt.money(r.revenue)
                            : '${r.bookings} bookings',
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
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                    _revenue ? _MoneyFmt.compact(v) : v.toInt().toString(),
                    style: TextStyle(fontSize: 9, color: crm.textSecondary),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= months.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_mLabel(months[i].name),
                          style: TextStyle(
                              fontSize: 8.5, color: crm.textSecondary)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < months.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: _val(months[i]),
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                      color: i == peakIdx
                          ? const Color(0xFFF59E0B)
                          : crm.primary,
                    ),
                  ],
                ),
            ],
          )),
        ),
      ],
    );
  }

  Widget _toggle(CrmTheme crm) {
    Widget seg(String label, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? crm.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : crm.textSecondary)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('Bookings', !_revenue, () => setState(() => _revenue = false)),
          seg('Revenue', _revenue, () => setState(() => _revenue = true)),
        ],
      ),
    );
  }
}

class _MoneyFmt {
  static String money(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  static String compact(double v) {
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
