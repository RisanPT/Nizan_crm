import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_dialogs.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';

Widget _quickNav(
    BuildContext context, CrmTheme crm, String label, IconData icon, String route) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: crm.primary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: crm.textPrimary)),
          ],
        ),
      ),
    ),
  );
}

// ── Screen ──────────────────────────────────────────────────────────────────

class InventoryDashboardScreen extends ConsumerWidget {
  const InventoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(inventoryProductsProvider);

    return InvBody(
      isMobile: isMobile,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
            error: e, onRetry: () => ref.invalidate(inventoryProductsProvider)),
        data: (products) => LayoutBuilder(builder: (context, box) {
          final stacked = box.maxWidth < 860;
          final now = DateTime.now();

          // ── Derived metrics ──
          final totalUnits = products.fold<int>(0, (a, p) => a + p.quantity);
          final stockValue =
              products.fold<double>(0, (a, p) => a + p.quantity * p.price);
          final out = products.where((p) => p.isOut).toList();
          final low = products.where((p) => p.isLow).toList()
            ..sort((a, b) => a.quantity.compareTo(b.quantity));
          final healthy = products.length - out.length - low.length;
          final expiring = products
              .where((p) =>
                  p.quantity > 0 &&
                  p.expiry != null &&
                  (daysLeft(p.expiry) ?? 999) <= 90)
              .toList()
            ..sort((a, b) => a.expiry!.compareTo(b.expiry!));
          final expired =
              expiring.where((p) => (daysLeft(p.expiry) ?? 0) < 0).length;
          final cats = products.map((p) => p.category).toSet();
          final monthStart = DateTime(now.year, now.month);
          final weekAgo = now.subtract(const Duration(days: 7));
          final addedThisMonth = products
              .where((p) =>
                  p.createdAt != null && !p.createdAt!.isBefore(monthStart))
              .length;
          final addedThisWeek = products
              .where((p) => p.createdAt != null && p.createdAt!.isAfter(weekAgo))
              .length;
          final recent = products.where((p) => p.createdAt != null).toList()
            ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
          int pct(int n) =>
              products.isEmpty ? 0 : (n / products.length * 100).round();

          void restock(InventoryProduct p) =>
              showProductDialog(context, ref, product: p);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(inventoryProductsProvider);
              ref.invalidate(purchasesProvider);
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
                  title: 'Inventory Dashboard',
                  subtitle:
                      'Studio stock at a glance · ${DateFormat('EEE, d MMM yyyy').format(now)}',
                  actionLabel: isMobile ? 'Add' : 'Add Product',
                  onAction: () => showProductDialog(context, ref),
                  trailing: IconButton(
                    tooltip: 'Refresh',
                    icon: Icon(Icons.refresh_rounded, color: crm.textSecondary),
                    onPressed: () {
                      ref.invalidate(inventoryProductsProvider);
                      ref.invalidate(purchasesProvider);
                    },
                  ),
                ),
                14.h,
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _quickNav(context, crm, 'Stock List',
                          Icons.list_alt_outlined, '/inventory/stock'),
                      _quickNav(context, crm, 'Staff Kits', Icons.work_outline,
                          '/inventory/kits'),
                      _quickNav(context, crm, 'Alerts',
                          Icons.warning_amber_rounded, '/inventory/alerts'),
                      _quickNav(context, crm, 'Expiry',
                          Icons.hourglass_bottom_outlined, '/inventory/expiry'),
                      _quickNav(context, crm, 'Reports',
                          Icons.bar_chart_outlined, '/inventory/reports'),
                      _quickNav(context, crm, 'Purchases',
                          Icons.add_shopping_cart_outlined,
                          '/inventory/purchases'),
                    ],
                  ),
                ),
                16.h,

                // ── Stat cards ──
                InvKpiGrid(width: box.maxWidth, stats: [
                  InvKpi('${products.length}', 'Total Products',
                      '${cats.length} categories', Icons.inventory_2_outlined,
                      crm.primary),
                  InvKpi('$totalUnits', 'Units in Stock', 'across all products',
                      Icons.layers_outlined, crm.accent),
                  InvKpi(fmtINR(stockValue), 'Stock Value', 'qty × unit price',
                      Icons.currency_rupee_rounded, const Color(0xFF6E1423)),
                  InvKpi('$healthy', 'Healthy Stock',
                      '${pct(healthy)}% of products',
                      Icons.check_circle_outline_rounded, crm.success),
                  InvKpi('${low.length}', 'Low Stock',
                      'at or below reorder level', Icons.trending_down_rounded,
                      kLowStockColor),
                  InvKpi('${out.length}', 'Out of Stock', 'need restocking',
                      Icons.remove_shopping_cart_outlined, crm.destructive),
                  InvKpi(
                      '${expiring.length}',
                      'Expiring Soon',
                      expired > 0 ? '$expired already expired' : 'within 90 days',
                      Icons.hourglass_bottom_rounded,
                      crm.warning),
                  InvKpi('$addedThisMonth', 'Added This Month',
                      '$addedThisWeek in the last 7 days',
                      Icons.add_box_outlined, const Color(0xFF9E2B43)),
                ]),
                16.h,

                // ── Stock health bar ──
                _StockHealthCard(
                    healthy: healthy, low: low.length, out: out.length),
                16.h,

                // ── Charts ──
                invPair(
                  stacked,
                  _MonthlyActivityCard(products: products),
                  _CategoryDonutCard(products: products),
                  flexA: 3,
                  flexB: 2,
                ),
                16.h,
                invPair(
                  stacked,
                  _UnitsByCategoryCard(products: products),
                  _ExpiringCard(items: expiring, onRestock: restock),
                ),
                16.h,

                // ── Attention lists ──
                invPair(
                  stacked,
                  _AttentionList(
                    title: 'Out of Stock',
                    subtitle: 'Products with zero units left',
                    color: crm.destructive,
                    items: out,
                    emptyText: 'Nothing is out of stock',
                    onRestock: restock,
                  ),
                  _AttentionList(
                    title: 'Low Stock',
                    subtitle: 'At or below their reorder level',
                    color: kLowStockColor,
                    items: low,
                    emptyText: 'No products running low',
                    onRestock: restock,
                  ),
                ),
                16.h,

                // ── Recently added ──
                _RecentlyAddedCard(
                    items: recent, twoColumns: !stacked, onTap: restock),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Stock health ────────────────────────────────────────────────────────────

