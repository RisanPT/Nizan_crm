import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/models/monthly_objective.dart';
import 'package:nizan_crm/features/it/domain/models/monthly_trend.dart';
import 'package:nizan_crm/features/it/domain/monthly_objective_stats.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_dashboard_kit.dart';
import 'package:nizan_crm/features/it/services/monthly_objective_service.dart';

// The cards of the Monthly Objectives page: status and priority pills, the five headline numbers, a card for each department, the
// trend line, target against achievement, what stands out, and the progress matrix. They draw what monthly_objective_stats.dart works out.

// ── small pieces ─────────────────────────────────────────────────────────────

Color statusColor(ObjectiveStatus s) => switch (s) {
  ObjectiveStatus.completed => const Color(0xFF22A06B),
  ObjectiveStatus.inProgress => const Color(0xFF3B82F6),
  ObjectiveStatus.notStarted => const Color(0xFF9AA0A6),
  ObjectiveStatus.partly => const Color(0xFFF5A524),
  ObjectiveStatus.missed => const Color(0xFFDC4C4C),
  ObjectiveStatus.cancelled => const Color(0xFF7A7A7A),
  ObjectiveStatus.postponed => const Color(0xFF8B5CF6),
};

IconData statusIcon(ObjectiveStatus s) => switch (s) {
  ObjectiveStatus.completed => Icons.check_circle_rounded,
  ObjectiveStatus.inProgress => Icons.play_circle_outline_rounded,
  ObjectiveStatus.notStarted => Icons.radio_button_unchecked_rounded,
  ObjectiveStatus.partly => Icons.timelapse_rounded,
  ObjectiveStatus.missed => Icons.highlight_off_rounded,
  ObjectiveStatus.cancelled => Icons.block_rounded,
  ObjectiveStatus.postponed => Icons.update_rounded,
};

class ObjectiveStatusPill extends StatelessWidget {
  const ObjectiveStatusPill(this.status, {super.key});
  final ObjectiveStatus status;

  @override
  Widget build(BuildContext context) => DashPill(status.label, statusColor(status), icon: statusIcon(status));
}

String priorityLabel(String p) => switch (p) {
  'critical' => 'Critical',
  'high' => 'High',
  'low' => 'Low',
  _ => 'Medium',
};

Color priorityColor(String p) => switch (p) {
  'critical' => const Color(0xFFB91C1C),
  'high' => const Color(0xFFDC4C4C),
  'low' => const Color(0xFF7A7A7A),
  _ => const Color(0xFFD99A1C),
};

class PriorityPill extends StatelessWidget {
  const PriorityPill(this.priority, {super.key});
  final String priority;

  @override
  Widget build(BuildContext context) => DashPill(
    priorityLabel(priority),
    priorityColor(priority),
    icon: switch (priority) {
      'critical' => Icons.keyboard_double_arrow_up_rounded,
      'high' => Icons.keyboard_arrow_up_rounded,
      'low' => Icons.keyboard_arrow_down_rounded,
      _ => Icons.drag_handle_rounded,
    },
  );
}

