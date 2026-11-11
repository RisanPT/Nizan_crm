import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:nizan_crm/core/utils/branded_pdf.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import '../data/marketing_eod_models.dart';

Future<Uint8List> buildIndividualDashboardPdfBytes(MarketingIndividualDashboardData data) async {
  final doc = pw.Document();
  final logo = await brandedPdfLogo();
  final printedDate = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) {
        return [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.SizedBox(height: 40, width: 40, child: pw.Image(logo, fit: pw.BoxFit.contain)),
                pw.SizedBox(width: 10),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TEAM N MAKEOVERS - MARKETING DEPARTMENT',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kPdfBrand),
                    ),
                    pw.Text(
                      'Monthly Activity Dashboard',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                    ),
                    pw.Text(
                      'Member: ${pdfSafe(data.member.name)} (${pdfSafe(data.member.role ?? "")})  |  Month: ${data.month}  |  Period: ${data.period}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.Text('Team N ERP', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 2, color: kPdfBrand),
          pw.SizedBox(height: 10),

          // 4 Summary Tiles
          pw.Row(
            children: [
              _summaryBox('Days Reported', data.summaryTiles['daysReported']?.toString() ?? '—'),
              pw.SizedBox(width: 8),
              _summaryBox('Total Output', data.summaryTiles['totalOutput']?.toString() ?? '0'),
              pw.SizedBox(width: 8),
              _summaryBox('Target Achieved', '${data.summaryTiles['targetAchievedPct'] ?? 0}%'),
              pw.SizedBox(width: 8),
              _summaryBox(
                'MTD vs Expected (${data.summaryTiles['workingDaysElapsed'] ?? 0}/${data.summaryTiles['workingDays'] ?? 0} days)',
                data.summaryTiles['mtdPacePct'] != null ? '${data.summaryTiles['mtdPacePct']}%' : '—',
              ),
              pw.SizedBox(width: 8),
              _summaryBox('Hours Worked', data.summaryTiles['hoursWorked']?.toString() ?? '—'),
            ],
          ),
          pw.SizedBox(height: 14),

          // Table 1: Activity Numbers — Target vs Achieved
          pw.Text('Activity Numbers - Target vs Achieved',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Activity', 'Group', 'Target', 'Achieved', 'Achieved %', 'Expected by Today', 'MTD vs Exp.', 'Daily Avg', 'Best Day', 'Status'],
            data: data.activityNumbers.map((r) {
              return [
                r.name,
                r.groupName,
                r.target != null ? r.target!.toStringAsFixed(0) : '—',
                r.achieved.toStringAsFixed(0),
                r.achievedPct != null ? '${r.achievedPct}%' : '—',
                r.expectedToDate != null ? r.expectedToDate!.toStringAsFixed(1) : '—',
                r.pacePct != null ? '${r.pacePct}%' : '—',
                r.dailyAvg,
                r.bestDay['count'] != null && r.bestDay['count'] > 0
                    ? '${r.bestDay['count']} (${r.bestDay['date']?.toString().split('-').last ?? ""})'
                    : '—',
                r.status.toUpperCase(),
              ].map(pdfSafe).toList();
            }).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: kPdfBrand),
            headerDecoration: const pw.BoxDecoration(color: kPdfBrandLt),
            cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
            cellHeight: 18,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
            },
          ),
          pw.SizedBox(height: 14),

          // Table 2: Week-wise Activity Numbers
          pw.Text('Week-wise Activity Numbers',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Activity', 'W1 (01-07)', 'W2 (08-14)', 'W3 (15-21)', 'W4 (22-28)', 'W5 (29-31)', 'Month Total'],
            data: [
              ...data.weekWiseRows.map((w) {
                return [
                  w.name,
                  w.w1.toStringAsFixed(0),
                  w.w2.toStringAsFixed(0),
                  w.w3.toStringAsFixed(0),
                  w.w4.toStringAsFixed(0),
                  w.w5.toStringAsFixed(0),
                  w.monthTotal.toStringAsFixed(0),
                ].map(pdfSafe).toList();
              }),
              [
                'TOTAL OUTPUT',
                data.totalOutputRow.w1.toStringAsFixed(0),
                data.totalOutputRow.w2.toStringAsFixed(0),
                data.totalOutputRow.w3.toStringAsFixed(0),
                data.totalOutputRow.w4.toStringAsFixed(0),
                data.totalOutputRow.w5.toStringAsFixed(0),
                data.totalOutputRow.monthTotal.toStringAsFixed(0),
              ].map(pdfSafe).toList(),
            ],
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: kPdfBrand),
            headerDecoration: const pw.BoxDecoration(color: kPdfBrandLt),
            cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
            cellHeight: 18,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 14),

          // Remarks & Signatures
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              color: PdfColors.grey50,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Highlights & Manager Remarks:',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
                pw.SizedBox(height: 3),
                pw.Text(
                  pdfSafe(data.remarks['managerRemarks']?.toString().isNotEmpty == true
                      ? data.remarks['managerRemarks']
                      : 'No remarks recorded for this month.'),
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(width: 150, height: 0.5, color: PdfColors.grey400),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          data.remarks['memberAckAt'] != null
                              ? 'Acknowledged: ${DateFormat('d MMM yyyy').format(DateTime.parse(data.remarks['memberAckAt']))}'
                              : 'Team Member Signature',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(width: 150, height: 0.5, color: PdfColors.grey400),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          data.remarks['managerSignedAt'] != null
                              ? 'Signed Off: ${DateFormat('d MMM yyyy').format(DateTime.parse(data.remarks['managerSignedAt']))}'
                              : 'Marketing Manager Signature',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];
      },
      footer: (ctx) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Auto-generated from the EOD Log  -  Printed $printedDate',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
            ],
          ),
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _summaryBox(String title, String value) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: kPdfBrandLt,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfBrand),
          ),
        ],
      ),
    ),
  );
}

