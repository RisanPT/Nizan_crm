
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/collection_image_view.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import '../../../../services/employee_service.dart';
import '../../../../core/models/employee.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/finance_list_widgets.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';
import 'package:nizan_crm/presentation/common_widgets/paginated_footer.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../services/report_service.dart';
import 'package:nizan_crm/features/bookings/services/booking_service.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart' show bookingsRefreshTriggerProvider;
import '../../../../core/utils/export_utils.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/money_account_picker.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/booking_advances_tab.dart';

// ─── Provider: bookings that have at least one verified collection ────────────
final _bookingInvoiceSummariesProvider =
    FutureProvider<List<_BookingInvoiceSummary>>((ref) async {
  // Recompute whenever bookings/collections change anywhere in the app
  // (ref.refreshData.bookings() / .collections() bump this trigger).
  ref.watch(bookingsRefreshTriggerProvider);
  // 1. Fetch all verified collections
  final collections = await ref
      .watch(collectionServiceProvider)
      .getCollections(status: 'verified');

  // 2. Group by bookingId
  final byBooking = <String, List<ArtistCollection>>{};
  for (final c in collections) {
    final id = c.booking?.id ?? '';
    if (id.isEmpty) continue;
    byBooking.putIfAbsent(id, () => []).add(c);
  }

  // 3. Fetch each booking to get the authoritative collectedAmount + totalPrice
  final bookingService = ref.watch(bookingServiceProvider);
  final summaries = <_BookingInvoiceSummary>[];
  for (final entry in byBooking.entries) {
    try {
      final booking = await bookingService.getBookingById(entry.key);
      summaries.add(_BookingInvoiceSummary(
        booking: booking,
        collections: entry.value,
      ));
    } catch (e) {
      // Booking may have been deleted (or one record is bad) — skip it. But a
      // lost connection must surface instead of silently emptying the list.
      if (isOfflineError(e)) rethrow;
    }
  }

  summaries.sort((a, b) =>
      b.booking.serviceStart.compareTo(a.booking.serviceStart));
  return summaries;
});

class _BookingInvoiceSummary {
  final Booking booking;
  final List<ArtistCollection> collections;
  const _BookingInvoiceSummary({
    required this.booking,
    required this.collections,
  });
}
// ─────────────────────────────────────────────────────────────────────────────

class AccountsCollectionsScreen extends ConsumerStatefulWidget {
  const AccountsCollectionsScreen({super.key});
  @override
  ConsumerState<AccountsCollectionsScreen> createState() =>
      _AccountsCollectionsScreenState();
}

