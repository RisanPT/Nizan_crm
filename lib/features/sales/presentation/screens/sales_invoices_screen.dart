import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/space_extension.dart';
import '../../../../core/models/booking.dart';
import '../../../../core/models/trial.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/providers/trial_provider.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/dashboard_report_service.dart';
import '../../../../core/utils/responsive_builder.dart';
import '../../../../services/employee_service.dart';
import '../../../../services/package_service.dart';
import '../../../../presentation/widgets/export_sales_report_dialog.dart';
import '../../../../core/utils/booking_print_service.dart';
import '../../../../services/zone_service.dart';
import '../../../../services/state_service.dart';
import '../../../../services/region_service.dart';
import '../../../../services/district_service.dart';
import '../../../../core/models/geographic_state.dart';
import '../../../../core/models/service_region.dart';
import '../../../../core/models/district.dart';
import '../../../../core/models/zone.dart';

part '../widgets/sales_components.dart';
part '../widgets/sales_monthly_summary.dart';

class SalesBookingsScreen extends HookConsumerWidget {
  const SalesBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final theme = Theme.of(context);
    final isMobile = ResponsiveBuilder.isMobile(context);
    final selectedIds = useState<Set<String>>(<String>{});
    final pageState = useState(1);
    final searchCtrl = useTextEditingController();
    final searchQuery = useState('');
    final duplicatesOnly = useState(false);
    final isMonthlyView = useState(false);
    final selectedFY = useState<String>('2026-27');
    final dateBasis = useState<String>('event_date');
    const pageSize = 20;

    final selectedZoneId = useState<String>('');
    final selectedStateId = useState<String>('');
    final selectedRegionId = useState<String>('');
    final selectedDistrictId = useState<String>('');

    final asyncZones = ref.watch(zonesProvider);
    final asyncStates = ref.watch(statesProvider);
    final asyncRegions = ref.watch(regionsProvider);
    final asyncDistricts = ref.watch(districtsProvider);

    final allZones = asyncZones.value ?? [];
    final allStates = asyncStates.value ?? [];
    final allRegions = asyncRegions.value ?? [];
    final allDistricts = asyncDistricts.value ?? [];

    final filteredStates = selectedZoneId.value.isEmpty
        ? allStates
        : allStates.where((s) => s.zoneId == selectedZoneId.value).toList();

    final filteredRegions = selectedStateId.value.isEmpty
        ? allRegions
        : allRegions.where((r) => r.stateId == selectedStateId.value).toList();

    final filteredDistricts = selectedRegionId.value.isEmpty
        ? allDistricts
        : allDistricts.where((d) => d.regionId == selectedRegionId.value).toList();

    final financialYears = ['2026-27', '2025-26', '2024-25', '2023-24'];

    final pageParams = PaginatedBookingsParams(
      page: pageState.value,
      limit: pageSize,
      search: searchQuery.value,
      duplicatesOnly: duplicatesOnly.value,
      financialYear: selectedFY.value,
      dateBasis: dateBasis.value,
      zoneId: selectedZoneId.value.isEmpty ? null : selectedZoneId.value,
      stateId: selectedStateId.value.isEmpty ? null : selectedStateId.value,
      regionId: selectedRegionId.value.isEmpty ? null : selectedRegionId.value,
      districtId: selectedDistrictId.value.isEmpty ? null : selectedDistrictId.value,
    );
    final asyncPaginatedBookings = ref.watch(
      paginatedBookingsProvider(pageParams),
    );
    final asyncAllBookings = ref.watch(bookingProvider);
    final allBookings = asyncAllBookings.value ?? const <Booking>[];
    final allTrials = ref.watch(allTrialsProvider).value ?? const <Trial>[];

    final now = DateTime.now();
    final useEventDateVal = dateBasis.value == 'event_date';

