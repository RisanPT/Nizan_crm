import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/subscription_controller.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:fl_chart/fl_chart.dart';

class AdministrativeDashboardScreen extends ConsumerStatefulWidget {
  const AdministrativeDashboardScreen({super.key});

  @override
  ConsumerState<AdministrativeDashboardScreen> createState() =>
      _AdministrativeDashboardScreenState();
}

class _AdministrativeDashboardScreenState
    extends ConsumerState<AdministrativeDashboardScreen> {
  static String _money(double v) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(v);

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final crm = context.crmColors;

    final asyncAdminStats = ref.watch(adminExpenseStatsProvider);
    final asyncSubStats = ref.watch(subscriptionStatsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminExpenseStatsProvider);
          ref.invalidate(subscriptionStatsProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            16,
            isMobile ? 16 : 24,
            32,
          ),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrative Dashboard',
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      4.h,
                      Text(
                        'Overview of administrative expenses, payroll, and subscriptions',
                        style: TextStyle(
                          fontSize: 13,
                          color: crm.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            24.h,

            // Stats Cards
            asyncAdminStats.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading admin stats: $e'),
              data: (adminStats) {
                return asyncSubStats.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error loading subscription stats: $e'),
                  data: (subStats) {
                    final totalMonthlyRunRate = adminStats.thisMonthAmount + subStats.monthlyRunRate;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InvStatGrid(
                          isMobile: isMobile,
                          stats: [
                            InvStat(
                              _money(adminStats.thisMonthAmount),
                              'Admin Expenses (Month)',
                              Icons.payments_outlined,
                              crm.primary,
                            ),
                            InvStat(
                              _money(subStats.monthlyRunRate),
                              'Software Run Rate / Mo',
                              Icons.cloud_sync_outlined,
                              crm.accent,
                            ),
                            InvStat(
                              _money(totalMonthlyRunRate),
                              'Total Admin Burn / Mo',
                              Icons.account_balance_wallet_outlined,
                              crm.destructive,
                            ),
                            InvStat(
                              '${subStats.upcomingRenewalsCount}',
                              'Upcoming Sub Renewals',
                              Icons.event_outlined,
                              crm.warning,
                            ),
                          ],
                        ),
                        24.h,
                        if (adminStats.departmentBreakdown.isNotEmpty) ...[
                          Text(
                            'Administrative Expenses by Department',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary,
                            ),
                          ),
                          16.h,
                          SizedBox(
                            height: 300,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final keys = adminStats.departmentBreakdown.keys.toList();
                                        if (value.toInt() < 0 || value.toInt() >= keys.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            keys[value.toInt()],
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: crm.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false),
                                barGroups: adminStats.departmentBreakdown.entries.map((e) {
                                  final index = adminStats.departmentBreakdown.keys.toList().indexOf(e.key);
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: e.value,
                                        color: crm.primary,
                                        width: 16,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
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
}
