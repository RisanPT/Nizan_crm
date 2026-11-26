import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_list_kit.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/finance_list_widgets.dart' show kArtistExpenseCategoryLabels;

/// One row of "Recent Transactions": a collection or an expense, newest first.
class _Tx {
  /// The entry's own id — what makes a row its own (two entries can share a day, a kind and an amount).
  final String id;
  final DateTime date;
  final String who;
  final bool isCollection;
  final String what;
  final double amount;
  final String status;
  const _Tx(this.id, this.date, this.who, this.isCollection, this.what, this.amount, this.status);
}

/// Desktop Artist Finance → Overview, all of it real: what was collected and spent in the period
/// (against the period before it), where the spending went, who collected the most, and the latest
/// entries. Nothing here is a stand-in — with no data a card says so.
///
/// The figures are the period's own, NOT the filters set in the Collections / Expenses tabs — the
/// screen asks for them separately, so filtering a list never changes the overview.
class ArtistFinanceOverviewView extends StatefulWidget {
  /// The period's collections (all statuses) — the totals by status and the newest entries.
  final FinancePage<ArtistCollection>? collections;

  /// The period's expenses that count (pending + approved; a rejected bill is not spend) — the totals
  /// by status, the category breakdown and the newest entries.
  final FinancePage<ArtistExpense>? expenses;

  /// Who collected the most (verified collections only), best first.
  final List<LabelTotal> topArtists;

  /// The period just before, for "vs Oct" (null = nothing to compare against).
  final FinanceSummary? previousCollections;
  final FinanceSummary? previousExpenses;
  final String previousLabel;

  /// "November 2026" / "All time" / "Custom range" — what the figures are for.
  final String periodText;
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;

  final VoidCallback onAddCollection;
  final VoidCallback onAddExpense;

  /// Null = this user cannot process payouts, so the shortcut is not offered.
  final VoidCallback? onRecordPayout;
  final VoidCallback onGenerateReport;
  final ValueChanged<int> onNavigateTab;

  const ArtistFinanceOverviewView({
    super.key,
    required this.collections,
    required this.expenses,
    this.topArtists = const [],
    this.previousCollections,
    this.previousExpenses,
    this.previousLabel = 'last period',
    this.periodText = '',
    this.loading = false,
    this.error,
    this.onRetry,
    required this.onAddCollection,
    required this.onAddExpense,
    this.onRecordPayout,
    required this.onGenerateReport,
    required this.onNavigateTab,
  });

  @override
  State<ArtistFinanceOverviewView> createState() => _ArtistFinanceOverviewViewState();
}

class _ArtistFinanceOverviewViewState extends State<ArtistFinanceOverviewView> {
  String _txFilter = 'all'; // all | collections | expenses

  /// The bar of the period before — a quiet grey beside this period's colour.
  static const _previousBar = Color(0xFFCFC4C8);

  static const _categoryColors = <String, Color>{
    'food': AfTheme.coral,
    'travel': Color(0xFF1976D2),
    'stay': Color(0xFF673AB7),
    'materials': Color(0xFFF5A623),
    'fuel': AfTheme.green,
    'other': Color(0xFF9E9E9E),
  };