    bool bookingMatchesGeoFilters(Booking b) {
      if (selectedDistrictId.value.isNotEmpty && b.districtId != selectedDistrictId.value) {
        return false;
      }
      if (selectedRegionId.value.isNotEmpty && b.regionId != selectedRegionId.value) {
        return false;
      }
      if (selectedStateId.value.isNotEmpty) {
        final region = allRegions.cast<ServiceRegion?>().firstWhere((r) => r?.id == b.regionId, orElse: () => null);
        if (region == null || region.stateId != selectedStateId.value) {
          return false;
        }
      }
      if (selectedZoneId.value.isNotEmpty) {
        final region = allRegions.cast<ServiceRegion?>().firstWhere((r) => r?.id == b.regionId, orElse: () => null);
        if (region == null) return false;
        final state = allStates.cast<GeographicState?>().firstWhere((s) => s?.id == region.stateId, orElse: () => null);
        if (state == null || state.zoneId != selectedZoneId.value) {
          return false;
        }
      }
      return true;
    }

    final geoFilteredAllBookings = allBookings.where(bookingMatchesGeoFilters).toList();

    int countPackages(Iterable<Booking> bookings) {
      return bookings.fold(0, (sum, b) => sum + (b.bookingItems.isEmpty ? 1 : b.bookingItems.length));
    }

    final todaysScheduled = countPackages(geoFilteredAllBookings.where((b) {
      final d = useEventDateVal ? b.bookingDate : (b.createdAt ?? b.bookingDate);
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }));

    final todaysCompleted = countPackages(geoFilteredAllBookings.where((b) {
      final d = useEventDateVal ? b.bookingDate : (b.createdAt ?? b.bookingDate);
      return b.status.toLowerCase() == 'completed' &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }));
    
