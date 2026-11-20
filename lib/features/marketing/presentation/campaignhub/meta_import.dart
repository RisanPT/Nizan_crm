import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/spreadsheet_reader.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_forms.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/campaign_hub_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

// "Import from Meta Ads Manager": there is NO live Meta sync, so figures come in from a file exported from Ads Manager (.csv / .xlsx). The file
// is read here in the app (the same reader as the Stock import) and can be one of three kinds — the server is told which (`level`):
//  • 'campaign'  — one row per campaign per day (the usual export);
//  • 'ad'        — one row per AD per day (Ads Manager's ad-level export: "Ad name" / "Ad ID", "Ad set name" / "Ad set ID"): the ads are found
//                  or added on the server and the Creatives & Ads tab follows the dates;
//  • 'breakdown' — one row per audience / placement segment per day (Breakdown → By delivery: Age, Gender, Platform / Placement): the
//                  Audiences & placements views.
// The server matches campaigns by Meta ID or exact name, REPLACES what it already has for the same day (re-importing the same file changes
// nothing) and reports what it could not match.

/// What one row of a file is.
enum MetaLevel {
  campaign('campaign', 'campaign-day', 'One row per campaign per day'),
  ad('ad', 'ad-day', 'One row per ad per day (an ad-level export)'),
  breakdown('breakdown', 'audience segment', 'Audience & placement breakdown (by age, gender or placement)');

  const MetaLevel(this.wire, this.unit, this.description);
  final String wire, unit, description;
}

/// "3 ad-days", "1 audience segment" — the unit of what an import writes, by the file's level ('campaign' | 'ad' | 'breakdown').
String importUnit(String level, int n) {
  final unit = MetaLevel.values.firstWhere((l) => l.wire == level, orElse: () => MetaLevel.campaign).unit;
  return n == 1 ? unit : '${unit}s';
}

/// What was read from an exported file: rows ready to send, and what was not usable.
class MetaExport {
  const MetaExport({this.rows = const [], this.warnings = const [], this.totalRows = 0, this.skipped = 0, this.level = MetaLevel.campaign});

  /// {campaign, campaignId?, day, spend, reach, impressions, clicks, results} — and ad / adId / adSet / adSetId (an ad-level file) or age /
  /// gender / platform / position (a breakdown file). Each campaign-day (ad-day, segment-day) appears once: rows of the same one are added.
  final List<Map<String, dynamic>> rows;
  final List<String> warnings;

  /// Data rows seen (below the header) and how many were not usable.
  final int totalRows, skipped;

  /// What one row of the file is.
  final MetaLevel level;

  bool get hasRows => rows.isNotEmpty;
  int get campaigns => rows.map(_keyOf).toSet().length;
  int get ads => level == MetaLevel.ad ? rows.map((r) => '${_keyOf(r)}|${_adKeyOf(r)}').toSet().length : 0;
  String? get firstDay => rows.isEmpty ? null : (rows.map((r) => r['day'] as String).toList()..sort()).first;
  String? get lastDay => rows.isEmpty ? null : (rows.map((r) => r['day'] as String).toList()..sort()).last;
}

String _keyOf(Map<String, dynamic> r) => (r['campaignId'] ?? '').toString().isNotEmpty ? 'id:${r['campaignId']}' : 'name:${r['campaign'].toString().toLowerCase()}';
String _adKeyOf(Map<String, dynamic> r) => (r['adId'] ?? '').toString().isNotEmpty ? 'id:${r['adId']}' : 'name:${(r['ad'] ?? '').toString().toLowerCase()}';

/// The columns that make a file a breakdown export, and the ones that make it ad-level.
const _breakdownCols = ['age', 'gender', 'platform', 'position'];
const _adCols = ['ad', 'adId'];

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

// The usual names of the columns in a Meta Ads Manager export, best first (a normalised header: lower case, letters and digits only).
const _aliases = <String, List<String>>{
  'campaign': ['campaignname', 'campaign', 'campaigns'],
  'campaignId': ['campaignid'],
  'day': ['day', 'date'],
  'start': ['reportingstarts', 'reportingstart', 'reportstart'],
  'end': ['reportingends', 'reportingend', 'reportend'],
  'spend': ['amountspentinr', 'amountspent', 'spendinr', 'spend', 'costinr'],
  'reach': ['reach'],
  'impressions': ['impressions'],
  'clicks': ['linkclicks', 'clicksall', 'clicks'],
  'results': ['results', 'leads'],
  // an ad-level export
  'ad': ['adname', 'ad'],
  'adId': ['adid'],
  'adSet': ['adsetname', 'adset'],
  'adSetId': ['adsetid'],
  // a breakdown export (Breakdown → By delivery)
  'age': ['age'],
  'gender': ['gender'],
  'platform': ['platform', 'publisherplatform'],
  'position': ['placement', 'platformposition', 'position'],
};

