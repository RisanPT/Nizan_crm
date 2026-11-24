import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

/// Add an asset (a link to the file where the team keeps it — Drive or any cloud link) or change [asset]. Used by Socials → Content & Assets
/// and the Creative Portfolio gallery: one library. [shootId] attaches a new asset to a shoot (it then takes the shoot's brand).
Future<void> showAssetEditor(BuildContext context, WidgetRef ref, {Asset? asset, String? shootId, String? brand}) {
  final form = _AssetForm(asset: asset, shootId: shootId, brand: brand);
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: form)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: form));
}

class _AssetForm extends ConsumerStatefulWidget {
  const _AssetForm({this.asset, this.shootId, this.brand});
  final Asset? asset;
  final String? shootId, brand;

  @override
  ConsumerState<_AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends ConsumerState<_AssetForm> {
  late final _title = TextEditingController(text: widget.asset?.title ?? '');
  late final _url = TextEditingController(text: widget.asset?.url ?? '');
  late final _thumb = TextEditingController(text: widget.asset?.thumbUrl ?? '');
  late final _portfolio = TextEditingController(text: widget.asset?.portfolio ?? 'Main (Company)');
  late final _page = TextEditingController(text: widget.asset?.page ?? '');
  late final _tags = TextEditingController(text: (widget.asset?.tags ?? const []).join(', '));
  late String _kind = widget.asset?.kind ?? 'still';
  late String _brand = widget.asset?.brand ?? widget.brand ?? 'main';
  late String _stage = widget.asset?.stage ?? 'raw';
  late bool _final = widget.asset?.isFinal ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _url, _thumb, _portfolio, _page, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(marketingSocialsServiceProvider).saveAsset({
        'title': _title.text.trim(),
        'url': _url.text.trim(),
        'thumbUrl': _thumb.text.trim(),
        'kind': _kind,
        'brand': _brand,
        'stage': _stage,
        'portfolio': _portfolio.text.trim(),
        'page': _page.text.trim(),
        'tags': _tags.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
        'isFinal': _final,
        if (widget.asset == null && widget.shootId != null) 'shootId': widget.shootId,
      }, id: widget.asset?.id);
      refreshSocials(ref);
      if (mounted) Navigator.pop(context);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() { _error = r.message; _saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(widget.asset == null ? 'Add asset' : 'Edit asset', style: mktText(19, weight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(key: const Key('asset_title'), controller: _title, decoration: _dec('Title')),
            const SizedBox(height: 10),
            TextField(key: const Key('asset_url'), controller: _url, decoration: _dec('Link to the file', hint: 'https://drive.google.com/…')),
            const SizedBox(height: 10),
            TextField(key: const Key('asset_thumb'), controller: _thumb, decoration: _dec('Thumbnail link (optional)', hint: 'https://…')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(key: const Key('asset_kind'), isExpanded: true, initialValue: _kind, decoration: _dec('Type'), items: [for (final k in kAssetKinds) DropdownMenuItem(value: k.$1, child: Text(k.$2))], onChanged: (v) => setState(() => _kind = v ?? _kind)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(key: const Key('asset_brand'), isExpanded: true, initialValue: _brand, decoration: _dec('Brand'), items: const [DropdownMenuItem(value: 'main', child: Text('Main')), DropdownMenuItem(value: 'kerala', child: Text('Kerala'))], onChanged: (v) => setState(() => _brand = v ?? _brand)),
              ),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(key: const Key('asset_stage'), isExpanded: true, initialValue: _stage, decoration: _dec('Production stage'), items: [for (final s in kAssetStages) DropdownMenuItem(value: s.$1, child: Text(s.$2))], onChanged: (v) => setState(() => _stage = v ?? _stage)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(key: const Key('asset_portfolio'), controller: _portfolio, decoration: _dec('Portfolio', hint: 'Main (Company), Kerala…'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(key: const Key('asset_page'), controller: _page, decoration: _dec('Page', hint: 'Bridal Makeup…'))),
            ]),
            const SizedBox(height: 10),
            TextField(key: const Key('asset_tags'), controller: _tags, decoration: _dec('Tags', hint: 'bridal, reel, kerala')),
            SwitchListTile(key: const Key('asset_final'), contentPadding: EdgeInsets.zero, title: const Text('This is a final output'), value: _final, onChanged: (v) => setState(() => _final = v)),
          ]),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Mkt.border))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const Key('asset_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(key: const Key('asset_cancel'), onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 10),
            FilledButton(key: const Key('asset_save'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
          ]),
        ]),
      ),
    ]);
  }
}
