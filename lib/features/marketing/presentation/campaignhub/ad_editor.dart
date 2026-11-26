import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_forms.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';

/// Add an ad to a campaign, or change [ad]. The creative and its thumbnail are LINKS (Drive or cloud: nothing is uploaded); the figures are the
/// ad's lifetime totals as the Meta Ads Manager shows them.
Future<void> showAdEditor(BuildContext context, WidgetRef ref, {HubAdRow? ad, String? campaignId}) => showHubForm<void>(context, _AdForm(ad: ad, campaignId: campaignId));

class _AdForm extends ConsumerStatefulWidget {
  const _AdForm({this.ad, this.campaignId});
  final HubAdRow? ad;
  final String? campaignId;

  @override
  ConsumerState<_AdForm> createState() => _AdFormState();
}

class _AdFormState extends ConsumerState<_AdForm> {
  late final _name = TextEditingController(text: widget.ad?.name ?? '');
  late final _set = TextEditingController(text: widget.ad?.adSetName ?? '');
  late final _creative = TextEditingController(text: widget.ad?.creativeUrl ?? '');
  late final _thumb = TextEditingController(text: widget.ad?.thumbUrl ?? '');
  late final Map<String, TextEditingController> _n = {
    'impressions': TextEditingController(text: _show(widget.ad?.impressions)),
    'clicks': TextEditingController(text: _show(widget.ad?.clicks)),
    'spend': TextEditingController(text: _show(widget.ad?.spend)),
    'results': TextEditingController(text: _show(widget.ad?.results)),
  };
  late String? _campaign = widget.ad?.campaignId ?? widget.campaignId;
  late String _format = widget.ad?.format ?? 'image';
  late String _status = widget.ad?.status ?? 'active';
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  static String _show(num? v) => v == null || v == 0 ? '' : (v is double && v != v.roundToDouble() ? v.toString() : v.round().toString());

  @override
  void dispose() {
    for (final c in [_name, _set, _creative, _thumb, ..._n.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_campaign == null) {
      setState(() => _error = 'Choose the campaign this ad belongs to.');
      return;
    }
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Give the ad a name.');
      return;
    }
    final nums = {for (final e in _n.entries) e.key: parseHubNumber(e.value.text)};
    if (nums.values.any((v) => v == null)) {
      setState(() => _error = 'Impressions, clicks, spend and results must be numbers (or blank).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'campaignId': _campaign,
      'name': _name.text.trim(),
      'adSetName': _set.text.trim(),
      'format': _format,
      'status': _status,
      'creativeUrl': _creative.text.trim(),
      'thumbUrl': _thumb.text.trim(),
      'impressions': nums['impressions'],
      'clicks': nums['clicks'],
      'spend': nums['spend'],
      'results': nums['results'],
    };
    try {
      await ref.read(marketingCampaignHubServiceProvider).saveAd(body, id: widget.ad?.id);
      refreshCampaignHub(ref);
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

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this ad?'),
        content: Text('"${widget.ad!.name}" and its figures will be removed from the campaign.'),
        actions: [TextButton(key: const Key('ad_delete_no'), onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')), FilledButton(key: const Key('ad_delete_yes'), style: FilledButton.styleFrom(backgroundColor: Mkt.bad), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(marketingCampaignHubServiceProvider).deleteAd(widget.ad!.id);
      refreshCampaignHub(ref);
      if (mounted) Navigator.pop(context);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() { _error = r.message; _deleting = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.ad != null;
    final campaigns = ref.watch(hubSetupProvider).maybeWhen(data: (s) => s.campaigns, orElse: () => const <HubCampaignOption>[]);
    // the campaign being edited stays selectable even if the list has not loaded
    final options = [...campaigns, if (_campaign != null && !campaigns.any((c) => c.id == _campaign)) HubCampaignOption(id: _campaign!, title: widget.ad?.campaign ?? 'This campaign')];
    return HubFormFrame(
      keyPrefix: 'ad',
      title: editing ? 'Edit ad' : 'Add an ad',
      saving: _saving || _deleting,
      error: _error,
      saveLabel: editing ? 'Save' : 'Add ad',
      onSave: _save,
      leading: editing ? Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('ad_delete'), onPressed: _saving || _deleting ? null : _delete, icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Mkt.bad), label: Text('Delete', style: mktText(12.5, weight: FontWeight.w700, color: Mkt.bad)))) : null,
      children: [
        DropdownButtonFormField<String>(key: const Key('ad_campaign'), isExpanded: true, initialValue: options.any((c) => c.id == _campaign) ? _campaign : null, decoration: hubDec('Campaign'), items: [for (final c in options) DropdownMenuItem(value: c.id, child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => _campaign = v)),
        const SizedBox(height: 10),
        TextField(key: const Key('ad_name'), controller: _name, decoration: hubDec('Ad name', hint: 'Bridal Transformation – Reel 1')),
        const SizedBox(height: 10),
        TextField(key: const Key('ad_set'), controller: _set, decoration: hubDec('Ad set (optional)', hint: 'Brides 22–35')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(key: const Key('ad_format'), isExpanded: true, initialValue: _format, decoration: hubDec('Format'), items: [for (final f in kAdFormats) DropdownMenuItem(value: f.$1, child: Text(f.$2))], onChanged: (v) => setState(() => _format = v ?? _format))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(key: const Key('ad_status'), isExpanded: true, initialValue: _status, decoration: hubDec('Status'), items: [for (final s in kAdStatuses) DropdownMenuItem(value: s.$1, child: Text(s.$2))], onChanged: (v) => setState(() => _status = v ?? _status))),
        ]),
        const SizedBox(height: 10),
        TextField(key: const Key('ad_creative'), controller: _creative, decoration: hubDec('Link to the creative (optional)', hint: 'https://drive.google.com/…')),
        const SizedBox(height: 10),
        TextField(key: const Key('ad_thumb'), controller: _thumb, decoration: hubDec('Thumbnail link (optional)', hint: 'https://…')),
        const SizedBox(height: 14),
        Text('Lifetime figures', style: mktText(13, weight: FontWeight.w800)),
        Text('As the Meta Ads Manager shows them for this ad. Results are the platform\'s own count.', style: mktText(11.5, color: Mkt.inkSoft)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in const [('impressions', 'Impressions'), ('clicks', 'Clicks'), ('spend', 'Spend (₹)'), ('results', 'Results')]) SizedBox(width: 132, child: TextField(key: Key('ad_${f.$1}'), controller: _n[f.$1], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: hubDec(f.$2))),
        ]),
      ],
    );
  }
}
