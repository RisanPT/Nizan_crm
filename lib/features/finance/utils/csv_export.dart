import 'dart:convert';
import 'dart:typed_data';

import 'package:nizan_crm/core/utils/file_saver.dart';

String _cell(Object? v) {
  final s = v?.toString() ?? '';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Two-decimal plain number for a CSV amount column (no ₹, so the CA can sum it).
String csvNum(num v) => v.toStringAsFixed(2);

/// Build a CSV from [rows] and save it as [filename] (cross-platform).
Future<void> downloadCsv(String filename, List<List<Object?>> rows) async {
  final buf = StringBuffer();
  for (final row in rows) {
    buf.writeln(row.map(_cell).join(','));
  }
  await saveFileBytes(filename, Uint8List.fromList(utf8.encode(buf.toString())), mime: 'text/csv');
}
