import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';
import 'package:nizan_crm/features/inventory/data/staff_kit.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/features/inventory/utils/inventory_import.dart';
import 'barcode_scanner_page.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_dialogs.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

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

/// Sort orders offered in the stock toolbar.
enum _StockSort { newest, oldest, nameAz, qtyLow, qtyHigh, valueHigh, expirySoon }

String _sortLabel(_StockSort s) {
  switch (s) {
    case _StockSort.newest:
      return 'Newest added';
    case _StockSort.oldest:
      return 'Oldest added';
    case _StockSort.nameAz:
      return 'Name A–Z';
    case _StockSort.qtyLow:
      return 'Quantity low → high';
    case _StockSort.qtyHigh:
      return 'Quantity high → low';
    case _StockSort.valueHigh:
      return 'Value high → low';
    case _StockSort.expirySoon:
      return 'Expiry soonest';
  }
}

/// Compares nullable dates, always placing nulls last.
int _cmpDate(DateTime? a, DateTime? b, {required bool desc}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return desc ? b.compareTo(a) : a.compareTo(b);
}

class _InventoryStockScreenState extends ConsumerState<InventoryStockScreen> {
  static const _pageSize = 24;
  static const _cardHeight = 262.0;

  String _search = '';
  String _cat = 'All';
  StockView _view = StockView.all;
  _StockSort _sort = _StockSort.newest;
  int _page = 0;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _gridTopKey = GlobalKey();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Applies a search/filter/view/sort change and jumps back to page 1.
  void _update(VoidCallback fn) => setState(() {
        fn();
        _page = 0;
      });

  void _goToPage(int page) {
    setState(() => _page = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _gridTopKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

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
        showErrorSnackBar(context, e);
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
      try {
        await ref.read(inventoryServiceProvider).deleteProduct(p.id);
        ref.refreshData.inventory();
      } catch (e) {
        if (mounted) showErrorSnackBar(context, e);
      }
    }
  }

