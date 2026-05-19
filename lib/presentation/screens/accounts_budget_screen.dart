import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/budget_service.dart';

class AccountsBudgetScreen extends ConsumerStatefulWidget {
  const AccountsBudgetScreen({super.key});

  @override
  ConsumerState<AccountsBudgetScreen> createState() => _AccountsBudgetScreenState();
}

class _AccountsBudgetScreenState extends ConsumerState<AccountsBudgetScreen> {
  String _currency(double v) => '₹${v.toStringAsFixed(2)}';

  final double openingBalance = 1244147.85;
  final double incoming = 4471424.00;
  final double outgoing = 3237584.77;
  final double closingBalance = 2477987.08;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crm = context.crmColors;

    final budgetAsync = ref.watch(currentBudgetProvider);

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
          _buildCashFlowSection(theme, crm),
          24.h,
          _buildIncomeExpenseSection(theme, crm),
        ],
      ),
    );
  }

  Widget _buildCashFlowSection(ThemeData theme, CrmTheme crm) {
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: crm.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Text('This Fiscal Year', style: TextStyle(fontSize: 13)),
                      4.w,
                      const Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            24.h,
            SizedBox(
              height: 250,
              child: _buildChart(crm),
            ),
            32.h,
            _buildSummaryRow('Cash as on 01/04/2026', openingBalance, crm.textPrimary, isBold: true),
            16.h,
            _buildSummaryRow('+ Incoming', incoming, crm.success, isBold: true),
            16.h,
            _buildSummaryRow('- Outgoing', outgoing, crm.destructive, isBold: true),
            24.h,
            _buildSummaryRow('= Cash as on 31/03/2027', closingBalance, crm.primary, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(CrmTheme crm) {
    final months = ['Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          horizontalInterval: 400000,
          getDrawingHorizontalLine: (value) => FlLine(color: crm.border, strokeWidth: 1),
          getDrawingVerticalLine: (value) => FlLine(color: crm.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      months[value.toInt()],
                      style: TextStyle(color: crm.textSecondary, fontSize: 12),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 400000,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return Text('0', style: TextStyle(color: crm.textSecondary, fontSize: 12));
                if (value >= 1000000) {
                  final formatted = (value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1);
                  return Text('${formatted}M', style: TextStyle(color: crm.textSecondary, fontSize: 12));
                }
                return Text('${(value / 1000).toStringAsFixed(0)}K', style: TextStyle(color: crm.textSecondary, fontSize: 12));
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: crm.border),
            left: BorderSide(color: crm.border),
            right: BorderSide.none,
            top: BorderSide.none,
          ),
        ),
        minX: 0,
        maxX: 12,
        minY: 0,
        maxY: 2800000,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 1050000),
              FlSpot(1, 2403808),
              FlSpot(2, 2477987),
              FlSpot(3, 2477987),
              FlSpot(4, 2477987),
              FlSpot(5, 2477987),
              FlSpot(6, 2477987),
              FlSpot(7, 2477987),
              FlSpot(8, 2477987),
              FlSpot(9, 2477987),
              FlSpot(10, 2477987),
              FlSpot(11, 2477987),
              FlSpot(12, 2477987),
            ],
            isCurved: true,
            color: crm.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: crm.primary.withValues(alpha: 0.05),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.white,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                if (spot.x == 12) {
                  return LineTooltipItem(
                    'Mar 2027\n',
                    const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                    children: [
                      const TextSpan(text: 'Opening Bal.   ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal, fontSize: 12)),
                      const TextSpan(text: '₹24,77,987.08\n', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      TextSpan(text: 'Income            ', style: TextStyle(color: crm.success, fontWeight: FontWeight.normal, fontSize: 12)),
                      const TextSpan(text: '₹0.00\n', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      TextSpan(text: 'Outgoing         ', style: TextStyle(color: crm.destructive, fontWeight: FontWeight.normal, fontSize: 12)),
                      const TextSpan(text: '₹0.00\n', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      TextSpan(text: 'Ending Bal.      ', style: TextStyle(color: crm.primary, fontWeight: FontWeight.normal, fontSize: 12)),
                      const TextSpan(text: '₹24,77,987.08', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  );
                }
                return LineTooltipItem(
                  '${months[spot.x.toInt()]} 2026\n',
                  const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Opening Bal.   ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal, fontSize: 12)),
                    const TextSpan(text: '₹12,44,147.85\n', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    TextSpan(text: 'Income            ', style: TextStyle(color: crm.success, fontWeight: FontWeight.normal, fontSize: 12)),
                    const TextSpan(text: '₹31,33,424.00\n', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    TextSpan(text: 'Outgoing         ', style: TextStyle(color: crm.destructive, fontWeight: FontWeight.normal, fontSize: 12)),
                    const TextSpan(text: '₹19,73,763.50\n', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    TextSpan(text: 'Ending Bal.      ', style: TextStyle(color: crm.primary, fontWeight: FontWeight.normal, fontSize: 12)),
                    const TextSpan(text: '₹24,03,808.35', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, double value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
        Text(
          _currency(value),
          style: TextStyle(
            color: Colors.black87,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeExpenseSection(ThemeData theme, CrmTheme crm) {
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
                    Icon(Icons.pie_chart_outline, color: crm.textSecondary),
                    8.w,
                    Text(
                      'Income and Expense',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: crm.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Text('This Fiscal Year', style: TextStyle(fontSize: 13)),
                      4.w,
                      const Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            16.h,
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: crm.border),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                    color: Colors.grey.withValues(alpha: 0.1),
                  ),
                  child: const Text('Accrual', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: crm.border),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                  ),
                  child: const Text('Cash'),
                ),
              ],
            ),
            64.h,
          ],
        ),
      ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the maximum allocated budget for this month.', style: TextStyle(fontSize: 13)),
            16.h,
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Budget Amount (INR)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
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
                await ref.read(budgetServiceProvider).setBudget(
                  month: now.month,
                  year: now.year,
                  amount: val,
                );
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
