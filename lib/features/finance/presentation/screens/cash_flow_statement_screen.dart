import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/subscription.dart';
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
/// cash OUT (artist expenses, purchases, admin, subscriptions) with the net
/// movement — respects the Date Range filter (all sources are date-driven;
/// subscriptions are prorated by the number of months in the range).
class CashFlowStatementScreen extends ConsumerStatefulWidget {
  const CashFlowStatementScreen({super.key});

  @override
  ConsumerState<CashFlowStatementScreen> createState() =>
      _CashFlowStatementScreenState();
}

class _CashFlowStatementScreenState
    extends ConsumerState<CashFlowStatementScreen> {
  DateTime? _from;
  DateTime? _to;
  DateRangePreset _preset = DateRangePreset.thisMonth;
  String? _drill; // which line we've drilled into

  ({
    double collections,
    double advances,
    double trials,
    double artistExp,
    double purchases,
    double admin,
    double subs,
    String range,
  })? _last;

  @override
  void initState() {
    super.initState();
    final r = rangeForPreset(_preset, DateTime.now());
    _from = r.from;
    _to = r.to;
  }

  bool _inRange(DateTime d) {
    if (_from != null && d.isBefore(_from!)) return false;
    if (_to != null &&
        d.isAfter(DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59))) {
      return false;
    }
    return true;
  }

  Future<void> _applyPreset(DateRangePreset p) async {
    if (p == DateRangePreset.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2015),
        lastDate: DateTime(now.year + 1),
        initialDateRange: _from != null && _to != null
            ? DateTimeRange(start: _from!, end: _to!)
            : null,
      );
      if (picked != null) {
        setState(() {
          _preset = p;
          _from = picked.start;
          _to = picked.end;
        });
      }
      return;
    }
    final r = rangeForPreset(p, DateTime.now());
    setState(() {
      _preset = p;
      _from = r.from;
      _to = r.to;
    });
  }

  int _monthsBetween(DateTime a, DateTime b) =>
      ((b.year - a.year) * 12 + (b.month - a.month) + 1).clamp(1, 1200);

  double _subMonthly(Subscription s) {
    switch (s.billingCycle) {
      case 'yearly':
        return s.cost / 12;
      case 'quarterly':
        return s.cost / 3;
      case 'one-time':
        return 0; // one-off, not a recurring monthly run-rate
      default:
        return s.cost; // monthly
    }
  }

  String get _rangeLabel {
    if (_from == null && _to == null) return 'All time';
    final f = _from == null ? '…' : DateFormat('d MMM yyyy').format(_from!);
    final t = _to == null ? '…' : DateFormat('d MMM yyyy').format(_to!);
    return '$f – $t';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;

    final asyncCollections = ref.watch(collectionsProvider);
    final asyncExpenses = ref.watch(expensesProvider);
    final asyncBookings = ref.watch(bookingProvider);
    final asyncAdmin = ref.watch(adminExpensesProvider);
    final asyncSubs = ref.watch(subscriptionsProvider);
    final purchases = ref.watch(purchasesProvider).value ?? const <Purchase>[];
    final trials = ref.watch(allTrialsProvider).value ?? const <Trial>[];

    final loading = asyncCollections.isLoading ||
        asyncExpenses.isLoading ||
        asyncBookings.isLoading ||
        asyncAdmin.isLoading ||
        asyncSubs.isLoading;
    final error = asyncCollections.error ??
        asyncExpenses.error ??
        asyncBookings.error ??
        asyncAdmin.error ??
        asyncSubs.error;

    void refresh() {
      ref.invalidate(collectionsProvider);
      ref.invalidate(expensesProvider);
      ref.invalidate(bookingProvider);
      ref.invalidate(adminExpensesProvider);
      ref.invalidate(subscriptionsProvider);
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
      final collections = asyncCollections.value ?? <ArtistCollection>[];
      final artistExpenses = asyncExpenses.value ?? <ArtistExpense>[];
      final bookings = asyncBookings.value ?? <Booking>[];
      final adminExpenses = asyncAdmin.value ?? <AdminExpense>[];
      final subs = asyncSubs.value ?? <Subscription>[];

      // Cash IN
      final collSum = collections
          .where((c) => c.status != 'rejected' && _inRange(c.date))
          .fold<double>(0, (s, c) => s + c.amount);
      final advSum = bookings.where((b) {
        final st = b.status.toLowerCase();
        if (st == 'cancelled' || st == 'rejected') return false;
        if (b.advanceAmount <= 0) return false;
        return _inRange(b.createdAt ?? b.bookingDate);
      }).fold<double>(0, (s, b) => s + b.advanceAmount);
      final trialSum = trials
          .where((t) =>
              t.status.toLowerCase() != 'cancelled' && _inRange(t.trialDate))
          .fold<double>(
              0,
              (s, t) =>
                  s + t.trialItems.fold<double>(0, (a, i) => a + i.price));

      // Cash OUT
      final artistExpSum = artistExpenses
          .where((e) => e.status != 'rejected' && _inRange(e.date))
          .fold<double>(0, (s, e) => s + e.amount);
      final purchSum = purchases
          .where((p) => _inRange(p.date))
          .fold<double>(0, (s, p) => s + p.grandTotal);
      // Only APPROVED admin expenses are actual cash out — a department head's
      // pending submission is not paid until Accounts approves it.
      final adminSum = adminExpenses
          .where((e) => e.status == 'approved' && _inRange(e.date))
          .fold<double>(0, (s, e) => s + e.amount);

      // Subscriptions are a recurring monthly run-rate → prorate to the range.
      final subMonthly = subs
          .where((s) => s.status.toLowerCase() != 'cancelled')
          .fold<double>(0, (a, s) => a + _subMonthly(s));
      final effFrom = _from ??
          _earliestDate(collections, bookings, trials, artistExpenses,
              purchases, adminExpenses) ??
          DateTime.now();
      final effTo = _to ?? DateTime.now();
      final months = _monthsBetween(effFrom, effTo);
      final subSum = subMonthly * months;

      _last = (
        collections: collSum,
        advances: advSum,
        trials: trialSum,
        artistExp: artistExpSum,
        purchases: purchSum,
        admin: adminSum,
        subs: subSum,
        range: _rangeLabel,
      );

      final totalIn = collSum + advSum + trialSum;
      final totalOut = artistExpSum + purchSum + adminSum + subSum;
      final net = totalIn - totalOut;

      content = _drill != null
          ? _drillView(crm, _drill!, collections, bookings, trials,
              artistExpenses, purchases, adminExpenses, subs, months)
          : RefreshIndicator(
        onRefresh: () async => refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            ReportTitleBlock(
                title: 'Cash Flow', asOf: false, from: _from, to: _to),
            12.h,
            _netCard(crm, net),
            18.h,
            _section(crm, 'Cash inflows', crm.success, [
              _Row('Collections received', collSum, 'collections'),
              _Row('Booking advances', advSum, 'advances'),
              _Row('Trial revenue', trialSum, 'trials'),
            ], totalIn, 'Total cash in'),
            16.h,
            _section(crm, 'Cash outflows', crm.destructive, [
              _Row('Artist expenses', artistExpSum, 'artistExp'),
              _Row('Inventory purchases', purchSum, 'purchases'),
              _Row('Admin expenses', adminSum, 'admin'),
              _Row('Subscriptions ($months mo)', subSum, 'subs'),
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
        preset: _preset,
        from: _from,
        to: _to,
        onPreset: _applyPreset,
        onExport: _last == null ? null : () => _exportCsv(context),
        onRefresh: () async => refresh(),
        child: content,
      ),
    );
  }

  DateTime? _earliestDate(
    List<ArtistCollection> collections,
    List<Booking> bookings,
    List<Trial> trials,
    List<ArtistExpense> artistExpenses,
    List<Purchase> purchases,
    List<AdminExpense> adminExpenses,
  ) {
    DateTime? min;
    void consider(DateTime? d) {
      if (d == null) return;
      if (min == null || d.isBefore(min!)) min = d;
    }

    for (final c in collections) {
      consider(c.date);
    }
    for (final b in bookings) {
      consider(b.createdAt ?? b.bookingDate);
    }
    for (final t in trials) {
      consider(t.trialDate);
    }
    for (final e in artistExpenses) {
      consider(e.date);
    }
    for (final p in purchases) {
      consider(p.date);
    }
    for (final e in adminExpenses) {
      consider(e.date);
    }
    return min;
  }

  // ── Tier 3: the records behind one cash-flow line ───────────────────────────
  Widget _drillView(
    CrmTheme crm,
    String key,
    List<ArtistCollection> collections,
    List<Booking> bookings,
    List<Trial> trials,
    List<ArtistExpense> artistExpenses,
    List<Purchase> purchases,
    List<AdminExpense> adminExpenses,
    List<Subscription> subs,
    int months,
  ) {
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    String dl(DateTime? d) =>
        d == null ? '' : '${d.day} ${mo[d.month - 1]} ${d.year}';

    final items = <_DrillItem>[];
    String title;
    switch (key) {
      case 'collections':
        title = 'Collections received';
        for (final c in collections
            .where((c) => c.status != 'rejected' && _inRange(c.date))) {
          final name = (c.booking?.customerName ?? '').isNotEmpty
              ? c.booking!.customerName
              : ((c.trial?.clientName ?? '').isNotEmpty
                  ? c.trial!.clientName
                  : 'Collection');
          items.add(_DrillItem(name, dl(c.date), c.amount));
        }
        break;
      case 'advances':
        title = 'Booking advances';
        for (final b in bookings.where((b) {
          final st = b.status.toLowerCase();
          return st != 'cancelled' &&
              st != 'rejected' &&
              b.advanceAmount > 0 &&
              _inRange(b.createdAt ?? b.bookingDate);
        })) {
          items.add(_DrillItem(
              b.customerName.isEmpty ? 'Booking' : b.customerName,
              dl(b.createdAt ?? b.bookingDate),
              b.advanceAmount,
              route: '/booking/manage/${b.id}'));
        }
        break;
      case 'trials':
        title = 'Trial revenue';
        for (final t in trials.where(
            (t) => t.status.toLowerCase() != 'cancelled' && _inRange(t.trialDate))) {
          final amt = t.trialItems.fold<double>(0, (a, i) => a + i.price);
          items.add(_DrillItem(
              t.clientName.isEmpty ? 'Trial' : t.clientName, dl(t.trialDate), amt));
        }
        break;
      case 'artistExp':
        title = 'Artist expenses';
        for (final e in artistExpenses
            .where((e) => e.status != 'rejected' && _inRange(e.date))) {
          items.add(_DrillItem(
              e.category.isEmpty ? 'Expense' : e.category, dl(e.date), e.amount));
        }
        break;
      case 'purchases':
        title = 'Inventory purchases';
        for (final p in purchases.where((p) => _inRange(p.date))) {
          items.add(_DrillItem('Purchase', dl(p.date), p.grandTotal));
        }
        break;
      case 'admin':
        title = 'Admin expenses';
        for (final e in adminExpenses
            .where((e) => e.status == 'approved' && _inRange(e.date))) {
          items.add(_DrillItem(
              e.title.isEmpty ? 'Expense' : e.title,
              '${dl(e.date)}${e.vendor.trim().isNotEmpty ? '  ·  ${e.vendor.trim()}' : ''}',
              e.amount));
        }
        break;
      case 'subs':
        title = 'Subscriptions';
        for (final s in subs.where((s) => s.status.toLowerCase() != 'cancelled')) {
          final m = _subMonthly(s);
          if (m <= 0) continue;
          items.add(_DrillItem(s.name.isEmpty ? 'Subscription' : s.name,
              '${s.billingCycle} · ₹${m.toStringAsFixed(0)}/mo × $months', m * months));
        }
        break;
      default:
        title = '';
    }
    items.sort((a, b) => b.amount.compareTo(a.amount));
    final total = items.fold<double>(0, (s, i) => s + i.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      children: [
        Row(children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: () => setState(() => _drill = null),
          ),
          Expanded(
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              InkWell(
                onTap: () => setState(() => _drill = null),
                child: Text('Cash Flow',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: crm.primary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right_rounded,
                    size: 16, color: crm.textSecondary),
              ),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
            ]),
          ),
        ]),
        12.h,
        if (items.isEmpty)
          Container(
            decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: crm.border)),
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
                child: Text('No records for this line in the selected range.',
                    style: TextStyle(color: crm.textSecondary))),
          )
        else
          Container(
            decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: crm.border)),
            child: Column(children: [
              for (final it in items)
                InkWell(
                  onTap:
                      it.route == null ? null : () => context.push(it.route!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: crm.border.withValues(alpha: 0.4)))),
                    child: Row(children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: crm.textPrimary)),
                            if (it.subtitle.isNotEmpty)
                              Text(it.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11, color: crm.textSecondary)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(_money(it.amount),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      if (it.route != null)
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: crm.textSecondary),
                    ]),
                  ),
                ),
              Divider(height: 1, color: crm.border),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Expanded(
                      child: Text('TOTAL',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary))),
                  Text(_money(total),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: crm.primary)),
                ]),
              ),
            ]),
          ),
      ],
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
              Text('Net cash flow · $_rangeLabel',
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
            InkWell(
              onTap: r.drillKey == null
                  ? null
                  : () => setState(() => _drill = r.drillKey),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(children: [
                  Expanded(
                      child: Text(r.label,
                          style: TextStyle(
                              fontSize: 13.5, color: crm.textPrimary))),
                  Text(_money(r.amount),
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  if (r.drillKey != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 16, color: crm.textSecondary),
                    ),
                ]),
              ),
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
      ['Cash Flow Statement', d.range],
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
  final String? drillKey;
  const _Row(this.label, this.amount, [this.drillKey]);
}

class _DrillItem {
  final String title;
  final String subtitle;
  final double amount;
  final String? route;
  const _DrillItem(this.title, this.subtitle, this.amount, {this.route});
}
