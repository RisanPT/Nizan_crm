import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';
import 'package:nizan_crm/features/inventory/data/purchase.dart';
import 'package:nizan_crm/features/inventory/data/vendor.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';

String _compact(double v) {
  if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
  return v.toStringAsFixed(0);
}

List<DateTime> _last12Months() {
  final now = DateTime.now();
  return List.generate(12, (i) => DateTime(now.year, now.month - 11 + i));
}

int _monthIndex(List<DateTime> months, DateTime d) =>
    months.indexWhere((m) => m.year == d.year && m.month == d.month);

// ── Screen ──────────────────────────────────────────────────────────────────

class InventoryReportsScreen extends ConsumerWidget {
  const InventoryReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(inventoryProductsProvider);
    // Purchases / vendors may be forbidden for some roles — null = unavailable.
    final purchases = ref.watch(purchasesProvider).value;
    final vendors = purchases == null
        ? const <Vendor>[]
        : (ref.watch(vendorsProvider).value ?? const <Vendor>[]);

    void refresh() {
      ref.invalidate(inventoryProductsProvider);
      ref.invalidate(purchasesProvider);
      ref.invalidate(vendorsProvider);
    }

    return InvBody(
      isMobile: isMobile,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: refresh),
        data: (products) => LayoutBuilder(builder: (context, box) {
          final stacked = box.maxWidth < 860;
          final now = DateTime.now();

          final stockValue =
              products.fold<double>(0, (a, p) => a + p.quantity * p.price);
          final units = products.fold<int>(0, (a, p) => a + p.quantity);
          final out = products.where((p) => p.isOut).length;
          final low = products.where((p) => p.isLow).length;
          final avgPrice = units == 0 ? 0.0 : stockValue / units;
          final cats = products.map((p) => p.category).toSet();
          final monthStart = DateTime(now.year, now.month);
          final monthSpend = purchases
              ?.where((p) => !p.date.isBefore(monthStart))
              .fold<double>(0, (a, p) => a + p.grandTotal);
          final monthBills = purchases
                  ?.where((p) => !p.date.isBefore(monthStart))
                  .length ??
              0;

          return RefreshIndicator(
            onRefresh: () async {
              refresh();
              try {
                await ref.read(inventoryProductsProvider.future);
              } catch (_) {
                // Failure is shown by the screen's error state; don't throw from pull-to-refresh.
              }
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                InvHeader(
                  title: 'Inventory Reports',
                  subtitle:
                      'Value, mix & trends · ${DateFormat('EEE, d MMM yyyy').format(now)}',
                  trailing: IconButton(
                    tooltip: 'Refresh',
                    icon: Icon(Icons.refresh_rounded, color: crm.textSecondary),
                    onPressed: refresh,
                  ),
                ),
                16.h,
                InvKpiGrid(width: box.maxWidth, stats: [
                  InvKpi(fmtINR(stockValue), 'Total Stock Value',
                      'qty × unit price', Icons.account_balance_wallet_outlined,
                      const Color(0xFF6E1423)),
                  InvKpi('$units', 'Units in Stock', 'across all products',
                      Icons.layers_outlined, crm.accent),
                  InvKpi('${products.length}', 'Products',
                      '${cats.length} categories', Icons.inventory_2_outlined,
                      crm.primary),
                  InvKpi(fmtINR(avgPrice), 'Avg Unit Price',
                      'stock value ÷ units', Icons.sell_outlined,
                      const Color(0xFF9E2B43)),
                  InvKpi('${low + out}', 'Low + Out of Stock',
                      '$out out · $low low', Icons.warning_amber_rounded,
                      crm.destructive),
                  if (monthSpend != null)
                    InvKpi(fmtINR(monthSpend), 'Purchases This Month',
                        '$monthBills bill${monthBills == 1 ? '' : 's'} in ${DateFormat('MMMM').format(now)}',
                        Icons.shopping_bag_outlined, crm.success),
                ]),
                16.h,
                invPair(
                  stacked,
                  _CategoryValueCard(products: products),
                  _CategoryShareCard(products: products),
                  flexA: 3,
                  flexB: 2,
                ),
                16.h,
                invPair(
                  stacked,
                  _TopProductsCard(products: products),
                  _StockStatusCard(products: products),
                  flexA: 3,
                  flexB: 2,
                ),
                16.h,
                if (purchases == null)
                  _AddedPerMonthCard(products: products)
                else ...[
                  invPair(
                    stacked,
                    _AddedPerMonthCard(products: products),
                    _SpendPerMonthCard(purchases: purchases),
                  ),
                  16.h,
                  _TopVendorsCard(
                      purchases: purchases,
                      vendors: vendors,
                      twoColumns: !stacked),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Stock value by category ─────────────────────────────────────────────────

class _CategoryValueCard extends StatelessWidget {
  final List<InventoryProduct> products;
  const _CategoryValueCard({required this.products});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final value = <String, double>{};
    final units = <String, int>{};
    final count = <String, int>{};
    for (final p in products) {
      value[p.category] = (value[p.category] ?? 0) + p.quantity * p.price;
      units[p.category] = (units[p.category] ?? 0) + p.quantity;
      count[p.category] = (count[p.category] ?? 0) + 1;
    }
    final rows = value.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = rows.fold<double>(0, (a, e) => a + e.value);
    final maxV = rows.isEmpty || rows.first.value <= 0 ? 1.0 : rows.first.value;

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Stock Value by Category',
            subtitle: 'Quantity × price · ${fmtINR(total)} total',
          ),
          16.h,
          if (rows.isEmpty)
            const InvEmptyLine('No products to report yet')
          else
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                              color: categoryColor(r.key)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7)),
                          child: Icon(productIcon(r.key),
                              size: 14, color: categoryColor(r.key)),
                        ),
                        10.w,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: crm.textPrimary)),
                              Text(
                                  '${count[r.key]} products · ${units[r.key]} units',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: crm.textSecondary)),
                            ],
                          ),
                        ),
                        8.w,
                        Text(fmtINR(r.value),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: crm.textPrimary)),
                        SizedBox(
                          width: 44,
                          child: Text(
                              total <= 0
                                  ? '0%'
                                  : '${(r.value / total * 100).round()}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: crm.textSecondary)),
                        ),
                      ],
                    ),
                    7.h,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (r.value / maxV).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: crm.input,
                        valueColor:
                            AlwaysStoppedAnimation(categoryColor(r.key)),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ── Category share donut (by stock value) ───────────────────────────────────

