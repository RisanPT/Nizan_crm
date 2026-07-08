import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/inventory_product.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/inventory_service.dart';
import 'inventory_widgets.dart';

/// Artist read-only view of the studio inventory (existing stock), plus a
/// shortcut to build their own kit from it. Artists cannot add or edit stock.
class ArtistInventoryScreen extends ConsumerStatefulWidget {
  const ArtistInventoryScreen({super.key});

  @override
  ConsumerState<ArtistInventoryScreen> createState() =>
      _ArtistInventoryScreenState();
}

class _ArtistInventoryScreenState extends ConsumerState<ArtistInventoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
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
          final q = _search.trim().toLowerCase();
          final filtered = products.where((p) {
            return q.isEmpty ||
                ('${p.name} ${p.brand} ${p.shade}').toLowerCase().contains(q);
          }).toList()
            ..sort((a, b) => a.category.compareTo(b.category));

          final totalUnits = products.fold<int>(0, (a, p) => a + p.quantity);
          final low = products.where((p) => p.isLow || p.isOut).length;

          final grouped = <String, List<InventoryProduct>>{};
          for (final p in filtered) {
            grouped.putIfAbsent(p.category, () => []).add(p);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InvHeader(
                title: 'Inventory',
                subtitle: 'Studio stock · view only',
              ),
              14.h,
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/inventory/kits'),
                  icon: const Icon(Icons.work_outline, size: 18),
                  label: const Text('My Kits'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                ),
              ),
              14.h,
              InvStatGrid(isMobile: isMobile, stats: [
                InvStat('${products.length}', 'Products',
                    Icons.category_outlined, crm.primary),
                InvStat('$totalUnits', 'Units',
                    Icons.inventory_2_outlined, crm.accent),
                InvStat('$low', 'Low / Out',
                    Icons.trending_down_rounded, crm.warning),
              ]),
              14.h,
              Container(
                height: 46,
                decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: crm.border)),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search stock...',
                    hintStyle:
                        TextStyle(fontSize: 13.5, color: crm.textSecondary),
                    prefixIcon: Icon(Icons.search,
                        size: 19, color: crm.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
              16.h,
              Expanded(
                child: filtered.isEmpty
                    ? const InvEmpty(
                        icon: Icons.inventory_2_outlined,
                        title: 'No stock to show',
                        subtitle:
                            'Studio inventory will appear here once added.')
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          for (final entry in grouped.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                              child: Row(children: [
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: categoryColor(entry.key),
                                        shape: BoxShape.circle)),
                                8.w,
                                Text(entry.key.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: crm.textSecondary)),
                              ]),
                            ),
                            for (final p in entry.value) _row(crm, p),
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

  Widget _row(CrmTheme crm, InventoryProduct p) {
    // Studio stock is read-only for artists — they consume from their own kit
    // allocations (see "My Kits"), which never affects this shared stock.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
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
                Text('${p.brand.isEmpty ? '—' : p.brand} · ${p.category}',
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
              Text('${p.quantity}',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: p.isOut ? crm.destructive : crm.textPrimary)),
              2.h,
              Text('in studio',
                  style: TextStyle(fontSize: 10, color: crm.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
