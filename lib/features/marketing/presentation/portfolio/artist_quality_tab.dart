import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/media/asset_viewer.dart' show showAssetViewer;
import 'package:nizan_crm/features/marketing/presentation/portfolio/work_review_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart' show AssetThumb;
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';

/// The periods Artist Quality looks over (days back from today): a week of works says little about an artist.
const kQualityPeriods = [(30, 'Last 30 days'), (90, 'Last 90 days'), (182, 'Last 6 months'), (365, 'Last 12 months')];

String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// [days] back from today, as the server's from–to.
({String from, String to}) qualityPeriod(int days, {DateTime? today}) {
  final t = today ?? DateTime.now();
  final end = DateTime(t.year, t.month, t.day);
  return (from: _day(end.subtract(Duration(days: days - 1))), to: _day(end));
}

/// Creative Portfolio → Artist Quality: what the clients said about each artist's works (the review the CRM sends the morning after a
/// work), so the team sees whose work needs a look and in what. Every artist on a work gets its rating. The artists needing a look
/// come first (complaints, low ratings, the lowest average); tapping one opens their works — the worst first — with the work's own
/// photos and videos and the client's words.
class ArtistQualityTab extends ConsumerStatefulWidget {
  const ArtistQualityTab({super.key});

  @override
  ConsumerState<ArtistQualityTab> createState() => _ArtistQualityTabState();
}

class _ArtistQualityTabState extends ConsumerState<ArtistQualityTab> {
  int _days = 90;
  bool _attentionOnly = false;
  String _sort = 'attention';

