import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/inventory_product.dart';
import '../../../core/models/staff_kit.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/inventory_service.dart';
import 'barcode_scanner_page.dart';
import 'inventory_dialogs.dart';
import 'inventory_widgets.dart';

enum StockView { all, kits, remaining }

/// Normalised key for matching a free-text kit item to a studio product.
String _matchKey(String name, String brand, String shade) {
  String n(String s) {
    final t = s.trim().toLowerCase();
    return t == '—' ? '' : t;
  }

  return '${n(name)}|${n(brand)}|${n(shade)}';
}

class InventoryStockScreen extends ConsumerStatefulWidget {
  const InventoryStockScreen({super.key});

  @override
  ConsumerState<InventoryStockScreen> createState() =>
      _InventoryStockScreenState();
}

class _InventoryStockScreenState extends ConsumerState<InventoryStockScreen> {
  String _search = '';
  String _cat = 'All';
  StockView _view = StockView.all;

  /// Scan a barcode from the header and show the existing product (or offer to
  /// add it if the code isn't registered yet).
  Future<void> _scanCheck() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    InventoryProduct? found;
    try {
      found = await ref.read(inventoryServiceProvider).lookupBarcode(code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    if (!mounted) return;
    if (found != null) {
      await showProductDialog(context, ref, product: found);
    } else {
      final add = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Not in stock'),
          content: Text(
              'No product is registered for barcode:\n\n$code\n\nAdd it now?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add product')),
          ],
        ),
      );
      if (add == true && mounted) {
        await showProductDialog(context, ref, initialBarcode: code);
      }
    }
  }

  Future<void> _delete(InventoryProduct p) async {
    final crm = context.crmColors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete ${p.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: crm.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(inventoryServiceProvider).deleteProduct(p.id);
      ref.invalidate(inventoryProductsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(inventoryProductsProvider);
    final kits = ref.watch(staffKitsProvider).value ?? const <StaffKit>[];

    // Allocation to kits, keyed by normalised product identity.
    final allocated = <String, int>{};
    for (final k in kits) {
      for (final it in k.items) {
        final key = _matchKey(it.name, it.brand, it.shade);
        allocated[key] = (allocated[key] ?? 0) + it.quantity;
      }
    }

    int allocatedFor(InventoryProduct p) =>
        allocated[_matchKey(p.name, p.brand, p.shade)] ?? 0;

    return InvBody(
      isMobile: isMobile,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Failed to load stock: $e',
                style: TextStyle(color: crm.textSecondary))),
        data: (products) {
          final q = _search.trim().toLowerCase();

          bool searchCat(InventoryProduct p) {
            final matchCat = _cat == 'All' || p.category == _cat;
            final matchQ = q.isEmpty ||
                ('${p.name} ${p.brand} ${p.shade}').toLowerCase().contains(q);
            return matchCat && matchQ;
          }

          final base = products.where(searchCat).toList();
          final allCount = base.length;
          final kitCount = base.where((p) => allocatedFor(p) > 0).length;
          final availCount =
              base.where((p) => (p.quantity - allocatedFor(p)) > 0).length;

          // Apply the view filter.
          final filtered = base.where((p) {
            switch (_view) {
              case StockView.all:
                return true;
              case StockView.kits:
                return allocatedFor(p) > 0;
              case StockView.remaining:
                return true;
            }
          }).toList()
            ..sort((a, b) => a.category.compareTo(b.category));

          final grouped = <String, List<InventoryProduct>>{};
          for (final p in filtered) {
            grouped.putIfAbsent(p.category, () => []).add(p);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InvHeader(
                title: 'Stock List',
                subtitle: '${products.length} products',
                trailing: IconButton(
                  onPressed: _scanCheck,
                  icon: const Icon(Icons.qr_code_scanner, size: 22),
                  tooltip: 'Scan to check stock',
                  style: IconButton.styleFrom(
                    foregroundColor: crm.primary,
                    backgroundColor: crm.primary.withValues(alpha: 0.10),
                    minimumSize: const Size(40, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                actionLabel: 'Add',
                onAction: () => showProductDialog(context, ref),
              ),
              14.h,
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                          color: crm.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: crm.border)),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: TextStyle(
                              fontSize: 13.5, color: crm.textSecondary),
                          prefixIcon: Icon(Icons.search,
                              size: 19, color: crm.textSecondary),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 13),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ),
                  10.w,
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: crm.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: crm.border)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _cat,
                        isDense: true,
                        borderRadius: BorderRadius.circular(12),
                        style:
                            TextStyle(fontSize: 13, color: crm.textPrimary),
                        items: [
                          const DropdownMenuItem(
                              value: 'All', child: Text('All')),
                          for (final c in InventoryProduct.categories)
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setState(() => _cat = v ?? 'All'),
                      ),
                    ),
                  ),
                ],
              ),
              12.h,
              // ── Complete stock / In kits / Remaining ─────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: crm.input, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    _seg(crm, 'All Stock', allCount, StockView.all),
                    _seg(crm, 'In Kits', kitCount, StockView.kits),
                    _seg(crm, 'Remaining', availCount, StockView.remaining),
                  ],
                ),
              ),
              14.h,
              Expanded(
                child: filtered.isEmpty
                    ? InvEmpty(
                        icon: Icons.inventory_2_outlined,
                        title: _view == StockView.kits
                            ? 'Nothing allocated to kits'
                            : 'No products found',
                        subtitle: _view == StockView.kits
                            ? 'Products added to staff kits appear here.'
                            : 'Try a different search, or add a product.')
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          for (final entry in grouped.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                              child: Row(
                                children: [
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
                                ],
                              ),
                            ),
                            for (final p in entry.value)
                              _row(crm, p, allocatedFor(p)),
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

  Widget _seg(CrmTheme crm, String label, int count, StockView view) {
    final selected = _view == view;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _view = view),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? crm.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? crm.primary : crm.textSecondary)),
                4.w,
                Text('$count',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? crm.primary.withValues(alpha: 0.7)
                            : crm.textSecondary.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(CrmTheme crm, InventoryProduct p, int allocated) {
    final remaining = (p.quantity - allocated).clamp(0, p.quantity);
    final qtyColor =
        p.isOut ? crm.destructive : (p.isLow ? const Color(0xFFB76E79) : crm.textPrimary);

    // Right-side metric depends on the active view.
    Widget metric;
    switch (_view) {
      case StockView.all:
        metric = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${p.quantity}',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: qtyColor)),
            3.h,
            StockPill(product: p),
          ],
        );
        break;
      case StockView.kits:
        metric = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$allocated',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: crm.accent)),
            2.h,
            Text('of ${p.quantity} in kits',
                style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          ],
        );
        break;
      case StockView.remaining:
        final none = remaining == 0;
        metric = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$remaining',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: none ? crm.destructive : crm.success)),
            2.h,
            Text(allocated > 0 ? 'left · $allocated in kits' : 'available',
                style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          ],
        );
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (_view == StockView.remaining && remaining == 0) ||
                (_view == StockView.all && p.isLow)
            ? const Color(0xFFFBEFF1)
            : crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                Text(
                    '${p.brand.isEmpty ? '—' : p.brand} · ${fmtINR(p.price)}${p.expiry != null ? ' · exp ${fmtExp(p.expiry)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          8.w,
          metric,
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: crm.textSecondary),
            onSelected: (v) {
              if (v == 'edit') showProductDialog(context, ref, product: p);
              if (v == 'delete') _delete(p);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text('Edit')
                  ])),
              PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete, size: 16, color: crm.destructive),
                    const SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: crm.destructive))
                  ])),
            ],
          ),
            ],
          ),
          if (_view == StockView.all) ...[
            10.h,
            TubeGauge(quantity: p.quantity, fillLevel: p.fillLevel),
          ],
        ],
      ),
    );
  }
}
