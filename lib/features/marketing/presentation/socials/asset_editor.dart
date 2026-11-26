import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/asset_search.dart' show normalizeKeyword, splitKeywords;
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_link.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/keyword_input.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/link_pickers.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_widgets.dart' show shootDay;
import 'package:nizan_crm/features/marketing/services/marketing_eod_service.dart' show marketingEodAccessProvider;
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

/// Add an asset (a link to the file where the team keeps it — Drive or any cloud link) or change [asset]. Used by Socials → Content & Assets
/// and the Creative Portfolio gallery: one library. An asset can be attached to a shoot (picked here, or [shootId] when it is added from
/// the shoot): it is then filed under the shoot's brand and portfolio and carries its tag — the server decides, so those fields lock.
///
/// [manager]: the person may approve, reject and mark final outputs (from the asset list); left out, it is asked of the server.
Future<void> showAssetEditor(BuildContext context, WidgetRef ref, {Asset? asset, String? shootId, String? brand, bool? manager}) {
  final form = _AssetForm(asset: asset, shootId: shootId, brand: brand, manager: manager);
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: form)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: form));
}

class _AssetForm extends ConsumerStatefulWidget {
  const _AssetForm({this.asset, this.shootId, this.brand, this.manager});
  final Asset? asset;
  final String? shootId, brand;
  final bool? manager;

