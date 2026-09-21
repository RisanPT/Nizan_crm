import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nizan_crm/core/utils/file_saver.dart';

/// Shared branded-PDF builder for every in-app report: a Team N logo header,
/// brand-coloured section tables, a page footer, and glyph-safe text (the
/// built-in PDF fonts lack characters like the en-dash, so we normalise them).

const PdfColor kPdfBrand = PdfColor.fromInt(0xFF601A29); // Team N maroon
const PdfColor kPdfBrandLt = PdfColor.fromInt(0xFFF3E9EC);
final PdfColor _ink = PdfColors.grey900;
final PdfColor _muted = PdfColors.grey700;

pw.MemoryImage? _logoCache;
bool _logoTried = false;

Future<pw.MemoryImage?> _logo() async {
  if (_logoTried) return _logoCache;
  _logoTried = true;
  try {
    final data = await rootBundle.load('assets/images/teamn_logo.png');
    _logoCache = pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    _logoCache = null; // header still renders without the logo
  }
  return _logoCache;
}

/// The built-in Helvetica/Times fonts render many Unicode punctuation marks as
/// blank boxes (en/em dash, smart quotes, bullet, ellipsis). Swap to ASCII.
String pdfSafe(Object? v) => v
    .toString()
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('•', '*')
    .replaceAll('‘', "'")
    .replaceAll('’', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('…', '...')
    .replaceAll(' ', ' ');

/// One titled table in a report.
class PdfSection {
  final String title;
  final List<String> headers;
  final List<List<dynamic>> rows;
  const PdfSection(this.title, this.headers, this.rows);
}

pw.Widget _header(pw.MemoryImage? logo, String title, String? subtitle) {
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      if (logo != null) ...[
        pw.SizedBox(height: 46, width: 46, child: pw.Image(logo, fit: pw.BoxFit.contain)),
        pw.SizedBox(width: 12),
      ],
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(pdfSafe(title),
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
          if (subtitle != null && subtitle.trim().isNotEmpty)
            pw.Text(pdfSafe(subtitle), style: pw.TextStyle(fontSize: 11, color: _muted)),
        ]),
      ),
      pw.Text('Team N ERP',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
    ]),
    pw.SizedBox(height: 8),
    pw.Container(height: 2.5, color: kPdfBrand),
  ]);
}

pw.Widget _footer(pw.Context ctx) {
  final gen = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.6)),
    ),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Team N ERP  -  generated $gen',
          style: pw.TextStyle(fontSize: 8, color: _muted)),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: _muted)),
    ]),
  );
}

pw.Widget _sectionTable(PdfSection s) {
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.SizedBox(height: 16),
    if (s.title.trim().isNotEmpty) ...[
      pw.Text(pdfSafe(s.title),
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
      pw.SizedBox(height: 5),
    ],
    pw.TableHelper.fromTextArray(
      headers: s.headers.map(pdfSafe).toList(),
      data: (s.rows.isEmpty ? [['-', '']] : s.rows)
          .map((row) => row.map(pdfSafe).toList())
          .toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: kPdfBrand),
      headerDecoration: const pw.BoxDecoration(color: kPdfBrandLt),
      cellStyle: pw.TextStyle(fontSize: 9.5, color: _ink),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.4)),
      ),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellHeight: 20,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        for (var i = 1; i < s.headers.length; i++) i: pw.Alignment.centerRight,
      },
    ),
  ]);
}

/// Build a branded multi-section report as PDF bytes.
Future<Uint8List> buildBrandedReportBytes({
  required String title,
  String? subtitle,
  required List<PdfSection> sections,
}) async {
  final logo = await _logo();
  final doc = pw.Document(title: title);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(30, 30, 30, 34),
    header: (ctx) => ctx.pageNumber == 1
        ? _header(logo, title, subtitle)
        : pw.SizedBox(height: 0),
    footer: _footer,
    build: (ctx) => [for (final s in sections) _sectionTable(s)],
  ));
  return doc.save();
}

/// Build + save a branded report (browser download on web, share on mobile).
Future<void> saveBrandedReportPdf({
  required String fileName,
  required String title,
  String? subtitle,
  required List<PdfSection> sections,
}) async {
  final bytes = await buildBrandedReportBytes(
      title: title, subtitle: subtitle, sections: sections);
  await saveFileBytes(fileName, bytes, mime: 'application/pdf');
}