class _CategoryShareCard extends StatelessWidget {
  final List<InventoryProduct> products;
  const _CategoryShareCard({required this.products});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final value = <String, double>{};
    for (final p in products) {
      value[p.category] = (value[p.category] ?? 0) + p.quantity * p.price;
    }
    final entries = value.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (a, e) => a + e.value);

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InvSectionHeader(
              title: 'Category Share', subtitle: 'Share of total stock value'),
          16.h,
          if (entries.isEmpty)
            const InvEmptyLine('No stock value yet')
          else ...[
            Center(
              child: SizedBox(
                width: 170,
                height: 170,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 54,
                      sections: [
                        for (final e in entries)
                          PieChartSectionData(
                            value: e.value,
                            color: categoryColor(e.key),
                            radius: 26,
                            showTitle: false,
                          ),
                      ],
                    )),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('₹${_compact(total)}',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: crm.textPrimary)),
                          ),
                          Text('stock value',
                              style: TextStyle(
                                  fontSize: 10.5, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            16.h,
            for (final e in entries.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: categoryColor(e.key),
                            shape: BoxShape.circle)),
                    8.w,
                    Expanded(
                        child: Text(e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5, color: crm.textPrimary))),
                    Text(fmtINR(e.value),
                        style:
                            TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                    8.w,
                    SizedBox(
                      width: 36,
                      child: Text('${(e.value / total * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary)),
                    ),
                  ],
                ),
              ),
            if (entries.length > 8)
              Text('+ ${entries.length - 8} more categories',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ],
        ],
      ),
    );
  }
}

