import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/ad_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/campaign_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/day_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_forms.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// One campaign's own page (opened from any campaign row): its figures for the range, budget, the daily records (with the by-hand entry),
/// its ads, and the work members logged against it.
Future<void> showCampaignDetail(BuildContext context, WidgetRef ref, String id) => showHubForm<void>(context, CampaignDetailView(id: id), maxWidth: 840);

class CampaignDetailView extends ConsumerStatefulWidget {
  const CampaignDetailView({super.key, required this.id});
  final String id;

  @override
  ConsumerState<CampaignDetailView> createState() => _CampaignDetailViewState();
}

class _CampaignDetailViewState extends ConsumerState<CampaignDetailView> {
  String? _error;
  bool _busy = false;

  Future<bool> _confirm(String title, String body, {String yes = 'Delete', required String keyPrefix}) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(key: Key('${keyPrefix}_no'), onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
            FilledButton(key: Key('${keyPrefix}_yes'), style: FilledButton.styleFrom(backgroundColor: Mkt.bad), onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
          ],
        ),
      ) ??
      false;

  Future<void> _deleteCampaign(HubCampaign c) async {
    if (!await _confirm('Delete this campaign?', '"${c.title}" and its daily figures and ads will be removed. A campaign that has leads or logged work cannot be deleted: mark it Completed instead.', keyPrefix: 'det_delete')) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(marketingCampaignHubServiceProvider).deleteCampaign(c.id);
      refreshCampaignHub(ref);
      if (mounted) Navigator.pop(context);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() { _error = r.message; _busy = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _deleteDay(DayRecord d) async {
    if (!await _confirm('Remove this day?', 'The figures for ${hubDay(d.day)} will be removed from the campaign.', yes: 'Remove', keyPrefix: 'det_day_delete')) return;
    try {
      await ref.read(marketingCampaignHubServiceProvider).deleteDay(d.id);
      refreshCampaignHub(ref);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() => _error = r.message);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Widget _stat(String key, String label, String value) => Container(
        key: Key(key),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: Mkt.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: mktText(15, weight: FontWeight.w800))),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, weight: FontWeight.w600, color: Mkt.inkSoft)),
        ]),
      );

  Widget _section(String title, Widget child, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(title, style: mktText(13, weight: FontWeight.w800))), ?trailing]),
          const SizedBox(height: 6),
          child,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(hubCampaignDetailProvider(widget.id));
    return async.when(
      loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(12), child: AppErrorView(error: e, onRetry: () => ref.invalidate(hubCampaignDetailProvider(widget.id)))),
      data: (d) => _body(d),
    );
  }

  Widget _body(HubCampaignDetail d) {
    final c = d.campaign;
    final now = d.kpis.now;
    final f = ref.watch(teamFilterProvider);
    final range = MktDateRangePill.label(f.from, f.to);
    final dates = [if (c.startDate != null) hubDay(c.startDate!), if (c.endDate != null) hubDay(c.endDate!)].join(' → ');
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(c.title, key: const Key('det_title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(19, weight: FontWeight.w800))),
              IconButton(key: const Key('det_close'), visualDensity: VisualDensity.compact, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            Wrap(spacing: 6, runSpacing: 4, children: [
              HubStatusChip(key: const Key('det_status'), status: c.status, metaStatus: c.metaStatus),
              MktChip(c.brand == 'kerala' ? 'Kerala' : 'Main', color: Mkt.primaryLight),
              if (c.platform.isNotEmpty) MktChip(hubPlatformLabel(c.platform), color: Mkt.blue, icon: hubPlatformIcon(c.platform)),
              if (c.objective.isNotEmpty) MktChip(hubObjectiveLabel(c.objective), color: Mkt.teal),
            ]),
            if (dates.isNotEmpty || c.metaCampaignId.isNotEmpty || c.audienceNote.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text([if (dates.isNotEmpty) dates, if (c.metaCampaignId.isNotEmpty) 'Meta ID ${c.metaCampaignId}', if (c.audienceNote.isNotEmpty) c.audienceNote].join('  ·  '), key: const Key('det_meta_line'), style: mktText(11.5, color: Mkt.inkSoft)),
              ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(key: const Key('det_edit'), onPressed: _busy ? null : () => showCampaignEditor(context, ref, campaign: c), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
              OutlinedButton.icon(key: const Key('det_add_day'), onPressed: _busy ? null : () => showDayEditor(context, ref, campaignId: c.id), icon: const Icon(Icons.edit_calendar_outlined, size: 16), label: const Text('Type a day\'s figures')),
              OutlinedButton.icon(key: const Key('det_delete'), style: OutlinedButton.styleFrom(foregroundColor: Mkt.bad), onPressed: _busy ? null : () => _deleteCampaign(c), icon: const Icon(Icons.delete_outline_rounded, size: 16), label: const Text('Delete')),
            ]),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('det_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
            _section(
              'Figures · $range',
              LayoutBuilder(builder: (context, box) {
                final w = (box.maxWidth - 8 * 3) / 4;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in [
                    ('det_kpi_spend', 'Ad spend', hubInr(now.spend, compact: true)),
                    ('det_kpi_reach', 'Reach', hubCount(now.reach)),
                    ('det_kpi_impr', 'Impressions', hubCount(now.impressions)),
                    ('det_kpi_clicks', 'Clicks', hubCount(now.clicks)),
                    ('det_kpi_leads', 'CRM leads', hubCount(now.leads)),
                    ('det_kpi_cpl', 'Cost per lead', hubInr(now.cpl)),
                    ('det_kpi_bookings', 'Bookings', hubCount(now.bookings)),
                    ('det_kpi_revenue', 'Booking value (ex-GST)', hubInr(now.revenue, compact: true)),
                  ])
                    SizedBox(width: w.clamp(96, 400), child: _stat(s.$1, s.$2, s.$3)),
                ]);
              }),
            ),
            _section('Budget', _budget(d.budget, c)),
            _section(
              'Daily figures',
              d.days.isEmpty
                  ? const MktEmpty('No figures for this period. Import from Meta Ads Manager, or type a day.', icon: Icons.insert_chart_outlined_rounded, height: 80)
                  : Column(key: const Key('det_days'), children: [for (final day in d.days) _dayRow(day)]),
            ),
            _section(
              'Ads',
              d.ads.isEmpty
                  ? const MktEmpty('No ads added to this campaign yet.', icon: Icons.image_outlined, height: 70)
                  : Column(key: const Key('det_ads'), children: [for (final a in d.ads) _adRow(a)]),
              trailing: TextButton.icon(key: const Key('det_add_ad'), onPressed: () => showAdEditor(context, ref, campaignId: c.id), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add ad')),
            ),
            _section('Work logged by the team', _work(d.work)),
          ]),
        ),
      ),
    ]);
  }

  Widget _budget(HubBudgetRow? b, HubCampaign c) {
    if (b == null || !b.hasBudget) {
      return Text('No budget set', key: const Key('det_budget_text'), style: mktText(12.5, color: Mkt.inkSoft));
    }
    final over = b.overBy > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MktProgress(pct: (b.utilisationPct ?? 0).round(), color: over ? Mkt.bad : ((b.utilisationPct ?? 0) >= 90 ? Mkt.warn : Mkt.good), labelWidth: 46),
      const SizedBox(height: 4),
      Text(over ? '${hubInr(b.spentToDate)} spent of ${hubInr(b.budget)} · over budget by ${hubInr(b.overBy)}' : '${hubInr(b.spentToDate)} spent of ${hubInr(b.budget)} · ${hubInr(b.remaining)} left', key: const Key('det_budget_text'), style: mktText(12, color: Mkt.inkSoft)),
    ]);
  }

  Widget _dayRow(DayRecord d) => Container(
        key: Key('det_day_${d.id}'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Mkt.border))),
        child: Row(children: [
          SizedBox(width: 74, child: Text(hubDay(d.day, pattern: 'd MMM'), style: mktText(12, weight: FontWeight.w700))),
          Expanded(child: Text('${hubInr(d.spend)} · ${hubCompact(d.impressions)} impr · ${hubCount(d.clicks)} clicks · ${d.results} results', maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft))),
          MktChip(d.source == 'manual' ? 'Typed' : 'Imported', color: d.source == 'manual' ? Mkt.primaryLight : Mkt.teal),
          IconButton(key: Key('det_day_edit_${d.id}'), visualDensity: VisualDensity.compact, tooltip: 'Change', onPressed: () => showDayEditor(context, ref, campaignId: widget.id, day: d), icon: const Icon(Icons.edit_outlined, size: 16)),
          IconButton(key: Key('det_day_remove_${d.id}'), visualDensity: VisualDensity.compact, tooltip: 'Remove', onPressed: () => _deleteDay(d), icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Mkt.bad)),
        ]),
      );

  Widget _adRow(HubAdRow a) => InkWell(
        key: Key('det_ad_${a.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => showAdEditor(context, ref, ad: a),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            HubThumb(url: a.thumbUrl, format: a.format, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
              Text('${adFormatLabel(a.format)} · ${hubCompact(a.impressions)} impr · CTR ${hubPct(a.ctr)} · ${a.leads == null ? '—' : hubCount(a.leads)} CRM leads · CPL ${hubInr(a.cpl)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
              if (a.isLifetime) Padding(padding: const EdgeInsets.only(top: 2), child: HubLifetimeMark(key: Key('det_ad_lifetime_${a.id}'))),
            ])),
            const SizedBox(width: 6),
            MktChip(adVerdictLabel(a.verdict), color: adVerdictColor(a.verdict)),
          ]),
        ),
      );

  Widget _work(WorkSummary w) {
    if (w.entries == 0) return const MktEmpty('Nobody has logged work against this campaign yet. Log Activity → Campaign adds it here.', icon: Icons.history_toggle_off_rounded, height: 80);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${hubHours(w.minutes)} over ${w.entries} ${w.entries == 1 ? 'entry' : 'entries'}', key: const Key('det_work_total'), style: mktText(12.5, weight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 6, children: [
        for (final m in w.members)
          Container(
            key: Key('det_work_member_${m.memberId}'),
            padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
            decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Mkt.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [MktAvatar(m.name, size: 22), const SizedBox(width: 6), Flexible(child: Text('${m.name} · ${hubHours(m.minutes)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, weight: FontWeight.w600)))]),
          ),
      ]),
      const SizedBox(height: 8),
      for (final e in w.recent)
        Padding(
          key: Key('det_work_entry_${e.id}'),
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 56, child: Text(hubDay(e.day, pattern: 'd MMM'), style: mktText(11, color: Mkt.inkSoft))),
            Expanded(child: Text('${e.member.isEmpty ? '' : '${e.member}: '}${e.workedOn}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12))),
            const SizedBox(width: 6),
            Text(hubHours(e.minutes), style: mktText(11, color: Mkt.inkSoft)),
          ]),
        ),
    ]);
  }
}
