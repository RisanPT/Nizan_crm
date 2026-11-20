import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/data/weekly_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart' show csvSafe, dayLabel, numText, pctText, rupees;

// The small pieces of the Marketing Weekly Report: the toggle above the chart, the this-week-against-last-week line chart, the
// shoots-done rings, the event icons and the CSV the Export button downloads.

String count(num n) => NumberFormat.decimalPattern('en_IN').format(n.round());

/// "27 Reels posted", or "3 h logged" for a member who logged hours and no counts.
String memberResult(WeeklyMemberRow r) => r.isHours ? '${numText(r.value)} h logged' : '${numText(r.value)} ${r.metric ?? ''}'.trim();

/// "↑ 35%" / "↓ 8%" / "—" for the change on the period before.
String changeArrow(double? c) => c == null ? '' : (c == 0 ? '→ 0%' : '${c > 0 ? '↑' : '↓'} ${numText(c.abs())}%');
Color changeColor(double? c) => c == null || c == 0 ? Mkt.inkSoft : (c > 0 ? Mkt.good : Mkt.bad);

/// The little segmented toggle above a card ("Leads | Bookings | Revenue").
class WeeklyToggle extends StatelessWidget {
  const WeeklyToggle({super.key, required this.options, required this.value, required this.onChanged, required this.keyPrefix});
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(9), border: Border.all(color: Mkt.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final o in options)
            GestureDetector(
              key: Key('${keyPrefix}_${o.$1}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: o.$1 == value ? Mkt.primary : Colors.transparent, borderRadius: BorderRadius.circular(7)),
                child: Text(o.$2, style: mktText(11, weight: FontWeight.w700, color: o.$1 == value ? Colors.white : Mkt.inkSoft)),
              ),
            ),
        ]),
      );
}

/// This range's day-by-day line against the period before (the same position in it): Monday against Monday for a week.
class WeeklyCompareChart extends StatelessWidget {
  const WeeklyCompareChart({super.key, required this.days, required this.metric, required this.nowLabel, required this.beforeLabel, this.height = 200});
  final List<WeeklyDay> days;
  final String metric; // leads | bookings | revenue
  final String nowLabel, beforeLabel;
  final double height;

  static String _axis(double v, String metric) => metric == 'revenue' ? rupees(v, decimals: 0).replaceAll('₹', '') : v.toInt().toString();

  @override
  Widget build(BuildContext context) {
    final anyNow = days.any((d) => d.now.of(metric) > 0);
    final anyBefore = days.any((d) => (d.before?.of(metric) ?? 0) > 0);
    if (days.isEmpty || (!anyNow && !anyBefore)) return MktEmpty('Nothing recorded in this range.', icon: Icons.show_chart_rounded, height: height);
    var maxY = 1.0;
    for (final d in days) {
      if (d.now.of(metric) > maxY) maxY = d.now.of(metric);
      if ((d.before?.of(metric) ?? 0) > maxY) maxY = d.before!.of(metric);
    }
    final short = days.length <= 7;
    final interval = days.length > 8 ? (days.length / 6).ceilToDouble() : 1.0;
    String label(int i) {
      final d = days[i.clamp(0, days.length - 1)];
      return short ? DateFormat('EEE').format(DateTime.tryParse(d.day) ?? DateTime(2026)) : dayLabel(d.day);
    }

    LineChartBarData line(List<double> ys, Color color, {bool soft = false}) => LineChartBarData(
          spots: [for (var i = 0; i < ys.length; i++) FlSpot(i.toDouble(), ys[i])],
          isCurved: true,
          color: color,
          barWidth: soft ? 2 : 2.6,
          dotData: FlDotData(show: days.length <= 14 && !soft),
          dashArray: soft ? [5, 4] : null,
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 14, runSpacing: 4, children: [
        for (final s in [(nowLabel, Mkt.primary), (beforeLabel, Mkt.primaryLight.withValues(alpha: 0.55))])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: s.$2, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(s.$1, style: mktText(11, color: Mkt.inkSoft)),
          ]),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        height: height,
        child: LineChart(LineChartData(
          minY: 0,
          maxY: maxY * 1.15,
          gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Mkt.border, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => v == m.max || (metric != 'revenue' && v != v.roundToDouble()) ? const SizedBox.shrink() : Text(_axis(v, metric), style: mktText(9.5, color: Mkt.inkSoft)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: interval, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(label(v.toInt()), style: mktText(9.5, color: Mkt.inkSoft))))),
          ),
          lineBarsData: [
            line([for (final d in days) d.before?.of(metric) ?? 0], Mkt.primaryLight.withValues(alpha: 0.55), soft: true),
            line([for (final d in days) d.now.of(metric)], Mkt.primary),
          ],
        )),
      ),
    ]);
  }
}

/// A ring with "done/planned" inside and a caption under it.
class WeeklyRing extends StatelessWidget {
  const WeeklyRing({super.key, required this.done, required this.planned, required this.caption, required this.color});
  final int done, planned;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 74,
          height: 74,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(value: planned == 0 ? 0 : (done / planned).clamp(0, 1).toDouble(), strokeWidth: 7, backgroundColor: Mkt.tint(color, 0.14), color: color)),
            FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.all(12), child: Text('$done/$planned', style: mktText(15, weight: FontWeight.w800)))),
          ]),
        ),
        const SizedBox(height: 6),
        SizedBox(width: 96, child: Text(caption, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11, weight: FontWeight.w600, color: Mkt.inkSoft, height: 1.2))),
      ]);
}

