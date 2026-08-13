import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/sales_report.dart';
import 'package:nizan_crm/features/finance/controllers/sales_report_provider.dart';
import 'package:nizan_crm/features/finance/services/sales_report_service.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_chrome.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_search_field.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/show_more_button.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/sort_header.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

/// Column layout + labels for one of the five sales reports.
class SalesReportSpec {
  final String kind;
  final String title;
  final String labelHeader;
  final String countHeader;
  final String amountHeader;
  final bool showReceived;
  final bool timeSeries; // offers a Day/Month toggle
  final String csvName;

  const SalesReportSpec({
    required this.kind,
    required this.title,
    required this.labelHeader,
    required this.countHeader,
    required this.amountHeader,
    this.showReceived = false,
    this.timeSeries = false,
    required this.csvName,
  });
}

const kSalesReportSpecs = <String, SalesReportSpec>{
  kSalesByCustomer: SalesReportSpec(
    kind: kSalesByCustomer,
    title: 'Sales by Customer',
    labelHeader: 'CUSTOMER',
    countHeader: 'BOOKINGS',
    amountHeader: 'SALES',
    showReceived: true,
    csvName: 'sales_by_customer',
  ),
  kSalesByPackage: SalesReportSpec(
    kind: kSalesByPackage,
    title: 'Sales by Package',
    labelHeader: 'PACKAGE',
    countHeader: 'BOOKINGS',
    amountHeader: 'REVENUE',
    csvName: 'sales_by_package',
  ),
  kSalesBySalesperson: SalesReportSpec(
    kind: kSalesBySalesperson,
    title: 'Sales by Sales Person',
    labelHeader: 'SALES PERSON',
    countHeader: 'BOOKINGS',
    amountHeader: 'REVENUE',
    showReceived: true,
    csvName: 'sales_by_salesperson',
  ),
  kSalesSummary: SalesReportSpec(
    kind: kSalesSummary,
    title: 'Sales Summary',
    labelHeader: 'DATE',
    countHeader: 'BOOKINGS',
    amountHeader: 'SALES',
    showReceived: true,
    timeSeries: true,
    csvName: 'sales_summary',
  ),
  kPaymentsByMode: SalesReportSpec(
    kind: kPaymentsByMode,
    title: 'Payments by Mode',
    labelHeader: 'PAYMENT MODE',
    countHeader: 'PAYMENTS',
    amountHeader: 'AMOUNT',
    csvName: 'payments_by_mode',
  ),
};

