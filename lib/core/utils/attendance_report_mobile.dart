import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'attendance_report_html.dart';

/// Mobile: build a PDF and open the share sheet.
Future<void> printAttendanceReport(AttendanceReportData d) async {
  final primary = PdfColor.fromHex('#601A29');
  final muted = PdfColor.fromHex('#9CA3AF');
  final pdf = pw.Document();

  pw.Widget kpi(String label, String value) => pw.Container(
        width: 110,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primary)),
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
      );

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
      ),
      build: (context) => [
        pw.Center(
          child: pw.Column(children: [
            pw.Text('TEAM N MAKEOVERS',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primary)),
            pw.Text('HR · Attendance Report · ${d.periodLabel} · ${d.modeLabel}',
                style: pw.TextStyle(fontSize: 10, color: muted)),
          ]),
        ),
        pw.Divider(color: primary, thickness: 2, height: 20),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          kpi('Total Staff', '${d.totalStaff}'),
          kpi('Present', '${d.presentCount}'),
          kpi('On Leave', '${d.leaveCount}'),
          kpi('Avg Attendance', '${d.avgAttendance}%'),
          kpi('Total Hours', d.totalHours.toStringAsFixed(0)),
          kpi('New Hires', '${d.newHires}'),
          kpi('Departments', '${d.departments}'),
        ]),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: ['Name', 'Department', 'Designation', 'Status', 'Days', 'Hours', 'Att %'],
          data: [
            for (final r in d.rows)
              [
                r.name,
                r.department,
                r.designation,
                r.status,
                '${r.daysPresent}/${r.expectedDays}',
                r.hoursWorked.toStringAsFixed(1),
                '${r.attendancePercent}%',
              ],
          ],
          headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
          headerDecoration: pw.BoxDecoration(color: primary),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellHeight: 20,
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E7EB'), width: .5),
          cellAlignments: {
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Source: Timebox attendance software. Attendance % = days present / expected working days.',
          style: pw.TextStyle(fontSize: 8, color: muted),
        ),
      ],
    ),
  );

  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/attendance_${d.periodLabel.replaceAll(' ', '_')}.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], subject: 'Attendance Report ${d.periodLabel}');
}

/// Mobile: write the CSV to a temp file and share it.
Future<void> downloadAttendanceCsv(AttendanceReportData d) async {
  final csv = buildAttendanceCsv(d);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/attendance_${d.periodLabel.replaceAll(' ', '_')}.csv');
  await file.writeAsString(csv);
  await Share.shareXFiles([XFile(file.path)], subject: 'Attendance ${d.periodLabel}');
}
