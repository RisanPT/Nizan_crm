import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/inventory_product.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/inventory_service.dart';
import 'inventory_widgets.dart';

class InventoryExpiryScreen extends ConsumerWidget {
  const InventoryExpiryScreen({super.key});

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
            child: Text('Failed to load expiry data: $e',
                style: TextStyle(color: crm.textSecondary))),
        data: (products) {
          final withExp = products.where((p) => p.expiry != null).toList()
            ..sort((a, b) =>
                (daysLeft(a.expiry) ?? 0).compareTo(daysLeft(b.expiry) ?? 0));
          final soon = withExp.where((p) => (daysLeft(p.expiry) ?? 999) <= 60).length;
          final mid = withExp
              .where((p) {
                final d = daysLeft(p.expiry) ?? 999;
                return d > 60 && d <= 90;
              })
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InvHeader(
                  title: 'Expiry Tracker',
                  subtitle: 'Products by expiry date'),
              16.h,
              InvStatGrid(isMobile: isMobile, stats: [
                InvStat('$soon', 'Expiring ≤ 60d',
                    Icons.warning_amber_rounded, crm.destructive),
                InvStat('$mid', 'Due 60–90d',
                    Icons.hourglass_bottom_rounded, crm.warning),
                InvStat('${withExp.length}', 'Tracked',
                    Icons.event_outlined, crm.primary),
              ]),
              16.h,
              Expanded(
                child: withExp.isEmpty
                    ? const InvEmpty(
                        icon: Icons.event_available_outlined,
                        title: 'No expiry data',
                        subtitle: 'Add expiry dates to products to track them.')
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: withExp.length,
                        separatorBuilder: (_, _) => 10.h,
                        itemBuilder: (context, i) => _row(crm, withExp[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(CrmTheme crm, InventoryProduct p) {
    final dl = daysLeft(p.expiry) ?? 999;
    final soon = dl <= 60, midW = dl <= 90;
    final tagColor = soon
        ? crm.destructive
        : (midW ? crm.warning : crm.textSecondary);
    final left = dl < 0
        ? 'Expired'
        : (dl < 30 ? '$dl days' : '${(dl / 30).round()} months');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: soon ? const Color(0xFFFBEFF1) : crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: categoryColor(p.category).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(productIcon(p.category),
                color: categoryColor(p.category), size: 20),
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
                Text('${p.brand} — ${p.category}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          8.w,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtExp(p.expiry),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: crm.textPrimary)),
              4.h,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: soon ? 1 : 0.14),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(left,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: soon ? Colors.white : tagColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
