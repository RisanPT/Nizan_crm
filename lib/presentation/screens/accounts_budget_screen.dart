import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/models/artist_collection.dart';
import '../../core/models/artist_expense.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
import '../../services/collection_service.dart';
import '../../services/expense_service.dart';
import '../../services/budget_service.dart';

class AccountsBudgetScreen extends ConsumerStatefulWidget {
  const AccountsBudgetScreen({super.key});

  @override
  ConsumerState<AccountsBudgetScreen> createState() => _AccountsBudgetScreenState();
}

class _AccountsBudgetScreenState extends ConsumerState<AccountsBudgetScreen> {
  bool _isAccrual = true;
  String _selectedPeriod = 'This Fiscal Year';
  final List<String> _shortMonths = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];

  String _currency(double v) => '₹${v.toStringAsFixed(0)}';

  String _formatChartValue(double value) {
    if (value == 0) return '0';
    if (value.abs() >= 1000000) {
      final formatted = (value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1);
      return '${formatted}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  (DateTime, DateTime, String) getPeriodRange(String option, DateTime now) {
    DateTime start;
    DateTime end;
    String label;

    switch (option) {
      case 'This Fiscal Year':
        int startYear = now.month >= 4 ? now.year : now.year - 1;
        start = DateTime(startYear, 4, 1);
        end = DateTime(startYear + 1, 3, 31, 23, 59, 59);
        label = '$startYear-${(startYear + 1).toString().substring(2)}';
        break;

      case 'This Quarter':
        int q = ((now.month - 1) / 3).floor();
        int startMonth = q * 3 + 1;
        start = DateTime(now.year, startMonth, 1);
        end = DateTime(now.year, startMonth + 3, 0, 23, 59, 59);
        label = 'Q${q + 1} $now.year';
        break;

      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        label = DateFormat('MMMM yyyy').format(now);
        break;

      case 'Previous Fiscal Year':
        int startYear = (now.month >= 4 ? now.year : now.year - 1) - 1;
        start = DateTime(startYear, 4, 1);
        end = DateTime(startYear + 1, 3, 31, 23, 59, 59);
        label = '$startYear-${(startYear + 1).toString().substring(2)}';
        break;

      case 'Previous Quarter':
        int q = ((now.month - 1) / 3).floor();
        int startMonth = (q - 1) * 3 + 1;
        int year = now.year;
        if (startMonth <= 0) {
          startMonth += 12;
          year -= 1;
        }
        start = DateTime(year, startMonth, 1);
        end = DateTime(year, startMonth + 3, 0, 23, 59, 59);
        label = 'Previous Q $year';
        break;

      case 'Previous Month':
        int month = now.month - 1;
        int year = now.year;
        if (month <= 0) {
          month += 12;
          year -= 1;
        }
        start = DateTime(year, month, 1);
        end = DateTime(year, month + 1, 0, 23, 59, 59);
        label = DateFormat('MMMM yyyy').format(start);
        break;

      case 'Last 6 Months':
        start = DateTime(now.year, now.month - 5, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        label = 'Last 6 Months';
        break;

      case 'Last 12 Months':
        start = DateTime(now.year, now.month - 11, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        label = 'Last 12 Months';
        break;

      default:
        int startYear = now.month >= 4 ? now.year : now.year - 1;
        start = DateTime(startYear, 4, 1);
        end = DateTime(startYear + 1, 3, 31, 23, 59, 59);
        label = '$startYear-${(startYear + 1).toString().substring(2)}';
    }

    return (start, end, label);
  }

  List<DateTime> getPeriodIntervals(DateTime start, DateTime end, String period) {
    List<DateTime> list = [];
    if (period == 'This Month' || period == 'Previous Month') {
      DateTime current = DateTime(start.year, start.month, start.day);
      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        list.add(current);
        current = current.add(const Duration(days: 1));
      }
    } else {
      DateTime current = DateTime(start.year, start.month, 1);
      while (current.isBefore(end)) {
        list.add(current);
        current = DateTime(current.year, current.month + 1, 1);
      }
    }
    return list;
  }

  double calculateCumulativeBalanceBefore(
    DateTime date,
    List<ArtistCollection> collections,
    List<ArtistExpense> expenses,
    List<Booking> bookings,
  ) {
    final prevCollectionsSum = collections
        .where((c) => (c.status == 'verified' || c.status == 'approved') && c.date.isBefore(date))
        .fold(0.0, (sum, c) => sum + c.amount);

    final prevAdvancesSum = bookings
        .where((b) {
          final s = b.status.toLowerCase();
          if (s == 'cancelled' || s == 'rejected') return false;
          final d = b.createdAt ?? b.bookingDate;
          return b.advanceAmount > 0 && d.isBefore(date);
        })
        .fold(0.0, (sum, b) => sum + b.advanceAmount);

    final prevExpensesSum = expenses
        .where((e) => (e.status == 'verified' || e.status == 'approved') && e.date.isBefore(date))
        .fold(0.0, (sum, e) => sum + e.amount);

    return prevCollectionsSum + prevAdvancesSum - prevExpensesSum;
  }

  double getIntervalIncome(
    DateTime intervalStart,
    DateTime intervalEnd,
    List<ArtistCollection> collections,
    List<Booking> bookings,
    bool isAccrual,
  ) {
    if (isAccrual) {
      return bookings
          .where((b) {
            final s = b.status.toLowerCase();
            if (s == 'cancelled' || s == 'rejected') return false;
            final d = b.bookingDate;
            return d.isAfter(intervalStart.subtract(const Duration(seconds: 1))) &&
                d.isBefore(intervalEnd.add(const Duration(seconds: 1)));
          })
          .fold(0.0, (sum, b) => sum + b.totalPrice);
    } else {
      final cSum = collections
          .where((c) =>
              (c.status == 'verified' || c.status == 'approved') &&
              c.date.isAfter(intervalStart.subtract(const Duration(seconds: 1))) &&
              c.date.isBefore(intervalEnd.add(const Duration(seconds: 1))))
          .fold(0.0, (sum, c) => sum + c.amount);

      final aSum = bookings
          .where((b) {
            final s = b.status.toLowerCase();
            if (s == 'cancelled' || s == 'rejected') return false;
            final d = b.createdAt ?? b.bookingDate;
            return b.advanceAmount > 0 &&
                d.isAfter(intervalStart.subtract(const Duration(seconds: 1))) &&
                d.isBefore(intervalEnd.add(const Duration(seconds: 1)));
          })
          .fold(0.0, (sum, b) => sum + b.advanceAmount);

      return cSum + aSum;
    }
  }

  double getIntervalExpense(
    DateTime intervalStart,
    DateTime intervalEnd,
    List<ArtistExpense> expenses,
  ) {
    return expenses
        .where((e) =>
            (e.status == 'verified' || e.status == 'approved') &&
            e.date.isAfter(intervalStart.subtract(const Duration(seconds: 1))) &&
            e.date.isBefore(intervalEnd.add(const Duration(seconds: 1))))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crm = context.crmColors;

    final asyncCollections = ref.watch(collectionsProvider);
    final asyncExpenses = ref.watch(expensesProvider);
    final asyncBookings = ref.watch(bookingProvider);
    final budgetAsync = ref.watch(currentBudgetProvider);

    final loading = asyncCollections.isLoading || asyncExpenses.isLoading || asyncBookings.isLoading;
    final error = asyncCollections.error ?? asyncExpenses.error ?? asyncBookings.error;

    if (loading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return SizedBox(
        height: 300,
        child: Center(child: Text('Failed to load financials: $error', style: TextStyle(color: crm.textSecondary))),
      );
    }

    final allCollections = asyncCollections.value ?? const <ArtistCollection>[];
    final allExpenses = asyncExpenses.value ?? const <ArtistExpense>[];
    final allBookings = asyncBookings.value ?? const <Booking>[];

    double bankBalance = 0;
    double cashInHand = 0;

    for (final c in allCollections.where((c) => c.status == 'verified' || c.status == 'approved')) {
      if (c.paymentMode == 'cash') {
        cashInHand += c.amount;
      } else {
        bankBalance += c.amount;
      }
    }
    for (final b in allBookings.where((b) {
      final s = b.status.toLowerCase();
      return s != 'cancelled' && s != 'rejected';
    })) {
      bankBalance += b.advanceAmount;
    }
    for (final e in allExpenses.where((e) => e.status == 'verified' || e.status == 'approved')) {
      if (e.category == 'materials' || e.category == 'stay') {
        bankBalance -= e.amount;
      } else {
        cashInHand -= e.amount;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Accounts Dashboard',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              budgetAsync.when(
                data: (budgetObj) {
                  final currentBudgetAmount = budgetObj?.amount ?? 0.0;
                  return ElevatedButton.icon(
                    onPressed: () => _showSetBudgetDialog(context, ref, currentBudgetAmount),
                    icon: const Icon(Icons.edit_square),
                    label: const Text('Set Budget'),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
            ],
          ),
          24.h,
          _buildAccrualCashToggle(),
          16.h,
          _buildIncomeExpenseSection(allCollections, allExpenses, allBookings, theme, crm),
          24.h,
          _buildBankingOverview(bankBalance, cashInHand, crm, theme),
          24.h,
          _buildQuickCreate(crm, theme),
          24.h,
          _buildCashFlowSection(allCollections, allExpenses, allBookings, theme, crm),
        ],
      ),
    );
  }

  Widget _buildAccrualCashToggle() {
    return Row(
      children: [
        _segmentButton('Accrual', _isAccrual, () => setState(() => _isAccrual = true)),
        8.w,
        _segmentButton('Cash', !_isAccrual, () => setState(() => _isAccrual = false)),
      ],
    );
  }

  Widget _segmentButton(String label, bool active, VoidCallback onTap) {
    final crm = context.crmColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? crm.primary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(color: active ? crm.primary : crm.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? crm.primary : crm.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseSection(
    List<ArtistCollection> collections,
    List<ArtistExpense> expenses,
    List<Booking> bookings,
    ThemeData theme,
    CrmTheme crm,
  ) {
    final now = DateTime.now();
    int startYear = now.month >= 4 ? now.year : now.year - 1;
    final fiscalMonths = List.generate(12, (i) {
      int m = 4 + i;
      int y = startYear;
      if (m > 12) {
        m -= 12;
        y += 1;
      }
      return DateTime(y, m, 1);
    });

    double totalIncome = 0;
    double totalExpense = 0;

    final incomes = <double>[];
    final outgoings = <double>[];

    for (final month in fiscalMonths) {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final inc = getIntervalIncome(start, end, collections, bookings, _isAccrual);
      final exp = getIntervalExpense(start, end, expenses);

      incomes.add(inc);
      outgoings.add(exp);

      totalIncome += inc;
      totalExpense += exp;
    }

    double maxVal = 0;
    for (int i = 0; i < 12; i++) {
      if (incomes[i] > maxVal) maxVal = incomes[i];
      if (outgoings[i] > maxVal) maxVal = outgoings[i];
    }
    if (maxVal == 0) maxVal = 100000;
    double chartMaxY = maxVal * 1.15;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: crm.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Income and Expense',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            16.h,
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: chartMaxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final valStr = _currency(rod.toY);
                        return BarTooltipItem(
                          rodIndex == 0 ? 'Income: $valStr' : 'Expense: $valStr',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMaxY / 4,
                    getDrawingHorizontalLine: (v) => FlLine(color: crm.border.withValues(alpha: 0.4), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: chartMaxY / 4,
                        getTitlesWidget: (v, meta) => Text(
                          v == 0 ? '0' : _formatChartValue(v),
                          style: TextStyle(fontSize: 9, color: crm.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= _shortMonths.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_shortMonths[i], style: TextStyle(fontSize: 10, color: crm.textSecondary)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(12, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: incomes[i],
                          color: crm.primary,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                        BarChartRodData(
                          toY: outgoings[i],
                          color: const Color(0xFFF59E0B),
                          width: 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            16.h,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _legendItem('Income', _currency(totalIncome), crm.primary, theme, crm),
                _legendItem('Expense', _currency(totalExpense), const Color(0xFFF59E0B), theme, crm),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, String value, Color color, ThemeData theme, CrmTheme crm) {
    return Column(
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            6.w,
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: crm.textSecondary)),
          ],
        ),
        4.h,
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: crm.textPrimary)),
      ],
    );
  }

  Widget _buildBankingOverview(double bank, double cash, CrmTheme crm, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance_outlined, color: crm.primary, size: 18),
            8.w,
            Text(
              'Banking Overview',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        16.h,
        Row(
          children: [
            _buildBankCard('Bank Balance', bank, Icons.account_balance_rounded, crm, theme),
            12.w,
            _buildBankCard('Cash In Hand', cash, Icons.wallet_rounded, crm, theme),
          ],
        ),
      ],
    );
  }

  Widget _buildBankCard(String title, double value, IconData icon, CrmTheme crm, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: crm.input.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: crm.textPrimary, size: 20),
            ),
            16.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: crm.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  4.h,
                  Text(
                    _currency(value),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCreate(CrmTheme crm, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt, color: crm.primary, size: 18),
            8.w,
            Text(
              'Quick Create',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        16.h,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _quickCreateButton(
              icon: Icons.person_add_outlined,
              label: 'New\nCustomer',
              onTap: () => context.go('/clients'),
              crm: crm,
              theme: theme,
            ),
            _quickCreateButton(
              icon: Icons.receipt_long_outlined,
              label: 'New\nInvoice',
              onTap: () => context.go('/accounts/invoices'),
              crm: crm,
              theme: theme,
            ),
            _quickCreateButton(
              icon: Icons.assignment_outlined,
              label: 'New\nBill',
              onTap: () => context.go('/finance'),
              crm: crm,
              theme: theme,
            ),
            _quickCreateButton(
              icon: Icons.credit_card_outlined,
              label: 'New\nExpense',
              onTap: () => context.go('/finance'),
              crm: crm,
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickCreateButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required CrmTheme crm,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: crm.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: crm.primary, size: 20),
                ),
                8.h,
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: crm.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashFlowSection(
    List<ArtistCollection> collections,
    List<ArtistExpense> expenses,
    List<Booking> bookings,
    ThemeData theme,
    CrmTheme crm,
  ) {
    final now = DateTime.now();
    final (start, end, periodLabel) = getPeriodRange(_selectedPeriod, now);

    final double startBalance = calculateCumulativeBalanceBefore(start, collections, expenses, bookings);
    final intervals = getPeriodIntervals(start, end, _selectedPeriod);

    final incomes = <double>[];
    final outgoings = <double>[];
    final endingBalances = <double>[];
    final openingBalances = <double>[];

    double runningBalance = startBalance;
    double totalIncomingPeriod = 0;
    double totalOutgoingPeriod = 0;

    for (int i = 0; i < intervals.length; i++) {
      final currentStart = intervals[i];
      DateTime currentEnd;
      if (_selectedPeriod == 'This Month' || _selectedPeriod == 'Previous Month') {
        currentEnd = DateTime(currentStart.year, currentStart.month, currentStart.day, 23, 59, 59);
      } else {
        currentEnd = DateTime(currentStart.year, currentStart.month + 1, 0, 23, 59, 59);
      }

      final inc = getIntervalIncome(currentStart, currentEnd, collections, bookings, false);
      final exp = getIntervalExpense(currentStart, currentEnd, expenses);

      openingBalances.add(runningBalance);
      incomes.add(inc);
      outgoings.add(exp);
      runningBalance += inc - exp;
      endingBalances.add(runningBalance);

      totalIncomingPeriod += inc;
      totalOutgoingPeriod += exp;
    }

    final double endingBalance = runningBalance;
    final spots = List.generate(intervals.length, (i) => FlSpot(i.toDouble(), endingBalances[i]));

    double minBal = endingBalances.isEmpty ? 0 : endingBalances.reduce((a, b) => a < b ? a : b);
    double maxBal = endingBalances.isEmpty ? 100000 : endingBalances.reduce((a, b) => a > b ? a : b);
    if (startBalance < minBal) minBal = startBalance;
    if (startBalance > maxBal) maxBal = startBalance;

    double diff = maxBal - minBal;
    if (diff == 0) diff = 100000;
    double minY = (minBal - diff * 0.15).clamp(0, double.infinity);
    double maxY = maxBal + diff * 0.15;
    double gridInterval = diff / 4;
    if (gridInterval <= 0) gridInterval = 10000;

    final xLabels = intervals.map((dt) {
      if (_selectedPeriod == 'This Month' || _selectedPeriod == 'Previous Month') {
        return dt.day.toString();
      }
      return _shortMonths[dt.month - 1];
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: crm.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart, color: crm.textSecondary),
                    8.w,
                    Text(
                      'Cash Flow',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (val) => setState(() => _selectedPeriod = val),
                  itemBuilder: (ctx) => [
                    'This Fiscal Year',
                    'This Quarter',
                    'This Month',
                    'Previous Fiscal Year',
                    'Previous Quarter',
                    'Previous Month',
                    'Last 6 Months',
                    'Last 12 Months',
                  ].map((p) => PopupMenuItem(value: p, child: Text(p))).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: crm.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text(_selectedPeriod, style: const TextStyle(fontSize: 13)),
                        4.w,
                        const Icon(Icons.keyboard_arrow_down, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            24.h,
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: gridInterval,
                    getDrawingHorizontalLine: (v) => FlLine(color: crm.border.withValues(alpha: 0.4), strokeWidth: 1),
                    getDrawingVerticalLine: (v) => FlLine(color: crm.border.withValues(alpha: 0.4), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _selectedPeriod == 'This Month' || _selectedPeriod == 'Previous Month' ? 5 : 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          return i >= 0 && i < xLabels.length ? Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(xLabels[i], style: TextStyle(color: crm.textSecondary, fontSize: 11)),
                          ) : const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: gridInterval,
                        reservedSize: 42,
                        getTitlesWidget: (v, meta) => Text(_formatChartValue(v), style: TextStyle(color: crm.textSecondary, fontSize: 9.5)),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(bottom: BorderSide(color: crm.border), left: BorderSide(color: crm.border)),
                  ),
                  minX: 0,
                  maxX: (intervals.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                      isCurved: true,
                      color: crm.primary,
                      barWidth: 2.2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: crm.primary.withValues(alpha: 0.05)),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        if (idx < 0 || idx >= intervals.length) return null;
                        return LineTooltipItem(
                          '${DateFormat('d MMMM yyyy').format(intervals[idx])}\n',
                          const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                          children: [
                            const TextSpan(text: 'Opening Bal.  ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            TextSpan(text: '₹${openingBalances[idx].toStringAsFixed(0)}\n', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                            TextSpan(text: 'Income           ', style: TextStyle(color: crm.success, fontSize: 11)),
                            TextSpan(text: '₹${incomes[idx].toStringAsFixed(0)}\n', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                            TextSpan(text: 'Outgoing        ', style: TextStyle(color: crm.destructive, fontSize: 11)),
                            TextSpan(text: '₹${outgoings[idx].toStringAsFixed(0)}\n', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                            TextSpan(text: 'Ending Bal.     ', style: TextStyle(color: crm.primary, fontSize: 11)),
                            TextSpan(text: '₹${endingBalances[idx].toStringAsFixed(0)}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            32.h,
            _buildSummaryRow('Cash as on ${DateFormat('dd/MM/yyyy').format(start)}', startBalance, crm.textPrimary, isBold: true),
            16.h,
            _buildSummaryRow('+ Incoming', totalIncomingPeriod, crm.success, isBold: true),
            16.h,
            _buildSummaryRow('- Outgoing', totalOutgoingPeriod, crm.destructive, isBold: true),
            24.h,
            _buildSummaryRow('= Cash as on ${DateFormat('dd/MM/yyyy').format(end)}', endingBalance, crm.primary, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, double value, Color color, {bool isBold = false}) {
    final crm = context.crmColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
        Text(_currency(value), style: TextStyle(color: crm.textPrimary, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: 15)),
      ],
    );
  }

  void _showSetBudgetDialog(BuildContext context, WidgetRef ref, double currentBudget) {
    final crm = context.crmColors;
    final ctrl = TextEditingController(text: currentBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the maximum allocated budget for this month.', style: TextStyle(fontSize: 13)),
            16.h,
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Budget Amount (INR)', prefixIcon: Icon(Icons.currency_rupee)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null && val >= 0) {
                final now = DateTime.now();
                await ref.read(budgetServiceProvider).setBudget(month: now.month, year: now.year, amount: val);
                ref.invalidate(currentBudgetProvider);
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: crm.primary, foregroundColor: Colors.white),
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }
}