  /// Bulk-import existing stock from an Excel (.xlsx) or CSV file. Parses the
  /// file locally, previews the result, then posts to the bulk endpoint.
  Future<void> _importStock() async {
    final messenger = ScaffoldMessenger.of(context);
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        withData: true,
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the file picker. Please try again.')),
      );
      return;
    }
    if (picked == null || !mounted) return;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }

    final result = parseInventoryImport(bytes, file.name);
    if (!mounted) return;

    final confirmed = await _showImportPreview(file.name, result);
    if (confirmed != true || !mounted) return;

    messenger.showSnackBar(
      SnackBar(content: Text('Importing ${result.items.length} products…')),
    );
    try {
      final inserted =
          await ref.read(inventoryServiceProvider).bulkCreateProducts(result.items);
      ref.refreshData.inventory();
      messenger.showSnackBar(
        SnackBar(content: Text('Imported $inserted product${inserted == 1 ? '' : 's'}.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<bool?> _showImportPreview(String fileName, InventoryImportResult r) {
    final crm = context.crmColors;
    final sample = r.items.take(5).toList();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: crm.surface,
        title: const Text('Import stock'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName,
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                10.h,
                if (r.hasItems)
                  Text('${r.items.length} product${r.items.length == 1 ? '' : 's'} ready to import'
                      '${r.skipped > 0 ? ' · ${r.skipped} skipped' : ''}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: crm.textPrimary))
                else
                  Text('Nothing to import',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: crm.destructive)),
                for (final w in r.warnings) ...[
                  6.h,
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline, size: 14, color: crm.warning),
                    6.w,
                    Expanded(
                      child: Text(w,
                          style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ),
                  ]),
                ],
                if (sample.isNotEmpty) ...[
                  12.h,
                  Text('Preview',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: crm.textSecondary)),
                  6.h,
                  for (final it in sample)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${it['name']}'
                        '${it['brand'] != null ? ' · ${it['brand']}' : ''}'
                        '${it['quantity'] != null ? ' · qty ${it['quantity']}' : ''}'
                        '${it['price'] != null ? ' · ₹${it['price']}' : ''}',
                        style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (r.items.length > sample.length)
                    Text('…and ${r.items.length - sample.length} more',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
                12.h,
                Text(
                  'Expected columns (first row = header): ${kInventoryImportColumns.join(', ')}. '
                  'Only "name" is required.',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(r.hasItems ? 'Cancel' : 'Close'),
          ),
          if (r.hasItems)
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
              child: Text('Import ${r.items.length}',
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
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
        error: (e, _) => AppErrorView(
            error: e, onRetry: () => ref.invalidate(inventoryProductsProvider)),
        data: (products) => LayoutBuilder(builder: (context, box) {
          final width = box.maxWidth;
          final narrow = width < 640;
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
          }).toList();

          // Apply the chosen sort.
          int byName(InventoryProduct a, InventoryProduct b) =>
              invDisplayName(a)
                  .toLowerCase()
                  .compareTo(invDisplayName(b).toLowerCase());
          filtered.sort((a, b) {
            int r;
            switch (_sort) {
              case _StockSort.newest:
                r = _cmpDate(a.createdAt, b.createdAt, desc: true);
                break;
              case _StockSort.oldest:
                r = _cmpDate(a.createdAt, b.createdAt, desc: false);
                break;
              case _StockSort.nameAz:
                r = 0;
                break;
              case _StockSort.qtyLow:
                r = a.quantity.compareTo(b.quantity);
                break;
              case _StockSort.qtyHigh:
                r = b.quantity.compareTo(a.quantity);
                break;
              case _StockSort.valueHigh:
                r = (b.quantity * b.price).compareTo(a.quantity * a.price);
                break;
              case _StockSort.expirySoon:
                r = _cmpDate(a.expiry, b.expiry, desc: false);
                break;
            }
            return r != 0 ? r : byName(a, b);
          });

          // ── Metrics for the shown products ──
          final units = filtered.fold<int>(0, (a, p) => a + p.quantity);
          final value =
              filtered.fold<double>(0, (a, p) => a + p.quantity * p.price);
          final lowCount = filtered.where((p) => p.isLow).length;
          final outCount = filtered.where((p) => p.isOut).length;
          final expiring = filtered
              .where((p) =>
                  p.quantity > 0 &&
                  p.expiry != null &&
                  (daysLeft(p.expiry) ?? 999) <= 90)
              .length;
          final allocatedUnits =
              filtered.fold<int>(0, (a, p) => a + allocatedFor(p));

          // ── Pagination ──
          final total = filtered.length;
          final pages = total == 0 ? 1 : (total + _pageSize - 1) ~/ _pageSize;
          final page = _page.clamp(0, pages - 1);
          final start = page * _pageSize;
          final end = (start + _pageSize).clamp(0, total);
          final pageItems =
              total == 0 ? const <InventoryProduct>[] : filtered.sublist(start, end);

          final cols = width < 520
              ? 1
              : width < 780
                  ? 2
                  : width < 1100
                      ? 3
                      : width < 1420
                          ? 4
                          : 5;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(inventoryProductsProvider);
              ref.invalidate(staffKitsProvider);
              try {
                await ref.read(inventoryProductsProvider.future);
              } catch (_) {
                // Failure is shown by the screen's error state; don't throw from pull-to-refresh.
              }
            },
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(crm, products.length),
                      16.h,
                      InvKpiGrid(width: width, stats: [
                        InvKpi(
                            '$total',
                            'Products Shown',
                            total == products.length
                                ? 'all products'
                                : 'of ${products.length} total',
                            Icons.inventory_2_outlined,
                            crm.primary),
                        InvKpi(
                            '$units',
                            'Units in Stock',
                            allocatedUnits > 0
                                ? '$allocatedUnits allocated to kits'
                                : 'across shown products',
                            Icons.layers_outlined,
                            crm.accent),
                        InvKpi(fmtINR(value), 'Stock Value', 'qty × unit price',
                            Icons.currency_rupee_rounded,
                            const Color(0xFF6E1423)),
                        InvKpi('$lowCount', 'Low Stock',
                            'at or below reorder level',
                            Icons.trending_down_rounded, kLowStockColor),
                        InvKpi('$outCount', 'Out of Stock', 'need restocking',
                            Icons.remove_shopping_cart_outlined,
                            crm.destructive),
                        InvKpi('$expiring', 'Expiring Soon', 'within 90 days',
                            Icons.hourglass_bottom_rounded, crm.warning),
                      ]),
                      16.h,
                      _toolbar(crm, narrow, allCount, kitCount, availCount),
                      16.h,
                      if (total > 0)
                        Padding(
                          key: _gridTopKey,
                          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Showing ${start + 1}–$end of $total'
                                  ' product${total == 1 ? '' : 's'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: crm.textSecondary),
                                ),
                              ),
                              if (pages > 1)
                                Text('Page ${page + 1} of $pages',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: crm.textSecondary)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (total == 0)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: InvEmpty(
                          icon: Icons.inventory_2_outlined,
                          title: _view == StockView.kits
                              ? 'Nothing allocated to kits'
                              : 'No products found',
                          subtitle: _view == StockView.kits
                              ? 'Products added to staff kits appear here.'
                              : 'Try a different search, or add a product.'),
                    ),
                  )
                else ...[
                  SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: _cardHeight,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final p = pageItems[i];
                        return _StockCard(
                          key: ValueKey(p.id),
                          product: p,
                          view: _view,
                          allocated: allocatedFor(p),
                          onEdit: () =>
                              showProductDialog(context, ref, product: p),
                          onDelete: () => _delete(p),
                        );
                      },
                      childCount: pageItems.length,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _pagination(
                        crm, narrow, page, pages, start, end, total),
                  ),
                ],
                SliverToBoxAdapter(child: 24.h),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header(CrmTheme crm, int productCount) {
    ButtonStyle tonal() => IconButton.styleFrom(
          foregroundColor: crm.primary,
          backgroundColor: crm.primary.withValues(alpha: 0.10),
          minimumSize: const Size(40, 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
    return InvHeader(
      title: 'Stock List',
      subtitle:
          '$productCount product${productCount == 1 ? '' : 's'} · sorted by ${_sortLabel(_sort).toLowerCase()}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _importStock,
            icon: const Icon(Icons.upload_file, size: 22),
            tooltip: 'Import stock from Excel / CSV',
            style: tonal(),
          ),
          8.w,
          IconButton(
            onPressed: _scanCheck,
            icon: const Icon(Icons.qr_code_scanner, size: 22),
            tooltip: 'Scan to check stock',
            style: tonal(),
          ),
        ],
      ),
      actionLabel: 'Add',
      onAction: () => showProductDialog(context, ref),
    );
  }

  // ── Toolbar: search, sort, category chips, view segments ─────────────────

  Widget _toolbar(
      CrmTheme crm, bool narrow, int allCount, int kitCount, int availCount) {
    final search = Container(
      height: 44,
      decoration: BoxDecoration(
          color: crm.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border)),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => _update(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search name, brand or shade...',
          hintStyle: TextStyle(fontSize: 13.5, color: crm.textSecondary),
          prefixIcon: Icon(Icons.search, size: 19, color: crm.textSecondary),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: crm.textSecondary),
                  onPressed: () {
                    _searchCtrl.clear();
                    _update(() => _search = '');
                  },
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
        style: TextStyle(fontSize: 13.5, color: crm.textPrimary),
      ),
    );

    final sort = Container(
      height: 44,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
          color: crm.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border)),
      child: Row(
        children: [
          Icon(Icons.sort_rounded, size: 18, color: crm.textSecondary),
          8.w,
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_StockSort>(
                value: _sort,
                isDense: true,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: crm.surface,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: crm.textPrimary),
                items: [
                  for (final s in _StockSort.values)
                    DropdownMenuItem(
                        value: s,
                        child: Text(_sortLabel(s),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  if (v != null) _update(() => _sort = v);
                },
              ),
            ),
          ),
        ],
      ),
    );

    return InvCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (narrow) ...[
            search,
            10.h,
            sort,
          ] else
            Row(
              children: [
                Expanded(child: search),
                10.w,
                SizedBox(width: 230, child: sort),
              ],
            ),
          12.h,
          // ── Category chips ──
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _catChip(crm, 'All', null),
                for (final c in InventoryProduct.categories)
                  _catChip(crm, c, categoryColor(c)),
              ],
            ),
          ),
          12.h,
          // ── Complete stock / In kits / Remaining ──
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
        ],
      ),
    );
  }

  Widget _catChip(CrmTheme crm, String label, Color? dot) {
    final selected = _cat == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _update(() => _cat = label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? crm.primary : crm.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? crm.primary : crm.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: selected ? Colors.white : dot,
                        shape: BoxShape.circle),
                  ),
                  6.w,
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : crm.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _seg(CrmTheme crm, String label, int count, StockView view) {
    final selected = _view == view;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _update(() => _view = view),
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

  // ── Pagination ────────────────────────────────────────────────────────────

  /// A single rounded bar: "Prev · 1 2 … 7 · Next", with the current page
  /// marked by colour + underline rather than boxed buttons, plus a thin
  /// progress line showing how far through the list the user is.
  Widget _pagination(CrmTheme crm, bool narrow, int page, int pages, int start,
      int end, int total) {
    final info = Text(
      'Showing ${start + 1}–$end of $total',
      style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: crm.textSecondary),
    );
    if (pages <= 1) {
      return Padding(
          padding: const EdgeInsets.only(top: 16), child: Center(child: info));
    }

    // Page numbers to show; null = ellipsis gap.
    final shown = <int>{0, pages - 1, page - 1, page, page + 1}
        .where((i) => i >= 0 && i < pages)
        .toList()
      ..sort();
    final entries = <int?>[];
    for (final i in shown) {
      if (entries.isNotEmpty && entries.last != null && i - entries.last! > 1) {
        entries.add(null);
      }
      entries.add(i);
    }

    Widget step(String label, IconData icon, int? target, {bool trailing = false}) {
      final enabled = target != null;
      final color =
          enabled ? crm.primary : crm.textSecondary.withValues(alpha: 0.4);
      final ic = Icon(icon, size: 18, color: color);
      return InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: enabled ? () => _goToPage(target) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!trailing) ic,
            if (!narrow) ...[
              if (!trailing) 2.w,
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color)),
              if (trailing) 2.w,
            ],
            if (trailing) ic,
          ]),
        ),
      );
    }

    Widget number(int i) {
      final selected = i == page;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : () => _goToPage(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${i + 1}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? crm.primary : crm.textSecondary)),
              3.h,
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2.5,
                width: selected ? 14 : 0,
                decoration: BoxDecoration(
                    color: crm.primary,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ],
          ),
        ),
      );
    }

    Widget divider() => Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: crm.border);

    final bar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: crm.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          step('Prev', Icons.chevron_left_rounded,
              page > 0 ? page - 1 : null),
          divider(),
          if (narrow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${page + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: crm.primary)),
                TextSpan(
                    text: ' / $pages',
                    style: TextStyle(color: crm.textSecondary)),
              ]), style: const TextStyle(fontSize: 13)),
            )
          else
            for (final e in entries)
              e == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text('…',
                          style: TextStyle(color: crm.textSecondary)))
                  : number(e),
          divider(),
          step('Next', Icons.chevron_right_rounded,
              page < pages - 1 ? page + 1 : null,
              trailing: true),
        ],
      ),
    );

    final progress = SizedBox(
      width: narrow ? 160 : 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: end / total,
          minHeight: 3,
          backgroundColor: crm.input,
          valueColor: AlwaysStoppedAnimation(crm.primary),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 4),
      child: Column(
        children: [
          bar,
          12.h,
          info,
          6.h,
          progress,
        ],
      ),
    );
  }
}

