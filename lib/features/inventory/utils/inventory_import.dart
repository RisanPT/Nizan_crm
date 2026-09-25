import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart' show CsvDecoder;
// `excel` re-exports Flutter's TextSpan (used by TextCellValue), so we get
// TextSpan + toPlainText() from here without a separate Flutter import.
import 'package:excel/excel.dart';

/// Columns the importer understands. `name` is the only required one; the rest
/// are optional and fall back to product defaults. Header matching is
/// case/space/punctuation-insensitive and accepts common aliases.
const kInventoryImportColumns = <String>[
  'name',
  'brand',
  'shade',
  'barcode',
  'quantity',
  'price',
  'category',
  'productType',
  'expiry',
  'lowStockThreshold',
  'notes',
];

/// Result of parsing an uploaded stock file.
class InventoryImportResult {
  /// Product maps ready to POST to /inventory/products/bulk.
  final List<Map<String, dynamic>> items;

  /// Non-fatal messages (unmapped rows, missing name column, etc.).
  final List<String> warnings;

  /// Data rows seen (excluding the header).
  final int totalRows;

  /// Rows skipped because they had no product name.
  final int skipped;

  const InventoryImportResult({
    required this.items,
    required this.warnings,
    required this.totalRows,
    required this.skipped,
  });

  bool get hasItems => items.isNotEmpty;
}

// Canonical field → accepted (normalised) header aliases.
const _fieldAliases = <String, List<String>>{
  'name': ['name', 'product', 'productname', 'item', 'itemname'],
  'brand': ['brand', 'company', 'make'],
  'shade': ['shade', 'color', 'colour'],
  'barcode': ['barcode', 'ean', 'upc', 'code', 'sku'],
  'quantity': ['quantity', 'qty', 'stock', 'count', 'units', 'onhand'],
  'price': ['price', 'cost', 'mrp', 'rate', 'unitprice'],
  'category': ['category', 'cat', 'group'],
  'productType': ['producttype', 'type', 'subcategory'],
  'expiry': ['expiry', 'expirydate', 'exp', 'expdate', 'expires'],
  'fillLevel': ['filllevel', 'fill', 'fillpercent'],
  'usagePerWork': ['usageperwork', 'usage', 'usagepercent'],
  'lowStockThreshold': [
    'lowstockthreshold',
    'lowstock',
    'threshold',
    'reorder',
    'reorderlevel',
    'minstock',
    'min',
  ],
  'notes': ['notes', 'note', 'remark', 'remarks', 'description', 'desc'],
};

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String? _fieldForHeader(String header) {
  final n = _norm(header);
  if (n.isEmpty) return null;
  for (final entry in _fieldAliases.entries) {
    if (entry.value.contains(n)) return entry.key;
  }
  return null;
}

/// Parse an uploaded inventory file (.xlsx or .csv) into product maps.
/// Never throws for content problems — surfaces them as [warnings] instead.
/// Names of the non-empty sheets in an .xlsx (empty for CSV). Lets the caller
/// offer a sheet picker for multi-sheet workbooks.
List<String> inventoryImportSheets(Uint8List bytes) {
  try {
    final excel = Excel.decodeBytes(bytes);
    return [
      for (final e in excel.tables.entries)
        if ((e.value.maxRows) > 0) e.key,
    ];
  } catch (_) {
    return const [];
  }
}

