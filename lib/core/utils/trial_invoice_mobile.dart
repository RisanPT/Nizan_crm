import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nizan_crm/core/models/trial.dart';

Future<void> printTrialInvoice(Trial trial) async {
  final primary = PdfColor.fromHex('#601A29');
  final border = PdfColor.fromHex('#E5E7EB');
  final muted = PdfColor.fromHex('#9CA3AF');
  final headerBg = PdfColor.fromHex('#601A29');

  String money(double v) => 'Rs ${v.toStringAsFixed(0)}';
  String label(TrialItem i) {
    final look = i.lookLabel.trim();
    final pkg = i.packageName.trim();
    if (look.isNotEmpty && pkg.isNotEmpty && look != pkg) return '$pkg - $look';
    if (look.isNotEmpty) return look;
    if (pkg.isNotEmpty) return pkg;
    return 'Trial look';
  }

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String date(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')} ${months[l.month - 1]} ${l.year}';
  }

  final items = trial.trialItems;
  final total = items.fold<double>(0, (s, i) => s + i.price);
  final invNo = trial.trialNumber.trim().isNotEmpty
      ? trial.trialNumber.trim()
      : 'TRIAL-${trial.id}';
  final status =
      trial.status.toLowerCase() == 'completed' ? 'COMPLETED' : 'SCHEDULED';

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

  pw.Widget row(String name, String amount, {bool header = false}) => pw.Container(
        decoration: pw.BoxDecoration(
          color: header ? headerBg : null,
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
                    fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
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
              pw.Text('TRIAL INVOICE',
                  style: pw.TextStyle(fontSize: 10, color: muted)),
            ]),
          ),
          pw.Divider(color: primary, thickness: 2, height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              metaCell('Invoice No.', invNo),
              metaCell('Trial Date', date(trial.trialDate)),
              metaCell('Status', status),
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
                    trial.clientName.trim().isEmpty ? '-' : trial.clientName,
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
                if (trial.phone.trim().isNotEmpty)
                  pw.Text('Phone: ${trial.phone}',
                      style: const pw.TextStyle(fontSize: 10)),
                if (trial.email.trim().isNotEmpty)
                  pw.Text('Email: ${trial.email}',
                      style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('TRIAL LOOKS',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: primary)),
          pw.SizedBox(height: 6),
          row('Look / Package', 'Amount', header: true),
          if (items.isEmpty)
            row('${trial.clientName} - Makeup Trial', money(total))
          else
            ...items.map((i) => row(label(i), money(i.price))),
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
                    pw.Text(money(total),
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
                      pw.Text(money(total),
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
          pw.SizedBox(height: 18),
          pw.Text('Terms & Conditions',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primary)),
          pw.SizedBox(height: 4),
          pw.Bullet(
              text:
                  'This is a trial invoice for makeup trial services and is not a tax invoice.',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Bullet(
              text: 'Trial charges are non-refundable once rendered.',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Spacer(),
          pw.Center(
            child: pw.Text('Team N Makeovers - Trial invoice',
                style: pw.TextStyle(fontSize: 8, color: muted)),
          ),
        ],
      ),
    ),
  );

  final bytes = await pdf.save();
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/trial_invoice_$invNo.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], subject: 'Trial Invoice $invNo');
}