class _StockHealthCard extends StatelessWidget {
  final int healthy;
  final int low;
  final int out;
  const _StockHealthCard(
      {required this.healthy, required this.low, required this.out});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final total = healthy + low + out;
    final segs = [
      ('In stock', healthy, crm.success),
      ('Low stock', low, kLowStockColor),
      ('Out of stock', out, crm.destructive),
    ];
    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Stock Health', style: invCardTitle(crm)),
              const Spacer(),
              Text(
                  total == 0
                      ? 'No products'
                      : '${(healthy / total * 100).round()}% healthy',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: crm.success)),
            ],
          ),
          12.h,
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
                                color: s.$3,
                                margin: const EdgeInsets.only(right: 2),
                              ),
                            ),
                      ],
                    ),
            ),
          ),
          12.h,
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              for (final s in segs)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: s.$3,
                            borderRadius: BorderRadius.circular(3))),
                    6.w,
                    Text(s.$1,
                        style: TextStyle(
                            fontSize: 12, color: crm.textSecondary)),
                    6.w,
                    Text(
                        '${s.$2}${total == 0 ? '' : ' (${(s.$2 / total * 100).round()}%)'}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Monthly activity chart ──────────────────────────────────────────────────

enum _ActivityMode { added, spend }

class _MonthlyActivityCard extends ConsumerStatefulWidget {
  final List<InventoryProduct> products;
  const _MonthlyActivityCard({required this.products});

  @override
  ConsumerState<_MonthlyActivityCard> createState() =>
      _MonthlyActivityCardState();
}

class _MonthlyActivityCardState extends ConsumerState<_MonthlyActivityCard> {
  _ActivityMode _mode = _ActivityMode.added;

  static String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    // Purchases may be forbidden for some roles — treat that as "no data".
    final purchases = ref.watch(purchasesProvider).value;
    final canSpend = purchases != null;
    final mode = canSpend ? _mode : _ActivityMode.added;

    final now = DateTime.now();
    final months =
        List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
    int idx(DateTime d) => months.indexWhere(
        (m) => m.year == d.year && m.month == d.month);

    final values = List<double>.filled(6, 0);
    if (mode == _ActivityMode.added) {
      for (final p in widget.products) {
        if (p.createdAt == null) continue;
        final i = idx(p.createdAt!);
        if (i >= 0) values[i] += 1;
      }
    } else {
      for (final pu in purchases!) {
        final i = idx(pu.date);
        if (i >= 0) values[i] += pu.grandTotal;
      }
    }
    final maxV = values.fold<double>(0, (a, v) => v > a ? v : a);
    final maxY = maxV <= 0 ? 4.0 : maxV * 1.25;
    final total = values.fold<double>(0, (a, v) => a + v);
    final color = mode == _ActivityMode.added ? crm.primary : crm.accent;
    final isMoney = mode == _ActivityMode.spend;

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: isMoney ? 'Purchase Spend' : 'Products Added',
            subtitle: isMoney
                ? 'Last 6 months · ${fmtINR(total)} total'
                : 'Last 6 months · ${total.toInt()} new products',
            trailing: canSpend
                ? SegmentedButton<_ActivityMode>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const [
                      ButtonSegment(
                          value: _ActivityMode.added, label: Text('Added')),
                      ButtonSegment(
                          value: _ActivityMode.spend, label: Text('Spend')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) =>
                        setState(() => _mode = s.first),
                  )
                : null,
          ),
          18.h,
          SizedBox(
            height: 210,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: crm.border.faded(0.5),
                      strokeWidth: 1),
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
                            style: TextStyle(
                                fontSize: 10, color: crm.textSecondary));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(DateFormat('MMM').format(months[i]),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: i == 5
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: i == 5
                                      ? crm.textPrimary
                                      : crm.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < 6; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: values[i],
                        width: 22,
                        color: i == 5 ? color : color.withValues(alpha: 0.55),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: crm.input.withValues(alpha: 0.5),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category donut ──────────────────────────────────────────────────────────

class _CategoryDonutCard extends StatelessWidget {
  final List<InventoryProduct> products;
  const _CategoryDonutCard({required this.products});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final counts = <String, int>{};
    for (final p in products) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = products.isEmpty ? 1 : products.length;

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
              title: 'Category Mix',
              subtitle: '${entries.length} categories by product count'),
          16.h,
          if (entries.isEmpty)
            const SizedBox(
                height: 210, child: Center(child: Text('No products yet')))
          else
            SizedBox(
              height: 210,
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                          sections: [
                            for (final e in entries)
                              PieChartSectionData(
                                value: e.value.toDouble(),
                                color: categoryColor(e.key),
                                radius: 26,
                                showTitle: false,
                              ),
                          ],
                        )),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${products.length}',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: crm.textPrimary)),
                            Text('products',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: crm.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  16.w,
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final e in entries)
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
                                            fontSize: 12.5,
                                            color: crm.textPrimary))),
                                Text('${e.value}',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: crm.textSecondary)),
                                8.w,
                                SizedBox(
                                  width: 34,
                                  child: Text(
                                      '${(e.value / total * 100).round()}%',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: crm.textPrimary)),
                                ),
                              ],
                            ),
                          ),
                      ],
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