// ── Top 10 products by stock value ──────────────────────────────────────────

class _TopProductsCard extends StatelessWidget {
  final List<InventoryProduct> products;
  const _TopProductsCard({required this.products});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    double v(InventoryProduct p) => p.quantity * p.price;
    final top = products.where((p) => v(p) > 0).toList()
      ..sort((a, b) => v(b).compareTo(v(a)));
    final shown = top.take(10).toList();
    final maxV = shown.isEmpty ? 1.0 : v(shown.first);

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InvSectionHeader(
              title: 'Top Products by Value',
              subtitle: 'The 10 products holding the most stock value'),
          12.h,
          if (shown.isEmpty)
            const InvEmptyLine('No stock value yet')
          else ...[
            // Column headings
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Row(
                children: [
                  SizedBox(width: 30, child: _th(crm, '#')),
                  Expanded(child: _th(crm, 'PRODUCT')),
                  SizedBox(
                      width: 70,
                      child: _th(crm, 'QTY', align: TextAlign.right)),
                  SizedBox(
                      width: 90,
                      child: _th(crm, 'VALUE', align: TextAlign.right)),
                ],
              ),
            ),
            Divider(height: 1, color: crm.border),
            for (var i = 0; i < shown.length; i++)
              _topRow(crm, i, shown[i], v(shown[i]) / maxV),
          ],
        ],
      ),
    );
  }

  Widget _th(CrmTheme crm, String t, {TextAlign align = TextAlign.left}) =>
      Text(t,
          textAlign: align,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: crm.textSecondary));

  Widget _topRow(CrmTheme crm, int i, InventoryProduct p, double frac) {
    final c = categoryColor(p.category);
    final medal = i < 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: crm.border.faded(0.6))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: medal ? crm.primary : crm.input,
                shape: BoxShape.circle,
              ),
              child: Text('${i + 1}',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: medal ? Colors.white : crm.textSecondary)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invDisplayName(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: crm.textPrimary)),
                2.h,
                Row(
                  children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration:
                            BoxDecoration(color: c, shape: BoxShape.circle)),
                    5.w,
                    Expanded(
                      child: Text(
                          '${p.brand.isEmpty ? '—' : p.brand} · ${p.category}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5, color: crm.textSecondary)),
                    ),
                  ],
                ),
                4.h,
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: crm.input,
                    valueColor: AlwaysStoppedAnimation(c),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: Text('${p.quantity} × ${_compact(p.price)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ),
          SizedBox(
            width: 90,
            child: Text(fmtINR(p.quantity * p.price),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: crm.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Stock status breakdown ──────────────────────────────────────────────────

class _StockStatusCard extends StatelessWidget {
  final List<InventoryProduct> products;
  const _StockStatusCard({required this.products});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final out = products.where((p) => p.isOut).toList();
    final low = products.where((p) => p.isLow).toList();
    final healthy =
        products.where((p) => !p.isOut && !p.isLow).toList();
    final tubeLow = products.where((p) => p.isTubeLow).length;
    final total = products.length;
    double val(List<InventoryProduct> l) =>
        l.fold<double>(0, (a, p) => a + p.quantity * p.price);
    final segs = [
      ('Healthy', healthy.length, val(healthy), crm.success,
          Icons.check_circle_outline_rounded),
      ('Low stock', low.length, val(low), kLowStockColor,
          Icons.trending_down_rounded),
      ('Out of stock', out.length, val(out), crm.destructive,
          Icons.remove_shopping_cart_outlined),
    ];

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Stock Status',
            subtitle: total == 0
                ? 'No products yet'
                : '${(healthy.length / total * 100).round()}% of products are healthy',
          ),
          16.h,
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: total == 0
                  ? Container(color: crm.input)
                  : Row(
                      children: [
                        for (final s in segs)
                          if (s.$2 > 0)
                            Expanded(
                              flex: s.$2,
                              child: Container(
                                  color: s.$4,
                                  margin: const EdgeInsets.only(right: 2)),
                            ),
                      ],
                    ),
            ),
          ),
          16.h,
          for (final s in segs)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: s.$4.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s.$4.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: s.$4.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(s.$5, size: 16, color: s.$4),
                  ),
                  10.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: crm.textPrimary)),
                        Text('${fmtINR(s.$3)} in stock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                  Text('${s.$2}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: s.$4)),
                  SizedBox(
                    width: 44,
                    child: Text(
                        total == 0 ? '0%' : '${(s.$2 / total * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: crm.textSecondary)),
                  ),
                ],
              ),
            ),
          if (tubeLow > 0) ...[
            4.h,
            Row(
              children: [
                Icon(Icons.water_drop_outlined, size: 14, color: crm.warning),
                6.w,
                Expanded(
                  child: Text(
                      '$tubeLow product${tubeLow == 1 ? ' has its' : 's have their'} open tube ≤ 20% full',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Monthly bar chart (shared by "added" and "spend") ───────────────────────

class _MonthlyBars extends StatelessWidget {
  final List<DateTime> months;
  final List<double> values;
  final Color color;
  final bool isMoney;
  const _MonthlyBars({
    required this.months,
    required this.values,
    required this.color,
    required this.isMoney,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final n = values.length;
    final maxV = values.fold<double>(0, (a, v) => v > a ? v : a);
    final maxY = maxV <= 0 ? 4.0 : maxV * 1.25;

    return SizedBox(
      height: 210,
      child: LayoutBuilder(builder: (context, box) {
        final barW = ((box.maxWidth - 40) / n * 0.55).clamp(6.0, 22.0);
        final narrow = box.maxWidth < 420;
        return BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: crm.border.faded(0.5), strokeWidth: 1),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${DateFormat('MMM yyyy').format(months[group.x])}\n',
                  const TextStyle(color: Colors.white70, fontSize: 10.5),
                  children: [
                    TextSpan(
                      text: isMoney
                          ? fmtINR(rod.toY)
                          : '${rod.toY.toInt()} product${rod.toY == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  interval: maxY / 4,
                  getTitlesWidget: (v, meta) {
                    if (v == meta.max) return const SizedBox.shrink();
                    return Text(
                        isMoney ? _compact(v) : v.round().toString(),
                        style:
                            TextStyle(fontSize: 10, color: crm.textSecondary));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= n) return const SizedBox.shrink();
                    // On narrow cards show every other month label.
                    if (narrow && i.isOdd && i != n - 1) {
                      return const SizedBox.shrink();
                    }
                    final last = i == n - 1;
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      child: Text(
                          narrow
                              ? DateFormat('MMM').format(months[i]).substring(0, 1)
                              : DateFormat('MMM').format(months[i]),
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight:
                                  last ? FontWeight.w700 : FontWeight.w500,
                              color: last
                                  ? crm.textPrimary
                                  : crm.textSecondary)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < n; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: barW,
                    color: i == n - 1 ? color : color.withValues(alpha: 0.55),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(5)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: crm.input.withValues(alpha: 0.5),
                    ),
                  ),
                ]),
            ],
          ),
        );
      }),
    );
  }
}

