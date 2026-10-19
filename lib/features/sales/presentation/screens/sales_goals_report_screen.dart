import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/branded_pdf.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/features/sales/data/goal_report.dart';
import 'package:nizan_crm/features/sales/presentation/widgets/goal_period_nav.dart';
import 'package:nizan_crm/features/sales/services/goal_service.dart';

const _green = Color(0xFF16A34A);
const _amber = Color(0xFFD97706);
const _red = Color(0xFFDC2626);
const _grey = Color(0xFF6B7280);

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _count = NumberFormat.decimalPattern('en_IN');

String _fmt(String key, double v) => key == 'revenue' ? _money.format(v) : _count.format(v.round());
// The built-in PDF fonts have no rupee glyph.
String _fmtPdf(String key, double v) => key == 'revenue' ? 'Rs ${_count.format(v.round())}' : _count.format(v.round());

Color _pctColor(double? pct) {
  if (pct == null) return _grey;
  if (pct >= 100) return _green;
  if (pct >= 70) return _amber;
  return _red;
}

Color _statusColor(String status) => switch (status) {
      'on_track' => _green,
      'slightly_behind' => _amber,
      'behind' => _red,
      _ => _grey,
    };

String _statusText(String status) => switch (status) {
      'on_track' => 'On track',
      'slightly_behind' => 'Slightly behind',
      'behind' => 'Behind',
      _ => 'No goal set',
    };

/// Sales → Report & Goals. Day / week / month figures set against the goals,
/// month-to-date progress, and print / PDF export of whatever is on screen.
class SalesGoalsReportScreen extends ConsumerStatefulWidget {
  const SalesGoalsReportScreen({super.key});

  @override
  ConsumerState<SalesGoalsReportScreen> createState() => _SalesGoalsReportScreenState();
}

class _SalesGoalsReportScreenState extends ConsumerState<SalesGoalsReportScreen> {
  String _type = 'day';
  DateTime _date = dateOnly(DateTime.now());
  String _basis = 'added';

  GoalQuery get _q => (granularity: _type, date: ymd(_date), basis: _basis);

  String get _basisText => _basis == 'event' ? 'counted by event / trial date' : 'counted by the date added';

  Future<Uint8List> _pdf(GoalReport rep, MtdReport? mtd) async {
    final period = periodLabel(rep.granularity, parseYmd(rep.start));
    final sections = <PdfSection>[
      PdfSection('Target vs actual', ['Metric', 'Actual', 'Target', '% of target'], [
        for (final m in rep.metrics)
          [
            m.label,
            _fmtPdf(m.key, m.actual),
            m.target == null ? '-' : _fmtPdf(m.key, m.target!),
            m.pct == null ? '-' : '${m.pct!.toStringAsFixed(0)}%',
          ],
      ]),
      if (mtd != null)
        PdfSection(
          'Month to date - ${DateFormat('MMMM yyyy').format(parseYmd('${mtd.month}-01'))} (day ${mtd.dayOfMonth} of ${mtd.daysInMonth})',
          ['Metric', 'Achieved', 'Month goal', 'Pro-rated goal', 'Ratio'],
          [
            for (final m in mtd.metrics)
              [
                m.label,
                _fmtPdf(m.key, m.achieved),
                m.goal > 0 ? _fmtPdf(m.key, m.goal) : '-',
                m.goal > 0 ? _fmtPdf(m.key, m.proRatedGoal) : '-',
                m.ratioPct == null ? '-' : '${m.ratioPct!.toStringAsFixed(0)}% (${_statusText(m.status)})',
              ],
          ],
        ),
      if (rep.granularity != 'day')
        PdfSection('Day by day', ['Day', for (final k in kGoalMetrics) kGoalMetricLabels[k]!], [
          for (final d in rep.days)
            [
              DateFormat('EEE d MMM').format(parseYmd(d.day)),
              for (final k in kGoalMetrics)
                d.targets[k] == null
                    ? _fmtPdf(k, d.values[k] ?? 0)
                    : '${_fmtPdf(k, d.values[k] ?? 0)} / ${_fmtPdf(k, d.targets[k]!)}',
            ],
          [
            'Total',
            for (final m in rep.metrics) _fmtPdf(m.key, m.actual),
          ],
        ]),
    ];
    return buildBrandedReportBytes(
      title: 'Sales Report - ${rep.granularity == 'day' ? 'Day' : rep.granularity == 'week' ? 'Week' : 'Month'}',
      subtitle: '$period  |  $_basisText  |  Team N Makeovers',
      sections: sections,
    );
  }

