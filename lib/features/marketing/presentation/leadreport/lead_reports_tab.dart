import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/reports/marketing_reports_panel.dart';
import 'package:nizan_crm/features/marketing/services/marketing_reports_service.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';

const _kCardIcons = {
  'summary': Icons.summarize_outlined,
  'sources': Icons.hub_outlined,
  'campaigns': Icons.campaign_outlined,
  'team': Icons.groups_2_outlined,
  'conversion': Icons.trending_up_rounded,
};

/// Lead Report → Reports: pick a report, look at it for the chosen date range and brand, and download it as a CSV (built from the CRM's
/// leads each time). A downloaded report is kept in "Saved reports" (its kind, period and brand — opening it runs it again); the
/// "Scheduled reports" make the weekly / monthly ones by themselves and tell the marketing managers (backend /api/marketing/reports).

/// The Lead Report card a saved report opens: a scheduled one's kind, else its own.
String leadReportTypeFor(String kind) => switch (kind) {
  'weekly' => 'summary',
  'monthly-conversion' => 'conversion',
  'campaign-performance' => 'campaigns',
  _ => kLeadReportCards.any((c) => c.$1 == kind) ? kind : 'summary',
};
class LeadReportsTab extends ConsumerStatefulWidget {
  const LeadReportsTab({super.key});

  @override
  ConsumerState<LeadReportsTab> createState() => _LeadReportsTabState();
}

class _LeadReportsTabState extends ConsumerState<LeadReportsTab> {
  bool _saving = false;

  /// Downloads the [type] report for the shared dates and brand; a report made here is kept in "Saved reports" ([keep]).
  Future<void> _download(String type, {bool keep = true}) async {
    setState(() => _saving = true);
    try {
      final t = await exportLeadReport(context, ref, type);
      if (t != null && keep && mounted) await keepGeneratedReport(ref, module: 'leads', kind: t.type, name: t.title, from: t.from, to: t.to, brand: t.brand);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// A saved report: its period and brand on the shared filter, its card picked, and downloaded again (not kept a second time).
  void _openSaved(MarketingSavedReport r) {
    final type = leadReportTypeFor(r.kind);
    showSavedReportPeriod(ref, r);
    ref.read(selectedLeadReportProvider.notifier).state = type;
    _download(type, keep: false);
  }

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(selectedLeadReportProvider);
    final async = ref.watch(leadReportTableProvider(type));
    return RefreshIndicator(
      onRefresh: () async => refreshLeadReport(ref),
      child: ListView(
        key: const Key('lr_reports_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          MktKpiRow(minWidth: 190, children: [
            for (final c in kLeadReportCards)
              InkWell(
                key: Key('lr_report_${c.$1}'),
                borderRadius: BorderRadius.circular(13),
                onTap: () => ref.read(selectedLeadReportProvider.notifier).state = c.$1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: type == c.$1 ? Mkt.primarySoft : Mkt.card, borderRadius: BorderRadius.circular(13), border: Border.all(color: type == c.$1 ? Mkt.primary : Mkt.border)),
                  child: Row(children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: Mkt.tint(Mkt.primary, 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(_kCardIcons[c.$1], size: 18, color: Mkt.primary)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w800)),
                        Text(c.$3, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft, height: 1.2)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 90), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => AppErrorView(error: e, onRetry: () => refreshLeadReport(ref)),
            data: (t) => MktCard(
              title: t.title,
              subtitle: '${dayLabel(t.from)} – ${dayLabel(t.to, pattern: 'd MMM yyyy')} · ${t.brand == 'all' ? 'All brands' : (t.brand == 'kerala' ? 'Kerala' : 'Main')}',
              icon: Icons.description_outlined,
              trailing: OutlinedButton.icon(
                key: const Key('lr_report_download'),
                onPressed: _saving ? null : () => _download(t.type),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(_saving ? 'Building…' : 'Download CSV'),
              ),
              child: _Preview(t: t),
            ),
          ),
          const SizedBox(height: 12),
          MarketingReportsPanel(module: 'leads', onOpen: _openSaved),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.t});
  final LeadReportTable t;

  static const _shown = 10;

  String _cell(Object? v) => v == null ? '' : (v is num ? numText(v) : v.toString());

  @override
  Widget build(BuildContext context) {
    if (t.rows.isEmpty) return const MktEmpty('Nothing to report in this date range.', icon: Icons.description_outlined, height: 120);
    final cols = t.columns.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MktTable(
        key: const Key('lr_report_table'),
        minWidth: cols * 130.0,
        columns: [for (var i = 0; i < cols; i++) MktCol(t.columns[i].toUpperCase(), flex: i == 0 ? 2 : 1, align: i == 0 ? Alignment.centerLeft : Alignment.centerRight)],
        rows: [
          for (final r in t.rows.take(_shown)) [for (var i = 0; i < cols; i++) lrCell(i < r.length ? _cell(r[i]) : '', bold: i == 0)],
        ],
      ),
      LrNote(t.rows.length > _shown ? 'Showing the first $_shown of ${t.rows.length} rows — the download has them all.' : '${t.rows.length} row${t.rows.length == 1 ? '' : 's'}.'),
      if (t.truncated) const LrNote('Only the first 20,000 rows are included — narrow the date range.', icon: Icons.warning_amber_rounded, color: Mkt.bad),
      if ((t.type == 'leads' || t.type == 'followups') && !t.canContact) const LrNote('Phone numbers are left out — only a Marketing Manager gets them.', icon: Icons.lock_outline_rounded),
    ]);
  }
}