class _AddedPerMonthCard extends StatelessWidget {
  final List<InventoryProduct> products;
  const _AddedPerMonthCard({required this.products});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final months = _last12Months();
    final values = List<double>.filled(12, 0);
    for (final p in products) {
      if (p.createdAt == null) continue;
      final i = _monthIndex(months, p.createdAt!);
      if (i >= 0) values[i] += 1;
    }
    final total = values.fold<double>(0, (a, v) => a + v).toInt();
    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Products Added',
            subtitle: 'Last 12 months · $total new product${total == 1 ? '' : 's'}',
          ),
          18.h,
          _MonthlyBars(
              months: months,
              values: values,
              color: crm.primary,
              isMoney: false),
        ],
      ),
    );
  }
}

class _SpendPerMonthCard extends StatelessWidget {
  final List<Purchase> purchases;
  const _SpendPerMonthCard({required this.purchases});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final months = _last12Months();
    final values = List<double>.filled(12, 0);
    for (final pu in purchases) {
      final i = _monthIndex(months, pu.date);
      if (i >= 0) values[i] += pu.grandTotal;
    }
    final total = values.fold<double>(0, (a, v) => a + v);
    final active = values.where((v) => v > 0).length;
    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Purchase Spend',
            subtitle: 'Last 12 months · ${fmtINR(total)} total'
                '${active > 0 ? ' · avg ${fmtINR(total / active)}/mo' : ''}',
          ),
          18.h,
          _MonthlyBars(
              months: months,
              values: values,
              color: crm.accent,
              isMoney: true),
        ],
      ),
    );
  }
}

