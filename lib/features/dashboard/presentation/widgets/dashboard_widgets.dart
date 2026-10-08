import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';

// Building blocks for the dashboard's analytics tabs (Sales, Marketing,
// Finance): cards, KPI tiles, and the charts.
//
// Colour roles (validated with the dataviz palette checker on white):
//  • kBrand      — the single/primary series (a chart-weight brand maroon;
//                  the UI maroon #601A29 is too dark to read as a series).
//  • kPrev       — the comparison period: grey AND dashed, never colour alone.
//  • kSeries     — categorical slots in FIXED order; >6 categories fold into
//                  "Other" (kOther). Passes CVD/normal-vision adjacent checks.
//  • kIncome / kExpense — blue vs orange (slots 1–2), not green vs red.
// Values and labels always use text colours, never the series colour.

const kBrand = Color(0xFFA3364D);
const kPrev = Color(0xFF8E96A3);
const kOther = Color(0xFFA8ADB5);
const kSeries = [
  Color(0xFF2A78D6), // blue
  Color(0xFFEB6834), // orange
  Color(0xFF1BAF7A), // aqua
  Color(0xFFEDA100), // yellow
  Color(0xFFE87BA4), // magenta
  Color(0xFF008300), // green
];
const kIncome = Color(0xFF2A78D6);
const kExpense = Color(0xFFEB6834);

const kDashText = Color(0xFF1F2937);
const kDashMuted = Color(0xFF6B7280);
const kDashBorder = Color(0xFFE8E5E1);
const kDashGrid = Color(0xFFF1EFEC);
const kDashGood = Color(0xFF0B7A4B);
const kDashBad = Color(0xFFB42318);

final _inr = NumberFormat.decimalPattern('en_IN');

/// ₹12,34,567 (Indian grouping, no decimals).
String inr(num v) => '${v < 0 ? '-' : ''}₹${_inr.format(v.abs().round())}';

/// ₹12.3L / ₹1.2Cr / ₹45.6K for tight spaces.
String inrShort(num v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 10000000) return '$sign₹${(a / 10000000).toStringAsFixed(2)}Cr';
  if (a >= 100000) return '$sign₹${(a / 100000).toStringAsFixed(1)}L';
  if (a >= 1000) return '$sign₹${(a / 1000).toStringAsFixed(1)}K';
  return '$sign₹${a.round()}';
}

String countLabel(num v) => _inr.format(v.round());
String pct(num v) => '${v.toStringAsFixed(1)}%';

/// Period-over-period change in %, or null when there is nothing to compare.
double? deltaPct(num now, num prev) {
  if (prev == 0) return now == 0 ? 0 : null;
  return (now - prev) / prev.abs() * 100;
}

/// Short axis label for a trend bucket key (YYYY-MM-DD or YYYY-MM).
String bucketLabel(String key, String unit) {
  final d = DateTime.tryParse(key.length == 7 ? '$key-01' : key);
  if (d == null) return key;
  if (unit == 'month' || key.length == 7) return DateFormat('MMM yy').format(d);
  return DateFormat('d MMM').format(d);
}

