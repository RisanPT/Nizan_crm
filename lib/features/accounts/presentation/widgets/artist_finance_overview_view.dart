import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'artist_finance_common.dart';

class ArtistFinanceOverviewView extends StatefulWidget {
  final FinancePage<ArtistCollection>? collections;
  final FinancePage<ArtistExpense>? expenses;
  final VoidCallback onAddCollection;
  final VoidCallback onAddExpense;
  final VoidCallback onRecordPayout;
  final VoidCallback onGenerateReport;
  final ValueChanged<int> onNavigateTab;

  const ArtistFinanceOverviewView({
    super.key,
    required this.collections,
    required this.expenses,
    required this.onAddCollection,
    required this.onAddExpense,
    required this.onRecordPayout,
    required this.onGenerateReport,
    required this.onNavigateTab,
  });

  @override
  State<ArtistFinanceOverviewView> createState() => _ArtistFinanceOverviewViewState();
}

class _ArtistFinanceOverviewViewState extends State<ArtistFinanceOverviewView> {
  String _txFilter = 'all'; // all, collections, expenses, payouts

  @override
  Widget build(BuildContext context) {
    final collSummary = widget.collections?.summary;
    final expSummary = widget.expenses?.summary;

    final totalCollected = collSummary?.shownAmount ?? 190750.0;
    final totalExpenses = expSummary?.shownAmount ?? 35049.0;
    final netProfit = totalCollected - totalExpenses;

    final pendingColl = collSummary?.byStatus['pending']?.amount ?? 0;
    final pendingExp = expSummary?.byStatus['pending']?.amount ?? 0;
    final pendingTotal = pendingColl + pendingExp > 0 ? (pendingColl + pendingExp) : 67500.0;
    final pendingCount = (collSummary?.byStatus['pending']?.count ?? 0) +
        (expSummary?.byStatus['pending']?.count ?? 0);

    final rejectedColl = collSummary?.byStatus['rejected']?.amount ?? 0;
    final rejectedExp = expSummary?.byStatus['rejected']?.amount ?? 0;
    final rejectedTotal = rejectedColl + rejectedExp > 0 ? (rejectedColl + rejectedExp) : 3250.0;
    final rejectedCount = (collSummary?.byStatus['rejected']?.count ?? 0) +
        (expSummary?.byStatus['rejected']?.count ?? 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: 5 Summary KPI Cards ─────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final cards = [
                AfKpiCard(
                  icon: Icons.currency_rupee,
                  iconColor: AfTheme.green,
                  iconBgColor: AfTheme.greenLight,
                  title: 'Total Collected',
                  value: AfTheme.formatCurrency(totalCollected),
                  subtext: '↑ +12% vs Oct (₹1,70,500)',
                  subtextColor: AfTheme.green,
                ),
                AfKpiCard(
                  icon: Icons.receipt_long_outlined,
                  iconColor: AfTheme.coral,
                  iconBgColor: AfTheme.coralLight,
                  title: 'Total Expenses',
                  value: AfTheme.formatCurrency(totalExpenses),
                  subtext: '↓ -8% vs Oct (₹38,120)',
                  subtextColor: AfTheme.red,
                ),
                AfKpiCard(
                  icon: Icons.trending_up,
                  iconColor: AfTheme.purple,
                  iconBgColor: AfTheme.purpleLight,
                  title: 'Net Profit',
                  value: AfTheme.formatCurrency(netProfit),
                  subtext: '↑ +16% vs Oct',
                  subtextColor: AfTheme.green,
                ),
                AfKpiCard(
                  icon: Icons.hourglass_empty,
                  iconColor: AfTheme.yellow,
                  iconBgColor: AfTheme.yellowLight,
                  title: 'Pending',
                  value: AfTheme.formatCurrency(pendingTotal),
                  subtext: '${pendingCount > 0 ? pendingCount : 7} items',
                  subtextColor: AfTheme.textSecondary,
                ),
                AfKpiCard(
                  icon: Icons.cancel_outlined,
                  iconColor: AfTheme.red,
                  iconBgColor: AfTheme.redLight,
                  title: 'Rejected',
                  value: AfTheme.formatCurrency(rejectedTotal),
                  subtext: '${rejectedCount > 0 ? rejectedCount : 2} items',
                  subtextColor: AfTheme.textSecondary,
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards.map((c) => SizedBox(width: 220, child: c)).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Row 2: Charts & Quick Actions (3 Cards) ────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1000;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildTrendChartCard()),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: _buildExpenseBreakdownCard(expSummary, totalExpenses)),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: _buildQuickActionsCard()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildTrendChartCard(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildExpenseBreakdownCard(expSummary, totalExpenses)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildQuickActionsCard()),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Row 3: Recent Transactions & Top Artists ───────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1000;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _buildRecentTransactionsCard()),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: _buildTopArtistsCard(collSummary)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildRecentTransactionsCard(),
                  const SizedBox(height: 16),
                  _buildTopArtistsCard(collSummary),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Chart 1: Collections & Expenses Trend ──────────────────────────────────
  Widget _buildTrendChartCard() {
    return AfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.description_outlined, size: 18, color: AfTheme.maroon),
                  const SizedBox(width: 8),
                  const Text(
                    'Collections & Expenses Trend',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AfTheme.textPrimary),
                  ),
                ],
              ),
              Row(
                children: [
                  _legendDot(AfTheme.maroon, 'Collection'),
                  const SizedBox(width: 12),
                  _legendDot(AfTheme.coral, 'Expense'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AfTheme.border,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: 50,
                      getTitlesWidget: (val, meta) {
                        final text = switch (val.toInt()) {
                          0 => '0',
                          50 => '₹50K',
                          100 => '₹1.0L',
                          150 => '₹1.5L',
                          200 => '₹2.0L',
                          250 => '₹2.5L',
                          _ => '',
                        };
                        return Text(
                          text,
                          style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        const months = ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'];
                        final idx = val.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              months[idx],
                              style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: 250,
                lineBarsData: [
                  // Collections line (Maroon)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 70),
                      FlSpot(1, 95),
                      FlSpot(2, 100),
                      FlSpot(3, 120),
                      FlSpot(4, 150),
                      FlSpot(5, 190.75),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AfTheme.maroon,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AfTheme.maroon.withValues(alpha: 0.22),
                          AfTheme.maroon.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Expenses line (Coral Pink)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 30),
                      FlSpot(1, 38),
                      FlSpot(2, 42),
                      FlSpot(3, 40),
                      FlSpot(4, 38.12),
                      FlSpot(5, 35.05),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AfTheme.coral,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Chart 2: Expense Breakdown Donut ────────────────────────────────────────
  Widget _buildExpenseBreakdownCard(FinanceSummary? summary, double totalExp) {
    // Breakdown data
    final items = [
      ('Bridal Work', 23100.0, 0.66, AfTheme.maroon),
      ('Food', 4565.0, 0.13, AfTheme.coral),
      ('Travel', 3610.0, 0.10, const Color(0xFFF5A623)),
      ('Fuel', 2100.0, 0.06, AfTheme.green),
      ('Others', 1674.0, 0.05, const Color(0xFFBA68C8)),
    ];

    return AfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 18, color: AfTheme.maroon),
              const SizedBox(width: 8),
              const Text(
                'Expense Breakdown',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AfTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Donut chart
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        startDegreeOffset: -90,
                        sections: items.map((it) {
                          return PieChartSectionData(
                            color: it.$4,
                            value: it.$3 * 100,
                            radius: 16,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AfTheme.formatCurrency(totalExp),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AfTheme.textPrimary),
                        ),
                        const Text(
                          'Total Expense',
                          style: TextStyle(fontSize: 9, color: AfTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Category legend list
              Expanded(
                child: Column(
                  children: items.map((it) {
                    final percent = (it.$3 * 100).round();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: it.$4, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              it.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AfTheme.textPrimary),
                            ),
                          ),
                          Text(
                            AfTheme.formatCurrency(it.$2),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '$percent%',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Card 3: Quick Actions ───────────────────────────────────────────────────
  Widget _buildQuickActionsCard() {
    return AfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('⚡', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'Quick Actions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AfTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _quickActionButton(
            icon: Icons.add,
            label: 'Add Collection',
            onTap: widget.onAddCollection,
          ),
          const SizedBox(height: 8),
          _quickActionButton(
            icon: Icons.add,
            label: 'Add Expense',
            onTap: widget.onAddExpense,
          ),
          const SizedBox(height: 8),
          _quickActionButton(
            icon: Icons.swap_horiz,
            label: 'Record Payout',
            onTap: widget.onRecordPayout,
          ),
          const SizedBox(height: 8),
          _quickActionButton(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Generate Report',
            onTap: widget.onGenerateReport,
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AfTheme.border),
          color: AfTheme.surface,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AfTheme.maroon),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AfTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent Transactions Card ────────────────────────────────────────────────
  Widget _buildRecentTransactionsCard() {
    return AfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.access_time, size: 18, color: AfTheme.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AfTheme.textPrimary),
                  ),
                ],
              ),
              // Filter pills
              Row(
                children: [
                  _txPill('All', 'all'),
                  const SizedBox(width: 6),
                  _txPill('Collections', 'collections'),
                  const SizedBox(width: 6),
                  _txPill('Expenses', 'expenses'),
                  const SizedBox(width: 6),
                  _txPill('Payouts', 'payouts'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Transactions Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 48,
              horizontalMargin: 8,
              columnSpacing: 20,
              headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textSecondary),
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Artist / Client')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Category / Work')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('')),
              ],
              rows: _mockRecentTransactions(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _txPill(String label, String key) {
    final active = _txFilter == key;
    return InkWell(
      onTap: () => setState(() => _txFilter = key),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AfTheme.maroon : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: active ? null : Border.all(color: AfTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : AfTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  List<DataRow> _mockRecentTransactions() {
    final txs = [
      ('08 Nov 2026', 'Fathima Nihala', 'collection', 'Bridal Work', 344.0, 'pending'),
      ('08 Nov 2026', 'Fathima Nihala', 'expense', 'Food (Lunch - Team)', 250.0, 'verified'),
      ('07 Nov 2026', 'Anjali TK', 'collection', 'Bridal Work', 6932.0, 'verified'),
      ('06 Nov 2026', 'Anaswara', 'expense', 'Travel (Client Visit)', 620.0, 'verified'),
      ('05 Nov 2026', 'Anshida', 'collection', 'Event Work', 558.0, 'pending'),
    ];

    final filtered = txs.where((t) {
      if (_txFilter == 'collections') return t.$3 == 'collection';
      if (_txFilter == 'expenses') return t.$3 == 'expense';
      if (_txFilter == 'payouts') return t.$3 == 'payout';
      return true;
    }).toList();

    return filtered.map((t) {
      final isColl = t.$3 == 'collection';
      return DataRow(cells: [
        DataCell(Text(t.$1, style: const TextStyle(fontSize: 12, color: AfTheme.textSecondary))),
        DataCell(Text(t.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AfTheme.textPrimary))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isColl ? Icons.arrow_downward : Icons.arrow_upward,
              size: 13,
              color: isColl ? AfTheme.green : AfTheme.coral,
            ),
            const SizedBox(width: 4),
            Text(
              isColl ? 'Collection' : 'Expense',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isColl ? AfTheme.green : AfTheme.coral),
            ),
          ],
        )),
        DataCell(Text(t.$4, style: const TextStyle(fontSize: 12, color: AfTheme.textPrimary))),
        DataCell(Text(AfTheme.formatCurrency(t.$5), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AfTheme.textPrimary))),
        DataCell(AfStatusBadge(status: t.$6)),
        DataCell(IconButton(
          icon: const Icon(Icons.more_horiz, size: 16, color: AfTheme.textSecondary),
          onPressed: () {},
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        )),
      ]);
    }).toList();
  }

  // ── Card: Top Artists – Collection ──────────────────────────────────────────
  Widget _buildTopArtistsCard(FinanceSummary? summary) {
    final artists = [
      ('Fathima Nihala', 22649.0, 0.85),
      ('Anjali TK', 6932.0, 0.40),
      ('Anaswara', 4810.0, 0.28),
      ('Anshida', 558.0, 0.12),
      ('Malu PS', 100.0, 0.05),
    ];

    return AfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🏆', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 6),
                  Text(
                    'Top Artists – Collection (Nov 2026)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AfTheme.textPrimary),
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onNavigateTab(1), // switch to collections tab
                child: const Text(
                  'View All',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.maroon),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              for (int i = 0; i < artists.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _artistRankRow(i + 1, artists[i].$1, artists[i].$2, artists[i].$3),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _artistRankRow(int rank, String name, double amount, double progress) {
    final isFirst = rank == 1;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isFirst ? AfTheme.maroon : AfTheme.border,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isFirst ? Colors.white : AfTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AfTheme.textPrimary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AfTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AfTheme.maroon),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          AfTheme.formatCurrency(amount),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AfTheme.textPrimary),
        ),
      ],
    );
  }
}

