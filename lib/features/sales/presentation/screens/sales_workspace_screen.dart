import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/models/service_package.dart';
import 'package:nizan_crm/core/models/addon_service.dart';
import 'package:nizan_crm/core/models/spot_invoice.dart';
import 'package:nizan_crm/core/utils/spot_invoice_service.dart';
import 'package:nizan_crm/services/package_service.dart';
import 'package:nizan_crm/services/addon_service_service.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'sales_leads_screen.dart';

/// The salesperson's main workspace: Leads · Calculator · Spot Invoice.
/// The Calculator feeds a total into the Spot Invoice tab, which generates a
/// shareable no-GST quotation.
class SalesWorkspaceScreen extends ConsumerStatefulWidget {
  const SalesWorkspaceScreen({super.key});

  @override
  ConsumerState<SalesWorkspaceScreen> createState() =>
      _SalesWorkspaceScreenState();
}

class _SalesWorkspaceScreenState extends ConsumerState<SalesWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  // Handoff from Calculator → Spot Invoice.
  List<SpotInvoiceLine> _prefillLines = const [];
  String _prefillCustomer = '';
  String _prefillPhone = '';
  int _prefillNonce = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _sendToInvoice(
      String customer, String phone, List<SpotInvoiceLine> lines) {
    setState(() {
      _prefillCustomer = customer;
      _prefillPhone = phone;
      _prefillLines = lines;
      _prefillNonce++;
    });
    _tabs.animateTo(2);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Scaffold(
      backgroundColor: crm.background,
      body: Column(
        children: [
          Material(
            color: crm.surface,
            child: TabBar(
              controller: _tabs,
              labelColor: crm.primary,
              unselectedLabelColor: crm.textSecondary,
              indicatorColor: crm.primary,
              tabs: const [
                Tab(icon: Icon(Icons.people_alt_outlined), text: 'Leads'),
                Tab(icon: Icon(Icons.calculate_outlined), text: 'Calculator'),
                Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Spot Invoice'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                const SalesLeadsScreen(),
                _CalculatorTab(onCreateInvoice: _sendToInvoice),
                _SpotInvoiceTab(
                  key: ValueKey(_prefillNonce),
                  initialCustomer: _prefillCustomer,
                  initialPhone: _prefillPhone,
                  initialLines: _prefillLines,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Calculator tab
// ─────────────────────────────────────────────────────────────────────────
class _CalculatorTab extends ConsumerStatefulWidget {
  final void Function(String customer, String phone, List<SpotInvoiceLine> lines)
      onCreateInvoice;

  const _CalculatorTab({required this.onCreateInvoice});

  @override
  ConsumerState<_CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends ConsumerState<_CalculatorTab> {
  final _customerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  ServicePackage? _package;
  String? _districtId;
  String _districtName = '';
  int _qty = 1;
  final Set<String> _addonIds = {};

  @override
  void dispose() {
    _customerCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  List<SpotInvoiceLine> _buildLines(List<AddonService> addons) {
    final lines = <SpotInvoiceLine>[];
    if (_package != null) {
      // Package price varies by district — use the district-specific price when
      // a district is chosen (falls back to the base price otherwise).
      final unit = _package!.effectivePriceForDistrict(_districtId);
      final where = _districtName.isNotEmpty ? ' · $_districtName' : '';
      lines.add(SpotInvoiceLine(
        label: _qty > 1
            ? '${_package!.name} × $_qty$where'
            : '${_package!.name}$where',
        amount: unit * _qty,
      ));
    }
    for (final a in addons) {
      if (_addonIds.contains(a.id)) {
        lines.add(SpotInvoiceLine(label: a.name, amount: a.price));
      }
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final asyncPackages = ref.watch(packagesProvider);
    final asyncAddons = ref.watch(addonServicesProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final districts = asyncDistricts.value ?? [];
    final addons = (asyncAddons.value ?? [])
        .where((a) => a.status.toLowerCase() == 'active')
        .toList();
    final lines = _buildLines(addons);
    final total = lines.fold<double>(0, (s, l) => s + l.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quote Calculator',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: crm.textPrimary)),
          const SizedBox(height: 4),
          Text('Build a quick price quote, then turn it into a shareable invoice.',
              style: TextStyle(color: crm.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),

          // Customer (optional)
          TextField(
            controller: _customerCtrl,
            decoration: const InputDecoration(
              labelText: 'Customer name (optional)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // District — package price varies by district.
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _districtId,
            decoration: const InputDecoration(
              labelText: 'District (for pricing)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Standard price')),
              for (final d in districts)
                DropdownMenuItem(value: d.id, child: Text(d.name)),
            ],
            onChanged: (id) => setState(() {
              _districtId = (id == null || id.isEmpty) ? null : id;
              _districtName = _districtId == null
                  ? ''
                  : (districts
                          .where((d) => d.id == _districtId)
                          .map((d) => d.name)
                          .firstOrNull ??
                      '');
            }),
          ),
          const SizedBox(height: 12),

          // Package (price shown reflects the selected district)
          asyncPackages.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load packages: $e',
                style: TextStyle(color: crm.destructive)),
            data: (packages) => DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _package?.id,
              decoration: const InputDecoration(
                labelText: 'Package',
                prefixIcon: Icon(Icons.card_giftcard_outlined),
              ),
              items: [
                for (final p in packages)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(
                        '${p.name}  ·  ₹${p.effectivePriceForDistrict(_districtId).toStringAsFixed(0)}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() =>
                  _package = packages.where((p) => p.id == id).firstOrNull),
            ),
          ),
          const SizedBox(height: 12),

          // Quantity
          Row(
            children: [
              Text('Quantity', style: TextStyle(color: crm.textSecondary)),
              const Spacer(),
              IconButton.outlined(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$_qty',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton.filled(
                onPressed: () => setState(() => _qty++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Add-ons
          if (addons.isNotEmpty) ...[
            Text('Add-ons',
                style: TextStyle(
                    color: crm.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...addons.map((a) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _addonIds.contains(a.id),
                  title: Text(a.name),
                  secondary: Text('₹${a.price.toStringAsFixed(0)}'),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _addonIds.add(a.id);
                    } else {
                      _addonIds.remove(a.id);
                    }
                  }),
                )),
          ],
          const SizedBox(height: 16),

          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: crm.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Text('Total',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: crm.textPrimary)),
                const Spacer(),
                Text('₹${total.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: crm.primary)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: lines.isEmpty
                  ? null
                  : () => widget.onCreateInvoice(
                        _customerCtrl.text.trim(),
                        _phoneCtrl.text.trim(),
                        lines,
                      ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Create Invoice from this Quote'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Spot Invoice tab
// ─────────────────────────────────────────────────────────────────────────
class _SpotInvoiceTab extends ConsumerStatefulWidget {
  final String initialCustomer;
  final String initialPhone;
  final List<SpotInvoiceLine> initialLines;

  const _SpotInvoiceTab({
    super.key,
    this.initialCustomer = '',
    this.initialPhone = '',
    this.initialLines = const [],
  });

  @override
  ConsumerState<_SpotInvoiceTab> createState() => _SpotInvoiceTabState();
}

class _SpotInvoiceTabState extends ConsumerState<_SpotInvoiceTab> {
  late final TextEditingController _customerCtrl =
      TextEditingController(text: widget.initialCustomer);
  late final TextEditingController _phoneCtrl =
      TextEditingController(text: widget.initialPhone);
  final _noteCtrl = TextEditingController();
  late final List<SpotInvoiceLine> _lines = [...widget.initialLines];
  bool _generating = false;

  @override
  void dispose() {
    _customerCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _addLineDialog() async {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add line item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    final label = labelCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    labelCtrl.dispose();
    amountCtrl.dispose();
    if (added == true && label.isNotEmpty) {
      setState(() => _lines.add(SpotInvoiceLine(label: label, amount: amount)));
    }
  }

  Future<void> _generate() async {
    if (_customerCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a customer name')),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item')),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final now = DateTime.now();
      final invoiceNo =
          'QT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 100000}';
      await printSpotInvoice(SpotInvoiceData(
        invoiceNo: invoiceNo,
        customerName: _customerCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        lines: List.of(_lines),
        date: now,
        note: _noteCtrl.text.trim(),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final total = _lines.fold<double>(0, (s, l) => s + l.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spot Invoice',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: crm.textPrimary)),
          const SizedBox(height: 4),
          Text('Generate a quotation and share it with the customer (no GST).',
              style: TextStyle(color: crm.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _customerCtrl,
            decoration: const InputDecoration(
              labelText: 'Customer name *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // Line items
          Row(
            children: [
              Text('Line items',
                  style: TextStyle(
                      color: crm.textSecondary, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addLineDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No items yet. Add one, or build a quote in the Calculator tab.',
                  style: TextStyle(color: crm.textSecondary)),
            )
          else
            ..._lines.asMap().entries.map((e) {
              final i = e.key;
              final l = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: crm.border),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(l.label)),
                    Text('₹${l.amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, size: 18, color: crm.destructive),
                      onPressed: () => setState(() => _lines.removeAt(i)),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),

          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: crm.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Text('Total',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: crm.textPrimary)),
                const Spacer(),
                Text('₹${total.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: crm.primary)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.ios_share),
              label: Text(_generating ? 'Generating…' : 'Generate & Share'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
