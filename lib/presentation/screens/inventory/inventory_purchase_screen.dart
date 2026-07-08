import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/inventory_product.dart';
import '../../../core/models/purchase.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../services/inventory_service.dart';
import 'barcode_scanner_page.dart';
import 'inventory_widgets.dart';

/// New Purchase composer — scan or type a barcode to add items, adjust
/// quantities and cost, then save. Saving increments studio stock.
class InventoryPurchaseScreen extends ConsumerStatefulWidget {
  const InventoryPurchaseScreen({super.key});

  @override
  ConsumerState<InventoryPurchaseScreen> createState() =>
      _InventoryPurchaseScreenState();
}

class _InventoryPurchaseScreenState
    extends ConsumerState<InventoryPurchaseScreen> {
  final _supplierCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();
  DateTime _date = DateTime.now();
  final List<PurchaseItem> _items = [];
  bool _paid = false;
  bool _saving = false;
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    // Autofocus so a USB / keyboard-wedge scanner types straight in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _invoiceCtrl.dispose();
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0, (a, i) => a + i.subtotal);

  void _addOrIncrement(PurchaseItem item) {
    final idx = _items.indexWhere((e) =>
        (item.productId.isNotEmpty && e.productId == item.productId) ||
        (item.barcode.isNotEmpty && e.barcode == item.barcode));
    setState(() {
      if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity + item.quantity);
      } else {
        _items.add(item);
      }
    });
  }

  Future<void> _handleBarcode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) return;
    _barcodeCtrl.clear();
    setState(() => _looking = true);
    try {
      final found = await ref.read(inventoryServiceProvider).lookupBarcode(code);
      if (!mounted) return;
      if (found != null) {
        _addOrIncrement(PurchaseItem(
          productId: found.id,
          name: found.name,
          brand: found.brand,
          shade: found.shade,
          barcode: code,
          category: found.category,
          quantity: 1,
          unitCost: found.price,
        ));
      } else {
        // Unknown barcode → enrich from public product databases (Open Beauty
        // Facts / UPCitemdb), then open a prefilled line.
        ExternalProduct? ext;
        try {
          ext = await ref.read(inventoryServiceProvider).lookupExternal(code);
        } catch (e) {
          // Real failure (couldn't reach the lookup service) — tell the user.
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$e')));
          }
        }
        if (!mounted) return;
        final item = await _lineDialog(
          barcode: code,
          initialName: ext?.name,
          initialBrand: ext?.brand,
          fromExternal: ext != null,
          lookupTried: true,
        );
        if (item != null) _addOrIncrement(item);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _looking = false);
        _barcodeFocus.requestFocus();
      }
    }
  }

  Future<void> _scanCamera() async {
    final code = await scanBarcode(context);
    if (code != null) _handleBarcode(code);
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(inventoryServiceProvider).createPurchase(
            supplier: _supplierCtrl.text.trim(),
            invoiceNo: _invoiceCtrl.text.trim(),
            date: _date,
            items: _items,
            paid: _paid,
          );
      ref.invalidate(inventoryProductsProvider);
      ref.invalidate(purchasesProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase saved to ledger')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                // ── Supplier / invoice / date ──────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _supplierCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Supplier'),
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: TextField(
                        controller: _invoiceCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Invoice #'),
                      ),
                    ),
                  ],
                ),
                12.h,
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Purchase date',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(DateFormat('d MMM yyyy').format(_date)),
                  ),
                ),
                12.h,
                // ── Payment status ─────────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 18, color: crm.textSecondary),
                    8.w,
                    Text('Payment',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: crm.textSecondary)),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Not Paid'),
                      selected: !_paid,
                      onSelected: (_) => setState(() => _paid = false),
                    ),
                    8.w,
                    ChoiceChip(
                      label: const Text('Paid'),
                      selected: _paid,
                      selectedColor: crm.success.withValues(alpha: 0.18),
                      onSelected: (_) => setState(() => _paid = true),
                    ),
                  ],
                ),
                16.h,
                // ── Scan / type barcode ────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeCtrl,
                        focusNode: _barcodeFocus,
                        onSubmitted: _handleBarcode,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Scan or type barcode',
                          prefixIcon: const Icon(Icons.qr_code_2_outlined),
                          suffixIcon: _looking
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.arrow_forward),
                                  onPressed: () =>
                                      _handleBarcode(_barcodeCtrl.text),
                                ),
                        ),
                      ),
                    ),
                    10.w,
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _scanCamera,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: const Text('Scan'),
                      ),
                    ),
                  ],
                ),
                8.h,
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final item = await _lineDialog();
                      if (item != null) _addOrIncrement(item);
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add item manually'),
                  ),
                ),
                16.h,
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.qr_code_scanner,
                              size: 46,
                              color: crm.textSecondary.withValues(alpha: 0.4)),
                          10.h,
                          Text('Scan a product to start',
                              style: TextStyle(color: crm.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < _items.length; i++) _line(crm, i),
              ],
            ),
          ),
          // ── Footer: total + save ─────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: crm.surface,
              border: Border(top: BorderSide(color: crm.border)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_items.length} items · ${_items.fold<int>(0, (a, i) => a + i.quantity)} units',
                        style:
                            TextStyle(fontSize: 12, color: crm.textSecondary)),
                    Text(fmtINR(_total),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
                const Spacer(),
                FilledButton(
                  onPressed: (_saving || _items.isEmpty) ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 48),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Save Purchase'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(CrmTheme crm, int i) {
    final it = _items[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: categoryColor(it.category).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(productIcon(it.category),
                    color: categoryColor(it.category), size: 20),
              ),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        it.shade.isNotEmpty && it.shade != '—'
                            ? '${it.name} · ${it.shade}'
                            : it.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    2.h,
                    Text(
                        it.stockIn
                            ? '${it.brand.isEmpty ? it.category : it.brand} · ${fmtINR(it.unitCost)}/unit'
                            : '${it.category} · ${fmtINR(it.unitCost)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              if (!it.stockIn) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: crm.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('EXPENSE',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: crm.accent)),
                ),
                6.w,
              ],
              IconButton(
                icon: Icon(Icons.close, size: 18, color: crm.destructive),
                onPressed: () => setState(() => _items.removeAt(i)),
              ),
            ],
          ),
          8.h,
          Row(
            children: [
              _qtyBtn(crm, Icons.remove, () {
                if (it.quantity > 1) {
                  setState(() =>
                      _items[i] = it.copyWith(quantity: it.quantity - 1));
                }
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('${it.quantity}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              _qtyBtn(crm, Icons.add, () {
                setState(
                    () => _items[i] = it.copyWith(quantity: it.quantity + 1));
              }),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final edited = await _lineDialog(existing: it);
                  if (edited != null) {
                    setState(() => _items[i] = edited);
                  }
                },
                child: const Text('Edit cost'),
              ),
              8.w,
              Text(fmtINR(it.subtotal),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(CrmTheme crm, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: crm.input,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: crm.textPrimary),
      ),
    );
  }

  /// Add / edit a purchase line (name, brand, shade, category, qty, cost).
  /// [initialName]/[initialBrand] seed a new line from a public-database match.
  Future<PurchaseItem?> _lineDialog({
    String? barcode,
    PurchaseItem? existing,
    String? initialName,
    String? initialBrand,
    bool fromExternal = false,
    bool lookupTried = false,
  }) {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? initialName ?? '');
    final brandCtrl =
        TextEditingController(text: existing?.brand ?? initialBrand ?? '');
    final shadeCtrl = TextEditingController(text: existing?.shade ?? '');
    final qtyCtrl =
        TextEditingController(text: '${existing?.quantity ?? 1}');
    final costCtrl = TextEditingController(
        text: existing != null && existing.unitCost > 0
            ? existing.unitCost.toStringAsFixed(0)
            : '');
    var stockIn = existing?.stockIn ?? true;
    var category = existing?.category ?? 'Prep';
    if (!InventoryProduct.categories.contains(category)) category = 'Prep';
    final catCtrl = TextEditingController(
        text: (existing != null && !existing.stockIn) ? existing.category : '');
    final code = barcode ?? existing?.barcode ?? '';

    return showDialog<PurchaseItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add Item' : 'Edit Item'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (code.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        const Icon(Icons.qr_code_2_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text('Barcode: $code',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  if (fromExternal)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Icon(Icons.cloud_done_outlined,
                            size: 14, color: ctx.crmColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              'Auto-filled from public product database — review the details.',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: ctx.crmColors.primary)),
                        ),
                      ]),
                    ),
                  if (lookupTried && !fromExternal && code.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Icon(Icons.search_off_outlined,
                            size: 14, color: ctx.crmColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              'No public data for this barcode — enter the details (it will be saved for next time).',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: ctx.crmColors.textSecondary)),
                        ),
                      ]),
                    ),
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Product *')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: brandCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Brand'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: shadeCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Shade'))),
                  ]),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: stockIn,
                    onChanged: (v) => setLocal(() => stockIn = v),
                    title: const Text('Adds to stock',
                        style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                        stockIn
                            ? 'Creates / restocks an inventory product'
                            : 'Expense-only — ledgered, not stocked',
                        style: const TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Qty')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText:
                                  stockIn ? 'Unit cost (₹)' : 'Amount (₹)')),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (stockIn)
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final c in InventoryProduct.categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) =>
                          setLocal(() => category = v ?? category),
                    )
                  else
                    TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Category (e.g. Software, Rent)'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  PurchaseItem(
                    productId: stockIn ? (existing?.productId ?? '') : '',
                    name: nameCtrl.text.trim(),
                    brand: brandCtrl.text.trim(),
                    shade: shadeCtrl.text.trim(),
                    barcode: code,
                    category: stockIn
                        ? category
                        : (catCtrl.text.trim().isEmpty
                            ? 'Other'
                            : catCtrl.text.trim()),
                    quantity: int.tryParse(qtyCtrl.text.trim()) ?? 1,
                    unitCost: double.tryParse(costCtrl.text.trim()) ?? 0,
                    stockIn: stockIn,
                  ),
                );
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
