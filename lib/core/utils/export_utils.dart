import 'dart:convert';
import 'package:csv/csv.dart';

import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/core/utils/branded_pdf.dart';

/// CSV / PDF export helpers. Delegates the actual save to [saveFileBytes],
/// which downloads in the browser on web and opens a share sheet on mobile.
class ExportUtils {
  static Future<void> exportCsv(String fileName, List<List<dynamic>> rows) async {
    final String csv = const CsvEncoder().convert(rows);
    await saveFileBytes(fileName, utf8.encode(csv), mime: 'text/csv');
  }

  /// A single-table PDF, now with the Team N branded header/footer (via
  /// [saveBrandedReportPdf]) so every report looks consistent.
  static Future<void> exportPdf(String fileName, String title,
      List<String> headers, List<List<dynamic>> dataRows) async {
    await saveBrandedReportPdf(
      fileName: fileName,
      title: title,
      sections: [PdfSection('', headers, dataRows)],
    );
  }
}