InventoryImportResult parseInventoryImport(
  Uint8List bytes,
  String filename, {
  String? sheetName,
}) {
  final lower = filename.toLowerCase();
  List<List<dynamic>> rows;
  try {
    rows = lower.endsWith('.csv') ? _readCsv(bytes) : _readXlsx(bytes, sheetName);
  } catch (e) {
    return InventoryImportResult(
      items: const [],
      warnings: const [
          'Could not read the file. Make sure it is a valid .xlsx or .csv file.'
      ],
      totalRows: 0,
      skipped: 0,
    );
  }

  if (rows.every((r) => r.every((c) => _asStr(c).isEmpty))) {
    return const InventoryImportResult(
      items: [],
      warnings: ['The sheet is empty.'],
      totalRows: 0,
      skipped: 0,
    );
  }

  // Find the header row: real spreadsheets often have a title row (or blank
  // rows) above the header, so scan the first rows for the one that maps the
  // most known columns AND includes "name".
  var headerIdx = -1;
  var colField = <int, String>{};
  final scanLimit = rows.length < 25 ? rows.length : 25;
  for (var i = 0; i < scanLimit; i++) {
    final map = <int, String>{};
    for (var c = 0; c < rows[i].length; c++) {
      final f = _fieldForHeader(_asStr(rows[i][c]));
      if (f != null && !map.containsValue(f)) map[c] = f; // first column wins per field
    }
    if (map.containsValue('name') && map.length > colField.length) {
      headerIdx = i;
      colField = map;
    }
  }

  if (headerIdx < 0) {
    return InventoryImportResult(
      items: const [],
      warnings: [
        'Could not find a header row with a "name"/"product" column. '
            'Supported columns: ${kInventoryImportColumns.join(', ')}.',
      ],
      totalRows: rows.length,
      skipped: 0,
    );
  }

  final warnings = <String>[];
  final items = <Map<String, dynamic>>[];
  var dataRows = 0;
  var skipped = 0;
  var lastName = ''; // for forward-filling grouped variant rows

  for (var r = headerIdx + 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => _asStr(c).isEmpty)) continue; // blank spacer row
    dataRows++;

    final item = <String, dynamic>{};
    colField.forEach((col, field) {
      if (col >= row.length) return;
      final raw = row[col];
      switch (field) {
        case 'quantity':
        case 'fillLevel':
        case 'usagePerWork':
        case 'lowStockThreshold':
          final n = _asInt(raw);
          if (n != null) item[field] = n;
        case 'price':
          final n = _asDouble(raw);
          if (n != null) item[field] = n;
        case 'expiry':
          final d = _asDateIso(raw);
          if (d != null) item[field] = d;
        default:
          final s = _asStr(raw);
          if (s.isNotEmpty) item[field] = s;
      }
    });

    var name = _asStr(item['name']);
    if (name.isEmpty) {
      // Grouped layout: a blank name on a row that still has brand/shade is a
      // variant of the product named above it — inherit that name.
      final isVariant = _asStr(item['brand']).isNotEmpty ||
          _asStr(item['shade']).isNotEmpty;
      if (isVariant && lastName.isNotEmpty) {
        name = lastName;
        item['name'] = lastName;
      }
    } else {
      lastName = name;
    }

    if (name.isEmpty) {
      skipped++;
      continue;
    }
    items.add(item);
  }

  if (skipped > 0) {
    warnings.add('$skipped row${skipped == 1 ? '' : 's'} skipped (no product name).');
  }

  return InventoryImportResult(
    items: items,
    warnings: warnings,
    totalRows: dataRows,
    skipped: skipped,
  );
}

List<List<dynamic>> _readCsv(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: true).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return const CsvDecoder(parseHeaders: false, dynamicTyping: true).convert(text);
}

List<List<dynamic>> _readXlsx(Uint8List bytes, [String? sheetName]) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return const [];
  final sheet = (sheetName != null && excel.tables.containsKey(sheetName))
      ? excel.tables[sheetName]!
      : excel.tables.values.firstWhere(
          (s) => s.maxRows > 0,
          orElse: () => excel.tables.values.first,
        );
  return sheet.rows.map((r) => r.map(_cellRaw).toList()).toList();
}

/// Convert one Excel cell into a plain Dart value (String / num / bool / DateTime).
dynamic _cellRaw(Data? cell) {
  final v = cell?.value;
  if (v == null) return null;
  return switch (v) {
    // excel's own TextSpan.toString() concatenates its text (+ any rich runs).
    TextCellValue() => v.value.toString(),
    IntCellValue() => v.value,
    DoubleCellValue() => v.value,
    BoolCellValue() => v.value,
    DateCellValue() => v.asDateTimeLocal(),
    DateTimeCellValue() => v.asDateTimeLocal(),
    TimeCellValue() => v.toString(),
    FormulaCellValue() => v.formula,
  };
}

String _asStr(dynamic v) =>
    v == null ? '' : (v is String ? v.trim() : v.toString().trim());

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final direct = int.tryParse(s) ?? double.tryParse(s)?.round();
  if (direct != null) return direct;
  // Tolerate values like "2 BOX" / "3 pcs" — take the leading number.
  final m = RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(s);
  return m != null ? double.parse(m.group(1)!).round() : null;
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim().replaceAll(',', '');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

String? _asDateIso(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toIso8601String();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toIso8601String();
}
