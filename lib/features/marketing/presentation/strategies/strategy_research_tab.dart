import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/strategy_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_editors.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_exports.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_widgets.dart';
import 'package:nizan_crm/features/marketing/services/strategy_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart' show teamFilterProvider;

/// Strategies & Developments → Research & Insights: market research, trend notes, competitor analysis and opportunities that team members
/// enter once (with a link to the file). The strip counts them by kind; Key Insights and Opportunity Areas are lists of what was entered.
/// (The document's "Market Trend Index" is not drawn: nothing entered measures a trend, so any figure would be invented.)
class StrategyResearchTab extends ConsumerWidget {
  const StrategyResearchTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(strategyResearchProvider);
    final setup = strategySetupOf(ref);
    ref.listen(teamFilterProvider, (_, _) {
      final q = ref.read(researchQueryProvider);
      if (q.page != 1) ref.read(researchQueryProvider.notifier).state = ResearchQuery(kind: q.kind, q: q.q);
    });
    return RefreshIndicator(
      onRefresh: () async => refreshStrategies(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshStrategies(ref))]),
        data: (d) {
          final c = d.counts;
          return ListView(
            key: const Key('strategies_research_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 180, children: [
                MktKpiCard(
                  key: const Key('rs_kpi_trend'),
                  icon: Icons.show_chart_rounded,
                  value: enquiryTrendValue(d.enquiryTrend),
                  label: d.enquiryTrend.label,
                  note: enquiryTrendNote(d.enquiryTrend),
                  good: d.enquiryTrend.change == null || d.enquiryTrend.change == 0 ? null : d.enquiryTrend.change! > 0,
                  tint: Mkt.teal,
                ),
                MktKpiCard(key: const Key('rs_kpi_report'), icon: Icons.description_outlined, value: '${c.report}', label: 'Research Reports', tint: Mkt.primary),
                MktKpiCard(key: const Key('rs_kpi_insight'), icon: Icons.insights_rounded, value: '${c.marketInsight}', label: 'Market Insights', tint: Mkt.blue),
                MktKpiCard(key: const Key('rs_kpi_competitor'), icon: Icons.compare_arrows_rounded, value: '${c.competitor}', label: 'Competitor Analysis', tint: Mkt.pink),
                MktKpiCard(key: const Key('rs_kpi_opportunity'), icon: Icons.lightbulb_outline_rounded, value: '${c.opportunity}', label: 'Opportunities', tint: Mkt.good),
              ]),
              const SizedBox(height: 12),
              MktGrid(breakpoint: 900, rows: [
                [
                  (6, _FindingList(key: const Key('rs_key_insights'), title: 'Key Insights', icon: Icons.insights_rounded, empty: 'No market insight entered in this period.', items: d.keyInsights)),
                  (6, _FindingList(key: const Key('rs_opportunities'), title: 'Opportunity Areas', icon: Icons.lightbulb_outline_rounded, empty: 'No opportunity entered in this period.', items: d.opportunities)),
                ],
                [(12, _Findings(d: d, setup: setup))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

class _FindingList extends StatelessWidget {
  const _FindingList({super.key, required this.title, required this.icon, required this.empty, required this.items});
  final String title, empty;
  final IconData icon;
  final List<Finding> items;

  @override
  Widget build(BuildContext context) => MktCard(
        title: title,
        icon: icon,
        child: items.isEmpty
            ? MktEmpty(empty, icon: icon, height: 120)
            : Column(children: [
                for (final f in items)
                  InkWell(
                    key: Key('rs_item_${f.id}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: f.link.isEmpty ? null : () => _open(f.link),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 32, height: 32, decoration: BoxDecoration(color: Mkt.tint(findingColor(f.kind), 0.12), borderRadius: BorderRadius.circular(9)), child: Icon(findingIcon(f.kind), size: 17, color: findingColor(f.kind))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                            if (f.summary.isNotEmpty) Text(f.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ]),
      );
}

class _Findings extends ConsumerStatefulWidget {
  const _Findings({required this.d, required this.setup});
  final ResearchData d;
  final StrategySetup setup;
  @override
  ConsumerState<_Findings> createState() => _FindingsState();
}

class _FindingsState extends ConsumerState<_Findings> {
  late final _search = TextEditingController(text: ref.read(researchQueryProvider).q);
  bool _exporting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(ResearchQuery q) => ref.read(researchQueryProvider.notifier).state = q;

  bool _mine(Finding f) => widget.setup.canManage || (widget.setup.meId != null && f.authorId == widget.setup.meId);

  Future<void> _delete(Finding f) async {
    final yes = await confirmStrategyDelete(context, title: 'Delete this finding?', body: '"${f.title}" is removed. The file it links to is not touched.');
    if (!yes) return;
    try {
      await ref.read(marketingStrategyServiceProvider).deleteFinding(f.id);
      refreshStrategies(ref);
    } on TeamRefusal catch (r) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final all = await ref.read(marketingStrategyServiceProvider).research(ref.read(teamFilterProvider), ref.read(researchQueryProvider).copyWithPage(1), limit: 100);
      await downloadCsv('research-findings.csv', findingsCsv(all.items));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final q = ref.watch(researchQueryProvider);
    final mayAdd = widget.setup.canManage || widget.setup.meId != null;
    return MktCard(
      title: 'Findings',
      subtitle: 'Entered by team members, once',
      icon: Icons.manage_search_rounded,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            TextButton.icon(key: const Key('rs_export'), onPressed: _exporting ? null : _export, icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Export')),
            if (mayAdd) TextButton(key: const Key('rs_new'), onPressed: () => showFindingEditor(context, ref), child: Text('+ Add Finding', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.primary))),
          ]),
        ),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final f in const [('all', 'All'), ('report', 'Reports'), ('market_insight', 'Insights'), ('competitor', 'Competitors'), ('opportunity', 'Opportunities')]) MktFilterChip(key: Key('rs_kind_${f.$1}'), label: f.$2, selected: q.kind == f.$1, onTap: () => _set(ResearchQuery(kind: f.$1, q: q.q))),
          SizedBox(width: 220, child: TextField(key: const Key('rs_search'), controller: _search, onChanged: (v) => _set(ResearchQuery(kind: q.kind, q: v)), style: mktText(13), decoration: strategySearchDec('Search findings…'))),
        ]),
        const SizedBox(height: 8),
        if (d.items.isEmpty) MktEmpty(q.kind == 'all' && q.q.isEmpty ? 'No findings in this period. Use Add Finding.' : 'Nothing matches these filters.', icon: Icons.manage_search_rounded, height: 120),
        for (final f in d.items)
          Container(
            key: Key('rs_row_${f.id}'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Mkt.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: Mkt.tint(findingColor(f.kind), 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(findingIcon(f.kind), size: 19, color: findingColor(f.kind))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w700)),
                  if (f.summary.isNotEmpty) Text(f.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    MktChip(findingKindLabel(f.kind), color: findingColor(f.kind)),
                    Text([strategyDay(f.date, pattern: 'd MMM yyyy'), if (f.author.isNotEmpty) f.author, if (f.brand == 'kerala') 'Kerala'].join(' · '), style: mktText(10.5, color: Mkt.inkSoft)),
                    for (final t in f.tags.take(4)) MktChip('#$t', color: Mkt.grey),
                  ]),
                ]),
              ),
              if (f.link.isNotEmpty) IconButton(key: Key('rs_open_${f.id}'), tooltip: 'Open the file', visualDensity: VisualDensity.compact, onPressed: () => _open(f.link), icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Mkt.primary)),
              if (_mine(f)) ...[
                IconButton(key: Key('rs_edit_${f.id}'), tooltip: 'Edit', visualDensity: VisualDensity.compact, onPressed: () => showFindingEditor(context, ref, finding: f), icon: const Icon(Icons.edit_outlined, size: 18)),
                IconButton(key: Key('rs_delete_${f.id}'), tooltip: 'Delete', visualDensity: VisualDensity.compact, onPressed: () => _delete(f), icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Mkt.bad)),
              ],
            ]),
          ),
        const SizedBox(height: 4),
        StrategyPager(keyPrefix: 'rs', page: d.page, pageSize: d.pageSize, total: d.total, shown: d.items.length, onPage: (n) => _set(ResearchQuery(kind: q.kind, q: q.q, page: n))),
      ]),
    );
  }
}

extension on ResearchQuery {
  ResearchQuery copyWithPage(int page) => ResearchQuery(kind: kind, q: q, page: page);
}

/// "+12%" / "−8%" / "—" — the enquiry trend's change (nothing to compare with is "—", never 0%).
String enquiryTrendValue(EnquiryTrend t) => t.change == null ? '—' : '${t.change! > 0 ? '+' : t.change! < 0 ? '−' : ''}${t.change!.abs()}%';

/// What the change is made of, in words: "84 enquiries so far in Q4 2026 vs 75 in the same 49 days of Q3 2026".
String enquiryTrendNote(EnquiryTrend t) => !t.known
    ? 'Our own CRM leads, quarter on quarter'
    : '${t.now} so far in ${t.quarter} vs ${t.before} in the same ${t.elapsedDays} day${t.elapsedDays == 1 ? '' : 's'} of ${t.previousQuarter}';

