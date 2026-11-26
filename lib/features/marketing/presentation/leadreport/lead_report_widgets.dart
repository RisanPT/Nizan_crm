import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

// The small pieces every Lead Report tab is built from: colours, number and change text, the funnel and trend charts, the pager and
// search box, the call / WhatsApp buttons, and the CSV export.

Color leadStageColor(String key) => switch (key) {
      'new' => Mkt.blue,
      'in_progress' => Mkt.warn,
      'not_converted' => Mkt.bad,
      'converted' => Mkt.good,
      _ => Mkt.primary,
    };

/// Hot / Warm / Nurture / Cold (the CRM priority); "Not rated" (no priority) is grey.
Color leadQualityColor(String quality) => switch (quality) {
      'Hot' => Mkt.bad,
      'Warm' => Mkt.warn,
      'Nurture' => Mkt.teal,
      'Cold' => Mkt.blue,
      _ => Mkt.grey,
    };

/// The source groups of the Sources screen, in the server's order (the keys are the All Leads `source` filter).
const kLeadSourceGroups = [('instagram', 'Instagram'), ('meta_ads', 'Meta Ads'), ('whatsapp', 'WhatsApp'), ('youtube', 'YouTube'), ('website', 'Website'), ('others', 'Others')];

Color sourceGroupColor(String key) => switch (key) {
      'instagram' => Mkt.pink,
      'meta_ads' => Mkt.blue,
      'whatsapp' => Mkt.good,
      'youtube' => Mkt.bad,
      'website' => Mkt.teal,
      _ => Mkt.grey,
    };

/// The colour of a campaign type (Leads by Campaign Type).
Color campaignTypeColor(String key) => switch (key) {
      'lead_gen' => Mkt.primaryLight,
      'whatsapp' => Mkt.good,
      'form' => Mkt.teal,
      'calls' => Mkt.blue,
      _ => Mkt.grey,
    };

Color followUpColor(String state) => switch (state) {
      'completed' => Mkt.good,
      'overdue' => Mkt.bad,
      'today' => Mkt.warn,
      _ => Mkt.blue,
    };

String followUpLabel(String state) => switch (state) {
      'completed' => 'Completed',
      'overdue' => 'Overdue',
      'today' => 'Due Today',
      _ => 'Upcoming',
    };

/// 33.3 → "33.3", 50.0 → "50".
String numText(num v) => v.toDouble() == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// "33.3%", or "—" when there is nothing to divide.
String pctText(double? v) => v == null ? '—' : '${numText(v)}%';

/// ₹ with Indian grouping; lakhs and crores shortened ("₹34.76L"). [decimals] for small figures such as a cost per lead.
String rupees(num v, {bool compact = true, int decimals = 0}) {
  final n = v.toDouble();
  if (compact && n.abs() >= 1e7) return '₹${(n / 1e7).toStringAsFixed(2)}Cr';
  if (compact && n.abs() >= 1e5) return '₹${(n / 1e5).toStringAsFixed(2)}L';
  return '₹${NumberFormat.decimalPatternDigits(locale: 'en_IN', decimalDigits: decimals).format(n)}';
}

/// "—" when the cost is not known (no ad spend recorded) — never a made-up number.
String costText(double? v) => v == null ? '—' : rupees(v, decimals: v < 1000 ? 2 : 0);

/// "↑ +12% vs previous period" (green), "↓ −8% …" (red), "No change", or null with nothing to compare. [points] for a rate's change.
({String text, bool? good})? leadDelta(double? change, {bool points = false, bool lowerIsBetter = false, String tail = 'vs previous period'}) {
  if (change == null) return null;
  if (change == 0) return (text: 'No change', good: null);
  final up = change > 0;
  return (text: '${up ? '↑ +' : '↓ −'}${numText(change.abs())}${points ? ' pp' : '%'} $tail', good: lowerIsBetter ? !up : up);
}

/// "8 Nov" for a day string like 2026-11-08 (the string itself when it cannot be read).
String dayLabel(String day, {String pattern = 'd MMM'}) {
  final d = DateTime.tryParse(day);
  return d == null ? day : DateFormat(pattern).format(d);
}

/// One KPI card from a figure and its change.
Widget leadKpi({required String key, required IconData icon, required String label, required String value, double? change, bool points = false, bool lowerIsBetter = false, Color tint = Mkt.primary, String? note, VoidCallback? onTap}) {
  final d = leadDelta(change, points: points, lowerIsBetter: lowerIsBetter);
  return MktKpiCard(key: Key(key), icon: icon, value: value, label: label, note: note ?? d?.text, good: note != null ? null : d?.good, tint: tint, onTap: onTap);
}

