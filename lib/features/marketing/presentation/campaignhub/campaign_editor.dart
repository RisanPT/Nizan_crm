import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_forms.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Create a campaign, or change [campaign]: name, brand, platform, objective, status, dates, budget, Meta ID. The budget is the campaign's
/// TOTAL budget (Budget & Spend reads spend against it); leave it blank for "No budget set". A NEW campaign's brand starts at
/// [defaultBrand] — Kerala unless told otherwise (the ads run only on the Kerala account); editing keeps the campaign's own brand.
/// Returns the saved campaign.
Future<HubCampaign?> showCampaignEditor(BuildContext context, WidgetRef ref, {HubCampaign? campaign, String defaultBrand = 'kerala'}) =>
    showHubForm<HubCampaign>(context, _CampaignForm(campaign: campaign, defaultBrand: defaultBrand));

class _CampaignForm extends ConsumerStatefulWidget {
  const _CampaignForm({this.campaign, required this.defaultBrand});
  final HubCampaign? campaign;
  final String defaultBrand;

  @override
  ConsumerState<_CampaignForm> createState() => _CampaignFormState();
}

class _CampaignFormState extends ConsumerState<_CampaignForm> {
  late final _title = TextEditingController(text: widget.campaign?.title ?? '');
  late final _budget = TextEditingController(text: (widget.campaign?.budget ?? 0) > 0 ? _plain(widget.campaign!.budget) : '');
  late final _daily = TextEditingController(text: (widget.campaign?.dailyBudget ?? 0) > 0 ? _plain(widget.campaign!.dailyBudget) : '');
  late final _metaId = TextEditingController(text: widget.campaign?.metaCampaignId ?? '');
  late final _audience = TextEditingController(text: widget.campaign?.audienceNote ?? '');
  late final _notes = TextEditingController(text: widget.campaign?.notes ?? '');
  late String _brand = widget.campaign?.brand ?? widget.defaultBrand;
  late String _platform = widget.campaign?.platform ?? '';
  late String _objective = widget.campaign?.objective ?? '';
  late String _status = widget.campaign?.status ?? 'active';
  late DateTime? _start = DateTime.tryParse(widget.campaign?.startDate ?? '');
  late DateTime? _end = DateTime.tryParse(widget.campaign?.endDate ?? '');
  bool _saving = false;
  String? _error;

  static String _plain(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_title, _budget, _daily, _metaId, _audience, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: (start ? _start : _end) ?? now, firstDate: DateTime(now.year - 3), lastDate: DateTime(now.year + 3));
    if (d != null) setState(() => start ? _start = d : _end = d);
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Give the campaign a name.');
      return;
    }
    final budget = parseHubNumber(_budget.text);
    final daily = parseHubNumber(_daily.text);
    if (budget == null || daily == null) {
      setState(() => _error = 'A budget must be an amount in rupees (or blank for none).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final editing = widget.campaign != null;
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'brand': _brand,
      'platform': _platform,
      'objective': _objective,
      'status': _status,
      'budget': budget,
      'dailyBudget': daily,
      'metaCampaignId': _metaId.text.trim(),
      'audienceNote': _audience.text.trim(),
      'notes': _notes.text.trim(),
      if (editing || _start != null) 'startDate': _start == null ? null : TeamFilter.day(_start!),
      if (editing || _end != null) 'endDate': _end == null ? null : TeamFilter.day(_end!),
    };
    try {
      final saved = await ref.read(marketingCampaignHubServiceProvider).saveCampaign(body, id: widget.campaign?.id);
      refreshCampaignHub(ref);
      if (mounted) Navigator.pop(context, saved);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() { _error = r.message; _saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Widget _datePill(String id, String label, DateTime? value, bool start) => Row(mainAxisSize: MainAxisSize.min, children: [
        MktPill(key: Key(id), label: value == null ? label : hubDay(TeamFilter.day(value)), icon: Icons.calendar_today_outlined, trailing: false, onTap: () => _pick(start)),
        if (value != null) IconButton(key: Key('${id}_clear'), visualDensity: VisualDensity.compact, tooltip: 'Clear', onPressed: () => setState(() => start ? _start = null : _end = null), icon: const Icon(Icons.close_rounded, size: 16)),
      ]);

  @override
  Widget build(BuildContext context) {
    final editing = widget.campaign != null;
    return HubFormFrame(
      keyPrefix: 'cmp',
      title: editing ? 'Edit campaign' : 'New campaign',
      saving: _saving,
      error: _error,
      saveLabel: editing ? 'Save' : 'Create campaign',
      onSave: _save,
      children: [
        TextField(key: const Key('cmp_title'), controller: _title, decoration: hubDec('Campaign name', hint: 'Bridal Campaign – Nov')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(key: const Key('cmp_brand'), isExpanded: true, initialValue: _brand, decoration: hubDec('Brand'), items: const [DropdownMenuItem(value: 'main', child: Text('Main')), DropdownMenuItem(value: 'kerala', child: Text('Kerala'))], onChanged: (v) => setState(() => _brand = v ?? _brand))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(key: const Key('cmp_status'), isExpanded: true, initialValue: _status, decoration: hubDec('Status', helper: (widget.campaign?.metaStatus ?? '').isEmpty ? null : 'Follows Meta (${widget.campaign!.metaStatus}): the sync sets it'), items: [for (final s in kHubStatuses) DropdownMenuItem(value: s.$1, child: Text(s.$2))], onChanged: (v) => setState(() => _status = v ?? _status))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(key: const Key('cmp_platform'), isExpanded: true, initialValue: _platform, decoration: hubDec('Platform'), items: [const DropdownMenuItem(value: '', child: Text('Not set')), for (final p in kHubPlatforms) DropdownMenuItem(value: p.$1, child: Text(p.$2))], onChanged: (v) => setState(() => _platform = v ?? ''))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(key: const Key('cmp_objective'), isExpanded: true, initialValue: _objective, decoration: hubDec('Objective'), items: [const DropdownMenuItem(value: '', child: Text('Not set')), for (final o in kHubObjectives) DropdownMenuItem(value: o.$1, child: Text(o.$2))], onChanged: (v) => setState(() => _objective = v ?? ''))),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _datePill('cmp_start', 'Start date', _start, true),
          _datePill('cmp_end', 'End date', _end, false),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: TextField(key: const Key('cmp_budget'), controller: _budget, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: hubDec('Total budget (₹)', helper: 'Blank = no budget set'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(key: const Key('cmp_daily'), controller: _daily, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: hubDec('Daily budget (₹)'))),
        ]),
        const SizedBox(height: 10),
        TextField(key: const Key('cmp_meta_id'), controller: _metaId, decoration: hubDec('Meta campaign ID (optional)', helper: 'Lets a Meta Ads Manager import find this campaign even if it is renamed there; the Meta leads that came from it are added to it.')),
        const SizedBox(height: 10),
        TextField(key: const Key('cmp_audience'), controller: _audience, decoration: hubDec('Audience (optional)', hint: 'Brides 22–35, Kerala')),
        const SizedBox(height: 10),
        TextField(key: const Key('cmp_notes'), controller: _notes, minLines: 2, maxLines: 4, decoration: hubDec('Notes')),
      ],
    );
  }
}