// ── Units by category (horizontal bars) ─────────────────────────────────────

class _UnitsByCategoryCard extends StatelessWidget {
  final List<InventoryProduct> products;
  const _UnitsByCategoryCard({required this.products});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final units = <String, int>{};
    final value = <String, double>{};
    for (final p in products) {
      units[p.category] = (units[p.category] ?? 0) + p.quantity;
      value[p.category] = (value[p.category] ?? 0) + p.quantity * p.price;
    }
    final rows = units.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxU = rows.isEmpty ? 1 : (rows.first.value == 0 ? 1 : rows.first.value);

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InvSectionHeader(
              title: 'Units by Category',
              subtitle: 'Units on hand and their stock value'),
          16.h,
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No products yet')),
            )
          else
            for (final r in rows.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(productIcon(r.key),
                            size: 14, color: categoryColor(r.key)),
                        6.w,
                        Expanded(
                          child: Text(r.key,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: crm.textPrimary)),
                        ),
                        Text('${r.value} units',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: crm.textPrimary)),
                        Text('  ·  ${fmtINR(value[r.key] ?? 0)}',
                            style: TextStyle(
                                fontSize: 11.5, color: crm.textSecondary)),
                      ],
                    ),
                    6.h,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: r.value / maxU,
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

// ── Out of stock / low stock lists ──────────────────────────────────────────