IconData eventIcon(String kind) => switch (kind) {
      'lead' => Icons.person_add_alt_1_rounded,
      'booking' => Icons.event_available_rounded,
      'campaign' => Icons.campaign_rounded,
      'shoot' => Icons.videocam_rounded,
      'post' => Icons.ios_share_rounded,
      _ => Icons.bolt_rounded,
    };

Color eventColor(String kind) => switch (kind) {
      'lead' => Mkt.blue,
      'booking' => Mkt.good,
      'campaign' => Mkt.primaryLight,
      'shoot' => Mkt.pink,
      'post' => Mkt.warn,
      _ => Mkt.grey,
    };

/// "2 min ago", "3 h ago", or the day and time for anything older than a day.
String eventTime(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final n = now ?? DateTime.now();
  final d = n.difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return DateFormat('d MMM, h:mm a').format(at);
}

// ── export ───────────────────────────────────────────────────────────────────────────────────────────────────────────────

typedef WeeklyCsvSaver = Future<void> Function(String fileName, List<List<Object?>> rows);
final weeklyCsvSaverProvider = Provider<WeeklyCsvSaver>((ref) => downloadCsv);

String weeklyCsvFileName(WeeklyReport r) => 'marketing-weekly-report-${r.from}-to-${r.to}${r.brand == 'all' ? '' : '-${r.brand}'}.csv';

/// The whole report as a CSV: its range and brand, then each card as a small table. A cell that starts like a formula is written as text.
List<List<Object?>> weeklyCsvRows(WeeklyReport r) {
  final h = r.headline;
  String chg(double? c) => c == null ? '' : '${numText(c)}%';
  return [
    ['Marketing Weekly Report'],
    ['From', r.from, 'To', r.to, 'Brand', TeamBrand.parse(r.brand).label],
    ['Compared with', r.previousFrom, 'to', r.previousTo],
    [],
    ['Headline', 'This period', 'Previous period', 'Change'],
    ['Total leads', h.leads.now.round(), h.leads.before.round(), chg(h.leads.change)],
    ['Bookings', h.bookings.now.round(), h.bookings.before.round(), chg(h.bookings.change)],
    ['Revenue (₹, ex-GST)', h.revenue.now, h.revenue.before, chg(h.revenue.change)],
    ['Ad spend (₹)', h.adSpend == null ? 'Not recorded' : h.adSpend!.now, h.adSpend == null ? '' : h.adSpend!.before, h.adSpend == null ? '' : chg(h.adSpend!.change)],
    ['Conversion rate (%)', h.conversionKnown ? numText(h.conversionRate.now) : '', h.conversionKnown ? numText(h.conversionRate.before) : '', h.conversionRate.change == null ? '' : '${numText(h.conversionRate.change!)} pp'],
    [],
    ['Day by day', 'Leads', 'Bookings', 'Revenue (₹, ex-GST)', 'Previous day', 'Previous leads', 'Previous bookings', 'Previous revenue (₹, ex-GST)'],
    for (final d in r.trend) [d.day, d.now.leads, d.now.bookings, d.now.revenue, d.before?.day ?? '', d.before?.leads ?? '', d.before?.bookings ?? '', d.before?.revenue ?? ''],
    [],
    ['Lead quality', 'Leads', 'Share (%)'],
    for (final q in r.quality.rows) [q.label, q.count, q.pct == null ? '' : numText(q.pct!)],
    [],
    ['Lead sources', 'Leads', 'Share (%)'],
    for (final s in r.sources.rows) [csvSafe(s.label), s.count, s.pct == null ? '' : numText(s.pct!)],
    [],
    ['Individual insights', 'Role', 'Key result', 'Change (%)'],
    for (final m in r.members.rows) [csvSafe(m.name), csvSafe(m.role), csvSafe(memberResult(m)), m.change == null ? '' : numText(m.change!)],
    if (r.members.silent > 0) ['${r.members.silent} member(s) logged nothing in this range'],
    [],
    ['Campaigns', 'Leads', 'Bookings', 'Revenue (₹)', 'Spend (₹)'],
    for (final c in r.campaigns) [csvSafe(c.title), c.leads, c.bookings, c.revenue, c.spend],
    [],
    ['Production', 'Planned', 'Done'],
    ['All shoots', r.production.planned, r.production.done],
    for (final c in r.production.categories) [csvSafe(c.category), c.planned, c.done],
    [],
    ['Revenue & collection', '₹'],
    ['Total order value (₹, incl. GST)', r.revenue.orderValue],
    ['Advance collected', r.revenue.advance],
    ['Collected later', r.revenue.collectedLater],
    ['Balance due', r.revenue.balanceDue],
    ['Average order value', r.revenue.averageOrder ?? ''],
    ['Advance collection progress (%)', r.revenue.advanceProgress == null ? '' : numText(r.revenue.advanceProgress!)],
    [],
    ['Key insights'],
    for (final s in r.insights) [csvSafe(s)],
  ];
}

String pct(double? v) => pctText(v);
