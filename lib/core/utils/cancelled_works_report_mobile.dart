import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nizan_crm/features/bookings/data/booking.dart';

Future<void> printCancelledWorksReport(
  List<Booking> cancelled, {
  String periodLabel = 'All time',
}) async {
  final primary = PdfColor.fromHex('#601A29');
  final headerBg = PdfColor.fromHex('#601A29');
  final border = PdfColor.fromHex('#E5E7EB');
  final zebra = PdfColor.fromHex('#FAF7F8');
  final muted = PdfColor.fromHex('#9CA3AF');
  final red = PdfColor.fromHex('#B91C1C');

  String dash(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? '—' : s;
  }

  String money(double v) => 'Rs ${v.toStringAsFixed(0)}';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String date(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')} ${months[l.month - 1]} ${l.year}';
  }

  final now = DateTime.now();
  final totalValue = cancelled.fold<double>(0, (s, b) => s + b.totalPrice);
  final totalAdvance = cancelled.fold<double>(0, (s, b) => s + b.advanceAmount);

  final pdf = pw.Document();

  pw.Widget cell(String text, {bool bold = false, PdfColor? color, pw.TextAlign? align}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      );

  pw.Widget headerCell(String text, {pw.TextAlign? align}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: pw.Text(
          text.toUpperCase(),
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        ),
      );

  pw.Widget statCard(String k, String v, {PdfColor? valueColor}) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: border),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(k.toUpperCase(),
                  style: pw.TextStyle(fontSize: 7.5, color: muted)),
              pw.SizedBox(height: 3),
              pw.Text(v,
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: valueColor)),
            ],
          ),
        ),
      );

  const widths = <int, pw.TableColumnWidth>{
    0: pw.FixedColumnWidth(18),
    1: pw.FlexColumnWidth(1.4),
    2: pw.FlexColumnWidth(2.0),
    3: pw.FlexColumnWidth(1.6),
    4: pw.FlexColumnWidth(1.6),
    5: pw.FlexColumnWidth(1.6),
    6: pw.FlexColumnWidth(1.3),
    7: pw.FlexColumnWidth(1.3),
    8: pw.FlexColumnWidth(2.0),
  };

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      build: (context) => [
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: primary, width: 2)),
          ),
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TEAM N MAKEOVERS',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: primary)),
                  pw.SizedBox(height: 2),
                  pw.Text('Cancelled Works Report · $periodLabel',
                      style: pw.TextStyle(fontSize: 10, color: muted)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generated ${date(now)}',
                      style: pw.TextStyle(fontSize: 9, color: muted)),
                  pw.Text('Cancelled works: ${cancelled.length}',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        if (cancelled.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 30),
            child: pw.Center(
              child: pw.Text('No cancelled works in this period.',
                  style: pw.TextStyle(fontSize: 12, color: muted)),
            ),
          )
        else ...[
          pw.Row(children: [
            statCard('Cancelled Works', '${cancelled.length}'),
            statCard('Value Lost', money(totalValue), valueColor: red),
            statCard('Advance Collected', money(totalAdvance)),
          ]),
          pw.SizedBox(height: 14),
          pw.Table(
            columnWidths: widths,
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: border, width: 0.5),
              bottom: pw.BorderSide(color: border, width: 0.5),
            ),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerBg),
                children: [
                  headerCell('#'),
                  headerCell('Booking'),
                  headerCell('Client'),
                  headerCell('Phone'),
                  headerCell('Service'),
                  headerCell('Event Date'),
                  headerCell('Amount', align: pw.TextAlign.right),
                  headerCell('Advance', align: pw.TextAlign.right),
                  headerCell('Location'),
                ],
              ),
              for (var i = 0; i < cancelled.length; i++)
                pw.TableRow(
                  decoration:
                      i.isOdd ? pw.BoxDecoration(color: zebra) : null,
                  children: [
                    cell('${i + 1}', color: muted),
                    cell(dash(cancelled[i].bookingNumber)),
                    cell(dash(cancelled[i].customerName), bold: true),
                    cell(dash(cancelled[i].phone)),
                    cell(dash(cancelled[i].service)),
                    cell(date(cancelled[i].serviceStart)),
                    cell(money(cancelled[i].totalPrice), align: pw.TextAlign.right),
                    cell(money(cancelled[i].advanceAmount), align: pw.TextAlign.right),
                    cell([
                      cancelled[i].district.trim(),
                      cancelled[i].region.trim(),
                    ].where((s) => s.isNotEmpty).join(', ')),
                  ],
                ),
            ],
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Text('Team N Makeovers · Confidential sales report',
              style: pw.TextStyle(fontSize: 8, color: muted)),
        ),
      ],
    ),
  );

  final bytes = await pdf.save();
  final tempDir = await getTemporaryDirectory();
  final fileName =
      'cancelled_works_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf';
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Cancelled Works Report',
  );
}