TextStyle dashText(double size, {FontWeight weight = FontWeight.w500, Color color = kDashText}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

/// "Nice" axis maximum and step so gridlines land on round numbers.
(double, double) _niceAxis(double maxV, {int ticks = 4}) {
  if (maxV <= 0) return (1, 0.25);
  final raw = maxV / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final n = raw / mag;
  final step = (n <= 1 ? 1 : n <= 2 ? 2 : n <= 2.5 ? 2.5 : n <= 5 ? 5 : 10) * mag;
  return ((maxV / step).ceil() * step, step);
}

/// White rounded card with a title row.
class DashCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const DashCard({super.key, required this.title, required this.child, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDashBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: dashText(15, weight: FontWeight.w700)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: dashText(12, color: kDashMuted)),
                  ),
              ]),
            ),
            ?trailing,
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// KPI tile: label, big value, change vs the comparison window, optional
/// sparkline of the period.
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double? delta;
  final String? deltaLabel;

  /// For costs a rise is bad — flips the badge colour.
  final bool lowerIsBetter;
  final String? hint;
  final List<double>? spark;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.delta,
    this.deltaLabel,
    this.lowerIsBetter = false,
    this.hint,
    this.spark,
  });

  @override
  Widget build(BuildContext context) {
    final d = delta;
    final good = d == null ? true : (lowerIsBetter ? d <= 0 : d >= 0);
    final badge = good ? kDashGood : kDashBad;
    final s = spark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDashBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: kBrand.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: kBrand),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: dashText(12, color: kDashMuted, weight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: dashText(22, weight: FontWeight.w800)),
              ),
            ),
            // The sparkline only where the tile has room for it.
            if (s != null && s.length > 1 && s.any((v) => v != 0) && MediaQuery.sizeOf(context).width >= 600) ...[
              const SizedBox(width: 8),
              SizedBox(width: 64, height: 26, child: _Sparkline(s)),
            ],
          ]),
          const SizedBox(height: 6),
          if (d != null)
            Row(children: [
              Icon(d >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: badge),
              const SizedBox(width: 2),
              Text('${d.abs().toStringAsFixed(1)}%', style: dashText(11.5, color: badge, weight: FontWeight.w700)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(deltaLabel ?? 'vs previous',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: dashText(11, color: kDashMuted)),
              ),
            ])
          else
            Text(hint ?? ' ', maxLines: 1, overflow: TextOverflow.ellipsis, style: dashText(11, color: kDashMuted)),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  const _Sparkline(this.values);

  @override
  Widget build(BuildContext context) {
    final maxV = values.reduce(math.max);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxV <= 0 ? 1 : maxV * 1.1,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
            isCurved: true,
            preventCurveOverShooting: true,
            color: kBrand,
            barWidth: 1.6,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kBrand.withValues(alpha: 0.18), kBrand.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive grid of equal-width tiles.
class TileGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  const TileGrid({super.key, required this.children, this.minTileWidth = 158, this.maxColumns = 4});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final cols = math.max(1, math.min(maxColumns, ((c.maxWidth + gap) / (minTileWidth + gap)).floor()));
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });
  }
}

/// Cards side by side on wide screens, stacked on narrow ones. [flex] sets
/// relative widths on wide screens.
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double breakpoint;

  /// Wide layout: every card is at least this tall, so a row lines up.
  final double? minHeight;
  const ResponsiveRow({super.key, required this.children, this.flex, this.breakpoint = 900, this.minHeight});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
        ]);
      }
      // Top-aligned rather than IntrinsicHeight: charts use LayoutBuilder,
      // which can't report intrinsic sizes.
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(
            flex: flex?[i] ?? 1,
            child: minHeight == null
                ? children[i]
                : ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight!), child: children[i]),
          ),
        ],
      ]);
    });
  }
}

class EmptyNote extends StatelessWidget {
  final String text;
  final double height;
  const EmptyNote(this.text, {super.key, this.height = 140});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Center(child: Text(text, textAlign: TextAlign.center, style: dashText(13, color: kDashMuted))),
      );
}

/// Legend swatch + label; [dashed] for the comparison series.
class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const LegendDot(this.color, this.label, {super.key, this.dashed = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (dashed)
          SizedBox(
            width: 16,
            height: 10,
            child: Row(children: [
              for (var i = 0; i < 3; i++) ...[
                Container(width: 4, height: 2, color: color),
                if (i < 2) const SizedBox(width: 2),
              ],
            ]),
          )
        else
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: dashText(12, color: kDashMuted)),
      ]);
}

/// Thins x-axis labels so they never collide.
int _labelStep(int count, double width) => math.max(1, (count / math.max(2, width / 54)).ceil());