  /// ₹1,23,456 → "₹1.2L"; ₹45,000 → "₹45K".
  static String _short(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}K';
    return '₹${v.round()}';
  }

  // what counts: collections the team has verified, expenses that are approved or still pending
  double _collected(FinanceSummary? s) => s?.status('verified').amount ?? 0;
  double _spent(FinanceSummary? s) => (s?.status('verified').amount ?? 0) + (s?.status('pending').amount ?? 0);

  @override
  Widget build(BuildContext context) {
    final cs = widget.collections?.summary;
    final es = widget.expenses?.summary;
    final haveData = cs != null && es != null;
    final collected = _collected(cs);
    final spent = _spent(es);
    final net = collected - spent;
    final pc = widget.previousCollections;
    final pe = widget.previousExpenses;
    final prevCollected = pc == null ? null : _collected(pc);
    final prevSpent = pe == null ? null : _spent(pe);
    final prevNet = pc == null || pe == null ? null : _collected(pc) - _spent(pe);

    final pendingAmount = (cs?.status('pending').amount ?? 0) + (es?.status('pending').amount ?? 0);
    final pendingCount = (cs?.status('pending').count ?? 0) + (es?.status('pending').count ?? 0);
    final rejectedAmount = (cs?.status('rejected').amount ?? 0) + (es?.status('rejected').amount ?? 0);
    final rejectedCount = (cs?.status('rejected').count ?? 0) + (es?.status('rejected').count ?? 0);

    String money(double v) => haveData ? AfTheme.formatCurrency(v) : '—';
    final dCollected = haveData ? afDeltaText(current: collected, previous: prevCollected, previousLabel: widget.previousLabel, higherIsGood: true) : null;
    final dSpent = haveData ? afDeltaText(current: spent, previous: prevSpent, previousLabel: widget.previousLabel, higherIsGood: false) : null;
    final dNet = haveData && net > 0 && prevNet != null && prevNet > 0
        ? afDeltaText(current: net, previous: prevNet, previousLabel: widget.previousLabel, higherIsGood: true)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.loading) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 3)),
          if (widget.error != null && !widget.loading && !haveData)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AfCard(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AfTheme.red, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('The overview could not be loaded.', style: TextStyle(fontSize: 13, color: AfTheme.textPrimary))),
                    if (widget.onRetry != null) TextButton(onPressed: widget.onRetry, child: const Text('Try again')),
                  ],
                ),
              ),
            ),
          AfKpiRow(
            cards: [
              AfKpiCard(
                icon: Icons.currency_rupee,
                iconColor: AfTheme.green,
                iconBgColor: AfTheme.greenLight,
                title: 'Total Collected',
                value: money(collected),
                subtext: dCollected?.text ?? (haveData ? '${cs.status('verified').count} verified' : null),
                subtextColor: dCollected?.color ?? AfTheme.textSecondary,
              ),
              AfKpiCard(
                icon: Icons.receipt_long_outlined,
                iconColor: AfTheme.coral,
                iconBgColor: AfTheme.coralLight,
                title: 'Total Expenses',
                value: money(spent),
                subtext: dSpent?.text ?? (haveData ? 'Approved + pending' : null),
                subtextColor: dSpent?.color ?? AfTheme.textSecondary,
              ),
              AfKpiCard(
                icon: Icons.trending_up,
                iconColor: AfTheme.purple,
                iconBgColor: AfTheme.purpleLight,
                title: 'Net',
                value: haveData ? (net < 0 ? '−${AfTheme.formatCurrency(-net)}' : AfTheme.formatCurrency(net)) : '—',
                subtext: dNet?.text ?? (haveData ? 'Collected − expenses' : null),
                subtextColor: dNet?.color ?? AfTheme.textSecondary,
              ),
              AfKpiCard(
                icon: Icons.hourglass_empty,
                iconColor: AfTheme.yellow,
                iconBgColor: AfTheme.yellowLight,
                title: 'Pending',
                value: money(pendingAmount),
                subtext: haveData ? '$pendingCount ${pendingCount == 1 ? 'item' : 'items'} to check' : null,
                subtextColor: AfTheme.textSecondary,
              ),
              AfKpiCard(
                icon: Icons.cancel_outlined,
                iconColor: AfTheme.red,
                iconBgColor: AfTheme.redLight,
                title: 'Rejected',
                value: money(rejectedAmount),
                subtext: haveData ? '$rejectedCount ${rejectedCount == 1 ? 'item' : 'items'}' : null,
                subtextColor: AfTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final chart = _buildCompareCard(collected, spent, prevCollected, prevSpent, haveData);
              final breakdown = _buildBreakdownCard(es, spent);
              final actions = _buildQuickActionsCard();
              if (c.maxWidth >= 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: chart),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: breakdown),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: actions),
                  ],
                );
              }
              return Column(
                children: [
                  chart,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: breakdown),
                      const SizedBox(width: 16),
                      Expanded(child: actions),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final recent = _buildRecentCard();
              final top = _buildTopArtistsCard();
              if (c.maxWidth >= 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: recent),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: top),
                  ],
                );
              }
              return Column(children: [recent, const SizedBox(height: 16), top]);
            },
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(IconData icon, String text, {Widget? trailing}) => Row(
        children: [
          Icon(icon, size: 18, color: AfTheme.maroon),
          const SizedBox(width: 8),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AfTheme.textPrimary))),
          ?trailing,
        ],
      );

  Widget _noData(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AfTheme.textSecondary))),
      );

  // ── Card: this period against the one before ───────────────────────────────

  Widget _buildCompareCard(double collected, double spent, double? prevCollected, double? prevSpent, bool haveData) {
    final hasPrev = prevCollected != null && prevSpent != null;
    final values = [collected, spent, ?prevCollected, ?prevSpent];
    final top = values.fold<double>(0, (a, b) => b > a ? b : a);
    final maxY = top <= 0 ? 1.0 : top * 1.2;

    BarChartRodData rod(double v, Color color) => BarChartRodData(
          toY: v,
          color: color,
          width: hasPrev ? 26 : 38,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        );

    return AfCard(
      key: const Key('afOverviewCompare'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.bar_chart_rounded,
            hasPrev ? 'Collections & Expenses vs ${widget.previousLabel}' : 'Collections & Expenses',
            trailing: Wrap(
              spacing: 12,
              children: [
                if (hasPrev) _legendDot(_previousBar, widget.previousLabel),
                _legendDot(AfTheme.maroon, widget.periodText.isEmpty ? 'This period' : widget.periodText),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!haveData || (top <= 0))
            _noData(haveData ? 'Nothing collected or spent in this period yet.' : 'Loading…')
          else
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => const FlLine(color: AfTheme.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        interval: maxY / 4,
                        getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox.shrink() : Text(_short(v), style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(v.toInt() == 0 ? 'Collected' : 'Expenses', style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary)),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(x: 0, barsSpace: 6, barRods: [if (hasPrev) rod(prevCollected, _previousBar), rod(collected, AfTheme.maroon)]),
                    BarChartGroupData(x: 1, barsSpace: 6, barRods: [if (hasPrev) rod(prevSpent, _previousBar), rod(spent, AfTheme.coral)]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11, color: AfTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      );

  // ── Card: where the spending went ──────────────────────────────────────────

  Widget _buildBreakdownCard(FinanceSummary? summary, double total) {
    final rows = [...?summary?.byCategory.where((r) => r.amount > 0)]..sort((a, b) => b.amount.compareTo(a.amount));
    final sum = rows.fold<double>(0, (a, r) => a + r.amount);
    return AfCard(
      key: const Key('afOverviewBreakdown'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.pie_chart_outline, 'Expense Breakdown'),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            _noData(summary == null ? 'Loading…' : 'No expenses in this period.')
          else
            Row(
              children: [
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
                          sections: [
                            for (final r in rows)
                              PieChartSectionData(color: _categoryColors[r.key] ?? _categoryColors['other'], value: r.amount, radius: 16, showTitle: false),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AfTheme.formatCurrency(sum), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AfTheme.textPrimary)),
                          const Text('Total Expense', style: TextStyle(fontSize: 9, color: AfTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (final r in rows)
                        Padding(
                          key: Key('afBreakdown_${r.key}'),
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: _categoryColors[r.key] ?? _categoryColors['other'], shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  kArtistExpenseCategoryLabels[r.key] ?? r.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AfTheme.textPrimary),
                                ),
                              ),
                              Text(AfTheme.formatCurrency(r.amount), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 32,
                                child: Text('${(r.amount / sum * 100).round()}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, color: AfTheme.textSecondary)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Card: quick actions ────────────────────────────────────────────────────

  Widget _buildQuickActionsCard() {
    return AfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.bolt_outlined, 'Quick Actions'),
          const SizedBox(height: 14),
          _quickActionButton(icon: Icons.add, label: 'Add Collection', onTap: widget.onAddCollection),
          const SizedBox(height: 8),
          _quickActionButton(icon: Icons.add, label: 'Add Expense', onTap: widget.onAddExpense),
          if (widget.onRecordPayout != null) ...[
            const SizedBox(height: 8),
            _quickActionButton(icon: Icons.swap_horiz, label: 'Artist Payouts', onTap: widget.onRecordPayout!),
          ],
          const SizedBox(height: 8),
          _quickActionButton(icon: Icons.picture_as_pdf_outlined, label: 'Generate Report', onTap: widget.onGenerateReport),
        ],
      ),
    );
  }

  Widget _quickActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
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
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ── Card: the latest entries ───────────────────────────────────────────────

  List<_Tx> _transactions() {
    final all = <_Tx>[
      for (final c in widget.collections?.items ?? const <ArtistCollection>[])
        _Tx(c.id, c.date, c.employee?.name ?? 'Artist', true, c.booking?.customerName ?? c.trial?.clientName ?? 'Direct client', c.amount, c.status),
      for (final e in widget.expenses?.items ?? const <ArtistExpense>[])
        _Tx(e.id, e.date, e.employee?.name ?? 'Artist', false, kArtistExpenseCategoryLabels[e.category] ?? e.category, e.amount, e.status),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return all.where((t) => _txFilter == 'all' || (_txFilter == 'collections' ? t.isCollection : !t.isCollection)).take(8).toList();
  }

  Widget _buildRecentCard() {
    final txs = _transactions();
    return AfCard(
      key: const Key('afOverviewRecent'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.access_time,
            'Recent Transactions',
            trailing: Wrap(
              spacing: 6,
              children: [_txPill('All', 'all'), _txPill('Collections', 'collections'), _txPill('Expenses', 'expenses')],
            ),
          ),
          const SizedBox(height: 14),
          if (txs.isEmpty)
            _noData(widget.collections == null || widget.expenses == null ? 'Loading…' : 'No transactions in this period.')
          else
            AfTable<_Tx>(
              minWidth: 560,
              columns: const [
                AfColumn('Date', width: 104),
                AfColumn('Artist', flex: 3),
                AfColumn('Type', width: 104),
                AfColumn('Client / Category', flex: 3),
                AfColumn('Amount', width: 90, right: true),
                AfColumn('Status', width: 96),
              ],
              items: txs,
              rowKey: (t) => Key('afTx_${t.isCollection ? 'c' : 'e'}_${t.id}'),
              cells: (t) => [
                AfCellText(afDay(t.date), muted: true),
                AfCellText(t.who, strong: true),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.isCollection ? Icons.arrow_downward : Icons.arrow_upward, size: 13, color: t.isCollection ? AfTheme.green : AfTheme.coral),
                    const SizedBox(width: 4),
                    Flexible(child: AfCellText(t.isCollection ? 'Collection' : 'Expense', color: t.isCollection ? AfTheme.green : AfTheme.coral)),
                  ],
                ),
                AfCellText(t.what),
                AfCellText(AfTheme.formatCurrency(t.amount), strong: true),
                AfFit(AfStatusBadge(status: t.status)),
              ],
              card: (t) => Row(
                children: [
                  Icon(t.isCollection ? Icons.arrow_downward : Icons.arrow_upward, size: 16, color: t.isCollection ? AfTheme.green : AfTheme.coral),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [AfCellText(t.who, strong: true), AfCellText('${afDay(t.date)} · ${t.what}', muted: true)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AfCellText(AfTheme.formatCurrency(t.amount), strong: true),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _txPill(String label, String key) {
    final active = _txFilter == key;
    return InkWell(
      key: Key('afTxPill_$key'),
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
          style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? Colors.white : AfTheme.textSecondary),
        ),
      ),
    );
  }

  // ── Card: who collected the most ───────────────────────────────────────────

  Widget _buildTopArtistsCard() {
    final artists = widget.topArtists.where((a) => a.amount > 0).take(5).toList();
    final best = artists.isEmpty ? 1.0 : artists.first.amount;
    return AfCard(
      key: const Key('afOverviewTopArtists'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.emoji_events_outlined,
            'Top Artists – Collections${widget.periodText.isEmpty ? '' : ' (${widget.periodText})'}',
            trailing: InkWell(
              onTap: () => widget.onNavigateTab(1), // the Collections tab
              child: const Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AfTheme.maroon)),
            ),
          ),
          const SizedBox(height: 16),
          if (artists.isEmpty)
            _noData('No verified collections in this period.')
          else
            for (var i = 0; i < artists.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _artistRankRow(i + 1, artists[i].name, artists[i].amount, artists[i].amount / best),
            ],
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
          decoration: BoxDecoration(color: isFirst ? AfTheme.maroon : AfTheme.border, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$rank', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isFirst ? Colors.white : AfTheme.textSecondary)),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AfTheme.textPrimary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AfTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AfTheme.maroon),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(AfTheme.formatCurrency(amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AfTheme.textPrimary)),
      ],
    );
  }
}
