part of '../screens/sales_invoices_screen.dart';
// Sales — monthly summary view + FY performance chart widgets.
// Part of the SalesBookingsScreen library.

class _MonthlySalesSummaryView extends ConsumerWidget {
  final String financialYear;
  final String dateBasis;
  final String? zoneId;
  final String? stateId;
  final String? regionId;
  final String? districtId;

  const _MonthlySalesSummaryView({
    required this.financialYear,
    required this.dateBasis,
    this.zoneId,
    this.stateId,
    this.regionId,
    this.districtId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncBookings = ref.watch(bookingProvider);
    final asyncStates = ref.watch(statesProvider);
    final asyncRegions = ref.watch(regionsProvider);
    final asyncZones = ref.watch(zonesProvider);
    final asyncDistricts = ref.watch(districtsProvider);

    final allStates = asyncStates.value ?? [];
    final allRegions = asyncRegions.value ?? [];
    final allZones = asyncZones.value ?? [];
    final allDistricts = asyncDistricts.value ?? [];

    return asyncBookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (allBookings) {
        bool bookingMatchesGeoFilters(Booking b) {
          if (districtId != null && districtId!.isNotEmpty && b.districtId != districtId) {
            return false;
          }
          if (regionId != null && regionId!.isNotEmpty && b.regionId != regionId) {
            return false;
          }
          if (stateId != null && stateId!.isNotEmpty) {
            final region = allRegions.cast<ServiceRegion?>().firstWhere((r) => r?.id == b.regionId, orElse: () => null);
            if (region == null || region.stateId != stateId) {
              return false;
            }
          }
          if (zoneId != null && zoneId!.isNotEmpty) {
            final region = allRegions.cast<ServiceRegion?>().firstWhere((r) => r?.id == b.regionId, orElse: () => null);
            if (region == null) return false;
            final state = allStates.cast<GeographicState?>().firstWhere((s) => s?.id == region.stateId, orElse: () => null);
            if (state == null || state.zoneId != zoneId) {
              return false;
            }
          }
          return true;
        }

        final geoFilteredAllBookings = allBookings.where(bookingMatchesGeoFilters).toList();

        // Parse FY
        final parts = financialYear.split('-');
        final startYear = int.parse(parts[0]);
        final endYear = 2000 + int.parse(parts[1]);

        final fyStart = DateTime(startYear, 4, 1);
        final fyEnd = DateTime(endYear, 3, 31, 23, 59, 59);

        final useEventDate = dateBasis == 'event_date';

        // Filter bookings for this FY
        final fyBookings = geoFilteredAllBookings.where((b) {
          final d = useEventDate ? b.bookingDate : (b.createdAt ?? b.bookingDate);
          return !d.isBefore(fyStart) && !d.isAfter(fyEnd);
        }).toList();

        // Group by month
        final monthlyStats = <int, _MonthStats>{};
        // Initialize all 12 months (Apr to Mar)
        for (int i = 0; i < 12; i++) {
          final month = (4 + i - 1) % 12 + 1;
          final year = (4 + i > 12) ? endYear : startYear;
          monthlyStats[i] = _MonthStats(month: month, year: year);
        }

        for (final b in fyBookings) {
          int monthIndex;
          final d = useEventDate ? b.bookingDate : (b.createdAt ?? b.bookingDate);
          if (d.month >= 4) {
            monthIndex = d.month - 4;
          } else {
            monthIndex = d.month + 8;
          }

          final stats = monthlyStats[monthIndex]!;
          stats.totalBookings++;
          final packageCount = b.bookingItems.isEmpty ? 1 : b.bookingItems.length;
          stats.totalPackages += packageCount;
          if (b.status.toLowerCase() != 'cancelled' && b.status.toLowerCase() != 'postponed') {
            stats.totalSales += b.totalPrice;
            stats.advanceCollected += b.advanceAmount;
            if (b.status.toLowerCase() != 'completed') {
              stats.forecastAmount += (b.totalPrice - b.advanceAmount - b.discountAmount).clamp(0, double.infinity);
            }
          }
          if (b.status.toLowerCase() == 'completed') {
            stats.completedCount++;
          } else if (b.status.toLowerCase() == 'cancelled') {
            stats.cancelledCount++;
          }
        }

        final statsList = List.generate(12, (index) => monthlyStats[index]!);

        // Shared download action for both the desktop table and mobile cards.
        Future<void> downloadMonth(_MonthStats stats, bool useEventDate) async {
          final asyncPackages = ref.read(packagesProvider);
          final asyncEmployees = ref.read(employeesProvider);
          if (asyncPackages.value == null || asyncEmployees.value == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Loading requirements...')),
            );
            return;
          }
          final reportMonth = DateTime(stats.year, stats.month);
          final activeFiltersStr = (() {
            final List<String> parts = [];
            if (zoneId != null && zoneId!.isNotEmpty) {
              final zone = allZones.cast<ZoneModel?>().firstWhere((z) => z?.id == zoneId, orElse: () => null);
              if (zone != null) parts.add('Zone: ${zone.name}');
            }
            if (stateId != null && stateId!.isNotEmpty) {
              final state = allStates.cast<GeographicState?>().firstWhere((s) => s?.id == stateId, orElse: () => null);
              if (state != null) parts.add('State: ${state.name}');
            }
            if (regionId != null && regionId!.isNotEmpty) {
              final region = allRegions.cast<ServiceRegion?>().firstWhere((r) => r?.id == regionId, orElse: () => null);
              if (region != null) parts.add('Region: ${region.name}');
            }
            if (districtId != null && districtId!.isNotEmpty) {
              final district = allDistricts.cast<District?>().firstWhere((d) => d?.id == districtId, orElse: () => null);
              if (district != null) parts.add('District: ${district.name}');
            }
            return parts.isEmpty ? 'All Bookings' : parts.join(' • ');
          })();
          await _runWithReportLoader(
            context: context,
            crmColors: crmColors,
            action: () => downloadDashboardReport(
              month: reportMonth,
              bookings: geoFilteredAllBookings,
              packages: asyncPackages.value!,
              employees: asyncEmployees.value!,
              useEventDate: useEventDate,
              districts: allDistricts,
              activeFilters: activeFiltersStr,
            ),
          );
        }

        Widget downloadMenu(_MonthStats stats) => PopupMenuButton<String>(
              icon: Icon(Icons.download, size: 20, color: crmColors.primary),
              tooltip: 'Download Monthly Report',
              onSelected: (value) => downloadMonth(stats, value == 'event_date'),
              itemBuilder: (context) => const [
                PopupMenuItem(
                    value: 'booking_date', child: Text('By Booking Date')),
                PopupMenuItem(
                    value: 'event_date', child: Text('By Event Date')),
              ],
            );

        return Column(
          children: [
            _FYPerformanceChart(
              stats: statsList,
              financialYear: financialYear,
            ),
            24.h,
            if (isMobile)
              _mobileMonthCards(context, crmColors, statsList, downloadMenu)
            else
              Container(
                decoration: BoxDecoration(
                  color: crmColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: crmColors.border),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      crmColors.primary.withValues(alpha: 0.05),
                    ),
                    columns: const [
                      DataColumn(label: _HeaderText('MONTH')),
                      DataColumn(label: _HeaderText('BOOKINGS'), numeric: true),
                      DataColumn(label: _HeaderText('PACKAGE COUNT'), numeric: true),
                      DataColumn(label: _HeaderText('GROSS SALES'), numeric: true),
                      DataColumn(label: _HeaderText('ADVANCE'), numeric: true),
                      DataColumn(label: _HeaderText('FORECAST'), numeric: true),
                      DataColumn(label: _HeaderText('COMPLETED'), numeric: true),
                      DataColumn(label: _HeaderText('CANCELLED'), numeric: true),
                      DataColumn(label: _HeaderText('ACTION')),
                    ],
                    rows: statsList.map((stats) {
                      return DataRow(
                        cells: [
                          DataCell(Text('${_monthName(stats.month)} ${stats.year}',
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(stats.totalBookings.toString())),
                          DataCell(Text(stats.totalPackages.toString())),
                          DataCell(Text('₹${_money(stats.totalSales)}')),
                          DataCell(Text('₹${_money(stats.advanceCollected)}')),
                          DataCell(Text('₹${_money(stats.forecastAmount)}')),
                          DataCell(Text(stats.completedCount.toString())),
                          DataCell(Text(stats.cancelledCount.toString())),
                          DataCell(downloadMenu(stats)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Mobile replacement for the monthly DataTable — one compact card per month
  /// that has activity, so nothing overflows off-screen.
  Widget _mobileMonthCards(BuildContext context, CrmTheme crm,
      List<_MonthStats> statsList, Widget Function(_MonthStats) downloadMenu) {
    final active = statsList.where((s) => s.totalBookings > 0).toList();
    if (active.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Center(
          child: Text('No bookings this year yet.',
              style: TextStyle(color: crm.textSecondary)),
        ),
      );
    }

    Widget stat(String label, String value, {Color? color}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: color ?? crm.textPrimary)),
            2.h,
            Text(label,
                style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          ],
        );

    return Column(
      children: [
        for (final s in active) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: crm.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${_monthName(s.month)} ${s.year}',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: crm.primary)),
                    ),
                    const Spacer(),
                    downloadMenu(s),
                  ],
                ),
                12.h,
                Row(
                  children: [
                    Expanded(child: stat('Bookings', '${s.totalBookings}')),
                    Expanded(child: stat('Packages', '${s.totalPackages}')),
                    Expanded(
                        child: stat('Completed', '${s.completedCount}',
                            color: crm.success)),
                    Expanded(
                        child: stat('Cancelled', '${s.cancelledCount}',
                            color: crm.destructive)),
                  ],
                ),
                12.h,
                Divider(height: 1, color: crm.border),
                12.h,
                Row(
                  children: [
                    Expanded(child: stat('Gross', '₹${_money(s.totalSales)}')),
                    Expanded(
                        child:
                            stat('Advance', '₹${_money(s.advanceCollected)}')),
                    Expanded(
                        child: stat('Forecast', '₹${_money(s.forecastAmount)}',
                            color: crm.primary)),
                  ],
                ),
              ],
            ),
          ),
          12.h,
        ],
      ],
    );
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }
}

