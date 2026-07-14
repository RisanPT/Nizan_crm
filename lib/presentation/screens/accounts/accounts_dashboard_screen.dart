import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/artist_collection.dart';
import '../../../core/models/artist_expense.dart';
import '../../../core/models/booking.dart';
import '../../../core/models/purchase.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/collection_service.dart';
import '../../../services/expense_service.dart';
import '../../../services/inventory_service.dart';
import '../../common_widgets/export_report_dialog.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _compact(double value) {
  final v = value.abs();
  final sign = value < 0 ? '-' : '';
  if (v >= 10000000) return '$sign₹${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '$sign₹${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '$sign₹${(v / 1000).toStringAsFixed(1)}k';
  return '$sign₹${v.toStringAsFixed(0)}';
}

String _rupees(double v) => '₹${v.toStringAsFixed(0)}';
bool _inMonth(DateTime d, DateTime m) => d.year == m.year && d.month == m.month;

double? _pctChange(double current, double previous) {
  if (previous <= 0) return null;
  return (current - previous) / previous * 100;
}

String _dtLabel(DateTime dt) =>
    '${DateFormat('d MMM yyyy').format(dt)} · ${DateFormat('h:mm a').format(dt)}';

String _pmLabel(String mode) {
  switch (mode) {
    case 'bank_transfer':
      return 'Bank Transfer';
    case 'upi':
      return 'UPI';
    case 'cash':
      return 'Cash';
    case 'split':
      return 'Split';
    case 'credit':
      return 'Credit';
    default:
      return mode.isEmpty ? 'Other' : mode[0].toUpperCase() + mode.substring(1);
  }
}

IconData _pmIcon(String mode) {
  switch (mode) {
    case 'cash':
      return Icons.payments_rounded;
    case 'upi':
      return Icons.qr_code_rounded;
    case 'bank_transfer':
      return Icons.account_balance_rounded;
    case 'split':
      return Icons.call_split_rounded;
    default:
      return Icons.receipt_rounded;
  }
}

Color _sourceColor(String label, CrmTheme crm) {
  switch (label) {
    case 'Cash':
      return crm.success;
    case 'UPI':
      return crm.primary;
    case 'Bank Transfer':
      return crm.accent;
    case 'Split':
      return const Color(0xFF2F6BB0);
    case 'Advance':
      return crm.warning;
    case 'Credit':
      return const Color(0xFF7A5AA8);
    default:
      return crm.textSecondary;
  }
}

Color _statusColor(String status, CrmTheme crm) {
  switch (status) {
    case 'verified':
      return crm.success;
    case 'rejected':
      return crm.destructive;
    default:
      return crm.warning;
  }
}

Color _catColor(String c, CrmTheme crm) {
  switch (c) {
    case 'food':
      return crm.primary;
    case 'travel':
      return crm.accent;
    case 'stay':
      return crm.success;
    case 'materials':
      return crm.warning;
    case 'fuel':
      return const Color(0xFF2F6BB0);
    case 'inventory':
      return const Color(0xFF8E5AA8);
    default:
      return crm.textSecondary;
  }
}

IconData _catIcon(String c) {
  switch (c) {
    case 'food':
      return Icons.restaurant_rounded;
    case 'travel':
      return Icons.directions_car_rounded;
    case 'stay':
      return Icons.hotel_rounded;
    case 'materials':
      return Icons.inventory_2_rounded;
    case 'fuel':
      return Icons.local_gas_station_rounded;
    case 'inventory':
      return Icons.storefront_rounded;
    default:
      return Icons.receipt_long_rounded;
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _Slice {
  final String label;
  final double value;
  final Color color;
  const _Slice(this.label, this.value, this.color);
}

class _Row {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final double amount;
  final String status;
  final Color statusColor;
  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.statusColor,
  });
}

/// Accounts → Operations → Dashboard.
class AccountsDashboardScreen extends ConsumerStatefulWidget {
  const AccountsDashboardScreen({super.key});

  @override
  ConsumerState<AccountsDashboardScreen> createState() =>
      _AccountsDashboardScreenState();
}

