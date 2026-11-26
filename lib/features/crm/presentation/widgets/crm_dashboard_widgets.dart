import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';

// The CRM Dashboard's cards (crm_dashboard_screen.dart → Overview): white rounded cards on the warm ground, a tinted icon per figure,
// the change on the period before in green (better) or red (worse) — never a guess: a figure that was not recorded reads "—".

const kCrmIndigo = Color(0xFF6366F1);
const kCrmGreen = Color(0xFF16A34A);
const kCrmAmber = Color(0xFFF59E0B);
const kCrmSky = Color(0xFF0EA5E9);
const kCrmRose = Color(0xFFE11D48);
const kCrmPink = Color(0xFFF6E9EC);

/// A white card with a soft shadow.
class CrmDashCard extends StatelessWidget {
  const CrmDashCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.height});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? crm.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }
}

/// A card's title row: an icon, the title, and "View All →" when there is somewhere to go.
class CrmCardHeader extends StatelessWidget {
  const CrmCardHeader({super.key, required this.title, required this.icon, this.onViewAll, this.viewAllKey});
  final String title;
  final IconData icon;
  final VoidCallback? onViewAll;
  final Key? viewAllKey;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Row(children: [
      Icon(icon, size: 19, color: crm.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary))),
      if (onViewAll != null)
        InkWell(
          key: viewAllKey,
          borderRadius: BorderRadius.circular(8),
          onTap: onViewAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('View All', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.primary)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 15, color: crm.primary),
            ]),
          ),
        ),
    ]);
  }
}

/// The change on the period before as a percentage — "+12%" / "−5%" — or null when it cannot be said (nothing before, or no figure).
/// Shares and scores change in points ("+4 pts"), times in their own unit.
String? crmChangeLabel(CrmKpi k) {
  final v = k.value;
  final p = k.prev;
  if (v == null || p == null) return null;
  final d = v - p;
  if (d == 0) return '0%';
  final sign = d > 0 ? '+' : '−';
  switch (k.unit) {
    case 'pct':
    case 'score':
      return '$sign${_trim(d.abs())} pts';
    case 'rating':
      return '$sign${_trim(d.abs())}';
    default:
      if (p == 0) return null;
      return '$sign${(d.abs() / p * 100).round()}%';
  }
}

String _trim(num n) => n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);

/// One of the five figures across the top: a tinted icon, the label, the figure, and its change (green when better, red when worse).
class CrmStatCard extends StatelessWidget {
  const CrmStatCard({super.key, required this.kpiKey, required this.label, required this.icon, required this.kpi, this.highlight = false, this.onTap});
  final String kpiKey, label;
  final IconData icon;
  final CrmKpi kpi;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final change = crmChangeLabel(kpi);
    final better = kpi.improved;
    final tone = better == null ? crm.textSecondary : (better ? kCrmGreen : crm.destructive);
    final up = kpi.value != null && kpi.prev != null && kpi.value! > kpi.prev!;
    return InkWell(
      key: Key('crmStat_$kpiKey'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: CrmDashCard(
        color: highlight ? kCrmPink : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: LayoutBuilder(builder: (context, c) {
          // a narrow card (two a row on a phone): a smaller icon, and the label may take two lines rather than be cut
          final narrow = c.maxWidth < 190;
          final dot = narrow ? 40.0 : 52.0;
          return Row(children: [
          Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: highlight ? crm.surface : crm.primary.withValues(alpha: 0.07), shape: BoxShape.circle),
            child: Icon(icon, color: crm.primary, size: narrow ? 20 : 24),
          ),
          SizedBox(width: narrow ? 10 : 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, maxLines: narrow ? 2 : 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, height: 1.2, fontWeight: FontWeight.w600, color: crm.textPrimary)),
              const SizedBox(height: 2),
              Text(kpi.display, key: Key('crmKpiValue_$kpiKey'), maxLines: 1, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kpi.value == null ? crm.textSecondary : crm.textPrimary, height: 1.15)),
              const SizedBox(height: 2),
              if (change != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (change != '0%') Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: tone),
                  const SizedBox(width: 2),
                  Flexible(child: Text(change, key: Key('crmKpiChange_$kpiKey'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tone))),
                ])
              else
                Text('vs before: —', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ]),
          ),
        ]);
        }),
      ),
    );
  }
}

