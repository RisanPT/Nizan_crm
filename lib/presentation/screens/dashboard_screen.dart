import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/auth/app_role.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/dashboard_report_service.dart';
import '../../core/utils/responsive_builder.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/collection_service.dart';
import '../../services/expense_service.dart';
import '../../services/lead_service.dart';
import '../../core/models/artist_collection.dart';
import '../../core/models/artist_expense.dart';
import '../../core/models/lead.dart';
import '../../services/employee_service.dart';
import '../../services/package_service.dart';

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final role = auth.session != null
        ? AppRole.fromString(auth.session!.role)
        : AppRole.artist;

    final canSeeCEOReport = role.canSeeCEOReport;
    final tabController = useTabController(initialLength: canSeeCEOReport ? 6 : 5);
    final isDesktop = ResponsiveBuilder.isDesktop(context);
    final isTablet = ResponsiveBuilder.isTablet(context);
    final asyncBookings = ref.watch(bookingProvider);
    final asyncArtistBookings = role == AppRole.artist
        ? ref.watch(artistAssignedWorksProvider(1))
        : null;

    final asyncPackages = ref.watch(packagesProvider);
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncCollections = ref.watch(collectionsProvider);
    final asyncExpenses = ref.watch(expensesProvider);
    final asyncLeads = ref.watch(leadsProvider);

    final allBookings = role == AppRole.artist
        ? (asyncArtistBookings?.value?.items ?? const <Booking>[])
        : (asyncBookings.value ?? const <Booking>[]);

    if (role == AppRole.artist) {
      return _ArtistDashboardView(
        isDesktop: isDesktop,
        isTablet: isTablet,
        allBookings: allBookings,
        employeeId: auth.session?.employeeId,
      );
    }
    final now = DateTime.now();

    String monthKey(DateTime value) => '${value.year}-${value.month}';
    final currentMonthKey = monthKey(now);
    final monthBookings = allBookings
        .where((booking) => monthKey(booking.serviceStart) == currentMonthKey)
        .toList();

    final totalWorksInMonth = monthBookings
        .where((booking) => booking.status.toLowerCase() != 'cancelled')
        .length;
    final completedWorksInMonth = monthBookings
        .where((booking) => booking.status.toLowerCase() == 'completed')
        .length;
    final cancelledWorksInMonth = monthBookings
        .where((booking) => booking.status.toLowerCase() == 'cancelled')
        .length;
    final totalForecastAmount = monthBookings
        .where((booking) => booking.status.toLowerCase() != 'cancelled')
        .where((booking) => booking.status.toLowerCase() != 'completed')
        .fold<double>(
          0,
          (sum, booking) =>
              sum +
              (booking.totalPrice -
                      booking.advanceAmount -
                      booking.discountAmount)
                  .clamp(0, double.infinity),
        );

    String money(double amount) => 'INR ${amount.toStringAsFixed(0)}';
    final monthLabel = '${_monthName(now.month)} ${now.year}';

    Future<void> exportReport() async {
      final bookings = asyncBookings.value;
      final packages = asyncPackages.value;
      final employees = asyncEmployees.value;

      if (bookings == null || packages == null || employees == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait until dashboard data finishes loading.'),
          ),
        );
        return;
      }

      final reportType = switch (tabController.index) {
        0 => 'executive',
        1 => 'sales',
        2 => 'marketing',
        3 => 'crm',
        4 => 'finance',
        5 => 'ceo_daily',
        _ => 'executive',
      };

      await downloadDashboardReport(
        month: now,
        bookings: bookings,
        packages: packages,
        employees: employees,
        reportType: reportType,
        leads: asyncLeads.value ?? [],
        collections: asyncCollections.value ?? [],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Welcome back, Jessica. Here\'s what\'s happening today.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.crmColors.textSecondary,
                ),
              ),
            ),
            if (!ResponsiveBuilder.isMobile(context))
              OutlinedButton.icon(
                onPressed: exportReport,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export Report'),
              ),
          ],
        ),
        16.h,
        TabBar(
          controller: tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: context.crmColors.primary,
          unselectedLabelColor: context.crmColors.textSecondary,
          indicatorColor: context.crmColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: [
            const Tab(text: 'Executive'),
            const Tab(text: 'Sales'),
            const Tab(text: 'Marketing'),
            const Tab(text: 'CRM'),
            const Tab(text: 'Finance'),
            if (canSeeCEOReport) const Tab(text: 'CEO Report'),
          ],
        ),
        8.h,
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _ExecutiveView(
                isDesktop: isDesktop,
                isTablet: isTablet,
                monthBookings: monthBookings,
                monthLabel: monthLabel,
                totalWorksInMonth: totalWorksInMonth,
                totalForecastAmount: totalForecastAmount,
                cancelledWorksInMonth: cancelledWorksInMonth,
                completedWorksInMonth: completedWorksInMonth,
                money: money,
                onExport: exportReport,
              ),
              _SalesView(isDesktop: isDesktop),
              _MarketingView(),
              _CRMView(),
              _FinanceView(
                collections: asyncCollections.value ?? [],
                expenses: asyncExpenses.value ?? [],
              ),
              if (canSeeCEOReport)
                _CEOReportView(
                  bookings: allBookings,
                  collections: asyncCollections.value ?? [],
                  leads: asyncLeads.value ?? [],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _monthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month - 1];
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String trend;
  final double width;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.trend,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: 20.p,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: crmColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: 8.p,
                    decoration: BoxDecoration(
                      color: crmColors.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: crmColors.textPrimary),
                  ),
                ],
              ),
              16.h,
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: crmColors.textPrimary,
                ),
              ),
              8.h,
              Row(
                children: [
                  Icon(Icons.trending_up, size: 16, color: crmColors.success),
                  4.w,
                  Expanded(
                    child: Text(
                      trend,
                      style: TextStyle(
                        color: crmColors.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({
    required this.monthBookings,
    required this.monthLabel,
    required this.onExport,
  });

  final List<Booking> monthBookings;
  final String monthLabel;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context) {
    final chartData = _buildRevenueSeries(monthBookings);
    final peakRevenue = chartData.fold<double>(
      0,
      (max, item) => item.revenue > max ? item.revenue : max,
    );

    return Card(
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Revenue Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onExport,
                  child: const Text('View Report'),
                ),
              ],
            ),
            16.h,
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.crmColors.background,
                border: Border.all(color: context.crmColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: chartData.isEmpty
                  ? Center(
                      child: Text(
                        'No revenue data for $monthLabel yet.',
                        style: TextStyle(
                          color: context.crmColors.textSecondary,
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily revenue and booking count for $monthLabel',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.crmColors.textSecondary,
                                ),
                          ),
                          20.h,
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final point in chartData)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: _RevenueBar(
                                        point: point,
                                        maxRevenue:
                                            peakRevenue <= 0 ? 1 : peakRevenue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueBar extends StatelessWidget {
  const _RevenueBar({
    required this.point,
    required this.maxRevenue,
  });

  final _RevenuePoint point;
  final double maxRevenue;

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final ratio = (point.revenue / maxRevenue).clamp(0.0, 1.0);
    final barHeight = 26 + (ratio * 132);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'INR ${point.revenue.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: crmColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        8.h,
        Tooltip(
          message:
              '${point.dayLabel}\nRevenue: INR ${point.revenue.toStringAsFixed(0)}\nBookings: ${point.bookingsCount}',
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  crmColors.sidebar,
                  crmColors.primary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: crmColors.sidebar.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              '${point.bookingsCount}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        8.h,
        Text(
          point.dayLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: crmColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _UpcomingBookingsCard extends StatelessWidget {
  const _UpcomingBookingsCard();

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Card(
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Upcoming Bookings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/calendar'),
                  child: const Text('View Calendar'),
                ),
              ],
            ),
            16.h,
            Consumer(
              builder: (context, ref, child) {
                final asyncBookings = ref.watch(bookingProvider);

                return asyncBookings.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Failed to load appointments.',
                      style: TextStyle(color: crmColors.textSecondary),
                    ),
                  ),
                  data: (bookings) {
                    final now = DateTime.now();
                    final upcomingBookings = [...bookings]
                      ..retainWhere(
                        (booking) => !booking.serviceStart.isBefore(now),
                      )
                      ..sort(
                        (a, b) => a.serviceStart.compareTo(b.serviceStart),
                      );

                    if (upcomingBookings.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 40,
                              color: crmColors.border,
                            ),
                            12.h,
                            Text(
                              'No upcoming appointments.',
                              style: TextStyle(color: crmColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    final visibleBookings = upcomingBookings.take(5).toList();

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleBookings.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final booking = visibleBookings[index];
                        return _UpcomingBookingTile(booking: booking);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBookingRequestsCard extends ConsumerWidget {
  const _PendingBookingRequestsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final asyncBookings = ref.watch(bookingProvider);

    return Card(
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Pending Booking Requests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/booking/requests'),
                  child: const Text('Open Requests'),
                ),
              ],
            ),
            16.h,
            asyncBookings.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Text(
                'Failed to load booking requests.',
                style: TextStyle(color: crmColors.textSecondary),
              ),
              data: (bookings) {
                final pendingBookings =
                    bookings
                        .where(
                          (booking) =>
                              booking.status.toLowerCase() == 'pending',
                        )
                        .toList()
                      ..sort(
                        (a, b) => a.serviceStart.compareTo(b.serviceStart),
                      );

                if (pendingBookings.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: crmColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: crmColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          color: crmColors.textSecondary,
                          size: 34,
                        ),
                        10.h,
                        Text(
                          'No pending booking requests right now.',
                          style: TextStyle(color: crmColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                final visibleBookings = pendingBookings.take(4).toList();

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleBookings.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final booking = visibleBookings[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: crmColors.secondary,
                        child: Text(
                          booking.initials,
                          style: TextStyle(
                            color: crmColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        booking.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${booking.service} • ${_UpcomingBookingTile._formatDate(booking.serviceStart)} • ${_UpcomingBookingTile._formatTime(booking.serviceStart)}',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => context.go('/booking/requests'),
                        child: const Text('Review'),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingBookingTile extends StatelessWidget {
  final Booking booking;

  const _UpcomingBookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => context.push('/booking/manage/${booking.id}'),
      leading: CircleAvatar(
        backgroundColor: crmColors.secondary,
        child: Text(
          booking.initials,
          style: TextStyle(
            color: crmColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        booking.customerName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(booking.service),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(booking.serviceStart),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          4.h,
          Container(
            padding: 4.px,
            decoration: BoxDecoration(
              color: crmColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatDate(booking.serviceStart),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: crmColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static String _formatDate(DateTime dateTime) {
    const months = [
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
    return '${dateTime.day} ${months[dateTime.month - 1]}';
  }
}

class _PopularServicesCard extends ConsumerWidget {
  const _PopularServicesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final asyncBookings = ref.watch(bookingProvider);
    final asyncPackages = ref.watch(packagesProvider);

    return Card(
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Popular Services',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/services'),
                  child: const Text('View All'),
                ),
              ],
            ),
            16.h,
            asyncBookings.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Text(
                'Failed to load service metrics.',
                style: TextStyle(color: crmColors.textSecondary),
              ),
              data: (bookings) {
                return asyncPackages.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => Text(
                    'Failed to load services.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                  data: (packages) {
                    final now = DateTime.now();
                    final monthBookings = bookings.where((booking) {
                      return booking.serviceStart.year == now.year &&
                          booking.serviceStart.month == now.month &&
                          booking.status.toLowerCase() != 'cancelled';
                    }).toList();

                    final packageById = {
                      for (final package in packages) package.id: package,
                    };
                    final metrics = <_ServiceMetric>[];

                    final grouped = <String, List<Booking>>{};
                    for (final booking in monthBookings) {
                      final key = booking.packageId.isNotEmpty
                          ? booking.packageId
                          : booking.service.trim().toLowerCase();
                      grouped.putIfAbsent(key, () => []).add(booking);
                    }

                    grouped.forEach((key, serviceBookings) {
                      final sample = serviceBookings.first;
                      final matchedPackage = packageById[sample.packageId];
                      final price = matchedPackage?.price ?? sample.totalPrice;
                      metrics.add(
                        _ServiceMetric(
                          name: matchedPackage?.name ?? sample.service,
                          bookingsCount: serviceBookings.length,
                          amount: price,
                          icon: _serviceIcon(
                            matchedPackage?.name ?? sample.service,
                          ),
                        ),
                      );
                    });

                    metrics.sort((a, b) {
                      final bookingsCompare =
                          b.bookingsCount.compareTo(a.bookingsCount);
                      if (bookingsCompare != 0) return bookingsCompare;
                      return b.amount.compareTo(a.amount);
                    });

                    final visibleMetrics = metrics.take(3).toList();

                    if (visibleMetrics.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No service bookings yet for this month.',
                          style: TextStyle(color: crmColors.textSecondary),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (var i = 0; i < visibleMetrics.length; i++) ...[
                          _buildServiceItem(context, visibleMetrics[i]),
                          if (i != visibleMetrics.length - 1) const Divider(),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, _ServiceMetric metric) {
    final crmColors = context.crmColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: 8.p,
        decoration: BoxDecoration(
          color: crmColors.secondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(metric.icon, color: crmColors.textPrimary),
      ),
      title: Text(
        metric.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${metric.bookingsCount} bookings this month'),
      trailing: Text(
        'INR ${metric.amount.toStringAsFixed(0)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TopStaffCard extends ConsumerWidget {
  const _TopStaffCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final asyncBookings = ref.watch(bookingProvider);
    final asyncEmployees = ref.watch(employeesProvider);

    return Card(
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Top Performing Staff',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/staff'),
                  child: const Text('View Team'),
                ),
              ],
            ),
            16.h,
            asyncBookings.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Text(
                'Failed to load staff performance.',
                style: TextStyle(color: crmColors.textSecondary),
              ),
              data: (bookings) {
                return asyncEmployees.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => Text(
                    'Failed to load staff members.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                  data: (employees) {
                    final now = DateTime.now();
                    final monthBookings = bookings.where((booking) {
                      return booking.serviceStart.year == now.year &&
                          booking.serviceStart.month == now.month &&
                          booking.status.toLowerCase() != 'cancelled';
                    }).toList();

                    final employeeById = {
                      for (final employee in employees) employee.id: employee,
                    };
                    final stats = <String, _StaffMetric>{};

                    for (final booking in monthBookings) {
                      for (final assignment in booking.assignedStaff) {
                        if (assignment.employeeId.isEmpty) continue;
                        final employee = employeeById[assignment.employeeId];
                        final existing = stats[assignment.employeeId];
                        final role =
                            employee?.specialization.trim().isNotEmpty == true
                            ? employee!.specialization.trim()
                            : assignment.works.isNotEmpty
                                ? assignment.works.join(', ')
                                : assignment.role;

                        stats[assignment.employeeId] = _StaffMetric(
                          employeeId: assignment.employeeId,
                          name: employee?.name ?? assignment.artistName,
                          role: role.isEmpty ? 'Assigned Staff' : role,
                          appointmentsCount:
                              (existing?.appointmentsCount ?? 0) + 1,
                        );
                      }
                    }

                    final visibleStaff = stats.values.toList()
                      ..sort((a, b) {
                        final countCompare =
                            b.appointmentsCount.compareTo(a.appointmentsCount);
                        if (countCompare != 0) return countCompare;
                        return a.name.compareTo(b.name);
                      });

                    if (visibleStaff.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No staff assignments yet for this month.',
                          style: TextStyle(color: crmColors.textSecondary),
                        ),
                      );
                    }

                    final topStaff = visibleStaff.take(3).toList();

                    return Column(
                      children: [
                        for (var i = 0; i < topStaff.length; i++) ...[
                          _buildStaffItem(context, topStaff[i]),
                          if (i != topStaff.length - 1) const Divider(),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffItem(BuildContext context, _StaffMetric metric) {
    final crmColors = context.crmColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: crmColors.primary,
        foregroundColor: Colors.white,
        child: Text(
          _initialsForName(metric.name),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        metric.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(metric.role),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${metric.appointmentsCount}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          4.h,
          Text(
            metric.appointmentsCount == 1
                ? '1 appointment'
                : '${metric.appointmentsCount} appointments',
            style: TextStyle(fontSize: 12, color: crmColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ServiceMetric {
  final String name;
  final int bookingsCount;
  final double amount;
  final IconData icon;

  const _ServiceMetric({
    required this.name,
    required this.bookingsCount,
    required this.amount,
    required this.icon,
  });
}

class _StaffMetric {
  final String employeeId;
  final String name;
  final String role;
  final int appointmentsCount;

  const _StaffMetric({
    required this.employeeId,
    required this.name,
    required this.role,
    required this.appointmentsCount,
  });
}

IconData _serviceIcon(String serviceName) {
  final normalized = serviceName.toLowerCase();
  if (normalized.contains('hair')) return Icons.cut;
  if (normalized.contains('spa') || normalized.contains('facial')) {
    return Icons.spa;
  }
  if (normalized.contains('bridal') || normalized.contains('makeover')) {
    return Icons.auto_awesome;
  }
  return Icons.design_services_outlined;
}

String _initialsForName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

List<_RevenuePoint> _buildRevenueSeries(List<Booking> monthBookings) {
  final grouped = <String, _RevenuePoint>{};

  for (final booking in monthBookings) {
    if (booking.status.toLowerCase() == 'cancelled') continue;
    final dayLabel = _UpcomingBookingTile._formatDate(booking.serviceStart);
    final previous = grouped[dayLabel];
    grouped[dayLabel] = _RevenuePoint(
      dayLabel: dayLabel,
      revenue: (previous?.revenue ?? 0) + booking.totalPrice,
      bookingsCount: (previous?.bookingsCount ?? 0) + 1,
      sortDate: DateTime(
        booking.serviceStart.year,
        booking.serviceStart.month,
        booking.serviceStart.day,
      ),
    );
  }

  final series = grouped.values.toList()
    ..sort((a, b) => a.sortDate.compareTo(b.sortDate));

  if (series.length <= 7) return series;
  return series.sublist(series.length - 7);
}

class _RevenuePoint {
  final String dayLabel;
  final double revenue;
  final int bookingsCount;
  final DateTime sortDate;

  const _RevenuePoint({
    required this.dayLabel,
    required this.revenue,
    required this.bookingsCount,
    required this.sortDate,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// NEW TAB VIEWS
// ─────────────────────────────────────────────────────────────────────────────

class _ExecutiveView extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;
  final List<Booking> monthBookings;
  final String monthLabel;
  final dynamic totalWorksInMonth;
  final dynamic totalForecastAmount;
  final dynamic cancelledWorksInMonth;
  final dynamic completedWorksInMonth;
  final String Function(double) money;
  final Future<void> Function() onExport;

  const _ExecutiveView({
    required this.isDesktop,
    required this.isTablet,
    required this.monthBookings,
    required this.monthLabel,
    required this.totalWorksInMonth,
    required this.totalForecastAmount,
    required this.cancelledWorksInMonth,
    required this.completedWorksInMonth,
    required this.money,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              int columns = isDesktop ? 4 : (isTablet ? 2 : 1);
              double spacing = 16.0;
              double itemWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _StatCard(
                    title: 'Total Works This Month',
                    value: totalWorksInMonth.toString(),
                    icon: Icons.event,
                    trend: monthLabel,
                    width: itemWidth,
                  ),
                  _StatCard(
                    title: 'Forecast Amount This Month',
                    value: money(totalForecastAmount),
                    icon: Icons.account_balance_wallet_outlined,
                    trend: monthLabel,
                    width: itemWidth,
                  ),
                  _StatCard(
                    title: 'Cancelled Works',
                    value: cancelledWorksInMonth.toString(),
                    icon: Icons.event_busy,
                    trend: monthLabel,
                    width: itemWidth,
                  ),
                  _StatCard(
                    title: 'Completed Works',
                    value: completedWorksInMonth.toString(),
                    icon: Icons.task_alt,
                    trend: monthLabel,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
          24.h,
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _RevenueChartCard(
                        monthBookings: monthBookings,
                        monthLabel: monthLabel,
                        onExport: onExport,
                      ),
                      24.h,
                      const _PendingBookingRequestsCard(),
                      24.h,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: const _PopularServicesCard()),
                          24.w,
                          Expanded(child: const _TopStaffCard()),
                        ],
                      ),
                    ],
                  ),
                ),
                24.w,
                Expanded(flex: 1, child: const _UpcomingBookingsCard()),
              ],
            )
          else
            Column(
              children: [
                _RevenueChartCard(
                  monthBookings: monthBookings,
                  monthLabel: monthLabel,
                  onExport: onExport,
                ),
                24.h,
                const _PendingBookingRequestsCard(),
                24.h,
                const _UpcomingBookingsCard(),
                24.h,
                if (isTablet)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: const _PopularServicesCard()),
                      16.w,
                      Expanded(child: const _TopStaffCard()),
                    ],
                  )
                else ...[
                  const _PopularServicesCard(),
                  24.h,
                  const _TopStaffCard(),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SalesView extends StatelessWidget {
  final bool isDesktop;

  const _SalesView({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const _QuickLeadEntryCard(),
          24.h,
          const _SalesPipelineCard(),
          24.h,
          const _SalesConversionCard(),
          24.h,
          const _TopPerformersCard(),
        ],
      ),
    );
  }
}

class _QuickLeadEntryCard extends HookConsumerWidget {
  const _QuickLeadEntryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final nameCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final locationCtrl = useTextEditingController();
    final remarksCtrl = useTextEditingController();
    final enquiryDate = useState(DateTime.now());
    final status = useState('New');
    final isSaving = useState(false);

    Future<void> _saveLead() async {
      if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill name and phone')),
        );
        return;
      }

      isSaving.value = true;
      try {
        final dio = ref.read(dioProvider);
        await dio.post('/leads', data: {
          'name': nameCtrl.text,
          'phone': phoneCtrl.text,
          'status': status.value,
          'source': 'Dashboard',
          'location': locationCtrl.text,
          'remarks': remarksCtrl.text,
          'enquiryDate': enquiryDate.value.toIso8601String(),
        });
        
        nameCtrl.clear();
        phoneCtrl.clear();
        locationCtrl.clear();
        remarksCtrl.clear();
        status.value = 'New';
        
        ref.invalidate(leadsProvider);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lead added successfully!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add lead: $e')),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Lead Entry',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            8.h,
            Text(
              'Quickly record a new potential client inquiry.',
              style: TextStyle(color: crm.textSecondary, fontSize: 13),
            ),
            20.h,
            if (ResponsiveBuilder.isDesktop(context))
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.person_outline)),
                    ),
                  ),
                  16.w,
                  Expanded(
                    child: TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone_outlined)),
                    ),
                  ),
                  16.w,
                  Expanded(
                    child: TextFormField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_outlined)),
                    ),
                  ),
                  16.w,
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: enquiryDate.value,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) enquiryDate.value = picked;
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Enquired For', prefixIcon: Icon(Icons.calendar_today_outlined)),
                        child: Text('${enquiryDate.value.day}/${enquiryDate.value.month}/${enquiryDate.value.year}'),
                      ),
                    ),
                  ),
                  16.w,
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: status.value,
                      decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline)),
                      items: ['New', 'Contacted', 'Qualified', 'Follow-up', 'Converted', 'Lost']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => status.value = v!,
                    ),
                  ),
                  24.w,
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isSaving.value ? null : _saveLead,
                      icon: isSaving.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
                      label: const Text('Add Lead'),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.person_outline))),
                  16.h,
                  TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone_outlined))),
                  16.h,
                  TextFormField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_outlined))),
                  16.h,
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: enquiryDate.value,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) enquiryDate.value = picked;
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Enquired For', prefixIcon: Icon(Icons.calendar_today_outlined)),
                      child: Text('${enquiryDate.value.day}/${enquiryDate.value.month}/${enquiryDate.value.year}'),
                    ),
                  ),
                  20.h,
                  DropdownButtonFormField<String>(
                    value: status.value,
                    decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline)),
                    items: ['New', 'Contacted', 'Qualified', 'Follow-up', 'Converted', 'Lost']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => status.value = v!,
                  ),
                  20.h,
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isSaving.value ? null : _saveLead,
                      icon: isSaving.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
                      label: const Text('Add Lead'),
                    ),
                  ),
                ],
              ),
            16.h,
            TextFormField(
              controller: remarksCtrl,
              decoration: const InputDecoration(labelText: 'Remarks', prefixIcon: Icon(Icons.notes)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const _MarketingCampaignsCard(),
          24.h,
          const _LeadSourceDistributionCard(),
        ],
      ),
    );
  }
}

