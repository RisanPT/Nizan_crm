import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_chrome.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';

String _money(num v) => NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 2)
    .format(v);

/// Finance → TDS Summary. Tax Deducted at Source on vendor / payee payments,
/// grouped by section, for a period. Reads any TDS recorded on admin expenses
/// (via the `[TDS …]` note tag); shows a clear empty state until TDS is
/// captured, so the return can be reconciled once it is.
class TdsSummaryScreen extends ConsumerStatefulWidget {
  const TdsSummaryScreen({super.key});

  @override
  ConsumerState<TdsSummaryScreen> createState() => _TdsSummaryScreenState();
}

class _TdsSummaryScreenState extends ConsumerState<TdsSummaryScreen> {
  DateTime? _from;
  DateTime? _to;
  DateRangePreset _preset = DateRangePreset.thisMonth;

  @override
  void initState() {
    super.initState();
    final r = rangeForPreset(_preset, DateTime.now());
    _from = r.from;
    _to = r.to;
  }

  bool _inRange(DateTime d) {
    if (_from != null && d.isBefore(_from!)) return false;
    if (_to != null &&
        d.isAfter(DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59))) {
      return false;
    }
    return true;
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

  // TDS recorded as a note tag like "[TDS 194C 10% 1500]" or "[TDS 1500]".
  ({String section, double amount})? _tdsOf(AdminExpense e) {
    final m = RegExp(r'\[TDS(?:\s+([0-9A-Za-z]+))?[^\]]*?([\d.]+)\s*\]')
        .firstMatch(e.notes);
    if (m == null) return null;
    final amt = double.tryParse(m.group(2) ?? '') ?? 0;
    if (amt <= 0) return null;
    return (section: (m.group(1) ?? 'Other').toUpperCase(), amount: amt);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(adminExpensesProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: ReportChrome(
        category: 'Taxes',
        title: 'TDS Summary',
        preset: _preset,
        from: _from,
        to: _to,
        onPreset: _applyPreset,
        onExport: async.hasValue ? () => _exportCsv(context, async.value!) : null,
        onRefresh: () async => ref.invalidate(adminExpensesProvider),
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminExpensesProvider),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                    child: Text(friendlyErrorMessage(e),
                        style: TextStyle(color: crm.destructive))),
              ),
            ]),
            data: (all) => _body(crm, all),
          ),
        ),
      ),
    );
  }

  Widget _body(CrmTheme crm, List<AdminExpense> all) {
    // Gather any recorded TDS in the period, grouped by section.
    final bySection = <String, ({double amount, int count})>{};
    for (final e in all) {
      // Approved-only — TDS is recognised when the expense is booked/paid.
      if (e.status != 'approved' || !_inRange(e.date)) continue;
      final t = _tdsOf(e);
      if (t == null) continue;
      final cur = bySection[t.section] ?? (amount: 0.0, count: 0);
      bySection[t.section] =
          (amount: cur.amount + t.amount, count: cur.count + 1);
    }
    final rows = bySection.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));
    final total = rows.fold<double>(0, (s, r) => s + r.value.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      children: [
        ReportTitleBlock(
            title: 'TDS Summary', asOf: false, from: _from, to: _to),
        12.h,
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: crm.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: crm.primary.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(Icons.receipt_long_rounded, size: 28, color: crm.primary),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total TDS deducted this period',
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                const SizedBox(height: 2),
                Text(_money(total),
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: crm.primary)),
              ],
            ),
          ]),
        ),
        18.h,
        if (rows.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: crm.border),
            ),
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
            child: Column(children: [
              Icon(Icons.info_outline_rounded, size: 40, color: crm.textSecondary),
              10.h,
              Text('No TDS recorded in this period',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: crm.textPrimary)),
              6.h,
              Text(
                'Record TDS on a payment by adding a note tag like '
                '"[TDS 194C 1500]" to the expense, and it will appear here '
                'grouped by section.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
              ),
            ]),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: crm.border),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(children: [
                  Expanded(
                      flex: 5,
                      child: Text('SECTION',
                          style: _hdr(crm))),
                  Expanded(
                      flex: 2,
                      child: Text('COUNT',
                          textAlign: TextAlign.right, style: _hdr(crm))),
                  Expanded(
                      flex: 3,
                      child: Text('TDS',
                          textAlign: TextAlign.right, style: _hdr(crm))),
                ]),
              ),
              Divider(height: 1, color: crm.border),
              for (final r in rows)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(children: [
                    Expanded(
                        flex: 5,
                        child: Text('Section ${r.key}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: crm.textPrimary))),
                    Expanded(
                        flex: 2,
                        child: Text('${r.value.count}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 12.5, color: crm.textSecondary))),
                    Expanded(
                        flex: 3,
                        child: Text(_money(r.value.amount),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700))),
                  ]),
                ),
              Divider(height: 1, color: crm.border),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(children: [
                  Expanded(
                      child: Text('TOTAL',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary))),
                  Text(_money(total),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: crm.primary)),
                ]),
              ),
            ]),
          ),
      ],
    );
  }

  TextStyle _hdr(CrmTheme crm) => TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: crm.textSecondary,
      letterSpacing: 0.4);

  Future<void> _exportCsv(BuildContext context, List<AdminExpense> all) async {
    final rows = <List<Object?>>[
      ['TDS Summary'],
      ['Date', 'Vendor', 'Section', 'TDS amount'],
      for (final e in all)
        if (e.status == 'approved' && _inRange(e.date))
          if (_tdsOf(e) case final t?)
            [
              DateFormat('yyyy-MM-dd').format(e.date),
              e.vendor,
              t.section,
              csvNum(t.amount),
            ],
    ];
    try {
      await downloadCsv('tds_summary.csv', rows);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('TDS summary exported')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }
}