  @override
  ConsumerState<_AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends ConsumerState<_AssetForm> {
  late final _title = TextEditingController(text: widget.asset?.title ?? '');
  late final _url = TextEditingController(text: widget.asset?.url ?? '');
  late final _thumb = TextEditingController(text: widget.asset?.thumbUrl ?? '');
  late final _portfolio = TextEditingController(text: widget.asset?.portfolio ?? 'Main (Company)');
  late final _page = TextEditingController(text: widget.asset?.page ?? '');
  // the keywords as chips; what is typed but not yet added stays in [_tagText] and is added on Save
  late List<String> _tags = [...?widget.asset?.tags];
  final _tagText = TextEditingController();
  late final _owner = TextEditingController(text: widget.asset?.ownerName ?? '');
  late String? _shootId = widget.asset?.shootId ?? widget.shootId;
  String? _shootTitle;
  // the work (CRM booking) it shows: its client's review then shows with it in the gallery
  late String? _bookingId = widget.asset?.bookingId;
  String? _bookingTitle;
  late String _kind = widget.asset?.kind ?? 'still';
  // a Type the person picked (or an existing asset's) is never changed behind their back
  late bool _kindChosen = widget.asset != null;
  late String _brand = widget.asset?.brand ?? widget.brand ?? 'main';
  late String _stage = widget.asset?.stage ?? 'raw';
  late bool _final = widget.asset?.isFinal ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _url, _thumb, _portfolio, _page, _tagText, _owner]) {
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
        // the chips, and anything still typed in the field (once each; the server refuses more than the most, with the reason)
        'tags': {..._tags, ...splitKeywords(_tagText.text).map(normalizeKeyword).where((t) => t.isNotEmpty)}.toList(),
        if (_manager || _final != (widget.asset?.isFinal ?? false)) 'isFinal': _final,
        'ownerName': _owner.text.trim(),
        'shootId': _shootId,
        'bookingId': _bookingId,
      }, id: widget.asset?.id);
      refreshPortfolio(ref);
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

  Future<void> _pickShoot() async {
    final r = await pickShoot(context, selectedId: _shootId);
    if (r == null || !mounted) return;
    setState(() {
      _shootId = r.value?.id;
      _shootTitle = r.value == null ? null : '${r.value!.title} · ${shootDay(r.value!.shootDate, pattern: 'd MMM')}';
      if (r.value != null) {
        // what the server will file it under — shown so the form agrees with what is saved
        _brand = r.value!.brand;
        _portfolio.text = r.value!.brand == 'kerala' ? 'Kerala' : 'Main (Company)';
      }
    });
  }

  Future<void> _pickBooking() async {
    final r = await pickBooking(context, selectedId: _bookingId);
    if (r == null || !mounted) return;
    setState(() {
      _bookingId = r.value?.id;
      _bookingTitle = r.value == null ? null : ['#${r.value!.bookingNumber}', r.value!.customerName].where((x) => x.length > 1).join(' · ');
    });
  }

  String? _bookingLabel() {
    if (_bookingId == null) return null;
    if (_bookingTitle != null) return _bookingTitle;
    final w = widget.asset?.work;
    return w != null && widget.asset?.bookingId == _bookingId && w.title.isNotEmpty ? w.title : 'The linked booking';
  }

  /// What the Work field says under it: where the work comes from, and what it brings.
  String _bookingNote() {
    final w = widget.asset?.work;
    if (_bookingId == null && w != null && widget.asset?.bookingId == null) return 'From the shoot: ${w.title}. Pick a booking only if this shows another work.';
    if (_bookingId == null) return 'Pick the booking this shows — its artists and the client\'s review then show with it.';
    return 'Its artists and the client\'s review of it show with this item in the gallery.';
  }

  String? _shootLabel() {
    if (_shootId == null) return null;
    return _shootTitle ?? ref.watch(shootDetailProvider(_shootId!)).maybeWhen(data: (d) => '${d.summary.title} · ${shootDay(d.summary.shootDate, pattern: 'd MMM')}', orElse: () => 'The linked shoot');
  }

  static const _videoKinds = ['reel', 'film', 'bts'];
  static const _managerStages = ['approved', 'rejected'];

  /// A Marketing Manager (approves, rejects, marks final outputs).
  bool get _manager => widget.manager ?? ref.watch(marketingEodAccessProvider).maybeWhen(data: (a) => a.isManager, orElse: () => false);

  /// The link is a video FILE the app plays (a Dropbox mp4/mov/m4v/webm). Until the person picks a Type themselves, a video link makes the
  /// Type a Reel — left as "Still" the asset would count as a photo and never play.
  void _linkChanged() {
    if (MediaLink.parse(_url.text.trim()).canPlayInline && !_kindChosen && !_videoKinds.contains(_kind)) _kind = 'reel';
    setState(() {});
  }

  Widget? _linkHint() {
    if (!MediaLink.parse(_url.text.trim()).canPlayInline) return null;
    final video = _videoKinds.contains(_kind);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(video ? 'This is a video file — it plays in the app.' : 'This link is a video file — set the Type to Reel, Film or BTS so it counts as a video.', key: const Key('asset_link_hint'), style: mktText(11.5, weight: FontWeight.w600, color: video ? Mkt.good : Mkt.warn)),
    );
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
            TextField(key: const Key('asset_url'), controller: _url, onChanged: (_) => _linkChanged(), decoration: _dec('Link to the file', hint: 'https://drive.google.com/…')),
            ?_linkHint(),
            const SizedBox(height: 10),
            TextField(key: const Key('asset_thumb'), controller: _thumb, decoration: _dec('Thumbnail link (optional)', hint: 'https://…')),
            const SizedBox(height: 10),
            LinkField(
              key: const Key('asset_shoot'),
              label: 'Shoot',
              icon: Icons.videocam_outlined,
              hint: 'No shoot',
              value: _shootLabel(),
              onTap: _pickShoot,
              onClear: () => setState(() {
                _shootId = null;
                _shootTitle = null;
              }),
              note: _shootId == null ? null : 'Filed under the shoot\'s brand and portfolio, with its tag.',
            ),
            const SizedBox(height: 10),
            LinkField(
              key: const Key('asset_booking'),
              label: 'Work (booking)',
              icon: Icons.event_note_outlined,
              hint: 'No booking',
              value: _bookingLabel(),
              onTap: _pickBooking,
              onClear: () => setState(() {
                _bookingId = null;
                _bookingTitle = null;
              }),
              note: _bookingNote(),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                // the outer key makes the menu show a Type that was set for the person (a video link → Reel); the inner key is the one tests and taps use
                child: KeyedSubtree(key: ValueKey('asset_kind_$_kind'), child: DropdownButtonFormField<String>(key: const Key('asset_kind'), isExpanded: true, initialValue: _kind, decoration: _dec('Type'), items: [for (final k in kAssetKinds) DropdownMenuItem(value: k.$1, child: Text(k.$2))], onChanged: (v) => setState(() {
                  _kind = v ?? _kind;
                  _kindChosen = true;
                }))),
              ),
              const SizedBox(width: 10),
              Expanded(
                // with a shoot the brand is the shoot's (the server decides): shown, not changeable
                child: KeyedSubtree(key: ValueKey('asset_brand_${_shootId != null}_$_brand'), child: DropdownButtonFormField<String>(key: const Key('asset_brand'), isExpanded: true, initialValue: _brand, decoration: _dec(_shootId == null ? 'Brand' : 'Brand (from the shoot)'), items: const [DropdownMenuItem(value: 'main', child: Text('Main')), DropdownMenuItem(value: 'kerala', child: Text('Kerala'))], onChanged: _shootId != null ? null : (v) => setState(() => _brand = v ?? _brand))),
              ),
            ]),
            const SizedBox(height: 10),
            // approving and rejecting are a Marketing Manager's call (the server refuses them from anyone else)
            DropdownButtonFormField<String>(
              key: const Key('asset_stage'),
              isExpanded: true,
              initialValue: _stage,
              decoration: _dec('Production stage', hint: null),
              items: [
                for (final s in kAssetStages)
                  DropdownMenuItem(value: s.$1, enabled: _manager || !_managerStages.contains(s.$1) || s.$1 == widget.asset?.stage, child: Text(_manager || !_managerStages.contains(s.$1) ? s.$2 : '${s.$2} (Marketing Manager)')),
              ],
              onChanged: (v) => setState(() => _stage = v ?? _stage),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(key: const Key('asset_portfolio'), controller: _portfolio, enabled: _shootId == null, decoration: _dec(_shootId == null ? 'Portfolio' : 'Portfolio (from the shoot)', hint: 'Main (Company), Kerala…'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(key: const Key('asset_page'), controller: _page, decoration: _dec('Page', hint: 'Bridal Makeup…'))),
            ]),
            const SizedBox(height: 10),
            KeywordInput(
              keywords: _tags,
              controller: _tagText,
              onChanged: (v) => setState(() => _tags = v),
              note: _shootId == null ? 'Keywords are how the team finds this later — the look, the occasion, the place, the artist.' : 'Keywords are how the team finds this later. The shoot adds its category as one more.',
            ),
            const SizedBox(height: 10),
            TextField(key: const Key('asset_owner'), controller: _owner, decoration: _dec('Owner', hint: 'You, unless you name someone')),
            SwitchListTile(key: const Key('asset_final'), contentPadding: EdgeInsets.zero, title: const Text('This is a final output'), subtitle: _manager ? null : Text('A Marketing Manager marks final outputs.', style: mktText(11.5, color: Mkt.inkSoft)), value: _final, onChanged: _manager ? (v) => setState(() => _final = v) : null),
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
