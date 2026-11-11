import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/work_profit_controller.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart'
    show FinanceQuery;
import 'package:nizan_crm/features/accounts/data/work_profit.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/finance_list_widgets.dart'
    show FinanceLoadError;
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/work_profit_card.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:nizan_crm/presentation/common_widgets/export_report_dialog.dart';
import 'package:nizan_crm/presentation/common_widgets/paginated_footer.dart';

const _sortLabels = <String, String>{
  'date_desc': 'Newest first',
  'date_asc': 'Oldest first',
  'profit_asc': 'Lowest profit first',
  'profit_desc': 'Highest profit first',
  'margin_asc': 'Lowest margin first',
  'margin_desc': 'Highest margin first',
};

/// WORK PROFIT (Accounts): for the works that happened in a period, what each earned and what it cost
/// to deliver — revenue without GST, minus the artists' expenses, the drivers' expenses and what
/// freelancers are paid for the job. Costs that sit on no work are shown beside the total, not hidden.
class WorkProfitScreen extends ConsumerStatefulWidget {
  const WorkProfitScreen({super.key});

  @override
  ConsumerState<WorkProfitScreen> createState() => _WorkProfitScreenState();
}

class _WorkProfitScreenState extends ConsumerState<WorkProfitScreen> {
  FinancePeriod _period = FinancePeriod.month;
  DateTime _month = FinancePeriodBar.thisMonth();
  DateTimeRange? _range;
  late WorkProfitQuery _query = _queryFor(
    const WorkProfitQuery(from: '', to: ''),
  );
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _busy = false;

