import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

// Export (CSV) for every tab of the Campaigns hub. Each tab downloads ONE of the server's reports (GET /campaign-hub/reports/:type) for the
// selected dates and brand — the same numbers the tab shows, built in one place (backend utils/marketingCampaignStats.js reportTable):
//   Overview → overview · All Campaigns → campaign · Performance → performance (its Audiences section → audience) ·
//   Creatives & Ads → creative · Budget & Spend → spend · Leads & Conversions → lead.

typedef CsvSaver = Future<void> Function(String filename, List<List<Object?>> rows);

/// How a report is saved as a CSV; a test overrides it to capture the file.
final hubCsvSaverProvider = Provider<CsvSaver>((ref) => downloadCsv);

/// Fetch the [type] report for the shared dates and brand and save it as a CSV (the columns, then the rows, under the server's file name).
Future<void> exportHubReport(BuildContext context, WidgetRef ref, String type) async {
  final t = await ref.read(marketingCampaignHubServiceProvider).report(ref.read(teamFilterProvider), type);
  await ref.read(hubCsvSaverProvider)(t.filename, [t.columns, ...t.rows]);
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.title} saved as ${t.filename}')));
}

/// A tab's "Export CSV" button (key `hub_export_<type>`): downloads the [type] report. It shows it is busy and cannot be pressed twice.
class HubExportButton extends ConsumerStatefulWidget {
  const HubExportButton({super.key, required this.type, this.label = 'Export CSV'});
  final String type;
  final String label;

  @override
  ConsumerState<HubExportButton> createState() => _HubExportButtonState();
}

class _HubExportButtonState extends ConsumerState<HubExportButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await exportHubReport(context, ref, widget.type);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        key: Key('hub_export_${widget.type}'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12), foregroundColor: Mkt.primary, side: const BorderSide(color: Mkt.border)),
        onPressed: _busy ? null : _run,
        icon: _busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 16),
        label: Text(widget.label, style: mktText(12, weight: FontWeight.w700, color: Mkt.primary)),
      );
}

/// The row at the top of a tab that holds its Export button, on the right.
class HubExportBar extends StatelessWidget {
  const HubExportBar({super.key, required this.type, this.note});
  final String type;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: note == null ? const SizedBox.shrink() : Text(note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft))),
          const SizedBox(width: 8),
          HubExportButton(type: type),
        ]),
      );
}
