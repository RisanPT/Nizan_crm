import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamBrand;
import 'package:nizan_crm/features/marketing/presentation/campaignhub/day_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_export.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/meta_import.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/reports/marketing_reports_panel.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

export 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_export.dart' show CsvSaver, hubCsvSaverProvider;

/// Campaigns → Reports & Insights: the reports (Campaign, Creative, Lead, Conversion, Spend, Audience, Overview, Performance — the ones each
/// tab's Export downloads) for the selected dates and brand, each
/// downloaded as a CSV with the same numbers the screens show; what the numbers say; and the history of what was imported from Meta Ads
/// Manager. A downloaded report is kept in "Saved reports" (opening it downloads it again for its period and brand); the "Scheduled
/// reports" make the weekly / monthly / quarterly ones by themselves and tell the marketing managers (backend /api/marketing/reports).
///
/// The report a saved one downloads: a scheduled one's (weekly / monthly / quarterly — the campaign-wise report), else its own.
String hubReportTypeFor(String kind, Iterable<String> types) => types.contains(kind) ? kind : 'campaign';
class HubReportsTab extends ConsumerStatefulWidget {
  const HubReportsTab({super.key});

  @override
  ConsumerState<HubReportsTab> createState() => _HubReportsTabState();
}

class _HubReportsTabState extends ConsumerState<HubReportsTab> {
  String? _busy;

  static const _icons = {
    'campaign': Icons.campaign_outlined,
    'creative': Icons.image_outlined,
    'lead': Icons.filter_alt_outlined,
    'conversion': Icons.trending_up_rounded,
    'spend': Icons.account_balance_wallet_outlined,
    'audience': Icons.groups_outlined,
    'overview': Icons.home_outlined,
    'performance': Icons.bar_chart_rounded,
  };
  static const _colors = {'campaign': Mkt.primary, 'creative': Mkt.pink, 'lead': Mkt.blue, 'conversion': Mkt.good, 'spend': Mkt.warn, 'audience': Mkt.teal, 'overview': Mkt.primaryLight, 'performance': Mkt.blue};

  /// Downloads the [type] report for the shared dates and brand; one made here is kept in "Saved reports" ([keep]).
  Future<void> _download(String type, String title, {bool keep = true}) async {
    setState(() => _busy = type);
    try {
      await exportHubReport(context, ref, type);
      if (!mounted) return;
      final f = ref.read(teamFilterProvider);
      if (keep) await keepGeneratedReport(ref, module: 'campaigns', kind: type, name: title, from: f.fromDay, to: f.toDay, brand: f.brand.wire);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(hubReportsProvider);
    final f = ref.watch(teamFilterProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCampaignHub(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshCampaignHub(ref))]),
        data: (r) => ListView(
          key: const Key('hub_reports_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text('Download a report as a CSV for ${MktDateRangePill.label(f.from, f.to)} · ${f.brand == TeamBrand.all ? 'All brands' : f.brand.label}.', key: const Key('rp_scope'), style: mktText(12, color: Mkt.inkSoft)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth >= 1000 ? 5 : (box.maxWidth >= 620 ? 3 : (box.maxWidth >= 420 ? 2 : 1));
              final w = (box.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(spacing: 10, runSpacing: 10, children: [for (final c in r.cards) SizedBox(width: w, child: _card(c))]);
            }),
            const SizedBox(height: 12),
            MktGrid(rows: [
              [(7, _InsightsCard(r: r)), (5, MetaCard(meta: r.meta, onImport: () => startMetaImport(context, ref), onTypeDay: () => showDayEditor(context, ref)))],
            ]),
            const SizedBox(height: 12),
            MarketingReportsPanel(
              module: 'campaigns',
              onOpen: (saved) {
                final type = hubReportTypeFor(saved.kind, r.cards.map((c) => c.type));
                final title = r.cards.where((c) => c.type == type).map((c) => c.title).firstOrNull ?? saved.name;
                showSavedReportPeriod(ref, saved);
                _download(type, title, keep: false);
              },
            ),
            const SizedBox(height: 12),
            _HistoryCard(r: r),
          ],
        ),
      ),
    );
  }

  Widget _card(ReportCard c) {
    final color = _colors[c.type] ?? Mkt.primary;
    return Container(
      key: Key('rp_card_${c.type}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Mkt.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: Mkt.tint(color, 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(_icons[c.type] ?? Icons.description_outlined, size: 19, color: color)),
        const SizedBox(height: 8),
        Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w800)),
        Text(c.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
        const SizedBox(height: 4),
        Text('${c.rows} ${c.rows == 1 ? 'row' : 'rows'}', key: Key('rp_rows_${c.type}'), style: mktText(11, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: Key('rp_download_${c.type}'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: _busy == null ? () => _download(c.type, c.title) : null,
          icon: _busy == c.type ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 16),
          label: const Text('CSV'),
        ),
      ]),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.r});
  final ReportsData r;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Insights',
        icon: Icons.lightbulb_outline_rounded,
        subtitle: 'Only what the numbers show',
        child: r.insights.isEmpty ? const MktEmpty('Nothing to point out for this period.', icon: Icons.lightbulb_outline_rounded, height: 80) : Column(key: const Key('rp_insights'), crossAxisAlignment: CrossAxisAlignment.start, children: [for (final i in r.insights) InsightLine(insight: i)]),
      );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.r});
  final ReportsData r;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Meta Import History',
        icon: Icons.history_rounded,
        subtitle: 'Each file imported, and each day typed by hand',
        child: r.imports.isEmpty
            ? const MktEmpty('Nothing imported yet.', icon: Icons.history_rounded, height: 80)
            : Column(key: const Key('rp_imports'), children: [
                for (final i in r.imports)
                  Container(
                    key: Key('rp_import_${i.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Mkt.border))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(i.source == 'manual' ? Icons.edit_calendar_outlined : Icons.upload_file_rounded, size: 16, color: Mkt.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.source == 'manual' ? 'Typed by hand' : (i.fileName.isEmpty ? 'File import' : i.fileName), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700)),
                          Text([if (i.at != null) DateFormat('d MMM yyyy, h:mm a').format(i.at!), if (i.byName.isNotEmpty) i.byName].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
                          Text(i.source == 'manual' ? (i.from.isEmpty ? '' : hubDay(i.from)) : '${i.written} ${importUnit(i.level, i.written)} written · ${i.matched} rows matched${i.unmatched > 0 ? ' · ${i.unmatched} not matched' : ''}${i.created > 0 ? ' · ${i.created} campaigns created' : ''}${i.adsCreated > 0 ? ' · ${i.adsCreated} ads added' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11)),
                          if (i.unmatchedNames.isNotEmpty) Text('Not matched: ${i.unmatchedNames.join(', ')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.warn)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
      );
}