/// Line chart for a trend: the period as a solid brand line with a soft fill,
/// the comparison window as a dashed grey line. Crosshair + tooltip on hover.
class TrendLineChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final List<double>? previous;
  final String seriesLabel;
  final String previousLabel;
  final String Function(double) format;
  final double height;

  const TrendLineChart({
    super.key,
    required this.labels,
    required this.values,
    this.previous,
    this.seriesLabel = 'This period',
    this.previousLabel = 'Previous',
    this.format = inrShort,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || (values.every((v) => v == 0) && (previous ?? const []).every((v) => v == 0))) {
      return EmptyNote('No data for this period', height: height);
    }
    final all = [...values, ...?previous];
    // Values can go negative (e.g. net cash flow): extend the axis below zero.
    final hi = all.reduce(math.max);
    final lo = math.min(0.0, all.reduce(math.min));
    final (_, step) = _niceAxis(hi - lo);
    final top = hi <= 0 ? step : (hi / step).ceil() * step;
    final bottom = lo < 0 ? -((-lo / step).ceil() * step) : 0.0;
    final prev = previous;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (prev != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(spacing: 16, children: [
            LegendDot(kBrand, seriesLabel),
            LegendDot(kPrev, previousLabel, dashed: true),
          ]),
        ),
      SizedBox(
        height: height,
        child: LayoutBuilder(builder: (context, c) {
          final every = _labelStep(labels.length, c.maxWidth - 56);
          return LineChart(
            LineChartData(
              minY: bottom,
              maxY: top,
              minX: 0,
              extraLinesData: bottom < 0
                  ? ExtraLinesData(horizontalLines: [HorizontalLine(y: 0, color: const Color(0xFFB9B2AB), strokeWidth: 1)])
                  : const ExtraLinesData(),
              maxX: math.max(1, labels.length - 1).toDouble(),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) => const FlLine(color: kDashGrid, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    interval: step,
                    getTitlesWidget: (v, meta) => v > top + 0.001 || v < bottom - 0.001
                        ? const SizedBox.shrink()
                        : Text(format(v), style: dashText(10.5, color: kDashMuted)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if ((v - i).abs() > 0.01 || i < 0 || i >= labels.length || i % every != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(labels[i], style: dashText(10.5, color: kDashMuted)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (bar, idx) => idx
                    .map((_) => TouchedSpotIndicatorData(
                          const FlLine(color: Color(0xFFCBC6C0), strokeWidth: 1, dashArray: [3, 3]),
                          FlDotData(
                            getDotPainter: (spot, _, b, _) => FlDotCirclePainter(
                              radius: 4.5,
                              color: b.color ?? kBrand,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                        ))
                    .toList(),
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => kDashText,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        s.barIndex == 0
                            ? '${labels[s.x.round()]}\n$seriesLabel  ${format(s.y)}'
                            : '$previousLabel  ${format(s.y)}',
                        dashText(11.5, color: Colors.white, weight: s.barIndex == 0 ? FontWeight.w700 : FontWeight.w500),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
                  isCurved: true,
                  preventCurveOverShooting: true,
                  curveSmoothness: 0.25,
                  color: kBrand,
                  barWidth: 2.4,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: values.length <= 14),
                  belowBarData: BarAreaData(
                    show: true,
                    cutOffY: 0,
                    applyCutOffY: bottom < 0,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [kBrand.withValues(alpha: 0.16), kBrand.withValues(alpha: 0)],
                    ),
                  ),
                ),
                if (prev != null)
                  LineChartBarData(
                    spots: [for (var i = 0; i < prev.length && i < values.length; i++) FlSpot(i.toDouble(), prev[i])],
                    isCurved: true,
                    preventCurveOverShooting: true,
                    curveSmoothness: 0.25,
                    color: kPrev,
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          );
        }),
      ),
    ]);
  }
}

/// One series of a [GroupedBarChart].
class BarSeries {
  final String name;
  final Color color;
  final List<double> values;
  const BarSeries(this.name, this.color, this.values);
}

/// Vertical bar chart — one series, or a few side by side. Labels should be
/// short (months, days, packages); use [BarList] for long names.
class GroupedBarChart extends StatelessWidget {
  final List<String> labels;
  final List<BarSeries> series;
  final String Function(double) format;
  final double height;

  const GroupedBarChart({
    super.key,
    required this.labels,
    required this.series,
    this.format = inrShort,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    final all = [for (final s in series) ...s.values];
    if (labels.isEmpty || all.every((v) => v == 0)) return EmptyNote('No data for this period', height: height);
    final (top, step) = _niceAxis(all.reduce(math.max));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (series.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(spacing: 16, children: [for (final s in series) LegendDot(s.color, s.name)]),
        ),
      SizedBox(
        height: height,
        child: LayoutBuilder(builder: (context, c) {
          final every = _labelStep(labels.length, c.maxWidth - 56);
          final slot = (c.maxWidth - 56) / labels.length;
          final barW = ((slot * 0.62) / series.length).clamp(4.0, 22.0);
          return BarChart(
            BarChartData(
              maxY: top,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) => const FlLine(color: kDashGrid, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => kDashText,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                    '${labels[group.x]}\n${series.length > 1 ? '${series[rodIndex].name}  ' : ''}${format(rod.toY)}',
                    dashText(11.5, color: Colors.white, weight: FontWeight.w600),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    interval: step,
                    getTitlesWidget: (v, _) => v > top + 0.001
                        ? const SizedBox.shrink()
                        : Text(format(v), style: dashText(10.5, color: kDashMuted)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length || i % every != 0) return const SizedBox.shrink();
                      final t = labels[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(t.length > 11 ? '${t.substring(0, 10)}…' : t, style: dashText(10.5, color: kDashMuted)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < labels.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      for (final s in series)
                        BarChartRodData(
                          toY: i < s.values.length ? s.values[i] : 0,
                          color: s.color,
                          width: barW,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                    ],
                  ),
              ],
            ),
          );
        }),
      ),
    ]);
  }
}