/// "AK  Akash" — the owner's initials in a circle, and the name ("You" when it is given to the person looking).
class OwnerChip extends StatelessWidget {
  const OwnerChip({super.key, required this.name, this.mine = false});
  final String name;
  final bool mine;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (name.isEmpty && !mine) return Text('—', style: TextStyle(fontSize: 12.5, color: crm.textSecondary));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: crm.primary.withValues(alpha: mine ? 0.9 : 0.12),
          child: Text(
            mine ? 'ME' : initials(name),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: mine ? Colors.white : crm.primary),
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            mine ? 'You' : name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: mine ? FontWeight.w800 : FontWeight.w600, color: mine ? crm.primary : crm.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// A department's icon, by what it is called.
IconData departmentIcon(String name) {
  final n = name.toLowerCase();
  bool has(String s) => n.contains(s);
  if (n == 'it' || has('tech') || has('software')) return Icons.laptop_mac_rounded;
  if (n == 'hr' || has('human') || has('people')) return Icons.diversity_3_rounded;
  if (has('financ')) return Icons.bar_chart_rounded;
  if (has('account')) return Icons.account_balance_rounded;
  if (has('crm') || has('sales') || has('client') || has('customer')) return Icons.support_agent_rounded;
  if (has('manag') || has('admin') || has('executive')) return Icons.corporate_fare_rounded;
  if (has('market') || has('brand') || has('content')) return Icons.campaign_rounded;
  if (has('artist') || has('creative') || has('design')) return Icons.brush_rounded;
  if (has('fleet') || has('driver') || has('transport')) return Icons.local_shipping_rounded;
  if (has('inventory') || has('stock') || has('store')) return Icons.inventory_2_rounded;
  return Icons.business_rounded;
}

/// A thin progress bar.
Widget progressBar(CrmTheme crm, int pct, {Color? color, double height = 7}) => ClipRRect(
  borderRadius: BorderRadius.circular(6),
  child: LinearProgressIndicator(
    value: pct.clamp(0, 100) / 100,
    minHeight: height,
    backgroundColor: crm.border.faded(1.6),
    valueColor: AlwaysStoppedAnimation(color ?? (pct >= 100 ? const Color(0xFF22A06B) : crm.primary)),
  ),
);

// ── the five headline numbers ────────────────────────────────────────────────

class _Kpi {
  const _Kpi({required this.keyName, required this.label, required this.value, required this.icon, required this.color, this.chip, this.chipColor, this.caption, this.captionColor, this.ring});
  final String keyName;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? chip;
  final Color? chipColor;
  final String? caption;
  final Color? captionColor;

  /// 0–100: draw the value as a ring instead of an icon tile.
  final int? ring;
}

class MonthlyKpiStrip extends StatelessWidget {
  const MonthlyKpiStrip({super.key, required this.stats, required this.month});
  final MonthlyStats stats;
  final MonthKey month;

