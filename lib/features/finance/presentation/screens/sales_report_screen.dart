import 'package:flutter/material.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
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
import 'package:nizan_crm/core/error/errors.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

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
  SalesRow? _drillRow; // Tier-3: the row we've drilled into.

  SalesReportSpec get spec => widget.spec;

  /// Customer / package / salesperson rows drill into the underlying bookings.
  bool get _drillable =>
      spec.kind == kSalesByCustomer ||
      spec.kind == kSalesByPackage ||
      spec.kind == kSalesBySalesperson;

  String _phoneKey(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  bool _bookingMatches(Booking b, SalesRow row) {
    switch (spec.kind) {
      case kSalesByCustomer:
        return _phoneKey(b.phone) == _phoneKey(row.id);
      case kSalesByPackage:
        return b.service.trim() == row.id.trim() ||
            b.bookingItems.any((it) => it.service.trim() == row.id.trim());
      case kSalesBySalesperson:
        return (b.salesPersonId ?? '') == row.id && row.id.isNotEmpty;
      default:
        return false;
    }
  }
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
      final picked = await showBrandedDateRangePicker(
        context,
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
              AppErrorView(error: e, onRetry: () => ref.invalidate(salesReportProvider(_key))),
            ]),
            data: (rep) {
              _last = rep;
              if (_drillRow != null && _drillable) {
                return _drillView(crm, _drillRow!);
              }
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
        border: Border.all(color: crm.border.faded(0.8)),
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

  Widget _row(CrmTheme crm, SalesRow r) {
    final canDrill = _drillable && r.id.trim().isNotEmpty;
    final body = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border.faded(0.4)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: canDrill ? crm.primary : crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (r.sublabel.isNotEmpty)
                Text(r.sublabel, style: TextStyle(fontSize: 11, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Expanded(flex: 2, child: Text('${r.count}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: crm.textPrimary))),
          Expanded(flex: 3, child: Text(_money(r.amount), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary))),
          if (spec.showReceived)
            Expanded(flex: 3, child: Text(_money(r.received), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: Color(0xFF0D9488)))),
          if (canDrill)
            Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right_rounded, size: 16, color: crm.textSecondary)),
        ]),
      );
    if (!canDrill) return body;
    return InkWell(
      onTap: () => setState(() {
        _drillRow = r;
        _visible = kFinancePageSize;
      }),
      child: body,
    );
  }

  // ── Tier 3: the bookings behind one summary row ─────────────────────────────
  Widget _drillView(CrmTheme crm, SalesRow row) {
    final async = ref.watch(bookingProvider);
    final months = const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    String dateLabel(DateTime? d) =>
        d == null ? '' : '${d.day} ${months[d.month - 1]} ${d.year}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      children: [
        // Breadcrumb + back
        Row(children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: () => setState(() => _drillRow = null),
          ),
          Expanded(
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              InkWell(
                onTap: () => setState(() => _drillRow = null),
                child: Text(spec.title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: crm.primary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right_rounded,
                    size: 16, color: crm.textSecondary),
              ),
              Text(row.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
            ]),
          ),
        ]),
        12.h,
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(bookingProvider)),
          data: (all) {
            final bookings = all
                .where((b) => _bookingMatches(b, row) && _inDrillRange(b))
                .toList()
              ..sort((a, b) => (b.bookingDate).compareTo(a.bookingDate));
            if (bookings.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: crm.border),
                ),
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                    child: Text('No bookings found for this selection.',
                        style: TextStyle(color: crm.textSecondary))),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border),
              ),
              child: Column(children: [
                for (final b in bookings)
                  InkWell(
                    onTap: () => context.push('/booking/manage/${b.id}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(
                                  color: crm.border.faded(0.4)))),
                      child: Row(children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  b.customerName.isEmpty
                                      ? (b.service.isEmpty
                                          ? 'Booking'
                                          : b.service)
                                      : b.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: crm.textPrimary)),
                              Text(
                                  '${dateLabel(b.bookingDate)}'
                                  '${b.service.trim().isNotEmpty ? '  ·  ${b.service.trim()}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11, color: crm.textSecondary)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(_money(b.totalPrice),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: crm.textSecondary),
                      ]),
                    ),
                  ),
              ]),
            );
          },
        ),
      ],
    );
  }

  bool _inDrillRange(Booking b) {
    if (_from != null && b.bookingDate.isBefore(_from!)) return false;
    if (_to != null &&
        b.bookingDate
            .isAfter(DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59))) {
      return false;
    }
    return true;
  }

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
      if (mounted) showErrorSnackBar(context, e);
    }
  }
}