String _asStr(dynamic v) => v == null ? '' : (v is String ? v.trim() : v.toString().trim());

/// A figure in a cell: 1250, "1,250.50", "₹1,250", "INR 1250"; blank and dashes are 0; anything else is null (the row is not usable).
double? _asNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(RegExp(r'[₹,\s]|INR', caseSensitive: false), '');
  if (s.isEmpty || s == '-' || s == '—') return 0;
  return double.tryParse(s);
}

/// A day as 'YYYY-MM-DD': an Excel date, 2026-11-03, 03/11/2026 (day first, as in India), 3 Nov 2026, Nov 3, 2026 — else null.
String? _asDay(dynamic v) {
  if (v == null) return null;
  String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  if (v is DateTime) return ymd(v);
  final s = v.toString().trim();
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (iso != null) return _valid(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
  final dmy = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$').firstMatch(s);
  if (dmy != null) return _valid(int.parse(dmy[3]!), int.parse(dmy[2]!), int.parse(dmy[1]!));
  for (final p in const ['d MMM yyyy', 'dd MMM yyyy', 'MMM d, yyyy', 'd MMMM yyyy', 'MMMM d, yyyy']) {
    try {
      return ymd(DateFormat(p).parseStrict(s));
    } catch (_) {
      // not this shape
    }
  }
  return null;
}

String? _valid(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final t = DateTime(y, m, d);
  if (t.year != y || t.month != m || t.day != d) return null; // 31 Feb is not a day
  return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

/// Rows of the same campaign and day are ADDED, so the server gets each day once. For an ad-level file the same goes for each ad's day; for
/// a breakdown file for each segment's day (age, gender, platform, position) — the ads inside it are added together.
List<Map<String, dynamic>> mergeMetaRows(List<Map<String, dynamic>> rows, {MetaLevel level = MetaLevel.campaign}) {
  final by = <String, Map<String, dynamic>>{};
  for (final r in rows) {
    final k = switch (level) {
      MetaLevel.campaign => '${_keyOf(r)}|${r['day']}',
      MetaLevel.ad => '${_keyOf(r)}|${_adKeyOf(r)}|${r['day']}',
      MetaLevel.breakdown => '${_keyOf(r)}|${r['day']}|${[for (final c in _breakdownCols) r[c] ?? ''].join('|')}',
    };
    final cur = by[k];
    if (cur == null) {
      by[k] = {...r};
    } else {
      for (final f in const ['spend', 'reach', 'impressions', 'clicks', 'results']) {
        cur[f] = ((cur[f] as num) + (r[f] as num)).toDouble();
      }
      cur['spend'] = ((cur['spend'] as double) * 100).roundToDouble() / 100;
    }
  }
  return by.values.map((r) => {...r, 'reach': (r['reach'] as num).round(), 'impressions': (r['impressions'] as num).round(), 'clicks': (r['clicks'] as num).round(), 'results': (r['results'] as num).round()}).toList();
}

/// At most this many rows go in one request (the server takes at most 500)…
const kImportChunk = 250;

/// …and a request body stays under this many bytes (the server's JSON limit is 100 KB; this leaves room for the rest of the request).
const kImportChunkBytes = 90000;

/// The rows in requests of at most [maxRows] rows AND at most [maxBytes] bytes of JSON (with [overhead] bytes for the rest of the body:
/// the file name, the options). Wide ad-level or breakdown rows make byte-sized parts smaller than 250 rows.
List<List<Map<String, dynamic>>> chunkImportRows(List<Map<String, dynamic>> rows, {int maxRows = kImportChunk, int maxBytes = kImportChunkBytes, int overhead = 600}) {
  final out = <List<Map<String, dynamic>>>[];
  var part = <Map<String, dynamic>>[];
  var bytes = overhead + 2; // the [ ] of the list
  for (final r in rows) {
    final size = utf8.encode(jsonEncode(r)).length + 1; // the row and its comma
    if (part.isNotEmpty && (part.length >= maxRows || bytes + size > maxBytes)) {
      out.add(part);
      part = <Map<String, dynamic>>[];
      bytes = overhead + 2;
    }
    part.add(r);
    bytes += size;
  }
  if (part.isNotEmpty) out.add(part);
  return out;
}

/// Read an exported Meta Ads Manager file (.csv or .xlsx). Never throws: what cannot be used is explained in [MetaExport.warnings].
MetaExport parseMetaExport(Uint8List bytes, String filename, {String? sheetName}) {
  List<List<dynamic>> table;
  try {
    table = readSpreadsheetRows(bytes, filename, sheetName: sheetName);
  } catch (_) {
    return const MetaExport(warnings: ['Could not read the file. Export it from Meta Ads Manager as .csv or .xlsx and try again.']);
  }
  if (table.every((r) => r.every((c) => _asStr(c).isEmpty))) return const MetaExport(warnings: ['The file is empty.']);

  // the header row: real exports can have a title above it, so look at the first rows for the one that names the most columns
  var headerIdx = -1;
  var cols = <String, int>{};
  final scan = table.length < 25 ? table.length : 25;
  for (var i = 0; i < scan; i++) {
    final found = <String, int>{};
    final rank = <String, int>{};
    for (var c = 0; c < table[i].length; c++) {
      final n = _norm(_asStr(table[i][c]));
      if (n.isEmpty) continue;
      for (final e in _aliases.entries) {
        final r = e.value.indexOf(n);
        if (r >= 0 && (!found.containsKey(e.key) || r < rank[e.key]!)) {
          found[e.key] = c;
          rank[e.key] = r;
        }
      }
    }
    final hasDay = found.containsKey('day') || found.containsKey('start');
    if ((found.containsKey('campaign') || found.containsKey('campaignId')) && hasDay && found.length > cols.length) {
      headerIdx = i;
      cols = found;
    }
  }
  if (headerIdx < 0) {
    return MetaExport(totalRows: table.length, warnings: const ['Could not find the columns. The file needs "Campaign name", a day ("Day", or "Reporting starts" for one-day rows) and "Amount spent". In Ads Manager use Breakdown → Time → Day, then export.']);
  }
  if (!cols.containsKey('spend') && !cols.containsKey('impressions')) {
    return MetaExport(totalRows: table.length - headerIdx - 1, warnings: const ['The file has no "Amount spent" or "Impressions" column to import.']);
  }

  // what one row is: a breakdown column wins over the ad columns (a breakdown file by ad is added up per campaign)
  final level = _breakdownCols.any(cols.containsKey) ? MetaLevel.breakdown : (_adCols.any(cols.containsKey) ? MetaLevel.ad : MetaLevel.campaign);
  final warnings = <String>[];
  final raw = <Map<String, dynamic>>[];
  var seen = 0;
  var skipped = 0;
  var summaryRows = 0;
  var noAd = 0;
  var noSegment = 0;
  dynamic cell(List<dynamic> row, String key) => cols.containsKey(key) && cols[key]! < row.length ? row[cols[key]!] : null;
  for (var r = headerIdx + 1; r < table.length; r++) {
    final row = table[r];
    if (row.every((c) => _asStr(c).isEmpty)) continue;
    seen++;
    final name = _asStr(cell(row, 'campaign'));
    final metaId = _asStr(cell(row, 'campaignId'));
    if (name.isEmpty && metaId.isEmpty) {
      skipped++; // a total row, or a blank name
      continue;
    }
    String? day;
    if (cols.containsKey('day')) {
      day = _asDay(cell(row, 'day'));
    } else {
      final start = _asDay(cell(row, 'start'));
      final end = cols.containsKey('end') ? _asDay(cell(row, 'end')) : start;
      if (start != null && end != null && start != end) {
        summaryRows++; // a figure for a whole period, not for a day
        skipped++;
        continue;
      }
      day = start;
    }
    if (day == null) {
      skipped++;
      continue;
    }
    final spend = _asNum(cell(row, 'spend'));
    final reach = _asNum(cell(row, 'reach'));
    final impressions = _asNum(cell(row, 'impressions'));
    final clicks = _asNum(cell(row, 'clicks'));
    final results = _asNum(cell(row, 'results'));
    if ([spend, reach, impressions, clicks, results].any((v) => v == null || v < 0)) {
      skipped++;
      continue;
    }
    final extra = <String, dynamic>{};
    if (level == MetaLevel.ad) {
      final ad = _asStr(cell(row, 'ad'));
      final adId = _asStr(cell(row, 'adId'));
      if (ad.isEmpty && adId.isEmpty) {
        noAd++; // a campaign or ad-set total row of an ad-level export
        skipped++;
        continue;
      }
      extra['ad'] = ad;
      if (adId.isNotEmpty) extra['adId'] = adId;
      final adSet = _asStr(cell(row, 'adSet'));
      final adSetId = _asStr(cell(row, 'adSetId'));
      if (adSet.isNotEmpty) extra['adSet'] = adSet;
      if (adSetId.isNotEmpty) extra['adSetId'] = adSetId;
    } else if (level == MetaLevel.breakdown) {
      for (final c in _breakdownCols) {
        final v = _asStr(cell(row, c));
        if (v.isNotEmpty) extra[c] = v;
      }
      if (extra.isEmpty) {
        noSegment++; // a total row with no segment
        skipped++;
        continue;
      }
    }
    raw.add({
      'campaign': name,
      if (metaId.isNotEmpty) 'campaignId': metaId,
      'day': day,
      'spend': spend,
      'reach': reach!.round(),
      'impressions': impressions!.round(),
      'clicks': clicks!.round(),
      'results': results!.round(),
      ...extra,
    });
  }
  if (summaryRows > 0) warnings.add('$summaryRows row${summaryRows == 1 ? '' : 's'} cover a whole period, not one day, so they were left out. In Ads Manager choose Breakdown → Time → Day and export again.');
  if (noAd > 0) warnings.add('$noAd row${noAd == 1 ? ' has' : 's have'} no ad name or ad ID (a total row), so ${noAd == 1 ? 'it was' : 'they were'} left out.');
  if (noSegment > 0) warnings.add('$noSegment row${noSegment == 1 ? ' has' : 's have'} no age, gender or placement (a total row), so ${noSegment == 1 ? 'it was' : 'they were'} left out.');
  final other = skipped - summaryRows - noAd - noSegment;
  if (other > 0) warnings.add('$other row${other == 1 ? '' : 's'} could not be used (no campaign name, no real day, or a figure that is not a number).');
  if (raw.isEmpty && warnings.isEmpty) warnings.add('No rows with a campaign and a day were found.');
  return MetaExport(rows: mergeMetaRows(raw, level: level), warnings: warnings, totalRows: seen, skipped: skipped, level: level);
}

// ── picking the file (replaceable in tests) ───────────────────────────────────────────────────────────────────────────────────

typedef PickedFile = ({String name, Uint8List bytes});

Future<PickedFile?> _pickMetaFile() async {
  final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx', 'xls', 'csv'], withData: true);
  final f = picked?.files.single;
  if (f == null || f.bytes == null) return null;
  return (name: f.name, bytes: f.bytes!);
}

/// How the app asks for the exported file; a test overrides it with a fixed file.
final hubFilePickerProvider = Provider<Future<PickedFile?> Function()>((ref) => _pickMetaFile);

/// Ask for the file, read it, and open the import's preview. The Overview's "Import from Meta Ads Manager" and the Reports tab call this.
Future<void> startMetaImport(BuildContext context, WidgetRef ref) async {
  final PickedFile? file;
  try {
    file = await ref.read(hubFilePickerProvider)();
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return;
  }
  if (file == null || !context.mounted) return;
  final export = parseMetaExport(file.bytes, file.name);
  await showHubForm<void>(context, MetaImportForm(fileName: file.name, export: export), maxWidth: 640);
}

// ── the preview and the import ─────────────────────────────────────────────────────────────────────────────────────────────────

class MetaImportForm extends ConsumerStatefulWidget {
  const MetaImportForm({super.key, required this.fileName, required this.export});
  final String fileName;
  final MetaExport export;

  @override
  ConsumerState<MetaImportForm> createState() => _MetaImportFormState();
}

enum _Phase { checking, ready, importing, done, failed }

class _MetaImportFormState extends ConsumerState<MetaImportForm> {
  _Phase _phase = _Phase.checking;
  HubImportReport? _check;
  HubImportReport? _result;
  bool _create = false;
  late String _brand = () {
    final b = ref.read(teamFilterProvider).brand;
    return b == TeamBrand.all ? 'kerala' : b.wire;
  }();
  String? _error;
  String _progress = '';

  @override
  void initState() {
    super.initState();
    if (widget.export.hasRows) {
      _dryRun();
    } else {
      _phase = _Phase.failed;
    }
  }

  /// One row per campaign is enough to ask the server which campaigns it knows.
  List<Map<String, dynamic>> _sample() {
    final seen = <String>{};
    return [
      for (final r in widget.export.rows)
        if (seen.add(_keyOf(r))) r,
    ];
  }

  Future<void> _dryRun() async {
    setState(() {
      _phase = _Phase.checking;
      _error = null;
    });
    try {
      final r = await ref.read(marketingCampaignHubServiceProvider).importRows(_sample(), level: widget.export.level.wire, dryRun: true, fileName: widget.fileName);
      if (mounted) setState(() { _check = r; _phase = _Phase.ready; });
    } on TeamRefusal catch (r) {
      if (mounted) setState(() { _error = r.message; _phase = _Phase.failed; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyErrorMessage(e); _phase = _Phase.failed; });
    }
  }

  List<ImportGroup> get _creatable => (_check?.unmatched ?? const []).where((u) => u.reason == 'no_match' && u.name.isNotEmpty).toList();
  bool get _canRun => (_check?.matched.isNotEmpty ?? false) || (_create && _creatable.isNotEmpty);

  Future<void> _run() async {
    final rows = widget.export.rows;
    setState(() {
      _phase = _Phase.importing;
      _error = null;
    });
    final svc = ref.read(marketingCampaignHubServiceProvider);
    String? importId;
    var written = 0;
    var created = 0;
    var adsCreated = 0;
    var skipped = 0;
    final unmatched = <String, ImportGroup>{};
    String? first;
    String? last;
    final level = widget.export.level.wire;
    try {
      final parts = chunkImportRows(rows, overhead: 600 + utf8.encode(widget.fileName).length);
      final chunks = parts.length;
      for (var i = 0; i < chunks; i++) {
        if (mounted) setState(() => _progress = chunks > 1 ? 'Sending part ${i + 1} of $chunks…' : 'Importing…');
        final r = await svc.importRows(parts[i], level: level, createMissing: _create, brand: _brand, fileName: widget.fileName, importId: importId);
        importId = r.importId ?? importId;
        written += r.written;
        created += r.created;
        adsCreated += r.adsCreated;
        skipped += r.skipped;
        for (final u in r.unmatched) {
          unmatched.putIfAbsent(u.name.isEmpty ? u.metaId : u.name.toLowerCase(), () => u);
        }
        if (r.from != null && (first == null || r.from!.compareTo(first) < 0)) first = r.from;
        if (r.to != null && (last == null || r.to!.compareTo(last) > 0)) last = r.to;
      }
      refreshCampaignHub(ref);
      if (mounted) {
        setState(() {
          _result = HubImportReport(level: level, written: written, created: created, adsCreated: adsCreated, skipped: skipped, unmatched: unmatched.values.toList(), importId: importId, from: first, to: last, rows: rows.length);
          _phase = _Phase.done;
        });
      }
    } on TeamRefusal catch (r) {
      refreshCampaignHub(ref); // an earlier part may have gone in
      if (mounted) setState(() { _error = r.message; _phase = _Phase.ready; });
    } catch (e) {
      refreshCampaignHub(ref);
      if (mounted) setState(() { _error = friendlyErrorMessage(e); _phase = _Phase.ready; });
    }
  }

  Widget _line(String text, {Color? color, FontWeight weight = FontWeight.w500, Key? key}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(text, key: key, style: mktText(12.5, color: color ?? Mkt.ink, weight: weight, height: 1.3)));

  Widget _summary() {
    final e = widget.export;
    final span = e.firstDay == null ? '' : (e.firstDay == e.lastDay ? ' · ${hubDay(e.firstDay!)}' : ' · ${hubDay(e.firstDay!)} – ${hubDay(e.lastDay!)}');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: Mkt.border)),
      child: Row(children: [
        const Icon(Icons.description_outlined, size: 20, color: Mkt.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.fileName, key: const Key('imp_file_name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w800)),
            Text('${e.rows.length} ${importUnit(e.level.wire, e.rows.length)} · ${e.level == MetaLevel.ad ? '${e.ads} ad${e.ads == 1 ? '' : 's'} · ' : ''}${e.campaigns} campaign${e.campaigns == 1 ? '' : 's'}$span', key: const Key('imp_summary'), style: mktText(11.5, color: Mkt.inkSoft)),
            Text(e.level.description, key: const Key('imp_level'), style: mktText(11, color: Mkt.inkSoft)),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _body() {
    final e = widget.export;
    final out = <Widget>[];
    if (_phase != _Phase.done) {
      out.add(e.hasRows ? _summary() : const SizedBox.shrink());
      if (e.warnings.isNotEmpty) {
        out.add(const SizedBox(height: 10));
        out.add(Container(
          key: const Key('imp_warnings'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Mkt.tint(Mkt.warn, 0.1), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final w in e.warnings) _line(w)]),
        ));
      }
    }
    switch (_phase) {
      case _Phase.checking:
        out.add(const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(key: Key('imp_checking')))));
      case _Phase.failed:
        if (_error != null) {
          out.add(const SizedBox(height: 10));
          out.add(_line(_error!, color: Mkt.bad, weight: FontWeight.w600, key: const Key('imp_check_error')));
          out.add(TextButton(key: const Key('imp_retry'), onPressed: _dryRun, child: const Text('Try again')));
        } else if (!e.hasRows) {
          out.add(const SizedBox(height: 10));
          out.add(_line('Nothing in this file can be imported.', color: Mkt.inkSoft, key: const Key('imp_nothing')));
        }
      case _Phase.ready || _Phase.importing:
        final c = _check!;
        out.add(const SizedBox(height: 12));
        out.add(Text('Found in the CRM (${c.matched.length})', style: mktText(13, weight: FontWeight.w800)));
        if (c.matched.isEmpty) out.add(_line('No campaign in the file matches one here yet.', color: Mkt.inkSoft, key: const Key('imp_none_matched')));
        for (final m in c.matched) {
          out.add(Padding(
            key: Key('imp_matched_${m.campaignId}'),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [const Icon(Icons.check_circle_rounded, size: 15, color: Mkt.good), const SizedBox(width: 6), Expanded(child: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5)))]),
          ));
        }
        if (c.unmatched.isNotEmpty) {
          out.add(const SizedBox(height: 12));
          out.add(Text('Not found (${c.unmatched.length})', style: mktText(13, weight: FontWeight.w800)));
          out.add(_line('These are left out unless you choose to create them.', color: Mkt.inkSoft));
          for (final u in c.unmatched) {
            out.add(Padding(
              key: Key('imp_unmatched_${u.name.isEmpty ? u.metaId : u.name}'),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(u.reason == 'ambiguous' ? Icons.warning_amber_rounded : Icons.help_outline_rounded, size: 15, color: u.reason == 'ambiguous' ? Mkt.warn : Mkt.inkSoft),
                const SizedBox(width: 6),
                Expanded(child: Text(u.reason == 'ambiguous' ? '${u.name} — two campaigns share this name' : (u.name.isEmpty ? 'Campaign ID ${u.metaId}' : u.name), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5))),
              ]),
            ));
          }
        }
        if (_creatable.isNotEmpty) {
          out.add(const SizedBox(height: 8));
          out.add(CheckboxListTile(
            key: const Key('imp_create_missing'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _create,
            onChanged: _phase == _Phase.importing ? null : (v) => setState(() => _create = v ?? false),
            title: Text('Also create ${_creatable.length == 1 ? 'this campaign' : 'these ${_creatable.length} campaigns'}', style: mktText(12.5, weight: FontWeight.w700)),
            subtitle: Text('They are added as active Meta campaigns with no budget.', style: mktText(11, color: Mkt.inkSoft)),
          ));
          if (_create) {
            out.add(Row(children: [
              Text('Brand', style: mktText(12.5, color: Mkt.inkSoft)),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(key: const Key('imp_brand'), isExpanded: true, initialValue: _brand, decoration: hubDec('Brand'), items: const [DropdownMenuItem(value: 'main', child: Text('Main')), DropdownMenuItem(value: 'kerala', child: Text('Kerala'))], onChanged: (v) => setState(() => _brand = v ?? _brand)),
              ),
            ]));
          }
        }
        if (_phase == _Phase.importing) {
          out.add(const SizedBox(height: 12));
          out.add(Row(children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 10), Text(_progress, key: const Key('imp_progress'), style: mktText(12.5, color: Mkt.inkSoft))]));
        }
      case _Phase.done:
        final r = _result!;
        out.add(Row(children: [const Icon(Icons.check_circle_rounded, color: Mkt.good, size: 22), const SizedBox(width: 8), Expanded(child: Text(r.written == 0 ? 'Nothing was imported.' : 'Imported ${r.written} ${importUnit(r.level, r.written)}.', key: const Key('imp_done_title'), style: mktText(15, weight: FontWeight.w800)))]));
        if (r.from != null) out.add(_line('${hubDay(r.from!)}${r.to != null && r.to != r.from ? ' – ${hubDay(r.to!)}' : ''}', color: Mkt.inkSoft, key: const Key('imp_done_span')));
        if (r.created > 0) out.add(_line('${r.created} new campaign${r.created == 1 ? '' : 's'} created.', key: const Key('imp_done_created')));
        if (r.adsCreated > 0) out.add(_line('${r.adsCreated} ad${r.adsCreated == 1 ? '' : 's'} added to ${r.adsCreated == 1 ? 'its campaign' : 'their campaigns'} (they were not in the CRM yet).', key: const Key('imp_done_ads_created')));
        if (r.unmatched.isNotEmpty) out.add(_line('Left out, no matching campaign: ${r.unmatched.map((u) => u.name.isEmpty ? u.metaId : u.name).join(', ')}.', color: Mkt.warn, weight: FontWeight.w600, key: const Key('imp_done_unmatched')));
        if (r.skipped > 0) out.add(_line('${r.skipped} row${r.skipped == 1 ? '' : 's'} skipped as not valid.', color: Mkt.inkSoft, key: const Key('imp_done_skipped')));
        out.add(_line(
          switch (r.level) {
            'ad' => 'Each ad\'s figures are on Creatives & Ads for the dates they ran, and the campaigns\' days are the sum of their ads. The Overview\'s Meta card shows when this import was made.',
            'breakdown' => 'The audiences and placements are on the Overview and Performance now. The Overview\'s Meta card shows when this import was made.',
            _ => 'The figures are on the Overview, Performance and Budget & Spend now. The Overview\'s Meta card shows when this import was made.',
          },
          color: Mkt.inkSoft,
        ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final done = _phase == _Phase.done;
    return HubFormFrame(
      keyPrefix: 'imp',
      title: 'Import from Meta Ads Manager',
      saving: _phase == _Phase.importing,
      error: _phase == _Phase.ready || _phase == _Phase.importing ? _error : null,
      saveLabel: done ? 'Done' : 'Import',
      onSave: done ? () => Navigator.pop(context) : (_phase == _Phase.ready && _canRun ? _run : null),
      onCancel: () => Navigator.pop(context),
      children: _body(),
    );
  }
}

