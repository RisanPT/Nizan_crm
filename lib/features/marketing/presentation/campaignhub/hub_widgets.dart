import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';

// The small pieces every Campaigns tab is built from.

// ── numbers ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────

String _indian(int n) {
  final s = n.abs().toString();
  if (s.length <= 3) return '${n < 0 ? '-' : ''}$s';
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${n < 0 ? '-' : ''}${parts.join(',')},${s.substring(s.length - 3)}';
}

String _trim(double v, int max) {
  final t = v.toStringAsFixed(max);
  return t.contains('.') ? t.replaceFirst(RegExp(r'\.?0+$'), '') : t;
}

/// Rupees: ₹85.49 under a thousand (two decimals when there are any), ₹1,45,000 above; [compact] shortens big sums (₹1.45L, ₹2.5Cr). null → "—".
String hubInr(double? v, {bool compact = false}) {
  if (v == null) return '—';
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (compact && a >= 1e7) return '$sign₹${_trim(a / 1e7, 2)}Cr';
  if (compact && a >= 1e5) return '$sign₹${_trim(a / 1e5, 2)}L';
  if (a >= 1000) return '$sign₹${_indian(a.round())}';
  return '$sign₹${_trim(a, 2)}';
}

/// A count with Indian-style thousands separators (468,320 → 4,68,320), or "—".
String hubCount(num? n) => n == null ? '—' : _indian(n.round());

/// 4.68 lakh → "4.68L"; under a lakh the exact figure.
String hubCompact(num n) {
  final a = n.abs().toDouble();
  if (a >= 1e7) return '${_trim(a / 1e7, 2)}Cr';
  if (a >= 1e5) return '${_trim(a / 1e5, 2)}L';
  return _indian(n.round());
}

/// A percentage figure ("3.62%", "20%"), or "—".
String hubPct(double? v, {int digits = 2}) => v == null ? '—' : '${_trim(v, digits)}%';

/// A ratio like ROAS: "14.55x", "20x", or "—".
String hubRatio(double? v) => v == null ? '—' : '${_trim(v, 2)}x';

/// Minutes as hours: 180 → "3h", 195 → "3h 15m", 45 → "45m".
String hubHours(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// "10 Nov 2026" for a 'YYYY-MM-DD' day.
String hubDay(String day, {String pattern = 'd MMM yyyy'}) {
  final d = DateTime.tryParse(day);
  return d == null ? day : DateFormat(pattern).format(d);
}

/// "↑ +12% vs last period" (green) / "↓ −8% vs last period" (red) / "No change" (grey); null when there is nothing to compare with.
/// [lowerIsBetter]: for a cost, going down is the good direction.
({String text, bool? good})? hubDelta(double? change, {bool lowerIsBetter = false, String tail = 'vs last period', bool points = false}) {
  if (change == null) return null;
  if (change == 0) return (text: 'No change', good: null);
  final up = change > 0;
  final amount = points ? '${_trim(change.abs(), 1)} pts' : '${change.abs().round()}%';
  return (text: '${up ? '↑ +' : '↓ −'}$amount $tail', good: lowerIsBetter ? !up : up);
}

// ── colours and icons ────────────────────────────────────────────────────────────────────────────────────────────────────────

Color hubStatusColor(String s) => switch (s) {
      'active' => Mkt.good,
      'paused' => Mkt.warn,
      'completed' => Mkt.blue,
      _ => Mkt.grey,
    };

Color adVerdictColor(String v) => switch (v) {
      'top' => Mkt.good,
      'under' => Mkt.warn,
      'needs_attention' => Mkt.bad,
      'early' => Mkt.grey,
      _ => Mkt.blue,
    };

IconData hubPlatformIcon(String p) => switch (p) {
      'instagram' => Icons.camera_alt_outlined,
      'facebook' => Icons.facebook_outlined,
      'meta' => Icons.all_inclusive_rounded,
      'google' => Icons.search_rounded,
      'youtube' => Icons.smart_display_outlined,
      'whatsapp' => Icons.chat_outlined,
      _ => Icons.public_rounded,
    };

IconData adFormatIcon(String f) => switch (f) {
      'video' || 'reel' => Icons.play_circle_outline_rounded,
      'carousel' => Icons.view_carousel_outlined,
      'story' => Icons.auto_stories_outlined,
      _ => Icons.image_outlined,
    };

Color adFormatColor(String f) => switch (f) {
      'reel' => Mkt.pink,
      'video' => Mkt.bad,
      'carousel' => Mkt.blue,
      'story' => Mkt.primaryLight,
      _ => Mkt.teal,
    };

Color insightColor(String kind) => switch (kind) {
      'good' => Mkt.good,
      'warn' => Mkt.warn,
      _ => Mkt.primary,
    };

IconData insightIcon(String kind) => switch (kind) {
      'good' => Icons.check_circle_rounded,
      'warn' => Icons.warning_amber_rounded,
      _ => Icons.info_outline_rounded,
    };

// ── small pieces ─────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// An ad's (or a campaign's) picture: its thumbnail link, else a tinted tile with its format's icon.
class HubThumb extends StatelessWidget {
  const HubThumb({super.key, required this.url, this.format = 'image', this.size = 44, this.radius = 9});
  final String url, format;
  final double size, radius;

  @override
  Widget build(BuildContext context) {
    final c = adFormatColor(format);
    final fallback = Container(width: size, height: size, color: Mkt.tint(c, 0.14), child: Icon(adFormatIcon(format), size: size * 0.45, color: c));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty ? fallback : Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback, loadingBuilder: (_, child, p) => p == null ? child : fallback),
    );
  }
}