class _AccountsDashboardScreenState
    extends ConsumerState<AccountsDashboardScreen> {
  late DateTime _month;
  int _tab = 0; // 0 = Collections + Advance, 1 = Expenses

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthYearPickerDialog(initial: _month),
    );
    if (picked != null) setState(() => _month = picked);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncCollections = ref.watch(collectionsProvider);
    final asyncExpenses = ref.watch(expensesProvider);
    final asyncBookings = ref.watch(bookingProvider);
    // Inventory purchases are supplementary — never block the dashboard on them.
    final purchases =
        ref.watch(purchasesProvider).value ?? const <Purchase>[];

    final loading = asyncCollections.isLoading ||
        asyncExpenses.isLoading ||
        asyncBookings.isLoading;
    final error =
        asyncCollections.error ?? asyncExpenses.error ?? asyncBookings.error;

    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = Center(
        child: Text('Failed to load dashboard: $error',
            style: TextStyle(color: crm.textSecondary)),
      );
    } else {
      body = _buildContent(
        crm,
        isMobile,
        asyncCollections.value ?? const <ArtistCollection>[],
        asyncExpenses.value ?? const <ArtistExpense>[],
        asyncBookings.value ?? const <Booking>[],
        purchases,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 0, isMobile ? 12 : 0, isMobile ? 16 : 0, 0),
      child: body,
    );
  }

  void _export(List<ArtistCollection> collections, List<ArtistExpense> expenses) {
    if (_tab == 0) {
      showDialog(
        context: context,
        builder: (_) => ExportReportDialog<ArtistCollection>(
          title: 'Collections',
          items: collections,
          getVehicleName: (_) => null,
          getDriverName: (_) => null,
          headers: const ['Date', 'Customer', 'Payment Mode', 'Amount', 'Status'],
          buildRow: (c) => [
            DateFormat('yyyy-MM-dd').format(c.date),
            c.booking?.customerName ?? c.employee?.name ?? '',
            _pmLabel(c.paymentMode),
            c.amount.toStringAsFixed(2),
            c.status,
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => ExportReportDialog<ArtistExpense>(
          title: 'Expenses',
          items: expenses,
          getVehicleName: (_) => null,
          getDriverName: (_) => null,
          headers: const ['Date', 'Category', 'Notes', 'Amount', 'Status'],
          buildRow: (e) => [
            DateFormat('yyyy-MM-dd').format(e.date),
            _cap(e.category),
            e.notes,
            e.amount.toStringAsFixed(2),
            e.status,
          ],
        ),
      );
    }
  }

  Widget _buildContent(
    CrmTheme crm,
    bool isMobile,
    List<ArtistCollection> allCollections,
    List<ArtistExpense> allExpenses,
    List<Booking> allBookings,
    List<Purchase> allPurchases,
  ) {
    final prevMonth = DateTime(_month.year, _month.month - 1);
    final lastDay = DateTime(_month.year, _month.month + 1, 0).day;

    List<ArtistCollection> collIn(DateTime m) => allCollections
        .where((c) => c.status != 'rejected' && _inMonth(c.date, m))
        .toList();
    List<ArtistExpense> expIn(DateTime m) => allExpenses
        .where((e) => e.status != 'rejected' && _inMonth(e.date, m))
        .toList();
    List<Purchase> purchIn(DateTime m) =>
        allPurchases.where((p) => _inMonth(p.date, m)).toList();
    List<Booking> advIn(DateTime m) => allBookings.where((b) {
          final s = b.status.toLowerCase();
          if (s == 'cancelled' || s == 'rejected') return false;
          if (b.advanceAmount <= 0) return false;
          return _inMonth(b.createdAt ?? b.bookingDate, m);
        }).toList();

    final collections = collIn(_month);
    final expenses = expIn(_month);
    final advances = advIn(_month);
    final purchases = purchIn(_month);

    double sumC(List<ArtistCollection> l) => l.fold(0, (s, c) => s + c.amount);
    double sumE(List<ArtistExpense> l) => l.fold(0, (s, e) => s + e.amount);
    double sumA(List<Booking> l) => l.fold(0, (s, b) => s + b.advanceAmount);
    // Include GST so spend/dues match the Bills & Payables view.
    double sumP(List<Purchase> l) => l.fold(0, (s, p) => s + p.grandTotal);

    // Inventory purchases count as expenses (linked from the Inventory module).
    final invSpend = sumP(purchases);
    final invDues = purchases.fold<double>(0, (s, p) => s + p.balance);

    final totalIn = sumC(collections) + sumA(advances);
    final totalExpenses = sumE(expenses) + invSpend;
    final net = totalIn - totalExpenses;
    final pending = collections.where((c) => c.status == 'pending').length +
        expenses.where((e) => e.status == 'pending').length;
    final collectionTotal = sumC(collections);
    final advanceTotal = sumA(advances);

    final prevIn = sumC(collIn(prevMonth)) + sumA(advIn(prevMonth));
    final prevExp = sumE(expIn(prevMonth)) + sumP(purchIn(prevMonth));

    // Daily series for sparklines.
    final dailyIn = List<double>.filled(lastDay, 0);
    final dailyExp = List<double>.filled(lastDay, 0);
    final dailyPending = List<double>.filled(lastDay, 0);
    for (final c in collections) {
      dailyIn[c.date.day - 1] += c.amount;
      if (c.status == 'pending') dailyPending[c.date.day - 1] += 1;
    }
    for (final b in advances) {
      dailyIn[(b.createdAt ?? b.bookingDate).day - 1] += b.advanceAmount;
    }
    for (final e in expenses) {
      dailyExp[e.date.day - 1] += e.amount;
      if (e.status == 'pending') dailyPending[e.date.day - 1] += 1;
    }
    for (final p in purchases) {
      final d = p.date.day;
      if (d >= 1 && d <= lastDay) dailyExp[d - 1] += p.total;
    }
    final dailyNet = [for (var i = 0; i < lastDay; i++) dailyIn[i] - dailyExp[i]];

    final kpis = [
      _KpiData(
        label: 'Collected + Advance',
        value: _compact(totalIn),
        icon: Icons.account_balance_wallet_rounded,
        color: crm.primary,
        trend: _pctChange(totalIn, prevIn),
        spark: dailyIn,
      ),
      _KpiData(
        label: 'Total Expenses',
        value: _compact(totalExpenses),
        icon: Icons.credit_card_rounded,
        color: crm.destructive,
        trend: _pctChange(totalExpenses, prevExp),
        positiveIsGood: false,
        spark: dailyExp,
      ),
      _KpiData(
        label: 'Net Balance',
        value: _compact(net),
        icon: Icons.pie_chart_rounded,
        color: net >= 0 ? crm.success : crm.destructive,
        trend: _pctChange(net, prevIn - prevExp),
        spark: dailyNet,
      ),
      _KpiData(
        label: 'Pending Verifications',
        value: '$pending',
        subLabel: 'Items',
        icon: Icons.hourglass_bottom_rounded,
        color: crm.warning,
        spark: dailyPending,
      ),
    ];

    final kpiGrid = GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: isMobile ? 1.28 : 1.75,
      children: [for (final k in kpis) _KpiCard(data: k)],
    );

    // ── Weekly buckets (for the trend bars) ────────────────────────────────
    final wBuckets = <List<int>>[
      [1, 7],
      [8, 14],
      [15, 21],
      [22, lastDay],
    ];
    final wLabels = ['1–7', '8–14', '15–21', '22–$lastDay'];
    List<double> weeklySum(Iterable<(int, double)> items) {
      final out = List<double>.filled(4, 0);
      for (final it in items) {
        final day = it.$1;
        for (var i = 0; i < wBuckets.length; i++) {
          if (day >= wBuckets[i][0] && day <= wBuckets[i][1]) {
            out[i] += it.$2;
            break;
          }
        }
      }
      return out;
    }

    final collWeekly = weeklySum(collections.map((c) => (c.date.day, c.amount)));
    final advWeekly = weeklySum(
        advances.map((b) => ((b.createdAt ?? b.bookingDate).day, b.advanceAmount)));
    final expWeekly = weeklySum([
      ...expenses.map((e) => (e.date.day, e.amount)),
      ...purchases.map((p) => (p.date.day, p.total)),
    ]);

    // ── Tab 1: Collection vs Advance ───────────────────────────────────────
    final collAdvSlices = <_Slice>[
      if (collectionTotal > 0)
        _Slice('Collection', collectionTotal, crm.primary),
      if (advanceTotal > 0) _Slice('Advance', advanceTotal, crm.accent),
    ];

    // ── Tab 2: Expenses by category ────────────────────────────────────────
    final catTotals = <String, double>{};
    for (final e in expenses) {
      final k = e.category.isEmpty ? 'other' : e.category;
      catTotals[k] = (catTotals[k] ?? 0) + e.amount;
    }
    if (invSpend > 0) {
      catTotals['inventory'] = (catTotals['inventory'] ?? 0) + invSpend;
    }
    final expenseSlices = catTotals.entries
        .map((e) => _Slice(_cap(e.key), e.value, _catColor(e.key, crm)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final donutPanel = _tab == 0
        ? _DonutPanel(
            title: 'Collection & Advance',
            subtitle: 'Amount breakdown',
            slices: collAdvSlices,
            total: totalIn,
            footer: [
              ('Collection Amount', _rupees(collectionTotal)),
              ('Advance Amount', _rupees(advanceTotal)),
            ],
          )
        : _DonutPanel(
            title: 'Expenses',
            subtitle: 'By category',
            slices: expenseSlices,
            total: totalExpenses,
            footer: [
              ('Inventory Spend', _rupees(invSpend)),
              ('Supplier Dues', _rupees(invDues)),
              ('Transactions', '${expenses.length + purchases.length}'),
            ],
          );

    final barPanel = _tab == 0
        ? _BarPanel(
            title: 'Collection vs Advance',
            subtitle: 'By week',
            labels: wLabels,
            crm: crm,
            series: [
              _Series('Collection', crm.primary, collWeekly),
              _Series('Advance', crm.accent, advWeekly),
            ],
          )
        : _BarPanel(
            title: 'Expenses',
            subtitle: 'By week',
            labels: wLabels,
            crm: crm,
            series: [
              _Series('Expenses', crm.destructive.withValues(alpha: 0.7),
                  expWeekly),
            ],
          );

    final tabbedCard = Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: crm.input.withValues(alpha: 0.5),
            child: Row(
              children: [
                _tabButton(
                    crm, 0, 'Collections + Advance', Icons.account_balance),
                _tabButton(crm, 1, 'Expenses', Icons.credit_card),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: isMobile
                ? Column(children: [
                    donutPanel,
                    16.h,
                    Divider(color: crm.border, height: 1),
                    16.h,
                    barPanel,
                  ])
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: donutPanel),
                        VerticalDivider(color: crm.border, width: 33),
                        Expanded(flex: 5, child: barPanel),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );

    // ── Recent lists ───────────────────────────────────────────────────────
    final collRows = <(_Row, DateTime)>[
      ...collections.map((c) {
        final dt = c.createdAt;
        return (
          _Row(
            icon: _pmIcon(c.paymentMode),
            color: _sourceColor(_pmLabel(c.paymentMode), crm),
            title: '${_pmLabel(c.paymentMode)} Collection',
            subtitle: 'Payment · ${_dtLabel(dt)}',
            amount: c.amount,
            status: c.status,
            statusColor: _statusColor(c.status, crm),
          ),
          dt,
        );
      }),
      ...advances.map((b) {
        final dt = b.createdAt ?? b.bookingDate;
        return (
          _Row(
            icon: Icons.bolt_rounded,
            color: crm.warning,
            title: 'Advance · ${b.customerName}',
            subtitle: 'Advance · ${_dtLabel(dt)}',
            amount: b.advanceAmount,
            status: 'advance',
            statusColor: crm.accent,
          ),
          dt,
        );
      }),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    final expRows = <(_Row, DateTime)>[
      ...expenses.map((e) {
        final dt = e.createdAt;
        return (
          _Row(
            icon: _catIcon(e.category),
            color: _catColor(e.category, crm),
            title: _cap(e.category.isEmpty ? 'expense' : e.category),
            subtitle:
                '${e.notes.isEmpty ? 'Payment' : e.notes} · ${_dtLabel(dt)}',
            amount: e.amount,
            status: e.status,
            statusColor: _statusColor(e.status, crm),
          ),
          dt,
        );
      }),
      // Inventory purchases (linked from the Inventory module).
      ...purchases.map((p) {
        final dt = p.date;
        return (
          _Row(
            icon: _catIcon('inventory'),
            color: _catColor('inventory', crm),
            title: p.supplier.isEmpty ? 'Inventory purchase' : p.supplier,
            subtitle:
                'Inventory · ${p.items.length} item${p.items.length == 1 ? '' : 's'} · ${_dtLabel(dt)}',
            amount: p.total,
            status: p.paid ? 'paid' : 'due',
            statusColor: p.paid ? crm.success : crm.warning,
          ),
          dt,
        );
      }),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    final recentColl = _RecentCard(
      title: 'Recent Collections + Advance',
      count: collRows.length,
      total: totalIn,
      rows: collRows.map((e) => e.$1).take(5).toList(),
      viewAllLabel: 'View All Collections + Advance',
      onViewAll: () => context.go('/accounts/artist-collections'),
      emptyText: 'No collections or advances',
    );
    final recentExp = _RecentCard(
      title: 'Recent Expenses',
      count: expRows.length,
      total: totalExpenses,
      rows: expRows.map((e) => e.$1).take(5).toList(),
      viewAllLabel: 'View All Expenses',
      onViewAll: () => context.go('/finance'),
      emptyText: 'No expenses this month',
    );

    final recentSection = isMobile
        ? Column(children: [recentColl, 16.h, recentExp])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: recentColl),
              16.w,
              Expanded(child: recentExp),
            ],
          );

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _header(crm, isMobile, () => _export(collections, expenses)),
        18.h,
        kpiGrid,
        18.h,
        tabbedCard,
        18.h,
        recentSection,
      ],
    );
  }

  Widget _header(CrmTheme crm, bool isMobile, VoidCallback onExport) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accounts Dashboard',
            style: TextStyle(
                fontSize: isMobile ? 22 : 28,
                fontWeight: FontWeight.w800,
                color: crm.textPrimary,
                letterSpacing: -0.5)),
        2.h,
        Text('Track collections, advances & expenses',
            style: TextStyle(fontSize: 13, color: crm.textSecondary)),
      ],
    );

    final monthPill = InkWell(
      onTap: _pickMonth,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 17, color: crm.primary),
            8.w,
            Text('${_monthNames[_month.month - 1]} ${_month.year}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: crm.textPrimary)),
            4.w,
            Icon(Icons.keyboard_arrow_down, size: 18, color: crm.textSecondary),
          ],
        ),
      ),
    );

    final exportBtn = InkWell(
      onTap: onExport,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: crm.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.file_download_outlined, size: 17, color: Colors.white),
            8.w,
            const Text('Export',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          14.h,
          Row(children: [Expanded(child: monthPill), 10.w, exportBtn]),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: titleBlock),
        monthPill,
        12.w,
        exportBtn,
      ],
    );
  }

  Widget _tabButton(CrmTheme crm, int index, String label, IconData icon) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: selected ? crm.surface : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: selected ? crm.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17,
                  color: selected ? crm.primary : crm.textSecondary),
              8.w,
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? crm.primary : crm.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── widgets ──────────────────────────────────

