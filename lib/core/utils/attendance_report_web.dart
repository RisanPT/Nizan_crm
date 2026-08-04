import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'attendance_report_html.dart';

/// Web: render the report into a hidden iframe and trigger the print dialog.
Future<void> printAttendanceReport(AttendanceReportData data) async {
  final content = buildAttendanceReportHtml(data);
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
    ..style.position = 'fixed'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = '0'
    ..src = objectUrl;

  web.document.body?.append(iframe);

  iframe.onLoad.listen((_) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final frameWindow = iframe.contentWindow;
    if (frameWindow != null) {
      try {
        frameWindow.focus();
        frameWindow.print();
      } catch (_) {
        try {
          web.window.print();
        } catch (_) {}
      }
    }
    Future<void>.delayed(const Duration(seconds: 2), () {
      web.URL.revokeObjectURL(objectUrl);
      iframe.remove();
    });
  });
}

/// Web: download the CSV via a temporary anchor click.
Future<void> downloadAttendanceCsv(AttendanceReportData data) async {
  final csv = buildAttendanceCsv(data);
  final blob = web.Blob(
    [csv.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = 'attendance_${data.periodLabel.replaceAll(' ', '_')}.csv'
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
}