  List<ArtistQuality> _sorted(List<ArtistQuality> rows) {
    final list = [...rows.where((r) => !_attentionOnly || r.needsAttention)];
    switch (_sort) {
      case 'lowest':
        list.sort((a, b) => (a.avgScore ?? 99).compareTo(b.avgScore ?? 99));
      case 'highest':
        list.sort((a, b) => (b.avgScore ?? -1).compareTo(a.avgScore ?? -1));
      case 'reviews':
        list.sort((a, b) => b.reviewed.compareTo(a.reviewed));
      case 'name':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      default:
        break; // the server's order: needing a look first
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final period = qualityPeriod(_days);
    final async = ref.watch(qualityReportProvider(period));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(qualityReportProvider),
      child: ListView(
        key: const Key('quality_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final (d, label) in kQualityPeriods) MktFilterChip(key: Key('quality_period_$d'), label: label, selected: _days == d, onTap: () => setState(() => _days = d)),
          ]),
          const SizedBox(height: 4),
          Text('From the client reviews of the works in these days (by event day). Every artist on a work gets its rating.', style: mktText(11.5, color: Mkt.inkSoft)),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(qualityReportProvider)),
            data: (r) => _body(context, r, period),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, QualityReport r, ({String from, String to}) period) {
    final t = r.totals;
    final rows = _sorted(r.artists);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MktKpiRow(minWidth: 150, children: [
        MktKpiCard(key: const Key('quality_kpi_reviewed'), icon: Icons.rate_review_outlined, value: '${t.reviewed}', label: 'Works reviewed', note: t.waiting > 0 ? '${t.waiting} waiting for the client' : null, tint: Mkt.primary),
        MktKpiCard(key: const Key('quality_kpi_avg'), icon: Icons.star_rounded, value: t.avgScore == null ? '—' : '${ratingText(t.avgScore!)} ★', label: 'Average rating', tint: Mkt.warn),
        MktKpiCard(key: const Key('quality_kpi_nps'), icon: Icons.thumb_up_alt_outlined, value: t.nps == null ? '—' : '${t.nps}', label: 'NPS', tint: Mkt.good),
        MktKpiCard(key: const Key('quality_kpi_complaints'), icon: Icons.report_gmailerrorred_rounded, value: '${t.complaints}', label: 'Complaints', tint: Mkt.bad),
        MktKpiCard(key: const Key('quality_kpi_low'), icon: Icons.trending_down_rounded, value: '${t.low}', label: 'Rated below 3.5', tint: Mkt.pink),
      ]),
      const SizedBox(height: 12),
      MktCard(
        title: 'Artists',
        subtitle: rows.length == r.artists.length ? '${r.artists.length} with reviewed or waiting works' : '${rows.length} of ${r.artists.length} need a look',
        icon: Icons.brush_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            KeyedSubtree(
              key: const Key('quality_sort'),
              child: MktDropdownPill<String>(
                value: _sort,
                icon: Icons.sort_rounded,
                options: const [('attention', 'Needs a look first'), ('lowest', 'Lowest rating'), ('highest', 'Highest rating'), ('reviews', 'Most reviews'), ('name', 'Name A–Z')],
                onChanged: (v) => setState(() => _sort = v),
              ),
            ),
            FilterChip(
              key: const Key('quality_attention_only'),
              label: const Text('Only those needing a look'),
              selected: _attentionOnly,
              onSelected: (v) => setState(() => _attentionOnly = v),
            ),
          ]),
          const SizedBox(height: 8),
          if (r.artists.isEmpty)
            const MktEmpty('No client review in these days yet. Reviews are sent the morning after a work is completed.', icon: Icons.rate_review_outlined, height: 140)
          else if (rows.isEmpty)
            const MktEmpty('No artist needs a look in these days.', icon: Icons.verified_outlined, height: 120)
          else
            for (final a in rows) _ArtistRow(row: a, onTap: () => showArtistQuality(context, artistKey: a.key, name: a.name, from: period.from, to: period.to)),
        ]),
      ),
    ]);
  }
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.row, required this.onTap});
  final ArtistQuality row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = row;
    return InkWell(
      key: Key('quality_artist_${a.key}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Mkt.border))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MktAvatar(a.name, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13.5, weight: FontWeight.w800))),
                const SizedBox(width: 8),
                if (a.avgScore != null) MktChip('★ ${ratingText(a.avgScore!)}', color: ratingColor(a.avgScore!), solid: true),
              ]),
              const SizedBox(height: 2),
              Text(
                [
                  '${a.reviewed} reviewed',
                  if (a.waiting > 0) '${a.waiting} waiting',
                  if (a.nps != null) 'NPS ${a.nps}',
                  if (a.assets > 0) a.assets == 1 ? '1 photo or video in the gallery' : '${a.assets} photos and videos in the gallery',
                ].join(' · '),
                style: mktText(11.5, color: Mkt.inkSoft),
              ),
              const SizedBox(height: 5),
              Wrap(spacing: 5, runSpacing: 5, children: [
                if (a.complaints > 0) MktChip('${a.complaints} complaint${a.complaints == 1 ? '' : 's'}', color: Mkt.bad, icon: Icons.report_gmailerrorred_rounded),
                if (a.low > 0) MktChip('${a.low} rated below 3.5', color: Mkt.pink),
                if (a.weakest != null) MktChip('Weakest: ${a.weakest!.label} ${ratingText(a.weakest!.value)}★', key: Key('quality_weakest_${a.key}'), color: Mkt.warn),
                if (a.great > 0) MktChip('${a.great} rated 4.5+', color: Mkt.good),
                if (a.lastIssueDay.isNotEmpty) MktChip('Last issue ${workDayText(a.lastIssueDay, pattern: 'd MMM')}', color: Mkt.inkSoft),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Mkt.inkSoft),
        ]),
      ),
    );
  }
}

/// One artist's quality: their figures, how the clients rate each area, and their works — the ones needing a look first — each with
/// the client's words and the work's photos and videos (tap one to play it). [from]/[to] default to the last 90 days.
Future<void> showArtistQuality(BuildContext context, {required String artistKey, required String name, String? from, String? to}) {
  final p = from != null && to != null ? (from: from, to: to) : qualityPeriod(90);
  final body = ArtistQualityView(artistKey: artistKey, name: name, from: p.from, to: p.to);
  if (MediaQuery.sizeOf(context).width >= 760) {
    return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820, maxHeight: 820), child: body)));
  }
  return showDialog<void>(context: context, useSafeArea: true, builder: (_) => Dialog.fullscreen(child: body));
}

