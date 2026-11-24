import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/data/visitor_stats.dart';
import 'package:nizan_crm/features/website/presentation/studio/studio_widgets.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';

/// Website Studio → Overview → Visitors: the website's own anonymous counter.
class VisitorsCard extends ConsumerStatefulWidget {
  const VisitorsCard({super.key});

  @override
  ConsumerState<VisitorsCard> createState() => _VisitorsCardState();
}

class _VisitorsCardState extends ConsumerState<VisitorsCard> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(websiteVisitorsProvider(_days));

    return StudioCard(
      title: 'Visitors',
      subtitle: 'Counted by the website itself — anonymous, no personal details',
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 7, label: Text('7 days')),
              ButtonSegment(value: 30, label: Text('30 days')),
              ButtonSegment(value: 90, label: Text('90 days')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(websiteVisitorsProvider(_days)),
          ),
        ],
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Row(
          children: [
            Icon(Icons.error_outline, color: crm.destructive),
            const SizedBox(width: 8),
            Expanded(child: Text(e.toString())),
          ],
        ),
        data: (s) => _VisitorsBody(stats: s),
      ),
    );
  }
}

class _VisitorsBody extends StatelessWidget {
  final VisitorStats stats;
  const _VisitorsBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final s = stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth < 600 ? 2 : 4;
            final w = (box.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StudioStatTile(
                  width: w,
                  icon: Icons.people_alt_outlined,
                  label: 'Visitors',
                  value: '${s.visitors}',
                  note: 'Today ${s.todayVisitors}',
                ),
                StudioStatTile(
                  width: w,
                  icon: Icons.visibility_outlined,
                  label: 'Page views',
                  value: '${s.pageViews}',
                  note: '${s.visits} visits · ${s.pagesPerVisit} pages each',
                ),
                StudioStatTile(
                  width: w,
                  icon: Icons.event_available_outlined,
                  label: 'Booking requests',
                  value: '${s.bookingRequests}',
                  note: '${_pct(s.bookingRate)} of visitors',
                  accent: crm.success,
                ),
                StudioStatTile(
                  width: w,
                  icon: Icons.fiber_new_outlined,
                  label: 'New visitors',
                  value: '${s.newVisitors}',
                  note: '${s.returningVisitors} came back',
                  accent: crm.warning,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (s.pageViews == 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: crm.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: crm.border),
            ),
            child: Text(
              'No visits counted in this period yet. Counting starts once the updated '
              'website and CRM backend are live.',
              style: TextStyle(fontSize: 13, color: crm.textSecondary),
            ),
          )
        else ...[
          SizedBox(height: 190, child: _DailyChart(days: s.daily)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 860 ? 3 : (box.maxWidth >= 560 ? 2 : 1);
              final w = (box.maxWidth - 16 * (cols - 1)) / cols;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: w,
                    child: _Breakdown(
                      title: 'Top pages',
                      rows: s.pages,
                      label: visitorPageLabel,
                      showViews: true,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _Breakdown(
                      title: 'Where visitors came from',
                      rows: s.sources,
                      label: visitorSourceLabel,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _Breakdown(
                      title: 'Devices',
                      rows: s.devices,
                      label: visitorDeviceLabel,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Ad-blockers hide some visits from every counter, so real numbers are a little higher. '
          'Visit details are kept for ${s.retentionDays} days.',
          style: TextStyle(fontSize: 11, color: crm.textSecondary),
        ),
      ],
    );
  }

  static String _pct(double v) =>
      '${v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(1)}%';
}

class _DailyChart extends StatelessWidget {
  final List<VisitorDay> days;
  const _DailyChart({required this.days});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _short(String day) {
    final p = day.split('-');
    if (p.length != 3) return day;
    final m = int.tryParse(p[1]) ?? 1;
    return '${int.tryParse(p[2]) ?? p[2]} ${_months[(m - 1).clamp(0, 11)]}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final peak = days.fold<int>(0, (m, d) => math.max(m, d.visitors));
    final maxY = math.max(4, (peak * 1.2).ceil()).toDouble();
    // Label about 6 days along the bottom whatever the range.
    final every = math.max(1, (days.length / 6).ceil());
    final barWidth = days.length > 45 ? 4.0 : (days.length > 14 ? 8.0 : 18.0);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final d = days[group.x];
              return BarTooltipItem(
                '${_short(d.day)}\n${d.visitors} visitors · ${d.pageViews} views',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: crm.border.faded(0.4), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: maxY / 4,
              getTitlesWidget: (v, meta) => Text(
                v.toInt().toString(),
                style: TextStyle(fontSize: 9, color: crm.textSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                if (i % every != 0 && i != days.length - 1) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_short(days[i].day), style: TextStyle(fontSize: 9, color: crm.textSecondary)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].visitors.toDouble(),
                  width: barWidth,
                  color: crm.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  final String title;
  final List<VisitorRow> rows;
  final String Function(String) label;
  final bool showViews;

  const _Breakdown({
    required this.title,
    required this.rows,
    required this.label,
    this.showViews = false,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final top = rows.fold<int>(0, (m, r) => math.max(m, r.visitors));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text('—', style: TextStyle(color: crm.textSecondary))
        else
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label(r.label),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                        ),
                      ),
                      Text(
                        showViews ? '${r.visitors}  ·  ${r.views} views' : '${r.visitors}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: crm.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: top == 0 ? 0 : r.visitors / top,
                      minHeight: 5,
                      backgroundColor: crm.border.faded(0.4),
                      color: crm.primary,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
