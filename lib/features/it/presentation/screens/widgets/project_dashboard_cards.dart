import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/rupees.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/domain/project_dashboard_stats.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_dashboard_kit.dart';

// The project dashboard's cards about the projects themselves: the five headline numbers, progress, what stands out,
// the departments and the timeline. (Tasks and notifications are in project_dashboard_activity.dart.)
// None of these has a LayoutBuilder in it that the page puts inside an IntrinsicHeight; the page tells them how wide
// they are (`compact`) instead.

// ── The five headline numbers ────────────────────────────────────────────────

class _Kpi {
  const _Kpi({
    required this.keyName,
    required this.label,
    this.short,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    this.chip,
    this.chipColor,
  });
  final String keyName;
  final String label;

  /// Used instead of [label] on a narrow card.
  final String? short;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final String? chip;
  final Color? chipColor;
}

class DashKpiStrip extends StatelessWidget {
  const DashKpiStrip({super.key, required this.stats});
  final ProjectDashboardStats stats;

  List<_Kpi> _kpis(CrmTheme crm) {
    final n = stats.startedInSpan;
    return [
      _Kpi(
        keyName: 'total',
        label: 'Total Projects',
        value: '${stats.total}',
        caption: 'in this period',
        icon: Icons.layers_rounded,
        color: crm.primary,
        chip: n > 0 ? '+$n new' : null,
        chipColor: const Color(0xFF22A06B),
      ),
      _Kpi(
        keyName: 'active',
        label: 'Active Projects',
        value: '${stats.active}',
        caption: 'of all projects',
        icon: Icons.play_arrow_rounded,
        color: const Color(0xFF22A06B),
        chip: '${stats.percentOfTotal(stats.active)}%',
        chipColor: const Color(0xFF22A06B),
      ),
      _Kpi(
        keyName: 'completed',
        label: 'Completed Projects',
        short: 'Completed',
        value: '${stats.completed}',
        caption: 'of all projects',
        icon: Icons.check_rounded,
        color: const Color(0xFF3B82F6),
        chip: '${stats.percentOfTotal(stats.completed)}%',
        chipColor: const Color(0xFF3B82F6),
      ),
      _Kpi(
        keyName: 'hold',
        label: 'On Hold',
        value: '${stats.onHold}',
        caption: 'past their end date',
        icon: Icons.pause_rounded,
        color: const Color(0xFFF5A524),
        chip: '${stats.overdue.length} overdue',
        chipColor: stats.overdue.isEmpty ? const Color(0xFF22A06B) : const Color(0xFFDC4C4C),
      ),
      _Kpi(
        keyName: 'people',
        label: 'Team Members',
        value: '${stats.people}',
        caption: 'working on projects',
        icon: Icons.groups_rounded,
        color: const Color(0xFF8B5CF6),
        chip: '${stats.departments.length} dept${stats.departments.length == 1 ? '' : 's'}',
        chipColor: const Color(0xFF8B5CF6),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final kpis = _kpis(crm);
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 5 : (c.maxWidth >= 560 ? 3 : 2);
        final compact = c.maxWidth / cols < 190;
        const gap = 12.0;
        final rows = <List<_Kpi>>[for (var i = 0; i < kpis.length; i += cols) kpis.sublist(i, i + cols > kpis.length ? kpis.length : i + cols)];
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows[r].length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(child: _KpiCard(rows[r][i], compact: compact)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.k, {required this.compact});
  final _Kpi k;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final tile = compact ? 36.0 : 46.0;
    return Container(
      key: Key('pd_kpi_${k.keyName}'),
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: tile,
            height: tile,
            decoration: BoxDecoration(color: k.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(compact ? 10 : 13)),
            child: Icon(k.icon, size: compact ? 20 : 24, color: k.color),
          ),
          SizedBox(width: compact ? 9 : 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  compact ? (k.short ?? k.label) : k.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: compact ? 11.5 : 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      k.value,
                      style: TextStyle(
                        fontSize: compact ? 24 : 30,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                    if (k.chip != null) DashPill(k.chip!, k.chipColor ?? k.color),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  k.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress overview: where every project stands, and how fast work is getting done ──

class ProgressOverviewCard extends StatefulWidget {
  const ProgressOverviewCard({super.key, required this.stats, required this.tasks, required this.now, this.onRetryTasks});
  final ProjectDashboardStats stats;

  /// The leaf-task list of the projects in the period (null value while loading).
  final AsyncValue<List<ITTask>> tasks;
  final DateTime now;
  final VoidCallback? onRetryTasks;

  @override
  State<ProgressOverviewCard> createState() => _ProgressOverviewCardState();
}

class _ProgressOverviewCardState extends State<ProgressOverviewCard> {
  TrendWindow _window = TrendWindow.yearly;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final s = widget.stats;
    return DashCard(
      key: const Key('pd_progress_card'),
      title: 'Project Progress Overview',
      subtitle: 'Overall completion status of all projects',
      icon: Icons.donut_large_rounded,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 640;
          final status = _StatusDonut(stats: s);
          final toggle = DashSegmented<TrendWindow>(
            keyPrefix: 'pd_trend',
            dense: true,
            value: _window,
            options: [for (final w in TrendWindow.values) (w, w.label)],
            onChanged: (w) => setState(() => _window = w),
          );
          final trend = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // beside the title when there is room; under it (and scrollable) when there is not
              if (c.maxWidth >= 440)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Task Completion Trend',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
                      ),
                    ),
                    toggle,
                  ],
                )
              else ...[
                Text(
                  'Task Completion Trend',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: toggle),
              ],
              const SizedBox(height: 10),
              widget.tasks.when(
                loading: () => const DashStatus.loading(height: 190),
                error: (_, _) => DashStatus.failed(height: 190, onRetry: widget.onRetryTasks),
                data: (tasks) => _TrendChart(tasks: tasks, window: _window, now: widget.now),
              ),
            ],
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: c.maxWidth >= 860 ? 340 : 300, child: status),
                Container(width: 1, height: 220, margin: const EdgeInsets.symmetric(horizontal: 18), color: crm.border),
                Expanded(child: trend),
              ],
            );
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [status, const SizedBox(height: 18), trend]);
        },
      ),
    );
  }
}