  Future<void> _export(GoalReport rep, MtdReport? mtd, {required bool print}) async {
    try {
      final bytes = await _pdf(rep, mtd);
      final name = 'sales_report_${rep.granularity}_${rep.start}.pdf';
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      } else {
        await saveFileBytes(name, bytes, mime: 'application/pdf');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final role = ref.watch(authSessionProvider)?.role;
    final report = ref.watch(goalReportProvider(_q));
    final mtd = ref.watch(mtdReportProvider(_q));
    final rep = report.value;

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(goalReportProvider(_q));
          ref.invalidate(mtdReportProvider(_q));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Sales Report & Goals',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                if (canSetGoals(role))
                  OutlinedButton.icon(
                    onPressed: () => context.go('/sales/goals'),
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: const Text('Set goals'),
                  ),
                OutlinedButton.icon(
                  onPressed: rep == null ? null : () => _export(rep, mtd.value, print: true),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print'),
                ),
                OutlinedButton.icon(
                  onPressed: rep == null ? null : () => _export(rep, mtd.value, print: false),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Download PDF'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GoalPeriodNav(
              type: _type,
              date: _date,
              basis: _basis,
              onType: (t) => setState(() => _type = t),
              onDate: (d) => setState(() => _date = d),
              onBasis: (b) => setState(() => _basis = b),
            ),
            const SizedBox(height: 16),
            report.when(
              loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(goalReportProvider(_q))),
              data: (r) => _body(crm, r),
            ),
            const SizedBox(height: 16),
            mtd.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(mtdReportProvider(_q))),
              data: (m) => _mtdCard(crm, m),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(CrmTheme crm, GoalReport r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(periodLabel(r.granularity, parseYmd(r.start)),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textSecondary)),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 12, children: [for (final m in r.metrics) _metricCard(crm, m)]),
      if (r.granularity != 'day') ...[
        const SizedBox(height: 16),
        _dailyTable(crm, r),
      ],
    ]);
  }

  Widget _metricCard(CrmTheme crm, GoalMetric m) {
    final color = _pctColor(m.pct);
    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
        const SizedBox(height: 4),
        Text(_fmt(m.key, m.actual),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        const SizedBox(height: 6),
        Text(m.target == null ? 'No target set' : 'Target ${_fmt(m.key, m.target!)}',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ((m.pct ?? 0) / 100).clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text(m.pct == null ? '—' : '${m.pct!.toStringAsFixed(0)}% of target',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _dailyTable(CrmTheme crm, GoalReport r) {
    Widget cell(String key, double v, double? t) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_fmt(key, v), style: const TextStyle(fontWeight: FontWeight.w600)),
            if (t != null) Text('of ${_fmt(key, t)}', style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          ],
        );
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Day')),
            for (final k in kGoalMetrics) DataColumn(label: Text(kGoalMetricLabels[k]!), numeric: true),
          ],
          rows: [
            for (final d in r.days)
              DataRow(cells: [
                DataCell(Text(DateFormat('EEE d MMM').format(parseYmd(d.day)))),
                for (final k in kGoalMetrics) DataCell(cell(k, d.values[k] ?? 0, d.targets[k])),
              ]),
            DataRow(cells: [
              const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.w800))),
              for (final m in r.metrics)
                DataCell(cell(m.key, m.actual, m.target)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _mtdCard(CrmTheme crm, MtdReport m) {
    final monthName = DateFormat('MMMM yyyy').format(parseYmd('${m.month}-01'));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Month to date · $monthName (day ${m.dayOfMonth} of ${m.daysInMonth})',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          ),
          Tooltip(
            message: m.method,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 6),
            child: Icon(Icons.info_outline_rounded, size: 18, color: crm.textSecondary),
          ),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Metric')),
              DataColumn(label: Text('Achieved'), numeric: true),
              DataColumn(label: Text('Month goal'), numeric: true),
              DataColumn(label: Text('Pro-rated goal'), numeric: true),
              DataColumn(label: Text('Ratio')),
            ],
            rows: [
              for (final x in m.metrics)
                DataRow(cells: [
                  DataCell(Text(x.label)),
                  DataCell(Text(_fmt(x.key, x.achieved))),
                  DataCell(Text(x.goal > 0 ? _fmt(x.key, x.goal) : '—')),
                  DataCell(Text(x.goal > 0 ? _fmt(x.key, x.proRatedGoal) : '—')),
                  DataCell(_ratio(x)),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(m.method, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
      ]),
    );
  }

  Widget _ratio(MtdMetric x) {
    final color = _statusColor(x.status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 90,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ((x.ratioPct ?? 0) / 100).clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(x.ratioPct == null ? _statusText(x.status) : '${x.ratioPct!.toStringAsFixed(0)}% · ${_statusText(x.status)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}
