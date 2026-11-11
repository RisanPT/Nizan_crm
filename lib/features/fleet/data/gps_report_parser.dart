import 'dart:typed_data';

import 'package:nizan_crm/core/utils/spreadsheet_reader.dart';

/// One day of one vehicle from a GPS tracker's day-wise report — what is sent to
/// POST /fleet/gps-km/upload.
class GpsReportRow {
  final String registrationNumber;

  /// 'YYYY-MM-DD'
  final String date;
  final double distanceKm;
  final double? runningHours;
  final double? stopHours;
  final double? idleHours;
  final String startAddress;
  final String endAddress;

  const GpsReportRow({
    required this.registrationNumber,
    required this.date,
    required this.distanceKm,
    this.runningHours,
    this.stopHours,
    this.idleHours,
    this.startAddress = '',
    this.endAddress = '',
  });

  Map<String, dynamic> toJson() => {
        'registrationNumber': registrationNumber,
        'date': date,
        'distanceKm': distanceKm,
        if (runningHours != null) 'runningHours': runningHours,
        if (stopHours != null) 'stopHours': stopHours,
        if (idleHours != null) 'idleHours': idleHours,
        if (startAddress.isNotEmpty) 'startAddress': startAddress,
        if (endAddress.isNotEmpty) 'endAddress': endAddress,
      };
}

/// What reading a GPS report gave: the rows, and — if it could not be read at
/// all — why.
class GpsReportParse {
  final List<GpsReportRow> rows;

  /// Rows that had a vehicle but whose date or distance could not be read.
  final int skipped;

  /// The first few reasons ("Row 7: date “x” not understood").
  final List<String> problems;

  /// Set when nothing could be read (not a spreadsheet, columns not found…).
  final String? error;

  /// The columns that were recognised, as the file wrote them.
  final List<String> columns;

  const GpsReportParse({
    this.rows = const [],
    this.skipped = 0,
    this.problems = const [],
    this.error,
    this.columns = const [],
  });

  bool get hasRows => rows.isNotEmpty;

  /// Days per vehicle, as the file wrote the plate.
  Map<String, int> get vehicleDays {
    final out = <String, int>{};
    for (final r in rows) {
      out[r.registrationNumber] = (out[r.registrationNumber] ?? 0) + 1;
    }
    return out;
  }

  /// First / last day in the file ('YYYY-MM-DD'), null when there are no rows.
  String? get from => rows.isEmpty
      ? null
      : rows.map((r) => r.date).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  String? get to => rows.isEmpty
      ? null
      : rows.map((r) => r.date).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

  double get totalKm => rows.fold(0.0, (s, r) => s + r.distanceKm);
}

// Canonical field → accepted (normalised) header aliases. Different GPS apps
// word the same column differently; matching ignores case, spaces and punctuation.
const _aliases = <String, List<String>>{
  'vehicle': [
    'vehicleno', 'vehiclenumber', 'vehicle', 'vehiclenameno', 'regno', 'regnumber',
    'registration', 'registrationno', 'registrationnumber', 'plateno', 'platenumber',
    'vehicleregno', 'vehiclename',
  ],
  'date': ['date', 'day', 'reportdate', 'tripdate'],
  'distance': [
    'distance', 'distancekm', 'distancetravelled', 'distancetraveled', 'totaldistance',
    'km', 'kms', 'totalkm', 'kmrun', 'runkm', 'dist',
    'distancem', 'distancemeters', 'distancemetres', 'distancemiles', 'distancemi',
  ],
  'running': ['running', 'runningtime', 'runninghours', 'moving', 'movingtime', 'drivingtime'],
  'stop': ['stop', 'stopped', 'stoptime', 'stoppedtime', 'parking', 'parked', 'parkingtime'],
  'idle': ['idle', 'idling', 'idletime', 'idlingtime'],
  'startAddress': ['startaddress', 'startlocation', 'startplace', 'from', 'fromaddress'],
  'endAddress': ['endaddress', 'endlocation', 'endplace', 'to', 'toaddress'],
};

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String? _fieldFor(String header) {
  // "Total Distance (KM)": try the whole name, then without the bracketed unit.
  for (final n in {_norm(header), _norm(header.replaceAll(RegExp(r'\(.*?\)'), ''))}) {
    if (n.isEmpty) continue;
    for (final e in _aliases.entries) {
      if (e.value.contains(n)) return e.key;
    }
  }
  return null;
}