class _KpiData {
  final String label;
  final String value;
  final String? subLabel;
  final IconData icon;
  final Color color;
  final double? trend;
  final bool positiveIsGood;
  final List<double> spark;
  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.spark,
    this.subLabel,
    this.trend,
    this.positiveIsGood = true,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget? badge;
    if (data.trend != null) {
      final up = data.trend! >= 0;
      final good = up == data.positiveIsGood;
      final c = good ? crm.success : crm.destructive;
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 11, color: c),
            2.w,
            Text('${data.trend!.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 18),
              ),
              8.w,
              Expanded(
                child: Text(data.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: crm.textSecondary)),
              ),
              ?badge,
            ],
          ),
          10.h,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: data.color,
                        height: 1.0)),
              ),
              if (data.subLabel != null) ...[
                4.w,
                Text(data.subLabel!,
                    style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              ],
            ],
          ),
          Expanded(child: _Sparkline(data: data.spark, color: data.color)),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  const _Sparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();
    var minV = data.reduce((a, b) => a < b ? a : b);
    var maxV = data.reduce((a, b) => a > b ? a : b);
    if (maxV == minV) {
      maxV += 1;
      minV -= 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: LineChart(
        LineChartData(
          minY: minV,
          maxY: maxV,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.28,
              color: color,
              barWidth: 1.6,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_Slice> slices;
  final double total;
  final List<(String, String)> footer;

  const _DonutPanel({
    required this.title,
    required this.subtitle,
    required this.slices,
    required this.total,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: crm.textPrimary)),
        2.h,
        Text(subtitle,
            style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        16.h,
        if (slices.isEmpty || total <= 0)
          SizedBox(
            height: 150,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline,
                      size: 40,
                      color: crm.textSecondary.withValues(alpha: 0.4)),
                  10.h,
                  Text('No data this month',
                      style:
                          TextStyle(fontSize: 13, color: crm.textSecondary)),
                ],
              ),
            ),
          )
        else
          Row(
            children: [
              SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        for (final s in slices)
                          PieChartSectionData(
                            value: s.value,
                            color: s.color,
                            radius: 24,
                            showTitle: false,
                          ),
                      ],
                    )),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total',
                            style: TextStyle(
                                fontSize: 10, color: crm.textSecondary)),
                        Text(_compact(total),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: crm.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              14.w,
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in slices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          children: [
                            Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                    color: s.color, shape: BoxShape.circle)),
                            8.w,
                            Expanded(
                              child: Text(s.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: crm.textPrimary)),
                            ),
                            Text(
                              '${_rupees(s.value)} (${(s.value / total * 100).toStringAsFixed(0)}%)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: crm.textSecondary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        16.h,
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: crm.input.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (var i = 0; i < footer.length; i++) ...[
                if (i > 0)
                  Container(width: 1, height: 30, color: crm.border),
                Expanded(
                  child: Column(
                    children: [
                      Text(footer[i].$1,
                          style: TextStyle(
                              fontSize: 11, color: crm.textSecondary)),
                      4.h,
                      Text(footer[i].$2,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Series {
  final String label;
  final Color color;
  final List<double> weekly;
  const _Series(this.label, this.color, this.weekly);
}

class _BarPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> labels;
  final List<_Series> series;
  final CrmTheme crm;

  const _BarPanel({
    required this.title,
    required this.subtitle,
    required this.labels,
    required this.series,
    required this.crm,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = [
      for (final s in series) ...s.weekly,
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    final maxY = maxVal * 1.25;
    final barWidth = series.length == 1 ? 20.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: crm.textPrimary)),
                  2.h,
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
              ),
            ),
            Wrap(
              spacing: 12,
              children: [for (final s in series) _dot(s.color, s.label)],
            ),
          ],
        ),
        16.h,
        SizedBox(
          height: 190,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(enabled: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (v) => FlLine(
                  color: crm.border.withValues(alpha: 0.6), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) => Text(
                      value == 0 ? '₹0' : _compact(value),
                      style:
                          TextStyle(fontSize: 9, color: crm.textSecondary)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(labels[i],
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: crm.textSecondary)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < labels.length; i++)
                BarChartGroupData(x: i, barRods: [
                  for (final s in series)
                    BarChartRodData(
                        toY: i < s.weekly.length ? s.weekly[i] : 0,
                        color: s.color,
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3))),
                ]),
            ],
          )),
        ),
      ],
    );
  }

  Widget _dot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          5.w,
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: crm.textSecondary)),
        ],
      );
}

