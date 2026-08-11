import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/asset.dart';
import 'package:nizan_crm/features/finance/controllers/asset_provider.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
String _date(DateTime d) => DateFormat('d MMM yyyy').format(d);
String _pretty(String s) =>
    s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

/// Finance → Assets. Company asset register with Digital / Physical tabs.
class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: crm.background,
        appBar: AppBar(
          backgroundColor: crm.surface,
          elevation: 0,
          titleSpacing: 16,
          title: Text('Company Assets',
              style: TextStyle(
                  color: crm.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
          bottom: TabBar(
            labelColor: crm.primary,
            unselectedLabelColor: crm.textSecondary,
            indicatorColor: crm.primary,
            tabs: const [
              Tab(icon: Icon(Icons.cloud_outlined), text: 'Digital'),
              Tab(icon: Icon(Icons.chair_outlined), text: 'Physical'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AssetList(type: 'digital'),
            _AssetList(type: 'physical'),
          ],
        ),
      ),
    );
  }
}

class _AssetList extends ConsumerWidget {
  const _AssetList({required this.type});
  final String type; // 'digital' | 'physical'

  bool get _isDigital => type == 'digital';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(assetsProvider(type));

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: crm.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(_isDigital ? 'Add Digital Asset' : 'Add Physical Asset',
            style: const TextStyle(color: Colors.white)),
        onPressed: () => _openForm(context, ref, type),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(assetsProvider(type));
          ref.invalidate(assetStatsProvider);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                  child: Text('$e',
                      style: TextStyle(color: crm.destructive))),
            ),
          ]),
          data: (assets) {
            final count = assets.length;
            final value = assets.fold<double>(0, (a, x) => a + x.totalValue);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Row(children: [
                  Expanded(child: _summary(crm, '$count', 'Items', crm.primary)),
                  10.w,
                  Expanded(child: _summary(crm, _money(value), 'Total value', crm.accent)),
                ]),
                16.h,
                if (assets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(children: [
                        Icon(_isDigital ? Icons.cloud_off_outlined : Icons.inventory_2_outlined,
                            size: 54, color: crm.border),
                        12.h,
                        Text('No ${_isDigital ? 'digital' : 'physical'} assets yet',
                            style: TextStyle(color: crm.textSecondary)),
                      ]),
                    ),
                  )
                else
                  for (final a in assets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AssetCard(
                        asset: a,
                        onEdit: () => _openForm(context, ref, type, existing: a),
                        onDelete: () => _delete(context, ref, a),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summary(CrmTheme crm, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          ),
          4.h,
          Text(label, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Asset a) async {
    final crm = context.crmColors;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: crm.surface,
        title: const Text('Delete asset?'),
        content: Text('Delete "${a.name}"?', style: TextStyle(color: crm.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: TextStyle(color: crm.destructive))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(assetServiceProvider).delete(a.id);
      ref.invalidate(assetsProvider(type));
      ref.invalidate(assetStatsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Asset deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openForm(BuildContext context, WidgetRef ref, String type, {Asset? existing}) {
    showDialog(
      context: context,
      builder: (_) => _AssetDialog(type: type, existing: existing),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, required this.onEdit, required this.onDelete});
  final Asset asset;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final days = asset.daysToExpiry;
    final expiryColor = days == null
        ? crm.textSecondary
        : days < 0
            ? crm.destructive
            : days <= 30
                ? crm.warning
                : crm.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(asset.isDigital ? Icons.language : Icons.category_outlined,
                    color: crm.primary, size: 20),
              ),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    2.h,
                    Text(
                      '${_pretty(asset.category)}'
                      '${asset.quantity > 1 ? ' · x${asset.quantity}' : ''}',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    ),
                  ],
                ),
              ),
              8.w,
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money(asset.totalValue),
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                  4.h,
                  _statusPill(crm, asset.status),
                ],
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: crm.textSecondary),
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (_detailLine(asset).isNotEmpty) ...[
            8.h,
            Text(_detailLine(asset),
                style: TextStyle(fontSize: 12, color: crm.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          if (asset.isDigital && asset.expiryDate != null) ...[
            6.h,
            Row(children: [
              Icon(Icons.event_outlined, size: 13, color: expiryColor),
              4.w,
              Text(
                days != null && days < 0
                    ? 'Expired ${_date(asset.expiryDate!)}'
                    : 'Renews ${_date(asset.expiryDate!)}${days != null ? ' · in $days d' : ''}',
                style: TextStyle(fontSize: 11.5, color: expiryColor, fontWeight: FontWeight.w600),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  String _detailLine(Asset a) {
    if (a.isDigital) {
      return [
        if (a.provider.isNotEmpty) a.provider,
        if (a.url.isNotEmpty) a.url,
        if (a.custodianName.isNotEmpty || a.custodian.isNotEmpty)
          'Owner: ${a.custodianName.isNotEmpty ? a.custodianName : a.custodian}',
      ].join(' · ');
    }
    return [
      if (a.location.isNotEmpty) a.location,
      if (a.condition.isNotEmpty) _pretty(a.condition),
      if (a.serialNumber.isNotEmpty) 'SN ${a.serialNumber}',
      if (a.custodianName.isNotEmpty || a.custodian.isNotEmpty)
        'With: ${a.custodianName.isNotEmpty ? a.custodianName : a.custodian}',
    ].join(' · ');
  }

  Widget _statusPill(CrmTheme crm, String status) {
    final color = switch (status) {
      'active' || 'in_use' => crm.success,
      'idle' => crm.textSecondary,
      'maintenance' => crm.warning,
      'disposed' || 'expired' => crm.destructive,
      _ => crm.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(_pretty(status),
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _AssetDialog extends ConsumerStatefulWidget {
  const _AssetDialog({required this.type, this.existing});
  final String type;
  final Asset? existing;

  @override
  ConsumerState<_AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends ConsumerState<_AssetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _value;
  late final TextEditingController _qty;
  late final TextEditingController _custodian;
  late final TextEditingController _notes;
  // digital
  late final TextEditingController _provider;
  late final TextEditingController _url;
  // physical
  late final TextEditingController _location;
  late final TextEditingController _serial;

  late String _category;
  late String _status;
  String _condition = '';
  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  bool _saving = false;

  bool get _isDigital => widget.type == 'digital';

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _name = TextEditingController(text: a?.name ?? '');
    _value = TextEditingController(text: a != null && a.value > 0 ? a.value.toStringAsFixed(0) : '');
    _qty = TextEditingController(text: (a?.quantity ?? 1).toString());
    _custodian = TextEditingController(text: a?.custodian ?? '');
    _notes = TextEditingController(text: a?.notes ?? '');
    _provider = TextEditingController(text: a?.provider ?? '');
    _url = TextEditingController(text: a?.url ?? '');
    _location = TextEditingController(text: a?.location ?? '');
    _serial = TextEditingController(text: a?.serialNumber ?? '');
    final cats = _isDigital ? kDigitalAssetCategories : kPhysicalAssetCategories;
    _category = (a != null && cats.contains(a.category)) ? a.category : cats.first;
    _status = (a != null && kAssetStatuses.contains(a.status)) ? a.status : 'active';
    _condition = a?.condition ?? '';
    _purchaseDate = a?.purchaseDate;
    _expiryDate = a?.expiryDate;
  }

  @override
  void dispose() {
    for (final c in [_name, _value, _qty, _custodian, _notes, _provider, _url, _location, _serial]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool expiry) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (expiry ? _expiryDate : _purchaseDate) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      setState(() => expiry ? _expiryDate = picked : _purchaseDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'assetType': widget.type,
        'category': _category,
        'value': double.tryParse(_value.text.trim()) ?? 0,
        'quantity': int.tryParse(_qty.text.trim()) ?? 1,
        'status': _status,
        'custodian': _custodian.text.trim(),
        'notes': _notes.text.trim(),
        'purchaseDate': _purchaseDate?.toIso8601String(),
        if (_isDigital) ...{
          'provider': _provider.text.trim(),
          'url': _url.text.trim(),
          'expiryDate': _expiryDate?.toIso8601String(),
        } else ...{
          'location': _location.text.trim(),
          'condition': _condition,
          'serialNumber': _serial.text.trim(),
        },
      };
      await ref.read(assetServiceProvider).save(body, id: widget.existing?.id);
      ref.invalidate(assetsProvider(widget.type));
      ref.invalidate(assetStatsProvider);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Asset saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final editing = widget.existing != null;
    final cats = _isDigital ? kDigitalAssetCategories : kPhysicalAssetCategories;

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${editing ? 'Edit' : 'New'} ${_isDigital ? 'Digital' : 'Physical'} Asset',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                16.h,
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Asset name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                12.h,
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final c in cats)
                          DropdownMenuItem(value: c, child: Text(_pretty(c))),
                      ],
                      onChanged: (v) => setState(() => _category = v ?? _category),
                    ),
                  ),
                  12.w,
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final s in kAssetStatuses)
                          DropdownMenuItem(value: s, child: Text(_pretty(s))),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                ]),
                12.h,
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _value,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Value (₹)', prefixText: '₹ '),
                    ),
                  ),
                  12.w,
                  Expanded(
                    child: TextFormField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                ]),
                12.h,
                if (_isDigital) ...[
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _provider,
                        decoration: const InputDecoration(
                            labelText: 'Provider / Platform', hintText: 'GoDaddy, Adobe, Instagram…'),
                      ),
                    ),
                    12.w,
                    Expanded(child: _dateField(crm, 'Renewal / Expiry', _expiryDate, () => _pickDate(true))),
                  ]),
                  12.h,
                  TextFormField(
                    controller: _url,
                    decoration: const InputDecoration(labelText: 'URL / Handle', hintText: 'https:// or @handle'),
                  ),
                ] else ...[
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(labelText: 'Location'),
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _condition.isEmpty ? null : _condition,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Condition'),
                        items: const [
                          DropdownMenuItem(value: 'new', child: Text('New')),
                          DropdownMenuItem(value: 'good', child: Text('Good')),
                          DropdownMenuItem(value: 'fair', child: Text('Fair')),
                          DropdownMenuItem(value: 'poor', child: Text('Poor')),
                        ],
                        onChanged: (v) => setState(() => _condition = v ?? ''),
                      ),
                    ),
                  ]),
                  12.h,
                  TextFormField(
                    controller: _serial,
                    decoration: const InputDecoration(labelText: 'Serial number'),
                  ),
                ],
                12.h,
                Row(children: [
                  Expanded(child: _dateField(crm, 'Purchase date', _purchaseDate, () => _pickDate(false))),
                  12.w,
                  Expanded(
                    child: TextFormField(
                      controller: _custodian,
                      decoration: InputDecoration(
                          labelText: _isDigital ? 'Owner' : 'Assigned to'),
                    ),
                  ),
                ]),
                12.h,
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                18.h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    8.w,
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField(CrmTheme crm, String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(value == null ? '—' : _date(value),
            style: TextStyle(color: value == null ? crm.textSecondary : crm.textPrimary)),
      ),
    );
  }
}
