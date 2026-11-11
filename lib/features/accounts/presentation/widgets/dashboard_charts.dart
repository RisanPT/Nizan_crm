import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/data/dashboard_series.dart';

/// A tiny trend line with a soft fill, for a KPI card's corner. No axes, no touch.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  const Sparkline({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final pad = (hi - lo).abs() < 0.0001 ? 1.0 : (hi - lo) * 0.12;
    return IgnorePointer(
      child: LineChart(
        LineChartData(
          minY: lo - pad,
          maxY: hi + pad,
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
              isCurved: true,
              preventCurveOverShooting: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 1.8,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Income and expense over the period: two smooth lines with a fill, a money (or entry-count) axis, dates along the
/// bottom, and a tooltip with both figures for the point you touch.
class TrendChart extends StatelessWidget {
  final List<ChartBucket> buckets;

  /// true: money; false: how many entries.
  final bool amount;
  final Color incomeColor;
  final Color expenseColor;

  const TrendChart({
    super.key,
    required this.buckets,
    required this.amount,
    required this.incomeColor,
    required this.expenseColor,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final n = buckets.length;
    if (n == 0) {
      return Center(child: Text('No data for this period.', style: TextStyle(color: crm.textSecondary)));
    }
    double inc(ChartBucket b) => amount ? b.income : b.incomeCount.toDouble();
    double exp(ChartBucket b) => amount ? b.expense : b.expenseCount.toDouble();
    final peak = buckets.fold<double>(0, (m, b) => math.max(m, math.max(inc(b), exp(b))));
    var scale = niceScale(peak);
    if (!amount) {
      // counts are whole numbers: whole steps
      final step = math.max(1.0, scale.step.ceilToDouble());
      scale = (max: (peak / step).floor() * step + step, step: step);
    }
    final dots = n <= 31;

    LineChartBarData line(double Function(ChartBucket) value, Color color) => LineChartBarData(
          spots: [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), value(buckets[i]))],
          isCurved: true,
          preventCurveOverShooting: true,
          curveSmoothness: 0.25,
          color: color,
          barWidth: 2.2,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: dots,
            getDotPainter: (spot, _, bar, _) => FlDotCirclePainter(radius: 3, color: Colors.white, strokeWidth: 1.8, strokeColor: color),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
            ),
          ),
        );

    return LayoutBuilder(builder: (context, box) {
    // about one date label per 70 px: a phone shows fewer than a desktop
    final every = math.max(1, (n / math.max(3, (box.maxWidth / 70).floor())).ceil());
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: scale.max,
        minX: 0,
        maxX: math.max(1, n - 1).toDouble(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: scale.step,
          getDrawingHorizontalLine: (_) => FlLine(color: crm.border.withValues(alpha: 0.7), strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: scale.step,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  amount ? axisMoney(v) : v.round().toString(),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if ((v - i).abs() > 0.01 || i < 0 || i >= n || i % every != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(buckets[i].label, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => crm.textPrimary,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            getTooltipItems: (spots) {
              if (spots.isEmpty) return const [];
              final b = buckets[spots.first.x.round().clamp(0, n - 1)];
              String show(double v, int c) => amount ? '${inrFull(v)}${c > 0 ? '  ·  $c' : ''}' : '$c ${c == 1 ? 'entry' : 'entries'}';
              final text = '${b.tooltip}\nIncome  ${show(b.income, b.incomeCount)}\nExpense  ${show(b.expense, b.expenseCount)}';
              // one tooltip for the point: the first line carries the text, the other is empty
              return [
                for (var k = 0; k < spots.length; k++)
                  LineTooltipItem(k == 0 ? text : '', const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.4)),
              ];
            },
          ),
        ),
        lineBarsData: [line(inc, incomeColor), line(exp, expenseColor)],
      ),
    );
    });
  }
}

/// Income against expense as a ring, with the income figure in the middle.
class IncomeExpenseDonut extends StatelessWidget {
  final double income;
  final double expense;
  final Color incomeColor;
  final Color expenseColor;

  const IncomeExpenseDonut({
    super.key,
    required this.income,
    required this.expense,
    required this.incomeColor,
    required this.expenseColor,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final total = income + expense;
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: total > 0 ? 3 : 0,
            centerSpaceRadius: 56,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(enabled: false),
            sections: total > 0
                ? [
                    PieChartSectionData(value: income, color: incomeColor, radius: 22, showTitle: false),
                    PieChartSectionData(value: expense, color: expenseColor.withValues(alpha: 0.45), radius: 22, showTitle: false),
                  ]
                : [PieChartSectionData(value: 1, color: crm.border, radius: 22, showTitle: false)],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(inrCompact(income), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            ),
            Text('Income', style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
