import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_chrome.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_search_field.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';

String _money(num v) => NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 0)
    .format(v);

/// Finance → Inventory Valuation. Current stock value = Σ(quantity × unit
/// price) with low-/out-of-stock counts. A snapshot report (no date range).
class InventoryValuationScreen extends ConsumerStatefulWidget {
  const InventoryValuationScreen({super.key});

  @override
  ConsumerState<InventoryValuationScreen> createState() =>
      _InventoryValuationScreenState();
}

class _InventoryValuationScreenState
    extends ConsumerState<InventoryValuationScreen> {
  String _search = '';

  bool _matches(InventoryProduct p) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${p.name} ${p.brand} ${p.shade} ${p.category} ${p.barcode}'
        .toLowerCase()
        .contains(q);
  }

  double _value(InventoryProduct p) => p.quantity * p.price;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(inventoryProductsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: ReportChrome(
        category: 'Business Overview',
        title: 'Inventory Valuation',
        preset: DateRangePreset.allTime,
        onPreset: (_) {},
        asOf: true,
        to: DateTime.now(),
        onExport:
            async.hasValue ? () => _exportCsv(context, async.value!) : null,
        onRefresh: () async => ref.invalidate(inventoryProductsProvider),
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(inventoryProductsProvider),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(friendlyErrorMessage(e),
                      style: TextStyle(color: crm.destructive)),
                ),
              ),
            ]),
            data: (all) {
              if (all.isEmpty) {
                return ListView(children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 56, color: crm.border),
                          12.h,
                          Text('No inventory yet',
                              style: TextStyle(color: crm.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ]);
              }
              final totalValue =
                  all.fold<double>(0, (s, p) => s + _value(p));
              final totalUnits = all.fold<int>(0, (s, p) => s + p.quantity);
              final outCount = all.where((p) => p.quantity <= 0).length;
              final lowCount = all
                  .where((p) =>
                      p.quantity > 0 && p.quantity <= p.lowStockThreshold)
                  .length;
              final products = all.where(_matches).toList()
                ..sort((a, b) => _value(b).compareTo(_value(a)));

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  ReportTitleBlock(
                      title: 'Inventory Valuation',
                      asOf: true,
                      to: DateTime.now()),
                  ReportSearchField(
                    hint: 'Search a product…',
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  12.h,
                  Row(children: [
                    Expanded(
                        child: _stat(crm, 'Stock Value', _money(totalValue),
                            crm.primary)),
                    8.w,
                    Expanded(
                        child: _stat(
                            crm, 'Units', '$totalUnits', crm.textPrimary)),
                    8.w,
                    Expanded(
                        child: _stat(crm, 'Low', '$lowCount', crm.warning)),
                    8.w,
                    Expanded(
                        child:
                            _stat(crm, 'Out', '$outCount', crm.destructive)),
                  ]),
                  14.h,
                  _table(context, crm, products, totalValue),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stat(CrmTheme crm, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, CrmTheme crm,
      List<InventoryProduct> products, double totalValue) {
    TextStyle head() => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: crm.textSecondary,
        letterSpacing: 0.4);
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(children: [
              Expanded(flex: 5, child: Text('PRODUCT', style: head())),
              Expanded(
                  flex: 2,
                  child: Text('QTY', textAlign: TextAlign.right, style: head())),
              Expanded(
                  flex: 3,
                  child:
                      Text('UNIT ₹', textAlign: TextAlign.right, style: head())),
              Expanded(
                  flex: 3,
                  child:
                      Text('VALUE', textAlign: TextAlign.right, style: head())),
            ]),
          ),
          Divider(height: 1, color: crm.border),
          for (final p in products)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name.isEmpty ? '(Unnamed)' : p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: crm.textPrimary)),
                      if ('${p.brand} ${p.shade}'.trim().isNotEmpty)
                        Text('${p.brand} ${p.shade}'.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: crm.textSecondary)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text('${p.quantity}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.quantity <= 0
                              ? crm.destructive
                              : (p.quantity <= p.lowStockThreshold
                                  ? crm.warning
                                  : crm.textPrimary))),
                ),
                Expanded(
                  flex: 3,
                  child: Text(_money(p.price),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, color: crm.textSecondary)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(_money(_value(p)),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          Divider(height: 1, color: crm.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Text('TOTAL STOCK VALUE',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary)),
              ),
              Text(_money(totalValue),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: crm.primary)),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(
      BuildContext context, List<InventoryProduct> all) async {
    final sorted = [...all]..sort((a, b) => _value(b).compareTo(_value(a)));
    final total = all.fold<double>(0, (s, p) => s + _value(p));
    final rows = <List<Object?>>[
      ['Inventory Valuation'],
      ['Product', 'Brand', 'Shade', 'Category', 'Quantity', 'Unit Price', 'Value'],
      for (final p in sorted)
        [
          p.name,
          p.brand,
          p.shade,
          p.category,
          p.quantity,
          csvNum(p.price),
          csvNum(_value(p)),
        ],
      ['', '', '', '', '', 'TOTAL', csvNum(total)],
    ];
    try {
      await downloadCsv('inventory_valuation.csv', rows);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inventory valuation exported')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }
}
