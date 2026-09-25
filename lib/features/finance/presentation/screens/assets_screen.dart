import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/asset.dart';
import 'package:nizan_crm/features/finance/controllers/asset_provider.dart';
import 'package:nizan_crm/services/upload_service.dart';
import 'package:nizan_crm/core/error/errors.dart';

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

class _AssetList extends ConsumerStatefulWidget {
  const _AssetList({required this.type});
  final String type; // 'digital' | 'physical'

  @override
  ConsumerState<_AssetList> createState() => _AssetListState();
}

class _AssetListState extends ConsumerState<_AssetList> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _status = 'all';
  String _category = 'all';

  String get type => widget.type;
  bool get _isDigital => widget.type == 'digital';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Asset> _applyFilters(List<Asset> all) {
    final q = _search.trim().toLowerCase();
    return all.where((a) {
      if (_status != 'all' && a.status != _status) return false;
      if (_category != 'all' && a.category != _category) return false;
      if (q.isNotEmpty) {
        final hay = [a.name, a.provider, a.location, a.serialNumber, a.custodian, a.notes]
            .join(' ')
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Widget _filterBar(CrmTheme crm) {
    final cats = _isDigital ? kDigitalAssetCategories : kPhysicalAssetCategories;
    return Column(children: [
      TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search name, provider, serial, owner…',
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                ),
        ),
      ),
      10.h,
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Status', isDense: true),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All statuses')),
              for (final s in kAssetStatuses) DropdownMenuItem(value: s, child: Text(_pretty(s))),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'all'),
          ),
        ),
        10.w,
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category', isDense: true),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All categories')),
              for (final c in cats) DropdownMenuItem(value: c, child: Text(_pretty(c))),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'all'),
          ),
        ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
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
            AppErrorView(error: e, onRetry: () {
              ref.invalidate(assetsProvider(type));
              ref.invalidate(assetStatsProvider);
            }),
          ]),
          data: (all) {
            final assets = _applyFilters(all);
            final count = assets.length;
            final value = assets.fold<double>(0, (a, x) => a + x.totalValue);
            final filtering = _search.isNotEmpty || _status != 'all' || _category != 'all';
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Row(children: [
                  Expanded(child: _summary(crm, '$count', filtering ? 'Matches' : 'Items', crm.primary)),
                  10.w,
                  Expanded(child: _summary(crm, _money(value), 'Total value', crm.accent)),
                ]),
                12.h,
                _filterBar(crm),
                16.h,
                if (assets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(children: [
                        Icon(_isDigital ? Icons.cloud_off_outlined : Icons.inventory_2_outlined,
                            size: 54, color: crm.border),
                        12.h,
                        Text(
                            all.isEmpty
                                ? 'No ${_isDigital ? 'digital' : 'physical'} assets yet'
                                : 'No assets match your filters',
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
        border: Border.all(color: crm.border.faded(0.6)),
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
      ref.refreshData.assets();
      messenger.showSnackBar(const SnackBar(content: Text('Asset deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
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
        border: Border.all(color: crm.border.faded(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              asset.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(
                        asset.imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _iconBox(crm),
                      ),
                    )
                  : _iconBox(crm),
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

  Widget _iconBox(CrmTheme crm) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: crm.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(asset.isDigital ? Icons.language : Icons.category_outlined,
            color: crm.primary, size: 20),
      );

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
  // depreciation
  late final TextEditingController _depRate;
  late final TextEditingController _life;
  late final TextEditingController _salvage;

  late String _category;
  late String _status;
  String _condition = '';
  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  bool _depreciable = false;
  String _depMethod = 'straight_line';
  DateTime? _depStart;
  String _imageUrl = '';
  bool _uploadingImage = false;
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
    _imageUrl = a?.imageUrl ?? '';
    _depRate = TextEditingController(
        text: a != null && a.depreciationRate > 0 ? _trimNum(a.depreciationRate) : '');
    _life = TextEditingController(
        text: a != null && a.usefulLifeYears > 0 ? _trimNum(a.usefulLifeYears) : '');
    _salvage = TextEditingController(
        text: a != null && a.salvageValue > 0 ? a.salvageValue.toStringAsFixed(0) : '');
    final cats = _isDigital ? kDigitalAssetCategories : kPhysicalAssetCategories;
    _category = (a != null && cats.contains(a.category)) ? a.category : cats.first;
    _status = (a != null && kAssetStatuses.contains(a.status)) ? a.status : 'active';
    _condition = a?.condition ?? '';
    _purchaseDate = a?.purchaseDate;
    _expiryDate = a?.expiryDate;
    _depreciable = a?.depreciable ?? false;
    _depMethod = (a != null && kDepreciationMethods.contains(a.depreciationMethod))
        ? a.depreciationMethod
        : 'straight_line';
    _depStart = a?.depreciationStart;
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    for (final c in [
      _name, _value, _qty, _custodian, _notes, _provider, _url, _location, _serial,
      _depRate, _life, _salvage,
    ]) {
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
          'imageUrl': _imageUrl,
        },
        'depreciable': _depreciable,
        if (_depreciable) ...{
          'depreciationMethod': _depMethod,
          'depreciationRate': double.tryParse(_depRate.text.trim()) ?? 0,
          'usefulLifeYears': double.tryParse(_life.text.trim()) ?? 0,
          'salvageValue': double.tryParse(_salvage.text.trim()) ?? 0,
          'depreciationStart': _depStart?.toIso8601String(),
        },
      };
      await ref.read(assetServiceProvider).save(body, id: widget.existing?.id);
      ref.refreshData.assets();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Asset saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red));
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
                  12.h,
                  _imagePicker(crm),
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
                12.h,
                _depreciationSection(crm),
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

  Future<void> _pickDepStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _depStart ?? _purchaseDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) setState(() => _depStart = picked);
  }

  Widget _imagePicker(CrmTheme crm) {
    final has = _imageUrl.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PHOTO',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
      6.h,
      if (has)
        Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _imageUrl,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 150,
                color: crm.background,
                child: Icon(Icons.broken_image_outlined, color: crm.textSecondary),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Row(children: [
              _imgIconBtn(Icons.edit_outlined, _uploadingImage ? null : _pickImage),
              6.w,
              _imgIconBtn(Icons.close, _uploadingImage ? null : () => setState(() => _imageUrl = '')),
            ]),
          ),
          if (_uploadingImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ])
      else
        InkWell(
          onTap: _uploadingImage ? null : _pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              color: crm.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crm.border),
            ),
            child: _uploadingImage
                ? const Center(child: CircularProgressIndicator())
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_outlined, color: crm.textSecondary),
                    6.h,
                    Text('Add a photo', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                  ]),
          ),
        ),
    ]);
  }

  Widget _imgIconBtn(IconData icon, VoidCallback? onTap) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 16, color: Colors.white)),
        ),
      );

  Future<void> _pickImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
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
    if (source == null || !mounted) return;
    final XFile? img;
    try {
      img = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    } catch (e) {
      // Camera/gallery permission denied or picker unavailable.
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, fallback: "Couldn't open the camera or gallery."))));
      return;
    }
    if (img == null || !mounted) return;
    setState(() => _uploadingImage = true);
    try {
      final url = await ref.read(uploadServiceProvider).uploadImage(img);
      if (mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Widget _depreciationSection(CrmTheme crm) {
    final byLife = _depMethod == 'straight_line';
    return Container(
      decoration: BoxDecoration(
        color: crm.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border.faded(0.8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _depreciable,
          onChanged: (v) => setState(() => _depreciable = v),
          title: Text('Depreciate this asset',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          subtitle: Text('Write its value off over time in the ledger',
              style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ),
        if (_depreciable) ...[
          8.h,
          DropdownButtonFormField<String>(
            initialValue: _depMethod,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Method', isDense: true),
            items: [
              for (final m in kDepreciationMethods)
                DropdownMenuItem(value: m, child: Text(depreciationMethodLabel(m))),
            ],
            onChanged: (v) => setState(() => _depMethod = v ?? _depMethod),
          ),
          12.h,
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _depRate,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: byLife ? 'Rate %/yr' : 'Rate %/yr *',
                  isDense: true,
                  suffixText: '%',
                ),
                validator: (v) {
                  if (!_depreciable) return null;
                  final rate = double.tryParse(v?.trim() ?? '') ?? 0;
                  final life = double.tryParse(_life.text.trim()) ?? 0;
                  if (byLife) {
                    if (rate <= 0 && life <= 0) return 'Set a rate or life';
                    return null;
                  }
                  return rate > 0 ? null : 'Required for WDV';
                },
              ),
            ),
            12.w,
            Expanded(
              child: TextFormField(
                controller: _life,
                enabled: byLife,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Useful life', isDense: true, suffixText: 'yrs'),
              ),
            ),
          ]),
          12.h,
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _salvage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Salvage value', isDense: true, prefixText: '₹ '),
              ),
            ),
            12.w,
            Expanded(
              child: _dateField(
                  crm, 'Start (else purchase)', _depStart ?? _purchaseDate, _pickDepStart),
            ),
          ]),
          8.h,
          Text(
              byLife
                  ? 'Straight line: equal charge each year. Uses the useful life, or the rate if no life is set.'
                  : 'Written-down value: a fixed % of the reducing book value each year (a rate is required).',
              style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          6.h,
        ],
      ]),
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