Future<void> hubOpenLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// A white search box in the kit's look.
InputDecoration hubSearchDecoration(String hint) => InputDecoration(
      prefixIcon: const Icon(Icons.search_rounded, size: 18),
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.primary)),
    );

/// "Showing 1–10 of 32" with ‹ › buttons (the keys are `<prefix>_showing`, `<prefix>_prev`, `<prefix>_next`).
class HubPager extends StatelessWidget {
  const HubPager({super.key, required this.prefix, required this.page, required this.pageSize, required this.total, required this.shown, required this.onPage});
  final String prefix;
  final int page, pageSize, total, shown;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final to = (page - 1) * pageSize + shown;
    final pages = (total / pageSize).ceil().clamp(1, 9999);
    return Row(children: [
      Flexible(child: Text(total == 0 ? 'Nothing to show' : 'Showing $from–$to of $total', key: Key('${prefix}_showing'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft))),
      const Spacer(),
      IconButton(key: Key('${prefix}_prev'), visualDensity: VisualDensity.compact, onPressed: page > 1 ? () => onPage(page - 1) : null, icon: const Icon(Icons.chevron_left_rounded, size: 20)),
      Text('$page / $pages', style: mktText(11.5, weight: FontWeight.w700)),
      IconButton(key: Key('${prefix}_next'), visualDensity: VisualDensity.compact, onPressed: page < pages ? () => onPage(page + 1) : null, icon: const Icon(Icons.chevron_right_rounded, size: 20)),
    ]);
  }
}

/// A plain-language line the data supports, with its coloured icon.
class InsightLine extends StatelessWidget {
  const InsightLine({super.key, required this.insight});
  final HubInsight insight;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(insightIcon(insight.kind), size: 16, color: insightColor(insight.kind)),
          const SizedBox(width: 8),
          Expanded(child: Text(insight.text, style: mktText(12.5, height: 1.3))),
        ]),
      );
}

// ── charts ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// One line (or one set of bars) of a chart; a null value is a gap.
class HubSeries {
  const HubSeries(this.label, this.color, this.values, {this.bars = false});
  final String label;
  final Color color;
  final List<double?> values;
  final bool bars;
}

FlLine _grid(double v) => const FlLine(color: Mkt.border, strokeWidth: 1);

/// The trend chart: bars for a single bar series (spend), lines otherwise. [days] label the x axis (a 'YYYY-MM-DD' each).
class HubChart extends StatelessWidget {
  const HubChart({super.key, required this.days, required this.series, this.height = 190, this.valueLabel});
  final List<String> days;
  final List<HubSeries> series;
  final double height;

  /// How an axis value reads (₹ for spend, plain for counts).
  final String Function(double)? valueLabel;

