import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import 'package:nizan_crm/core/utils/file_saver.dart';

/// CSV / PDF export helpers. Delegates the actual save to [saveFileBytes],
/// which downloads in the browser on web and opens a share sheet on mobile.
class ExportUtils {
  static Future<void> exportCsv(String fileName, List<List<dynamic>> rows) async {
    final String csv = const CsvEncoder().convert(rows);
    await saveFileBytes(fileName, utf8.encode(csv), mime: 'text/csv');
  }

  static Future<void> exportPdf(String fileName, String title,
      List<String> headers, List<List<dynamic>> dataRows) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: dataRows
                .map((row) => row.map((e) => e.toString()).toList())
                .toList(),
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
    await saveFileBytes(fileName, bytes, mime: 'application/pdf');
  }
}