class _StatusDonut extends StatelessWidget {
  const _StatusDonut({required this.stats});
  final ProjectDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (stats.total == 0) return const DashEmpty('No projects run in this period.', icon: Icons.layers_clear_outlined, height: 200);
    final shown = [
      for (final s in stats.slices)
        if (s.count > 0 || s.bucket != ProjectBucket.cancelled) s,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 44,
                  startDegreeOffset: -90,
                  sections: [
                    for (final s in shown.where((s) => s.count > 0))
                      PieChartSectionData(value: s.count.toDouble(), color: bucketColor(s.bucket), radius: 17, showTitle: false),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${stats.progress}%',
                    key: const Key('pd_overall'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.5),
                  ),
                  Text(
                    'Overall\nProgress',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9.5, height: 1.15, color: crm.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in shown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: bucketColor(s.bucket), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.bucket.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                        ),
                      ),
                      Text(
                        '${s.count}',
                        key: Key('pd_status_${s.bucket.name}'),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                      ),
                      SizedBox(
                        width: 38,
                        child: Text(
                          '${stats.percentOfTotal(s.count)}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 12, color: crm.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.tasks, required this.window, required this.now});
  final List<ITTask> tasks;
  final TrendWindow window;
  final DateTime now;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _label(DateTime d) => window == TrendWindow.yearly ? _months[d.month - 1] : '${d.day} ${_months[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final points = completionTrend(tasks, window, now);
    final measured = points.where((p) => p.percent != null).length;
    if (measured < 2) {
      return const DashEmpty(
        'Not enough task history yet — it builds up as tasks are created and finished.',
        icon: Icons.show_chart_rounded,
        height: 190,
      );
    }
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        if (points[i].percent != null) FlSpot(i.toDouble(), points[i].percent!.clamp(0, 100).toDouble()),
    ];
    final bar = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.22,
      preventCurveOverShooting: true,
      color: crm.primary,
      barWidth: 2.4,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, _, _, _) => FlDotCirclePainter(radius: 2.8, color: crm.primary, strokeWidth: 1.6, strokeColor: crm.surface),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [crm.primary.withValues(alpha: 0.18), crm.primary.withValues(alpha: 0.0)],
        ),
      ),
    );
    final step = window == TrendWindow.yearly ? 1 : 2;
    return SizedBox(
      key: const Key('pd_trend_chart'),
      height: 190,
      // room on the right for the label that stands on the latest point
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 6),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            minY: 0,
            maxY: 100,
            clipData: const FlClipData.none(),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) => FlLine(color: crm.border, strokeWidth: 1, dashArray: const [3, 4]),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 25,
                  getTitlesWidget: (v, meta) => Text('${v.toInt()}%', style: TextStyle(fontSize: 10, color: crm.textSecondary)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (v != i.toDouble() || i < 0 || i >= points.length) return const SizedBox.shrink();
                    // always name the last point; thin out the rest so labels never touch
                    final last = i == points.length - 1;
                    if (!last && ((points.length - 1 - i) % step != 0 || (points.length - 1 - i) < step)) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(_label(points[i].at), style: TextStyle(fontSize: 10, color: crm.textSecondary)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [bar],
            lineTouchData: LineTouchData(
              enabled: false, // only the standing label on the latest point
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => crm.primary,
                tooltipBorderRadius: BorderRadius.circular(8),
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem('${s.y.round()}%', const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                ],
              ),
            ),
            showingTooltipIndicators: [
              ShowingTooltipIndicators([LineBarSpot(bar, 0, spots.last)]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── What stands out ──────────────────────────────────────────────────────────

class KeyInsightsCard extends StatelessWidget {
  const KeyInsightsCard({super.key, required this.insights});
  final List<Insight> insights;

  static (IconData, Color) _look(InsightTone t) => switch (t) {
    InsightTone.good => (Icons.trending_up_rounded, const Color(0xFF22A06B)),
    InsightTone.info => (Icons.event_outlined, const Color(0xFF3B82F6)),
    InsightTone.warn => (Icons.pause_circle_outline_rounded, const Color(0xFFF5A524)),
    InsightTone.bad => (Icons.warning_amber_rounded, const Color(0xFFDC4C4C)),
  };

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return DashCard(
      title: 'Key Insights',
      icon: Icons.lightbulb_outline_rounded,
      iconColor: const Color(0xFFF5A524),
      child: insights.isEmpty
          ? const DashEmpty('Nothing to point out yet.', icon: Icons.lightbulb_outline_rounded)
          : Column(
              children: [
                for (var i = 0; i < insights.length; i++)
                  Padding(
                    key: Key('pd_insight_$i'),
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _look(insights[i].tone).$2.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_look(insights[i].tone).$1, size: 18, color: _look(insights[i].tone).$2),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insights[i].title,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                insights[i].detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, height: 1.3, color: crm.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Departments ──────────────────────────────────────────────────────────────

enum DeptView { count, progress }

class DepartmentDonutCard extends StatefulWidget {
  const DepartmentDonutCard({super.key, required this.departments, required this.colorOf});
  final List<DeptStat> departments;
  final Color Function(String name) colorOf;

  @override
  State<DepartmentDonutCard> createState() => _DepartmentDonutCardState();
}

class _DepartmentDonutCardState extends State<DepartmentDonutCard> {
  DeptView _view = DeptView.count;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final all = widget.departments;
    final totalProjects = all.fold<int>(0, (a, d) => a + d.projects);
    const keep = 6;
    final shown = all.take(keep).toList();
    final rest = all.skip(keep).toList();
    final restProjects = rest.fold<int>(0, (a, d) => a + d.projects);
    return DashCard(
      key: const Key('pd_dept_card'),
      title: 'Projects by Department',
      icon: Icons.corporate_fare_rounded,
      iconColor: const Color(0xFF3B82F6),
      child: all.isEmpty
          ? const DashEmpty('No projects in this period.', icon: Icons.corporate_fare_rounded, height: 170)
          : Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: DashSegmented<DeptView>(
                    keyPrefix: 'pd_dept_view',
                    dense: true,
                    value: _view,
                    options: const [(DeptView.count, 'Count'), (DeptView.progress, 'Progress %')],
                    onChanged: (v) => setState(() => _view = v),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 46,
                              startDegreeOffset: -90,
                              sections: [
                                for (final d in shown)
                                  PieChartSectionData(value: d.projects.toDouble(), color: widget.colorOf(d.name), radius: 16, showTitle: false),
                                if (restProjects > 0)
                                  PieChartSectionData(value: restProjects.toDouble(), color: const Color(0xFF9AA0A6), radius: 16, showTitle: false),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${all.length}',
                                key: const Key('pd_dept_total'),
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.5),
                              ),
                              Text(all.length == 1 ? 'Department' : 'Departments', style: TextStyle(fontSize: 9.5, color: crm.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final d in shown) _row(crm, d.name, widget.colorOf(d.name), d.projects, d.progress, totalProjects),
                          if (restProjects > 0) _row(crm, 'Other', const Color(0xFF9AA0A6), restProjects, _avgProgress(rest), totalProjects),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  int _avgProgress(List<DeptStat> l) {
    final w = l.fold<int>(0, (a, d) => a + (d.tasks < 1 ? 1 : d.tasks));
    return w == 0 ? 0 : (l.fold<double>(0, (a, d) => a + d.progress * (d.tasks < 1 ? 1 : d.tasks)) / w).round();
  }

  Widget _row(CrmTheme crm, String name, Color color, int count, int progress, int total) {
    final byCount = _view == DeptView.count;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
            ),
          ),
          if (byCount) ...[
            Text(
              '$count',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
            ),
            SizedBox(
              width: 38,
              child: Text(
                '${total == 0 ? 0 : (count * 100 / total).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: crm.textSecondary),
              ),
            ),
          ] else
            SizedBox(
              width: 46,
              child: Text(
                '$progress%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

class TopDepartmentsCard extends StatelessWidget {
  const TopDepartmentsCard({super.key, required this.top, required this.colorOf});
  final List<DeptStat> top;
  final Color Function(String name) colorOf;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return DashCard(
      title: 'Top Performing Departments',
      subtitle: 'By share of their tasks done',
      icon: Icons.emoji_events_outlined,
      iconColor: const Color(0xFFF08A24),
      child: top.isEmpty
          ? const DashEmpty('No tasks to measure yet.', icon: Icons.emoji_events_outlined)
          : Column(
              children: [
                for (var i = 0; i < top.length; i++)
                  Padding(
                    key: Key('pd_top_$i'),
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          child: Text(
                            top[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: top[i].progress / 100,
                              minHeight: 8,
                              backgroundColor: crm.background,
                              valueColor: AlwaysStoppedAnimation(colorOf(top[i].name)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${top[i].progress}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Timeline ─────────────────────────────────────────────────────────────────

/// One column of the timeline's time scale: a label and how many days of the visible range it covers.
class TimelineColumn {
  const TimelineColumn(this.label, this.days);
  final String label;
  final int days;
}

/// The scale across the top: months up to a quarter, quarters up to a couple of years, years beyond.
List<TimelineColumn> timelineColumns(DaySpan span) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final cols = <TimelineColumn>[];
  final unit = span.days <= 130 ? 1 : (span.days <= 800 ? 3 : 12); // months per column
  var cur = DateTime(span.start.year, span.start.month - (unit == 1 ? 0 : (span.start.month - 1) % unit), 1);
  while (!cur.isAfter(span.end)) {
    final next = DateTime(cur.year, cur.month + unit, 1);
    final from = cur.isBefore(span.start) ? span.start : cur;
    final to = DateTime(next.year, next.month, next.day - 1); // not "minus 24 hours": a clock change would land on the wrong day
    final lastDay = to.isAfter(span.end) ? span.end : to;
    final days = daysBetween(from, lastDay) + 1;
    final label = unit == 1 ? '${months[cur.month - 1]} ${cur.year}' : (unit == 3 ? 'Q${(cur.month - 1) ~/ 3 + 1} ${cur.year}' : '${cur.year}');
    if (days > 0) cols.add(TimelineColumn(label, days));
    cur = next;
  }
  return cols;
}

class UpcomingProjectsCard extends StatelessWidget {
  const UpcomingProjectsCard({
    super.key,
    required this.rows,
    required this.span,
    required this.now,
    required this.onOpen,
    required this.onViewAll,
    this.compact = false,
  });
  final List<TimelineRow> rows;

  /// The days the chart covers.
  final DaySpan span;
  final DateTime now;
  final void Function(String projectId) onOpen;
  final VoidCallback onViewAll;
  final bool compact;

  static const _rowH = 46.0;
  static const _headH = 30.0;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final cols = timelineColumns(span);
    final labelW = compact ? 104.0 : 156.0;
    final today = DateTime(now.year, now.month, now.day);
    final todayAt = span.contains(today) ? (daysBetween(span.start, today) + 0.5) / span.days : null;
    return DashCard(
      key: const Key('pd_upcoming_card'),
      title: 'Upcoming & Ongoing Projects',
      icon: Icons.view_timeline_outlined,
      iconColor: const Color(0xFF8B5CF6),
      trailing: DashLink('View All', onTap: onViewAll),
      child: rows.isEmpty
          ? const DashEmpty('No dated projects still to finish in this period.', icon: Icons.view_timeline_outlined, height: 170)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelW,
                  child: Column(
                    children: [
                      SizedBox(
                        height: _headH,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Project',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary),
                          ),
                        ),
                      ),
                      for (final r in rows)
                        InkWell(
                          key: Key('pd_up_${r.project.id}'),
                          onTap: () => onOpen(r.project.id),
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: _rowH,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.project.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                                  ),
                                  Text(
                                    deptLabel(r.project.targetDepartment),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: _headH,
                        child: Row(
                          children: [
                            for (final c in cols)
                              Expanded(
                                flex: c.days,
                                child: Text(
                                  c.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  softWrap: false,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: crm.textSecondary),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Stack(
                        children: [
                          // the scale's dividers
                          Positioned.fill(
                            child: Row(
                              children: [
                                for (var i = 0; i < cols.length; i++)
                                  Expanded(
                                    flex: cols[i].days,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(color: crm.border),
                                          right: i == cols.length - 1 ? BorderSide(color: crm.border) : BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            children: [for (final r in rows) SizedBox(height: _rowH, child: _bar(context, r))],
                          ),
                          if (todayAt != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Align(
                                  alignment: Alignment(todayAt * 2 - 1, 0),
                                  child: Container(key: const Key('pd_today'), width: 1.6, color: crm.primary.withValues(alpha: 0.55)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// The status colour, darkened enough to read on both the solid part of a bar and the tinted rest.
  static Color _ink(Color c) => HSLColor.fromColor(c).withLightness(0.16).withSaturation(0.7).toColor();

  Widget _bar(BuildContext context, TimelineRow r) {
    final p = r.project;
    final from = p.startDate!.isBefore(span.start) ? span.start : DateTime(p.startDate!.year, p.startDate!.month, p.startDate!.day);
    final to = p.endDate!.isAfter(span.end) ? span.end : DateTime(p.endDate!.year, p.endDate!.month, p.endDate!.day);
    final left = daysBetween(span.start, from);
    final len = daysBetween(from, to) + 1;
    if (len < 1 || left < 0) return const SizedBox.shrink();
    final right = span.days - left - len;
    final color = r.overdue ? const Color(0xFFDC4C4C) : bucketColor(r.bucket);
    final label = r.overdue ? 'Overdue' : r.bucket.label;
    return Row(
      children: [
        if (left > 0) Spacer(flex: left),
        Expanded(
          flex: len,
          child: Container(
            key: Key('pd_bar_${p.id}'),
            height: 22,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.26), borderRadius: BorderRadius.circular(6)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: (p.progress.clamp(0, 100)) / 100,
                  child: Container(color: color),
                ),
                Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _ink(color)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (right > 0) Spacer(flex: right),
      ],
    );
  }
}

// ── Money ────────────────────────────────────────────────────────────────────

/// "Budget vs Actual": what the finance head approved for the projects in the period against what has been charged to them
/// (spent = approved expenses, committed = waiting for approval), by department, and the projects that need a look. Only the
/// projects whose amounts the viewer may see are in it, and the card is not shown when there are none.
class BudgetVsActualCard extends StatelessWidget {
  const BudgetVsActualCard({super.key, required this.totals, required this.onOpenProject});
  final BudgetTotals totals;
  final void Function(String projectId) onOpenProject;

  static Color _levelColor(String level) => switch (level) {
    'over' => const Color(0xFFB91C1C),
    'warn' => const Color(0xFFB45309),
    _ => const Color(0xFF15803D),
  };

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final t = totals;
    final color = _levelColor(t.level);
    final pct = ((t.fraction ?? 0) * 100).round();
    final watch = [...t.over, ...t.near].take(4).toList();
    return DashCard(
      key: const Key('pd_budget_card'),
      title: 'Budget vs Actual',
      subtitle: 'Against what Finance approved · ${t.projects} project${t.projects == 1 ? '' : 's'}',
      icon: Icons.account_balance_wallet_outlined,
      iconColor: const Color(0xFF22A06B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (t.fraction ?? 0).clamp(0.0, 1.0),
                      strokeWidth: 10,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$pct%',
                            key: const Key('pd_budget_pct'),
                            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.4),
                          ),
                          Text(
                            t.level == 'over' ? 'Over budget' : 'used',
                            style: TextStyle(fontSize: 10, color: t.level == 'over' ? color : crm.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _legend(crm, const Color(0xFF3B82F6), 'Approved budget', rupees(t.approved), const Key('pd_budget_approved')),
                    _legend(crm, const Color(0xFF22A06B), 'Spent', rupees(t.spent), const Key('pd_budget_spent')),
                    if (t.committed > 0) _legend(crm, const Color(0xFFF5A524), 'Committed', rupees(t.committed), const Key('pd_budget_committed')),
                    _legend(
                      crm,
                      t.available < 0 ? color : const Color(0xFF9AA0A6),
                      t.available < 0 ? 'Over by' : 'Left',
                      rupees(t.available.abs()),
                      const Key('pd_budget_left'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (t.byDepartment.length > 1) ...[
            const SizedBox(height: 16),
            Text(
              'By department',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in t.byDepartment.take(6))
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${((d.fraction ?? 0) * 100).round()}%',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: crm.textSecondary),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            key: Key('pd_budget_dept_${d.name}'),
                            width: 16,
                            height: 6 + 46.0 * (d.fraction ?? 0).clamp(0.0, 1.0),
                            decoration: BoxDecoration(
                              color: _levelColor((d.fraction ?? 0) > 1 ? 'over' : ((d.fraction ?? 0) >= 0.8 ? 'warn' : 'ok')),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: crm.textSecondary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (watch.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Needs a look',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
            ),
            for (final p in watch)
              InkWell(
                key: Key('pd_budget_watch_${p.id}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onOpenProject(p.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary),
                        ),
                      ),
                      DashPill(
                        p.cost!.level == 'over'
                            ? 'Over · ${((p.cost!.usedFraction ?? 0) * 100).round()}%'
                            : '${((p.cost!.usedFraction ?? 0) * 100).round()}% used',
                        _levelColor(p.cost!.level),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _legend(CrmTheme crm, Color dot, String label, String value, Key key) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
        ),
        Text(
          value,
          key: key,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
        ),
      ],
    ),
  );
}