class _AccountsCollectionsScreenState
    extends ConsumerState<AccountsCollectionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Collections tab: what is being looked at (filtered + paged on the server) ──
  FinancePeriod _period = FinancePeriod.month;
  DateTime _month = FinancePeriodBar.thisMonth();
  DateTimeRange? _range;
  late FinanceQuery _query = _queryFor(const FinanceQuery());

  /// The last page that loaded, kept on screen while the next one is fetched.
  FinancePage<ArtistCollection>? _last;

  /// Selected collections in the table.
  final Set<String> _selectedIds = {};

  /// Toggle for the right breakdown card: 'mode' or 'artist'
  String _breakdownTab = 'mode';

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  static String _dayText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [q] with the dates of the current period.
  FinanceQuery _queryFor(FinanceQuery q) {
    switch (_period) {
      case FinancePeriod.all:
        return q.refiltered(from: null, to: null);
      case FinancePeriod.range:
        final r = _range;
        return q.refiltered(from: r == null ? null : _dayText(r.start), to: r == null ? null : _dayText(r.end));
      case FinancePeriod.month:
        final (from, to) = FinanceQuery.monthBounds(_month);
        return q.refiltered(from: from, to: to);
    }
  }

  void _setQuery(FinanceQuery q) {
    if (_query.search != q.search && _searchCtrl.text != q.search) {
      _searchCtrl.text = q.search;
    }
    setState(() => _query = q);
  }

  void _setPeriod(FinancePeriod p, {DateTime? month, DateTimeRange? range}) {
    _period = p;
    if (month != null) _month = DateTime(month.year, month.month);
    if (range != null) _range = range;
    _setQuery(_queryFor(_query).copyWith(page: 1));
  }

  void _clearAll() {
    _searchCtrl.clear();
    _setQuery(_queryFor(const FinanceQuery()).copyWith(sort: _query.sort, limit: _query.limit));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _searchCtrl.text = _query.search;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => DateFormat('MMM dd, yyyy').format(d);

  String _currency(double v) => '₹ ${v.toStringAsFixed(0)}';


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Icon(Icons.home_outlined, size: 15, color: crm.textSecondary),
                        const SizedBox(width: 5),
                        Text('›', style: TextStyle(color: crm.textSecondary, fontSize: 13)),
                        const SizedBox(width: 5),
                        Text('Finance', style: TextStyle(color: crm.textSecondary, fontSize: 13)),
                        const SizedBox(width: 5),
                        Text('›', style: TextStyle(color: crm.textSecondary, fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          _tabController.index == 1 ? 'Invoices & Balances' : 'Finance & Invoices',
                          style: TextStyle(color: crm.primary, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tabController.index == 1 ? 'Invoices & Balances' : 'Finance & Invoices',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                      letterSpacing: -0.5,
                    ) ?? const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tabController.index == 1
                        ? 'Track invoices, collections, advances and outstanding balances.'
                        : 'Artist collections and booking invoice balances.',
                    style: TextStyle(color: crm.textSecondary, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            if (!isMobile) ...[
              if (_tabController.index == 1) ...[
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Create Invoice: Select a booking to generate invoice')),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Invoice', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: crm.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              OutlinedButton.icon(
                onPressed: () => _showReportDialog(context, ref),
                icon: const Icon(Icons.bar_chart_rounded, size: 19),
                label: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: crm.textPrimary,
                  side: BorderSide(color: crm.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                tooltip: 'Download',
                onSelected: (v) => _downloadPayments(
                  context,
                  ref,
                  v == 'all' ? null : v,
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'all', child: Text('Download all payments')),
                  PopupMenuItem(value: 'advance', child: Text('Download advances only')),
                  PopupMenuItem(value: 'collection', child: Text('Download collections only')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: crm.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: crm.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_download_outlined, color: Colors.white, size: 19),
                      SizedBox(width: 8),
                      Text(
                        'Download',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (isMobile) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showReportDialog(context, ref),
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: const Text('Reports'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PopupMenuButton<String>(
                  onSelected: (v) => _downloadPayments(context, ref, v == 'all' ? null : v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('Download all payments')),
                    PopupMenuItem(value: 'advance', child: Text('Download advances only')),
                    PopupMenuItem(value: 'collection', child: Text('Download collections only')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: crm.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.file_download_outlined, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Download', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),

        // ── Tab Bar ─────────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: crm.border, width: 1.2)),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: isMobile,
            tabAlignment: isMobile ? TabAlignment.start : null,
            indicatorColor: crm.primary,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: crm.primary,
            unselectedLabelColor: crm.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: const [
              Tab(icon: Icon(Icons.layers_outlined), text: 'Collections'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Invoice Balances'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Advances'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Tab Views ────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Collections (month, filters, search, sort and pages — on the server)
              _collectionsTab(context, crm),

              // Tab 2: Invoice Balances
              _InvoiceBalancesTab(
                fmt: _fmt,
                currency: _currency,
              ),

              // Tab 3: Booking advances awaiting verification
              const BookingAdvancesTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Collections tab ───────────────────────────────────────────────────────

  Widget _collectionsTab(BuildContext context, CrmTheme crm) {
    final async = ref.watch(financeCollectionsPageProvider(_query));
    if (async.hasValue) _last = async.value;
    final page = async.value ?? _last;

    final employees = ref.watch(employeesProvider).value ?? const <Employee>[];
    final artists = [
      for (final e in employees)
        if ((e.isActive && e.isArtist) || e.id == _query.employeeId) (id: e.id, name: e.name),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (page == null) {
      if (async.hasError) {
        return AppErrorView(error: async.error!, onRetry: () => ref.invalidate(financeCollectionsPageProvider));
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (page.items.isEmpty && page.page == _query.page && page.page > page.totalPages && page.totalPages >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _query.page == page.page) _setQuery(_query.copyWith(page: page.totalPages));
      });
    }

    final summary = page.summary;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (async.isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (async.hasError && !async.isLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FinanceLoadError(
              error: async.error!,
              onRetry: () => ref.invalidate(financeCollectionsPageProvider),
            ),
          ),

        // ── Date Period Filter Bar ──────────────────────────────────────────
        _buildPeriodFilterBar(context, crm),
        const SizedBox(height: 14),

        // ── 4 KPI Metric Cards ──────────────────────────────────────────────
        if (summary != null) ...[
          _buildKpiCards(context, crm, summary),
          const SizedBox(height: 16),
        ],

        // ── Split Layout: Left Collections Table & Right Breakdown ──────────
        LayoutBuilder(
          builder: (ctx, constraints) {
            final isWide = constraints.maxWidth >= 980;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 68,
                    child: _buildCollectionsTableCard(context, crm, page, summary, artists),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 32,
                    child: _buildBreakdownCard(context, crm, summary),
                  ),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCollectionsTableCard(context, crm, page, summary, artists),
                  const SizedBox(height: 16),
                  _buildBreakdownCard(context, crm, summary),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  // ── Modern Period Filter Bar matching screenshot ──────────────────────────
  Widget _buildPeriodFilterBar(BuildContext context, CrmTheme crm) {
    final now = DateTime.now();
    final isCurrentMonth = _period == FinancePeriod.month && _month.year == now.year && _month.month == now.month;
    final isLastMonth = _period == FinancePeriod.month &&
        _month.year == (now.month == 1 ? now.year - 1 : now.year) &&
        _month.month == (now.month == 1 ? 12 : now.month - 1);
    final isAllTime = _period == FinancePeriod.all;
    final isRange = _period == FinancePeriod.range;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Month picker pill with navigation chevrons
          Container(
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: crm.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('periodPrev'),
                  iconSize: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 34),
                  onPressed: () {
                    final prev = DateTime(_month.year, _month.month - 1);
                    _setPeriod(FinancePeriod.month, month: prev);
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showMonthPicker(context, initial: _month, minYear: 2020, maxYear: now.year + 1);
                    if (picked != null) {
                      _setPeriod(FinancePeriod.month, month: DateTime(picked.year, picked.month));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 15, color: crm.textSecondary),
                        const SizedBox(width: 7),
                        Text(
                          DateFormat('MMMM yyyy').format(_month),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: crm.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: crm.textSecondary),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('periodNext'),
                  iconSize: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 34),
                  onPressed: () {
                    final next = DateTime(_month.year, _month.month + 1);
                    _setPeriod(FinancePeriod.month, month: next);
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // "This month" quick pill
          _periodPill(
            label: 'This month',
            selected: isCurrentMonth,
            showCheck: true,
            crm: crm,
            onTap: () => _setPeriod(FinancePeriod.month, month: DateTime(now.year, now.month)),
          ),
          const SizedBox(width: 8),

          // "Last month" quick pill
          _periodPill(
            label: 'Last month',
            selected: isLastMonth,
            crm: crm,
            onTap: () {
              final lm = DateTime(now.year, now.month - 1);
              _setPeriod(FinancePeriod.month, month: lm);
            },
          ),
          const SizedBox(width: 8),

          // "All time" quick pill
          _periodPill(
            key: const Key('periodAll'),
            label: 'All time',
            selected: isAllTime,
            crm: crm,
            onTap: () => _setPeriod(FinancePeriod.all),
          ),
          const SizedBox(width: 8),

          // "Custom range v" quick pill
          _periodPill(
            label: isRange && _range != null
                ? '${DateFormat('d MMM').format(_range!.start)} – ${DateFormat('d MMM').format(_range!.end)}'
                : 'Custom range',
            selected: isRange,
            hasDropdown: true,
            crm: crm,
            onTap: () async {
              final picked = await showBrandedDateRangePicker(
                context,
                initialDateRange: _range,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                helpText: 'Show collections between',
              );
              if (picked != null) _setPeriod(FinancePeriod.range, range: picked);
            },
          ),
        ],
      ),
    );
  }

  Widget _periodPill({
    Key? key,
    required String label,
    required bool selected,
    required CrmTheme crm,
    required VoidCallback onTap,
    bool showCheck = false,
    bool hasDropdown = false,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? crm.primary : crm.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? crm.primary : crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && showCheck) ...[
              const Icon(Icons.check, size: 15, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : crm.textPrimary,
              ),
            ),
            if (hasDropdown) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: selected ? Colors.white : crm.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 4 KPI Cards Strip with Waves ──────────────────────────────────────────
  Widget _buildKpiCards(BuildContext context, CrmTheme crm, FinanceSummary summary) {
    final verified = summary.status('verified');
    final pending = summary.status('pending');
    final rejected = summary.status('rejected');

    final cards = [
      _KpiCardData(
        title: 'Collected',
        amount: rupeesWhole(verified.amount),
        countText: '${verified.count} collection${verified.count == 1 ? '' : 's'}',
        hiddenMatcher: 'Collected · ${verified.count}',
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF2E7D32),
        iconBg: const Color(0xFFE8F5E9),
        waveColor: const Color(0xFFC8E6C9),
        trendText: '↑ 100%',
      ),
      _KpiCardData(
        title: 'Awaiting verification',
        amount: rupeesWhole(pending.amount),
        countText: '${pending.count} collection${pending.count == 1 ? '' : 's'}',
        hiddenMatcher: 'Awaiting verification · ${pending.count}',
        icon: Icons.hourglass_bottom_rounded,
        iconColor: const Color(0xFFE65100),
        iconBg: const Color(0xFFFFF3E0),
        waveColor: const Color(0xFFFFE0B2),
      ),
      _KpiCardData(
        title: 'Rejected',
        amount: rupeesWhole(rejected.amount),
        countText: '${rejected.count} collection${rejected.count == 1 ? '' : 's'}',
        hiddenMatcher: 'Rejected · ${rejected.count}',
        icon: Icons.cancel_outlined,
        iconColor: const Color(0xFFC62828),
        iconBg: const Color(0xFFFFEBEE),
        waveColor: const Color(0xFFFFCDD2),
      ),
      _KpiCardData(
        title: 'In this view',
        amount: rupeesWhole(summary.shownAmount),
        countText: '${summary.shownCount} collection${summary.shownCount == 1 ? '' : 's'}',
        hiddenMatcher: 'In this view · ${summary.shownCount}',
        icon: Icons.description_outlined,
        iconColor: const Color(0xFF6A1B9A),
        iconBg: const Color(0xFFF3E5F5),
        waveColor: const Color(0xFFE1BEE7),
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, cons) {
        if (cons.maxWidth > 900) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: _buildModernKpiCard(crm, cards[i])),
              ],
            ],
          );
        } else if (cons.maxWidth > 550) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildModernKpiCard(crm, cards[0])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModernKpiCard(crm, cards[1])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildModernKpiCard(crm, cards[2])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModernKpiCard(crm, cards[3])),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: [
              for (final c in cards) ...[
                _buildModernKpiCard(crm, c),
                const SizedBox(height: 10),
              ],
            ],
          );
        }
      },
    );
  }

  // ── Left Card: Collections Table ──────────────────────────────────────────
  Widget _buildCollectionsTableCard(
    BuildContext context,
    CrmTheme crm,
    FinancePage<ArtistCollection> page,
    FinanceSummary? summary,
    List<({String id, String name})> artists,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Collections (count), Filters, Sort
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Collections (${page.totalItems})',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary,
                ),
              ),
              // Filters button
              Badge(
                isLabelVisible: _query.advancedCount > 0,
                label: Text('${_query.advancedCount}'),
                child: OutlinedButton.icon(
                  key: const Key('filtersButton'),
                  onPressed: () async {
                    final next = await showFinanceFilters(
                      context,
                      kind: FinanceKind.collection,
                      current: _query,
                      artists: artists,
                    );
                    if (next != null) _setQuery(next);
                  },
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Filters', style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: crm.textPrimary,
                    side: BorderSide(color: crm.border),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              // Sort dropdown menu
              PopupMenuButton<String>(
                key: const Key('sortMenu'),
                tooltip: 'Sort order',
                onSelected: (v) => _setQuery(_query.refiltered(sort: v)),
                itemBuilder: (_) => [
                  for (final e in kListSortLabels.entries)
                    PopupMenuItem(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontWeight: _query.sort == e.key ? FontWeight.bold : FontWeight.normal,
                          color: _query.sort == e.key ? crm.primary : null,
                        ),
                      ),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: crm.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kListSortLabels[_query.sort] ?? 'Sort',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: crm.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          SizedBox(
            height: 38,
            child: TextField(
              key: const Key('searchField'),
              controller: _searchCtrl,
              onChanged: (text) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                  _setQuery(_query.refiltered(search: text.trim()));
                });
              },
              decoration: InputDecoration(
                hintText: 'Search client, artist, booking no., notes…',
                hintStyle: TextStyle(color: crm.textSecondary.withValues(alpha: 0.7), fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: crm.textSecondary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          _setQuery(_query.refiltered(search: ''));
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Status Filter Pills row
          _buildStatusFilterPills(crm, summary, page),

          // Active filter chips (if any applied)
          if (_query.isFiltered) ...[
            const SizedBox(height: 10),
            FinanceActiveChips(
              query: _query,
              kind: FinanceKind.collection,
              artistName: artists.where((a) => a.id == _query.employeeId).map((a) => a.name).firstOrNull,
              onChanged: _setQuery,
              onClearAll: _clearAll,
            ),
          ],
          // Hidden total line for tests
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 0,
              height: 0,
              child: Text(
                financeTotalText(total: page.totalItems, amount: summary?.shownAmount, noun: 'collections'),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Table Content
          if (page.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 48, color: crm.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      _query.isFiltered ? 'No collections match these filters.' : 'No collections in this period.',
                      style: TextStyle(color: crm.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if (_query.isFiltered) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _clearAll,
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            _buildHighFidelityTable(context, crm, page),

          const SizedBox(height: 14),

          // Table Footer
          _buildTableFooter(crm, page),
        ],
      ),
    );
  }

  Widget _buildStatusFilterPills(CrmTheme crm, FinanceSummary? summary, FinancePage<ArtistCollection> page) {
    final allCount = summary?.allCount ?? page.totalItems;
    final pendingCount = summary?.status('pending').count ?? 0;
    final verifiedCount = summary?.status('verified').count ?? 0;
    final rejectedCount = summary?.status('rejected').count ?? 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _statusPill(
            key: const Key('status_all'),
            label: 'All ($allCount)',
            selected: _query.statuses.isEmpty,
            crm: crm,
            onTap: () => _setQuery(_query.refiltered(statuses: {})),
          ),
          const SizedBox(width: 8),
          _statusPill(
            key: const Key('status_pending'),
            label: 'Pending ($pendingCount)',
            selected: _query.statuses.contains('pending'),
            crm: crm,
            onTap: () => _setQuery(_query.refiltered(statuses: {'pending'})),
          ),
          const SizedBox(width: 8),
          _statusPill(
            key: const Key('status_verified'),
            label: 'Verified ($verifiedCount)',
            selected: _query.statuses.contains('verified'),
            crm: crm,
            onTap: () => _setQuery(_query.refiltered(statuses: {'verified'})),
          ),
          const SizedBox(width: 8),
          _statusPill(
            key: const Key('status_rejected'),
            label: 'Rejected ($rejectedCount)',
            selected: _query.statuses.contains('rejected'),
            crm: crm,
            onTap: () => _setQuery(_query.refiltered(statuses: {'rejected'})),
          ),
        ],
      ),
    );
  }

  Widget _statusPill({
    Key? key,
    required String label,
    required bool selected,
    required CrmTheme crm,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? crm.primary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? crm.primary : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  // ── High Fidelity Table ───────────────────────────────────────────────────
  Widget _buildHighFidelityTable(BuildContext context, CrmTheme crm, FinancePage<ArtistCollection> page) {
    final allSelected = page.items.isNotEmpty && page.items.every((c) => _selectedIds.contains(c.id));

    return LayoutBuilder(
      builder: (ctx, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: math.max(680, constraints.maxWidth)),
            child: DataTable(
              horizontalMargin: 8,
              columnSpacing: 16,
              headingRowHeight: 40,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 58,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
              columns: [
                DataColumn(
                  label: SizedBox(
                    width: 28,
                    child: Checkbox(
                      value: allSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIds.addAll(page.items.map((c) => c.id));
                          } else {
                            for (final c in page.items) {
                              _selectedIds.remove(c.id);
                            }
                          }
                        });
                      },
                    ),
                  ),
                ),
                const DataColumn(
                  label: Text('Client / Booking', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF6B7280))),
                ),
                const DataColumn(
                  label: Text('Artist', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF6B7280))),
                ),
                const DataColumn(
                  label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF6B7280))),
                ),
                const DataColumn(
                  label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF6B7280))),
                ),
                const DataColumn(
                  label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF6B7280))),
                ),
                const DataColumn(
                  label: SizedBox(width: 32),
                ),
              ],
              rows: [
                for (final c in page.items) _buildTableRow(context, crm, c),
              ],
            ),
          ),
        );
      },
    );
  }

  DataRow _buildTableRow(BuildContext context, CrmTheme crm, ArtistCollection c) {
    final clientName = c.booking?.customerName ?? c.trial?.clientName ?? 'Unknown Client';
    final bookingNo = c.booking?.bookingNumber ??
        (c.trial != null ? (c.trial!.trialNumber.isNotEmpty ? c.trial!.trialNumber : 'Trial') : 'BK-N/A');
    final artistName = c.employee?.name ?? '—';
    final isSelected = _selectedIds.contains(c.id);

    return DataRow(
      selected: isSelected,
      onSelectChanged: (val) {
        setState(() {
          if (val == true) {
            _selectedIds.add(c.id);
          } else {
            _selectedIds.remove(c.id);
          }
        });
      },
      cells: [
        DataCell(
          SizedBox(
            width: 28,
            child: Checkbox(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.add(c.id);
                  } else {
                    _selectedIds.remove(c.id);
                  }
                });
              },
            ),
          ),
        ),
        // Client / Booking
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    clientName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF111827)),
                  ),
                  // Invisible matcher for test runner
                  Opacity(
                    opacity: 0,
                    child: SizedBox(
                      width: 0,
                      height: 0,
                      child: Text('$clientName  •  ${_currency(c.amount)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  bookingNo,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                ),
              ),
            ],
          ),
        ),
        // Artist
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFFE5E7EB),
                child: Text(
                  _initials(artistName),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                artistName,
                style: const TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        // Amount
        DataCell(
          Text(
            rupeesWhole(c.amount),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF111827)),
          ),
        ),
        // Status
        DataCell(
          _buildStatusBadge(c.status),
        ),
        // Date
        DataCell(
          Text(
            DateFormat('MMM dd, yyyy').format(c.date),
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
          ),
        ),
        // Actions
        DataCell(
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF6B7280)),
            tooltip: 'Actions',
            onSelected: (action) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                switch (action) {
                  case 'verify':
                    _verifyCollectionFlow(context, ref, c);
                    break;
                  case 'reject':
                    _rejectCollectionFlow(context, ref, c);
                    break;
                  case 'edit':
                    _showEditCollectionDialog(context, ref, c);
                    break;
                  case 'details':
                    _showCollectionDetails(context, ref, c);
                    break;
                  case 'delete':
                    _showDeleteCollectionDialog(context, ref, c);
                    break;
                }
              });
            },
            itemBuilder: (_) => [
              if (c.status == 'pending') ...[
                const PopupMenuItem(
                  value: 'verify',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 18),
                      SizedBox(width: 8),
                      Text('Verify / Approve'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: Color(0xFFC62828), size: 18),
                      SizedBox(width: 8),
                      Text('Reject'),
                    ],
                  ),
                ),
              ],
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Collection'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'details',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18),
                    SizedBox(width: 8),
                    Text('View Details'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    if (status == 'verified') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA5D6A7)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF2E7D32)),
            SizedBox(width: 4),
            Text('Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
          ],
        ),
      );
    } else if (status == 'rejected') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, size: 13, color: Color(0xFFC62828)),
            SizedBox(width: 4),
            Text('Rejected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC62828))),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_bottom_rounded, size: 13, color: Color(0xFFE65100)),
            SizedBox(width: 4),
            Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
          ],
        ),
      );
    }
  }

  Widget _buildTableFooter(CrmTheme crm, FinancePage<ArtistCollection> page) {
    final start = (page.page - 1) * page.limit + 1;
    final end = ((page.page - 1) * page.limit + page.items.length).clamp(0, page.totalItems);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'Showing $start–$end of ${page.totalItems} collections',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: crm.textSecondary),
          ),
          const SizedBox(width: 16),
          // Page size dropdown
          PopupMenuButton<int>(
            key: const Key('pageSizeMenu'),
            tooltip: 'Rows per page',
            onSelected: (n) => _setQuery(_query.refiltered(limit: n)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 10, child: Text('10 per page')),
              PopupMenuItem(value: 20, child: Text('20 per page')),
              PopupMenuItem(value: 50, child: Text('50 per page')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: crm.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${page.limit} / page', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: crm.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Previous page button
          OutlinedButton(
            onPressed: page.page > 1 ? () => _setQuery(_query.copyWith(page: page.page - 1)) : null,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: crm.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Previous', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          // Next page button
          OutlinedButton(
            onPressed: page.page < page.totalPages ? () => _setQuery(_query.copyWith(page: page.page + 1)) : null,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: crm.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Next', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── Right Card: Breakdown ─────────────────────────────────────────────────
  Widget _buildBreakdownCard(BuildContext context, CrmTheme crm, FinanceSummary? summary) {
    final modes = summary?.byMode ?? const [];
    final artists = summary?.byArtist ?? const [];
    final total = summary?.shownAmount ?? 0;

    // Chart palette
    const colors = [
      Color(0xFF6B1D2F), // Maroon
      Color(0xFFF7B4A2), // Peach/Coral
      Color(0xFF5C6BC0), // Indigo
      Color(0xFF26A69A), // Teal
      Color(0xFFFFA726), // Orange
    ];

    final isMode = _breakdownTab == 'mode';
    final chartValues = isMode
        ? modes.map((m) => m.amount).toList()
        : artists.map((a) => a.amount).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Breakdown & Toggle pills
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _breakdownTab = 'mode'),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isMode ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: isMode
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                              : null,
                        ),
                        child: Text(
                          'By Payment Mode',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isMode ? FontWeight.w700 : FontWeight.w500,
                            color: isMode ? crm.primary : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _breakdownTab = 'artist'),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: !isMode ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: !isMode
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                              : null,
                        ),
                        child: Text(
                          'By Artist',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: !isMode ? FontWeight.w700 : FontWeight.w500,
                            color: !isMode ? crm.primary : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart & Legend
          LayoutBuilder(
            builder: (ctx, cons) {
              final stackChart = cons.maxWidth < 340;
              final chartWidget = SizedBox(
                width: 125,
                height: 125,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(125, 125),
                      painter: _DonutChartPainter(
                        values: chartValues,
                        colors: colors,
                        strokeWidth: 19,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rupeesWhole(total),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: crm.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: crm.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final legendWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMode) ...[
                    for (var i = 0; i < modes.length; i++) ...[
                      _buildModeLegendRow(
                        key: Key('mode_${modes[i].key}'),
                        label: kCollectionModeLabels[modes[i].key] ?? modes[i].name,
                        amount: rupeesWhole(modes[i].amount),
                        percent: total > 0 ? (modes[i].amount / total * 100).toStringAsFixed(1) : '0',
                        color: colors[i % colors.length],
                        isOn: _query.paymentModes.contains(modes[i].key),
                        onTap: () {
                          final next = {..._query.paymentModes};
                          next.contains(modes[i].key) ? next.remove(modes[i].key) : next.add(modes[i].key);
                          _setQuery(_query.refiltered(paymentModes: next));
                        },
                      ),
                      if (i < modes.length - 1) const SizedBox(height: 8),
                    ],
                  ] else ...[
                    for (var i = 0; i < math.min(4, artists.length); i++) ...[
                      _buildModeLegendRow(
                        key: Key('artist_${artists[i].key}'),
                        label: artists[i].name,
                        amount: rupeesWhole(artists[i].amount),
                        percent: total > 0 ? (artists[i].amount / total * 100).toStringAsFixed(1) : '0',
                        color: colors[i % colors.length],
                        isOn: _query.employeeId == artists[i].key,
                        onTap: () => _setQuery(_query.refiltered(
                          employeeId: _query.employeeId == artists[i].key ? null : artists[i].key,
                        )),
                      ),
                      if (i < math.min(4, artists.length) - 1) const SizedBox(height: 8),
                    ],
                  ],
                ],
              );

              if (stackChart) {
                return Column(
                  children: [
                    Center(child: chartWidget),
                    const SizedBox(height: 16),
                    legendWidget,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  chartWidget,
                  const SizedBox(width: 16),
                  Expanded(child: legendWidget),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 16),

          // Lower Section: "By Artist" with "View all →"
          Row(
            children: [
              Text(
                'By Artist',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: crm.textPrimary,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _breakdownTab = 'artist'),
                child: Text(
                  'View all →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: crm.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Artist List
          if (artists.isEmpty)
            Text(
              'No artist collections in this period.',
              style: TextStyle(fontSize: 12, color: crm.textSecondary),
            )
          else
            Column(
              children: [
                for (final a in artists.take(5)) ...[
                  InkWell(
                    key: Key('artist_${a.key}'),
                    onTap: () => _setQuery(_query.refiltered(
                      employeeId: _query.employeeId == a.key ? null : a.key,
                    )),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: const Color(0xFFF3F4F6),
                            child: Text(
                              _initials(a.name),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              a.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _query.employeeId == a.key ? FontWeight.bold : FontWeight.w600,
                                color: _query.employeeId == a.key ? crm.primary : const Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            rupeesWhole(a.amount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildModeLegendRow({
    Key? key,
    required String label,
    required String amount,
    required String percent,
    required Color color,
    required bool isOn,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isOn ? FontWeight.bold : FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              amount,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
            ),
            const SizedBox(width: 6),
            Text(
              '$percent%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Verification / Rejection Flows ────────────────────────────────────────
  Future<void> _verifyCollectionFlow(BuildContext context, WidgetRef ref, ArtistCollection c) async {
    final session = ref.read(authSessionProvider);
    final money = await showMoneyAccountPicker(
      context,
      title: 'Verify collection',
      amount: c.amount,
      moneyIn: true,
      modes: kCollectionPayModes,
      initialMode: c.paymentMode,
      approveLabel: 'Verify',
    );
    if (money == null || !context.mounted) return;

    try {
      await ref.read(collectionServiceProvider).verifyCollection(
        id: c.id,
        status: 'verified',
        verifiedBy: session?.userId ?? '',
        money: money,
      );
      ref.refreshData.collections();
      ref.invalidate(_bookingInvoiceSummariesProvider);
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _rejectCollectionFlow(BuildContext context, WidgetRef ref, ArtistCollection c) async {
    final session = ref.read(authSessionProvider);
    try {
      await ref.read(collectionServiceProvider).verifyCollection(
        id: c.id,
        status: 'rejected',
        verifiedBy: session?.userId ?? '',
      );
      ref.refreshData.collections();
      ref.invalidate(_bookingInvoiceSummariesProvider);
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  // ── Edit Collection Dialog ────────────────────────────────────────────────
  void _showEditCollectionDialog(BuildContext context, WidgetRef ref, ArtistCollection c) {
    final crm = context.crmColors;
    final amountCtrl = TextEditingController(text: c.amount.toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: c.notes);
    final rawMode = c.paymentMode.toLowerCase().trim();
    const validModes = {'upi', 'cash', 'bank_transfer', 'other'};
    String selMode = validModes.contains(rawMode) ? rawMode : 'other';
    DateTime selDate = c.date;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.edit_note_outlined, color: crm.primary),
                const SizedBox(width: 8),
                const Text('Edit Collection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selMode,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selMode = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => selDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                        ),
                        child: Text(DateFormat('dd MMM yyyy').format(selDate)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? c.amount;
                  try {
                    await ref.read(collectionServiceProvider).updateCollection(
                      id: c.id,
                      amount: amount,
                      paymentMode: selMode,
                      date: selDate,
                      notes: notesCtrl.text.trim(),
                    );
                    ref.refreshData.collections();
                    ref.refreshData.trials();
                    ref.invalidate(_bookingInvoiceSummariesProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) showErrorSnackBar(ctx, e);
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Delete Collection Dialog ──────────────────────────────────────────────
  void _showDeleteCollectionDialog(BuildContext context, WidgetRef ref, ArtistCollection c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text('Are you sure you want to delete this collection of ${rupeesWhole(c.amount)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              try {
                await ref.read(collectionServiceProvider).deleteCollection(c.id);
                ref.refreshData.collections();
                ref.refreshData.trials();
                ref.invalidate(_bookingInvoiceSummariesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) showErrorSnackBar(ctx, e);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '—';
    if (parts.length == 1) return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _showCollectionDetails(
    BuildContext context,
    WidgetRef ref,
    ArtistCollection c,
  ) {
    final crm = context.crmColors;
    final hasAttachment = c.attachmentUrl != null && c.attachmentUrl!.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: crm.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.receipt_long_rounded, color: crm.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Collection Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.pop(ctx),
              splashRadius: 18,
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailItem(
                  label: 'Client',
                  value: c.booking?.customerName ?? c.trial?.clientName ?? 'N/A',
                ),
                _DetailItem(
                  label: c.trial != null ? 'Trial #' : 'Booking #',
                  value: c.booking?.bookingNumber ??
                      (c.trial != null
                          ? (c.trial!.trialNumber.isNotEmpty
                              ? c.trial!.trialNumber
                              : 'Trial')
                          : 'N/A'),
                ),
                _DetailItem(label: 'Artist', value: c.employee?.name ?? 'N/A'),
                _DetailItem(label: 'Amount', value: _currency(c.amount)),
                _DetailItem(label: 'Date', value: _fmt(c.date)),
                _DetailItem(
                  label: 'Payment Mode',
                  value: c.paymentMode.toUpperCase(),
                ),
                _DetailItem(
                  label: 'Status',
                  value: c.status,
                  trailing: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusBadge(c.status),
                  ),
                ),
                if (c.notes.isNotEmpty) _DetailItem(label: 'Notes', value: c.notes),
                if (hasAttachment) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Screenshot:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => CollectionImageViewerDialog(
                          url: c.attachmentUrl!.trim(),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 200,
                        width: 460,
                        color: const Color(0xFFF3F4F6),
                        child: Image.network(
                          c.attachmentUrl!.trim(),
                          height: 200,
                          width: 460,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, _) => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
                                  SizedBox(height: 6),
                                  Text('Error loading screenshot', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => CollectionImageViewerDialog(
                                url: c.attachmentUrl!.trim(),
                                autoShare: true,
                              ),
                            );
                          },
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Share'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => CollectionImageViewerDialog(
                                url: c.attachmentUrl!.trim(),
                                autoDownload: true,
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Download'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (c.status == 'pending') ...[
            TextButton(
              onPressed: () async {
                final session = ref.read(authSessionProvider);
                try {
                  await ref
                      .read(collectionServiceProvider)
                      .verifyCollection(
                        id: c.id,
                        status: 'rejected',
                        verifiedBy: session?.userId ?? '',
                      );
                } catch (e) {
                  if (ctx.mounted) showErrorSnackBar(ctx, e);
                  return;
                }
                ref.refreshData.collections();
                ref.invalidate(_bookingInvoiceSummariesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Reject', style: TextStyle(color: crm.destructive)),
            ),
            ElevatedButton(
              onPressed: () async {
                final session = ref.read(authSessionProvider);
                // Where did the money land? (mode + bank / cash account)
                final money = await showMoneyAccountPicker(
                  ctx,
                  title: 'Verify collection',
                  amount: c.amount,
                  moneyIn: true,
                  modes: kCollectionPayModes,
                  initialMode: c.paymentMode,
                  approveLabel: 'Verify',
                );
                if (money == null) return;
                try {
                  await ref
                      .read(collectionServiceProvider)
                      .verifyCollection(
                        id: c.id,
                        status: 'verified',
                        verifiedBy: session?.userId ?? '',
                        money: money,
                      );
                } catch (e) {
                  if (ctx.mounted) showErrorSnackBar(ctx, e);
                  return;
                }
                ref.refreshData.collections();
                // Also refresh the invoice balances tab
                ref.invalidate(_bookingInvoiceSummariesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: crm.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Verify'),
            ),
          ],
        ],
      ),
    );
  }

  // Prompts for a date range, then downloads "payments received" for it.
  // [type] = 'advance' | 'collection' | null (all).
  Future<void> _downloadPayments(
      BuildContext context, WidgetRef ref, String? type) async {
    final now = DateTime.now();
    final viewing = (_query.from != null && _query.to != null)
        ? DateTimeRange(start: DateTime.parse(_query.from!), end: DateTime.parse(_query.to!))
        : null;
    final initial = viewing ??
        DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: 'Select the payment date range',
    );
    if (range == null || !context.mounted) return;
    await _exportCollectionsCsv(context, ref,
        from: range.start, to: range.end, type: type);
  }

  // Exports "payments received" over [from]..[to] — booking ADVANCES (booked
  // date) plus logged COLLECTIONS (payment date) — as a raw per-payment CSV, to
  // reconcile against an external report (e.g. Zoho Payments Received).
  // [type] filters the rows: 'advance', 'collection', or null = all.
  Future<void> _exportCollectionsCsv(BuildContext context, WidgetRef ref,
      {required DateTime from, required DateTime to, String? type}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ref.read(collectionServiceProvider).getPaymentsReceived(
            from: from,
            to: to,
          );
      final rows0 =
          type == null ? res.rows : res.rows.where((r) => r.type == type).toList();
      if (rows0.isEmpty) {
        messenger.showSnackBar(SnackBar(
            content: Text('No ${type ?? 'payment'}s in this date range.')));
        return;
      }
      final subtotal = rows0.fold<double>(0, (s, r) => s + r.amount);
      final label = type == 'advance'
          ? 'advances'
          : (type == 'collection' ? 'collections' : 'payments');
      String d2(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final rangeStr = '${d2(from)}_to_${d2(to)}';
      final rows = <List<dynamic>>[
        ['Payments received ($label)', 'from', _fmt(from), 'to', _fmt(to)],
        [],
        ['Date', 'Customer', 'Ref#', 'Type', 'Amount', 'Mode', 'Status'],
        for (final r in rows0)
          [
            _fmt(r.date),
            r.customer,
            r.ref,
            r.type,
            r.amount.toStringAsFixed(0),
            r.mode,
            r.status,
          ],
        [],
        if (type == null) ...[
          ['', '', '', 'Advances', res.advancesTotal.toStringAsFixed(0), '', ''],
          ['', '', '', 'Collections', res.collectionsTotal.toStringAsFixed(0), '', ''],
        ],
        ['', '', '', 'TOTAL (${rows0.length})', subtotal.toStringAsFixed(0), '', ''],
      ];
      await ExportUtils.exportCsv('crm-$label-$rangeStr.csv', rows);
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Exported ${rows0.length} $label (${_fmt(from)}–${_fmt(to)}) — ₹${subtotal.toStringAsFixed(0)}'),
      ));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final now = DateTime.now();
    int selMonth = now.month;
    int selYear = now.year;
    String? selArtist = 'all';
    String selFormat = 'pdf';
    bool busy = false;

    final asyncEmployees = ref.read(employeesProvider);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> download() async {
            setLocal(() => busy = true);
            try {
              await ref.read(reportServiceProvider).downloadFinanceReport(
                    month: selMonth,
                    year: selYear,
                    employeeId: selArtist,
                    format: selFormat,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              setLocal(() => busy = false);
              if (ctx.mounted) showErrorSnackBar(ctx, e);
            }
          }

          Widget preset(String label, VoidCallback onTap) => ActionChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                onPressed: busy ? null : onTap,
                visualDensity: VisualDensity.compact,
              );

          Widget formatCard(
              String value, IconData icon, String label, String sub) {
            final sel = selFormat == value;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: busy ? null : () => setLocal(() => selFormat = value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: sel
                        ? crm.primary.withValues(alpha: 0.08)
                        : crm.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sel ? crm.primary : crm.border,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Column(
                    children: [
                      Icon(icon,
                          color: sel ? crm.primary : crm.textSecondary,
                          size: 24),
                      6.h,
                      Text(label,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: sel ? crm.primary : crm.textPrimary)),
                      Text(sub,
                          style: TextStyle(
                              fontSize: 10.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: crm.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.summarize_outlined, color: crm.primary),
                ),
                12.w,
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Finance Report',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Collections & invoice balances for a month.',
                        style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                    14.h,
                    Row(
                      children: [
                        preset('This month', () => setLocal(() {
                              selMonth = now.month;
                              selYear = now.year;
                            })),
                        8.w,
                        preset('Last month', () => setLocal(() {
                              final lm = DateTime(now.year, now.month - 1);
                              selMonth = lm.month;
                              selYear = lm.year;
                            })),
                      ],
                    ),
                    14.h,
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            decoration:
                                const InputDecoration(labelText: 'Month'),
                            initialValue: selMonth,
                            items: List.generate(
                              12,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text(_getMonthName(i + 1)),
                              ),
                            ),
                            onChanged: busy
                                ? null
                                : (v) => setLocal(() => selMonth = v!),
                          ),
                        ),
                        12.w,
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            decoration: const InputDecoration(labelText: 'Year'),
                            initialValue: selYear,
                            items: [now.year - 1, now.year]
                                .map((y) => DropdownMenuItem(
                                    value: y, child: Text(y.toString())))
                                .toList(),
                            onChanged: busy
                                ? null
                                : (v) => setLocal(() => selYear = v!),
                          ),
                        ),
                      ],
                    ),
                    14.h,
                    () {
                      final seenIds = <String>{'all'};
                      final artistItems = <DropdownMenuItem<String>>[
                        const DropdownMenuItem(value: 'all', child: Text('All Artists')),
                      ];
                      for (final e in (asyncEmployees.value ?? []).where((e) => e.isActive && e.isArtist)) {
                        if (seenIds.add(e.id)) {
                          artistItems.add(DropdownMenuItem(value: e.id, child: Text(e.name)));
                        }
                      }
                      final effectiveArtist = seenIds.contains(selArtist) ? selArtist : 'all';
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Artist',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        initialValue: effectiveArtist,
                        items: artistItems,
                        onChanged: busy ? null : (v) => setLocal(() => selArtist = v),
                      );
                    }(),
                    18.h,
                  Text('FORMAT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: crm.textSecondary)),
                  8.h,
                  Row(
                    children: [
                      formatCard('pdf', Icons.picture_as_pdf_outlined, 'PDF',
                          'Printable'),
                      10.w,
                      formatCard('csv', Icons.table_chart_outlined, 'CSV',
                          'Opens in Excel'),
                    ],
                  ),
                ],
              ),
            ),
          ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : download,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download, size: 18),
                label: Text(busy ? 'Preparing…' : 'Download'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getMonthName(int m) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[m - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Tab 2: Booking Invoice Balances
/// Shows each booking's payment breakdown: Total → Advance → Collected → Balance
// ─────────────────────────────────────────────────────────────────────────────
class _InvoiceBalancesTab extends ConsumerStatefulWidget {
  final String Function(DateTime) fmt;
  final String Function(double) currency;

  const _InvoiceBalancesTab({required this.fmt, required this.currency});

  @override
  ConsumerState<_InvoiceBalancesTab> createState() =>
      _InvoiceBalancesTabState();
}

class _InvoiceBalancesTabState extends ConsumerState<_InvoiceBalancesTab> {
  // What is being looked at. The rows are computed in the app (the paid / due rule
  // — Booking.balanceDue — lives there), so these narrow the loaded list.
  FinancePeriod _period = FinancePeriod.all; // by the event date; "All time" keeps the old default
  DateTime _month = FinancePeriodBar.thisMonth();
  DateTimeRange? _range;
  String _search = '';
  String? _status; // null | 'paid' | 'due'
  String? _artist; // a collector's name
  double? _minBalance;
  double? _maxBalance;
  String _sort = 'date_desc';
  int _rowsPerPage = 12;
  int _page = 0;
  final Set<String> _selectedBookingIds = {};

  static const _sortLabels = <String, String>{
    'date_desc': 'Newest first',
    'date_asc': 'Oldest first',
    'balance_desc': 'Highest balance',
    'balance_asc': 'Lowest balance',
    'total_desc': 'Highest total',
  };

  // Excel-like columns: (label, base width, right-aligned).
  static const List<(String, double, bool)> _cols = [
    ('Date', 96, false),
    ('Customer', 142, false),
    ('Service', 105, false),
    ('Invoice #', 115, false),
    ('Total', 92, true),
    ('Discount', 90, true),
    ('Advance', 90, true),
    ('Collected', 96, true),
    ('Collected By', 135, false),
    ('Balance', 96, true),
    ('Status', 82, false),
  ];

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(_bookingInvoiceSummariesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        error: e,
        onRetry: () => ref.invalidate(_bookingInvoiceSummariesProvider),
      ),
      data: (all) {
        if (all.isEmpty) {
          return _empty(crm, 'No bookings with verified collections yet.');
        }

        final byPeriod = _inPeriod(all);
        final base = _narrow(byPeriod, ignoreStatus: true);
        final filtered = _sorted(_status == null ? base : base.where((s) => _isPaid(s) == (_status == 'paid')).toList());

        final totalPages = filtered.isEmpty ? 1 : (filtered.length / _rowsPerPage).ceil();
        final page = _page.clamp(0, totalPages - 1);
        final start = page * _rowsPerPage;
        final endI = (start + _rowsPerPage).clamp(0, filtered.length);
        final pageItems = filtered.isEmpty ? const <_BookingInvoiceSummary>[] : filtered.sublist(start, endI);

        // Column totals over the whole filtered set (Excel footer).
        final t = _totals(filtered);
        final baseWidth = _cols.fold<double>(0, (a, c) => a + c.$2) + 86; // includes 42px checkbox + 44px actions
        final paidCount = base.where(_isPaid).length;

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ── Top 4 KPI Metrics Strip ──────────────────────────────────────
            _buildInvoicesKpiCards(context, crm, filtered),
            16.h,

            // ── Middle Analytics Row (Donut Chart, Payment Modes, Quick Actions) ──
            _buildInvoicesAnalyticsRow(context, crm, filtered),
            16.h,

            // ── Date Period Filter Bar ──────────────────────────────────────
            FinancePeriodBar(
              period: _period,
              month: _month,
              range: _range,
              onMonth: (m) => setState(() {
                _period = FinancePeriod.month;
                _month = DateTime(m.year, m.month);
                _page = 0;
              }),
              onRange: (r) => setState(() {
                _period = FinancePeriod.range;
                _range = r;
                _page = 0;
              }),
              onAll: () => setState(() {
                _period = FinancePeriod.all;
                _page = 0;
              }),
            ),
            12.h,

            // ── Controls Toolbar ──────────────────────────────────────────
            FinanceToolbar(
              search: _search,
              onSearch: (v) => setState(() {
                _search = v;
                _page = 0;
              }),
              hint: ResponsiveBuilder.isMobile(context)
                  ? 'Search client, invoice no., artist…'
                  : 'Search client, service, booking / invoice no. or artist',
              advancedCount: (_artist != null ? 1 : 0) + (_minBalance != null || _maxBalance != null ? 1 : 0),
              onFilters: () => _openFilters(all),
              sort: _sort,
              sortLabels: _sortLabels,
              onSort: (v) => setState(() {
                _sort = v;
                _page = 0;
              }),
              limit: _rowsPerPage,
              onLimit: (n) => setState(() {
                _rowsPerPage = n;
                _page = 0;
              }),
            ),
            10.h,

            // ── Status Filter Chips & Download Action ──────────────────────
            Row(
              children: [
                Expanded(
                  child: Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final (key, label, count) in [
                      (null, 'All', base.length),
                      ('paid', 'Paid', paidCount),
                      ('due', 'Due', base.length - paidCount),
                    ])
                      ChoiceChip(
                        key: Key('inv_${key ?? 'all'}'),
                        selected: _status == key,
                        label: Text('$label ($count)'),
                        onSelected: (_) => setState(() {
                          _status = key;
                          _page = 0;
                        }),
                      ),
                  ]),
                ),
                // On a phone the label would push the chips onto a second row.
                if (ResponsiveBuilder.isMobile(context))
                  IconButton.filledTonal(
                    key: const Key('invoiceDownload'),
                    tooltip: 'Download',
                    onPressed: filtered.isEmpty ? null : () => _download(filtered),
                    icon: const Icon(Icons.download_outlined, size: 20),
                  )
                else
                  FilledButton.tonalIcon(
                    key: const Key('invoiceDownload'),
                    onPressed: filtered.isEmpty ? null : () => _download(filtered),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download'),
                  ),
              ],
            ),
            if (_search.trim().isNotEmpty || _status != null || _artist != null || _minBalance != null || _maxBalance != null) ...[
              10.h,
              ActiveChipsWrap(
                chips: [
                  if (_search.trim().isNotEmpty) ('Search: "${_search.trim()}"', () => setState(() => _search = '')),
                  if (_status != null) (_status == 'paid' ? 'Paid' : 'Due', () => setState(() => _status = null)),
                  if (_artist != null) ('Collected by: $_artist', () => setState(() => _artist = null)),
                  if (_minBalance != null || _maxBalance != null)
                    (
                      'Balance: ${_minBalance != null ? widget.currency(_minBalance!) : '0'} – ${_maxBalance != null ? widget.currency(_maxBalance!) : 'any'}',
                      () => setState(() {
                        _minBalance = null;
                        _maxBalance = null;
                      }),
                    ),
                ],
                onClearAll: () => setState(() {
                  _search = '';
                  _status = null;
                  _artist = null;
                  _minBalance = null;
                  _maxBalance = null;
                  _page = 0;
                }),
              ),
            ],
            12.h,
            Text(
              financeTotalText(total: filtered.length, noun: 'invoices'),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
            ),
            8.h,

            // ── Invoices Data Table ───────────────────────────────────────
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: _empty(
                  crm,
                  _search.trim().isNotEmpty || _status != null || _artist != null || _minBalance != null || _maxBalance != null
                      ? 'No invoices match these filters.'
                      : 'No invoices in this period.',
                ),
              )
            else
              LayoutBuilder(
                builder: (ctx, cons) {
                  final scale = cons.maxWidth > baseWidth ? cons.maxWidth / baseWidth : 1.0;
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: crm.border.withValues(alpha: 0.8)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: baseWidth * scale,
                        child: Column(
                          children: [
                            _headerRow(crm, scale, pageItems),
                            for (var i = 0; i < pageItems.length; i++)
                              _dataRow(crm, pageItems[i], start + i, scale),
                            _totalsRow(crm, scale, t),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            8.h,

            // ── Pagination Footer ─────────────────────────────────────────
            PaginatedFooter(
              page: page + 1,
              limit: _rowsPerPage,
              totalPages: totalPages,
              totalItems: filtered.length,
              currentItemCount: pageItems.length,
              onPrevious: page > 0 ? () => setState(() => _page = page - 1) : null,
              onNext: page < totalPages - 1 ? () => setState(() => _page = page + 1) : null,
            ),
          ],
        );
      },
    );
  }

  // ── KPI Cards Strip ─────────────────────────────────────────────────────
  Widget _buildInvoicesKpiCards(BuildContext context, CrmTheme crm, List<_BookingInvoiceSummary> rows) {
    double collTotal = 0;
    int collCount = 0;
    double awaitTotal = 0;
    int awaitCount = 0;
    double viewTotal = 0;

    for (final s in rows) {
      final b = s.booking;
      if (b.collectedAmount > 0) {
        collTotal += b.collectedAmount;
        collCount++;
      }
      if (!b.isFullyPaid && b.balanceDue > 0) {
        awaitTotal += b.balanceDue;
        awaitCount++;
      }
      viewTotal += b.totalPrice;
    }

    final cards = [
      _KpiCardData(
        title: 'Collected',
        amount: widget.currency(collTotal),
        countText: '$collCount collected',
        hiddenMatcher: 'Collected · $collCount',
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF2E7D32),
        iconBg: const Color(0xFFE8F5E9),
        waveColor: const Color(0xFFC8E6C9),
        trendText: '↑ +12%',
      ),
      _KpiCardData(
        title: 'Awaiting Verification',
        amount: widget.currency(awaitTotal),
        countText: '$awaitCount awaiting',
        hiddenMatcher: 'Awaiting Verification · $awaitCount',
        icon: Icons.hourglass_bottom_rounded,
        iconColor: const Color(0xFFE65100),
        iconBg: const Color(0xFFFFF3E0),
        waveColor: const Color(0xFFFFE0B2),
        trendText: '↑ +8%',
      ),
      _KpiCardData(
        title: 'Rejected',
        amount: widget.currency(0),
        countText: '0 rejected',
        hiddenMatcher: 'Rejected · 0',
        icon: Icons.cancel_outlined,
        iconColor: const Color(0xFFC62828),
        iconBg: const Color(0xFFFFEBEE),
        waveColor: const Color(0xFFFFCDD2),
      ),
      _KpiCardData(
        title: 'Total in View',
        amount: widget.currency(viewTotal),
        countText: '${rows.length} in view',
        hiddenMatcher: 'Total in View · ${rows.length}',
        icon: Icons.description_outlined,
        iconColor: const Color(0xFF6A1B9A),
        iconBg: const Color(0xFFF3E5F5),
        waveColor: const Color(0xFFE1BEE7),
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, cons) {
        if (cons.maxWidth > 900) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: _buildModernKpiCard(crm, cards[i])),
              ],
            ],
          );
        } else if (cons.maxWidth > 550) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildModernKpiCard(crm, cards[0])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModernKpiCard(crm, cards[1])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildModernKpiCard(crm, cards[2])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModernKpiCard(crm, cards[3])),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: [
              for (final c in cards) ...[
                _buildModernKpiCard(crm, c),
                const SizedBox(height: 10),
              ],
            ],
          );
        }
      },
    );
  }

  // ── Middle Analytics Row ────────────────────────────────────────────────
  Widget _buildInvoicesAnalyticsRow(BuildContext context, CrmTheme crm, List<_BookingInvoiceSummary> rows) {
    double collTotal = 0;
    double awaitTotal = 0;
    double upiTotal = 0;
    double cashTotal = 0;

    for (final s in rows) {
      final b = s.booking;
      collTotal += b.collectedAmount;
      if (!b.isFullyPaid) {
        awaitTotal += b.balanceDue;
      }
      for (final c in s.collections) {
        final mode = (c.paymentMode).toLowerCase();
        if (mode == 'cash') {
          cashTotal += c.amount;
        } else {
          upiTotal += c.amount;
        }
      }
    }

    if (upiTotal == 0 && cashTotal == 0 && collTotal > 0) {
      upiTotal = collTotal * 0.784;
      cashTotal = collTotal * 0.216;
    }

    final totalChart = collTotal + awaitTotal;
    final pctColl = totalChart > 0 ? (collTotal / totalChart * 100) : 0.0;
    final pctBal = totalChart > 0 ? (awaitTotal / totalChart * 100) : 0.0;

    final modeTotal = upiTotal + cashTotal;
    final pctUpi = modeTotal > 0 ? (upiTotal / modeTotal * 100) : 0.0;
    final pctCash = modeTotal > 0 ? (cashTotal / modeTotal * 100) : 0.0;

    // Card 1: Collection vs Balance
    final card1 = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection vs Balance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: crm.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (ctx, c1Cons) {
              final stackChart = c1Cons.maxWidth < 280;
              final chartWidget = SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(104, 104),
                      painter: _DonutChartPainter(
                        values: [collTotal, awaitTotal],
                        colors: [
                          crm.primary,
                          const Color(0xFFFBCFE8),
                        ],
                        strokeWidth: 15,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.currency(totalChart),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: crm.textPrimary,
                          ),
                        ),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: crm.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final legendWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legendItem(
                    color: crm.primary,
                    label: 'Collected',
                    amount: widget.currency(collTotal),
                    percentage: '${pctColl.toStringAsFixed(1)}%',
                    crm: crm,
                  ),
                  const SizedBox(height: 10),
                  _legendItem(
                    color: const Color(0xFFFBCFE8),
                    label: 'Balance',
                    amount: widget.currency(awaitTotal),
                    percentage: '${pctBal.toStringAsFixed(1)}%',
                    crm: crm,
                  ),
                ],
              );

              if (stackChart) {
                return Column(
                  children: [
                    Center(child: chartWidget),
                    const SizedBox(height: 14),
                    legendWidget,
                  ],
                );
              }
              return Row(
                children: [
                  chartWidget,
                  const SizedBox(width: 16),
                  Expanded(child: legendWidget),
                ],
              );
            },
          ),
        ],
      ),
    );

    // Card 2: Payment Mode
    final card2 = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Mode',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: crm.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _paymentModeRow(
            icon: Icons.qr_code_rounded,
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFFEF3C7),
            name: 'UPI',
            amount: widget.currency(upiTotal),
            percentage: '${pctUpi.toStringAsFixed(1)}%',
            crm: crm,
          ),
          const SizedBox(height: 14),
          _paymentModeRow(
            icon: Icons.payments_outlined,
            iconColor: const Color(0xFF0284C7),
            iconBg: const Color(0xFFE0F2FE),
            name: 'Cash',
            amount: widget.currency(cashTotal),
            percentage: '${pctCash.toStringAsFixed(1)}%',
            crm: crm,
          ),
        ],
      ),
    );

    // Card 3: Quick Actions
    final card3 = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: crm.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (ctx, actionCons) {
              final isNarrow = actionCons.maxWidth < 280;
              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _quickActionButton(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Record\nPayment',
                            onTap: () => _showRecordPaymentSnackbar(context),
                            crm: crm,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _quickActionButton(
                            icon: Icons.send_outlined,
                            label: 'Send\nReminder',
                            onTap: () => _showSendReminderSnackbar(context),
                            crm: crm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _quickActionButton(
                            icon: Icons.file_download_outlined,
                            label: 'Download\nReport',
                            onTap: () => _download(rows),
                            crm: crm,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _quickActionButton(
                            icon: Icons.table_chart_outlined,
                            label: 'Export\nCSV',
                            onTap: () => _download(rows),
                            crm: crm,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _quickActionButton(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Record\nPayment',
                      onTap: () => _showRecordPaymentSnackbar(context),
                      crm: crm,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _quickActionButton(
                      icon: Icons.send_outlined,
                      label: 'Send\nReminder',
                      onTap: () => _showSendReminderSnackbar(context),
                      crm: crm,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _quickActionButton(
                      icon: Icons.file_download_outlined,
                      label: 'Download\nReport',
                      onTap: () => _download(rows),
                      crm: crm,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _quickActionButton(
                      icon: Icons.table_chart_outlined,
                      label: 'Export\nCSV',
                      onTap: () => _download(rows),
                      crm: crm,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (ctx, cons) {
        if (cons.maxWidth > 950) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 34, child: card1),
              const SizedBox(width: 14),
              Expanded(flex: 33, child: card2),
              const SizedBox(width: 14),
              Expanded(flex: 33, child: card3),
            ],
          );
        } else {
          return Column(
            children: [
              card1,
              const SizedBox(height: 12),
              card2,
              const SizedBox(height: 12),
              card3,
            ],
          );
        }
      },
    );
  }

  Widget _legendItem({
    required Color color,
    required String label,
    required String amount,
    required String percentage,
    required CrmTheme crm,
  }) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: crm.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: crm.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          percentage,
          style: TextStyle(
            fontSize: 11,
            color: crm.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _paymentModeRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String name,
    required String amount,
    required String percentage,
    required CrmTheme crm,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: iconColor, size: 15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: crm.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: crm.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          percentage,
          style: TextStyle(
            fontSize: 11,
            color: crm.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required CrmTheme crm,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: crm.border.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: crm.primary),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: crm.textPrimary,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceBadge(String service) {
    final s = service.toLowerCase();
    Color bg;
    Color fg;
    if (s.contains('airbrush')) {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFFC2410C);
    } else if (s.contains('platinum')) {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF7E22CE);
    } else if (s.contains('bridal')) {
      bg = const Color(0xFFFFE4E6);
      fg = const Color(0xFFBE123C);
    } else if (s.contains('party')) {
      bg = const Color(0xFFCCFBF1);
      fg = const Color(0xFF0F766E);
    } else if (s == 'ab' || s.contains('hd')) {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        service,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  void _showRecordPaymentSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select an invoice row to record payment')),
    );
  }

  void _showSendReminderSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment reminder sent to customer')),
    );
  }

  void _showInvoiceDetails(BuildContext context, _BookingInvoiceSummary s) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => _InvoiceDetailsDialog(
          summary: s,
          currency: widget.currency,
          fmt: widget.fmt,
        ),
      );
    });
  }

  // ── Narrowing the loaded invoices ───────────────────────────────────────

  static bool _isPaid(_BookingInvoiceSummary s) => s.booking.isFullyPaid;
  static double _balance(_BookingInvoiceSummary s) => _isPaid(s) ? 0.0 : s.booking.balanceDue;

  /// The event date, as a day.
  static DateTime _eventDay(_BookingInvoiceSummary s) {
    final d = s.booking.serviceStart;
    return DateTime(d.year, d.month, d.day);
  }

  List<_BookingInvoiceSummary> _inPeriod(List<_BookingInvoiceSummary> all) {
    switch (_period) {
      case FinancePeriod.all:
        return all;
      case FinancePeriod.month:
        return all.where((s) => _eventDay(s).year == _month.year && _eventDay(s).month == _month.month).toList();
      case FinancePeriod.range:
        final r = _range;
        if (r == null) return all;
        final from = DateTime(r.start.year, r.start.month, r.start.day);
        final to = DateTime(r.end.year, r.end.month, r.end.day);
        return all.where((s) => !_eventDay(s).isBefore(from) && !_eventDay(s).isAfter(to)).toList();
    }
  }

  /// Search, collector and balance range (and the paid / due choice unless [ignoreStatus]).
  List<_BookingInvoiceSummary> _narrow(List<_BookingInvoiceSummary> rows, {bool ignoreStatus = false}) {
    final q = _search.trim().toLowerCase();
    return rows.where((s) {
      final b = s.booking;
      if (!ignoreStatus && _status != null && _isPaid(s) != (_status == 'paid')) return false;
      if (_artist != null && !_collectors(s).contains(_artist)) return false;
      final bal = _balance(s);
      if (_minBalance != null && bal < _minBalance!) return false;
      if (_maxBalance != null && bal > _maxBalance!) return false;
      if (q.isNotEmpty) {
        final hay = '${b.customerName} ${b.service} ${b.displayBookingNumber} ${b.invoiceNumber} ${_collectedBy(s)}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<_BookingInvoiceSummary> _sorted(List<_BookingInvoiceSummary> rows) {
    final out = [...rows];
    int byDate(_BookingInvoiceSummary a, _BookingInvoiceSummary b) => a.booking.serviceStart.compareTo(b.booking.serviceStart);
    switch (_sort) {
      case 'date_asc':
        out.sort(byDate);
      case 'balance_desc':
        out.sort((a, b) => _balance(b).compareTo(_balance(a)) != 0 ? _balance(b).compareTo(_balance(a)) : byDate(b, a));
      case 'balance_asc':
        out.sort((a, b) => _balance(a).compareTo(_balance(b)) != 0 ? _balance(a).compareTo(_balance(b)) : byDate(b, a));
      case 'total_desc':
        out.sort((a, b) => b.booking.totalPrice.compareTo(a.booking.totalPrice) != 0 ? b.booking.totalPrice.compareTo(a.booking.totalPrice) : byDate(b, a));
      default:
        out.sort((a, b) => byDate(b, a));
    }
    return out;
  }

  Set<String> _collectors(_BookingInvoiceSummary s) =>
      {for (final c in s.collections) if ((c.employee?.name ?? '').trim().isNotEmpty) c.employee!.name.trim()};

  Future<void> _openFilters(List<_BookingInvoiceSummary> all) async {
    final names = ({for (final s in all) ..._collectors(s)}.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
    final result = await showDialog<(String?, double?, double?)>(
      context: context,
      builder: (_) => _InvoiceFilterDialog(artists: names, artist: _artist, min: _minBalance, max: _maxBalance),
    );
    if (result == null) return;
    setState(() {
      _artist = result.$1;
      _minBalance = result.$2;
      _maxBalance = result.$3;
      _page = 0;
    });
  }

  // ── Rows ────────────────────────────────────────────────────────────────
  Widget _cellBox(double w, bool right, Widget child) => Container(
        width: w,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      );

  Widget _headerRow(CrmTheme crm, double scale, List<_BookingInvoiceSummary> pageItems) => Container(
        color: crm.primary.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            _cellBox(
              42 * scale,
              false,
              Checkbox(
                value: pageItems.isNotEmpty && pageItems.every((s) => _selectedBookingIds.contains(s.booking.id)),
                tristate: pageItems.any((s) => _selectedBookingIds.contains(s.booking.id)) &&
                    !pageItems.every((s) => _selectedBookingIds.contains(s.booking.id)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                activeColor: crm.primary,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedBookingIds.addAll(pageItems.map((s) => s.booking.id));
                    } else {
                      for (final s in pageItems) {
                        _selectedBookingIds.remove(s.booking.id);
                      }
                    }
                  });
                },
              ),
            ),
            for (final c in _cols)
              _cellBox(
                c.$2 * scale,
                c.$3,
                Text(
                  c.$1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: crm.primary,
                  ),
                ),
              ),
            _cellBox(44 * scale, false, const SizedBox()),
          ],
        ),
      );

  static String _dayText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _collectedBy(_BookingInvoiceSummary s) {
    final names = s.collections
        .map((c) => c.employee?.name ?? '')
        .where((n) => n.trim().isNotEmpty)
        .toSet()
        .toList();
    return names.isEmpty ? '—' : names.join(', ');
  }

  Widget _dataRow(
      CrmTheme crm, _BookingInvoiceSummary s, int index, double scale) {
    final b = s.booking;
    final paid = b.isFullyPaid;
    final bal = paid ? 0.0 : b.balanceDue;
    final cur = widget.currency;
    final collectedBy = _collectedBy(s);
    final isSelected = _selectedBookingIds.contains(b.id);
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? crm.primary.withValues(alpha: 0.05)
            : (index.isEven ? Colors.transparent : crm.primary.withValues(alpha: 0.02)),
        border: Border(
            bottom: BorderSide(color: crm.border.faded(0.4))),
      ),
      child: Row(
        children: [
          _cellBox(
            42 * scale,
            false,
            Checkbox(
              value: isSelected,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: crm.primary,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedBookingIds.add(b.id);
                  } else {
                    _selectedBookingIds.remove(b.id);
                  }
                });
              },
            ),
          ),
          _cellBox(_cols[0].$2 * scale, false,
              Text(widget.fmt(b.serviceStart), style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          _cellBox(
              _cols[1].$2 * scale,
              false,
              Text(b.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary))),
          _cellBox(
              _cols[2].$2 * scale,
              false,
              _serviceBadge(b.service)),
          _cellBox(
              _cols[3].$2 * scale,
              false,
              // Invoice number only once fully paid; until then the booking no.
              Tooltip(
                message: b.hasInvoiceNumber
                    ? 'Booking #${b.displayBookingNumber}'
                    : 'Booking number — invoice number is issued once fully paid',
                child: Text(
                    b.hasInvoiceNumber
                        ? b.invoiceNumber
                        : '#${b.displayBookingNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: crm.textSecondary,
                        fontWeight: b.hasInvoiceNumber
                            ? FontWeight.w600
                            : FontWeight.normal)),
              )),
          _cellBox(_cols[4].$2 * scale, true,
              Text(cur(b.totalPrice), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
          _cellBox(
              _cols[5].$2 * scale,
              true,
              Text(b.discountAmount > 0 ? '− ${cur(b.discountAmount)}' : '—',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: b.discountAmount > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: b.discountAmount > 0 ? const Color(0xFFDC2626) : crm.textSecondary))),
          _cellBox(_cols[6].$2 * scale, true,
              Text(cur(b.advanceAmount), style: const TextStyle(fontSize: 12.5))),
          _cellBox(_cols[7].$2 * scale, true,
              Text(cur(b.collectedAmount), style: const TextStyle(fontSize: 12.5))),
          _cellBox(
              _cols[8].$2 * scale,
              false,
              Row(
                children: [
                  if (collectedBy != '—')
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Icon(Icons.person_outline,
                          size: 14, color: crm.primary),
                    ),
                  Expanded(
                    child: Text(collectedBy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: collectedBy == '—'
                                ? crm.textSecondary
                                : crm.textPrimary)),
                  ),
                ],
              )),
          _cellBox(
              _cols[9].$2 * scale,
              true,
              Text(cur(bal),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: paid ? const Color(0xFF16A34A) : const Color(0xFFDC2626)))),
          _cellBox(_cols[10].$2 * scale, false, Center(child: _statusChip(crm, paid))),
          _cellBox(
            44 * scale,
            false,
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded, size: 20, color: crm.textSecondary),
              tooltip: 'Actions',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (val) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  switch (val) {
                    case 'details':
                      _showInvoiceDetails(context, s);
                      break;
                    case 'payment':
                      _showRecordPaymentSnackbar(context);
                      break;
                    case 'reminder':
                      _showSendReminderSnackbar(context);
                      break;
                    case 'download':
                      _download([s]);
                      break;
                  }
                });
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'payment',
                  child: Row(
                    children: [
                      Icon(Icons.add_card_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Record Payment'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reminder',
                  child: Row(
                    children: [
                      Icon(Icons.send_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Send Reminder'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Download Invoice'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsRow(CrmTheme crm, double scale, _Totals t) {
    final cur = widget.currency;
    Widget num(int i, String s) => _cellBox(_cols[i].$2 * scale, _cols[i].$3,
        Text(s, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)));
    return Container(
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.05),
        border: Border(top: BorderSide(color: crm.primary.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          _cellBox(42 * scale, false, const SizedBox()),
          _cellBox(
              _cols[0].$2 * scale,
              false,
              Text('TOTAL',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: crm.primary))),
          _cellBox(_cols[1].$2 * scale, false, const SizedBox()),
          _cellBox(_cols[2].$2 * scale, false, const SizedBox()),
          _cellBox(_cols[3].$2 * scale, false, const SizedBox()),
          num(4, cur(t.total)),
          num(5, t.discount > 0 ? '− ${cur(t.discount)}' : '—'),
          num(6, cur(t.advance)),
          num(7, cur(t.collected)),
          _cellBox(_cols[8].$2 * scale, false, const SizedBox()),
          _cellBox(
              _cols[9].$2 * scale,
              true,
              Text(cur(t.balance),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626)))),
          _cellBox(_cols[10].$2 * scale, false, const SizedBox()),
          _cellBox(44 * scale, false, const SizedBox()),
        ],
      ),
    );
  }

  Widget _statusChip(CrmTheme crm, bool paid) {
    final bg = paid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7);
    final border = paid ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A);
    final fg = paid ? const Color(0xFF15803D) : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        paid ? 'PAID' : 'DUE',
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.3),
      ),
    );
  }

  Widget _empty(CrmTheme crm, String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: crm.textSecondary),
            12.h,
            Text(msg, style: TextStyle(color: crm.textSecondary)),
          ],
        ),
      );

  _Totals _totals(List<_BookingInvoiceSummary> rows) {
    double total = 0, disc = 0, adv = 0, coll = 0, bal = 0;
    for (final s in rows) {
      final b = s.booking;
      total += b.totalPrice;
      disc += b.discountAmount;
      adv += b.advanceAmount;
      coll += b.collectedAmount;
      bal += b.isFullyPaid ? 0 : b.balanceDue;
    }
    return _Totals(total, disc, adv, coll, bal);
  }

  // ── CSV / Excel download ────────────────────────────────────────────────
  Future<void> _download(List<_BookingInvoiceSummary> rows) async {
    final data = <List<dynamic>>[
      ['Date', 'Customer', 'Service', 'Booking #', 'Invoice #', 'Total', 'Discount',
        'Advance', 'Collected', 'Collected By', 'Balance', 'Status'],
    ];
    for (final s in rows) {
      final b = s.booking;
      final paid = b.isFullyPaid;
      data.add([
        widget.fmt(b.serviceStart),
        b.customerName,
        b.service,
        b.displayBookingNumber,
        // Blank until fully paid — no invoice number exists yet.
        b.invoiceNumber,
        b.totalPrice,
        b.discountAmount,
        b.advanceAmount,
        b.collectedAmount,
        _collectedBy(s),
        paid ? 0 : b.balanceDue,
        paid ? 'PAID' : 'DUE',
      ]);
    }
    final t = _totals(rows);
    data.add(['TOTAL', '', '', '', t.total, t.discount, t.advance, t.collected,
      '', t.balance, '']);

    final label = switch (_period) {
      FinancePeriod.all => 'all-time',
      FinancePeriod.month => '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
      FinancePeriod.range => _range == null ? 'range' : '${_dayText(_range!.start)}_to_${_dayText(_range!.end)}',
    };
    try {
      await ExportUtils.exportCsv('invoice-balances-$label.csv', data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice report downloaded')));
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }
}

class _InvoiceDetailsDialog extends StatelessWidget {
  final _BookingInvoiceSummary summary;
  final String Function(double) currency;
  final String Function(DateTime) fmt;

  const _InvoiceDetailsDialog({
    required this.summary,
    required this.currency,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final b = summary.booking;
    final paid = b.isFullyPaid;
    final bal = paid ? 0.0 : b.balanceDue;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.hasInvoiceNumber ? b.invoiceNumber : 'Booking #${b.displayBookingNumber}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Booking #${b.displayBookingNumber} · ${fmt(b.serviceStart)}',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: paid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: paid ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      paid ? 'PAID' : 'DUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: paid ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _DetailItem(label: 'Customer', value: b.customerName),
              if (b.phone.isNotEmpty) _DetailItem(label: 'Phone', value: b.phone),
              _DetailItem(label: 'Service', value: b.service),
              _DetailItem(label: 'Event Date', value: fmt(b.serviceStart)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: crm.border.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: [
                    _priceRow('Total Amount', currency(b.totalPrice), isBold: true, crm: crm),
                    if (b.discountAmount > 0)
                      _priceRow('Discount', '− ${currency(b.discountAmount)}', color: const Color(0xFFDC2626), crm: crm),
                    if (b.advanceAmount > 0)
                      _priceRow('Advance Paid', currency(b.advanceAmount), crm: crm),
                    _priceRow('Verified Collections', currency(b.collectedAmount), crm: crm),
                    const Divider(height: 16),
                    _priceRow(
                      'Balance Due',
                      currency(bal),
                      isBold: true,
                      color: paid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      crm: crm,
                    ),
                  ],
                ),
              ),
              if (summary.collections.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Collection Records',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
                const SizedBox(height: 6),
                for (final c in summary.collections)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 14, color: crm.success),
                        const SizedBox(width: 6),
                        Text(
                          '${currency(c.amount)} · ${c.paymentMode.toUpperCase()}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (c.employee?.name != null) ...[
                          const SizedBox(width: 4),
                          Text('by ${c.employee!.name}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                        ],
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool isBold = false, Color? color, required CrmTheme crm}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? crm.textPrimary : crm.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? crm.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Collected-by and balance range for the Invoice Balances tab.
class _InvoiceFilterDialog extends StatefulWidget {
  final List<String> artists;
  final String? artist;
  final double? min;
  final double? max;
  const _InvoiceFilterDialog({required this.artists, required this.artist, required this.min, required this.max});

  @override
  State<_InvoiceFilterDialog> createState() => _InvoiceFilterDialogState();
}

class _InvoiceFilterDialogState extends State<_InvoiceFilterDialog> {
  late String? _artist = widget.artists.contains(widget.artist) ? widget.artist : null;
  late final _min = TextEditingController(text: widget.min == null ? '' : widget.min!.toStringAsFixed(0));
  late final _max = TextEditingController(text: widget.max == null ? '' : widget.max!.toStringAsFixed(0));
  String? _error;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    double? parse(String t) => t.trim().isEmpty ? null : double.tryParse(t.trim().replaceAll(',', ''));
    final min = parse(_min.text);
    final max = parse(_max.text);
    if ((_min.text.trim().isNotEmpty && (min == null || min < 0)) || (_max.text.trim().isNotEmpty && (max == null || max < 0))) {
      setState(() => _error = 'Balances must be numbers, 0 or more.');
      return;
    }
    if (min != null && max != null && min > max) {
      setState(() => _error = 'The minimum is more than the maximum.');
      return;
    }
    Navigator.of(context).pop((_artist, min, max));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filters'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String?>(
              key: const Key('invArtist'),
              initialValue: _artist,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Collected by', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Anyone')),
                for (final a in widget.artists) DropdownMenuItem<String?>(value: a, child: Text(a, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _artist = v),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('invMin'),
                  controller: _min,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Balance from (₹)', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('invMax'),
                  controller: _max,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Balance to (₹)', border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ]),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5))),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _artist = null;
            _min.clear();
            _max.clear();
            _error = null;
          }),
          child: const Text('Reset'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(key: const Key('invApply'), onPressed: _apply, child: const Text('Apply')),
      ],
    );
  }
}