// ── Top vendors by spend ────────────────────────────────────────────────────

class _TopVendorsCard extends StatelessWidget {
  final List<Purchase> purchases;
  final List<Vendor> vendors;
  final bool twoColumns;
  const _TopVendorsCard({
    required this.purchases,
    required this.vendors,
    required this.twoColumns,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final byId = {for (final v in vendors) v.id: v.name};
    final spend = <String, double>{};
    final bills = <String, int>{};
    final lastDate = <String, DateTime>{};
    for (final pu in purchases) {
      var name = (byId[pu.vendorId] ?? pu.supplier).trim();
      if (name.isEmpty) name = 'Unnamed vendor';
      spend[name] = (spend[name] ?? 0) + pu.grandTotal;
      bills[name] = (bills[name] ?? 0) + 1;
      final prev = lastDate[name];
      if (prev == null || pu.date.isAfter(prev)) lastDate[name] = pu.date;
    }
    final rows = spend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = rows.take(8).toList();
    final total = rows.fold<double>(0, (a, e) => a + e.value);
    final maxV = shown.isEmpty || shown.first.value <= 0 ? 1.0 : shown.first.value;

    Widget tile(int i, MapEntry<String, double> e) {
      final c = i == 0 ? crm.accent : crm.accent.withValues(alpha: 0.6);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: crm.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                  e.key.isEmpty ? '?' : e.key.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: crm.accent)),
            ),
            12.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: crm.textPrimary)),
                      ),
                      8.w,
                      Text(fmtINR(e.value),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary)),
                    ],
                  ),
                  3.h,
                  Text(
                      '${bills[e.key]} bill${bills[e.key] == 1 ? '' : 's'} · last ${DateFormat('d MMM yyyy').format(lastDate[e.key]!)}'
                      '${total > 0 ? ' · ${(e.value / total * 100).round()}% of spend' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11, color: crm.textSecondary)),
                  6.h,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (e.value / maxV).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: crm.input,
                      valueColor: AlwaysStoppedAnimation(c),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Top Vendors by Spend',
            subtitle:
                '${rows.length} vendor${rows.length == 1 ? '' : 's'} · ${fmtINR(total)} across ${purchases.length} bill${purchases.length == 1 ? '' : 's'}',
            count: shown.isEmpty ? null : shown.length,
            badgeColor: crm.accent,
          ),
          12.h,
          if (shown.isEmpty)
            const InvEmptyLine('No purchases recorded yet')
          else
            LayoutBuilder(builder: (context, box) {
              final cols = twoColumns ? 2 : 1;
              const gap = 10.0;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    SizedBox(width: w, child: tile(i, shown[i])),
                ],
              );
            }),
        ],
      ),
    );
  }
}
