import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
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
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(marketingInsightsProvider);
    final selectedFy = ref.watch(marketingFyProvider);
    final nowFy = _currentFyStartYear();

    return MktPage(
      child: Material(
        type: MaterialType.transparency,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(marketingInsightsProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              MktHeader(
                icon: Icons.insights_outlined,
                title: 'Marketing Analytics',
                subtitle: 'Timeline · Culture · Location',
                actions: [_fyDropdown(ref, selectedFy ?? nowFy, nowFy)],
              ),
              const SizedBox(height: 14),
              async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: AppErrorView(error: e, onRetry: () => ref.invalidate(marketingInsightsProvider)),
                ),
                data: (d) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MktCard(
                      title: 'Booking Timeline — Seasonality',
                      icon: Icons.show_chart_rounded,
                      subtitle: 'By event date · ${d.totalBookings} bookings this period',
                      child: _TimelineSection(months: d.byMonth),
                    ),
                    const SizedBox(height: 12),
                    MktCard(
                      title: 'By Culture / Community',
                      icon: Icons.diversity_3_outlined,
                      child: _cultureSection(d.byCulture),
                    ),
                    const SizedBox(height: 12),
                    MktCard(
                      title: 'Location',
                      icon: Icons.place_outlined,
                      subtitle: 'Booking volume across Kerala',
                      child: _locationSection(isMobile, d),
                    ),
                    const SizedBox(height: 12),
                    MktCard(
                      title: 'Data Quality — event dates, culture & location',
                      icon: Icons.fact_check_outlined,
                      subtitle: 'Completeness across all existing bookings',
                      child: _coverageSection(context, d.coverage),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Culture: donut + ranked list (with revenue) ──
  Widget _cultureSection(List<SegmentRow> rows) {
    final meaningful = rows
        .where((r) => r.name != 'Not specified' && r.bookings > 0)
        .toList();
    if (meaningful.isEmpty) {
      return const MktEmpty(
        'No community data yet. Set "Community / Culture" on the Manage Booking screen (or it is inferred from the service) to build this segment.',
        icon: Icons.diversity_3_outlined,
        height: 130,
      );
    }
    final total =
        meaningful.fold<int>(0, (s, r) => s + r.bookings).clamp(1, 1 << 30);
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
                      color: Mkt.series(i),
                      radius: 20,
                      showTitle: false,
                    ),
                ],
              )),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$total', style: mktText(20, weight: FontWeight.w900)),
                  Text('bookings', style: mktText(10, color: Mkt.inkSoft)),
                ],
              ),
            ],
          ),
        ),
        16.wg,
        Expanded(child: _ranked(meaningful, colored: true)),
      ],
    );
  }

  // ── Location: Kerala region map + district/pincode ranked (where present) ──
  Widget _locationSection(bool isMobile, MarketingInsights d) {
    final hasDistrict = d.byDistrict.isNotEmpty;
    final hasPincode = d.byPincode.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeralaBookingsMap(rows: d.byRegion, height: isMobile ? 280 : 340),
        12.hg,
        _cols(isMobile, [
          _subCard('By Region', _ranked(d.byRegion, colored: false)),
          if (hasDistrict)
            _subCard('By District', _ranked(d.byDistrict, colored: false)),
        ]),
        if (hasPincode) ...[
          12.hg,
          _subCard('By Pincode', _ranked(d.byPincode, colored: false)),
        ],
        if (!hasDistrict && !hasPincode) ...[
          10.hg,
          _note(
              'District & pincode were not captured for older imported bookings — these breakdowns fill in as new bookings record them.'),
        ],
      ],
    );
  }

  // ── Data-quality / coverage panel ──
  Widget _coverageSection(BuildContext context, Coverage c) {
    final knownCulture = c.cultureExplicit + c.cultureInferred;
    final cultureTotal =
        (knownCulture + c.cultureUnknown).clamp(1, 1 << 30);
    final locTotal = c.eventTotal.clamp(1, 1 << 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _meter('Event date', c.eventWithDate, c.eventTotal,
            detail: c.eventMissing == 0
                ? 'Every booking has a real event date'
                : '${c.eventMissing} missing an event date'),
        10.hg,
        _meter('Culture / community', knownCulture, cultureTotal,
            detail:
                'explicit ${c.cultureExplicit} · inferred ${c.cultureInferred} · unknown ${c.cultureUnknown}'),
        10.hg,
        _meter('Location', c.locWithRegion, locTotal,
            detail:
                'region ${c.locWithRegion} · district ${c.locWithDistrict} · pincode ${c.locWithPincode}'),
        if (c.eventMissing == 0) ...[
          12.hg,
          _note(
              '✓ Every booking carries a real event date, so the timeline above reflects actual event seasonality — not entry dates.',
              good: true),
        ],
        14.hg,
        const Divider(color: Mkt.border, height: 1),
        12.hg,
        if (c.worklist.isEmpty)
          _note('✓ No bookings are missing event / culture / location data.',
              good: true)
        else ...[
          Text('Needs attention (${c.worklist.length})', style: mktText(13, weight: FontWeight.w700)),
          6.hg,
          Text('Tap a booking to open it and fill the missing field.', style: mktText(11.5, color: Mkt.inkSoft)),
          8.hg,
          for (final w in c.worklist) _worklistRow(context, w),
        ],
      ],
    );
  }

  Widget _worklistRow(BuildContext context, CoverageItem w) {
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
                      style: mktText(13, weight: FontWeight.w600)),
                  4.hg,
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(date, style: mktText(11, color: Mkt.inkSoft)),
                      for (final m in w.missing) _missChip(m),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Mkt.inkSoft),
          ],
        ),
      ),
    );
  }

  Widget _missChip(String key) {
    final label = switch (key) {
      'eventDate' => 'event date',
      'culture' => 'culture',
      'location' => 'location',
      _ => key,
    };
    return MktChip(label, color: Mkt.bad);
  }

  Widget _meter(String label, int have, int total, {required String detail}) {
    final pct = total > 0 ? (have / total).clamp(0.0, 1.0) : 0.0;
    final color = pct >= 0.9 ? Mkt.good : (pct >= 0.5 ? Mkt.warn : Mkt.bad);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: mktText(13, weight: FontWeight.w600)),
            ),
            Text('$have / $total  (${(pct * 100).round()}%)', style: mktText(12, weight: FontWeight.w700)),
          ],
        ),
        6.hg,
        MktProgress(pct: (pct * 100).round(), color: color, height: 9, showLabel: false),
        4.hg,
        Text(detail, style: mktText(11, color: Mkt.inkSoft)),
      ],
    );
  }

  // ── Ranked bars (with revenue subtitle) ──
  Widget _ranked(List<SegmentRow> rows, {required bool colored}) {
    if (rows.isEmpty) return const MktEmpty('No data yet.', icon: Icons.bar_chart_rounded);
    final max = rows.fold<int>(1, (m, r) => r.bookings > m ? r.bookings : m);
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
                      Text(rows[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12)),
                      if (rows[i].revenue > 0)
                        Text(_money(rows[i].revenue), style: mktText(10, color: Mkt.inkSoft)),
                    ],
                  ),
                ),
                Expanded(
                  child: MktProgress(
                    pct: (rows[i].bookings / max * 100).round(),
                    color: colored ? Mkt.series(i) : Mkt.primaryLight,
                    height: 9,
                    showLabel: false,
                  ),
                ),
                8.wg,
                Text('${rows[i].bookings}', style: mktText(12, weight: FontWeight.w800)),
              ],
            ),
          ),
      ],
    );
  }

  // ── FY selector ──
  Widget _fyDropdown(WidgetRef ref, int value, int nowFy) {
    final years = [nowFy, nowFy - 1, nowFy - 2, nowFy - 3];
    return MktDropdownPill<int>(
      value: value,
      icon: Icons.calendar_today_outlined,
      options: [for (final y in years) (y, 'FY ${_fyLabel(y)}')],
      onChanged: (v) {
        ref.read(marketingFyProvider.notifier).state = v;
        ref.invalidate(marketingInsightsProvider);
      },
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

  Widget _subCard(String title, Widget child) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Mkt.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Mkt.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: mktText(12.5, weight: FontWeight.w700)),
            8.hg,
            child,
          ],
        ),
      );

  Widget _note(String t, {bool good = false}) {
    final c = good ? Mkt.good : Mkt.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Mkt.tint(c, 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(t, style: mktText(12, color: good ? Mkt.good : Mkt.inkSoft)),
    );
  }

  // ── formatting / FY helpers ──
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
  final List<SegmentRow> months;
  const _TimelineSection({required this.months});

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
    final months = widget.months;
    if (months.isEmpty) {
      return const MktEmpty('No bookings in this period.', icon: Icons.show_chart_rounded);
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
                style: mktText(12, weight: FontWeight.w600),
              ),
            ),
            _toggle(),
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
                getTooltipColor: (_) => Mkt.ink,
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
            gridData: const FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: _gridLine,
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
                    style: mktText(9, color: Mkt.inkSoft),
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
                          style: mktText(8.5, color: Mkt.inkSoft)),
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
                      color: i == peakIdx ? Mkt.warn : Mkt.primaryLight,
                    ),
                  ],
                ),
            ],
          )),
        ),
      ],
    );
  }

  static FlLine _gridLine(double _) => const FlLine(color: Mkt.border, strokeWidth: 0.6);

  Widget _toggle() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MktFilterChip(label: 'Bookings', selected: !_revenue, onTap: () => setState(() => _revenue = false)),
          6.wg,
          MktFilterChip(label: 'Revenue', selected: _revenue, onTap: () => setState(() => _revenue = true)),
        ],
      );
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