/// The honest card the Overview and the Reports tab show for Meta: whether the live sync is set up and when it last worked (or why it did
/// not), what was brought in last and how, and whether Lead Ads forms arrive on their own. The file import and a typed day stay.
class MetaCard extends StatelessWidget {
  const MetaCard({super.key, required this.meta, required this.onImport, this.onTypeDay});
  final HubMeta meta;
  final VoidCallback onImport;
  final VoidCallback? onTypeDay;

  static final _at = DateFormat('d MMM yyyy, h:mm a');

  static String lastImportText(ImportInfo? i) {
    if (i == null || i.at == null) return 'No import yet';
    final how = switch (i.source) { 'manual' => 'typed by hand', 'csv' => 'file import', 'api' => 'Meta sync', _ => i.source };
    return 'Last import: ${_at.format(i.at!)} ($how)';
  }

  /// The chip: what state the live sync is in.
  static (String, Color) chipOf(HubMeta m) => switch (m.status) {
    'connected' => ('Live sync on', Mkt.good),
    'error' => ('Sync failed', Mkt.bad),
    'not_synced' => ('Not synced yet', Mkt.warn),
    _ => ('Not connected', Mkt.grey),
  };

  @override
  Widget build(BuildContext context) {
    final i = meta.lastImport;
    final sync = meta.sync;
    final (chip, chipColor) = chipOf(meta);
    void open(String tab) => GoRouter.maybeOf(context)?.go('/marketing/meta?tab=$tab');
    return MktCard(
      title: 'Meta Ads figures',
      icon: Icons.all_inclusive_rounded,
      trailing: MktChip(chip, key: const Key('hub_meta_status'), color: chipColor),
      child: Column(key: const Key('hub_meta_card'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          sync != null
              ? 'Figures come from Meta on their own${sync.autoSync ? ' every 6 hours' : ' when someone presses Sync now'}. You can still import an Ads Manager file or type a day.'
              : 'Ad figures have no live Meta sync yet. Export from Meta Ads Manager (one row per day — by campaign, by ad, or broken down by age, gender or placement) and import the file here, or type a day\'s figures by hand.',
          key: const Key('hub_meta_text'),
          style: mktText(12, color: Mkt.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 8),
        for (final t in [sync != null ? 'Spend, reach, impressions and clicks come from Meta' : 'Spend, reach, impressions and clicks come from what you import or type', 'Leads, bookings and revenue come from the CRM', 'Work logged by the team attaches to its campaign'])
          Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.circle, size: 5, color: Mkt.primary), const SizedBox(width: 8), Expanded(child: Text(t, style: mktText(11.5, height: 1.3)))])),
        const SizedBox(height: 8),
        if (sync != null && !sync.ok) Text(sync.problem.isEmpty ? 'The last sync failed.' : sync.problem, key: const Key('hub_meta_sync_problem'), style: mktText(11.5, weight: FontWeight.w700, color: Mkt.bad, height: 1.3)),
        if (sync != null && sync.lastOkAt != null) Text('Last synced: ${_at.format(sync.lastOkAt!)}', key: const Key('hub_meta_last_sync'), style: mktText(11.5, weight: FontWeight.w700)),
        if (sync != null && sync.unlinked > 0)
          Text('${sync.unlinked} Meta campaign${sync.unlinked == 1 ? '' : 's'} not linked: ${sync.unlinked == 1 ? 'its' : 'their'} spend is not counted yet', key: const Key('hub_meta_unlinked'), style: mktText(11.5, weight: FontWeight.w700, color: Mkt.warn)),
        Text(lastImportText(i), key: const Key('hub_meta_last_import'), style: mktText(11.5, weight: FontWeight.w700, color: i == null ? Mkt.inkSoft : Mkt.ink)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (sync != null) FilledButton.icon(key: const Key('hub_meta_sync_button'), style: FilledButton.styleFrom(backgroundColor: Mkt.primary, minimumSize: const Size(0, 36)), onPressed: () => open('spend'), icon: const Icon(Icons.sync_rounded, size: 17), label: Text(sync.unlinked > 0 ? 'Link campaigns' : 'Meta sync')),
          if (sync == null) FilledButton.icon(key: const Key('hub_import_button'), style: FilledButton.styleFrom(backgroundColor: Mkt.primary, minimumSize: const Size(0, 36)), onPressed: onImport, icon: const Icon(Icons.upload_file_rounded, size: 17), label: const Text('Import from Meta Ads Manager'))
          else OutlinedButton.icon(key: const Key('hub_import_button'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)), onPressed: onImport, icon: const Icon(Icons.upload_file_rounded, size: 17), label: const Text('Import a file')),
          if (onTypeDay != null) OutlinedButton.icon(key: const Key('hub_type_day_button'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)), onPressed: onTypeDay, icon: const Icon(Icons.edit_calendar_outlined, size: 17), label: const Text('Type a day')),
          if (sync == null) TextButton(key: const Key('hub_meta_setup_button'), onPressed: () => open('spend'), child: const Text('Set up the live sync')),
        ]),
        const Divider(height: 22),
        Row(children: [
          Icon(meta.leadAds ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: meta.leadAds ? Mkt.good : Mkt.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              meta.leadAds ? 'Lead Ads forms arrive as CRM leads on their own' : 'Lead Ads forms are not connected yet',
              key: const Key('hub_lead_ads_status'),
              style: mktText(12, weight: FontWeight.w600),
            ),
          ),
          TextButton(key: const Key('hub_meta_leads_button'), onPressed: () => open('leads'), child: const Text('Meta Lead Ads')),
        ]),
      ]),
    );
  }
}