class _AttentionList extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<InventoryProduct> items;
  final String emptyText;
  final void Function(InventoryProduct) onRestock;
  const _AttentionList({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.items,
    required this.emptyText,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: title,
            subtitle: subtitle,
            count: items.length,
            badgeColor: color,
            onViewAll: items.length > 5
                ? () => context.go('/inventory/alerts')
                : null,
          ),
          12.h,
          if (items.isEmpty)
            InvEmptyLine(emptyText)
          else
            for (final p in items.take(5))
              InvProductTile(
                product: p,
                color: color,
                badge: invBadge(
                    p.isOut
                        ? '0 left'
                        : '${p.quantity} left · min ${p.lowStockThreshold}',
                    color),
                onAction: () => onRestock(p),
              ),
        ],
      ),
    );
  }
}

// ── Expiring soon ───────────────────────────────────────────────────────────

class _ExpiringCard extends StatelessWidget {
  final List<InventoryProduct> items;
  final void Function(InventoryProduct) onRestock;
  const _ExpiringCard({required this.items, required this.onRestock});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Expiring Soon',
            subtitle: 'In-stock products expiring within 90 days',
            count: items.length,
            badgeColor: crm.warning,
            onViewAll: () => context.go('/inventory/expiry'),
          ),
          12.h,
          if (items.isEmpty)
            const InvEmptyLine('No products expiring soon')
          else
            for (final p in items.take(5))
              Builder(builder: (_) {
                final d = daysLeft(p.expiry) ?? 0;
                final c = d < 0
                    ? crm.destructive
                    : (d <= 30 ? crm.warning : kLowStockColor);
                return InvProductTile(
                  product: p,
                  color: c,
                  detail:
                      '${p.brand.isEmpty ? '—' : p.brand} · exp ${DateFormat('d MMM yyyy').format(p.expiry!)}',
                  badge: invBadge(
                      d < 0 ? 'Expired' : (d == 0 ? 'Today' : '${d}d left'),
                      c),
                  actionLabel: 'Edit',
                  onAction: () => onRestock(p),
                );
              }),
        ],
      ),
    );
  }
}

// ── Recently added (with date & time) ───────────────────────────────────────

class _RecentlyAddedCard extends StatelessWidget {
  final List<InventoryProduct> items;
  final bool twoColumns;
  final void Function(InventoryProduct) onTap;
  const _RecentlyAddedCard(
      {required this.items, required this.twoColumns, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shown = items.take(twoColumns ? 8 : 6).toList();
    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Recently Added',
            subtitle: 'Latest products with the date and time they were added',
            onViewAll: () => context.go('/inventory/stock'),
          ),
          12.h,
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No products added yet')),
            )
          else
            LayoutBuilder(builder: (context, box) {
              final cols = twoColumns ? 2 : 1;
              const gap = 10.0;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final p in shown)
                    SizedBox(
                        width: w,
                        child: _RecentTile(product: p, onTap: () => onTap(p))),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final InventoryProduct product;
  final VoidCallback onTap;
  const _RecentTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final p = product;
    final c = categoryColor(p.category);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(productIcon(p.category), size: 20, color: c),
            ),
            12.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(invDisplayName(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: crm.textPrimary)),
                      ),
                      6.w,
                      StockPill(product: p),
                    ],
                  ),
                  3.h,
                  Text(
                      '${p.brand.isEmpty ? '—' : p.brand} · ${p.category} · ${p.quantity} units · ${fmtINR(p.price)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  5.h,
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 12, color: crm.primary),
                      4.w,
                      Flexible(
                        child: Text(fmtAdded(p.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: crm.primary)),
                      ),
                      Text('  ·  ${fmtAgo(p.createdAt)}',
                          style: TextStyle(
                              fontSize: 11, color: crm.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