/// A table cell: one line of text that ends in an ellipsis rather than overflowing.
Widget lrCell(String text, {bool bold = false, Color color = Mkt.ink, int maxLines = 1}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: mktText(12, weight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
    );

// ── page body ────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// A tab's body: loading, a "Try again" error, or the cards in a pull-to-refresh list.
class LrAsync<T> extends ConsumerWidget {
  const LrAsync({super.key, required this.value, required this.listKey, required this.builder});
  final AsyncValue<T> value;
  final Key listKey;
  final List<Widget> Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
        onRefresh: () async => refreshLeadReport(ref),
        child: value.when(
          loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshLeadReport(ref))]),
          data: (d) => ListView(key: listKey, physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: builder(context, d)),
        ),
      );
}

/// A quiet line of explanation under a card or strip.
class LrNote extends StatelessWidget {
  const LrNote(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.color = Mkt.inkSoft});
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 13, color: color)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: mktText(11, color: color, height: 1.3))),
        ]),
      );
}

/// The warning every tab shows when the server stopped at its cap (so the figures would be a part, not the whole).
Widget? cappedNote(bool capped) => capped ? const LrNote('There are more leads in this range than the report can load — narrow the dates so the figures are complete.', icon: Icons.warning_amber_rounded, color: Mkt.bad) : null;

// ── charts ───────────────────────────────────────────────────────────────────────────────────────────────────────────────

FlLine _grid(double v) => const FlLine(color: Mkt.border, strokeWidth: 1);

typedef TrendSeries = ({String key, String label, Color color, num Function(TrendRow r) value});

/// The legend line over a chart: a dot and a name for each series.
class _Legend extends StatelessWidget {
  const _Legend(this.series);
  final List<TrendSeries> series;

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

double _maxOf(List<TrendRow> rows, List<TrendSeries> series) {
  var m = 0.0;
  for (final r in rows) {
    for (final s in series) {
      if (s.value(r) > m) m = s.value(r).toDouble();
    }
  }
  return m < 1 ? 1 : m;
}

Widget _bottomTitle(List<TrendRow> rows, double v) {
  final i = v.toInt().clamp(0, rows.length - 1);
  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(dayLabel(rows[i].from), style: mktText(9.5, color: Mkt.inkSoft)));
}

/// Lines over time: one per series, a point per bucket (a day, or a week for long ranges).
class LeadLineChart extends StatelessWidget {
  const LeadLineChart({super.key, required this.rows, required this.series, this.height = 190});
  final List<TrendRow> rows;
  final List<TrendSeries> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty || !rows.any((r) => series.any((s) => s.value(r) > 0))) return MktEmpty('No leads arrived in this range.', icon: Icons.show_chart_rounded, height: height);
    final maxY = _maxOf(rows, series);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Legend(series),
      const SizedBox(height: 10),
      SizedBox(
        height: height,
        child: LineChart(LineChartData(
          minY: 0,
          maxY: maxY * 1.15,
          gridData: const FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: _grid),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, m) => v == m.max || v != v.roundToDouble() ? const SizedBox.shrink() : Text(v.toInt().toString(), style: mktText(9.5, color: Mkt.inkSoft)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: rows.length > 8 ? (rows.length / 6).ceilToDouble() : 1, getTitlesWidget: (v, _) => _bottomTitle(rows, v))),
          ),
          lineBarsData: [
            for (final s in series)
              LineChartBarData(
                spots: [for (var i = 0; i < rows.length; i++) FlSpot(i.toDouble(), s.value(rows[i]).toDouble())],
                isCurved: true,
                color: s.color,
                barWidth: 2.4,
                dotData: FlDotData(show: rows.length <= 14),
              ),
          ],
        )),
      ),
    ]);
  }
}

/// Grouped bars over time: one bar per series in each bucket (leads against converted).
class LeadBarChart extends StatelessWidget {
  const LeadBarChart({super.key, required this.rows, required this.series, this.height = 190});
  final List<TrendRow> rows;
  final List<TrendSeries> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty || !rows.any((r) => series.any((s) => s.value(r) > 0))) return MktEmpty('No leads arrived in this range.', icon: Icons.bar_chart_rounded, height: height);
    final maxY = _maxOf(rows, series);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Legend(series),
      const SizedBox(height: 10),
      SizedBox(
        height: height,
        child: LayoutBuilder(builder: (context, box) {
          final rod = ((box.maxWidth - 40) / (rows.length * (series.length + 1.2))).clamp(2.0, 14.0);
          return BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            minY: 0,
            maxY: maxY * 1.15,
            gridData: const FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: _grid),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, m) => v == m.max || v != v.roundToDouble() ? const SizedBox.shrink() : Text(v.toInt().toString(), style: mktText(9.5, color: Mkt.inkSoft)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: rows.length > 8 ? (rows.length / 6).ceilToDouble() : 1, getTitlesWidget: (v, _) => _bottomTitle(rows, v))),
            ),
            barGroups: [
              for (var i = 0; i < rows.length; i++)
                BarChartGroupData(x: i, barsSpace: 1, barRods: [for (final s in series) BarChartRodData(toY: s.value(rows[i]).toDouble(), color: s.color, width: rod, borderRadius: BorderRadius.circular(2))]),
            ],
          ));
        }),
      ),
    ]);
  }
}

