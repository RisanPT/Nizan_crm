import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';
import 'package:nizan_crm/features/inventory/data/purchase.dart';
import 'package:nizan_crm/features/inventory/data/vendor.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/inventory/services/inventory_service.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/services/upload_service.dart';
import 'barcode_scanner_page.dart';
import 'inventory_vendors_screen.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

const _gstRates = <double>[0, 5, 12, 18, 28];

String _pct(double r) => '${r.toStringAsFixed(r % 1 == 0 ? 0 : 1)}%';

/// New Purchase composer — pick a vendor, scan or type barcodes to add items,
/// adjust quantities and cost, add GST / payment details, then save. Saving
/// increments studio stock for stock-in lines.
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
  final _notesCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();
  final _picker = ImagePicker();
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  final List<PurchaseItem> _items = [];
  Vendor? _vendor;
  String? _billImage;
  bool _uploadingBill = false;
  bool _paid = false;
  bool _saving = false;
  bool _looking = false;
  // GST (input tax) on the vendor bill.
  bool _gstEnabled = false;
  double _gstRate = 18;
  bool _interState = false;

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
    _notesCtrl.dispose();
    _gstinCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  /// Taxable base — sum of all line items.
  double get _total => _items.fold(0, (a, i) => a + i.subtotal);
  int get _units => _items.fold<int>(0, (a, i) => a + i.quantity);
  double get _gstAmount => _gstEnabled ? _total * _gstRate / 100 : 0;
  double get _grandTotal => _total + _gstAmount;

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
            showErrorSnackBar(context, e);
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
        showErrorSnackBar(context, e);
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

  Future<void> _pickBill() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final XFile? img;
    try {
      img = await _picker.pickImage(source: source, imageQuality: 70);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e,
            fallback: 'Could not open the camera / gallery. Please try again.');
      }
      return;
    }
    if (img == null || !mounted) return;
    setState(() => _uploadingBill = true);
    try {
      final url = await ref.read(uploadServiceProvider).uploadImage(img);
      if (mounted) {
        setState(() {
          _billImage = url;
          _uploadingBill = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingBill = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(inventoryServiceProvider).createPurchase(
            supplier: _vendor?.name ?? _supplierCtrl.text.trim(),
            vendorId: _vendor?.id ?? '',
            invoiceNo: _invoiceCtrl.text.trim(),
            billImage: _billImage ?? '',
            date: _date,
            dueDate: _dueDate,
            items: _items,
            paid: _paid,
            notes: _notesCtrl.text.trim(),
            gstEnabled: _gstEnabled,
            gstin: _gstEnabled ? _gstinCtrl.text.trim() : '',
            gstRate: _gstEnabled ? _gstRate : 0,
            gstAmount: _gstAmount,
            interState: _gstEnabled && _interState,
          );
      ref.refreshData.purchases();
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase saved to ledger')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final vendors = ref.watch(vendorsProvider).value ?? const <Vendor>[];
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase')),
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 980;
        final pairs = box.maxWidth >= 600;
        final sections = <Widget>[
          _vendorSection(crm, vendors, pairs),
          16.h,
          _itemsSection(crm),
          16.h,
          invPair(!pairs, _taxSection(crm), _paymentSection(crm)),
          16.h,
          _notesSection(crm),
        ];

        if (wide) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 24),
                      children: sections,
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 20, 24, 24),
                      child: _summaryCard(crm, showSave: true),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  ...sections,
                  16.h,
                  _summaryCard(crm, showSave: false),
                ],
              ),
            ),
            _footer(crm),
          ],
        );
      }),
    );
  }

  /// Section card with an icon tile, title, optional subtitle and trailing.
  Widget _section(
    CrmTheme crm, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? color,
    required Widget child,
  }) {
    final c = color ?? crm.primary;
    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: c),
              ),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: invCardTitle(crm)),
                    if (subtitle != null) ...[
                      2.h,
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: crm.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[8.w, trailing],
            ],
          ),
          16.h,
          child,
        ],
      ),
    );
  }

  Widget _fieldPair(bool pairs, Widget a, Widget b) {
    if (!pairs) return Column(children: [a, 12.h, b]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: a), 12.w, Expanded(child: b)],
    );
  }

  Widget _datePickerField({
    required String label,
    required IconData icon,
    required DateTime? value,
    required String emptyText,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime?> onChanged,
    bool clearable = false,
    Color? valueColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: clearable && value != null
              ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(
          value == null ? emptyText : DateFormat('d MMM yyyy').format(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: valueColor),
        ),
      ),
    );
  }

  // ── 1. Vendor & bill details ──────────────────────────────────────────────

  Widget _vendorSection(CrmTheme crm, List<Vendor> vendors, bool pairs) {
    return _section(
      crm,
      icon: Icons.storefront_outlined,
      title: 'Vendor & Bill Details',
      subtitle: 'Who you bought from and the supplier invoice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Vendor>(
                  initialValue: _vendor,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vendor / Supplier',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  hint: Text(
                      vendors.isEmpty ? 'No vendors — tap +' : 'Select vendor'),
                  items: [
                    for (final v in vendors)
                      DropdownMenuItem(
                        value: v,
                        child: Text(v.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _vendor = v;
                    // Prefill the GSTIN from the vendor master when empty.
                    if (v != null &&
                        v.gstNumber.isNotEmpty &&
                        _gstinCtrl.text.trim().isEmpty) {
                      _gstinCtrl.text = v.gstNumber;
                    }
                  }),
                ),
              ),
              8.w,
              SizedBox(
                height: 52,
                child: IconButton.filledTonal(
                  onPressed: () => showVendorDialog(context, ref),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add vendor',
                ),
              ),
            ],
          ),
          if (_vendor != null &&
              (_vendor!.gstNumber.isNotEmpty || _vendor!.phone.isNotEmpty)) ...[
            8.h,
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_vendor!.gstNumber.isNotEmpty)
                  invBadge('GSTIN ${_vendor!.gstNumber}', crm.primary),
                if (_vendor!.phone.isNotEmpty)
                  invBadge(_vendor!.phone, crm.textSecondary),
              ],
            ),
          ],
          12.h,
          _fieldPair(
            pairs,
            TextField(
              controller: _invoiceCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Invoice #',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            _datePickerField(
              label: 'Purchase date',
              icon: Icons.event_outlined,
              value: _date,
              emptyText: '',
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              onChanged: (d) {
                if (d != null) setState(() => _date = d);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Line items ─────────────────────────────────────────────────────────

  Widget _itemsSection(CrmTheme crm) {
    return _section(
      crm,
      icon: Icons.inventory_2_outlined,
      title: 'Line Items',
      subtitle: 'Scan a barcode or add items manually',
      trailing: _items.isEmpty
          ? null
          : invBadge(
              '${_items.length} item${_items.length == 1 ? '' : 's'} · $_units unit${_units == 1 ? '' : 's'}',
              crm.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () => _handleBarcode(_barcodeCtrl.text),
                          ),
                  ),
                ),
              ),
              10.w,
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _scanCamera,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Scan'),
                ),
              ),
            ],
          ),
          8.h,
          TextButton.icon(
            onPressed: () async {
              final item = await _lineDialog();
              if (item != null) _addOrIncrement(item);
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add item manually'),
          ),
          8.h,
          if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: crm.input.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code_scanner,
                      size: 42, color: crm.textSecondary.withValues(alpha: 0.4)),
                  10.h,
                  Text('Scan a product to start',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: crm.textSecondary)),
                  4.h,
                  Text('Items you add appear here with quantity and cost.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: crm.textSecondary.withValues(alpha: 0.75))),
                ],
              ),
            )
          else
            for (var i = 0; i < _items.length; i++) _line(crm, i),
        ],
      ),
    );
  }

  /// Toggle a line between stock-in and expense-only, mirroring the rules of
  /// the line dialog (expense lines carry no product link; stock-in lines need
  /// an inventory category).
  Future<void> _toggleStockIn(int i, bool stockIn) async {
    final it = _items[i];
    if (stockIn == it.stockIn) return;
    if (!stockIn) {
      setState(() => _items[i] = PurchaseItem(
            productId: '',
            name: it.name,
            brand: it.brand,
            shade: it.shade,
            barcode: it.barcode,
            category: it.category,
            quantity: it.quantity,
            unitCost: it.unitCost,
            stockIn: false,
            expiry: it.expiry,
          ));
      return;
    }
    if (InventoryProduct.categories.contains(it.category)) {
      setState(() => _items[i] = it.copyWith(stockIn: true));
      return;
    }
    // Needs a valid inventory category — let the user pick one.
    final edited = await _lineDialog(existing: it.copyWith(stockIn: true));
    if (edited != null && mounted) setState(() => _items[i] = edited);
  }

  Widget _line(CrmTheme crm, int i) {
    final it = _items[i];
    final cat = categoryColor(it.category);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 10),
      decoration: BoxDecoration(
        color: it.stockIn
            ? crm.surface
            : crm.accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: it.stockIn
                ? crm.border
                : crm.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: cat.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(productIcon(it.category), color: cat, size: 20),
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
                        [
                          if (it.brand.isNotEmpty) it.brand,
                          it.category,
                          if (it.barcode.isNotEmpty) it.barcode,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              if (!it.stockIn) ...[
                6.w,
                invBadge('EXPENSE', crm.accent),
              ],
              IconButton(
                tooltip: 'Edit item',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined,
                    size: 18, color: crm.textSecondary),
                onPressed: () async {
                  final edited = await _lineDialog(existing: it);
                  if (edited != null) setState(() => _items[i] = edited);
                },
              ),
              IconButton(
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 18, color: crm.destructive),
                onPressed: () => setState(() => _items.removeAt(i)),
              ),
            ],
          ),
          10.h,
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                // Qty stepper
                Container(
                  decoration: BoxDecoration(
                    color: crm.input.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _qtyBtn(crm, Icons.remove, () {
                        if (it.quantity > 1) {
                          setState(() => _items[i] =
                              it.copyWith(quantity: it.quantity - 1));
                        }
                      }),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 34),
                        child: Text('${it.quantity}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                      _qtyBtn(crm, Icons.add, () {
                        setState(() => _items[i] =
                            it.copyWith(quantity: it.quantity + 1));
                      }),
                    ],
                  ),
                ),
                10.w,
                // Unit cost (tap to edit)
                Flexible(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final edited = await _lineDialog(existing: it);
                      if (edited != null) setState(() => _items[i] = edited);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: crm.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                                it.stockIn
                                    ? '${fmtINR(it.unitCost)} / unit'
                                    : fmtINR(it.unitCost),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: crm.textPrimary)),
                          ),
                          4.w,
                          Icon(Icons.edit_outlined,
                              size: 13, color: crm.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
                8.w,
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Subtotal',
                        style: TextStyle(
                            fontSize: 10, color: crm.textSecondary)),
                    Text(fmtINR(it.subtotal),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          6.h,
          Row(
            children: [
              SizedBox(
                height: 30,
                child: FittedBox(
                  child: Switch(
                    value: it.stockIn,
                    onChanged: (v) => _toggleStockIn(i, v),
                  ),
                ),
              ),
              6.w,
              Expanded(
                child: Text(
                    it.stockIn
                        ? 'Adds to stock'
                        : 'Expense only — ledgered, not stocked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: it.stockIn ? crm.success : crm.accent)),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '${it.quantity} × ${fmtINR(it.unitCost)}',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                ),
              ),
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
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(icon, size: 18, color: crm.textPrimary),
      ),
    );
  }

  // ── 3. Tax (GST) ──────────────────────────────────────────────────────────

  Widget _taxSection(CrmTheme crm) {
    return _section(
      crm,
      icon: Icons.percent_rounded,
      title: 'Tax (GST)',
      subtitle: _gstEnabled
          ? '${_pct(_gstRate)} · ${_interState ? 'IGST' : 'CGST + SGST'}'
          : 'Input tax on the vendor bill',
      color: const Color(0xFF9E2B43),
      trailing: Switch(
        value: _gstEnabled,
        onChanged: (v) => setState(() => _gstEnabled = v),
      ),
      child: !_gstEnabled
          ? Text('Turn on if this is a GST tax invoice.',
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _gstinCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Vendor GSTIN',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                12.h,
                Text('GST rate',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: crm.textSecondary)),
                6.h,
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in _gstRates)
                      ChoiceChip(
                        label: Text(_pct(r)),
                        selected: _gstRate == r,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _gstRate = r),
                      ),
                  ],
                ),
                12.h,
                Text('Supply type',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: crm.textSecondary)),
                6.h,
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Intra-state · CGST + SGST'),
                      selected: !_interState,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _interState = false),
                    ),
                    ChoiceChip(
                      label: const Text('Inter-state · IGST'),
                      selected: _interState,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _interState = true),
                    ),
                  ],
                ),
                12.h,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: crm.input.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                          _interState
                              ? 'IGST ${_pct(_gstRate)}  ${fmtINR(_gstAmount)}'
                              : 'CGST ${_pct(_gstRate / 2)} ${fmtINR(_gstAmount / 2)} · SGST ${_pct(_gstRate / 2)} ${fmtINR(_gstAmount / 2)}',
                          style: TextStyle(
                              fontSize: 12, color: crm.textSecondary)),
                      Text('GST ${fmtINR(_gstAmount)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── 4. Payment ────────────────────────────────────────────────────────────

  Widget _paymentSection(CrmTheme crm) {
    final overdue = !_paid &&
        _dueDate != null &&
        _dueDate!.isBefore(DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day));
    return _section(
      crm,
      icon: Icons.payments_outlined,
      title: 'Payment',
      subtitle: _paid ? 'Bill settled in full' : 'Record as payable to vendor',
      color: _paid ? crm.success : crm.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _payOption(crm,
                    selected: !_paid,
                    icon: Icons.schedule_rounded,
                    label: 'Not Paid',
                    color: crm.warning,
                    onTap: () => setState(() => _paid = false)),
              ),
              10.w,
              Expanded(
                child: _payOption(crm,
                    selected: _paid,
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Paid',
                    color: crm.success,
                    onTap: () => setState(() => _paid = true)),
              ),
            ],
          ),
          12.h,
          _datePickerField(
            label: 'Due date (optional)',
            icon: Icons.event_available_outlined,
            value: _dueDate,
            emptyText: 'Not set',
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            clearable: true,
            valueColor: overdue ? crm.destructive : null,
            onChanged: (d) => setState(() => _dueDate = d),
          ),
          if (overdue) ...[
            6.h,
            Text('Due date is in the past — this bill will show as overdue.',
                style: TextStyle(fontSize: 11.5, color: crm.destructive)),
          ],
          8.h,
          Text('Partial payments can be recorded from the Purchases list.',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ],
      ),
    );
  }

  Widget _payOption(
    CrmTheme crm, {
    required bool selected,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color.withValues(alpha: 0.6) : crm.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? color : crm.textSecondary),
            8.w,
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : crm.textPrimary)),
            ),
            if (selected) Icon(Icons.radio_button_checked, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  // ── 5. Notes & attachment ─────────────────────────────────────────────────

  Widget _notesSection(CrmTheme crm) {
    return _section(
      crm,
      icon: Icons.sticky_note_2_outlined,
      title: 'Notes & Attachment',
      subtitle: 'Internal notes and a photo of the supplier bill',
      color: crm.accent,
      child: Column(
        children: [
          TextField(
            controller: _notesCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
            ),
          ),
          12.h,
          _billSection(crm),
        ],
      ),
    );
  }

  Widget _billSection(CrmTheme crm) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.input.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          if (_billImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(_billImage!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.receipt_long, color: crm.textSecondary)),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: crm.border)),
              child: Icon(Icons.receipt_long_outlined,
                  color: crm.textSecondary),
            ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_billImage != null ? 'Bill attached' : 'Attach bill / invoice',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
                2.h,
                Text(
                    _billImage != null
                        ? 'Photo saved with this purchase'
                        : 'Photo of the supplier tax invoice',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          if (_uploadingBill)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            if (_billImage != null)
              IconButton(
                tooltip: 'Remove',
                icon: Icon(Icons.close, color: crm.destructive),
                onPressed: () => setState(() => _billImage = null),
              ),
            TextButton.icon(
              onPressed: _pickBill,
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: Text(_billImage != null ? 'Replace' : 'Upload'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  Widget _summaryCard(CrmTheme crm, {required bool showSave}) {
    final stockValue =
        _items.where((i) => i.stockIn).fold<double>(0, (a, i) => a + i.subtotal);
    final expenseValue = _total - stockValue;
    final paidAmt = _paid ? _grandTotal : 0.0;
    final balance = _grandTotal - paidAmt;

    Widget row(String label, String value,
            {Color? color, bool strong = false, bool muted = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: muted ? 12 : 13,
                        color: crm.textSecondary)),
              ),
              8.w,
              Text(value,
                  style: TextStyle(
                      fontSize: strong ? 14 : (muted ? 12 : 13),
                      fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                      color: color ??
                          (muted ? crm.textSecondary : crm.textPrimary))),
            ],
          ),
        );

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Summary',
            subtitle:
                '${_items.length} item${_items.length == 1 ? '' : 's'} · $_units unit${_units == 1 ? '' : 's'}',
          ),
          14.h,
          if (_vendor != null || _invoiceCtrl.text.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: crm.input.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 16, color: crm.textSecondary),
                  8.w,
                  Expanded(
                    child: Text(
                        [
                          _vendor?.name ?? 'No vendor',
                          if (_invoiceCtrl.text.trim().isNotEmpty)
                            '#${_invoiceCtrl.text.trim()}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: crm.textPrimary)),
                  ),
                ],
              ),
            ),
            10.h,
          ],
          if (expenseValue > 0) ...[
            row('Stock-in items', fmtINR(stockValue), muted: true),
            row('Expense items', fmtINR(expenseValue), muted: true),
          ],
          row('Subtotal (taxable)', fmtINR(_total)),
          if (_gstEnabled) ...[
            if (_interState)
              row('IGST @ ${_pct(_gstRate)}', fmtINR(_gstAmount))
            else ...[
              row('CGST @ ${_pct(_gstRate / 2)}', fmtINR(_gstAmount / 2)),
              row('SGST @ ${_pct(_gstRate / 2)}', fmtINR(_gstAmount / 2)),
            ],
          ] else
            row('GST', 'Not applied', muted: true),
          8.h,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crm.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Text('GRAND TOTAL',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: crm.textSecondary)),
                8.w,
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(fmtINR(_grandTotal),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: crm.primary)),
                  ),
                ),
              ],
            ),
          ),
          8.h,
          row('Paid', fmtINR(paidAmt), color: crm.success),
          row('Balance', fmtINR(balance),
              strong: true,
              color: balance > 0.01 ? crm.warning : crm.success),
          if (_dueDate != null)
            row('Due', DateFormat('d MMM yyyy').format(_dueDate!), muted: true),
          if (showSave) ...[
            16.h,
            SizedBox(
              width: double.infinity,
              child: _saveButton(),
            ),
            8.h,
            Text(
                _items.isEmpty
                    ? 'Add at least one item to save.'
                    : 'Saving adds stock-in items to inventory.',
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _saveButton() {
    return FilledButton.icon(
      onPressed: (_saving || _items.isEmpty) ? null : _save,
      style: FilledButton.styleFrom(
        minimumSize: const Size(140, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white))
          : const Icon(Icons.check_rounded, size: 18),
      label: const Text('Save Purchase'),
    );
  }

  Widget _footer(CrmTheme crm) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(top: BorderSide(color: crm.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${_items.length} items · $_units units${_gstEnabled ? ' · incl. GST' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(fmtINR(_grandTotal),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          12.w,
          _saveButton(),
        ],
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
                          onChanged: (_) => setLocal(() {}),
                          decoration:
                              const InputDecoration(labelText: 'Qty')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setLocal(() {}),
                          decoration: InputDecoration(
                              labelText:
                                  stockIn ? 'Unit cost (₹)' : 'Amount (₹)')),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Builder(builder: (context) {
                    final crm = context.crmColors;
                    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                    final cost = double.tryParse(costCtrl.text.trim()) ?? 0;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: crm.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: crm.primary.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        children: [
                          Text('$qty × ${fmtINR(cost)}',
                              style: TextStyle(
                                  fontSize: 13, color: crm.textSecondary)),
                          const Spacer(),
                          Text('Total  ${fmtINR(qty * cost)}',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: crm.primary)),
                        ],
                      ),
                    );
                  }),
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
