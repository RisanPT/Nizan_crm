import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_export.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';

// Audiences & placements: who the ads reached and where, from Meta Ads Manager BREAKDOWN exports (Breakdown → By delivery: Age, Gender,
// Platform / Placement) imported in the Campaigns hub. Each segment's spend and the platform's results (Meta's leads / messages) for the
// selected dates and brand. The CRM does not record a lead's age or placement, so CRM leads cannot be split this way — the views say so.

const _kNoBreakdown = 'No audience breakdown imported yet. In Ads Manager use Breakdown → By delivery → Age / Gender / Placement, export, and import the file.';
const _kMetaNote = 'Results are Meta\'s — the CRM does not record a lead\'s age or placement.';

/// The Overview's "Top audiences & placements": the top 3 segments by age, by gender and by placement.
class TopAudiencesCard extends StatelessWidget {
  const TopAudiencesCard({super.key, required this.audiences, this.onMore});
  final HubAudiences audiences;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Top audiences & placements',
        icon: Icons.groups_outlined,
        subtitle: _kMetaNote,
        link: onMore == null || audiences.isEmpty ? null : 'View all',
        onLink: onMore,
        linkKey: const Key('ov_audiences_more'),
        child: audiences.isEmpty
            ? const MktEmpty(_kNoBreakdown, icon: Icons.groups_outlined, height: 120)
            : LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth >= 600 ? 3 : 1;
                final w = (box.maxWidth - 12 * (cols - 1)) / cols;
                return Wrap(key: const Key('ov_audiences'), spacing: 12, runSpacing: 12, children: [
                  for (final f in kAudienceFields) SizedBox(width: w, child: _TopList(field: f, data: audiences.of(f.$1))),
                ]);
              }),
      );
}

class _TopList extends StatelessWidget {
  const _TopList({required this.field, required this.data});
  final (String, String) field;
  final AudienceField data;

  @override
  Widget build(BuildContext context) => Column(key: Key('ov_audience_${field.$1}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(field.$2, style: mktText(11.5, weight: FontWeight.w800, color: Mkt.inkSoft)),
        const SizedBox(height: 4),
        if (data.rows.isEmpty)
          Text('Not in the imported files', style: mktText(11.5, color: Mkt.inkSoft))
        else
          for (final r in data.rows.take(3))
            Padding(
              key: Key('ov_audience_${field.$1}_${r.segment}'),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r.segment, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700))),
                  const SizedBox(width: 6),
                  Text(hubInr(r.spend, compact: true), style: mktText(12, weight: FontWeight.w700)),
                ]),
                Text('${hubCount(r.results)} results · ${hubInr(r.costPerResult)} per result', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
              ]),
            ),
      ]);
}

/// The Performance tab's "Audiences & placements": the top 12 segments of each breakdown, with the 'audience' export.
class AudiencesSection extends ConsumerStatefulWidget {
  const AudiencesSection({super.key});

  @override
  ConsumerState<AudiencesSection> createState() => _AudiencesSectionState();
}

class _AudiencesSectionState extends ConsumerState<AudiencesSection> {
  String _field = 'age';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(hubAudiencesProvider);
    return MktCard(
      title: 'Audiences & placements',
      icon: Icons.groups_outlined,
      subtitle: _kMetaNote,
      trailing: const HubExportButton(type: 'audience'),
      child: async.when(
        loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(hubAudiencesProvider)),
        data: (a) {
          if (a.isEmpty) return const MktEmpty(_kNoBreakdown, icon: Icons.groups_outlined, height: 130);
          final data = a.of(_field);
          final shown = data.rows.take(12).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            HubToggle(keyPrefix: 'hp_aud', value: _field, options: kAudienceFields, onChanged: (v) => setState(() => _field = v)),
            const SizedBox(height: 10),
            if (data.rows.isEmpty)
              MktEmpty('No ${_field == 'placement' ? 'placement' : _field} breakdown in the imported files for these dates.', icon: Icons.groups_outlined, height: 100)
            else
              MktTable(
                key: Key('hp_audience_table_$_field'),
                minWidth: 760,
                columns: const [
                  MktCol('Segment', flex: 4),
                  MktCol('Spend', flex: 2, align: Alignment.centerRight),
                  MktCol('Share', flex: 2, align: Alignment.centerRight),
                  MktCol('Impressions', flex: 2, align: Alignment.centerRight),
                  MktCol('Clicks', flex: 2, align: Alignment.centerRight),
                  MktCol('CTR', flex: 2, align: Alignment.centerRight),
                  MktCol('Results', flex: 2, align: Alignment.centerRight),
                  MktCol('Cost / result', flex: 2, align: Alignment.centerRight),
                ],
                rowKeys: [for (final r in shown) Key('hp_audience_${_field}_${r.segment}')],
                rows: [
                  for (final r in shown)
                    [
                      Text(r.segment, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700)),
                      Text(hubInr(r.spend, compact: true), style: mktText(12)),
                      Text(hubPct(r.spendPct, digits: 1), style: mktText(12)),
                      Text(hubCompact(r.impressions), style: mktText(12)),
                      Text(hubCount(r.clicks), style: mktText(12)),
                      Text(hubPct(r.ctr), style: mktText(12)),
                      Text(hubCount(r.results), style: mktText(12)),
                      Text(hubInr(r.costPerResult), style: mktText(12)),
                    ],
                ],
              ),
            if (data.dimension.contains('+'))
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('Read from the ${data.dimension.replaceAll('+', ' and ')} file.', style: mktText(10.5, color: Mkt.inkSoft))),
          ]);
        },
      ),
    );
  }
}
