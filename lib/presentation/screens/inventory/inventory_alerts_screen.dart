import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/inventory_product.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/inventory_service.dart';
import 'inventory_dialogs.dart';
import 'inventory_widgets.dart';

class InventoryAlertsScreen extends ConsumerWidget {
  const InventoryAlertsScreen({super.key});

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
            child: Text('Failed to load alerts: $e',
                style: TextStyle(color: crm.textSecondary))),
        data: (products) {
          final out = products.where((p) => p.isOut).toList();
          final low = products.where((p) => p.isLow).toList();
          final rows = [...out, ...low];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InvHeader(
                  title: 'Restock Alerts',
                  subtitle: 'Out of stock & low items'),
              16.h,
              InvStatGrid(isMobile: isMobile, stats: [
                InvStat('${out.length}', 'Out of Stock',
                    Icons.remove_shopping_cart_outlined, crm.destructive),
                InvStat('${low.length}', 'Low Stock',
                    Icons.trending_down_rounded, crm.warning),
              ]),
              16.h,
              Expanded(
                child: rows.isEmpty
                    ? InvEmpty(
                        icon: Icons.verified_outlined,
                        title: 'All stocked up',
                        subtitle: 'Nothing needs restocking right now.')
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => 10.h,
                        itemBuilder: (context, i) =>
                            _alertRow(context, ref, crm, rows[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _alertRow(
      BuildContext context, WidgetRef ref, CrmTheme crm, InventoryProduct p) {
    final out = p.isOut;
    final color = out ? crm.destructive : crm.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: out ? const Color(0xFFFBEFF1) : crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withValues(alpha: out ? 0.9 : 0.14),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(productIcon(p.category),
                color: out ? Colors.white : color, size: 20),
          ),
          12.w,
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
                        fontSize: 14, fontWeight: FontWeight.w600)),
                2.h,
                Text(
                    '${p.brand} — ${p.category}${out ? '' : ' · ${p.quantity} left'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          8.w,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
                color: out ? crm.destructive : color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20)),
            child: Text(out ? 'OUT' : 'LOW',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: out ? Colors.white : color)),
          ),
          4.w,
          TextButton(
            onPressed: () => showProductDialog(context, ref, product: p),
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }
}
