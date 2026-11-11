import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/fleet_expense_filters.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';
import 'package:nizan_crm/features/fleet/controllers/vehicle_controller.dart';
import 'package:nizan_crm/features/fleet/data/expense_km_check.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense_page.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/expense_work_check.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fuel_price_manager.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fuel_rate_widgets.dart';
import 'package:nizan_crm/presentation/common_widgets/export_report_dialog.dart';
import 'package:nizan_crm/presentation/common_widgets/paginated_footer.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_expense_controller.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/money_account_picker.dart';

/// Accounts → Operations → Fleet Expenses. Driver-submitted fleet expenses (with the
/// uploaded bill) surfaced in Accounts, reviewable / approvable here.
///
/// Everything is filtered, sorted and paged ON THE SERVER, so the list, its page
/// count and every total stay right however many expenses there are:
///   • month switcher (◀ October 2026 ▶), this / last month, a custom range, all time
///   • status chips with counts, search, sort, and an advanced-filters form
///   • totals and a breakdown that cover the whole filtered set, not just the page
///   • export of everything that matches, and bulk approve / reject
class AccountsFleetExpensesScreen extends ConsumerStatefulWidget {
  const AccountsFleetExpensesScreen({super.key});

  @override
  ConsumerState<AccountsFleetExpensesScreen> createState() =>
      _AccountsFleetExpensesScreenState();
}

