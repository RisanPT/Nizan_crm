import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/inventory_service.dart';
import 'inventory_dialogs.dart';
import 'inventory_widgets.dart';

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
        error: (e, _) => Center(
            child: Text('Failed to load inventory: $e',
                style: TextStyle(color: crm.textSecondary))),
        data: (products) {
          final totalUnits = products.fold<int>(0, (a, p) => a + p.quantity);
          final out = products.where((p) => p.isOut).toList();
          final expiring = products
              .where((p) =>
                  p.quantity > 0 &&
                  p.expiry != null &&
                  (daysLeft(p.expiry) ?? 999) <= 90)
              .length;
          final cats = products.map((p) => p.category).toSet();

          // Category distribution (product count).
          final counts = <String, int>{};
          for (final p in products) {
            counts[p.category] = (counts[p.category] ?? 0) + 1;
          }
          final entries = counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final totalCount = products.isEmpty ? 1 : products.length;

          final donut = InvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category Distribution',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: crm.textPrimary)),
                14.h,
                if (entries.isEmpty)
                  const SizedBox(
                    height: 120,
                    child: Center(child: Text('No products yet')),
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                for (final e in entries)
                                  PieChartSectionData(
                                    value: e.value.toDouble(),
                                    color: categoryColor(e.key),
                                    radius: 24,
                                    showTitle: false,
                                  ),
                              ],
                            )),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${products.length}',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: crm.textPrimary)),
                                Text('items',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: crm.textSecondary)),
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
                            for (final e in entries.take(6))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
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
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                color: crm.textPrimary))),
                                    Text(
                                        '${(e.value / totalCount * 100).round()}%',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: crm.textSecondary)),
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

          final restockCard = InvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Restock Needed',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary)),
                    8.w,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: crm.destructive.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${out.length}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: crm.destructive)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/inventory/alerts'),
                      child: const Text('View all'),
                    ),
                  ],
                ),
                8.h,
                if (out.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(children: [
                      Icon(Icons.check_circle_outline,
                          color: crm.success, size: 18),
                      8.w,
                      Text('Everything is in stock',
                          style:
                              TextStyle(fontSize: 13, color: crm.textSecondary)),
                    ]),
                  )
                else
                  for (final p in out.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: crm.destructive.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(productIcon(p.category),
                                size: 18, color: crm.destructive),
                          ),
                          10.w,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    p.shade.isNotEmpty && p.shade != '—'
                                        ? '${p.name} · ${p.shade}'
                                        : p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text('${p.brand} — ${p.category}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11, color: crm.textSecondary)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                showProductDialog(context, ref, product: p),
                            child: const Text('Restock'),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          );

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const InvHeader(
                  title: 'Inventory Dashboard',
                  subtitle: 'Studio stock at a glance'),
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
              InvStatGrid(isMobile: isMobile, stats: [
                InvStat('$totalUnits', 'Total Units',
                    Icons.inventory_2_outlined, crm.primary),
                InvStat('${out.length}', 'Out of Stock',
                    Icons.remove_shopping_cart_outlined, crm.destructive),
                InvStat('$expiring', 'Expiring Soon',
                    Icons.hourglass_bottom_rounded, crm.warning),
                InvStat('${cats.length}', 'Categories',
                    Icons.category_outlined, crm.accent),
              ]),
              16.h,
              if (isMobile)
                Column(children: [donut, 12.h, restockCard])
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: donut),
                    16.w,
                    Expanded(child: restockCard),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