  /// The last page that loaded, kept on screen while the next one is fetched.
  WorkProfitPage? _last;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _dayText(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// [q] with the dates of the chosen period.
  WorkProfitQuery _queryFor(WorkProfitQuery q) {
    if (_period == FinancePeriod.range && _range != null) {
      return q.refiltered(
        from: _dayText(_range!.start),
        to: _dayText(_range!.end),
      );
    }
    final (from, to) = FinanceQuery.monthBounds(_month);
    return q.refiltered(from: from, to: to);
  }

  void _setQuery(WorkProfitQuery q) => setState(() => _query = q);

  void _setPeriod(FinancePeriod p, {DateTime? month, DateTimeRange? range}) {
    _period = p;
    if (month != null) _month = DateTime(month.year, month.month);
    if (range != null) _range = range;
    _setQuery(_queryFor(_query));
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && text.trim() != _query.search.trim()) {
        _setQuery(_query.refiltered(search: text.trim()));
      }
    });
  }

  String get _periodLabel => _period == FinancePeriod.range && _range != null
      ? '${_query.from} to ${_query.to}'
      : DateFormat('MMMM yyyy').format(_month);

  Future<void> _export() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    WorkProfitPage data;
    try {
      data = await ref.read(workProfitServiceProvider).export(_query);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showErrorSnackBar(context, e);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (data.items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to export for these filters.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => ExportReportDialog<WorkProfit>(
        title: 'Work Profit $_periodLabel',
        items: data.items,
        getVehicleName: (_) => null,
        getDriverName: (_) => null,
        headers: kWorkProfitExportHeaders,
        buildRow: workProfitExportRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(workProfitPageProvider(_query));
    if (async.hasValue) _last = async.value;
    final page = async.value ?? _last;

    if (page == null) {
      if (async.hasError) {
        return AppErrorView(
          error: async.error!,
          onRetry: () => ref.invalidate(workProfitPageProvider),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final t = page.totals;
    final filtered = _query.search.trim().isNotEmpty;
    final pad = EdgeInsets.fromLTRB(
      isMobile ? 16 : 24,
      16,
      isMobile ? 16 : 24,
      24,
    );

    return ListView(
      padding: pad,
      children: [
        if (async.isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        _header(crm, isMobile),
        14.h,
        FinancePeriodBar(
          period: _period,
          month: _month,
          range: _range,
          allowAll: false,
          onMonth: (m) => _setPeriod(FinancePeriod.month, month: m),
          onRange: (r) => _setPeriod(FinancePeriod.range, range: r),
          onAll: () {},
        ),
        if (async.hasError) ...[
          10.h,
          FinanceLoadError(
            error: async.error!,
            onRetry: () => ref.invalidate(workProfitPageProvider),
          ),
        ],
        14.h,
        InvStatGrid(
          isMobile: isMobile,
          stats: [
            InvStat(
              profitRupees(t.taxable),
              'Revenue${page.gstOn ? ' (without GST)' : ''}',
              Icons.payments_outlined,
              crm.primary,
            ),
            InvStat(
              profitRupees(t.costs),
              t.pendingCosts > 0
                  ? 'Costs · ${profitRupees(t.pendingCosts)} not verified'
                  : 'Costs',
              Icons.receipt_long_outlined,
              crm.warning,
            ),
            InvStat(
              profitRupees(t.profit),
              'Profit · ${marginText(t.marginPct)}',
              Icons.trending_up,
              t.profit < 0 ? crm.destructive : crm.success,
            ),
            InvStat(
              '${t.works}',
              'Works · ${t.loss} loss · ${t.thin} thin',
              Icons.event_available_outlined,
              crm.accent,
            ),
          ],
        ),
        8.h,
        Text(
          page.gstOn
              ? 'Revenue is what the customer pays after discount, without the ${page.gstRate.toStringAsFixed(0)}% GST. Costs are the artists\' and drivers\' expenses and freelancer payouts for each work. Salaries and overheads are not included.'
              : 'Revenue is what the customer pays after discount. Costs are the artists\' and drivers\' expenses and freelancer payouts for each work. Salaries and overheads are not included.',
          key: const Key('profitNote'),
          style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
        ),
        if (!filtered && t.unallocated > 0) ...[10.h, _unallocated(crm, t)],
        14.h,
        _toolbar(crm),
        10.h,
        _flagChips(t),
        12.h,
        if (page.items.isEmpty)
          _empty(crm)
        else
          ...page.items.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WorkProfitCard(work: w, thinMarginPct: page.thinMarginPct),
            ),
          ),
        8.h,
        PaginatedFooter(
          page: page.page,
          limit: page.limit,
          totalPages: page.totalPages,
          totalItems: page.totalItems,
          currentItemCount: page.items.length,
          onPrevious: page.page > 1
              ? () => _setQuery(_query.copyWith(page: page.page - 1))
              : null,
          onNext: page.page < page.totalPages
              ? () => _setQuery(_query.copyWith(page: page.page + 1))
              : null,
        ),
      ],
    );
  }

  Widget _header(CrmTheme crm, bool isMobile) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work Profit',
              key: const Key('workProfitTitle'),
              style: TextStyle(
                fontSize: isMobile ? 22 : 28,
                fontWeight: FontWeight.w800,
                color: crm.textPrimary,
              ),
            ),
            4.h,
            Text(
              'What each work earned and what it cost to deliver.',
              style: TextStyle(fontSize: 13, color: crm.textSecondary),
            ),
          ],
        ),
      ),
      IconButton(
        key: const Key('exportButton'),
        tooltip: 'Export everything that matches',
        onPressed: _busy ? null : _export,
        icon: const Icon(Icons.download_rounded),
        style: IconButton.styleFrom(
          foregroundColor: crm.accent,
          backgroundColor: crm.accent.withValues(alpha: 0.10),
        ),
      ),
      4.w,
      IconButton(
        tooltip: 'Refresh',
        onPressed: () => ref.refreshData.expenses(),
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );

  Widget _unallocated(CrmTheme crm, WorkProfitTotals t) => Container(
    key: const Key('unallocatedNote'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: crm.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: crm.warning.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 18,
          color: crm.warning,
        ),
        10.w,
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: crm.textPrimary,
              ),
              children: [
                TextSpan(
                  text:
                      '${profitRupees(t.unallocated)} was spent in this period but is not on any of these works',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text:
                      ' (${[if (t.unallocatedArtist > 0) 'artists ${profitRupees(t.unallocatedArtist)}', if (t.unallocatedFleet > 0) 'fleet ${profitRupees(t.unallocatedFleet)}'].join(' · ')}) — a day with no work, or a work not counted here. ',
                ),
                TextSpan(
                  text:
                      'After it, the period\'s profit is ${profitRupees(t.profitAfterUnallocated)}.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _toolbar(CrmTheme crm) {
    final search = TextField(
      key: const Key('searchField'),
      controller: _searchCtrl,
      onChanged: _onSearch,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search client, booking no. or artist',
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  _setQuery(_query.refiltered(search: ''));
                },
              ),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    final sort = PopupMenuButton<String>(
      key: const Key('sortMenu'),
      tooltip: 'Sort',
      initialValue: _query.sort,
      onSelected: (s) => _setQuery(_query.refiltered(sort: s)),
      itemBuilder: (_) => [
        for (final e in _sortLabels.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: _query.sort == e.key,
            child: Text(e.value),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: crm.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18),
            6.w,
            Text(
              _sortLabels[_query.sort] ?? 'Sort',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 520
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                8.h,
                Align(alignment: Alignment.centerLeft, child: sort),
              ],
            )
          : Row(
              children: [
                Expanded(child: search),
                10.w,
                sort,
              ],
            ),
    );
  }

  Widget _flagChips(WorkProfitTotals t) {
    Widget chip(String flag, String label, int? n) => ChoiceChip(
      key: Key('flagChip_${flag.isEmpty ? 'all' : flag}'),
      selected: _query.flag == flag,
      label: Text(n == null ? label : '$label ($n)'),
      onSelected: (_) => _setQuery(_query.refiltered(flag: flag)),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip('', 'All', t.works),
        chip('loss', 'Loss', t.loss),
        chip('thin', 'Thin margin', t.thin),
        chip('pending_costs', 'Costs not verified', t.pendingCount),
        chip('no_costs', 'No costs yet', t.noCosts),
      ],
    );
  }

  Widget _empty(CrmTheme crm) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        Icon(
          Icons.query_stats_outlined,
          size: 44,
          color: crm.textSecondary.withValues(alpha: 0.5),
        ),
        10.h,
        Text(
          _query.flag.isNotEmpty || _query.search.trim().isNotEmpty
              ? 'No works match these filters'
              : 'No works in this period',
          key: const Key('profitEmpty'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: crm.textSecondary,
          ),
        ),
        4.h,
        Text(
          _query.flag.isNotEmpty || _query.search.trim().isNotEmpty
              ? 'Try a different filter or search.'
              : 'Confirmed and completed works appear here once their day falls in the period.',
          style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
        ),
      ],
    ),
  );
}

const kWorkProfitExportHeaders = <String>[
  'Date',
  'Booking',
  'Client',
  'Service',
  'Revenue (without GST)',
  'GST',
  'Artists',
  'Fleet',
  'Freelancers',
  'Total cost',
  'Not verified',
  'Profit',
  'Margin %',
  'Notes',
];

String _plain(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

List<String> workProfitExportRow(WorkProfit w) => [
  w.serviceStart == null
      ? ''
      : DateFormat('dd/MM/yyyy').format(w.serviceStart!),
  w.bookingNumber,
  w.customerName,
  w.service,
  _plain(w.revenue.taxable),
  _plain(w.revenue.gst),
  _plain(w.costs.artist.total),
  _plain(w.costs.fleet.total),
  _plain(w.costs.freelance.total),
  _plain(w.costs.total),
  _plain(w.costs.pending),
  _plain(w.profit),
  w.marginPct == null ? '' : _plain(w.marginPct!),
  [
    if (w.isLoss) 'Loss',
    if (w.isThin) 'Thin margin',
    if (w.hasPending) 'Costs not verified',
    if (w.noCosts) 'No costs recorded',
  ].join('; '),
];