  List<_Kpi> _kpis(CrmTheme crm) {
    final prev = kMonthNames[prevMonthOf(month).month - 1].substring(0, 3);
    final change = stats.change;
    String? chip;
    Color? chipColor;
    if (change != null) {
      chip = change > 0 ? '+$change vs $prev (${stats.previousCount})' : (change < 0 ? '$change vs $prev (${stats.previousCount})' : 'same as $prev (${stats.previousCount})');
      chipColor = change > 0 ? const Color(0xFF22A06B) : (change < 0 ? const Color(0xFFDC4C4C) : const Color(0xFF7A7A7A));
    }
    String share(int n) => '${stats.percentOf(n)}% of total';
    return [
      _Kpi(keyName: 'total', label: 'Total Objectives', value: '${stats.total}', icon: Icons.track_changes_rounded, color: crm.primary, chip: chip, chipColor: chipColor),
      _Kpi(
        keyName: 'completed',
        label: 'Completed',
        value: '${stats.completed}',
        icon: Icons.check_rounded,
        color: statusColor(ObjectiveStatus.completed),
        caption: share(stats.completed),
        captionColor: statusColor(ObjectiveStatus.completed),
      ),
      _Kpi(
        keyName: 'progress',
        label: 'In Progress',
        value: '${stats.inProgress}',
        icon: Icons.play_arrow_rounded,
        color: statusColor(ObjectiveStatus.inProgress),
        caption: share(stats.inProgress),
        captionColor: statusColor(ObjectiveStatus.inProgress),
      ),
      _Kpi(
        keyName: 'notstarted',
        label: 'Not Started',
        value: '${stats.notStarted}',
        icon: Icons.schedule_rounded,
        color: const Color(0xFFF5A524),
        caption: share(stats.notStarted),
        captionColor: const Color(0xFFB7791F),
      ),
      _Kpi(
        keyName: 'overall',
        label: 'Overall Progress',
        value: '${stats.avgProgress}%',
        icon: Icons.donut_large_rounded,
        color: crm.primary,
        caption: '${stats.completed} of ${stats.total} completed',
        ring: stats.avgProgress,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final kpis = _kpis(crm);
    return Column(
      key: const Key('mo_summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 1000 ? 5 : (c.maxWidth >= 600 ? 3 : 2);
            final compact = c.maxWidth / cols < 190;
            const gap = 12.0;
            final rows = <List<_Kpi>>[for (var i = 0; i < kpis.length; i += cols) kpis.sublist(i, math.min(i + cols, kpis.length))];
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
                          Expanded(child: _KpiTile(rows[r][i], compact: compact)),
                        ],
                        // a short last row keeps its tiles the same width as the rows above
                        for (var i = rows[r].length; i < cols && rows.length > 1; i++) ...[const SizedBox(width: gap), const Expanded(child: SizedBox.shrink())],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        if (stats.other > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Also this month: ${[if (stats.endedShort > 0) '${stats.endedShort} ended short', if (stats.dropped > 0) '${stats.dropped} cancelled or postponed'].join(' · ')}',
              key: const Key('mo_kpi_other'),
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile(this.k, {required this.compact});
  final _Kpi k;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final tile = compact ? 38.0 : 48.0;
    return Container(
      key: Key('mo_kpi_${k.keyName}'),
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
          if (k.ring != null)
            SizedBox(
              width: tile + 6,
              height: tile + 6,
              child: CustomPaint(
                painter: _RingPainter(value: k.ring!, color: k.color, track: crm.border),
                child: Center(
                  child: Text(
                    '${k.ring}%',
                    key: const Key('mo_kpi_overall_value'),
                    style: TextStyle(fontSize: compact ? 10.5 : 12, fontWeight: FontWeight.w800, color: crm.textPrimary),
                  ),
                ),
              ),
            )
          else
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
                  k.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: compact ? 11.5 : 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
                ),
                if (k.ring == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      k.value,
                      key: Key('mo_kpi_${k.keyName}_value'),
                      style: TextStyle(fontSize: compact ? 24 : 30, height: 1.1, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.8),
                    ),
                  ),
                if (k.chip != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      k.chip!,
                      key: Key('mo_kpi_${k.keyName}_chip'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: k.chipColor ?? k.color),
                    ),
                  ),
                if (k.caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      k.caption!,
                      key: Key('mo_kpi_${k.keyName}_caption'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: k.captionColor ?? crm.textSecondary),
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

/// A ring: [value] percent of it in [color] over a [track] — drawn by hand (no chart, so it can sit in an IntrinsicHeight).
class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.track});
  final int value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, base..color = track);
    if (value > 0) canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * value.clamp(0, 100) / 100, false, base..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}

// ── a department ─────────────────────────────────────────────────────────────

class MonthlyDepartmentCard extends StatelessWidget {
  const MonthlyDepartmentCard({super.key, required this.department, required this.index, required this.month, required this.selected, required this.onTap});
  final MonthlyDepartment department;

  /// Its place in the list — what colour it gets.
  final int index;
  final MonthKey month;

