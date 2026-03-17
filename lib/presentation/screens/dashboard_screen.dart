import 'package:flutter/material.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBuilder.isDesktop(context);
    final isTablet = ResponsiveBuilder.isTablet(context);

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
                  onPressed: () {},
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
              double itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
              
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _StatCard(title: 'Today\'s Appointments', value: '18', icon: Icons.event, trend: '+4 from yesterday', width: itemWidth),
                  _StatCard(title: 'Monthly Revenue', value: '\$42,500', icon: Icons.attach_money, trend: '+12% from last month', width: itemWidth),
                  _StatCard(title: 'New Clients', value: '64', icon: Icons.group_add, trend: '+8% from last month', width: itemWidth),
                  _StatCard(title: 'Customer Satisfaction', value: '4.9/5', icon: Icons.star_border, trend: '+0.2 from last month', width: itemWidth),
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
                      const _RevenueChartCard(),
                      24.h,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: const _PopularServicesCard()),
                          24.w,
                          Expanded(child: const _TopStaffCard()),
                        ],
                      )
                    ],
                  ),
                ),
                24.w,
                Expanded(
                  flex: 1,
                  child: const _UpcomingBookingsCard(),
                ),
              ],
            )
          else
            Column(
              children: [
                const _RevenueChartCard(),
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
                ]
              ],
            )
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String trend;
  final double width;

  const _StatCard({required this.title, required this.value, required this.icon, required this.trend, required this.width});

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
                    child: Text(title, style: TextStyle(color: crmColors.textSecondary, fontWeight: FontWeight.w500)),
                  ),
                  Container(
                    padding: 8.p,
                    decoration: BoxDecoration(
                      color: crmColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: crmColors.textPrimary),
                  ),
                ],
              ),
              16.h,
              Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: crmColors.textPrimary)),
              8.h,
              Row(
                children: [
                  Icon(Icons.trending_up, size: 16, color: crmColors.success),
                  4.w,
                  Expanded(
                    child: Text(trend, style: TextStyle(color: crmColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
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
  const _RevenueChartCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Revenue Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                TextButton(onPressed: () {}, child: const Text('View Report')),
              ],
            ),
            16.h,
            // Placeholder for Bar Chart
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.crmColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Bar Chart Placeholder\n(Requires a charting package like fl_chart)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingBookingsCard extends StatelessWidget {
  const _UpcomingBookingsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Upcoming Bookings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                TextButton(onPressed: () {}, child: const Text('View Calendar')),
              ],
            ),
            16.h,
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final bookings = [
                  {'name': 'Emma Watson', 'service': 'Bridal Makeover', 'time': '10:00 AM', 'status': 'CONFIRMED'},
                  {'name': 'Sarah Jenkins', 'service': 'Luxury Facial', 'time': '11:30 AM', 'status': 'PENDING'},
                  {'name': 'Chloe Kim', 'service': 'Hair Styling', 'time': '1:00 PM', 'status': 'CONFIRMED'},
                  {'name': 'Maria Garcia', 'service': 'Manicure & Pedicure', 'time': '2:45 PM', 'status': 'CONFIRMED'},
                ];
                final b = bookings[index];
                final isConfirmed = b['status'] == 'CONFIRMED';
                final crmColors = context.crmColors;
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(b['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(b['service']!),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(b['time']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                      4.h,
                      Container(
                        padding: 4.px,
                        decoration: BoxDecoration(
                          color: isConfirmed ? crmColors.success.withOpacity(0.1) : crmColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          b['status']!,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isConfirmed ? crmColors.success : crmColors.warning),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularServicesCard extends StatelessWidget {
  const _PopularServicesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Popular Services', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
            16.h,
            // Mock list
            _buildServiceItem(context, Icons.auto_awesome, 'Bridal Makeover Package', '\$18,500', '124 Bookings this month'),
            const Divider(),
            _buildServiceItem(context, Icons.cut, 'Premium Hair Styling', '\$8,200', '98 Bookings this month'),
            const Divider(),
            _buildServiceItem(context, Icons.spa, 'Luxury Spa Facial', '\$6,500', '65 Bookings this month'),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, IconData icon, String name, String rev, String bookings) {
    final crmColors = context.crmColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: 8.p,
        decoration: BoxDecoration(color: crmColors.background, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: crmColors.textPrimary),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(bookings),
      trailing: Text(rev, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _TopStaffCard extends StatelessWidget {
  const _TopStaffCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Top Performing Staff', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                TextButton(onPressed: () {}, child: const Text('View Team')),
              ],
            ),
            16.h,
            // Mock list
            _buildStaffItem(context, 'Jessica Davis', 'Senior Makeover Artist', '4.9', '42 Appointments'),
            const Divider(),
            _buildStaffItem(context, 'Amanda Lopez', 'Hair Stylist', '4.8', '38 Appointments'),
            const Divider(),
            _buildStaffItem(context, 'Michael Chen', 'Esthetician', '4.7', '31 Appointments'),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffItem(BuildContext context, String name, String role, String rating, String appts) {
    final crmColors = context.crmColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(role),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: 14, color: crmColors.warning),
              4.w,
              Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          4.h,
          Text(appts, style: TextStyle(fontSize: 12, color: crmColors.textSecondary)),
        ],
      ),
    );
  }
}
