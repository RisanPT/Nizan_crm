import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/purchase.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/inventory_service.dart';
import 'inventory_purchase_screen.dart';
import 'inventory_widgets.dart';

/// One ledger line = one purchase item, carrying its parent purchase (for date,
/// supplier and payment status).
class _LedgerRow {
  final Purchase purchase;
  final PurchaseItem item;
  const _LedgerRow(this.purchase, this.item);
}

/// Purchase Ledger — Date · Supplier · Product · Category · Amount · Paid,
/// with a running TOTAL and paid/unpaid split.
class InventoryPurchasesScreen extends ConsumerWidget {
  const InventoryPurchasesScreen({super.key});

  Future<void> _newPurchase(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InventoryPurchaseScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(purchasesProvider);

    return InvBody(
      isMobile: isMobile,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Failed to load ledger: $e',
                style: TextStyle(color: crm.textSecondary))),
        data: (purchases) {
          // Flatten to ledger rows (backend already sorts purchases by date desc).
          final rows = <_LedgerRow>[
            for (final p in purchases)
              for (final it in p.items) _LedgerRow(p, it),
          ];
          final total = purchases.fold<double>(0, (a, p) => a + p.total);
          final paid = purchases
              .where((p) => p.paid)
              .fold<double>(0, (a, p) => a + p.total);
          final unpaid = total - paid;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InvHeader(
                title: 'Purchase Ledger',
                subtitle: '${rows.length} entries',
                actionLabel: 'New',
                actionIcon: Icons.add_shopping_cart_outlined,
                onAction: () => _newPurchase(context),
              ),
              16.h,
              InvStatGrid(isMobile: isMobile, stats: [
                InvStat(fmtINR(total), 'Total', Icons.summarize_outlined,
                    crm.primary),
                InvStat(fmtINR(paid), 'Paid', Icons.check_circle_outline,
                    crm.success),
                InvStat(fmtINR(unpaid), 'Unpaid',
                    Icons.pending_actions_outlined, crm.warning),
              ]),
              16.h,
              Expanded(
                child: rows.isEmpty
                    ? const InvEmpty(
                        icon: Icons.receipt_long_outlined,
                        title: 'Ledger is empty',
                        subtitle:
                            'Record a purchase to start your buying ledger.')
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => 8.h,
                        itemBuilder: (context, i) =>
                            _row(context, ref, crm, rows[i]),
                      ),
              ),
              // ── TOTAL footer ─────────────────────────────────────────
              if (rows.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: crm.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Text('TOTAL',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: crm.textSecondary)),
                      const Spacer(),
                      Text(fmtINR(total),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: crm.primary)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
      BuildContext context, WidgetRef ref, CrmTheme crm, _LedgerRow r) {
    final p = r.purchase;
    final it = r.item;
    final title = it.shade.isNotEmpty && it.shade != '—'
        ? '${it.name} · ${it.shade}'
        : it.name;
    final sub =
        '${p.supplier.isEmpty ? 'No supplier' : p.supplier} · ${it.category}${it.stockIn ? '' : ' · expense'}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          // Date block
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('d MMM').format(p.date),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(DateFormat('yyyy').format(p.date),
                    style: TextStyle(fontSize: 10, color: crm.textSecondary)),
              ],
            ),
          ),
          10.w,
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: categoryColor(it.category), shape: BoxShape.circle),
          ),
          10.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                2.h,
                Text(sub,
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
              Text(fmtINR(it.subtotal),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
              4.h,
              _paidPill(context, ref, crm, p),
            ],
          ),
        ],
      ),
    );
  }

  /// Tappable payment pill — toggles the whole purchase's paid status.
  Widget _paidPill(
      BuildContext context, WidgetRef ref, CrmTheme crm, Purchase p) {
    final color = p.paid ? crm.success : crm.warning;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        try {
          await ref
              .read(inventoryServiceProvider)
              .setPurchasePaid(p.id, !p.paid);
          ref.invalidate(purchasesProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$e')));
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(p.paid ? Icons.check_circle : Icons.schedule,
                size: 11, color: color),
            const SizedBox(width: 4),
            Text(p.paid ? 'PAID' : 'UNPAID',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
