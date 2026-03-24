import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/dashboard_report_service.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/employee_service.dart';
import '../../services/package_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveBuilder.isDesktop(context);
    final isTablet = ResponsiveBuilder.isTablet(context);
    final asyncBookings = ref.watch(bookingProvider);
    final asyncPackages = ref.watch(packagesProvider);
    final asyncEmployees = ref.watch(employeesProvider);
    final allBookings = asyncBookings.value ?? const <Booking>[];
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

      await downloadDashboardReport(
        month: now,
        bookings: bookings,
        packages: packages,
        employees: employees,
      );
    }

    return SingleChildScrollView(
      child: Column(
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
          24.h,

          // STATS ROW
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

          // MAIN CONTENT GRID
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
                        onExport: exportReport,
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
                  onExport: exportReport,
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