/// Open work right now, as a ring: requests to decide, chats to answer, open cases, trials to report — the total in the middle — and
/// what of it is overdue or has nobody yet.
class CrmOpenWorkCard extends StatelessWidget {
  const CrmOpenWorkCard({super.key, required this.now, this.unassigned, this.onViewAll, this.height});
  final CrmWorkload now;
  final CrmWorkload? unassigned;
  final VoidCallback? onViewAll;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final parts = [
      ('requests', 'Booking requests', now.requests, crm.primary),
      ('chats', 'Client chats', now.chats, const Color(0xFFC77B8B)),
      ('cases', 'Open cases', now.cases, const Color(0xFFE7CDB8)),
      ('trials', 'Trials to report', now.trials, const Color(0xFF8C837B)),
    ];
    final total = now.total;
    Widget legend(String key, String label, int n, Color c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: crm.textPrimary))),
        Text('$n', key: Key('crmOpen_$key'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
      ]),
    );
    Widget alert(String key, IconData icon, String label, int n, Color c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 15, color: n > 0 ? c : crm.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
        Text('$n', key: Key('crmOpen_$key'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: n > 0 ? c : crm.textPrimary)),
      ]),
    );
    Widget ring(double size) => SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        PieChart(
          PieChartData(
            startDegreeOffset: -90,
            sectionsSpace: total == 0 ? 0 : 2,
            centerSpaceRadius: size / 2 - 23,
            sections: total == 0
                ? [PieChartSectionData(value: 1, color: crm.border, radius: 16, showTitle: false)]
                : [for (final p in parts) if (p.$3 > 0) PieChartSectionData(value: p.$3.toDouble(), color: p.$4, radius: 16, showTitle: false)],
          ),
        ),
        // inside the hole, shrunk to fit a small ring
        SizedBox(
          width: size - 56,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$total', key: const Key('crmOpen_total'), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: crm.textPrimary, height: 1)),
              const SizedBox(height: 4),
              Text('Open works', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ]),
          ),
        ),
      ]),
    );
    final details = Column(mainAxisSize: MainAxisSize.min, children: [
      for (final p in parts) legend(p.$1, p.$2, p.$3, p.$4),
      Divider(height: 14, color: crm.border),
      alert('overdue', Icons.error_outline_rounded, 'Overdue', now.overdue, crm.destructive),
      if (unassigned != null) alert('unassigned', Icons.person_off_outlined, 'Not assigned', unassigned!.total, crm.warning),
    ]);
    return CrmDashCard(
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CrmCardHeader(title: 'Open Work Now', icon: Icons.pending_actions_outlined, onViewAll: onViewAll, viewAllKey: const Key('crmOpenWorkViewAll')),
        const SizedBox(height: 14),
        // the ring beside its legend whenever there is room (a smaller ring in a narrow card); above it only on the narrowest
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 260) return Column(children: [ring(140), const SizedBox(height: 12), details]);
          final size = c.maxWidth < 380 ? 118.0 : 150.0;
          return Row(children: [ring(size), SizedBox(width: c.maxWidth < 380 ? 12 : 18), Expanded(child: details)]);
        }),
      ]),
    );
  }
}

/// Booking requests received over the period, as a line (the last point labelled with its figure).
class CrmRequestsChartCard extends StatelessWidget {
  const CrmRequestsChartCard({super.key, required this.trend, this.onViewAll, this.height});
  final List<CrmTrendPoint> trend;
  final VoidCallback? onViewAll;
  final double? height;

