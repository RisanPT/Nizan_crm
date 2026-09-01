import 'package:flutter/material.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
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
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/slots/data/slot_models.dart';
import 'package:nizan_crm/features/slots/services/slot_service.dart';

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
  late final TabController _tabs = TabController(length: 4, vsync: this);

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
    _tabs.animateTo(3);
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
              labelStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.5,
              tabs: const [
                Tab(icon: Icon(Icons.groups_rounded), text: 'Leads'),
                Tab(icon: Icon(Icons.calculate_rounded), text: 'Quote'),
                Tab(icon: Icon(Icons.event_available_rounded), text: 'Slots'),
                Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Invoice'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                const SalesLeadsScreen(),
                _CalculatorTab(onCreateInvoice: _sendToInvoice),
                const _AvailabilityTab(),
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.calculate_rounded, color: crm.primary, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quote Calculator',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800, color: crm.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Build a quick price quote, then turn it into an invoice.',
                        style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

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
            error: (e, _) => Text(friendlyErrorMessage(e),
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
                    color: crm.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 8),
            ...addons.map((a) {
              final selected = _addonIds.contains(a.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() {
                    if (selected) {
                      _addonIds.remove(a.id);
                    } else {
                      _addonIds.add(a.id);
                    }
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? crm.primary.withValues(alpha: 0.06)
                          : crm.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? crm.primary : crm.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                selected ? crm.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: selected ? crm.primary : crm.border,
                                width: 1.5),
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  size: 15, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(a.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: crm.textPrimary)),
                        ),
                        const SizedBox(width: 8),
                        Text('₹${a.price.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? crm.primary
                                    : crm.textSecondary)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 16),

          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [crm.primary, const Color(0xFF3A101A)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: crm.primary.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total amount',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 2),
                    Text('₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ],
                ),
                const Spacer(),
                Icon(Icons.receipt_long_rounded,
                    color: Colors.white.withValues(alpha: 0.85), size: 28),
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
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Create Invoice from this Quote'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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

  /// Pick an existing service package and add it as a line item (name + price).
  Future<void> _addPackageDialog() async {
    final packages = await ref.read(packagesProvider.future);
    if (!mounted) return;
    if (packages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No packages available')),
      );
      return;
    }
    final picked = await showModalBottomSheet<ServicePackage>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var q = '';
        return StatefulBuilder(builder: (ctx, setSheet) {
          final filtered = q.isEmpty
              ? packages
              : packages.where((p) => p.name.toLowerCase().contains(q.toLowerCase())).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add a package', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search packages…', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setSheet(() => q = v.trim()),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                child: filtered.isEmpty
                    ? const Padding(padding: EdgeInsets.all(24), child: Text('No matching packages.'))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final p in filtered)
                            ListTile(
                              title: Text(p.name),
                              trailing: Text('₹${p.price.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              onTap: () => Navigator.pop(ctx, p),
                            ),
                        ],
                      ),
              ),
            ]),
          );
        });
      },
    );
    if (picked != null) {
      setState(() => _lines.add(SpotInvoiceLine(label: picked.name, amount: picked.price)));
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
          SnackBar(content: Text(friendlyErrorMessage(e))),
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.receipt_long_rounded, color: crm.primary, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spot Invoice',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800, color: crm.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Generate a quotation and share it with the customer (no GST).',
                        style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                onPressed: _addPackageDialog,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Package'),
              ),
              TextButton.icon(
                onPressed: _addLineDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_lines.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: crm.input,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: crm.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.playlist_add_rounded,
                      color: crm.textSecondary, size: 28),
                  const SizedBox(height: 8),
                  Text('No items yet',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Add a package or line, or build a quote in the Quote tab.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
              ),
            )
          else
            ..._lines.asMap().entries.map((e) {
              final i = e.key;
              final l = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: crm.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(l.label,
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Text('₹${l.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: crm.textPrimary)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: crm.destructive),
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [crm.primary, const Color(0xFF3A101A)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: crm.primary.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total amount',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 2),
                    Text('₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ],
                ),
                const Spacer(),
                Icon(Icons.ios_share_rounded,
                    color: Colors.white.withValues(alpha: 0.85), size: 26),
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
                  : const Icon(Icons.ios_share_rounded),
              label: Text(_generating ? 'Generating…' : 'Generate & Share'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Availability tab ─────────────────────────────────────────────────────
// Read-only view of this month's morning/evening slot availability so a
// salesperson can see which days still have room before promising a date.
const _monthNames = ['', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];
const _weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class _AvailabilityTab extends ConsumerStatefulWidget {
  const _AvailabilityTab();
  @override
  ConsumerState<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends ConsumerState<_AvailabilityTab> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final key = (year: _month.year, month: _month.month);
    final async = ref.watch(monthAvailabilityProvider(key));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Row(
            children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showMonthPicker(context, initial: _month);
                    if (picked != null) setState(() => _month = DateTime(picked.year, picked.month));
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${_monthNames[_month.month]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const Icon(Icons.arrow_drop_down, size: 22),
                  ]),
                ),
              ),
              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(
              error: e,
              onRetry: () => ref.invalidate(monthAvailabilityProvider(key)),
            ),
            data: (m) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(monthAvailabilityProvider(key)),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _summary(context, m),
                  const SizedBox(height: 14),
                  for (final d in m.days) _dayRow(context, d),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, MonthAvailability m) {
    final crm = context.crmColors;
    const gold = Color(0xFFC9A66B);
    final pct = m.totalCapacity == 0
        ? 0.0
        : (m.totalBooked / m.totalCapacity).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [crm.primary, const Color(0xFF3A101A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: crm.primary.withValues(alpha: 0.26),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${m.totalAvailable}',
              style: const TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
          const SizedBox(height: 4),
          Text('slots open in ${_monthNames[m.month]} ${m.year}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroPill(Icons.event_busy_rounded, '${m.totalBooked}', 'Booked'),
              const SizedBox(width: 8),
              _heroPill(Icons.event_seat_rounded, '${m.totalCapacity}', 'Capacity'),
              const SizedBox(width: 8),
              _heroPill(Icons.today_rounded,
                  '${m.defaultMorning + m.defaultEvening}', 'Per day'),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation(gold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(pct * 100).round()}% booked  ·  ${m.defaultMorning} morning + ${m.defaultEvening} evening',
            style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.62)),
          ),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String value, String label) {
    const gold = Color(0xFFC9A66B);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: gold),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(BuildContext context, DaySlot d) {
    final crm = context.crmColors;
    final today = DateTime.now();
    final isPast = d.date.isBefore(DateTime(today.year, today.month, today.day));
    final color = d.unavailable ? crm.destructive : crm.success;
    final pct = d.total.capacity == 0
        ? 0.0
        : (d.total.booked / d.total.capacity).clamp(0.0, 1.0);
    final label = d.blocked
        ? 'BLOCKED'
        : (d.total.isFull ? 'FULL' : '${d.total.available} of ${d.total.capacity} left');

    return Opacity(
      opacity: isPast ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: d.unavailable
                  ? crm.destructive.withValues(alpha: 0.30)
                  : crm.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Date chip
            Container(
              width: 46,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${d.date.day}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1)),
                  const SizedBox(height: 2),
                  Text(_weekdays[d.date.weekday],
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.85))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: color)),
                      ),
                      const Spacer(),
                      if (d.isOverride)
                        Tooltip(
                          message: 'HR set a custom limit for this day',
                          child: Icon(Icons.push_pin_rounded,
                              size: 14, color: crm.textSecondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  if (d.blocked)
                    Text('Blocked by HR — no bookings',
                        style: TextStyle(fontSize: 11.5, color: crm.destructive))
                  else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _amPm(Icons.wb_sunny_rounded, 'Morning',
                            d.morning.booked, d.morning.capacity, crm.textSecondary),
                        const SizedBox(width: 16),
                        _amPm(Icons.nightlight_round, 'Evening',
                            d.evening.booked, d.evening.capacity, crm.textSecondary),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amPm(
      IconData icon, String label, int booked, int capacity, Color c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 5),
        Text('$label $booked/$capacity',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
      ],
    );
  }
}