class _RecentCard extends StatelessWidget {
  final String title;
  final int count;
  final double total;
  final List<_Row> rows;
  final String viewAllLabel;
  final VoidCallback onViewAll;
  final String emptyText;

  const _RecentCard({
    required this.title,
    required this.count,
    required this.total,
    required this.rows,
    required this.viewAllLabel,
    required this.onViewAll,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Flexible(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary)),
                ),
                8.w,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: crm.primary)),
                ),
                const Spacer(),
                Text('Total ${_rupees(total)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary)),
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(emptyText,
                    style:
                        TextStyle(fontSize: 13, color: crm.textSecondary)),
              ),
            )
          else
            ...rows.map((r) => _row(context, crm, r)),
          InkWell(
            onTap: onViewAll,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: crm.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(viewAllLabel,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: crm.primary)),
                  6.w,
                  Icon(Icons.arrow_forward, size: 15, color: crm.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, CrmTheme crm, _Row r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: r.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(r.icon, color: r.color, size: 19),
          ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: crm.textPrimary)),
                2.h,
                Text(r.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: crm.textSecondary)),
              ],
            ),
          ),
          8.w,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_rupees(r.amount),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
              4.h,
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: r.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_cap(r.status),
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: r.statusColor)),
              ),
            ],
          ),
          6.w,
          Icon(Icons.chevron_right, size: 18, color: crm.textSecondary),
        ],
      ),
    );
  }
}

// ─────────────────────────── month/year picker ────────────────────────────

class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initial;
  const _MonthYearPickerDialog({required this.initial});

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    onPressed: () => setState(() => _year--),
                    icon: Icon(Icons.chevron_left, color: crm.primary)),
                Text('$_year',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary)),
                IconButton(
                    onPressed: () => setState(() => _year++),
                    icon: Icon(Icons.chevron_right, color: crm.primary)),
              ],
            ),
            12.h,
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                for (var m = 1; m <= 12; m++) _chip(crm, _shortMonths[m - 1], m),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(CrmTheme crm, String label, int month) {
    final selected =
        _year == widget.initial.year && month == widget.initial.month;
    return InkWell(
      onTap: () => Navigator.pop(context, DateTime(_year, month)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? crm.primary : crm.input,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? crm.primary : crm.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : crm.textPrimary)),
      ),
    );
  }
}
