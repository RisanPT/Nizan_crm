import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:nizan_crm/core/utils/branded_pdf.dart';
import 'package:nizan_crm/features/hr/lms/data/lms_models.dart';

/// A real, printable copy of an orientation plan (2026-11-24). It replaces the
/// old "Print / Export PDF" button that only showed a success message.
Future<Uint8List> buildOrientationPlanPdfBytes(OrientationPlan plan) async {
  final logo = await brandedPdfLogo();
  final doc = pw.Document(title: '${plan.roleTitle} - Orientation Plan');
  final muted = PdfColors.grey700;

  pw.Widget header() => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          if (logo != null) ...[
            pw.SizedBox(height: 42, width: 42, child: pw.Image(logo, fit: pw.BoxFit.contain)),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(pdfSafe('${plan.roleTitle} - Orientation Plan'),
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
              pw.Text(
                pdfSafe('Department: ${plan.department}   |   Mentor: ${plan.trainerName}   |   ${plan.days.length} days'),
                style: pw.TextStyle(fontSize: 10, color: muted),
              ),
            ]),
          ),
          pw.Text('Team N Makeovers',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
        ]),
        pw.SizedBox(height: 8),
        pw.Container(height: 2, color: kPdfBrand),
        pw.SizedBox(height: 12),
      ]);

  final days = [...plan.days]..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

  doc.addPage(pw.MultiPage(
    maxPages: 100,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 30, 32, 34),
    header: (ctx) => ctx.pageNumber == 1 ? header() : pw.SizedBox(height: 0),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Printed ${DateFormat('d MMM yyyy').format(DateTime.now())}',
          style: pw.TextStyle(fontSize: 8, color: muted)),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 8, color: muted)),
    ]),
    build: (ctx) => [
      if (plan.overview.trim().isNotEmpty) ...[
        pw.Text('Overview', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
        pw.SizedBox(height: 4),
        pw.Text(pdfSafe(plan.overview.trim()), style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
        pw.SizedBox(height: 14),
      ],
      if (days.isEmpty) pw.Text('No days have been added to this plan yet.', style: pw.TextStyle(color: muted)),
      for (final d in days) ...[
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: kPdfBrandLt,
          child: pw.Row(children: [
            pw.Text('DAY ${d.dayNumber}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Text(pdfSafe(d.title), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ),
            if (d.mandatorySignOff) pw.Text('Sign-off required', style: pw.TextStyle(fontSize: 8.5, color: muted)),
          ]),
        ),
        pw.SizedBox(height: 4),
        for (final t in d.topics)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
            child: pw.Text(pdfSafe('-  $t'), style: const pw.TextStyle(fontSize: 10)),
          ),
        if (d.notes.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, top: 2),
            child: pw.Text(pdfSafe('Notes: ${d.notes.trim()}'), style: pw.TextStyle(fontSize: 9, color: muted)),
          ),
        pw.SizedBox(height: 10),
      ],
    ],
  ));
  return doc.save();
}

/// Opens the system print dialog (which also offers "Save as PDF").
Future<void> printOrientationPlan(OrientationPlan plan) async {
  final bytes = await buildOrientationPlanPdfBytes(plan);
  final safe = plan.roleTitle.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  await Printing.layoutPdf(onLayout: (_) => bytes, name: 'Orientation_Plan_$safe.pdf');
}
