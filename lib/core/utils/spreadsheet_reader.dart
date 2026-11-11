import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart' show CsvDecoder;
// `excel` re-exports Flutter's TextSpan (used by TextCellValue), so we get
// TextSpan + toPlainText() from here without a separate Flutter import.
import 'package:excel/excel.dart';

/// Rows of an uploaded spreadsheet as plain Dart values (String / int / double /
/// bool / DateTime / null), whatever the file type: `.csv` is read as text,
/// anything else as an `.xlsx` workbook (the first non-empty sheet unless
/// [sheetName] names one). Throws if the bytes are not a readable file — callers
/// turn that into a message.
List<List<dynamic>> readSpreadsheetRows(
  Uint8List bytes,
  String filename, {
  String? sheetName,
}) {
  return filename.toLowerCase().endsWith('.csv')
      ? _readCsv(bytes)
      : _readXlsx(bytes, sheetName);
}

/// Names of the non-empty sheets in an .xlsx (empty for anything unreadable).
List<String> spreadsheetSheetNames(Uint8List bytes) {
  try {
    final excel = Excel.decodeBytes(bytes);
    return [
      for (final e in excel.tables.entries)
        if (e.value.maxRows > 0) e.key,
    ];
  } catch (_) {
    return const [];
  }
}

List<List<dynamic>> _readCsv(Uint8List bytes) {
  final text = utf8
      .decode(bytes, allowMalformed: true)
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  return const CsvDecoder(parseHeaders: false, dynamicTyping: true)
      .convert(text);
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

/// One Excel cell as a plain Dart value.
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
