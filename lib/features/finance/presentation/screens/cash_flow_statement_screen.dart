import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/trial.dart';
import 'package:nizan_crm/core/providers/trial_provider.dart';
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
import 'package:nizan_crm/features/finance/presentation/widgets/report_chrome.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';

String _money(num v) => NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 0)
    .format(v);

/// Finance → Cash Flow Statement. Cash IN (collections, advances, trials) vs
/// cash OUT (artist expenses, purchases, admin, subscriptions) for a month,
/// with the net movement — a Zoho-style operating cash-flow view.
///
/// Scoped to the CURRENT month: administrative figures come from month stats,
/// so historical months aren't shown here.
class CashFlowStatementScreen extends ConsumerStatefulWidget {
  const CashFlowStatementScreen({super.key});

  @override
  ConsumerState<CashFlowStatementScreen> createState() =>
      _CashFlowStatementScreenState();
}

class _CashFlowStatementScreenState
    extends ConsumerState<CashFlowStatementScreen> {
  bool _inMonth(DateTime d, DateTime m) => d.year == m.year && d.month == m.month;

  ({
    double collections,
    double advances,
    double trials,
    double artistExp,
    double purchases,
    double admin,
    double subs,
  })? _last;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final now = DateTime.now();

    final asyncCollections = ref.watch(collectionsProvider);
    final asyncExpenses = ref.watch(expensesProvider);
    final asyncBookings = ref.watch(bookingProvider);
    final asyncAdminStats = ref.watch(adminExpenseStatsProvider);
    final asyncSubStats = ref.watch(subscriptionStatsProvider);
    final purchases = ref.watch(purchasesProvider).value ?? const <Purchase>[];
    final trials = ref.watch(allTrialsProvider).value ?? const <Trial>[];

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

    void refresh() {
      ref.invalidate(collectionsProvider);
      ref.invalidate(expensesProvider);
      ref.invalidate(bookingProvider);
      ref.invalidate(adminExpenseStatsProvider);
      ref.invalidate(subscriptionStatsProvider);
      ref.invalidate(purchasesProvider);
    }

    Widget content;
    if (loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      content = Center(
          child: Text(friendlyErrorMessage(error),
              style: TextStyle(color: crm.destructive)));
    } else {
      final allCollections = asyncCollections.value ?? <ArtistCollection>[];
      final allArtistExpenses = asyncExpenses.value ?? <ArtistExpense>[];
      final allBookings = asyncBookings.value ?? <Booking>[];
      final adminStats = asyncAdminStats.value;
      final subStats = asyncSubStats.value;

      // Cash IN
      final collSum = allCollections
          .where((c) => c.status != 'rejected' && _inMonth(c.date, now))
          .fold<double>(0, (s, c) => s + c.amount);
      final advSum = allBookings.where((b) {
        final st = b.status.toLowerCase();
        if (st == 'cancelled' || st == 'rejected') return false;
        if (b.advanceAmount <= 0) return false;
        return _inMonth(b.createdAt ?? b.bookingDate, now);
      }).fold<double>(0, (s, b) => s + b.advanceAmount);
      final trialSum = trials
          .where((t) =>
              t.status.toLowerCase() != 'cancelled' && _inMonth(t.trialDate, now))
          .fold<double>(
              0,
              (s, t) =>
                  s + t.trialItems.fold<double>(0, (a, i) => a + i.price));

      // Cash OUT
      final artistExpSum = allArtistExpenses
          .where((e) => e.status != 'rejected' && _inMonth(e.date, now))
          .fold<double>(0, (s, e) => s + e.amount);
      final purchSum = purchases
          .where((p) => _inMonth(p.date, now))
          .fold<double>(0, (s, p) => s + p.grandTotal);
      final adminSum = adminStats?.thisMonthAmount ?? 0;
      final subSum = subStats?.monthlyRunRate ?? 0;

      _last = (
        collections: collSum,
        advances: advSum,
        trials: trialSum,
        artistExp: artistExpSum,
        purchases: purchSum,
        admin: adminSum,
        subs: subSum,
      );

      final totalIn = collSum + advSum + trialSum;
      final totalOut = artistExpSum + purchSum + adminSum + subSum;
      final net = totalIn - totalOut;

      content = RefreshIndicator(
        onRefresh: () async => refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            ReportTitleBlock(
                title: 'Cash Flow — ${DateFormat('MMMM yyyy').format(now)}',
                asOf: true,
                to: now),
            12.h,
            _netCard(crm, net),
            18.h,
            _section(crm, 'Cash inflows', crm.success, [
              _Row('Collections received', collSum),
              _Row('Booking advances', advSum),
              _Row('Trial revenue', trialSum),
            ], totalIn, 'Total cash in'),
            16.h,
            _section(crm, 'Cash outflows', crm.destructive, [
              _Row('Artist expenses', artistExpSum),
              _Row('Inventory purchases', purchSum),
              _Row('Admin expenses', adminSum),
              _Row('Subscriptions', subSum),
            ], totalOut, 'Total cash out'),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: crm.background,
      body: ReportChrome(
        category: 'Business Overview',
        title: 'Cash Flow Statement',
        preset: DateRangePreset.allTime,
        onPreset: (_) {},
        asOf: true,
        to: now,
        onExport: _last == null ? null : () => _exportCsv(context),
        onRefresh: () async => refresh(),
        child: content,
      ),
    );
  }

  Widget _netCard(CrmTheme crm, double net) {
    final positive = net >= 0;
    final color = positive ? crm.success : crm.destructive;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: color, size: 30),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Net cash flow this month',
                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              const SizedBox(height: 2),
              Text(_money(net),
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(CrmTheme crm, String title, Color accent, List<_Row> rows,
      double total, String totalLabel) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(title.toUpperCase(),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: crm.textPrimary)),
              ],
            ),
          ),
          Divider(height: 1, color: crm.border),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(children: [
                Expanded(
                    child: Text(r.label,
                        style: TextStyle(fontSize: 13.5, color: crm.textPrimary))),
                Text(_money(r.amount),
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          Divider(height: 1, color: crm.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              Expanded(
                  child: Text(totalLabel,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary))),
              Text(_money(total),
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900, color: accent)),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final d = _last;
    if (d == null) return;
    final totalIn = d.collections + d.advances + d.trials;
    final totalOut = d.artistExp + d.purchases + d.admin + d.subs;
    final rows = <List<Object?>>[
      ['Cash Flow Statement', DateFormat('MMMM yyyy').format(DateTime.now())],
      [],
      ['Cash inflows', ''],
      ['Collections received', csvNum(d.collections)],
      ['Booking advances', csvNum(d.advances)],
      ['Trial revenue', csvNum(d.trials)],
      ['Total cash in', csvNum(totalIn)],
      [],
      ['Cash outflows', ''],
      ['Artist expenses', csvNum(d.artistExp)],
      ['Inventory purchases', csvNum(d.purchases)],
      ['Admin expenses', csvNum(d.admin)],
      ['Subscriptions', csvNum(d.subs)],
      ['Total cash out', csvNum(totalOut)],
      [],
      ['Net cash flow', csvNum(totalIn - totalOut)],
    ];
    try {
      await downloadCsv('cash_flow_statement.csv', rows);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cash flow statement exported')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }
}

class _Row {
  final String label;
  final double amount;
  const _Row(this.label, this.amount);
}