    // Financial year comes from the selected dropdown (e.g. "2026-27" =>
    // 1 Apr 2026 to 31 Mar 2027), NOT from today's date.
    final fyStartYear =
        int.tryParse(selectedFY.value.split('-').first) ?? now.year;
    final fyStart = DateTime(fyStartYear, 4, 1);
    final fyEnd = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59);
    final fyBookings = geoFilteredAllBookings.where((b) {
      final d = useEventDateVal ? b.bookingDate : (b.createdAt ?? b.bookingDate);
      return !d.isBefore(fyStart) && !d.isAfter(fyEnd);
    });


    final totalSalesValue = geoFilteredAllBookings.fold<double>(0, (sum, b) => b.status.toLowerCase() != 'cancelled' && b.status.toLowerCase() != 'postponed' ? sum + b.totalPrice : sum);
    final advanceCollectedFY = fyBookings.fold<double>(0, (sum, b) => b.status.toLowerCase() != 'cancelled' && b.status.toLowerCase() != 'postponed' ? sum + b.advanceAmount : sum);

    // ── Today vs Yesterday · Total revenue · Q1–Q4 works (selected FY) ──────
    DateTime dateOf(Booking b) =>
        useEventDateVal ? b.bookingDate : (b.createdAt ?? b.bookingDate);
    bool isActiveBooking(Booking b) {
      final s = b.status.toLowerCase();
      return s != 'cancelled' && s != 'postponed' && s != 'rejected';
    }
    bool onSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Trials are studio-wide (no region), so include them only when no location
    // filter is active. Each non-cancelled trial adds its item-price sum as
    // revenue and counts as one work.
    final includeTrials = selectedZoneId.value.isEmpty &&
        selectedStateId.value.isEmpty &&
        selectedRegionId.value.isEmpty &&
        selectedDistrictId.value.isEmpty;
    final salesTrials = includeTrials
        ? allTrials
            .where((t) => t.status.toLowerCase() != 'cancelled')
            .toList()
        : const <Trial>[];
    double trialAmount(Trial t) =>
        t.trialItems.fold<double>(0, (s, i) => s + i.price);
    bool trialInFY(Trial t) =>
        !t.trialDate.isBefore(fyStart) && !t.trialDate.isAfter(fyEnd);

    double revenueOn(DateTime day) =>
        geoFilteredAllBookings
            .where((b) => isActiveBooking(b) && onSameDay(dateOf(b), day))
            .fold<double>(0, (s, b) => s + b.totalPrice) +
        salesTrials
            .where((t) => onSameDay(t.trialDate, day))
            .fold<double>(0, (s, t) => s + trialAmount(t));
    int worksOn(DateTime day) =>
        countPackages(geoFilteredAllBookings
            .where((b) => isActiveBooking(b) && onSameDay(dateOf(b), day))) +
        salesTrials.where((t) => onSameDay(t.trialDate, day)).length;

    final todaySales = revenueOn(today);
    final yesterdaySales = revenueOn(yesterday);
    final todayWorks = worksOn(today);
    final yesterdayWorks = worksOn(yesterday);
    final salesTrend = yesterdaySales <= 0
        ? null
        : (todaySales - yesterdaySales) / yesterdaySales * 100;

    final totalRevenueFY =
        fyBookings.where(isActiveBooking).fold<double>(0, (s, b) => s + b.totalPrice) +
        salesTrials
            .where(trialInFY)
            .fold<double>(0, (s, t) => s + trialAmount(t));

    // Indian FY quarters: Q1 Apr–Jun, Q2 Jul–Sep, Q3 Oct–Dec, Q4 Jan–Mar.
    int quarterIndex(int month) {
      if (month >= 4 && month <= 6) return 0;
      if (month >= 7 && month <= 9) return 1;
      if (month >= 10 && month <= 12) return 2;
      return 3;
    }
    final quarterWorks = List<int>.filled(4, 0);
    for (final b in fyBookings.where(isActiveBooking)) {
      quarterWorks[quarterIndex(dateOf(b).month)] +=
          b.bookingItems.isEmpty ? 1 : b.bookingItems.length;
    }
    for (final t in salesTrials.where(trialInFY)) {
      quarterWorks[quarterIndex(t.trialDate.month)] += 1;
    }



    final currentMonthKey = '${now.year}-${now.month}';
    final monthBookings = geoFilteredAllBookings.where((b) {
      final d = useEventDateVal ? b.bookingDate : (b.createdAt ?? b.bookingDate);
      return '${d.year}-${d.month}' == currentMonthKey && b.status.toLowerCase() != 'cancelled' && b.status.toLowerCase() != 'postponed';
    }).toList();

    final forecastSales = monthBookings.fold<double>(
      0,
      (sum, b) => sum + b.totalPrice,
    );

    final forecastCollection = monthBookings.where((b) => b.status.toLowerCase() != 'completed').fold<double>(
      0,
      (sum, b) => sum + (b.totalPrice - b.advanceAmount - b.discountAmount).clamp(0, double.infinity),
    );



    Future<void> exportReport() async {
      final packages = ref.read(packagesProvider).value;
      final employees = ref.read(employeesProvider).value;

      if (packages == null || employees == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait until dashboard data finishes loading.'),
          ),
        );
        return;
      }

      final activeFiltersStr = (() {
        final List<String> parts = [];
        if (selectedZoneId.value.isNotEmpty) {
          final zone = allZones.cast<ZoneModel?>().firstWhere((z) => z?.id == selectedZoneId.value, orElse: () => null);
          if (zone != null) parts.add('Zone: ${zone.name}');
        }
        if (selectedStateId.value.isNotEmpty) {
          final state = allStates.cast<GeographicState?>().firstWhere((s) => s?.id == selectedStateId.value, orElse: () => null);
          if (state != null) parts.add('State: ${state.name}');
        }
        if (selectedRegionId.value.isNotEmpty) {
          final region = allRegions.cast<ServiceRegion?>().firstWhere((r) => r?.id == selectedRegionId.value, orElse: () => null);
          if (region != null) parts.add('Region: ${region.name}');
        }
        if (selectedDistrictId.value.isNotEmpty) {
          final district = allDistricts.cast<District?>().firstWhere((d) => d?.id == selectedDistrictId.value, orElse: () => null);
          if (district != null) parts.add('District: ${district.name}');
        }
        return parts.isEmpty ? 'All Bookings' : parts.join(' • ');
      })();

      showDialog(
        context: context,
        builder: (dialogCtx) => ExportSalesReportDialog(
          financialYear: selectedFY.value,
          activeFilters: activeFiltersStr,
          initialUseEventDate: useEventDateVal,
          onTodayReport: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () => downloadDashboardReport(
              month: DateTime.now(),
              bookings: geoFilteredAllBookings,
              packages: packages,
              employees: employees,
              reportType: 'ceo_daily',
              useEventDate: useEventDate,
              districts: allDistricts,
              activeFilters: activeFiltersStr,
            ),
          ),
          onDailyPerformance: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () => downloadDashboardReport(
              month: DateTime.now(),
              bookings: geoFilteredAllBookings,
              packages: packages,
              employees: employees,
              reportType: 'sales',
              useEventDate: useEventDate,
              districts: allDistricts,
              activeFilters: activeFiltersStr,
            ),
          ),
          onExecutiveSummary: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () => downloadDashboardReport(
              month: DateTime.now(),
              bookings: geoFilteredAllBookings,
              packages: packages,
              employees: employees,
              reportType: 'executive',
              useEventDate: useEventDate,
              districts: allDistricts,
              activeFilters: activeFiltersStr,
            ),
          ),
          onFullLedger: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () => downloadDashboardReport(
              month: DateTime.now(),
              bookings: geoFilteredAllBookings,
              packages: packages,
              employees: employees,
              reportType: 'crm',
              useEventDate: useEventDate,
              districts: allDistricts,
              activeFilters: activeFiltersStr,
            ),
          ),
          onMonthEndCashFlowReport: (useEventDate, selectedMonth, transactionType) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () => downloadDashboardReport(
              month: selectedMonth,
              bookings: geoFilteredAllBookings,
              packages: packages,
              employees: employees,
              reportType: 'month_end_cashflow_$transactionType',
              useEventDate: useEventDate,
              districts: allDistricts,
              activeFilters: activeFiltersStr,
            ),
          ),
          onForecastReport: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () => downloadDashboardReport(
              month: DateTime.now(),
              bookings: geoFilteredAllBookings,
              packages: packages,
              employees: employees,
              reportType: 'forecast',
              useEventDate: useEventDate,
              districts: allDistricts,
              activeFilters: activeFiltersStr,
            ),
          ),
          onAprJunReport: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () {
              final parts = selectedFY.value.split('-');
              final startYear = int.parse(parts[0]);
              return downloadDashboardReport(
                month: DateTime(startYear, 4),
                bookings: geoFilteredAllBookings,
                packages: packages,
                employees: employees,
                reportType: 'sales',
                useEventDate: useEventDate,
                startDate: DateTime(startYear, 4, 1),
                endDate: DateTime(startYear, 6, 30, 23, 59, 59),
                districts: allDistricts,
                activeFilters: activeFiltersStr,
              );
            },
          ),
          onJulSepReport: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () {
              final parts = selectedFY.value.split('-');
              final startYear = int.parse(parts[0]);
              return downloadDashboardReport(
                month: DateTime(startYear, 7),
                bookings: geoFilteredAllBookings,
                packages: packages,
                employees: employees,
                reportType: 'sales',
                useEventDate: useEventDate,
                startDate: DateTime(startYear, 7, 1),
                endDate: DateTime(startYear, 9, 30, 23, 59, 59),
                districts: allDistricts,
                activeFilters: activeFiltersStr,
              );
            },
          ),
          onOctDecReport: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () {
              final parts = selectedFY.value.split('-');
              final startYear = int.parse(parts[0]);
              return downloadDashboardReport(
                month: DateTime(startYear, 10),
                bookings: geoFilteredAllBookings,
                packages: packages,
                employees: employees,
                reportType: 'sales',
                useEventDate: useEventDate,
                startDate: DateTime(startYear, 10, 1),
                endDate: DateTime(startYear, 12, 31, 23, 59, 59),
                districts: allDistricts,
                activeFilters: activeFiltersStr,
              );
            },
          ),
          onJanMarReport: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () {
              final parts = selectedFY.value.split('-');
              final endYear = 2000 + int.parse(parts[1]);
              return downloadDashboardReport(
                month: DateTime(endYear, 1),
                bookings: geoFilteredAllBookings,
                packages: packages,
                employees: employees,
                reportType: 'sales',
                useEventDate: useEventDate,
                startDate: DateTime(endYear, 1, 1),
                endDate: DateTime(endYear, 3, 31, 23, 59, 59),
                districts: allDistricts,
                activeFilters: activeFiltersStr,
              );
            },
          ),
          onSixMonthsReport: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () {
              final now = DateTime.now();
              return downloadDashboardReport(
                month: now,
                bookings: geoFilteredAllBookings,
                packages: packages,
                employees: employees,
                reportType: 'sales',
                useEventDate: useEventDate,
                startDate: DateTime(now.year, now.month - 6, now.day),
                endDate: now,
                districts: allDistricts,
                activeFilters: activeFiltersStr,
              );
            },
          ),
          onOneYearReport: (useEventDate) => _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () {
              final now = DateTime.now();
              return downloadDashboardReport(
                month: now,
                bookings: geoFilteredAllBookings,
                packages: packages,
                employees: employees,
                reportType: 'sales',
                useEventDate: useEventDate,
                startDate: DateTime(now.year - 1, now.month, now.day),
                endDate: now,
                districts: allDistricts,
                activeFilters: activeFiltersStr,
              );
            },
          ),
        ),
      );
    }

    useEffect(() {
      selectedIds.value = <String>{};
      return null;
    }, [pageState.value]);

    useEffect(() {
      pageState.value = 1;
      selectedIds.value = <String>{};
      return null;
    }, [searchQuery.value, duplicatesOnly.value, selectedFY.value, dateBasis.value]);

    Future<void> deleteBookings(
      List<String> bookingIds,
      int currentPageCount, {
      bool clearAllSelections = false,
    }) async {
      if (bookingIds.isEmpty) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            bookingIds.length == 1 ? 'Delete Booking' : 'Delete Bookings',
          ),
          content: Text(
            bookingIds.length == 1
                ? 'This booking will be deleted permanently.'
                : '${bookingIds.length} bookings will be deleted permanently.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      final notifier = ref.read(bookingProvider.notifier);
      for (final bookingId in bookingIds) {
        await notifier.removeBooking(bookingId);
      }

      ref.invalidate(paginatedBookingsProvider);

      // When deleting from a row icon (single booking), clear all selections
      // so the "Delete Selected" bulk button disappears and avoids confusion.
      if (clearAllSelections) {
        selectedIds.value = <String>{};
      } else {
        selectedIds.value = {
          for (final existingId in selectedIds.value)
            if (!bookingIds.contains(existingId)) existingId,
        };
      }

      if (bookingIds.length >= currentPageCount && pageState.value > 1) {
        pageState.value -= 1;
      }
    }

    Future<void> printCombinedClientPdf(List<Booking> selectedBookings) async {
      if (selectedBookings.isEmpty) return;
      await printMultipleBookingDetails(
        selectedBookings,
        variant: BookingPrintVariant.clientInvoice,
      );
    }

    return asyncPaginatedBookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load bookings: $error',
          style: TextStyle(color: crmColors.textSecondary),
        ),
      ),
      data: (response) {
        final bookings = response.items;
        final allSelected =
            bookings.isNotEmpty &&
            bookings.every((booking) => selectedIds.value.contains(booking.id));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales & Invoices',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        8.h,
                        Text(
                          'Manage your bookings, track payments, and generate sales reports.',
                          style: TextStyle(color: crmColors.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B), // Dark slate blue from image
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: exportReport,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Export Reports', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              24.h,
              LayoutBuilder(
                builder: (context, constraints) {
                  int columns = isMobile ? 2 : 4;
                  double spacing = 16.0;
                  double itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _StatCardWithIcon(
                        title: "Forecast Sales",
                        value: '₹${_money(forecastSales)}',
                        subtitle: 'Current Month',
                        icon: Icons.trending_up,
                        color: crmColors.primary,
                        width: itemWidth,
                      ),
                      _StatCardWithIcon(
                        title: "Forecast Collection",
                        value: '₹${_money(forecastCollection)}',
                        subtitle: 'Remaining Balance',
                        icon: Icons.account_balance_wallet,
                        color: crmColors.success,
                        width: itemWidth,
                      ),
                      _StatCardWithIcon(
                        title: "Today's Bookings",
                        value: todaysScheduled.toString(),
                        subtitle: 'Scheduled events',
                        icon: Icons.calendar_today,
                        color: Colors.blue,
                        width: itemWidth,
                      ),
                      _StatCardWithIcon(
                        title: "Today's Completed",
                        value: '$todaysCompleted',
                        subtitle: 'Successfully closed',
                        icon: Icons.check_circle_outline,
                        color: Colors.teal,
                        width: itemWidth,
                      ),
                    ],
                  );
                },
              ),
              24.h,
              // ── Today vs Yesterday (70%) · Total revenue + Q1–Q4 (30%) ──
              if (isMobile)
                Column(
                  children: [
                    _TodayYesterdayPanel(
                      todaySales: todaySales,
                      yesterdaySales: yesterdaySales,
                      todayWorks: todayWorks,
                      yesterdayWorks: yesterdayWorks,
                      trend: salesTrend,
                    ),
                    16.h,
                    _RevenueQuarterPanel(
                      totalRevenue: totalRevenueFY,
                      quarterWorks: quarterWorks,
                      fyLabel: selectedFY.value,
                      onTap: () => context.push(
                          '/sales/quarterly?fy=${selectedFY.value}&basis=${dateBasis.value}'),
                    ),
                  ],
                )
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _TodayYesterdayPanel(
                          todaySales: todaySales,
                          yesterdaySales: yesterdaySales,
                          todayWorks: todayWorks,
                          yesterdayWorks: yesterdayWorks,
                          trend: salesTrend,
                        ),
                      ),
                      16.w,
                      Expanded(
                        flex: 3,
                        child: _RevenueQuarterPanel(
                          totalRevenue: totalRevenueFY,
                          quarterWorks: quarterWorks,
                          fyLabel: selectedFY.value,
                          onTap: () => context.push(
                              '/sales/quarterly?fy=${selectedFY.value}&basis=${dateBasis.value}'),
                        ),
                      ),
                    ],
                  ),
                ),
              24.h,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: crmColors.border),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: selectedFY.value,
                      onChanged: (val) {
                        if (val != null) selectedFY.value = val;
                      },
                      items: financialYears.map((fy) {
                        return DropdownMenuItem(
                          value: fy,
                          child: Text('FY $fy', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      style: TextStyle(color: crmColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    if (!isMobile) Container(width: 1, height: 24, color: crmColors.border),
                    DropdownButton<String>(
                      value: dateBasis.value,
                      onChanged: (val) {
                        if (val != null) dateBasis.value = val;
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'event_date',
                          child: Text('By Event Date', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        DropdownMenuItem(
                          value: 'booking_date',
                          child: Text('By Booking Date', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                      style: TextStyle(color: crmColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    if (!isMobile) Container(width: 1, height: 24, color: crmColors.border),
                    // ── Zone Dropdown ──
                    DropdownButton<String>(
                      value: selectedZoneId.value.isEmpty ? 'all' : selectedZoneId.value,
                      onChanged: (val) {
                        selectedZoneId.value = val == 'all' ? '' : val!;
                        selectedStateId.value = '';
                        selectedRegionId.value = '';
                        selectedDistrictId.value = '';
                      },
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Zones', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...allZones.map((z) => DropdownMenuItem(
                              value: z.id,
                              child: Text(z.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            )),
                      ],
                      style: TextStyle(color: crmColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    if (!isMobile) Container(width: 1, height: 24, color: crmColors.border),

                    // ── State Dropdown ──
                    DropdownButton<String>(
                      value: selectedStateId.value.isEmpty ? 'all' : selectedStateId.value,
                      onChanged: (val) {
                        selectedStateId.value = val == 'all' ? '' : val!;
                        selectedRegionId.value = '';
                        selectedDistrictId.value = '';
                      },
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All States', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...filteredStates.map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            )),
                      ],
                      style: TextStyle(color: crmColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    if (!isMobile) Container(width: 1, height: 24, color: crmColors.border),

                    // ── Region Dropdown ──
                    DropdownButton<String>(
                      value: selectedRegionId.value.isEmpty ? 'all' : selectedRegionId.value,
                      onChanged: (val) {
                        selectedRegionId.value = val == 'all' ? '' : val!;
                        selectedDistrictId.value = '';
                      },
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Regions', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...filteredRegions.map((r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            )),
                      ],
                      style: TextStyle(color: crmColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    if (!isMobile) Container(width: 1, height: 24, color: crmColors.border),

                    // ── District Dropdown ──
                    DropdownButton<String>(
                      value: selectedDistrictId.value.isEmpty ? 'all' : selectedDistrictId.value,
                      onChanged: (val) {
                        selectedDistrictId.value = val == 'all' ? '' : val!;
                      },
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Districts', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...filteredDistricts.map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            )),
                      ],
                      style: TextStyle(color: crmColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    if (!isMobile) Container(width: 1, height: 24, color: crmColors.border),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('List View'),
                          icon: Icon(Icons.check),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Monthly Summary'),
                          icon: Icon(Icons.bar_chart),
                        ),
                      ],
                      selected: {isMonthlyView.value},
                      onSelectionChanged: (val) {
                        isMonthlyView.value = val.first;
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    if (!isMobile) Container(width: 1, height: 24, color: crmColors.border),
                    SizedBox(
                      width: isMobile ? double.infinity : 300,
                      child: TextFormField(
                        controller: searchCtrl,
                        onFieldSubmitted: (value) {
                          final trimmed = value.trim();
                          searchQuery.value = trimmed;
                          if (trimmed.isEmpty) {
                            searchCtrl.clear();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Search clients, packages...',
                          hintStyle: TextStyle(color: crmColors.textSecondary, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: searchQuery.value.isEmpty
                              ? IconButton(
                                  onPressed: () => searchQuery.value = searchCtrl.text.trim(),
                                  icon: const Icon(Icons.search, size: 20),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => searchQuery.value = searchCtrl.text.trim(),
                                      icon: const Icon(Icons.search, size: 20),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        searchCtrl.clear();
                                        searchQuery.value = '';
                                      },
                                      icon: const Icon(Icons.close, size: 20),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    if (!isMobile) Container(width: 1, height: 24, color: crmColors.border),
                    OutlinedButton.icon(
                      onPressed: () => duplicatesOnly.value = !duplicatesOnly.value,
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: const Text('Duplicates'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: duplicatesOnly.value ? crmColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                        side: BorderSide(color: duplicatesOnly.value ? crmColors.primary : Colors.transparent),
                      ),
                    ),
                  ],
                ),
              ),
              20.h,
              Row(
                children: [
                  if (!isMobile) ...[
                    Checkbox(
                      value: allSelected,
                      onChanged: bookings.isEmpty
                          ? null
                          : (value) {
                              selectedIds.value = value == true
                                  ? {for (final booking in bookings) booking.id}
                                  : <String>{};
                            },
                    ),
                    Text(
                      'Select all',
                      style: TextStyle(color: crmColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const Spacer(),
                  if (selectedIds.value.length >= 2) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        final selectedBookings = bookings
                            .where((b) => selectedIds.value.contains(b.id))
                            .toList();
                        printCombinedClientPdf(selectedBookings);
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(
                        'Combined PDF (${selectedIds.value.length})',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    8.w,
                  ],
                  if (selectedIds.value.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => deleteBookings(
                        selectedIds.value.toList(growable: false),
                        bookings.length,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(
                        'Delete Selected (${selectedIds.value.length})',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crmColors.destructive,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              24.h,
              Text(
                'General Summary',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              16.h,
              LayoutBuilder(
                builder: (context, constraints) {
                  int columns = isMobile ? 2 : 5;
                  double spacing = 16.0;
                  double itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _StatCardWithIcon(
                        title: 'Total Sales Value',
                        value: '₹${_money(totalSalesValue)}',
                        subtitle: 'Across all bookings',
                        icon: Icons.monetization_on_outlined,
                        color: Colors.amber.shade700,
                        width: itemWidth,
                      ),
                      _StatCardWithIcon(
                        title: 'Advance Collected',
                        value: '₹${_money(advanceCollectedFY)}',
                        subtitle: 'FY ${selectedFY.value}',
                        icon: Icons.payments_outlined,
                        color: Colors.teal,
                        width: itemWidth,
                      ),
                      _StatCardWithIcon(
                        title: 'Pending Works',
                        value: '${countPackages(bookings.where((b) => b.status == 'Pending'))}',
                        subtitle: 'Currently active',
                        icon: Icons.pending_actions,
                        color: Colors.orange,
                        width: itemWidth,
                      ),
                      _StatCardWithIcon(
                        title: 'Completed Overall',
                        value: '${countPackages(bookings.where((b) => b.status == 'Completed'))}',
                        subtitle: 'Successfully delivered',
                        icon: Icons.task_alt,
                        color: Colors.green,
                        width: itemWidth,
                      ),
                      _StatCardWithIcon(
                        title: 'Cancelled',
                        value: '${countPackages(bookings.where((b) => b.status == 'Cancelled'))}',
                        subtitle: 'Bookings lost',
                        icon: Icons.cancel_outlined,
                        color: Colors.red,
                        width: itemWidth,
                      ),
                    ],
                  );
                },
              ),
              24.h,
              if (duplicatesOnly.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    response.duplicateItems == 0
                        ? 'No duplicate bookings found for the current filter.'
                        : '${response.duplicateItems} duplicate entries found across ${response.duplicateGroups} groups. Review them, then use single delete or bulk delete safely.',
                    style: TextStyle(
                      color: crmColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (isMonthlyView.value)
                _MonthlySalesSummaryView(
                  financialYear: selectedFY.value,
                  dateBasis: dateBasis.value,
                  zoneId: selectedZoneId.value,
                  stateId: selectedStateId.value,
                  regionId: selectedRegionId.value,
                  districtId: selectedDistrictId.value,
                )
              else
                Container(
                  // Standalone cards on mobile → no panel; bordered table on desktop.
                  decoration: isMobile
                      ? null
                      : BoxDecoration(
                          color: crmColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: crmColors.border),
                        ),
                  child: isMobile
                      ? Column(
                          children: bookings
                              .map(
                                (booking) => _MobileBookingCard(
                                  booking: booking,
                                  isSelected: selectedIds.value.contains(
                                    booking.id,
                                  ),
                                  onSelectChanged: (value) {
                                    final next = {...selectedIds.value};
                                    if (value == true) {
                                      next.add(booking.id);
                                    } else {
                                      next.remove(booking.id);
                                    }
                                    selectedIds.value = next;
                                  },
                                  onDelete: () => deleteBookings(
                                    [booking.id],
                                    bookings.length,
                                    clearAllSelections: true,
                                  ),
                                ),
                              )
                              .toList(),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: Row(
                                children: const [
                                  SizedBox(width: 44),
                                  Expanded(
                                    flex: 2,
                                    child: _HeaderText('Booking'),
                                  ),
                                  Expanded(flex: 2, child: _HeaderText('Booked Date')),
                                  Expanded(flex: 2, child: _HeaderText('Event Date')),
                                  Expanded(flex: 2, child: _HeaderText('Client')),
                                  Expanded(
                                    flex: 2,
                                    child: _HeaderText('Package'),
                                  ),
                                  Expanded(flex: 2, child: _HeaderText('Status')),
                                  Expanded(child: _HeaderText('Advance')),
                                  Expanded(child: _HeaderText('Total')),
                                  Expanded(child: _HeaderText('Balance')),
                                  SizedBox(width: 60),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...bookings.map(
                              (booking) => _DesktopBookingRow(
                                booking: booking,
                                isSelected: selectedIds.value.contains(
                                  booking.id,
                                ),
                                onSelectChanged: (value) {
                                  final next = {...selectedIds.value};
                                  if (value == true) {
                                    next.add(booking.id);
                                  } else {
                                    next.remove(booking.id);
                                  }
                                  selectedIds.value = next;
                                },
                                onDelete: () => deleteBookings(
                                  [booking.id],
                                  bookings.length,
                                  clearAllSelections: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              20.h,
              _PaginationBar(
                page: response.page,
                limit: response.limit,
                totalPages: response.totalPages,
                totalItems: response.totalItems,
                currentItemCount: bookings.length,
                onPrevious: response.page > 1
                    ? () => pageState.value -= 1
                    : null,
                onNext: response.page < response.totalPages
                    ? () => pageState.value += 1
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
