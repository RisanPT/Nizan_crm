import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/inventory_product.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../services/inventory_service.dart';
import 'barcode_scanner_page.dart';
import 'inventory_widgets.dart';

/// Add / edit a single inventory product. Used by Stock List and by the
/// artist "My Inventory" screen.
Future<void> showProductDialog(
  BuildContext context,
  WidgetRef ref, {
  InventoryProduct? product,
  String? initialBarcode,
}) async {
  final crm = context.crmColors;
  final nameCtrl = TextEditingController(text: product?.name ?? '');
  final brandCtrl = TextEditingController(text: product?.brand ?? '');
  final shadeCtrl = TextEditingController(text: product?.shade ?? '');
  final qtyCtrl =
      TextEditingController(text: product != null ? '${product.quantity}' : '');
  final priceCtrl = TextEditingController(
      text: product != null && product.price > 0
          ? product.price.toStringAsFixed(0)
          : '');
  final barcodeCtrl =
      TextEditingController(text: product?.barcode ?? initialBarcode ?? '');
  final fillCtrl =
      TextEditingController(text: '${product?.fillLevel ?? 100}');
  final usageCtrl =
      TextEditingController(text: '${product?.usagePerWork ?? 10}');
  var category = product?.category ?? 'Prep';
  if (!InventoryProduct.categories.contains(category)) category = 'Prep';
  DateTime? expiry = product?.expiry;
  var saving = false;
  // Tracks the product being edited — set automatically when a scanned barcode
  // matches an existing product (so a re-scan updates it, not creates a dupe).
  var editing = product;
  var looking = false;
  String? lookupNote;
  String? externalImage; // thumbnail from a public-database match

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        // Resolve a barcode → if it exists, load it into the form as an edit.
        Future<void> lookup(String rawCode) async {
          final code = rawCode.trim();
          if (code.isEmpty || editing != null) return;
          setState(() {
            looking = true;
            lookupNote = null;
          });
          try {
            final found =
                await ref.read(inventoryServiceProvider).lookupBarcode(code);
            if (found != null) {
              editing = found;
              nameCtrl.text = found.name;
              brandCtrl.text = found.brand;
              shadeCtrl.text = found.shade;
              qtyCtrl.text = '${found.quantity}';
              fillCtrl.text = '${found.fillLevel}';
              usageCtrl.text = '${found.usagePerWork}';
              priceCtrl.text =
                  found.price > 0 ? found.price.toStringAsFixed(0) : '';
              if (InventoryProduct.categories.contains(found.category)) {
                category = found.category;
              }
              expiry = found.expiry;
              lookupNote = 'existing';
            } else {
              lookupNote = 'new';
              // Not in our inventory — try public product databases to prefill
              // the brand/name so the artist/manager doesn't type it manually.
              // Best-effort: a lookup failure keeps the plain "new barcode" note.
              try {
                final ext = await ref
                    .read(inventoryServiceProvider)
                    .lookupExternal(code);
                if (ext != null) {
                  if (nameCtrl.text.trim().isEmpty && ext.name.isNotEmpty) {
                    nameCtrl.text = ext.name;
                  }
                  if (brandCtrl.text.trim().isEmpty && ext.brand.isNotEmpty) {
                    brandCtrl.text = ext.brand;
                  }
                  externalImage = ext.imageUrl.isNotEmpty ? ext.imageUrl : null;
                  lookupNote = 'external';
                }
              } catch (_) {
                // keep 'new'
              }
            }
          } catch (_) {
            lookupNote = null;
          }
          setState(() => looking = false);
        }

        return AlertDialog(
        title: Text(editing == null ? 'Add Product' : 'Edit Product'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Existing-product summary — shown after a scan matches a
                // product already in stock.
                if (editing != null) ...[
                  _existingProductCard(crm, editing!),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Product Name *'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: brandCtrl,
                        decoration: const InputDecoration(labelText: 'Brand'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: shadeCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Shade / Variant'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Quantity'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Price (₹)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fillCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tube fill %',
                          helperText: '100 = full',
                          suffixText: '%',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: usageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Use per work',
                          helperText: '% used / job',
                          suffixText: '%',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: barcodeCtrl,
                  onSubmitted: lookup,
                  decoration: InputDecoration(
                    labelText: 'Barcode (scan to auto-fill)',
                    prefixIcon: const Icon(Icons.qr_code_2_outlined),
                    suffixIcon: looking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.photo_camera_outlined),
                            tooltip: 'Scan',
                            onPressed: () async {
                              final code = await scanBarcode(context);
                              if (code != null) {
                                setState(() => barcodeCtrl.text = code);
                                await lookup(code);
                              }
                            },
                          ),
                  ),
                ),
                if (lookupNote == 'existing')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Icon(Icons.check_circle, size: 14, color: crm.success),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            'Existing product found — saving will update it.',
                            style: TextStyle(
                                fontSize: 11.5, color: crm.success)),
                      ),
                    ]),
                  ),
                if (lookupNote == 'new')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          size: 14, color: crm.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            'New barcode — fill in details to register it.',
                            style: TextStyle(
                                fontSize: 11.5, color: crm.textSecondary)),
                      ),
                    ]),
                  ),
                if (lookupNote == 'external')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      if (externalImage != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              externalImage!,
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      Icon(Icons.cloud_done_outlined,
                          size: 14, color: crm.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            'Auto-filled from public product database — review & save.',
                            style:
                                TextStyle(fontSize: 11.5, color: crm.primary)),
                      ),
                    ]),
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in InventoryProduct.categories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => category = v ?? category),
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: expiry ?? DateTime(now.year, now.month + 6),
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 6),
                      helpText: 'Select expiry',
                    );
                    if (picked != null) setState(() => expiry = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expiry (optional)',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Row(
                      children: [
                        Text(
                          expiry == null
                              ? 'No expiry'
                              : DateFormat('MMM yyyy').format(expiry!),
                          style: TextStyle(
                              color: expiry == null
                                  ? crm.textSecondary
                                  : crm.textPrimary),
                        ),
                        const Spacer(),
                        if (expiry != null)
                          GestureDetector(
                            onTap: () => setState(() => expiry = null),
                            child:
                                Icon(Icons.clear, size: 18, color: crm.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                saving ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() => saving = true);
                    try {
                      await ref.read(inventoryServiceProvider).saveProduct(
                            id: editing?.id,
                            name: nameCtrl.text.trim(),
                            brand: brandCtrl.text.trim(),
                            shade: shadeCtrl.text.trim(),
                            quantity: int.tryParse(qtyCtrl.text.trim()) ?? 0,
                            price:
                                double.tryParse(priceCtrl.text.trim()) ?? 0,
                            category: category,
                            productType: editing?.productType ?? '',
                            barcode: barcodeCtrl.text.trim(),
                            fillLevel:
                                int.tryParse(fillCtrl.text.trim()) ?? 100,
                            usagePerWork:
                                int.tryParse(usageCtrl.text.trim()) ?? 10,
                            expiry: expiry,
                          );
                      ref.invalidate(inventoryProductsProvider);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (e) {
                      setState(() => saving = false);
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
        );
      },
    ),
  );
}

/// Compact summary of an already-in-stock product, shown when a scan matches.
Widget _existingProductCard(CrmTheme crm, InventoryProduct p) {
  final qtyColor =
      p.isOut ? crm.destructive : (p.isLow ? crm.warning : crm.success);

  Widget chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: crm.success.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: crm.success.withValues(alpha: 0.3)),
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
                  color: categoryColor(p.category), size: 22),
            ),
            const SizedBox(width: 12),
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
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(p.brand.isEmpty ? 'Existing product' : p.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: crm.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${p.quantity}',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: qtyColor)),
                Text('in stock',
                    style: TextStyle(fontSize: 10, color: crm.textSecondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            chip(fmtINR(p.price), crm.primary),
            chip(p.category, categoryColor(p.category)),
            if (p.expiry != null) chip('exp ${fmtExp(p.expiry)}', crm.warning),
            if (p.barcode.isNotEmpty) chip('#${p.barcode}', crm.textSecondary),
          ],
        ),
      ],
    ),
  );
}