/// One row of a ranked horizontal bar breakdown.
class BarItem {
  final String label;
  final double value;
  final String valueLabel;
  final String? sub;
  const BarItem(this.label, this.value, this.valueLabel, {this.sub});
}

/// Ranked horizontal bars — for named categories (salespeople, districts,
/// campaigns) whose labels are too long for a vertical axis.
class BarList extends StatelessWidget {
  final List<BarItem> items;
  final Color color;
  final int maxItems;
  final String emptyText;

  const BarList({
    super.key,
    required this.items,
    this.color = kBrand,
    this.maxItems = 8,
    this.emptyText = 'No data for this period',
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return EmptyNote(emptyText);
    final shown = items.take(maxItems).toList();
    final maxV = shown.map((e) => e.value).fold<double>(0, math.max);
    return Column(children: [
      for (final it in shown)
        Tooltip(
          message: '${it.label}: ${it.valueLabel}${it.sub == null ? '' : ' · ${it.sub}'}',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: dashText(13, weight: FontWeight.w600)),
                ),
                if (it.sub != null) ...[
                  Flexible(
                    child: Text(it.sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: dashText(11.5, color: kDashMuted)),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(it.valueLabel, style: dashText(13, weight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              LayoutBuilder(builder: (context, c) {
                final f = maxV > 0 ? (it.value / maxV).clamp(0.0, 1.0) : 0.0;
                return Stack(children: [
                  Container(height: 8, decoration: BoxDecoration(color: kDashGrid, borderRadius: BorderRadius.circular(4))),
                  Container(
                    height: 8,
                    width: math.max(f > 0 ? 4 : 0, c.maxWidth * f),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                ]);
              }),
            ]),
          ),
        ),
      if (items.length > maxItems)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('+ ${items.length - maxItems} more', style: dashText(11.5, color: kDashMuted)),
          ),
        ),
    ]);
  }
}

/// A slice of a [DonutChart].
class Slice {
  final String label;
  final double value;
  const Slice(this.label, this.value);
}

/// Part-of-whole donut with a legend (value + share). The centre shows the
/// total, or the hovered slice. Colours follow the ORDER GIVEN (pass a fixed
/// order for fixed categories so an entity keeps its colour across periods);
/// beyond six, the smallest slices fold into "Other".
class DonutChart extends StatefulWidget {
  final List<Slice> slices;
  final String Function(double) format;
  final String centerLabel;
  final double size;