// ── Team Summary PDF (A4 Landscape) ─────────────────────────────────────────

Future<Uint8List> buildTeamSummaryPdfBytes(MarketingTeamSummaryData data) async {
  final doc = pw.Document();
  final logo = await brandedPdfLogo();
  final printedDate = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());

  final headers = [
    'Group',
    'Activity',
    ...data.members.map((m) => m.shortName),
    'TEAM TOTAL',
  ];

  final rows = <List<dynamic>>[];

  // 1. Overview rows
  final ov = data.overviewRows;
  final overviewDefs = [
    ('Days Reported', ov['daysReported']),
    ('Hours Worked', ov['hoursWorked']),
    ('Total Output', ov['totalOutput']),
    ('Avg Target Achieved', ov['avgTargetAchieved']),
    ('MTD vs Expected', ov['mtdPace']),
    ('Working Days (so far / month)', ov['workingDaysElapsed']),
  ];

  for (final def in overviewDefs) {
    final label = def.$1;
    final obj = def.$2;
    if (obj is Map) {
      final mVals = (obj['memberValues'] as Map?) ?? {};
      rows.add([
        'OVERVIEW',
        label,
        ...data.members.map((m) => mVals[m.id]?.toString() ?? '—'),
        obj['teamTotal']?.toString() ?? '—',
      ]);
    }
  }

  // 2. Metrics grouped
  for (final m in data.metricRows) {
    rows.add([
      m.groupName,
      m.name,
      ...data.members.map((mem) => m.memberValues[mem.id]?.toString() ?? '—'),
      m.teamTotal?.toString() ?? '—',
    ]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) {
        return [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.SizedBox(height: 36, width: 36, child: pw.Image(logo, fit: pw.BoxFit.contain)),
                pw.SizedBox(width: 8),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TEAM N MAKEOVERS - MARKETING DEPARTMENT',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: kPdfBrand),
                    ),
                    pw.Text(
                      'Team Summary Dashboard - ${data.month}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                    ),
                  ],
                ),
              ),
              pw.Text('Team N ERP', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 2, color: kPdfBrand),
          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headers: headers.map(pdfSafe).toList(),
            data: rows.map((r) => r.map(pdfSafe).toList()).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: kPdfBrand),
            headerDecoration: const pw.BoxDecoration(color: kPdfBrandLt),
            cellStyle: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey900),
            cellHeight: 17,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              for (var i = 2; i < headers.length; i++) i: pw.Alignment.centerRight,
            },
          ),
        ];
      },
      footer: (ctx) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Team N Marketing Team Summary  -  Printed $printedDate',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            ],
          ),
        );
      },
    ),
  );

  return doc.save();
}

Future<void> downloadIndividualDashboardPdf(MarketingIndividualDashboardData data) async {
  final bytes = await buildIndividualDashboardPdfBytes(data);
  final filename = 'Marketing_Dashboard_${data.member.shortName}_${data.month}.pdf';
  await saveFileBytes(filename, bytes, mime: 'application/pdf');
}

Future<void> printIndividualDashboardPdf(MarketingIndividualDashboardData data) async {
  final bytes = await buildIndividualDashboardPdfBytes(data);
  await Printing.layoutPdf(onLayout: (_) => bytes);
}

Future<void> downloadTeamSummaryPdf(MarketingTeamSummaryData data) async {
  final bytes = await buildTeamSummaryPdfBytes(data);
  final filename = 'Marketing_Team_Summary_${data.month}.pdf';
  await saveFileBytes(filename, bytes, mime: 'application/pdf');
}

Future<void> printTeamSummaryPdf(MarketingTeamSummaryData data) async {
  final bytes = await buildTeamSummaryPdfBytes(data);
  await Printing.layoutPdf(onLayout: (_) => bytes);
}