String _str(dynamic v) => v == null ? '' : v.toString().trim();

/// Read a GPS tracker's day-wise km report (.xlsx or .csv). Never throws for
/// content problems — they come back in [GpsReportParse.error] / [problems].
GpsReportParse parseGpsReport(Uint8List bytes, String filename) {
  final List<List<dynamic>> table;
  try {
    table = readSpreadsheetRows(bytes, filename);
  } catch (_) {
    return const GpsReportParse(
      error: 'Could not read this file. Export the report from your GPS app as Excel (.xlsx) or CSV and try again.',
    );
  }
  return parseGpsTable(table);
}

/// The same, from rows already read (so it can be tested without a file).
GpsReportParse parseGpsTable(List<List<dynamic>> table) {
  if (table.every((r) => r.every((c) => _str(c).isEmpty))) {
    return const GpsReportParse(error: 'The sheet is empty.');
  }

  // The header is not always the first row (a title or blank rows can sit above
  // it): take the row, among the first few, that names the most known columns.
  var headerIdx = -1;
  var best = <int, String>{};
  final scan = table.length < 25 ? table.length : 25;
  for (var i = 0; i < scan; i++) {
    final map = <int, String>{};
    for (var c = 0; c < table[i].length; c++) {
      final f = _fieldFor(_str(table[i][c]));
      if (f != null && !map.containsValue(f)) map[c] = f; // first column wins
    }
    final has = map.containsValue('vehicle') && map.containsValue('date') && map.containsValue('distance');
    if (has && map.length > best.length) {
      headerIdx = i;
      best = map;
    }
  }

  if (headerIdx < 0) {
    final seen = table
        .take(scan)
        .expand((r) => r)
        .map(_str)
        .where((s) => s.isNotEmpty)
        .take(8)
        .join(', ');
    return GpsReportParse(
      error: 'Could not find the columns this needs: a vehicle number, a date and a distance. '
          '${seen.isEmpty ? '' : 'The file starts with: $seen.'}',
    );
  }

  int? col(String f) {
    for (final e in best.entries) {
      if (e.value == f) return e.key;
    }
    return null;
  }

  final header = table[headerIdx];
  final cVehicle = col('vehicle')!;
  final cDate = col('date')!;
  final cDist = col('distance')!;
  final cRun = col('running');
  final cStop = col('stop');
  final cIdle = col('idle');
  final cStart = col('startAddress');
  final cEnd = col('endAddress');

  // "Distance (m)" / "Distance (miles)": say so rather than guess it is km.
  final distHeader = _str(header[cDist]).toLowerCase();
  final unit = RegExp(r'\bmiles?\b|\(mi\)').hasMatch(distHeader)
      ? 1.609344
      : RegExp(r'\(m\)|\bmeters?\b|\bmetres?\b').hasMatch(distHeader)
          ? 0.001
          : 1.0;

  String at(List<dynamic> row, int? c) => c == null || c >= row.length ? '' : _str(row[c]);

  final rows = <GpsReportRow>[];
  final problems = <String>[];
  var skipped = 0;
  var vehicle = '';

  for (var r = headerIdx + 1; r < table.length; r++) {
    final row = table[r];
    if (row.every((c) => _str(c).isEmpty)) continue; // blank spacer

    final plate = at(row, cVehicle);
    final dateCell = cDate < row.length ? row[cDate] : null;
    final distCell = cDist < row.length ? row[cDist] : null;

    // A totals line ("Total", or a distance with no date) is not a day.
    if (_str(dateCell).isEmpty) continue;
    if (RegExp(r'^(grand\s*)?(total|summary)\b', caseSensitive: false).hasMatch(plate)) continue;

    // Grouped layouts name the vehicle on the first row of its block only.
    if (plate.isNotEmpty) vehicle = plate;
    if (vehicle.isEmpty) {
      skipped++;
      if (problems.length < 20) problems.add('Row ${r + 1}: no vehicle number');
      continue;
    }

    final day = parseReportDay(dateCell);
    if (day == null) {
      skipped++;
      if (problems.length < 20) problems.add('Row ${r + 1}: date “${_str(dateCell)}” not understood');
      continue;
    }
    final km = parseReportNumber(distCell);
    if (km == null) {
      skipped++;
      if (problems.length < 20) problems.add('Row ${r + 1}: distance “${_str(distCell)}” is not a number');
      continue;
    }

    rows.add(GpsReportRow(
      registrationNumber: vehicle,
      date: day,
      distanceKm: double.parse((km * unit).toStringAsFixed(3)),
      runningHours: cRun == null || cRun >= row.length ? null : parseReportHours(row[cRun]),
      stopHours: cStop == null || cStop >= row.length ? null : parseReportHours(row[cStop]),
      idleHours: cIdle == null || cIdle >= row.length ? null : parseReportHours(row[cIdle]),
      startAddress: at(row, cStart),
      endAddress: at(row, cEnd),
    ));
  }

  if (rows.isEmpty) {
    return GpsReportParse(
      error: skipped > 0
          ? 'None of the ${skipped == 1 ? 'row' : '$skipped rows'} could be read.'
          : 'The report has a header but no days under it.',
      skipped: skipped,
      problems: problems,
    );
  }

  return GpsReportParse(
    rows: rows,
    skipped: skipped,
    problems: problems,
    columns: [for (final c in best.keys) _str(header[c])],
  );
}