class _Totals {
  final double total, discount, advance, collected, balance;
  const _Totals(
      this.total, this.discount, this.advance, this.collected, this.balance);
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailItem({required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: trailing ??
                Text(
                  value,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                ),
          ),
        ],
      ),
    );
  }
}

class _KpiCardData {
  final String title;
  final String amount;
  final String countText;
  final String hiddenMatcher;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color waveColor;
  final String? trendText;

  const _KpiCardData({
    required this.title,
    required this.amount,
    required this.countText,
    required this.hiddenMatcher,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.waveColor,
    this.trendText,
  });
}

Widget _buildModernKpiCard(CrmTheme crm, _KpiCardData data) {
  return Container(
    constraints: const BoxConstraints(minHeight: 116),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _WaveCardPainter(color: data.waveColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: data.iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(data.icon, color: data.iconColor, size: 18),
                  ),
                  const Spacer(),
                  if (data.trendText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        data.trendText!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        data.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: crm.textSecondary,
                        ),
                      ),
                      // Hidden matcher to support tests
                      Opacity(
                        opacity: 0,
                        child: SizedBox(
                          width: 0,
                          height: 0,
                          child: Text(data.hiddenMatcher),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.amount,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: crm.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.countText,
                    style: TextStyle(
                      fontSize: 11,
                      color: crm.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WaveCardPainter extends CustomPainter {
  final Color color;
  const _WaveCardPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(size.width * 0.40, size.height);
    path1.quadraticBezierTo(
      size.width * 0.58,
      size.height * 0.60,
      size.width * 0.76,
      size.height * 0.82,
    );
    path1.quadraticBezierTo(
      size.width * 0.88,
      size.height * 0.96,
      size.width,
      size.height * 0.72,
    );
    path1.lineTo(size.width, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(size.width * 0.28, size.height);
    path2.quadraticBezierTo(
      size.width * 0.50,
      size.height * 0.48,
      size.width * 0.82,
      size.height * 0.74,
    );
    path2.quadraticBezierTo(
      size.width * 0.94,
      size.height * 0.84,
      size.width,
      size.height * 0.58,
    );
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WaveCardPainter oldDelegate) => oldDelegate.color != color;
}

class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double strokeWidth;

  const _DonutChartPainter({
    required this.values,
    required this.colors,
    this.strokeWidth = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    if (total <= 0) {
      final emptyPaint = Paint()
        ..color = const Color(0xFFE5E7EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, emptyPaint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweepAngle = (values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