  @override
  Widget build(BuildContext context) {
    final label = valueLabel ?? (double v) => hubCompact(v);
    final all = [for (final s in series) ...s.values.whereType<double>()];
    final maxV = all.isEmpty ? 1.0 : all.reduce((a, b) => a > b ? a : b);
    final top = maxV <= 0 ? 1.0 : maxV * 1.15;
    final n = days.length;
    final interval = n > 10 ? (n / 7).ceilToDouble() : 1.0;
    final titles = FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 46, getTitlesWidget: (v, m) => v == m.max || v == m.min ? const SizedBox.shrink() : Text(label(v), style: mktText(9.5, color: Mkt.inkSoft)))),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: interval,
          getTitlesWidget: (v, _) => n == 0 ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 6), child: Text(hubDay(days[v.toInt().clamp(0, n - 1)], pattern: n <= 8 ? 'd MMM' : 'd MMM'), style: mktText(9.5, color: Mkt.inkSoft))),
        ),
      ),
    );
    final Widget chart;
    if (series.length == 1 && series.first.bars) {
      final s = series.first;
      chart = BarChart(BarChartData(
        maxY: top,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: _grid),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: titles,
        barGroups: [
          for (var i = 0; i < n; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: s.values[i] ?? 0, color: s.color, width: n > 20 ? 5 : (n > 10 ? 9 : 16), borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]),
        ],
      ));
    } else {
      chart = LineChart(LineChartData(
        minY: 0,
        maxY: top,
        gridData: const FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: _grid),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: titles,
        lineBarsData: [
          for (final s in series)
            LineChartBarData(
              spots: [for (var i = 0; i < n; i++) s.values[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), s.values[i]!)],
              isCurved: true,
              color: s.color,
              barWidth: 2.5,
              dotData: FlDotData(show: n <= 12),
              belowBarData: BarAreaData(show: series.length == 1, color: s.color.withValues(alpha: 0.12)),
            ),
        ],
      ));
    }
    return SizedBox(height: height, child: chart);
  }
}

/// A row of coloured dots naming a chart's series.
class HubLegend extends StatelessWidget {
  const HubLegend({super.key, required this.series});
  final List<HubSeries> series;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 14, runSpacing: 4, children: [
        for (final s in series)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(s.label, style: mktText(11, color: Mkt.inkSoft)),
          ]),
      ]);
}

/// The little segmented toggle above a chart ("Spend | Leads | CPL").
class HubToggle extends StatelessWidget {
  const HubToggle({super.key, required this.options, required this.value, required this.onChanged, this.keyPrefix = 'hub_toggle'});
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

/// The small "Lifetime" mark of an ad typed by hand: its figures are the cumulative ones typed on it, so the dates do not narrow them.
class HubLifetimeMark extends StatelessWidget {
  const HubLifetimeMark({super.key});

  @override
  Widget build(BuildContext context) => const Tooltip(
        message: 'Typed by hand: lifetime figures, not narrowed by the dates. Import the ad-level export to see this ad day by day.',
        child: MktChip('Lifetime', color: Mkt.grey, icon: Icons.all_inclusive_rounded),
      );
}

/// How the Creatives & Ads verdicts are decided (the server's rules, backend utils/marketingCampaignStats.js adVerdict), in plain words.
const kAdVerdictRules = [
  ('top', 'Top performing', 'CTR at least 110% of the brand\'s average, or cost per result at most 90% of it — and neither is poor.'),
  ('under', 'Underperforming', 'One signal is poor (CTR below 70% of the average, or cost per result above 130% of it) and none is good.'),
  ('needs_attention', 'Needs attention', 'Both signals are poor, or ₹500+ was spent with no result while other ads do get results.'),
  ('early', 'Too early', 'Fewer than 1,000 impressions and less than ₹500 spent: not enough to judge.'),
];

/// The legend under the ads table: what each verdict means. Ads are judged against ALL the brand's ads of the dates, so a filter never
/// changes a verdict; results and cost per result are Meta's own.
class AdVerdictLegend extends StatelessWidget {
  const AdVerdictLegend({super.key});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('ad_verdict_legend'),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: Mkt.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How an ad is judged — against the average of all the brand\'s ads in these dates (Meta\'s results)', style: mktText(11.5, weight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final r in kAdVerdictRules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 128, child: Align(alignment: Alignment.centerLeft, child: MktChip(r.$2, color: adVerdictColor(r.$1)))),
                const SizedBox(width: 6),
                Expanded(child: Text(r.$3, style: mktText(11, color: Mkt.inkSoft, height: 1.3))),
              ]),
            ),
        ]),
      );
}
