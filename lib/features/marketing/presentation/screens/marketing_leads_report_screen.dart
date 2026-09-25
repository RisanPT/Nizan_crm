import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/features/marketing/utils/leads_report_export.dart';

/// Marketing Leads Report — a day / week / month view of lead performance
/// (received, converted, lost, follow-ups) with source & status breakdowns, a
/// trend chart and a like-for-like previous-period comparison.
class MarketingLeadsReportScreen extends ConsumerStatefulWidget {
  const MarketingLeadsReportScreen({super.key});

  @override
  ConsumerState<MarketingLeadsReportScreen> createState() =>
      _MarketingLeadsReportScreenState();
}

class _MarketingLeadsReportScreenState
    extends ConsumerState<MarketingLeadsReportScreen> {
  String _period = 'day'; // day | week | month
  DateTime _anchor = DateTime.now();

  String get _dateKey =>
      '${_anchor.year}-${_two(_anchor.month)}-${_two(_anchor.day)}';
  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(leadReportProvider((period: _period, date: _dateKey)));
    final report = async.asData?.value;

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(leadReportProvider((period: _period, date: _dateKey))),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 18, isMobile ? 14 : 24, 40),
          children: [
            Text('Leads Report',
                style: TextStyle(
                    fontSize: isMobile ? 22 : 27,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary)),
            Text('End-of-day, weekly and monthly lead performance',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            14.gap,
            Row(children: [
              Flexible(child: _periodToggle(crm)),
              const Spacer(),
              _downloadMenu(crm, report),
            ]),
            10.gap,
            _dateNavigator(crm),
            16.gap,
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: AppErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(leadReportProvider((period: _period, date: _dateKey))),
                ),
              ),
              data: (r) => _report(crm, isMobile, r),
            ),
          ],
        ),
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────
  Widget _periodToggle(CrmTheme crm) {
    Widget seg(String value, String label) {
      final active = _period == value;
      return GestureDetector(
        onTap: () => setState(() => _period = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: active ? crm.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : crm.textSecondary)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: crm.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('day', 'Day'),
        seg('week', 'Week'),
        seg('month', 'Month'),
      ]),
    );
  }

  Widget _downloadMenu(CrmTheme crm, LeadsReport? report) {
    final enabled = report != null;
    return PopupMenuButton<String>(
      enabled: enabled,
      onSelected: (v) => _download(v, report!),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'pdf', child: Row(children: [
          Icon(Icons.picture_as_pdf_outlined, size: 18), SizedBox(width: 8), Text('Download PDF'),
        ])),
        PopupMenuItem(value: 'csv', child: Row(children: [
          Icon(Icons.grid_on_outlined, size: 18), SizedBox(width: 8), Text('Download CSV'),
        ])),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? crm.primary : crm.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: enabled ? crm.primary : crm.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.download_outlined, size: 16, color: enabled ? Colors.white : crm.textSecondary),
          const SizedBox(width: 6),
          Text('Download',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : crm.textSecondary)),
          Icon(Icons.arrow_drop_down, size: 18, color: enabled ? Colors.white : crm.textSecondary),
        ]),
      ),
    );
  }

  Future<void> _download(String fmt, LeadsReport r) async {
    final base = 'leads-report-$_period-$_dateKey';
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (fmt == 'pdf') {
        await exportLeadsReportPdf(r, periodLabel: _periodLabel(), fileBase: base);
      } else {
        await exportLeadsReportCsv(r, periodLabel: _periodLabel(), fileBase: base);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Widget _dateNavigator(CrmTheme crm) {
    return Row(children: [
      _navBtn(crm, Icons.chevron_left, () => _step(-1)),
      8.wgap,
      Expanded(
        child: Text(_periodLabel(),
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
      ),
      if (!_isCurrentPeriod())
        TextButton.icon(
          onPressed: () => setState(() => _anchor = DateTime.now()),
          icon: const Icon(Icons.today_outlined, size: 16),
          label: const Text('Today'),
          style: TextButton.styleFrom(
              foregroundColor: crm.primary, visualDensity: VisualDensity.compact),
        ),
      _navBtn(crm, Icons.chevron_right, () => _step(1)),
    ]);
  }

  Widget _navBtn(CrmTheme crm, IconData icon, VoidCallback onTap) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: crm.textPrimary),
        style: IconButton.styleFrom(
          backgroundColor: crm.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: crm.border)),
        ),
      );

  void _step(int dir) {
    setState(() {
      if (_period == 'day') {
        _anchor = _anchor.add(Duration(days: dir));
      } else if (_period == 'week') {
        _anchor = _anchor.add(Duration(days: 7 * dir));
      } else {
        _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
      }
    });
  }

  DateTime get _mondayOf {
    final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
    return d.subtract(Duration(days: (d.weekday - 1)));
  }

  String _periodLabel() {
    if (_period == 'day') return DateFormat('EEE, d MMM yyyy').format(_anchor);
    if (_period == 'month') return DateFormat('MMMM yyyy').format(_anchor);
    final mon = _mondayOf;
    final sun = mon.add(const Duration(days: 6));
    final sameMonth = mon.month == sun.month;
    return sameMonth
        ? '${mon.day}–${sun.day} ${DateFormat('MMM yyyy').format(mon)}'
        : '${DateFormat('d MMM').format(mon)} – ${DateFormat('d MMM yyyy').format(sun)}';
  }

  bool _isCurrentPeriod() {
    final now = DateTime.now();
    if (_period == 'day') {
      return _anchor.year == now.year && _anchor.month == now.month && _anchor.day == now.day;
    }
    if (_period == 'month') {
      return _anchor.year == now.year && _anchor.month == now.month;
    }
    final a = _mondayOf;
    final b = now.subtract(Duration(days: now.weekday - 1));
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ── Report body ─────────────────────────────────────────────────────────
  Widget _report(CrmTheme crm, bool isMobile, LeadsReport r) {
    final unit = _period == 'day' ? 'yesterday' : (_period == 'week' ? 'last week' : 'last month');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // KPI grid
      LayoutBuilder(builder: (ctx, c) {
        final cols = c.maxWidth >= 900 ? 5 : (c.maxWidth >= 560 ? 3 : 2);
        const gap = 10.0;
        final w = (c.maxWidth - (cols - 1) * gap) / cols;
        final tiles = <Widget>[
          _kpi(crm, w, 'Leads', '${r.total}', Icons.person_add_alt_1_outlined,
              crm.primary, delta: _delta(r.total, r.prevTotal), sub: 'vs $unit'),
          _kpi(crm, w, 'Converted', '${r.converted}', Icons.verified_outlined,
              const Color(0xFF2E8B57),
              delta: _delta(r.converted, r.prevConverted), sub: '${r.conversionRate}% rate'),
          _kpi(crm, w, 'Lost', '${r.lost}', Icons.cancel_outlined,
              const Color(0xFFDC2626)),
          _kpi(crm, w, 'Follow-ups due', '${r.followUpsDue}', Icons.schedule_outlined,
              const Color(0xFFB45309)),
          _kpi(crm, w, 'Overdue', '${r.followUpsOverdue}', Icons.warning_amber_outlined,
              const Color(0xFFDC2626), sub: 'all open'),
        ];
        return Wrap(spacing: gap, runSpacing: gap, children: tiles);
      }),
      16.gap,
      if (r.series.length > 1) ...[
        _card(crm, 'Trend', _trend(crm, r)),
        14.gap,
      ],
      if (isMobile) ...[
        _card(crm, 'By source', _sourceBars(crm, r.bySource)),
        14.gap,
        _card(crm, 'By status', _statusDonut(crm, r.byStatus)),
      ] else
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _card(crm, 'By source', _sourceBars(crm, r.bySource))),
            12.wgap,
            Expanded(child: _card(crm, 'By status', _statusDonut(crm, r.byStatus))),
          ]),
        ),
      14.gap,
      if (isMobile) ...[
        _card(crm, 'By added-by', _sourceBars(crm, r.byAddedBy)),
        14.gap,
        _card(crm, 'By assignee', _sourceBars(crm, r.byAssignee)),
      ] else
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _card(crm, 'By added-by', _sourceBars(crm, r.byAddedBy))),
            12.wgap,
            Expanded(child: _card(crm, 'By assignee', _sourceBars(crm, r.byAssignee))),
          ]),
        ),
      14.gap,
      _card(crm, 'By priority', _priorityChips(crm, r.byPriority)),
    ]);
  }

  double? _delta(int cur, int prev) {
    if (prev == 0) return cur == 0 ? null : 100.0;
    return ((cur - prev) / prev) * 100.0;
  }

  Widget _kpi(CrmTheme crm, double w, String label, String value, IconData icon,
      Color color, {double? delta, String? sub}) {
    return SizedBox(
      width: w,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 15, color: color),
            const Spacer(),
            if (delta != null) _deltaChip(delta),
          ]),
          6.gap,
          Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: crm.textPrimary)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
          if (sub != null)
            Text(sub, style: TextStyle(fontSize: 10, color: crm.textSecondary)),
        ]),
      ),
    );
  }

  Widget _deltaChip(double pct) {
    final up = pct >= 0;
    final color = pct == 0
        ? const Color(0xFF6B7280)
        : (up ? const Color(0xFF16A34A) : const Color(0xFFDC2626));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
      child: Text('${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _trend(CrmTheme crm, LeadsReport r) {
    final pts = r.series;
    double maxY = 1;
    for (final p in pts) {
      if (p.count > maxY) maxY = p.count.toDouble();
    }
    final showEvery = (pts.length / 8).ceil().clamp(1, 999);
    return SizedBox(
      height: 180,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => crm.textPrimary,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${pts[group.x].date}\n${rod.toY.toInt()} leads',
              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: crm.border, strokeWidth: 0.6),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style: TextStyle(fontSize: 9, color: crm.textSecondary)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= pts.length || i % showEvery != 0) {
                  return const SizedBox.shrink();
                }
                final d = DateTime.tryParse(pts[i].date);
                final label = d == null
                    ? pts[i].date
                    : (_period == 'week' ? DateFormat('E').format(d) : '${d.day}');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label, style: TextStyle(fontSize: 9, color: crm.textSecondary)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < pts.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: pts[i].count.toDouble(),
                width: pts.length > 20 ? 5 : 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                color: crm.primary,
              ),
            ]),
        ],
      )),
    );
  }

  Widget _sourceBars(CrmTheme crm, List<LeadReportBucket> rows) {
    if (rows.isEmpty) return _empty(crm);
    final max = rows.map((e) => e.count).reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    return Column(children: [
      for (final b in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(width: 78, child: Text(b.key, style: TextStyle(fontSize: 12, color: crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: b.count / max,
                  minHeight: 14,
                  backgroundColor: crm.background,
                  valueColor: AlwaysStoppedAnimation(crm.primary),
                ),
              ),
            ),
            8.wgap,
            SizedBox(width: 28, child: Text('${b.count}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textPrimary))),
          ]),
        ),
    ]);
  }

  Widget _statusDonut(CrmTheme crm, List<LeadReportBucket> rows) {
    if (rows.isEmpty) return _empty(crm);
    final total = rows.fold<int>(0, (s, b) => s + b.count);
    return Row(children: [
      SizedBox(
        width: 120,
        height: 120,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 34,
          sections: [
            for (final b in rows)
              PieChartSectionData(
                value: b.count.toDouble(),
                color: _statusColor(crm, b.key),
                radius: 22,
                showTitle: false,
              ),
          ],
        )),
      ),
      16.wgap,
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final b in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: _statusColor(crm, b.key), shape: BoxShape.circle)),
                6.wgap,
                Expanded(child: Text(b.key, style: TextStyle(fontSize: 12, color: crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('${b.count}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                4.wgap,
                Text(total == 0 ? '' : '${((b.count / total) * 100).round()}%',
                    style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
              ]),
            ),
        ]),
      ),
    ]);
  }

  Widget _priorityChips(CrmTheme crm, List<LeadReportBucket> rows) {
    if (rows.isEmpty) return _empty(crm);
    Color c(String k) => switch (k) {
          'Hot' => const Color(0xFFDC2626),
          'Warm' => const Color(0xFFB45309),
          'Cold' => const Color(0xFF2563EB),
          _ => crm.textSecondary,
        };
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final b in rows)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c(b.key).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c(b.key).withValues(alpha: 0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 9, color: c(b.key)),
            6.wgap,
            Text(b.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            6.wgap,
            Text('${b.count}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c(b.key))),
          ]),
        ),
    ]);
  }

  Color _statusColor(CrmTheme crm, String status) => switch (status) {
        'New' => const Color(0xFF2563EB),
        'Contacted' => const Color(0xFF7C3AED),
        'Qualified' => const Color(0xFF0891B2),
        'Follow-up' => const Color(0xFFB45309),
        'Converted' => const Color(0xFF2E8B57),
        'Lost' => const Color(0xFFDC2626),
        _ => crm.textSecondary,
      };

  Widget _empty(CrmTheme crm) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: Text('No leads in this period.', style: TextStyle(color: crm.textSecondary))),
      );

  Widget _card(CrmTheme crm, String title, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
          14.gap,
          child,
        ]),
      );
}

extension _Gap on num {
  Widget get gap => SizedBox(height: toDouble());
  Widget get wgap => SizedBox(width: toDouble());
}