class ArtistQualityView extends ConsumerWidget {
  const ArtistQualityView({super.key, required this.artistKey, required this.name, required this.from, required this.to});
  final String artistKey, name, from, to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(artistQualityProvider((key: artistKey, from: from, to: to)));
    return Padding(
      key: const Key('artist_quality'),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          MktAvatar(name, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: mktText(16, weight: FontWeight.w800)),
              Text('Client reviews · ${workDayText(from, pattern: 'd MMM yyyy')} – ${workDayText(to, pattern: 'd MMM yyyy')}', style: mktText(11.5, color: Mkt.inkSoft)),
            ]),
          ),
          IconButton(key: const Key('artist_quality_close'), tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(artistQualityProvider)),
            data: (d) => ListView(children: [
              _figures(d.artist),
              if (d.artist.areas.isNotEmpty) ...[const SizedBox(height: 12), _areas(d.artist)],
              const SizedBox(height: 14),
              Text('Works — the ones needing a look first', style: mktText(13, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final w in d.works) _WorkCard(work: w),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _figures(ArtistQuality a) => Wrap(spacing: 8, runSpacing: 8, children: [
        MktChip(a.avgScore == null ? 'No rating yet' : 'Average ★ ${ratingText(a.avgScore!)}', color: a.avgScore == null ? Mkt.grey : ratingColor(a.avgScore!), solid: a.avgScore != null),
        MktChip('${a.reviewed} reviewed', color: Mkt.primary),
        if (a.waiting > 0) MktChip('${a.waiting} waiting', color: Mkt.blue),
        if (a.nps != null) MktChip('NPS ${a.nps}', color: Mkt.good),
        if (a.complaints > 0) MktChip('${a.complaints} complaint${a.complaints == 1 ? '' : 's'}', color: Mkt.bad),
        if (a.low > 0) MktChip('${a.low} rated below 3.5', color: Mkt.pink),
      ]);

  /// Each area the clients rated, lowest first, as a bar out of 5.
  Widget _areas(ArtistQuality a) {
    final areas = [...a.areas]..sort((x, y) => x.value.compareTo(y.value));
    return Container(
      key: const Key('artist_quality_areas'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Mkt.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How the clients rate each area', style: mktText(12.5, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final ar in areas)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              SizedBox(width: 130, child: Text(ar.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, weight: ar.value < 4 ? FontWeight.w800 : FontWeight.w500, color: ar.value < 4 ? ratingColor(ar.value) : Mkt.ink))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (ar.value / 5).clamp(0, 1), minHeight: 7, color: ratingColor(ar.value), backgroundColor: Mkt.border))),
              const SizedBox(width: 8),
              SizedBox(width: 62, child: Text('${ratingText(ar.value)}★ (${ar.count})', textAlign: TextAlign.right, style: mktText(11, color: Mkt.inkSoft))),
            ]),
          ),
      ]),
    );
  }
}

/// One work in an artist's quality: what it was, the client's review, and its photos and videos.
class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work});
  final QualityWork work;

  @override
  Widget build(BuildContext context) {
    final w = work.work;
    // each item carries the work, so opening it shows the review beside it
    final items = [for (final i in work.items) Asset.fromJson({...i, 'work': work.raw})];
    return Container(
      key: Key('quality_work_${w.bookingId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: (w.review?.needsAttention ?? false) ? Mkt.bad.withValues(alpha: 0.4) : Mkt.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WorkDetailsPanel(work: w),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text('No photo or video of this work in the gallery yet.', style: mktText(11.5, color: Mkt.inkSoft))
        else
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => InkWell(
                key: Key('quality_item_${items[i].id}'),
                onTap: () => showAssetViewer(context, items[i]),
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: AssetThumb(asset: items[i], height: 68)),
                    const SizedBox(height: 3),
                    Text(items[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, weight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