  static String axisLabel(String key) {
    final d = DateTime.tryParse(key.length == 7 ? '$key-01' : key);
    if (d == null) return key;
    return key.length == 7 ? DateFormat('MMM').format(d) : DateFormat('d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final values = [for (final p in trend) (p.requestsReceived ?? 0).toDouble()];
    final maxY = values.fold<double>(0, math.max);
    final top = maxY <= 4 ? 5.0 : (maxY * 1.25).ceilToDouble();
    final step = (trend.length / 7).ceil().clamp(1, 1 << 20);
    final last = values.isEmpty ? -1 : values.length - 1;
    return CrmDashCard(
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CrmCardHeader(title: 'Booking Requests', icon: Icons.event_available_outlined, onViewAll: onViewAll, viewAllKey: const Key('crmRequestsViewAll')),
        const SizedBox(height: 14),
        Expanded(
          child: trend.isEmpty
              ? Center(child: Text('No requests in this period.', style: TextStyle(color: crm.textSecondary)))
              : LineChart(
                  key: const Key('crmRequestsChart'),
                  LineChartData(
                    minY: 0,
                    maxY: top,
                    minX: 0,
                    maxX: math.max(1, values.length - 1).toDouble(),
                    gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (top / 4).ceilToDouble().clamp(1, double.infinity), getDrawingHorizontalLine: (_) => FlLine(color: crm.border, strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    // the last day's figure stays labelled (as the design has it)
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: false,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => crm.primary,
                        tooltipBorderRadius: BorderRadius.circular(8),
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        getTooltipItems: (spots) => [for (final s in spots) LineTooltipItem('${s.y.toInt()}', const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))],
                      ),
                    ),
                    showingTooltipIndicators: last < 0 ? [] : [ShowingTooltipIndicators([LineBarSpot(_bar(values, crm.primary, last), 0, FlSpot(last.toDouble(), values[last]))])],
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: (top / 4).ceilToDouble().clamp(1, double.infinity),
                          getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox.shrink() : Text('${v.toInt()}', style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: 1,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            if (v != i || i < 0 || i >= trend.length || (i % step != 0 && i != last)) return const SizedBox.shrink();
                            if (i != last && last - i < step) return const SizedBox.shrink();
                            return Padding(padding: const EdgeInsets.only(top: 6), child: Text(axisLabel(trend[i].key), style: TextStyle(fontSize: 10.5, color: crm.textSecondary)));
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [_bar(values, crm.primary, last)],
                  ),
                ),
        ),
      ]),
    );
  }

  static LineChartBarData _bar(List<double> values, Color color, int last) => LineChartBarData(
    spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
    isCurved: true,
    curveSmoothness: 0.3,
    preventCurveOverShooting: true,
    color: color,
    barWidth: 3,
    dotData: FlDotData(show: true, checkToShowDot: (s, _) => s.x == last, getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 5, color: Colors.white, strokeWidth: 3, strokeColor: color)),
    belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)])),
  );
}

/// A tinted square with an icon.
class CrmIconTile extends StatelessWidget {
  const CrmIconTile({super.key, required this.icon, required this.color, this.size = 34});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, size: size * 0.55, color: color),
  );
}

/// Today's booking requests at a glance: received, decided, the time to decide, decided in time.
class CrmTodayCard extends StatelessWidget {
  const CrmTodayCard({super.key, required this.today, this.height, this.loading = false});
  final CrmOverview? today;
  final double? height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget row(String key, IconData icon, Color color, String label) {
      final k = today?.kpi(key) ?? const CrmKpi();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          CrmIconTile(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: crm.textPrimary))),
          Text(loading ? '…' : k.display, key: Key('crmToday_$key'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: k.value == null ? crm.textSecondary : crm.textPrimary)),
        ]),
      );
    }

    return CrmDashCard(
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CrmCardHeader(title: 'Today\'s Summary', icon: Icons.today_outlined),
        const SizedBox(height: 8),
        row('requestsReceived', Icons.inbox_outlined, kCrmIndigo, 'Requests received'),
        row('requestsDecided', Icons.task_alt_rounded, kCrmGreen, 'Requests decided'),
        row('requestMedianHours', Icons.timer_outlined, kCrmAmber, 'Time to decide'),
        row('requestWithinSlaPct', Icons.verified_outlined, kCrmSky, 'Decided in time'),
      ]),
    );
  }
}

/// A small figure: a tinted icon, its label and the figure.
class CrmMiniStat extends StatelessWidget {
  const CrmMiniStat({super.key, required this.label, required this.value, required this.icon, required this.color, this.valueKey, this.suffix, this.unknown = false});
  final String label, value;
  final String? suffix;
  final IconData icon;
  final Color color;
  final Key? valueKey;
  final bool unknown;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Row(children: [
        CrmIconTile(icon: icon, color: color, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, height: 1.2, color: crm.textSecondary)),
            const SizedBox(height: 3),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: unknown ? crm.textSecondary : crm.textPrimary)),
                if (suffix != null) TextSpan(text: suffix, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textSecondary)),
              ]),
              key: valueKey,
              maxLines: 1,
            ),
          ]),
        ),
      ]),
    );
  }
}

