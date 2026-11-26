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

/// Type one day's paid-ads figures for a campaign (what the Meta Ads Manager shows for that day). Typing the same day again replaces it.
/// This is the by-hand path beside the file import: there is no live Meta sync.
Future<void> showDayEditor(BuildContext context, WidgetRef ref, {String? campaignId, DayRecord? day}) => showHubForm<void>(context, _DayForm(campaignId: campaignId, record: day), maxWidth: 520);

class _DayForm extends ConsumerStatefulWidget {
  const _DayForm({this.campaignId, this.record});
  final String? campaignId;
  final DayRecord? record;

  @override
  ConsumerState<_DayForm> createState() => _DayFormState();
}

class _DayFormState extends ConsumerState<_DayForm> {
  late final Map<String, TextEditingController> _n = {
    for (final k in const ['spend', 'reach', 'impressions', 'clicks', 'results']) k: TextEditingController(text: _show(widget.record, k)),
  };
  late String? _campaign = widget.campaignId;
  late DateTime _day = DateTime.tryParse(widget.record?.day ?? '') ?? DateTime.now().subtract(const Duration(days: 1));
  bool _saving = false;
  String? _error;

  static String _show(DayRecord? r, String k) {
    if (r == null) return '';
    final v = switch (k) { 'spend' => r.spend, 'reach' => r.reach, 'impressions' => r.impressions, 'clicks' => r.clicks, _ => r.results };
    return v == 0 ? '' : (v is double && v != v.roundToDouble() ? v.toString() : v.round().toString());
  }

  @override
  void dispose() {
    for (final c in _n.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _day.isAfter(now) ? now : _day, firstDate: DateTime(now.year - 3), lastDate: DateTime(now.year, now.month, now.day));
    if (d != null) setState(() => _day = d);
  }

  Future<void> _save() async {
    if (_campaign == null) {
      setState(() => _error = 'Choose the campaign.');
      return;
    }
    final nums = {for (final e in _n.entries) e.key: parseHubNumber(e.value.text)};
    if (nums.values.any((v) => v == null)) {
      setState(() => _error = 'Every figure must be a number (or blank for none).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(marketingCampaignHubServiceProvider).saveDay({'campaignId': _campaign, 'day': TeamFilter.day(_day), ...nums});
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

  @override
  Widget build(BuildContext context) {
    final campaigns = ref.watch(hubSetupProvider).maybeWhen(data: (s) => s.campaigns, orElse: () => const <HubCampaignOption>[]);
    final options = [...campaigns, if (_campaign != null && !campaigns.any((c) => c.id == _campaign)) HubCampaignOption(id: _campaign!, title: 'This campaign')];
    return HubFormFrame(
      keyPrefix: 'day',
      title: widget.record == null ? 'Type a day\'s figures' : 'Change this day',
      saving: _saving,
      error: _error,
      saveLabel: 'Save day',
      onSave: _save,
      children: [
        DropdownButtonFormField<String>(key: const Key('day_campaign'), isExpanded: true, initialValue: options.any((c) => c.id == _campaign) ? _campaign : null, decoration: hubDec('Campaign'), items: [for (final c in options) DropdownMenuItem(value: c.id, child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => _campaign = v)),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: MktPill(key: const Key('day_date'), label: hubDay(TeamFilter.day(_day), pattern: 'EEE d MMM yyyy'), icon: Icons.calendar_today_outlined, trailing: false, onTap: _pickDay)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in const [('spend', 'Spend (₹)'), ('reach', 'Reach'), ('impressions', 'Impressions'), ('clicks', 'Clicks'), ('results', 'Results')]) SizedBox(width: 140, child: TextField(key: Key('day_${f.$1}'), controller: _n[f.$1], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: hubDec(f.$2))),
        ]),
        const SizedBox(height: 8),
        Text('From the Meta Ads Manager for that one day. Reach and clicks cannot be more than impressions. Typing the same day again replaces it.', style: mktText(11.5, color: Mkt.inkSoft)),
      ],
    );
  }
}
