import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nizan_crm/core/models/spot_invoice.dart';

Future<void> printSpotInvoice(SpotInvoiceData data) async {
  final primary = PdfColor.fromHex('#601A29');
  final border = PdfColor.fromHex('#E5E7EB');
  final muted = PdfColor.fromHex('#9CA3AF');

  String money(double v) => 'Rs ${v.toStringAsFixed(0)}';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String date(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')} ${months[l.month - 1]} ${l.year}';
  }

  final pdf = pw.Document();

  pw.Widget metaCell(String k, String v) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(k.toUpperCase(),
              style: pw.TextStyle(fontSize: 8, color: muted)),
          pw.SizedBox(height: 2),
          pw.Text(v,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      );

  pw.Widget row(String name, String amount, {bool header = false}) =>
      pw.Container(
        decoration: pw.BoxDecoration(
          color: header ? primary : null,
          border: header
              ? null
              : pw.Border(bottom: pw.BorderSide(color: border, width: 0.5)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text(name,
                style: pw.TextStyle(
                    fontSize: header ? 9 : 10,
                    fontWeight:
                        header ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: header ? PdfColors.white : null)),
          ),
          pw.Text(amount,
              style: pw.TextStyle(
                  fontSize: header ? 9 : 10,
                  fontWeight: pw.FontWeight.bold,
                  color: header ? PdfColors.white : null)),
        ]),
      );

  pdf.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Column(children: [
              pw.Container(
                width: 54,
                height: 54,
                decoration:
                    pw.BoxDecoration(color: primary, shape: pw.BoxShape.circle),
                alignment: pw.Alignment.center,
                child: pw.Text('N',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 26)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('TEAM N MAKEOVERS',
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: primary)),
              pw.Text('QUOTATION',
                  style: pw.TextStyle(fontSize: 10, color: muted)),
            ]),
          ),
          pw.Divider(color: primary, thickness: 2, height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              metaCell('Quotation No.', data.invoiceNo),
              metaCell('Date', date(data.date)),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: border),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BILLED TO',
                    style: pw.TextStyle(fontSize: 8, color: muted)),
                pw.SizedBox(height: 3),
                pw.Text(
                    data.customerName.trim().isEmpty ? '-' : data.customerName,
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
                if (data.customerPhone.trim().isNotEmpty)
                  pw.Text('Phone: ${data.customerPhone}',
                      style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          row('Description', 'Amount', header: true),
          if (data.lines.isEmpty)
            row('Makeup services', money(data.total))
          else
            ...data.lines.map((l) => row(l.label, money(l.amount))),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal',
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(money(data.total),
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  color: primary,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                      pw.Text(money(data.total),
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          if (data.note.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Note: ${data.note.trim()}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
          pw.SizedBox(height: 18),
          pw.Text(
              'This is a quotation for makeup services and is not a tax invoice. '
              'Prices are subject to confirmation.',
              style: pw.TextStyle(fontSize: 9, color: muted)),
          pw.Spacer(),
          pw.Center(
            child: pw.Text('Team N Makeovers — Quotation',
                style: pw.TextStyle(fontSize: 8, color: muted)),
          ),
        ],
      ),
    ),
  );

  final bytes = await pdf.save();
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/quotation_${data.invoiceNo}.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)],
      subject: 'Quotation ${data.invoiceNo}');
}
