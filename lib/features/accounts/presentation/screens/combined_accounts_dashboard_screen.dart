import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/models/trial.dart';
import 'package:nizan_crm/core/providers/trial_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/subscription_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/features/inventory/data/purchase.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';

class CombinedAccountsDashboardScreen extends ConsumerStatefulWidget {
  const CombinedAccountsDashboardScreen({super.key});

  @override
  ConsumerState<CombinedAccountsDashboardScreen> createState() =>
      _CombinedAccountsDashboardScreenState();
}

class _CombinedAccountsDashboardScreenState
    extends ConsumerState<CombinedAccountsDashboardScreen> {
  static String _compact(double value) {
    final v = value.abs();
    final sign = value < 0 ? '-' : '';
    if (v >= 10000000) return '$sign₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '$sign₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '$sign₹${(v / 1000).toStringAsFixed(1)}k';
    return '$sign₹${v.toStringAsFixed(0)}';
  }

  bool _inMonth(DateTime d, DateTime m) => d.year == m.year && d.month == m.month;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final crm = context.crmColors;
    final now = DateTime.now();

    // Operations Data
    final asyncCollections = ref.watch(collectionsProvider);
    final asyncExpenses = ref.watch(expensesProvider);
    final asyncBookings = ref.watch(bookingProvider);
    final purchases = ref.watch(purchasesProvider).value ?? const <Purchase>[];
    final trials = ref.watch(allTrialsProvider).value ?? const <Trial>[];

    // Administrative Data
    final asyncAdminStats = ref.watch(adminExpenseStatsProvider);
    final asyncSubStats = ref.watch(subscriptionStatsProvider);

    final loading = asyncCollections.isLoading ||
        asyncExpenses.isLoading ||
        asyncBookings.isLoading ||
        asyncAdminStats.isLoading ||
        asyncSubStats.isLoading;

    final error = asyncCollections.error ??
        asyncExpenses.error ??
        asyncBookings.error ??
        asyncAdminStats.error ??
        asyncSubStats.error;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Text('Failed to load dashboard: $error',
              style: TextStyle(color: crm.textSecondary)),
        ),
      );
    }

    final allCollections = asyncCollections.value ?? <ArtistCollection>[];
    final allArtistExpenses = asyncExpenses.value ?? <ArtistExpense>[];
    final allBookings = asyncBookings.value ?? <Booking>[];
    final adminStats = asyncAdminStats.value!;
    final subStats = asyncSubStats.value!;

    // Filter Operations by current month
    final collections = allCollections.where((c) => c.status != 'rejected' && _inMonth(c.date, now));
    final artistExpenses = allArtistExpenses.where((e) => e.status != 'rejected' && _inMonth(e.date, now));
    final advances = allBookings.where((b) {
      final s = b.status.toLowerCase();
      if (s == 'cancelled' || s == 'rejected') return false;
      if (b.advanceAmount <= 0) return false;
      return _inMonth(b.createdAt ?? b.bookingDate, now);
    });
    final purchasesThisMonth = purchases.where((p) => _inMonth(p.date, now));
    final trialsThisMonth = trials.where((t) => t.status.toLowerCase() != 'cancelled' && _inMonth(t.trialDate, now));

    // Sums
    final collSum = collections.fold<double>(0, (s, c) => s + c.amount);
    final advSum = advances.fold<double>(0, (s, b) => s + b.advanceAmount);
    final trialRev = trialsThisMonth.fold<double>(0, (s, t) => s + t.trialItems.fold<double>(0, (a, i) => a + i.price));
    final opsIncome = collSum + advSum + trialRev;

    final artistExpSum = artistExpenses.fold<double>(0, (s, e) => s + e.amount);
    final purchSum = purchasesThisMonth.fold<double>(0, (s, p) => s + p.grandTotal);
    final opsExpenses = artistExpSum + purchSum;

    // Admin
    final adminSpend = adminStats.thisMonthAmount;
    final subSpend = subStats.monthlyRunRate;
    final totalAdminSpend = adminSpend + subSpend;

    // Totals
    final totalCompanyIncome = opsIncome;
    final totalCompanySpend = opsExpenses + totalAdminSpend;
    final netCompanyProfit = totalCompanyIncome - totalCompanySpend;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(collectionsProvider);
          ref.invalidate(expensesProvider);
          ref.invalidate(bookingProvider);
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
                        'Combined Accounts Dashboard',
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      4.h,
                      Text(
                        'Holistic view of all company finances (Operations + Administrative) for ${DateFormat('MMMM yyyy').format(now)}',
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

            // Top Level KPIs
            InvStatGrid(
              isMobile: isMobile,
              stats: [
                InvStat(
                  _compact(totalCompanyIncome),
                  'Total Company Income',
                  Icons.arrow_circle_up_outlined,
                  crm.primary,
                ),
                InvStat(
                  _compact(totalCompanySpend),
                  'Total Company Spend',
                  Icons.arrow_circle_down_outlined,
                  crm.destructive,
                ),
                InvStat(
                  _compact(netCompanyProfit),
                  'Net Profit/Loss',
                  netCompanyProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                  netCompanyProfit >= 0 ? crm.success : crm.destructive,
                ),
              ],
            ),

            24.h,

            // Breakdowns
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _BreakdownCard(
                    title: 'Operations Breakdown',
                    icon: Icons.dashboard_customize_outlined,
                    color: crm.primary,
                    items: [
                      _BreakdownItem('Collections', collSum, crm.textPrimary),
                      _BreakdownItem('Advances', advSum, crm.textPrimary),
                      _BreakdownItem('Trial Revenue', trialRev, crm.textPrimary),
                      _BreakdownItem('Artist Expenses', -artistExpSum, crm.destructive),
                      _BreakdownItem('Inventory Purchases', -purchSum, crm.destructive),
                    ],
                    total: opsIncome - opsExpenses,
                    totalLabel: 'Operations Net',
                  ),
                ),
                if (!isMobile) 16.w,
                if (!isMobile)
                  Expanded(
                    child: _BreakdownCard(
                      title: 'Administrative Breakdown',
                      icon: Icons.admin_panel_settings_outlined,
                      color: crm.warning,
                      items: [
                        _BreakdownItem('Admin Expenses & Salaries', -adminSpend, crm.destructive),
                        _BreakdownItem('Subscriptions', -subSpend, crm.destructive),
                      ],
                      total: -totalAdminSpend,
                      totalLabel: 'Administrative Net',
                    ),
                  ),
              ],
            ),
            if (isMobile) ...[
              16.h,
              _BreakdownCard(
                title: 'Administrative Breakdown',
                icon: Icons.admin_panel_settings_outlined,
                color: crm.warning,
                items: [
                  _BreakdownItem('Admin Expenses & Salaries', -adminSpend, crm.destructive),
                  _BreakdownItem('Subscriptions', -subSpend, crm.destructive),
                ],
                total: -totalAdminSpend,
                totalLabel: 'Administrative Net',
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_BreakdownItem> items;
  final double total;
  final String totalLabel;

  const _BreakdownCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.total,
    required this.totalLabel,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: color, size: 20),
              8.w,
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: crm.textPrimary,
                ),
              ),
            ],
          ),
          16.h,
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: crm.textSecondary,
                      ),
                    ),
                    Text(
                      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(item.value),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: item.color,
                      ),
                    ),
                  ],
                ),
              )),
          Divider(color: crm.border),
          8.h,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: crm.textPrimary,
                ),
              ),
              Text(
                NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(total),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: total >= 0 ? crm.success : crm.destructive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownItem {
  final String label;
  final double value;
  final Color color;
  const _BreakdownItem(this.label, this.value, this.color);
}
