import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nizan_crm/models/customer.dart';

Future<void> printClientsReport(List<Customer> clients) async {
  final primary = PdfColor.fromHex('#601A29');
  final border = PdfColor.fromHex('#E5E7EB');
  final headerBg = PdfColor.fromHex('#601A29');
  final zebra = PdfColor.fromHex('#FAF7F8');
  final muted = PdfColor.fromHex('#9CA3AF');

  String dash(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? '—' : s;
  }

  String email(String v) {
    final s = v.trim();
    return (s.isEmpty || s.contains('@placeholder')) ? '—' : s;
  }

  final now = DateTime.now();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final generatedAt =
      '${now.day} ${months[now.month - 1]} ${now.year}';

  final pdf = pw.Document();

  pw.Widget cell(String text, {bool bold = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      );

  pw.Widget headerCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: pw.Text(
          text.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      );

  const widths = <int, pw.TableColumnWidth>{
    0: pw.FixedColumnWidth(22),
    1: pw.FlexColumnWidth(2.2),
    2: pw.FlexColumnWidth(1.6),
    3: pw.FlexColumnWidth(2.6),
    4: pw.FlexColumnWidth(2.6),
    5: pw.FlexColumnWidth(1.1),
    6: pw.FlexColumnWidth(1.4),
  };

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text('Clients Directory Report (cont.)',
                  style: pw.TextStyle(fontSize: 9, color: muted)),
            ),
      build: (context) => [
        // Title block (first page)
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
                          fontSize: 17,
                          fontWeight: pw.FontWeight.bold,
                          color: primary)),
                  pw.SizedBox(height: 2),
                  pw.Text('Clients Directory — Full Report',
                      style: pw.TextStyle(fontSize: 10, color: muted)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generated $generatedAt',
                      style: pw.TextStyle(fontSize: 9, color: muted)),
                  pw.Text('Total clients: ${clients.length}',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        if (clients.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 30),
            child: pw.Center(
              child: pw.Text('No clients to report.',
                  style: pw.TextStyle(fontSize: 12, color: muted)),
            ),
          )
        else
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
                  headerCell('Name'),
                  headerCell('Phone'),
                  headerCell('Email'),
                  headerCell('Address'),
                  headerCell('Pincode'),
                  headerCell('Status'),
                ],
              ),
              for (var i = 0; i < clients.length; i++)
                pw.TableRow(
                  decoration: i.isOdd
                      ? pw.BoxDecoration(color: zebra)
                      : null,
                  children: [
                    cell('${i + 1}', color: muted),
                    cell(dash(clients[i].name), bold: true),
                    cell(dash(clients[i].phone)),
                    cell(email(clients[i].email)),
                    cell(dash(clients[i].address)),
                    cell(dash(clients[i].pincode)),
                    cell(dash(clients[i].status)),
                  ],
                ),
            ],
          ),
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Text('Team N Makeovers · Confidential client report',
              style: pw.TextStyle(fontSize: 8, color: muted)),
        ),
      ],
    ),
  );

  final bytes = await pdf.save();
  final tempDir = await getTemporaryDirectory();
  final fileName =
      'clients_report_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf';
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Clients Directory Report',
  );
}