// ── Product card ─────────────────────────────────────────────────────────────

class _StockCard extends StatelessWidget {
  final InventoryProduct product;
  final StockView view;
  final int allocated;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StockCard({
    super.key,
    required this.product,
    required this.view,
    required this.allocated,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final p = product;
    final remaining = (p.quantity - allocated).clamp(0, p.quantity);
    final catColor = categoryColor(p.category);

    final noneLeft = view == StockView.remaining && remaining == 0;
    final flagged = p.isOut || p.isLow || noneLeft;
    final tint = (p.isOut || noneLeft) ? crm.destructive : kLowStockColor;
    final qtyColor = p.isOut
        ? crm.destructive
        : (p.isLow ? kLowStockColor : crm.textPrimary);

    // Headline metric depends on the active view.
    final String bigValue;
    final String bigCaption;
    final Color bigColor;
    switch (view) {
      case StockView.all:
        bigValue = '${p.quantity}';
        bigCaption = p.quantity == 1 ? 'unit in stock' : 'units in stock';
        bigColor = qtyColor;
        break;
      case StockView.kits:
        bigValue = '$allocated';
        bigCaption = 'of ${p.quantity} in kits';
        bigColor = crm.accent;
        break;
      case StockView.remaining:
        bigValue = '$remaining';
        bigCaption = allocated > 0 ? 'left · $allocated in kits' : 'available';
        bigColor = remaining == 0 ? crm.destructive : crm.success;
        break;
    }

    // Expiry line.
    final dl = daysLeft(p.expiry);
    final expWarn = dl != null && dl <= 90;
    final expColor = dl != null && dl < 0
        ? crm.destructive
        : (expWarn ? crm.warning : crm.textSecondary);
    final expText = p.expiry == null
        ? 'No expiry date'
        : dl! < 0
            ? 'Expired · ${fmtExp(p.expiry)}'
            : expWarn
                ? 'Exp ${fmtExp(p.expiry)} · ${dl}d left'
                : 'Exp ${fmtExp(p.expiry)}';

    return Material(
      color: flagged
          ? Color.alphaBlend(tint.withValues(alpha: 0.05), crm.surface)
          : crm.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: flagged ? tint.withValues(alpha: 0.38) : crm.border),
      ),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11)),
                    child: Icon(productIcon(p.category),
                        color: catColor, size: 20),
                  ),
                  10.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invDisplayName(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: crm.textPrimary)),
                        2.h,
                        Text(p.brand.isEmpty ? '—' : p.brand,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      tooltip: 'More',
                      icon: Icon(Icons.more_vert,
                          size: 18, color: crm.textSecondary),
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
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
                              Icon(Icons.delete,
                                  size: 16, color: crm.destructive),
                              const SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: crm.destructive))
                            ])),
                      ],
                    ),
                  ),
                ],
              ),
              10.h,
              // ── Category + status ──
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(p.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: catColor)),
                      ),
                    ),
                    6.w,
                    StockPill(product: p),
                  ],
                ),
              ),
              12.h,
              // ── Quantity + price / value ──
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(bigValue,
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: bigColor,
                                    height: 1.0)),
                          ),
                          4.h,
                          Text(bigCaption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                    8.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _kv(crm, 'Price', fmtINR(p.price)),
                          4.h,
                          _kv(crm, 'Value', fmtINR(p.quantity * p.price)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              10.h,
              // ── Expiry ──
              Row(
                children: [
                  Icon(
                      expWarn
                          ? Icons.hourglass_bottom_rounded
                          : Icons.event_outlined,
                      size: 13,
                      color: expColor),
                  5.w,
                  Expanded(
                    child: Text(expText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                expWarn ? FontWeight.w700 : FontWeight.w500,
                            color: expColor)),
                  ),
                ],
              ),
              const Spacer(),
              // ── Gauge / allocation bar ──
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: view == StockView.all
                    ? TubeGauge(
                        quantity: p.quantity, fillLevel: p.fillLevel, height: 8)
                    : _allocationBar(crm, p, remaining),
              ),
              10.h,
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(height: 1, color: crm.border),
              ),
              8.h,
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 12, color: crm.textSecondary),
                  5.w,
                  Expanded(
                    child: Text(
                        p.createdAt != null
                            ? 'Added ${fmtAdded(p.createdAt)}'
                            : 'Added date unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5, color: crm.textSecondary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(CrmTheme crm, String label, String value) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$label ',
              style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          TextSpan(
              text: value,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: crm.textPrimary)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
      );

  /// Kits / remaining views: share of stock allocated vs left.
  Widget _allocationBar(CrmTheme crm, InventoryProduct p, int remaining) {
    final isKits = view == StockView.kits;
    final shown = isKits ? allocated : remaining;
    final frac =
        p.quantity <= 0 ? 0.0 : (shown / p.quantity).clamp(0.0, 1.0).toDouble();
    final color = isKits
        ? crm.accent
        : (remaining == 0 ? crm.destructive : crm.success);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                  '${(frac * 100).round()}% ${isKits ? 'allocated' : 'available'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            ),
            Text('$shown / ${p.quantity}',
                style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          ],
        ),
        4.h,
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 8,
            color: color,
            backgroundColor: crm.input,
          ),
        ),
      ],
    );
  }
}