class _AccountsFleetExpensesScreenState
    extends ConsumerState<AccountsFleetExpensesScreen> {
  // ── what is being looked at ──
  FinancePeriod _period = FinancePeriod.month;
  DateTime _month = FinancePeriodBar.thisMonth();
  DateTimeRange? _range;
  late FuelExpenseQuery _query = _queryFor(const FuelExpenseQuery());

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  /// Pending expenses ticked for a bulk approve / reject (this page only).
  final Set<String> _selected = {};
  bool _busy = false;

  /// The last page that loaded, kept on screen while the next one is fetched.
  FuelExpensePage? _last;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _dayText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [q] with the dates of the current period.
  FuelExpenseQuery _queryFor(FuelExpenseQuery q) {
    switch (_period) {
      case FinancePeriod.all:
        return q.refiltered(from: null, to: null);
      case FinancePeriod.range:
        final r = _range;
        return q.refiltered(from: r == null ? null : _dayText(r.start), to: r == null ? null : _dayText(r.end));
      case FinancePeriod.month:
        final (from, to) = FuelExpenseQuery.monthBounds(_month);
        return q.refiltered(from: from, to: to);
    }
  }

  void _setQuery(FuelExpenseQuery q) => setState(() {
        _query = q;
        _selected.clear();
      });

  void _setPeriod(FinancePeriod p, {DateTime? month, DateTimeRange? range}) {
    _period = p;
    if (month != null) _month = DateTime(month.year, month.month);
    if (range != null) _range = range;
    _setQuery(_queryFor(_query));
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && text.trim() != _query.search.trim()) _setQuery(_query.refiltered(search: text.trim()));
    });
  }

  void _clearAll() {
    _searchCtrl.clear();
    _setQuery(_queryFor(const FuelExpenseQuery()).copyWith(sort: _query.sort, limit: _query.limit));
  }

  /// The day sheet loads for fleet managers and full-access roles only.
  bool get _canOpenDaySheet {
    final access = Access.of(ref.read(authSessionProvider));
    return access.isFullAccess || access.role == AppRole.fleetManager;
  }

  static String _money(double v) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(v);
  static String _date(DateTime d) => DateFormat('d MMM yyyy').format(d);

  Color _statusColor(CrmTheme crm, String s) {
    switch (s) {
      case 'approved':
        return crm.success;
      case 'rejected':
        return crm.destructive;
      default:
        return crm.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(accountsFuelExpensePageProvider(_query));
    if (async.hasValue) _last = async.value;
    final page = async.value ?? _last;

    final drivers = [
      for (final e in ref.watch(employeesProvider).value ?? const <Employee>[])
        if (e.isDriver) (id: e.id, name: e.name),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final vehicles = [
      for (final v in ref.watch(vehiclesProvider).value ?? const <Vehicle>[])
        (id: v.id, name: v.registrationNumber.isEmpty ? v.name : '${v.name} · ${v.registrationNumber}'),
    ];

    if (page == null) {
      if (async.hasError) {
        return AppErrorView(
          error: async.error!,
          onRetry: () => ref.invalidate(accountsFuelExpensePageProvider),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final summary = page.summary;
    final pad = EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 24);

    return ListView(
      padding: pad,
      children: [
        if (async.isLoading) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 3)),
        _header(crm, isMobile),
        14.h,
        FinancePeriodBar(
          period: _period,
          month: _month,
          range: _range,
          onMonth: (m) => _setPeriod(FinancePeriod.month, month: m),
          onRange: (r) => _setPeriod(FinancePeriod.range, range: r),
          onAll: () => _setPeriod(FinancePeriod.all),
        ),
        14.h,
        if (summary != null) ...[
          InvStatGrid(
            isMobile: isMobile,
            stats: [
              InvStat(_money(summary.allAmount), 'Total · ${summary.allCount}', Icons.summarize_outlined, crm.primary),
              InvStat(_money(summary.status('pending').amount), 'Pending review · ${summary.status('pending').count}',
                  Icons.hourglass_bottom_outlined, crm.warning),
              InvStat(_money(summary.status('approved').amount), 'Approved · ${summary.status('approved').count}',
                  Icons.check_circle_outline, crm.success),
              InvStat(_money(summary.status('rejected').amount), 'Rejected · ${summary.status('rejected').count}',
                  Icons.cancel_outlined, crm.destructive),
            ],
          ),
          14.h,
        ],
        _toolbar(crm, isMobile, drivers, vehicles),
        10.h,
        _statusChips(summary),
        if (_query.advancedCount > 0 || _query.search.trim().isNotEmpty || _query.statuses.isNotEmpty) ...[
          10.h,
          ActiveFilterChips(
            query: _query,
            driverName: drivers.where((d) => d.id == _query.driverId).map((d) => d.name).firstOrNull,
            vehicleName: vehicles.where((v) => v.id == _query.vehicleId).map((v) => v.name).firstOrNull,
            onChanged: (q) {
              if (q.search != _query.search) _searchCtrl.text = q.search;
              _setQuery(q);
            },
            onClearAll: _clearAll,
          ),
        ],
        if (summary != null && summary.shownCount > 0) ...[
          12.h,
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('breakdownTile'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              expandedAlignment: Alignment.centerLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              initiallyExpanded: !isMobile,
              title: Text('Breakdown', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
              children: [
                ExpenseBreakdown(
                  summary: summary,
                  query: _query,
                  onCategory: (cat) {
                    final next = {..._query.categories};
                    next.contains(cat) ? next.remove(cat) : next.add(cat);
                    _setQuery(_query.refiltered(categories: next));
                  },
                  onDriver: (id) => _setQuery(_query.refiltered(driverId: _query.driverId == id ? null : id)),
                ),
              ],
            ),
          ),
        ],
        12.h,
        _listHeader(crm, page),
        if (_selected.isNotEmpty) _bulkBar(page),
        if (page.items.isEmpty)
          _empty(crm)
        else
          ...page.items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _expenseCard(crm, e),
              )),
        8.h,
        PaginatedFooter(
          page: page.page,
          limit: page.limit,
          totalPages: page.totalPages,
          totalItems: page.totalItems,
          currentItemCount: page.items.length,
          onPrevious: page.page > 1 ? () => _setQuery(_query.copyWith(page: page.page - 1)) : null,
          onNext: page.page < page.totalPages ? () => _setQuery(_query.copyWith(page: page.page + 1)) : null,
        ),
      ],
    );
  }

  // ── header, toolbar, chips ──

  Widget _header(CrmTheme crm, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fleet Expenses',
                  style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              4.h,
              Text('Driver-submitted fleet expenses with bills — review & approve.',
                  style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            ],
          ),
        ),
        // Accounts keeps the fuel prices bills are checked against, and fill-ins use.
        if (canEditFuelPrices(ref.read(authSessionProvider)?.role)) ...[
          IconButton(
            key: const Key('fuelPricesButton'),
            tooltip: 'Fuel prices',
            onPressed: () => showFuelPriceManager(context),
            icon: const Icon(Icons.local_gas_station_outlined),
            style: IconButton.styleFrom(foregroundColor: crm.accent, backgroundColor: crm.accent.withValues(alpha: 0.10)),
          ),
          4.w,
        ],
        IconButton(
          key: const Key('exportButton'),
          tooltip: 'Export everything that matches',
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.download_rounded),
          style: IconButton.styleFrom(foregroundColor: crm.accent, backgroundColor: crm.accent.withValues(alpha: 0.10)),
        ),
        4.w,
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.refreshData.fuelExpenses(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _toolbar(CrmTheme crm, bool isMobile, List<NameOption> drivers, List<NameOption> vehicles) {
    final search = TextField(
      key: const Key('searchField'),
      controller: _searchCtrl,
      onChanged: _onSearch,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: ResponsiveBuilder.isMobile(context)
            ? 'Search driver, vehicle, client, notes…'
            : 'Search driver, vehicle, station, notes, client, booking no. or amount',
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

    final filters = Badge(
      isLabelVisible: _query.advancedCount > 0,
      label: Text('${_query.advancedCount}'),
      child: OutlinedButton.icon(
        key: const Key('filtersButton'),
        onPressed: () async {
          final next = await showExpenseFilters(context, current: _query, drivers: drivers, vehicles: vehicles);
          if (next != null) _setQuery(next);
        },
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: const Text('Filters'),
      ),
    );

    final sort = PopupMenuButton<String>(
      key: const Key('sortMenu'),
      tooltip: 'Sort',
      initialValue: _query.sort,
      onSelected: (s) => _setQuery(_query.refiltered(sort: s)),
      itemBuilder: (_) => [
        for (final e in kListSortLabels.entries)
          CheckedPopupMenuItem(value: e.key, checked: _query.sort == e.key, child: Text(e.value)),
      ],
      child: Chip(
        avatar: const Icon(Icons.sort_rounded, size: 18),
        label: Text(kListSortLabels[_query.sort] ?? 'Sort', style: const TextStyle(fontSize: 12.5)),
        visualDensity: VisualDensity.compact,
      ),
    );

    final size = PopupMenuButton<int>(
      key: const Key('pageSizeMenu'),
      tooltip: 'Rows per page',
      initialValue: _query.limit,
      onSelected: (n) => _setQuery(_query.refiltered(limit: n)),
      itemBuilder: (_) => [
        for (final n in const [10, 20, 50, 100]) CheckedPopupMenuItem(value: n, checked: _query.limit == n, child: Text('$n per page')),
      ],
      child: Chip(
        label: Text('${_query.limit} / page', style: const TextStyle(fontSize: 12.5)),
        visualDensity: VisualDensity.compact,
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          search,
          8.h,
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [filters, sort, size]),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: search),
        10.w,
        filters,
        10.w,
        sort,
        6.w,
        size,
      ],
    );
  }

  Widget _statusChips(ExpenseSummary? summary) {
    String label(String s, String text) =>
        summary == null ? text : '$text (${s == 'all' ? summary.allCount : summary.status(s).count})';
    final current = _query.statuses.length == 1 ? _query.statuses.first : 'all';
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final s in const ['all', 'pending', 'approved', 'rejected'])
          ChoiceChip(
            key: Key('status_$s'),
            selected: current == s,
            label: Text(label(s, s[0].toUpperCase() + s.substring(1))),
            onSelected: (_) => _setQuery(_query.refiltered(statuses: s == 'all' ? <String>{} : {s})),
          ),
      ],
    );
  }

  Widget _listHeader(CrmTheme crm, FuelExpensePage page) {
    final start = page.totalItems == 0 ? 0 : (page.page - 1) * page.limit + 1;
    final end = page.totalItems == 0 ? 0 : start + page.items.length - 1;
    final pending = page.items.where((e) => e.status == 'pending').toList();
    final allTicked = pending.isNotEmpty && pending.every((e) => _selected.contains(e.id));
    final shown = page.summary?.shownAmount;
    return Row(
      children: [
        if (pending.isNotEmpty)
          Tooltip(
            message: 'Select every pending expense on this page',
            child: Checkbox(
              key: const Key('selectAllPending'),
              value: allTicked,
              visualDensity: VisualDensity.compact,
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                        if (v == true) {
                          _selected.addAll(pending.map((e) => e.id));
                        } else {
                          _selected.removeAll(pending.map((e) => e.id));
                        }
                      }),
            ),
          ),
        Expanded(
          child: Text(
            page.totalItems == 0
                ? 'No expenses'
                : 'Showing $start–$end of ${page.totalItems}${shown == null ? '' : '  ·  ${_money(shown)}'}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _empty(CrmTheme crm) {
    final filtered = _query.advancedCount > 0 || _query.search.trim().isNotEmpty || _query.statuses.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 44, color: crm.textSecondary.withValues(alpha: 0.5)),
            10.h,
            Text(filtered ? 'No fleet expenses match these filters.' : 'No fleet expenses in this period.',
                style: TextStyle(color: crm.textSecondary)),
            if (filtered) ...[
              6.h,
              TextButton(onPressed: _clearAll, child: const Text('Clear filters')),
            ],
          ],
        ),
      ),
    );
  }

  // ── bulk approve / reject ──

  List<FuelExpense> _ticked(FuelExpensePage page) =>
      page.items.where((e) => _selected.contains(e.id) && e.status == 'pending').toList();

  Widget _bulkBar(FuelExpensePage page) {
    final items = _ticked(page);
    return BulkActionBar(
      count: items.length,
      amount: items.fold(0.0, (a, e) => a + e.totalAmount),
      busy: _busy,
      onApprove: () => _bulk(items, 'approved'),
      onReject: () => _bulk(items, 'rejected'),
      onClear: () => setState(_selected.clear),
    );
  }

  Future<void> _bulk(List<FuelExpense> items, String status) async {
    if (items.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final total = items.fold(0.0, (a, e) => a + e.totalAmount);
    MoneyChoice? money;
    if (status == 'approved') {
      // One bank / cash account for the whole batch. The reference (UTR / UPI no.)
      // belongs to a single payment, so it is not copied onto each expense.
      final picked = await showMoneyAccountPicker(
        context,
        title: 'Approve ${items.length} fleet expenses',
        amount: total,
        moneyIn: false,
        modes: kFleetPayModes,
        initialMode: 'cash',
        approveLabel: 'Approve all',
      );
      if (picked == null) return;
      money = MoneyChoice(moneyAccountId: picked.moneyAccountId, paymentMode: picked.paymentMode);
    } else {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Reject ${items.length} expenses?'),
          content: Text('${_money(total)} across ${items.length} driver expenses will be marked rejected and won\'t count as a cost.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject all')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    var done = 0;
    String? firstError;
    for (final e in items) {
      try {
        await ref.read(fuelExpenseServiceProvider).setStatus(e.id, status, money: money);
        done += 1;
        _selected.remove(e.id);
      } catch (err) {
        firstError ??= friendlyErrorMessage(err);
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.refreshData.fuelExpenses();
    final failed = items.length - done;
    messenger.showSnackBar(SnackBar(
      content: Text(failed == 0
          ? '${status == 'approved' ? 'Approved' : 'Rejected'} $done expense${done == 1 ? '' : 's'}.'
          : '${status == 'approved' ? 'Approved' : 'Rejected'} $done of ${items.length}. $failed failed: $firstError'),
    ));
  }

  // ── export ──

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    FuelExpenseExport data;
    try {
      data = await ref.read(fuelExpenseServiceProvider).exportFuelExpenses(_query);
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
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to export for these filters.')));
      return;
    }
    if (data.truncated) {
      messenger.showSnackBar(SnackBar(
        content: Text('Exporting the first ${data.items.length} of ${data.totalItems} — narrow the filters for the rest.'),
      ));
    }
    final label = switch (_period) {
      FinancePeriod.all => 'All time',
      FinancePeriod.range => '${_query.from ?? ''} to ${_query.to ?? ''}',
      FinancePeriod.month => DateFormat('MMMM yyyy').format(_month),
    };
    await showDialog<void>(
      context: context,
      builder: (_) => ExportReportDialog<FuelExpense>(
        title: 'Fleet Expenses $label',
        items: data.items,
        getVehicleName: (e) => e.vehicle?.name,
        getDriverName: (e) => e.driver?.name,
        headers: kFleetExpenseExportHeaders,
        buildRow: fleetExpenseExportRow,
      ),
    );
  }

  Widget _expenseCard(CrmTheme crm, FuelExpense e) {
    final c = _statusColor(crm, e.status);
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pending expenses can be ticked for a bulk approve / reject.
              if (e.status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      key: Key('select_${e.id}'),
                      value: _selected.contains(e.id),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => v == true ? _selected.add(e.id) : _selected.remove(e.id)),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                    e.driver?.name.isNotEmpty == true
                        ? e.driver!.name
                        : 'Driver',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: crm.textPrimary)),
              ),
              Text(_money(e.totalAmount),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: crm.textPrimary)),
              8.w,
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(e.status,
                    style: TextStyle(
                        color: c, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          4.h,
          Text(
            [
              e.category,
              if (e.vehicle?.name.isNotEmpty == true) e.vehicle!.name,
              if (e.station.isNotEmpty) e.station,
              _date(e.date),
            ].join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
          // Which work and where, the fuel detail, and the km check for the day.
          ExpenseWorkCheck(
            expense: e,
            canOpenDaySheet: _canOpenDaySheet && (e.driver?.id.isNotEmpty ?? false),
            onOpenDaySheet: () {
              final day = e.kmCheck?.dayKey.isNotEmpty == true ? e.kmCheck!.dayKey : e.dayKey;
              context.go('/fleet/day-sheet?driverId=${e.driver!.id}&date=$day');
            },
          ),
          // The bill's rate against the fuel price of its day (only fuel fill-ups carry one).
          RateCheckLine(check: e.rateCheck),
          if (e.notes.isNotEmpty) ...[
            4.h,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes_outlined, size: 13, color: crm.textSecondary),
                4.w,
                Expanded(
                  child: Text(
                    e.notes,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: crm.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          10.h,
          Row(
            children: [
              if (e.billImage.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _viewBill(crm, e.billImage),
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('View bill'),
                  style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                )
              else
                Text('No bill attached',
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: crm.textSecondary)),
              const Spacer(),
              if (e.status != 'approved')
                TextButton(
                  onPressed: () => _setStatus(e, 'approved'),
                  child: Text('Approve',
                      style: TextStyle(color: crm.success)),
                ),
              if (e.status != 'rejected')
                TextButton(
                  onPressed: () => _setStatus(e, 'rejected'),
                  child: Text('Reject',
                      style: TextStyle(color: crm.destructive)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(FuelExpense e, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    // Approving asks which bank / cash account paid it.
    MoneyChoice? money;
    if (status == 'approved') {
      money = await showMoneyAccountPicker(
        context,
        title: 'Approve fleet expense',
        amount: e.totalAmount,
        moneyIn: false,
        modes: kFleetPayModes,
        initialMode: e.paymentMode,
      );
      if (money == null) return; // cancelled
    }
    try {
      await ref.read(fuelExpenseServiceProvider).setStatus(e.id, status, money: money);
      if (mounted) setState(() => _selected.remove(e.id));
      ref.refreshData.fuelExpenses();
      messenger.showSnackBar(SnackBar(content: Text('Marked $status')));
    } catch (err) {
      if (mounted) showErrorSnackBar(context, err);
    }
  }

  void _viewBill(CrmTheme crm, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: crm.primary),
                  8.w,
                  const Expanded(
                      child: Text('Expense Bill',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Download Bill',
                    onPressed: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text('Could not load bill image',
                              style: TextStyle(color: crm.textSecondary)),
                        )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── export rows ──────────────────────────────────────────────────────────────

const kFleetExpenseExportHeaders = <String>[
  'Date',
  'Driver',
  'Vehicle',
  'Category',
  'Amount',
  'Status',
  'Payment',
  'Station / Vendor',
  'Notes',
  'Tied to',
  'Client(s)',
  'Artist(s)',
  'Litres',
  'Odometer (km)',
  'Km check',
];

String _kmCheckText(ExpenseKmCheck? k) => switch (k?.status) {
      null => '',
      'ok' => 'OK',
      'over' => 'Over plan',
      'under' => 'Under plan',
      'in_progress' => 'Trips not finished',
      'no_works' => 'No work that day',
      _ => 'Route not available',
    };

/// One expense as an export row: what, who, how, and — for Accounts — which work(s),
/// which client(s) and which artist(s) it belongs to.
List<String> fleetExpenseExportRow(FuelExpense e) {
  final split = e.split;
  final works = split?.works ?? const [];
  final artists = <String>{
    for (final w in works)
      for (final a in w.artists)
        if (a.name.trim().isNotEmpty) a.name.trim(),
  };
  final clients = [
    for (final w in works) w.customerName.trim().isNotEmpty ? w.customerName.trim() : w.bookingNumber,
  ];
  return [
    DateFormat('yyyy-MM-dd').format(e.date),
    e.driver?.name ?? '',
    e.vehicle?.name ?? '',
    categoryLabel(e.category),
    e.totalAmount.toStringAsFixed(2),
    e.status,
    kExpensePaymentLabels[e.paymentMode] ?? e.paymentMode,
    e.station,
    e.notes,
    switch (split?.mode) {
      'direct' => 'One work',
      'shared' => 'Whole day (shared equally)',
      'unallocated' => 'No work',
      _ => e.bookingId != null ? 'One work' : '',
    },
    clients.join('; '),
    artists.join('; '),
    e.liters > 0 ? e.liters.toStringAsFixed(2) : '',
    e.odometerKm > 0 ? e.odometerKm.toStringAsFixed(0) : '',
    _kmCheckText(e.kmCheck),
  ];
}
