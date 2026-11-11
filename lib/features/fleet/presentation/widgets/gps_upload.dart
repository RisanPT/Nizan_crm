import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/fleet/controllers/gps_km_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/vehicle_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart' show formatKm;
import 'package:nizan_crm/features/fleet/data/gps_km.dart';
import 'package:nizan_crm/features/fleet/data/gps_report_parser.dart';

final _long = DateFormat('d MMM yyyy');

/// Pick a GPS km report (Excel / CSV), show what was read, and — once the user
/// confirms — save it. Returns the result, or null if the user backed out or it
/// failed (the failure has been shown).
Future<GpsUploadResult?> pickAndUploadGpsReport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final FilePickerResult? picked;
  try {
    picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
      withData: true,
    );
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not open the file picker. Please try again.')));
    return null;
  }
  if (picked == null || !context.mounted) return null;

  final file = picked.files.single;
  final bytes = file.bytes;
  if (bytes == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not read the selected file.')));
    return null;
  }

  final parse = parseGpsReport(bytes, file.name);

  // Which plates are already vehicles here — a failure just means we can't say.
  var known = <String, String>{};
  try {
    final vehicles = await ref.read(vehiclesProvider.future);
    known = {
      for (final v in vehicles) ...{
        gpsRegKey(v.registrationNumber): v.name,
        if (v.name.isNotEmpty) gpsRegKey(v.name): v.name,
      },
    };
  } catch (_) {}
  if (!context.mounted) return null;

  final go = await showDialog<bool>(
    context: context,
    builder: (_) => GpsUploadPreview(fileName: file.name, parse: parse, knownVehicles: known),
  );
  if (go != true || !context.mounted) return null;

  messenger.showSnackBar(SnackBar(content: Text('Uploading ${parse.rows.length} days…')));
  try {
    final result = await ref.read(gpsKmServiceProvider).upload(fileName: file.name, rows: parse.rows);
    messenger.hideCurrentSnackBar();
    return result;
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    return null;
  }
}

/// "22 days saved: 12 new, 10 updated."
String gpsUploadSummary(GpsUploadResult r) {
  final parts = [
    if (r.created > 0) '${r.created} new',
    if (r.updated > 0) '${r.updated} updated',
    if (r.unchanged > 0) '${r.unchanged} already saved',
  ];
  return '${r.rows} day${r.rows == 1 ? '' : 's'} read${parts.isEmpty ? '' : ': ${parts.join(', ')}'}'
      '${r.skipped > 0 ? ' · ${r.skipped} skipped' : ''}.';
}

/// What was read from the file, before anything is saved.
class GpsUploadPreview extends StatelessWidget {
  final String fileName;
  final GpsReportParse parse;

  /// regKey → CRM vehicle name, for telling which plates are known.
  final Map<String, String> knownVehicles;

  const GpsUploadPreview({
    super.key,
    required this.fileName,
    required this.parse,
    required this.knownVehicles,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final from = parse.from == null ? null : DateTime.tryParse(parse.from!);
    final to = parse.to == null ? null : DateTime.tryParse(parse.to!);
    final vehicles = parse.vehicleDays;

    return AlertDialog(
      backgroundColor: crm.surface,
      title: const Text('Upload GPS km report'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fileName, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              const SizedBox(height: 10),
              if (!parse.hasRows)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.error_outline, size: 18, color: crm.destructive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(parse.error ?? 'Nothing to upload.',
                        style: TextStyle(fontSize: 13, color: crm.textPrimary)),
                  ),
                ])
              else ...[
                Text(
                  '${parse.rows.length} day${parse.rows.length == 1 ? '' : 's'} · '
                  '${vehicles.length} vehicle${vehicles.length == 1 ? '' : 's'} · '
                  '${formatKm(parse.totalKm)} km',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: crm.textPrimary),
                ),
                if (from != null && to != null)
                  Text('${_long.format(from)} → ${_long.format(to)}',
                      style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                const SizedBox(height: 12),
                for (final e in vehicles.entries) _vehicleRow(crm, e.key, e.value),
                if (parse.skipped > 0) ...[
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline, size: 15, color: crm.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${parse.skipped} row${parse.skipped == 1 ? '' : 's'} will be skipped:\n'
                        '${parse.problems.take(4).join('\n')}'
                        '${parse.problems.length > 4 ? '\n…' : ''}',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 10),
                Text(
                  'Days already saved are updated, so it is safe to upload overlapping reports.',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(parse.hasRows ? 'Cancel' : 'Close')),
        if (parse.hasRows)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Upload ${parse.rows.length} day${parse.rows.length == 1 ? '' : 's'}'),
          ),
      ],
    );
  }

  Widget _vehicleRow(CrmTheme crm, String plate, int days) {
    final name = knownVehicles[gpsRegKey(plate)];
    final known = name != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(known ? Icons.check_circle_outline : Icons.help_outline,
            size: 16, color: known ? crm.success : crm.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            known
                ? '$plate · $name'
                : knownVehicles.isEmpty
                    ? plate
                    : '$plate · not one of your vehicles yet',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: crm.textPrimary),
          ),
        ),
        Text('$days day${days == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
      ]),
    );
  }
}