/// A config-driven sales report (customer / package / salesperson / summary /
/// payment mode) — Zoho-style header + date presets + a grouped table.
class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key, required this.spec});
  final SalesReportSpec spec;

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  DateTime? _from;
  DateTime? _to;
  DateRangePreset _preset = DateRangePreset.allTime;
  String _groupBy = 'day';
  String _search = '';
  String _sortBy = 'amount'; // label | count | amount | received
  bool _asc = false;
  int _visible = kFinancePageSize;
  SalesReport? _last;

  SalesReportSpec get spec => widget.spec;
  String _iso(DateTime? d) => d == null ? '' : DateTime(d.year, d.month, d.day).toIso8601String();

  void _sort(String key) => setState(() {
        if (_sortBy == key) {
          _asc = !_asc;
        } else {
          _sortBy = key;
          _asc = key == 'label'; // text ascending, numbers descending by default
        }
        _visible = kFinancePageSize;
      });

  List<SalesRow> _sorted(List<SalesRow> rows) {
    final list = [...rows];
    int cmp(SalesRow a, SalesRow b) {
      switch (_sortBy) {
        case 'label':
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        case 'count':
          return a.count.compareTo(b.count);
        case 'received':
          return a.received.compareTo(b.received);
        default:
          return a.amount.compareTo(b.amount);
      }
    }

    list.sort((a, b) => _asc ? cmp(a, b) : -cmp(a, b));
    return list;
  }

  ({String kind, String from, String to, String groupBy}) get _key => (
        kind: spec.kind,
        from: _iso(_from),
        to: _iso(_to),
        groupBy: spec.timeSeries ? _groupBy : '',
      );

  Future<void> _applyPreset(DateRangePreset p) async {
    if (p == DateRangePreset.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2015),
        lastDate: DateTime(now.year + 1),
        initialDateRange:
            (_from != null && _to != null) ? DateTimeRange(start: _from!, end: _to!) : null,
      );
      if (picked != null) {
        setState(() {
          _preset = p;
          _from = picked.start;
          _to = picked.end;
          _visible = kFinancePageSize;
        });
      }
      return;
    }
    final r = rangeForPreset(p, DateTime.now());
    setState(() {
      _preset = p;
      _from = r.from;
      _to = r.to;
      _visible = kFinancePageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(salesReportProvider(_key));

    return Scaffold(
      backgroundColor: crm.background,
      body: ReportChrome(
        category: 'Sales',
        title: spec.title,
        preset: _preset,
        from: _from,
        to: _to,
        onPreset: _applyPreset,
        onExport: _last == null ? null : _export,
        onRefresh: () async => ref.invalidate(salesReportProvider(_key)),
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(salesReportProvider(_key)),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('$e', style: TextStyle(color: crm.destructive)))),
            ]),
            data: (rep) {
              _last = rep;
              return _content(crm, rep);
            },
          ),
        ),
      ),
    );
  }

  Widget _content(CrmTheme crm, SalesReport rep) {
    final q = _search.trim().toLowerCase();
    final filtered = q.isEmpty
        ? rep.rows
        : rep.rows.where((r) => '${r.label} ${r.sublabel}'.toLowerCase().contains(q)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        ReportTitleBlock(title: spec.title, from: _from, to: _to),
        if (spec.timeSeries) _groupToggle(crm),
        if (!spec.timeSeries) ...[
          ReportSearchField(
            hint: 'Search ${spec.labelHeader.toLowerCase()}…',
            onChanged: (v) => setState(() {
              _search = v;
              _visible = kFinancePageSize;
            }),
          ),
          12.h,
        ],
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
                child: Text(rep.rows.isEmpty ? 'No sales in this period' : 'No matches',
                    style: TextStyle(color: crm.textSecondary))),
          )
        else
          _table(crm, _sorted(filtered)),
      ],
    );
  }

  Widget _groupToggle(CrmTheme crm) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Text('Group by', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
          10.w,
          ChoiceChip(
            label: const Text('Day'),
            selected: _groupBy == 'day',
            onSelected: (_) => setState(() {
              _groupBy = 'day';
              _visible = kFinancePageSize;
            }),
          ),
          8.w,
          ChoiceChip(
            label: const Text('Month'),
            selected: _groupBy == 'month',
            onSelected: (_) => setState(() {
              _groupBy = 'month';
              _visible = kFinancePageSize;
            }),
          ),
        ]),
      );

  Widget _table(CrmTheme crm, List<SalesRow> all) {
    final rows = all.take(_visible).toList();
    final totalCount = all.fold<int>(0, (a, r) => a + r.count);
    final totalAmount = all.fold<double>(0, (a, r) => a + r.amount);
    final totalReceived = all.fold<double>(0, (a, r) => a + r.received);
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      ),
      child: Column(children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: crm.background.withValues(alpha: 0.4), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Expanded(flex: 5, child: SortHeader(label: spec.labelHeader, active: _sortBy == 'label', ascending: _asc, onTap: () => _sort('label'))),
            Expanded(flex: 2, child: SortHeader(label: spec.countHeader, active: _sortBy == 'count', ascending: _asc, alignEnd: true, onTap: () => _sort('count'))),
            Expanded(flex: 3, child: SortHeader(label: spec.amountHeader, active: _sortBy == 'amount', ascending: _asc, alignEnd: true, onTap: () => _sort('amount'))),
            if (spec.showReceived) Expanded(flex: 3, child: SortHeader(label: 'RECEIVED', active: _sortBy == 'received', ascending: _asc, alignEnd: true, onTap: () => _sort('received'))),
          ]),
        ),
        for (final r in rows) _row(crm, r),
        ShowMoreButton(
          remaining: all.length - _visible,
          onPressed: () => setState(() => _visible += kFinancePageSize),
        ),
        // totals
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: crm.background.withValues(alpha: 0.4),
            border: Border(top: BorderSide(color: crm.border)),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Row(children: [
            Expanded(flex: 5, child: Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: crm.textPrimary))),
            Expanded(flex: 2, child: Text('$totalCount', textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            Expanded(flex: 3, child: Text(_money(totalAmount), textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: crm.textPrimary))),
            if (spec.showReceived) Expanded(flex: 3, child: Text(_money(totalReceived), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0D9488)))),
          ]),
        ),
      ]),
    );
  }

  Widget _row(CrmTheme crm, SalesRow r) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border.withValues(alpha: 0.4)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (r.sublabel.isNotEmpty)
                Text(r.sublabel, style: TextStyle(fontSize: 11, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Expanded(flex: 2, child: Text('${r.count}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: crm.textPrimary))),
          Expanded(flex: 3, child: Text(_money(r.amount), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary))),
          if (spec.showReceived)
            Expanded(flex: 3, child: Text(_money(r.received), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: Color(0xFF0D9488)))),
        ]),
      );

  Future<void> _export() async {
    final rep = _last;
    if (rep == null) return;
    final header = <Object?>[spec.labelHeader, 'Detail', spec.countHeader, spec.amountHeader];
    if (spec.showReceived) header.add('Received');
    final rows = <List<Object?>>[
      [spec.title],
      header,
      for (final r in rep.rows)
        [
          r.label,
          r.sublabel,
          r.count,
          csvNum(r.amount),
          if (spec.showReceived) csvNum(r.received),
        ],
      [
        'TOTAL',
        '',
        rep.totalCount,
        csvNum(rep.totalAmount),
        if (spec.showReceived) csvNum(rep.totalReceived),
      ],
    ];
    try {
      await downloadCsv('${spec.csvName}.csv', rows);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${spec.title} exported')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}