/// The funnel: a bar for each step, narrower as the leads thin out, with its count and its share of ALL the leads.
class LeadFunnelView extends StatelessWidget {
  const LeadFunnelView({super.key, required this.funnel, this.keyPrefix = 'lr_funnel', this.colorOf = _funnelColor});
  final Funnel funnel;
  final String keyPrefix;
  final Color Function(String key) colorOf;

  static Color _funnelColor(String key) => switch (key) {
        'qualified' => Mkt.blue,
        'hot' => Mkt.warn,
        'bookings' => Mkt.good,
        _ => Mkt.primary,
      };

  @override
  Widget build(BuildContext context) {
    if (funnel.total == 0) return const MktEmpty('No leads in this range.', icon: Icons.filter_alt_outlined, height: 150);
    return Column(children: [
      for (final s in funnel.steps)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: (s.count / funnel.total).clamp(0.4, 1.0),
              child: Container(
                key: Key('${keyPrefix}_${s.key}'),
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colorOf(s.key), borderRadius: BorderRadius.circular(8)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.label, style: mktText(12, weight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(width: 10),
                    Text('${s.count}', style: mktText(14, weight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(width: 6),
                    Text(s.pct == null ? '' : '(${pctText(s.pct)})', style: mktText(11, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

// ── list controls ────────────────────────────────────────────────────────────────────────────────────────────────────────

/// "Showing 1–10 of 42" with previous / next.
class LeadPager extends StatelessWidget {
  const LeadPager({super.key, required this.page, required this.pageSize, required this.total, required this.onPage, this.keyPrefix = 'lr', this.noun = 'leads'});
  final int page, pageSize, total;
  final ValueChanged<int> onPage;
  final String keyPrefix, noun;

  @override
  Widget build(BuildContext context) {
    final pages = total == 0 ? 1 : (total / pageSize).ceil();
    final from = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final to = total == 0 ? 0 : (page * pageSize > total ? total : page * pageSize);
    return Row(children: [
      Flexible(child: Text(total == 0 ? 'No $noun' : 'Showing $from–$to of $total', key: Key('${keyPrefix}_showing'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft))),
      const Spacer(),
      IconButton(key: Key('${keyPrefix}_prev'), visualDensity: VisualDensity.compact, onPressed: page > 1 ? () => onPage(page - 1) : null, icon: const Icon(Icons.chevron_left_rounded, size: 20)),
      Text('$page / $pages', style: mktText(11.5, weight: FontWeight.w700)),
      IconButton(key: Key('${keyPrefix}_next'), visualDensity: VisualDensity.compact, onPressed: page < pages ? () => onPage(page + 1) : null, icon: const Icon(Icons.chevron_right_rounded, size: 20)),
    ]);
  }
}

/// A search box that waits for a pause in typing before it asks the server.
class LeadSearchField extends StatefulWidget {
  const LeadSearchField({super.key, required this.initial, required this.onChanged, this.hint = 'Search leads'});
  final String initial, hint;
  final ValueChanged<String> onChanged;

  @override
  State<LeadSearchField> createState() => _LeadSearchFieldState();
}

class _LeadSearchFieldState extends State<LeadSearchField> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  Timer? _wait;

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        onChanged: (v) {
          _wait?.cancel();
          _wait = Timer(const Duration(milliseconds: 350), () => widget.onChanged(v));
        },
        style: mktText(13),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hint,
          hintStyle: mktText(13, color: Mkt.inkSoft),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Mkt.inkSoft),
          filled: true,
          fillColor: Mkt.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.primary)),
        ),
      );
}

// ── contact ──────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// The digits for a WhatsApp link: a 10-digit Indian number gets 91 in front (a leading 0 is dropped); a number that already carries
/// its country code is kept; anything else cannot be dialled (null).
String? whatsappNumber(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length == 10) return '91$d';
  if (d.length == 11 && d.startsWith('0')) return '91${d.substring(1)}';
  if (d.length >= 11 && d.length <= 15) return d;
  return null;
}

Uri? whatsappUri(String phone) {
  final n = whatsappNumber(phone);
  return n == null ? null : Uri.parse('https://wa.me/$n');
}

/// tel: with the digits (and a leading + when the number had one); null when there are too few digits to be a number.
Uri? telUri(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length < 6 || d.length > 15) return null;
  return Uri(scheme: 'tel', path: phone.trim().startsWith('+') ? '+$d' : d);
}

/// The call and WhatsApp buttons of a row — only ever shown with a real number (the server sends one to managers only).
class ContactButtons extends ConsumerWidget {
  const ContactButtons({super.key, required this.phone, required this.idKey});
  final String phone;
  final String idKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> open(Uri? uri) async {
      if (uri == null) return;
      final ok = await ref.read(leadLinkOpenerProvider)(uri);
      if (!ok && context.mounted) showErrorSnackBar(context, null, fallback: 'Could not open that. Is there an app for it on this device?');
    }

    final tel = telUri(phone);
    final wa = whatsappUri(phone);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(key: Key('lr_call_$idKey'), tooltip: 'Call', visualDensity: VisualDensity.compact, iconSize: 18, color: Mkt.good, onPressed: tel == null ? null : () => open(tel), icon: const Icon(Icons.call_outlined)),
      IconButton(key: Key('lr_wa_$idKey'), tooltip: 'WhatsApp', visualDensity: VisualDensity.compact, iconSize: 18, color: Mkt.teal, onPressed: wa == null ? null : () => open(wa), icon: const Icon(Icons.chat_outlined)),
    ]);
  }
}