class _CRMView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const _CustomerSatisfactionCard(),
          24.h,
          // const _RecentPatientActivityCard(), removed as it was replaced by CEO Report metrics
        ],
      ),
    );
  }
}

class _FinanceView extends StatelessWidget {
  final List<ArtistCollection> collections;
  final List<ArtistExpense> expenses;

  const _FinanceView({
    required this.collections,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _FinanceChartCard(collections: collections, expenses: expenses),
          24.h,
          const _RevenueBreakdownCard(),
          24.h,
          const _ExpenseAnalysisCard(),
        ],
      ),
    );
  }
}

class _FinanceChartCard extends StatelessWidget {
  final List<ArtistCollection> collections;
  final List<ArtistExpense> expenses;

  const _FinanceChartCard({
    required this.collections,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    
    // Process data for the last 7 days
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    
    final dailyData = last7Days.map((date) {
      final dayCollections = collections.where((c) => 
        c.date.year == date.year && c.date.month == date.month && c.date.day == date.day
      ).fold(0.0, (sum, c) => sum + c.amount);
      
      final dayExpenses = expenses.where((e) => 
        e.date.year == date.year && e.date.month == date.month && e.date.day == date.day
      ).fold(0.0, (sum, e) => sum + e.amount);
      
      return (collections: dayCollections, expenses: dayExpenses, date: date);
    }).toList();

    double maxVal = 0;
    for (var d in dailyData) {
      if (d.collections > maxVal) maxVal = d.collections;
      if (d.expenses > maxVal) maxVal = d.expenses;
    }
    if (maxVal == 0) maxVal = 1000;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash Flow Analysis',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Last 7 days of collections vs expenses',
                      style: TextStyle(color: crm.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _legendItem('Collections', crm.success),
                    16.w,
                    _legendItem('Expenses', crm.destructive),
                  ],
                ),
              ],
            ),
            32.h,
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => crm.sidebar,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '₹${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final date = dailyData[value.toInt()].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${date.day}/${date.month}',
                              style: TextStyle(color: crm.textSecondary, fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: dailyData.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.collections,
                          color: crm.success,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: entry.value.expenses,
                          color: crm.destructive,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        6.w,
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI COMPONENTS FOR TABS
// ─────────────────────────────────────────────────────────────────────────────

class _SalesPipelineCard extends StatelessWidget {
  const _SalesPipelineCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: 24.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Pipeline Flow',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            16.h,
            const _PipelineStep(
              label: 'Awareness',
              value: '142 Leads',
              color: Colors.blue,
              percentage: 1.0,
            ),
            8.h,
            const _PipelineStep(
              label: 'Consideration',
              value: '86 Qualifed',
              color: Colors.indigo,
              percentage: 0.6,
            ),
            8.h,
            const _PipelineStep(
              label: 'Decision',
              value: '34 Proposals',
              color: Colors.purple,
              percentage: 0.24,
            ),
            8.h,
            const _PipelineStep(
              label: 'Purchase',
              value: '12 Closed',
              color: Colors.green,
              percentage: 0.08,
            ),
          ],
        ),
      ),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double percentage;

  const _PipelineStep({
    required this.label,
    required this.value,
    required this.color,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(value, style: TextStyle(color: context.crmColors.textSecondary)),
          ],
        ),
        8.h,
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 12,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }
}