  /// The page is narrowed to this department.
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final d = department;
    final color = deptColor(index);
    final stats = MonthlyStats.of(d.objectives);
    final last = d.lastMonth;
    final unclosed = last.open > 0;
    final lastText = last.count > 0
        ? 'Last month: ${last.achieved} achieved · ${last.partly} partly · ${last.missed} missed'
              '${last.continued > 0 ? ' · ${last.continued} continuing' : ''}${last.deferred > 0 ? ' · ${last.deferred} postponed' : ''}'
              '${last.cancelled > 0 ? ' · ${last.cancelled} cancelled' : ''}${last.open > 0 ? ' · ${last.open} not closed' : ''}'
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('mo_dept_open_${d.departmentId}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          key: Key('mo_dept_${d.departmentId}'),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? crm.primary : color.withValues(alpha: 0.28), width: selected ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                    child: Icon(departmentIcon(d.name), size: 22, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(d.name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                            if (d.isMine) DashPill('Your department', crm.primary, key: Key('mo_mine_${d.departmentId}')),
                          ],
                        ),
                        Text(
                          d.headName == null || d.headName!.isEmpty ? 'No head set' : 'Head: ${d.headName}',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: selected ? crm.primary : crm.textSecondary),
                ],
              ),
              const SizedBox(height: 10),
              if (d.isEmpty)
                Text(
                  'No objectives set for ${kMonthNames[month.month - 1]}',
                  key: Key('mo_empty_${d.departmentId}'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${stats.total} objective${stats.total == 1 ? '' : 's'}${stats.completed > 0 ? ' · ${stats.completed} done' : ''}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary),
                      ),
                    ),
                    Text(
                      '${stats.avgProgress}%',
                      key: Key('mo_dept_progress_${d.departmentId}'),
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                progressBar(crm, stats.avgProgress, color: color),
              ],
              if (lastText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    lastText,
                    key: Key('mo_dept_last_${d.departmentId}'),
                    style: TextStyle(fontSize: 11.5, color: unclosed ? const Color(0xFFB7791F) : crm.textSecondary, fontWeight: unclosed ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── the trend ────────────────────────────────────────────────────────────────

class MonthlyTrendCard extends ConsumerWidget {
  const MonthlyTrendCard({super.key, required this.month, this.departmentId, this.departmentName});
  final MonthKey month;

  /// Narrowed to one department (null: the whole company).
  final String? departmentId;
  final String? departmentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monthlyTrendProvider(month));
    return DashCard(
      title: 'Monthly Progress Trend',
      subtitle: departmentName ?? 'All departments · average progress',
      icon: Icons.show_chart_rounded,
      child: async.when(
        loading: () => const DashStatus.loading(height: 190),
        error: (_, _) => DashStatus.failed(height: 190, onRetry: () => ref.invalidate(monthlyTrendProvider(month))),
        data: (t) => _TrendChart(trend: t, departmentId: departmentId),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.trend, required this.departmentId});
  final MonthlyTrend trend;
  final String? departmentId;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final months = trend.months;
    if (trend.measured(departmentId) < 2) {
      return const DashEmpty('Not enough history yet — a line appears once two months have objectives.', icon: Icons.show_chart_rounded, height: 190);
    }
    final spots = <FlSpot>[
      for (var i = 0; i < months.length; i++)
        (months[i].of(departmentId)?.hasData ?? false) ? FlSpot(i.toDouble(), months[i].of(departmentId)!.avgProgress.clamp(0, 100).toDouble()) : FlSpot.nullSpot,
    ];
    final lastIndex = spots.lastIndexWhere((s) => s != FlSpot.nullSpot);
    final bar = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.22,
      preventCurveOverShooting: true,
      color: crm.primary,
      barWidth: 2.4,
      dotData: FlDotData(show: true, getDotPainter: (spot, _, _, _) => FlDotCirclePainter(radius: 3, color: crm.primary, strokeWidth: 1.6, strokeColor: crm.surface)),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [crm.primary.withValues(alpha: 0.16), crm.primary.withValues(alpha: 0)]),
      ),
    );
    return SizedBox(
      key: const Key('mo_trend_chart'),
      height: 190,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 6),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (months.length - 1).toDouble(),
            minY: 0,
            maxY: 100,
            clipData: const FlClipData.none(),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (_) => FlLine(color: crm.border, strokeWidth: 1, dashArray: const [3, 4])),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 20,
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
                    if (v != i.toDouble() || i < 0 || i >= months.length) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.only(top: 7), child: Text(months[i].shortName, style: TextStyle(fontSize: 10, color: crm.textSecondary)));
                  },
                ),
              ),
            ),
            lineBarsData: [bar],
            lineTouchData: LineTouchData(
              enabled: false, // the standing label is on the latest month only
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => crm.primary,
                tooltipBorderRadius: BorderRadius.circular(8),
                getTooltipItems: (touched) => [for (final s in touched) LineTooltipItem('${s.y.round()}%', const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11))],
              ),
            ),
            showingTooltipIndicators: [
              ShowingTooltipIndicators([LineBarSpot(bar, 0, spots[lastIndex])]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── target against achievement ───────────────────────────────────────────────

class MonthlyTargetCard extends StatelessWidget {
  const MonthlyTargetCard({super.key, required this.stats, required this.month});
  final MonthlyStats stats;
  final MonthKey month;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final label = '${kMonthNames[month.month - 1].substring(0, 3)} ${month.year}';

    Widget row(String key, String name, int n, Color color, {bool planned = false}) {
      final fraction = stats.total == 0 ? 0.0 : (n / stats.total).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          children: [
            SizedBox(width: 118, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: planned ? 1 : fraction, minHeight: 9, backgroundColor: crm.border.faded(1.6), valueColor: AlwaysStoppedAnimation(color)),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 66,
              child: Text(
                planned ? '$n' : '$n (${stats.percentOf(n)}%)',
                key: Key('mo_target_${key}_value'),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    return DashCard(
      key: const Key('mo_target_card'),
      title: 'Target vs Achievement',
      subtitle: label,
      icon: Icons.emoji_events_outlined,
      iconColor: const Color(0xFFD99A1C),
      child: stats.total == 0
          ? DashEmpty('Nothing is planned for ${kMonthNames[month.month - 1]} yet.', icon: Icons.flag_outlined, height: 150)
          : Column(
              children: [
                row('planned', 'Planned Objectives', stats.total, crm.primary.withValues(alpha: 0.45), planned: true),
                row('completed', 'Completed', stats.completed, statusColor(ObjectiveStatus.completed)),
                row('progress', 'In Progress', stats.inProgress, statusColor(ObjectiveStatus.inProgress)),
                row('notstarted', 'Not Started', stats.notStarted, statusColor(ObjectiveStatus.notStarted)),
                if (stats.other > 0) row('other', 'Ended short / dropped', stats.other, statusColor(ObjectiveStatus.partly)),
              ],
            ),
    );
  }
}

// ── what stands out ──────────────────────────────────────────────────────────

class MonthlyTakeawaysCard extends StatelessWidget {
  const MonthlyTakeawaysCard({super.key, required this.takeaways});
  final List<Takeaway> takeaways;

  static (IconData, Color) _look(TakeawayTone t) => switch (t) {
    TakeawayTone.good => (Icons.check_circle_rounded, const Color(0xFF22A06B)),
    TakeawayTone.info => (Icons.timelapse_rounded, const Color(0xFF3B82F6)),
    TakeawayTone.neutral => (Icons.radio_button_unchecked_rounded, const Color(0xFF9AA0A6)),
    TakeawayTone.warn => (Icons.error_outline_rounded, const Color(0xFFF5A524)),
    TakeawayTone.bad => (Icons.event_busy_rounded, const Color(0xFFDC4C4C)),
  };

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return DashCard(
      key: const Key('mo_takeaways_card'),
      title: 'Key Takeaways',
      icon: Icons.lightbulb_outline_rounded,
      iconColor: const Color(0xFFF5A524),
      child: takeaways.isEmpty
          ? const DashEmpty('Nothing to point out yet.', icon: Icons.lightbulb_outline_rounded, height: 150)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < takeaways.length; i++)
                  Padding(
                    key: Key('mo_takeaway_$i'),
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_look(takeaways[i].tone).$1, size: 18, color: _look(takeaways[i].tone).$2),
                        const SizedBox(width: 10),
                        Expanded(child: Text(takeaways[i].text, style: TextStyle(fontSize: 12.5, height: 1.3, color: crm.textPrimary))),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── the progress matrix ──────────────────────────────────────────────────────

Color heatColor(Heat h) => switch (h) {
  Heat.none => const Color(0xFF9AA0A6),
  Heat.low => const Color(0xFFDC4C4C),
  Heat.mid => const Color(0xFFF5A524),
  Heat.high => const Color(0xFF3B82F6),
  Heat.full => const Color(0xFF22A06B),
};

class MonthlyProgressMatrix extends ConsumerWidget {
  const MonthlyProgressMatrix({super.key, required this.month, this.departmentId});
  final MonthKey month;
  final String? departmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monthlyTrendProvider(month));
    return DashCard(
      key: const Key('mo_matrix_card'),
      title: 'Progress Matrix',
      subtitle: 'Average progress of each department, month by month',
      icon: Icons.grid_view_rounded,
      child: async.when(
        loading: () => const DashStatus.loading(height: 190),
        error: (_, _) => DashStatus.failed(height: 190, onRetry: () => ref.invalidate(monthlyTrendProvider(month))),
        data: (t) => _Matrix(trend: t, departmentId: departmentId),
      ),
    );
  }
}

class _Matrix extends StatelessWidget {
  const _Matrix({required this.trend, required this.departmentId});
  final MonthlyTrend trend;
  final String? departmentId;

  static const _labelWidth = 130.0;
  static const _minCell = 58.0;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final rows = [
      for (final d in trend.departments)
        if (departmentId == null || d.departmentId == departmentId) d,
    ];
    if (!trend.hasAny || rows.isEmpty) {
      return const DashEmpty('No objectives were set in these months yet.', icon: Icons.grid_view_rounded, height: 150);
    }

    Widget legend(Heat h, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: heatColor(h).withValues(alpha: h == Heat.none ? 0.2 : 0.35), borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            // wide enough: the month columns share the card; otherwise they keep a minimum width and the grid scrolls sideways
            final stretch = (c.maxWidth - _labelWidth) / trend.months.length >= _minCell;
            Widget head(String text) => Center(child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary)));
            Widget line({required Widget label, required List<Widget> cells}) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: _labelWidth, child: label),
                  for (final cell in cells) stretch ? Expanded(child: cell) : SizedBox(width: _minCell, child: cell),
                ],
              ),
            );
            Widget name(String text, {bool bold = false}) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: crm.textPrimary));

            final grid = Column(
              key: const Key('mo_matrix'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(label: const SizedBox.shrink(), cells: [for (final m in trend.months) head(m.shortName)]),
                for (final d in rows)
                  line(
                    label: name(d.name),
                    cells: [for (var i = 0; i < trend.months.length; i++) _cell(crm, trend.months[i], d.name, trend.months[i].of(d.departmentId), 'mo_cell_${d.departmentId}_$i')],
                  ),
                // the whole company, when more than one department is on show
                if (rows.length > 1) ...[
                  Divider(height: 10, color: crm.border),
                  line(
                    label: name('Whole company', bold: true),
                    cells: [for (var i = 0; i < trend.months.length; i++) _cell(crm, trend.months[i], 'Whole company', trend.months[i].of(null), 'mo_cell_all_$i')],
                  ),
                ],
              ],
            );
            return stretch
                ? grid
                : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: _labelWidth + _minCell * trend.months.length, child: grid));
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [legend(Heat.none, 'No objectives'), legend(Heat.low, 'Under 40%'), legend(Heat.mid, '40–69%'), legend(Heat.high, '70–99%'), legend(Heat.full, '100%')],
        ),
      ],
    );
  }

  Widget _cell(CrmTheme crm, TrendMonth m, String who, ({int count, int avgProgress, bool hasData})? at, String keyName) {
    final has = at?.hasData ?? false;
    final color = heatColor(heatOf(has ? at!.avgProgress : null));
    return Tooltip(
      message: has ? '$who · ${m.shortName} ${m.year}: ${at!.count} objective${at.count == 1 ? '' : 's'}, ${at.avgProgress}%' : '$who · ${m.shortName} ${m.year}: no objectives',
      child: Container(
        key: Key(keyName),
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: has ? 0.2 : 0.12), borderRadius: BorderRadius.circular(9)),
        child: Text(has ? '${at!.avgProgress}%' : '—', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: has ? color : crm.textSecondary)),
      ),
    );
  }
}
