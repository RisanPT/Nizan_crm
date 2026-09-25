import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/data/gst_models.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_chrome.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';

String _money(num v) => NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 2)
    .format(v);

/// Finance → GSTR-3B Summary. The monthly self-assessed GST return in its
/// standard sections — 3.1 outward supplies, 4 eligible ITC, and the net tax
/// payable — computed from the same output/input data as the GST report.
class Gstr3bSummaryScreen extends ConsumerStatefulWidget {
  const Gstr3bSummaryScreen({super.key});

  @override
  ConsumerState<Gstr3bSummaryScreen> createState() =>
      _Gstr3bSummaryScreenState();
}

class _Gstr3bSummaryScreenState extends ConsumerState<Gstr3bSummaryScreen> {
  DateTime? _from;
  DateTime? _to;
  DateRangePreset _preset = DateRangePreset.thisMonth;

  String _iso(DateTime? d) =>
      d == null ? '' : DateTime(d.year, d.month, d.day).toIso8601String();
  ({String from, String to}) get _range => (from: _iso(_from), to: _iso(_to));

  ({GstSummary s, double taxable})? _last;

  @override
  void initState() {
    super.initState();
    final r = rangeForPreset(_preset, DateTime.now());
    _from = r.from;
    _to = r.to;
  }

  Future<void> _applyPreset(DateRangePreset p) async {
    if (p == DateRangePreset.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2015),
        lastDate: DateTime(now.year + 1),
        initialDateRange: _from != null && _to != null
            ? DateTimeRange(start: _from!, end: _to!)
            : null,
      );
      if (picked != null) {
        setState(() {
          _preset = p;
          _from = picked.start;
          _to = picked.end;
        });
      }
      return;
    }
    final r = rangeForPreset(p, DateTime.now());
    setState(() {
      _preset = p;
      _from = r.from;
      _to = r.to;
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final summaryAsync = ref.watch(gstSummaryProvider(_range));
    final gstr1Async = ref.watch(gstr1Provider(_range));

    void refresh() {
      ref.invalidate(gstSummaryProvider);
      ref.invalidate(gstr1Provider);
    }

    return Scaffold(
      backgroundColor: crm.background,
      body: ReportChrome(
        category: 'Taxes',
        title: 'GSTR-3B Summary',
        preset: _preset,
        from: _from,
        to: _to,
        onPreset: _applyPreset,
        onExport: _last == null ? null : () => _exportCsv(context),
        onRefresh: () async => refresh(),
        child: RefreshIndicator(
          onRefresh: () async => refresh(),
          child: (summaryAsync.isLoading || gstr1Async.isLoading)
              ? const Center(child: CircularProgressIndicator())
              : (summaryAsync.hasError || gstr1Async.hasError)
                  ? ListView(children: [
                      AppErrorView(
                          error: summaryAsync.error ?? gstr1Async.error,
                          onRetry: refresh),
                    ])
                  : _body(crm, summaryAsync.value!,
                      gstr1Async.value?.rows ?? const []),
        ),
      ),
    );
  }

  Widget _body(CrmTheme crm, GstSummary s, List<Gstr1Row> rows) {
    final taxable = rows.fold<double>(0, (a, r) => a + r.taxable);
    _last = (s: s, taxable: taxable);
    final netPayable = s.totalOutput - s.inputCredit;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      children: [
        ReportTitleBlock(
            title: 'GSTR-3B Summary', asOf: false, from: _from, to: _to),
        12.h,
        // Net payable hero
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: (netPayable >= 0 ? crm.destructive : crm.success)
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: (netPayable >= 0 ? crm.destructive : crm.success)
                    .withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(Icons.account_balance_rounded,
                size: 28,
                color: netPayable >= 0 ? crm.destructive : crm.success),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(netPayable >= 0 ? 'Net GST payable' : 'Net GST credit',
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                const SizedBox(height: 2),
                Text(_money(netPayable.abs()),
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color:
                            netPayable >= 0 ? crm.destructive : crm.success)),
              ],
            ),
          ]),
        ),
        18.h,

        // 3.1 Outward supplies
        _sectionCard(crm, '3.1  Details of Outward Supplies', [
          _amtRow(crm, '(a) Outward taxable supplies (other than zero-rated, nil-rated, exempted)',
              taxable,
              highlight: true),
          _taxRow(crm, 'Integrated tax (IGST)', s.outputIgst),
          _taxRow(crm, 'Central tax (CGST)', s.outputCgst),
          _taxRow(crm, 'State tax (SGST)', s.outputSgst),
          _taxRow(crm, 'Total output tax', s.totalOutput, bold: true),
        ]),
        14.h,

        // 4 Eligible ITC
        _sectionCard(crm, '4  Eligible ITC', [
          _taxRow(crm, '(A) ITC available (all other ITC)', s.inputCredit),
          _taxRow(crm, '(C) Net ITC available', s.inputCredit, bold: true),
        ]),
        14.h,

        // 5.1 Tax payable
        _sectionCard(crm, '5.1  Tax payable', [
          _taxRow(crm, 'Output tax', s.totalOutput),
          _taxRow(crm, 'Less: input tax credit', -s.inputCredit),
          _taxRow(crm, 'Net tax payable', netPayable, bold: true),
        ]),
      ],
    );
  }

  Widget _sectionCard(CrmTheme crm, String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
            child: Text(title,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: crm.primary)),
          ),
          Divider(height: 1, color: crm.border),
          ...rows,
        ],
      ),
    );
  }

  Widget _amtRow(CrmTheme crm, String label, double v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: crm.textPrimary,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w400))),
        Text(_money(v),
            style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: crm.textPrimary)),
      ]),
    );
  }

  Widget _taxRow(CrmTheme crm, String label, double v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: crm.textSecondary,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
        Text(_money(v),
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: v < 0 ? crm.success : crm.textPrimary)),
      ]),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final d = _last;
    if (d == null) return;
    final s = d.s;
    final net = s.totalOutput - s.inputCredit;
    final rows = <List<Object?>>[
      ['GSTR-3B Summary'],
      ['Section', 'Description', 'Amount'],
      ['3.1(a)', 'Outward taxable value', csvNum(d.taxable)],
      ['3.1', 'IGST', csvNum(s.outputIgst)],
      ['3.1', 'CGST', csvNum(s.outputCgst)],
      ['3.1', 'SGST', csvNum(s.outputSgst)],
      ['3.1', 'Total output tax', csvNum(s.totalOutput)],
      ['4', 'Net ITC available', csvNum(s.inputCredit)],
      ['5.1', 'Net tax payable', csvNum(net)],
    ];
    try {
      await downloadCsv('gstr3b_summary.csv', rows);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GSTR-3B summary exported')));
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, e);
      }
    }
  }
}