class _SalesConversionCard extends StatelessWidget {
  const _SalesConversionCard();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Conversion Rate',
            value: '14.2%',
            icon: Icons.trending_up,
            trend: '+2.4% from last month',
            width: double.infinity,
          ),
        ),
        16.w,
        Expanded(
          child: _StatCard(
            title: 'Avg. Deal Size',
            value: 'INR 42,500',
            icon: Icons.monetization_on_outlined,
            trend: '+12% from last month',
            width: double.infinity,
          ),
        ),
      ],
    );
  }
}

class _TopPerformersCard extends StatelessWidget {
  const _TopPerformersCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: 24.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Sales Performers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            16.h,
            _performerTile(context, 'Rahul Sharma', '28 Closings', 'INR 1.4M'),
            const Divider(),
            _performerTile(context, 'Anjali Nair', '24 Closings', 'INR 1.1M'),
            const Divider(),
            _performerTile(context, 'Kevin Peterson', '19 Closings', 'INR 850k'),
          ],
        ),
      ),
    );
  }

  Widget _performerTile(
    BuildContext context,
    String name,
    String closings,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.crmColors.secondary,
            child: Text(name[0], style: TextStyle(color: context.crmColors.primary)),
          ),
          16.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(closings, style: TextStyle(color: context.crmColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(value, style: TextStyle(color: context.crmColors.primary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MarketingCampaignsCard extends StatelessWidget {
  const _MarketingCampaignsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: 24.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Campaigns',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            16.h,
            _campaignItem(context, 'Summer Wedding Promo', '420 Leads', 'INR 12k Spend'),
            24.h,
            _campaignItem(context, 'Corporate Event Package', '186 Leads', 'INR 8k Spend'),
            24.h,
            _campaignItem(context, 'Social Media Blast', '1,240 Leads', 'INR 5k Spend'),
          ],
        ),
      ),
    );
  }

  Widget _campaignItem(BuildContext context, String title, String stats, String spend) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(spend, style: TextStyle(color: context.crmColors.textSecondary, fontSize: 12)),
          ],
        ),
        8.h,
        Text(stats, style: TextStyle(color: context.crmColors.primary, fontWeight: FontWeight.w500)),
        4.h,
        LinearProgressIndicator(
          value: 0.7,
          backgroundColor: context.crmColors.border,
          valueColor: AlwaysStoppedAnimation<Color>(context.crmColors.primary),
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _LeadSourceDistributionCard extends StatelessWidget {
  const _LeadSourceDistributionCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: 24.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lead Sources',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            16.h,
            Row(
              children: [
                _sourceItem(context, 'Instagram', '45%', Colors.pink),
                _sourceItem(context, 'Referrals', '25%', Colors.green),
                _sourceItem(context, 'Website', '20%', Colors.blue),
                _sourceItem(context, 'Others', '10%', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceItem(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 8,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          8.h,
          Text(label, style: const TextStyle(fontSize: 10)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _CustomerSatisfactionCard extends StatelessWidget {
  const _CustomerSatisfactionCard();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Net Promoter Score',
            value: '78',
            icon: Icons.sentiment_very_satisfied,
            trend: 'High Customer Loyalty',
            width: double.infinity,
          ),
        ),
        16.w,
        Expanded(
          child: _StatCard(
            title: 'Response Time',
            value: '1.2 hr',
            icon: Icons.timer,
            trend: '-14m from yesterday',
            width: double.infinity,
          ),
        ),
      ],
    );
  }
}

class _CEOReportView extends HookConsumerWidget {
  final List<Booking> bookings;
  final List<ArtistCollection> collections;
  final List<Lead> leads;

  const _CEOReportView({
    required this.bookings,
    required this.collections,
    required this.leads,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final now = DateTime.now();

    // Data filtering for "Today"
    final todayBookings = bookings.where((b) => 
      b.serviceStart.year == now.year && 
      b.serviceStart.month == now.month && 
      b.serviceStart.day == now.day
    ).toList();

    final todayLeads = leads.where((l) => 
      l.createdAt.year == now.year && 
      l.createdAt.month == now.month && 
      l.createdAt.day == now.day
    ).toList();

    final todayCollections = collections.where((c) => 
      c.date.year == now.year && 
      c.date.month == now.month && 
      c.date.day == now.day &&
      c.status == 'verified'
    ).toList();

    // Metrics Calculation
    final revenueToday = todayCollections.fold(0.0, (sum, c) => sum + c.amount);
    final totalBookings = todayBookings.length;
    final avgTicketSize = totalBookings > 0 ? revenueToday / totalBookings : 0.0;
    final leadsGenerated = todayLeads.length;
    final convertedLeads = todayLeads.where((l) => l.status.toLowerCase() == 'converted').length;
    final conversionRate = leadsGenerated > 0 ? (convertedLeads / leadsGenerated) * 100 : 0.0;
    final lostLeads = todayLeads.where((l) => l.status.toLowerCase() == 'lost').toList();
    
    // Slot Utilization (Approximate: assume 10 slots per day per artist, total 5 active artists)
    const totalSlots = 50; 
    final slotUtilization = (totalBookings / totalSlots * 100).clamp(0.0, 100.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('📅 DAILY CEO REPORT – Nizan Makeovers', now),
          24.h,
          _buildMetricsGrid(context, [
            _MetricItem('Revenue Today', '₹${revenueToday.toStringAsFixed(0)}', 'Target: ₹50k', crm.success),
            _MetricItem('Total Bookings', totalBookings.toString(), 'Capacity: $totalSlots', crm.primary),
            _MetricItem('Avg Ticket Size', '₹${avgTicketSize.toStringAsFixed(0)}', 'Goal: ₹5k', crm.warning),
            _MetricItem('Leads Generated', leadsGenerated.toString(), 'Target: 20', crm.accent),
          ]),
          24.h,
          _buildMetricsGrid(context, [
            _MetricItem('Conversions', '${conversionRate.toStringAsFixed(1)}%', 'Goal: 15%', crm.accent),
            _MetricItem('Lost Leads', lostLeads.length.toString(), 'Follow up!', crm.destructive),
            _MetricItem('Slot Utilization', '${slotUtilization.toStringAsFixed(1)}%', 'Efficiency', crm.secondary),
          ]),
          24.h,
          _buildReportNotesCard(context, 'Key Issues', Icons.warning_amber_rounded, crm.destructive),
          16.h,
          _buildReportNotesCard(context, 'Key Wins', Icons.emoji_events_outlined, crm.success),
          16.h,
          _buildReportNotesCard(context, 'Tomorrow Priorities', Icons.list_alt_rounded, crm.primary),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text(
          'Report for ${_monthName(date.month)} ${date.day}, ${date.year}',
          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(BuildContext context, List<_MetricItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildMetricCard(context, items[index]),
        );
      },
    );
  }

  Widget _buildMetricCard(BuildContext context, _MetricItem item) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.label, style: TextStyle(color: crm.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          4.h,
          Text(item.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          4.h,
          Text(item.subtext, style: TextStyle(color: item.color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildReportNotesCard(BuildContext context, String title, IconData icon, Color color) {
    final crm = context.crmColors;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: crm.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                12.w,
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_note, size: 20),
                  onPressed: () {
                    // TODO: Implement note editing
                  },
                ),
              ],
            ),
            const Divider(),
            8.h,
            Text(
              'No ${title.toLowerCase()} recorded for today yet.',
              style: TextStyle(color: crm.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  final String subtext;
  final Color color;

  _MetricItem(this.label, this.value, this.subtext, this.color);
}

class _RevenueBreakdownCard extends StatelessWidget {
  const _RevenueBreakdownCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: 24.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Finance Health',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            24.h,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _circularStat(context, 'Gross Revenue', 'INR 2.4M', 0.85, Colors.green),
                _circularStat(context, 'Net Profit', 'INR 840k', 0.35, Colors.blue),
                _circularStat(context, 'Operating Cost', 'INR 1.2M', 0.5, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _circularStat(BuildContext context, String label, String value, double progress, Color color) {
    return Column(
      children: [
        SizedBox(
          height: 80,
          width: 80,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        16.h,
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ExpenseAnalysisCard extends StatelessWidget {
  const _ExpenseAnalysisCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: 24.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            16.h,
            _expenseItem(context, 'Staff Payroll', 'INR 640,000', 0.6),
            16.h,
            _expenseItem(context, 'Marketing Ad Spend', 'INR 180,000', 0.2),
            16.h,
            _expenseItem(context, 'Operational Utilites', 'INR 120,000', 0.1),
          ],
        ),
      ),
    );
  }

  Widget _expenseItem(BuildContext context, String label, String value, double ratio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        8.h,
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.crmColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                color: context.crmColors.warning,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtistDashboardView extends StatelessWidget {
  const _ArtistDashboardView({
    required this.isDesktop,
    required this.isTablet,
    required this.allBookings,
    this.employeeId,
  });

  final bool isDesktop;
  final bool isTablet;
  final List<Booking> allBookings;
  final String? employeeId;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final theme = Theme.of(context);
    
    // Bookings are already filtered by employeeId from the backend provider
    final myBookings = allBookings;

    final now = DateTime.now();
    final todayBookings = myBookings.where((b) => 
      b.serviceStart.year == now.year && 
      b.serviceStart.month == now.month && 
      b.serviceStart.day == now.day
    ).toList();

    final upcomingBookings = myBookings.where((b) => b.serviceStart.isAfter(now)).toList()
      ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));

    final totalEarnings = myBookings
        .where((b) => b.status.toLowerCase() == 'completed')
        .fold<double>(0, (sum, b) => sum + b.totalPrice);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [crm.primary, crm.sidebar],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: crm.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
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
                            'Hello, Artist',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          4.h,
                          Text(
                            todayBookings.isEmpty 
                              ? 'No works today' 
                              : 'You have ${todayBookings.length} tasks',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_none, color: Colors.white),
                    ),
                  ],
                ),
                24.h,
                const Divider(color: Colors.white24),
                16.h,
                Row(
                  children: [
                    _HeaderMiniStat(
                      label: 'Total Collected',
                      value: '₹${totalEarnings.toStringAsFixed(0)}',
                    ),
                    const VerticalDivider(color: Colors.white24, indent: 8, endIndent: 8),
                    _HeaderMiniStat(
                      label: 'Pending',
                      value: '${upcomingBookings.length} Works',
                    ),
                  ],
                ),
              ],
            ),
          ),
          24.h,
          Text(
            'Performance Overview',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          16.h,
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _ModernStatCard(
                  title: 'Completed',
                  value: '${myBookings.where((b) => b.status.toLowerCase() == "completed").length}',
                  icon: Icons.task_alt_rounded,
                  color: Colors.green,
                ),
                16.w,
                _ModernStatCard(
                  title: 'In Progress',
                  value: '${myBookings.where((b) => b.status.toLowerCase() == "confirmed").length}',
                  icon: Icons.sync_rounded,
                  color: Colors.blue,
                ),
                16.w,
                _ModernStatCard(
                  title: 'Assigned',
                  value: '${myBookings.length}',
                  icon: Icons.assignment_rounded,
                  color: crm.primary,
                ),
              ],
            ),
          ),
          32.h,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Schedule',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              TextButton(
                onPressed: () => context.go('/works'),
                child: const Text('View All'),
              ),
            ],
          ),
          12.h,
          if (todayBookings.isEmpty)
            _buildEmptyState(context, 'Relax! No assignments for today.')
          else
            ...todayBookings.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UpcomingBookingTile(booking: b),
            )),
          32.h,
          _ArtistQuickActions(),
          40.h,
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.crmColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.crmColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 48, color: context.crmColors.textSecondary.withValues(alpha: 0.5)),
          16.h,
          Text(message, style: TextStyle(color: context.crmColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ArtistQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            20.h,
            _QuickActionItem(
              icon: Icons.calendar_today,
              title: 'View Calendar',
              onTap: () => context.go('/works'),
              color: crm.primary,
            ),
            _QuickActionItem(
              icon: Icons.add_moderator_outlined,
              title: 'Request Leave',
              onTap: () => context.go('/leave-requests'),
              color: Colors.orange,
            ),
            _QuickActionItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'My Finance',
              onTap: () => context.go('/finance'),
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  const _QuickActionItem({required this.icon, required this.title, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

class _HeaderMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        4.h,
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crm.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: crm.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