/// A card of small figures (Client Chat, Reviews & Cases): four across when there is room, two by two when not.
class CrmMiniStatsCard extends StatelessWidget {
  const CrmMiniStatsCard({super.key, required this.title, required this.icon, required this.stats, this.onViewAll, this.viewAllKey});
  final String title;
  final IconData icon;
  final List<Widget> stats;
  final VoidCallback? onViewAll;
  final Key? viewAllKey;

  @override
  Widget build(BuildContext context) => CrmDashCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CrmCardHeader(title: title, icon: icon, onViewAll: onViewAll, viewAllKey: viewAllKey),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 4 : 2;
        const gap = 10.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final s in stats) SizedBox(width: w, child: s)]);
      }),
    ]),
  );
}

/// "2 min ago", "3 h ago", "yesterday", "14 Nov".
String crmAgo(DateTime? at, DateTime now) {
  if (at == null) return '';
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 7) return '${d.inDays} days ago';
  return DateFormat('d MMM').format(at);
}

/// The newest things that happened in the CRM.
class CrmRecentCard extends StatelessWidget {
  const CrmRecentCard({super.key, required this.items, required this.now, this.onOpen});
  final List<CrmFeedItem> items;
  final DateTime now;
  final ValueChanged<CrmFeedItem>? onOpen;

  static (IconData, Color) look(String kind, BuildContext context) => switch (kind) {
    'request' => (Icons.event_note_outlined, const Color(0xFF8C837B)),
    'decided' => (Icons.task_alt_rounded, kCrmGreen),
    'chat' => (Icons.chat_bubble_outline_rounded, kCrmIndigo),
    'case' => (Icons.check_circle_outline_rounded, kCrmGreen),
    'review' => (Icons.star_outline_rounded, kCrmAmber),
    _ => (Icons.circle_outlined, context.crmColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return CrmDashCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CrmCardHeader(title: 'Recent Activities', icon: Icons.history_rounded),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Nothing has happened in the last two weeks.', style: TextStyle(color: crm.textSecondary))))
        else
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: crm.border),
            InkWell(
              key: Key('crmRecent_$i'),
              onTap: onOpen == null ? null : () => onOpen!(items[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  Icon(look(items[i].kind, context).$1, size: 19, color: look(items[i].kind, context).$2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(items[i].text, style: TextStyle(fontSize: 13.5, color: crm.textPrimary)),
                      if (items[i].tag.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFF3EBDD), borderRadius: BorderRadius.circular(6)),
                          child: Text(items[i].tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Text(crmAgo(items[i].at, now), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ]),
              ),
            ),
          ],
      ]),
    );
  }
}

/// The next trials: the day in a box, what and for whom, the time and the artists, its status.
class CrmUpcomingTrialsCard extends StatelessWidget {
  const CrmUpcomingTrialsCard({super.key, required this.trials, this.onViewAll});
  final List<CrmUpcomingTrial> trials;
  final VoidCallback? onViewAll;

  static String time(String hhmm) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm.trim());
    if (m == null) return hhmm;
    final h = int.parse(m.group(1)!);
    return '${h % 12 == 0 ? 12 : h % 12}:${m.group(2)} ${h < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return CrmDashCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CrmCardHeader(title: 'Upcoming Trials', icon: Icons.science_outlined, onViewAll: onViewAll, viewAllKey: const Key('crmTrialsViewAll')),
        const SizedBox(height: 10),
        if (trials.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No trial is booked from today.', style: TextStyle(color: crm.textSecondary))))
        else
          for (final t in trials) _trial(context, crm, t),
      ]),
    );
  }

  Widget _trial(BuildContext context, CrmTheme crm, CrmUpcomingTrial t) {
    final d = DateTime.tryParse(t.date);
    final postponed = t.status == 'postponed';
    final detail = [if (t.startTime.isNotEmpty) time(t.startTime), if (t.artists.isNotEmpty) t.artists.join(', ')].join(' – ');
    return Container(
      key: Key('crmTrial_${t.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Row(children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(color: kCrmPink, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(d == null ? '' : DateFormat('MMM').format(d), style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            Text(d == null ? '—' : '${d.day}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t.what} – ${t.clientName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            if (detail.isNotEmpty) Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: (postponed ? crm.warning : kCrmGreen).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(postponed ? 'Postponed' : 'Scheduled', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: postponed ? crm.warning : kCrmGreen)),
        ),
      ]),
    );
  }
}
