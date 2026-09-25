import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';

/// Marketing Intelligence — customer promoter score (NPS) + trend, satisfaction,
/// artist utilization, financial-year slot utilization, and Pincode/Timeline/
/// Culture segmentation. All from one backend insights call.
class MarketingInsightsScreen extends ConsumerWidget {
  const MarketingInsightsScreen({super.key});

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
          padding: EdgeInsets.fromLTRB(
              isMobile ? 14 : 24, 18, isMobile ? 14 : 24, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Marketing Intelligence',
                          style: TextStyle(
                              fontSize: isMobile ? 22 : 27,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      Text('Promoter score · utilization · segments',
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
                child: AppErrorView(error: e, onRetry: () => ref.invalidate(marketingInsightsProvider)),
              ),
              data: (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI row
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _kpi(crm, isMobile, Icons.sentiment_very_satisfied_outlined,
                          '${d.nps.nps}', 'Promoter Score (NPS)',
                          '${d.nps.responses} responses', _npsColor(d.nps.nps)),
                      _kpi(crm, isMobile, Icons.star_border_rounded,
                          d.avgBrideScore.toStringAsFixed(1), 'Client Satisfaction',
                          'avg /5 · ${d.csatSubmitted} reviews',
                          const Color(0xFFF59E0B)),
                      _kpi(crm, isMobile, Icons.groups_2_outlined,
                          '${d.artistUtilPct}%', 'Artist Utilization',
                          '${d.artistBusy}/${d.artistTotal} on jobs',
                          const Color(0xFF6D5DF6)),
                      _kpi(crm, isMobile, Icons.event_seat_outlined,
                          '${d.slot.pct}%', 'Slot Utilization (FY)',
                          '${d.slot.totalBooked}/${d.slot.totalCapacity} slots',
                          const Color(0xFF0D9488)),
                    ],
                  ),
                  18.hg,

                  // NPS + utilization gauges
                  _cols(isMobile, [
                    _card(crm, 'Net Promoter Score', _npsBody(crm, d.nps)),
                    _card(crm, 'Utilization',
                        _utilBody(crm, d.artistUtilPct, d.slot)),
                  ]),
                  14.hg,

                  // Timeline (seasonality)
                  _card(crm, 'Booking Timeline (seasonality)',
                      _timeline(crm, d.byMonth)),
                  14.hg,

                  // Pincode / area + culture
                  _cols(isMobile, [
                    _card(crm, 'Top Areas (District)',
                        _ranked(crm, d.byDistrict, 'bookings')),
                    _card(crm, 'By Region', _ranked(crm, d.byRegion, 'bookings')),
                  ]),
                  14.hg,
                  _card(crm, 'By Culture / Community', _culture(crm, d.byCulture)),
                  18.hg,

                  // Re-engagement entry
                  _reEngagementCard(context, crm),
                ],
              ),
            ),
          ],
        ),
      ),
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

  // ── NPS body: split bar + monthly trend ──
  Widget _npsBody(CrmTheme crm, NpsSummary n) {
    final total =
        (n.promoters + n.passives + n.detractors).clamp(1, 1 << 30).toDouble();
    Widget seg(int v, Color c) => v == 0
        ? const SizedBox.shrink()
        : Expanded(flex: v, child: Container(height: 12, color: c));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${n.nps}',
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: _npsColor(n.nps))),
            8.wg,
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${n.responses} responses',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ),
          ],
        ),
        10.hg,
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Row(children: [
              seg(n.promoters, const Color(0xFF16A34A)),
              seg(n.passives, const Color(0xFFF59E0B)),
              seg(n.detractors, const Color(0xFFDC2626)),
            ]),
          ),
        8.hg,
        Row(
          children: [
            _legend(crm, 'Promoters', n.promoters, const Color(0xFF16A34A)),
            _legend(crm, 'Passives', n.passives, const Color(0xFFF59E0B)),
            _legend(crm, 'Detractors', n.detractors, const Color(0xFFDC2626)),
          ],
        ),
        if (n.trend.length >= 2) ...[
          16.hg,
          Text('NPS trend', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          8.hg,
          SizedBox(height: 90, child: _npsTrendChart(crm, n.trend)),
        ],
      ],
    );
  }

  Widget _npsTrendChart(CrmTheme crm, List<NpsPoint> trend) {
    final pts = trend.length > 12 ? trend.sublist(trend.length - 12) : trend;
    return LineChart(LineChartData(
      minY: -100,
      maxY: 100,
      gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 50,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: crm.border, strokeWidth: 0.6)),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 50,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: TextStyle(fontSize: 9, color: crm.textSecondary)))),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= pts.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_mLabel(pts[i].month),
                        style: TextStyle(fontSize: 8, color: crm.textSecondary)),
                  );
                })),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < pts.length; i++)
              FlSpot(i.toDouble(), pts[i].nps.toDouble())
          ],
          isCurved: true,
          color: crm.primary,
          barWidth: 2.5,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
              show: true, color: crm.primary.withValues(alpha: 0.10)),
        ),
      ],
    ));
  }

  // ── Utilization: two gauges ──
  Widget _utilBody(CrmTheme crm, int artistPct, SlotUtil slot) {
    return Row(
      children: [
        Expanded(child: _gauge(crm, artistPct, 'Artists', 'on live jobs')),
        Expanded(
            child: _gauge(crm, slot.pct, 'FY Slots',
                '${slot.totalBooked}/${slot.totalCapacity}')),
      ],
    );
  }

  Widget _gauge(CrmTheme crm, int pct, String title, String sub) {
    final color = pct >= 70
        ? const Color(0xFF16A34A)
        : (pct >= 40 ? const Color(0xFFF59E0B) : const Color(0xFF6D5DF6));
    return Column(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 0,
                centerSpaceRadius: 38,
                sections: [
                  PieChartSectionData(
                      value: pct.toDouble(),
                      color: color,
                      radius: 12,
                      showTitle: false),
                  PieChartSectionData(
                      value: (100 - pct).toDouble().clamp(0, 100),
                      color: crm.border,
                      radius: 12,
                      showTitle: false),
                ],
              )),
              Text('$pct%',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: crm.textPrimary)),
            ],
          ),
        ),
        6.hg,
        Text(title,
            style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
        Text(sub, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
      ],
    );
  }

  // ── Timeline / seasonality bars ──
  Widget _timeline(CrmTheme crm, List<SegmentRow> months) {
    if (months.isEmpty) return _muted(crm, 'No bookings in this period.');
    final max = months.fold<int>(1, (m, r) => r.bookings > m ? r.bookings : m);
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in months)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${m.bookings}',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: crm.textSecondary)),
                        3.hg,
                        Container(
                          height: (90 * (m.bookings / max)).clamp(2, 90),
                          decoration: BoxDecoration(
                            color: crm.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        4.hg,
                        Text(_mLabel(m.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 8.5, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Ranked segment bars (district / region) ──
  Widget _ranked(CrmTheme crm, List<SegmentRow> rows, String unit) {
    if (rows.isEmpty) return _muted(crm, 'No data yet.');
    final max = rows.fold<int>(1, (m, r) => r.bookings > m ? r.bookings : m);
    return Column(
      children: [
        for (final r in rows.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: crm.textPrimary)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: (r.bookings / max).clamp(0, 1),
                      minHeight: 9,
                      backgroundColor: crm.border,
                      valueColor: AlwaysStoppedAnimation(crm.primary),
                    ),
                  ),
                ),
                8.wg,
                Text('${r.bookings}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _culture(CrmTheme crm, List<SegmentRow> rows) {
    final meaningful =
        rows.where((r) => r.name != 'Not specified' && r.bookings > 0).toList();
    if (meaningful.isEmpty) {
      return _muted(crm,
          'No community data yet. Set "Community / Culture" on the Manage Booking screen to build this segment.');
    }
    return _ranked(crm, rows, 'bookings');
  }

  // ── Re-engagement entry card ──
  Widget _reEngagementCard(BuildContext context, CrmTheme crm) => InkWell(
        onTap: () => context.push('/marketing/re-engagement'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: crm.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: crm.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.campaign_outlined, color: crm.primary),
              12.wg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client Re-engagement',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: crm.textPrimary)),
                    2.hg,
                    Text(
                        'Past brides due for a re-touch — one-tap WhatsApp outreach.',
                        style: TextStyle(
                            fontSize: 12, color: crm.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: crm.textSecondary),
            ],
          ),
        ),
      );

  // ── shared layout helpers ──
  Widget _cols(bool isMobile, List<Widget> items) => isMobile
      ? Column(
          children: [
            for (final c in items)
              Padding(padding: const EdgeInsets.only(bottom: 14), child: c)
          ],
        )
      : IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i < items.length - 1) const SizedBox(width: 14),
              ],
            ],
          ),
        );

  Widget _card(CrmTheme crm, String title, Widget child) => Container(
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
            14.hg,
            child,
          ],
        ),
      );

  Widget _kpi(CrmTheme crm, bool isMobile, IconData icon, String value,
          String label, String sub, Color color) =>
      SizedBox(
        width: isMobile ? (_half(isMobile)) : 210,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: crm.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: color, size: 20),
              ),
              12.hg,
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: crm.textPrimary)),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: crm.textPrimary)),
              2.hg,
              Text(sub, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            ],
          ),
        ),
      );

  Widget _legend(CrmTheme crm, String label, int v, Color c) => Expanded(
        child: Row(
          children: [
            Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            5.wg,
            Flexible(
              child: Text('$label ($v)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            ),
          ],
        ),
      );

  Widget _muted(CrmTheme crm, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t, style: TextStyle(color: crm.textSecondary, fontSize: 13)),
      );

  static double _half(bool isMobile) => 160;

  static Color _npsColor(int nps) {
    if (nps >= 50) return const Color(0xFF16A34A);
    if (nps >= 0) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  static int _currentFyStartYear() {
    final n = DateTime.now();
    return n.month >= 4 ? n.year : n.year - 1;
  }

  static String _fyLabel(int startYear) =>
      '$startYear-${((startYear + 1) % 100).toString().padLeft(2, '0')}';

  static const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
      'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _mLabel(String ym) {
    // 'YYYY-MM' → 'Mon'
    final parts = ym.split('-');
    if (parts.length < 2) return ym;
    final m = int.tryParse(parts[1]) ?? 0;
    return (m >= 1 && m <= 12) ? _mon[m] : ym;
  }
}

extension _Gap on num {
  Widget get hg => SizedBox(height: toDouble());
  Widget get wg => SizedBox(width: toDouble());
}