  const DonutChart({
    super.key,
    required this.slices,
    this.format = inrShort,
    this.centerLabel = 'Total',
    this.size = 176,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int? _touched;

  List<(Slice, Color)> get _folded {
    final s = widget.slices.where((e) => e.value > 0).toList();
    if (s.length <= kSeries.length) return [for (var i = 0; i < s.length; i++) (s[i], kSeries[i])];
    // Keep the largest five (in their given order); fold the rest.
    final keep = ([...s]..sort((a, b) => b.value.compareTo(a.value))).take(kSeries.length - 1).toSet();
    final head = s.where(keep.contains).toList();
    final rest = s.where((e) => !keep.contains(e)).fold<double>(0, (t, e) => t + e.value);
    return [
      for (var i = 0; i < head.length; i++) (head[i], kSeries[i]),
      (Slice('Other', rest), kOther),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final parts = _folded;
    if (parts.isEmpty) return EmptyNote('No data for this period', height: widget.size);
    final total = parts.fold<double>(0, (t, p) => t + p.$1.value);
    final t = _touched;
    final focus = t != null && t < parts.length ? parts[t].$1 : null;

    final donut = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(alignment: Alignment.center, children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: widget.size * 0.32,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(
              touchCallback: (event, resp) => setState(() {
                _touched = event.isInterestedForInteractions ? resp?.touchedSection?.touchedSectionIndex : null;
                if (_touched != null && _touched! < 0) _touched = null;
              }),
            ),
            sections: [
              for (var i = 0; i < parts.length; i++)
                PieChartSectionData(
                  value: parts[i].$1.value,
                  color: parts[i].$2,
                  radius: widget.size * (i == t ? 0.18 : 0.15),
                  showTitle: false,
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(widget.size * 0.2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(focus?.label ?? widget.centerLabel,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: dashText(11, color: kDashMuted, weight: FontWeight.w600)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(widget.format(focus?.value ?? total), style: dashText(17, weight: FontWeight.w800)),
            ),
            if (focus != null)
              Text('${(focus.value / total * 100).toStringAsFixed(0)}%', style: dashText(11, color: kDashMuted)),
          ]),
        ),
      ]),
    );

    final legend = Column(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < parts.length; i++)
        MouseRegion(
          onEnter: (_) => setState(() => _touched = i),
          onExit: (_) => setState(() => _touched = null),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(
                  width: 10, height: 10, decoration: BoxDecoration(color: parts[i].$2, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(parts[i].$1.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dashText(12.5, weight: i == t ? FontWeight.w700 : FontWeight.w500)),
              ),
              Text(widget.format(parts[i].$1.value), style: dashText(12.5, weight: FontWeight.w700)),
              SizedBox(
                width: 44,
                child: Text('${(parts[i].$1.value / total * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right, style: dashText(12, color: kDashMuted)),
              ),
            ]),
          ),
        ),
    ]);

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < widget.size + 220) {
        return Column(children: [Center(child: donut), const SizedBox(height: 14), legend]);
      }
      return Row(children: [donut, const SizedBox(width: 24), Expanded(child: legend)]);
    });
  }
}

/// Horizontally scrollable data table with a consistent look.
class DashTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final Set<int> numericColumns;

  const DashTable({super.key, required this.columns, required this.rows, this.numericColumns = const {}});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyNote('No rows for this period');
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: c.maxWidth),
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 38,
        dataRowMaxHeight: 46,
        columnSpacing: 28,
        horizontalMargin: 4,
        headingTextStyle: dashText(11.5, color: kDashMuted, weight: FontWeight.w700),
        dataTextStyle: dashText(13),
        dividerThickness: 0.6,
        columns: [
          for (var i = 0; i < columns.length; i++) DataColumn(label: Text(columns[i]), numeric: numericColumns.contains(i)),
        ],
        rows: [for (final r in rows) DataRow(cells: [for (final cell in r) DataCell(cell)])],
      ),
      ),
      ),
    );
  }
}

/// Loading / error / data body for a tab. Keeps showing the last data while
/// a new period loads, so the layout doesn't jump.
Widget dashAsync<T>(AsyncValue<T> async, List<Widget> Function(T data) builder, VoidCallback onRetry) {
  final d = async.value;
  if (d != null) {
    return Opacity(
      opacity: async.isLoading ? 0.55 : 1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: builder(d)),
    );
  }
  if (async.hasError) return AppErrorView(error: async.error, onRetry: onRetry);
  return const Padding(padding: EdgeInsets.all(80), child: Center(child: CircularProgressIndicator(color: kBrand)));
}

/// Section heading between groups of cards.
class DashSection extends StatelessWidget {
  final String title;
  const DashSection(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(title.toUpperCase(), style: dashText(11.5, color: kDashMuted, weight: FontWeight.w800).copyWith(letterSpacing: 0.8)),
      );
}
