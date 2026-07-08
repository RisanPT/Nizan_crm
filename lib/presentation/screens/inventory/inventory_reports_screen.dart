import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/inventory_service.dart';
import 'inventory_widgets.dart';

class InventoryReportsScreen extends ConsumerWidget {
  const InventoryReportsScreen({super.key});

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
            child: Text('Failed to load reports: $e',
                style: TextStyle(color: crm.textSecondary))),
        data: (products) {
          // Stock value by category (qty × price).
          final catVal = <String, double>{};
          for (final p in products) {
            catVal[p.category] =
                (catVal[p.category] ?? 0) + p.quantity * p.price;
          }
          final entries = catVal.entries.where((e) => e.value > 0).toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final maxV = entries.isEmpty ? 1.0 : entries.first.value;
          final totalV = entries.fold<double>(0, (a, e) => a + e.value);
          final totalUnits = products.fold<int>(0, (a, p) => a + p.quantity);

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const InvHeader(
                  title: 'Reports', subtitle: 'Inventory value & insights'),
              16.h,
              InvStatGrid(isMobile: isMobile, stats: [
                InvStat(fmtINR(totalV), 'Total Value',
                    Icons.account_balance_wallet_outlined, crm.primary),
                InvStat('$totalUnits', 'Total Units',
                    Icons.inventory_2_outlined, crm.accent),
                InvStat('${products.length}', 'Products',
                    Icons.category_outlined, crm.success),
              ]),
              16.h,
              InvCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock Value by Category',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary)),
                    4.h,
                    Text('Quantity × price, per category',
                        style:
                            TextStyle(fontSize: 12, color: crm.textSecondary)),
                    16.h,
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                            child: Text('No stock value to report',
                                style:
                                    TextStyle(color: crm.textSecondary))),
                      )
                    else
                      for (final e in entries) ...[
                        Row(
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
                            Text(fmtINR(e.value),
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: crm.textPrimary)),
                          ],
                        ),
                        6.h,
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: e.value / maxV,
                            minHeight: 8,
                            backgroundColor: crm.input,
                            valueColor:
                                AlwaysStoppedAnimation(categoryColor(e.key)),
                          ),
                        ),
                        14.h,
                      ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