// ── Leads by Campaign Type ───────────────────────────────────────────────────────────────────────────────────────────────

/// The campaign leads of the range by type (lead gen / WhatsApp / website form / calls / others) — the Campaigns hub's split, from the
/// same server function, so the two screens agree.
class LeadCampaignTypesCard extends StatelessWidget {
  const LeadCampaignTypesCard({super.key, required this.rows});
  final List<CampaignTypeRow> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<int>(0, (t, r) => t + r.leads);
    return MktCard(
      title: 'Leads by Campaign Type',
      subtitle: 'Campaign leads of this range — from the campaign\'s objective and the lead\'s source',
      icon: Icons.category_outlined,
      child: rows.isEmpty
          ? const MktEmpty('No lead in this range is tagged to a campaign.', icon: Icons.category_outlined, height: 120)
          : MktDonut(
              key: const Key('lr_campaign_types'),
              centerKey: const Key('lr_campaign_types_total'),
              size: 110,
              sideBySideFrom: 360,
              centerValue: '$total',
              centerLabel: 'Campaign leads',
              colors: [for (final r in rows) campaignTypeColor(r.key)],
              slices: [for (final r in rows) (label: r.label, value: r.leads.toDouble(), trailing: '${r.leads} · ${r.pct}%')],
            ),
    );
  }
}

// ── export ───────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// What the Export button downloads for each tab (the Reports tab has its own buttons).
const kLeadExportOf = {
  'overview': 'summary',
  'leads': 'leads',
  'stages': 'summary',
  'sources': 'sources',
  'followups': 'followups',
  'conversion': 'conversion',
};

/// A cell that starts like a spreadsheet formula (= + - @) is written as text, so a lead named "=HYPERLINK(…)" cannot run anything.
Object? csvSafe(Object? v) => v is String && v.isNotEmpty && '=+-@\t\r'.contains(v[0]) ? "'$v" : v;

String csvFileName(LeadReportTable t) => 'lead-report-${t.type}-${t.from}-to-${t.to}${t.brand == 'all' ? '' : '-${t.brand}'}.csv';

/// The CSV of a report: its title, range and brand, then the table.
List<List<Object?>> leadReportCsvRows(LeadReportTable t) => [
      ['Lead Report — ${t.title}'],
      ['From', t.from, 'To', t.to, 'Brand', TeamBrand.parse(t.brand).label],
      if (t.truncated) ['Only the first 20,000 rows are included — narrow the dates.'],
      [],
      t.columns,
      for (final r in t.rows) [for (final c in r) csvSafe(c)],
    ];

typedef CsvSaver = Future<void> Function(String fileName, List<List<Object?>> rows);
final leadCsvSaverProvider = Provider<CsvSaver>((ref) => downloadCsv);

/// Build a report for the chosen range and brand and download it as a CSV; a refusal or failure is shown in plain words.
/// → the report it downloaded (its period and brand, to keep it in "Saved reports"), or null when it could not (the error is shown).
Future<LeadReportTable?> exportLeadReport(BuildContext context, WidgetRef ref, String type) async {
  try {
    final t = await ref.read(leadReportServiceProvider).report(type, ref.read(teamFilterProvider));
    await ref.read(leadCsvSaverProvider)(csvFileName(t), leadReportCsvRows(t));
    return t;
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return null;
  }
}