// ── cells ───────────────────────────────────────────────────────────────────

const _months = {
  'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3,
  'apr': 4, 'april': 4, 'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
  'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9,
  'oct': 10, 'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
};

String? _ymd(int y, int m, int d) {
  if (y < 100) y += 2000;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final t = DateTime.utc(y, m, d);
  if (t.year != y || t.month != m || t.day != d) return null; // 30 Feb…
  return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

/// A report's date as 'YYYY-MM-DD', or null if it cannot be read. Understands
/// real date cells, Excel serial numbers, "Oct 29, 2026", "29-Oct-2026",
/// "2026-10-29" and "29/10/2026" (day first — the Indian order; a number over 12
/// in the middle makes it month first).
String? parseReportDay(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return _ymd(v.year, v.month, v.day);
  if (v is num) {
    if (v < 20000 || v > 80000) return null; // not a date serial (1954–2119)
    final t = DateTime.utc(1899, 12, 30).add(Duration(days: v.floor()));
    return _ymd(t.year, t.month, t.day);
  }
  final s = v.toString().trim();
  if (s.isEmpty) return null;

  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T\s].*)?$').firstMatch(s);
  if (m != null) return _ymd(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));

  m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2}|\d{4})(?:[T\s].*)?$').firstMatch(s);
  if (m != null) {
    final a = int.parse(m[1]!);
    final b = int.parse(m[2]!);
    final y = int.parse(m[3]!);
    return b > 12 && a <= 12 ? _ymd(y, a, b) : _ymd(y, b, a);
  }

  // "Oct 29, 2026" / "October 9 2026"
  m = RegExp(r'^([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})$').firstMatch(s);
  if (m != null) {
    final mon = _months[m[1]!.toLowerCase()];
    return mon == null ? null : _ymd(int.parse(m[3]!), mon, int.parse(m[2]!));
  }

  // "29-Oct-2026" / "29 Oct 2026" / "29 October, 26"
  m = RegExp(r'^(\d{1,2})(?:st|nd|rd|th)?[\s\-]+([A-Za-z]{3,9})\.?,?[\s\-]+(\d{2}|\d{4})$').firstMatch(s);
  if (m != null) {
    final mon = _months[m[2]!.toLowerCase()];
    return mon == null ? null : _ymd(int.parse(m[3]!), mon, int.parse(m[1]!));
  }
  return null;
}

/// A number from a cell: a real number, or text like "1,234.5" / "23.7 km".
double? parseReportNumber(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.isFinite ? v.toDouble() : null;
  final s = v.toString().trim().replaceAll(',', '');
  if (s.isEmpty) return null;
  final m = RegExp(r'^(-?\d+(?:\.\d+)?|-?\.\d+)\s*(?:km|kms|kilometers|kilometres)?$', caseSensitive: false).firstMatch(s);
  return m == null ? null : double.tryParse(m[1]!);
}

/// Hours from a cell: a number of hours (0.98), or a duration "01:30" / "1:30:15".
double? parseReportHours(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final t = RegExp(r'^(\d+):(\d{1,2})(?::(\d{1,2}))?$').firstMatch(s);
  if (t != null) {
    final h = int.parse(t[1]!);
    final mi = int.parse(t[2]!);
    final se = t[3] == null ? 0 : int.parse(t[3]!);
    return double.parse((h + mi / 60 + se / 3600).toStringAsFixed(2));
  }
  return parseReportNumber(v);
}
