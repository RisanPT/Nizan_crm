import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

class ExportUtils {
  static Future<void> exportCsv(String fileName, List<List<dynamic>> rows) async {
    final String csv = const CsvEncoder().convert(rows);
    final bytes = utf8.encode(csv);

    if (kIsWeb) {
      _downloadWeb(fileName, bytes, 'text/csv');
    } else {
      await _saveLocal(fileName, Uint8List.fromList(bytes));
    }
  }

  static Future<void> exportPdf(String fileName, String title, List<String> headers, List<List<dynamic>> dataRows) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: dataRows.map((row) => row.map((e) => e.toString()).toList()).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellHeight: 30,
            cellAlignments: {
              for (var i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft,
            },
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      _downloadWeb(fileName, bytes, 'application/pdf');
    } else {
      await _saveLocal(fileName, bytes);
    }
  }

  static void _downloadWeb(String fileName, List<int> bytes, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.Url.revokeObjectUrl(url);
  }

  static Future<void> _saveLocal(String fileName, Uint8List bytes) async {
    // Requires path_provider
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = io.File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      // Ideally we should use a package like share_plus or file_saver to show to user
      // For now, it's saved in app docs.
    } catch (e) {
      log('Error saving file locally: $e');
    }
  }
}
