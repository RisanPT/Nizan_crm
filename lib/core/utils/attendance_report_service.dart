import 'attendance_report_html.dart';

import 'attendance_report_stub.dart'
    if (dart.library.io) 'attendance_report_mobile.dart'
    if (dart.library.html) 'attendance_report_web.dart' as impl;

/// Print / PDF the monthly attendance report.
/// Web → browser print dialog; mobile → PDF share sheet.
Future<void> printAttendanceReport(AttendanceReportData data) =>
    impl.printAttendanceReport(data);

/// Download the attendance rows as a CSV file.
/// Web → browser download; mobile → share sheet.
Future<void> downloadAttendanceCsv(AttendanceReportData data) =>
    impl.downloadAttendanceCsv(data);