class _MonthStats {
  final int month;
  final int year;
  int totalBookings = 0;
  int totalPackages = 0;
  double totalSales = 0;
  double advanceCollected = 0;
  int completedCount = 0;
  int cancelledCount = 0;
  double forecastAmount = 0;

  _MonthStats({required this.month, required this.year});
}

class _FYPerformanceChart extends StatelessWidget {
  final List<_MonthStats> stats;
  final String financialYear;

  const _FYPerformanceChart({
    required this.stats,
    required this.financialYear,
  });

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(0)}k';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _monthNameShort(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final maxSales = stats.fold<double>(
      0,
      (max, s) => s.totalSales > max ? s.totalSales : max,
    );
    final double displayMaxSales = maxSales <= 0 ? 100000.0 : maxSales;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Financial Performance Chart (FY $financialYear)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _LegendItem(color: crmColors.primary, label: 'Gross Sales'),
                  16.w,
                  _LegendItem(color: crmColors.sidebar, label: 'Advance Collected'),
                ],
              ),
            ],
          ),
          24.h,
          SizedBox(
            height: 320,
            child: Row(
              children: [
                // Y-Axis Labels
                Container(
                  width: 75,
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(5, (index) {
                      final val = displayMaxSales * (1 - index / 4);
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          _formatAmount(val),
                          style: TextStyle(
                            color: crmColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // Chart Area
                Expanded(
                  child: Stack(
                    children: [
                      // Gridlines
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (index) {
                            return Container(
                              height: 1,
                              color: crmColors.border.withValues(alpha: 0.15),
                            );
                          }),
                        ),
                      ),
                      // Bars
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: stats.map((s) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: _MonthlyBarStack(
                                  stats: s,
                                  maxSales: displayMaxSales,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Month Labels at the bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: stats.map((s) {
                            return Expanded(
                              child: Center(
                                child: Text(
                                  _monthNameShort(s.month),
                                  style: TextStyle(
                                    color: crmColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
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
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        8.w,
        Text(
          label,
          style: TextStyle(
            color: context.crmColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MonthlyBarStack extends StatelessWidget {
  final _MonthStats stats;
  final double maxSales;

  const _MonthlyBarStack({required this.stats, required this.maxSales});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final salesRatio = stats.totalSales / maxSales;
    final advanceRatio = stats.advanceCollected / maxSales;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: _Bar(
            heightRatio: salesRatio,
            color: crmColors.primary,
            tooltip: 'Sales: ₹${stats.totalSales.toStringAsFixed(0)}',
            value: stats.totalSales,
          ),
        ),
        4.w,
        Expanded(
          child: _Bar(
            heightRatio: advanceRatio,
            color: crmColors.sidebar,
            tooltip: 'Advance: ₹${stats.advanceCollected.toStringAsFixed(0)}',
            value: stats.advanceCollected,
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double heightRatio;
  final Color color;
  final String tooltip;
  final double value;

  const _Bar({
    required this.heightRatio,
    required this.color,
    required this.tooltip,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final showBar = value > 0;

    return Tooltip(
      message: tooltip,
      child: FractionallySizedBox(
        heightFactor: showBar ? heightRatio.clamp(0.01, 1.0) : 0.0,
        child: Container(
          constraints: const BoxConstraints(minWidth: 16, maxWidth: 32),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            boxShadow: showBar
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ]
                : null,
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                color,
                color.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _runWithReportLoader({
  required BuildContext context,
  required CrmTheme crmColors,
  required Future<void> Function() action,
}) async {
  NavigatorState? dialogNavigator;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      dialogNavigator = Navigator.of(dialogContext);
      return Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: crmColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(crmColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Generating Report',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: crmColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please wait while the PDF is prepared...',
                  style: TextStyle(
                    color: crmColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  // Yield frame to render loading dialog
  await Future.delayed(const Duration(milliseconds: 100));

  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: $e'),
          backgroundColor: crmColors.destructive,
        ),
      );
    }
  } finally {
    if (dialogNavigator != null && dialogNavigator!.mounted) {
      dialogNavigator!.pop();
    }
  }
}
