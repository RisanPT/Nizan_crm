import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nizan_crm/features/reports/data/financial_analyst_report.dart';

String _money(num v) => 'Rs ${v.round()}';

Future<void> printFinancialReport(FinancialAnalystReport r) async {
  final primary = PdfColor.fromHex('#601A29');
  final muted = PdfColor.fromHex('#9CA3AF');

  final pdf = pw.Document();

  pw.Widget h2(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: primary)),
      );

  pw.Widget kpis(List<List<String>> pairs) => pw.Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final p in pairs)
            pw.Container(
              width: 150,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(p[1],
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: primary)),
                  pw.Text(p[0],
                      style: pw.TextStyle(fontSize: 8, color: muted)),
                ],
              ),
            ),
        ],
      );

  pw.Widget table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows.isEmpty ? [List.filled(headers.length, '—')] : rows,
        headerStyle: pw.TextStyle(
            color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
        headerDecoration: pw.BoxDecoration(color: primary),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellHeight: 20,
        border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E7EB'), width: .5),
      );

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      build: (context) => [
        pw.Center(
          child: pw.Column(children: [
            pw.Text('TEAM N MAKEOVERS',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold, color: primary)),
            pw.Text('Monthly Financial-Analyst Report · ${r.month}',
                style: pw.TextStyle(fontSize: 10, color: muted)),
          ]),
        ),
        pw.Divider(color: primary, thickness: 2, height: 20),
        h2('Sales'),
        kpis([
          ['Total bookings', '${r.totalBookings}'],
          ['Revenue', _money(r.totalRevenue)],
          ['Advance', _money(r.totalAdvance)],
          ['Balance', _money(r.totalBalance)],
          ['Discounts', _money(r.totalDiscounts)],
          ['Cancellations', '${r.totalCancellations}'],
          ['Enquiries', '${r.enquiries}'],
          ['Next month', '${r.forwardCount} · ${_money(r.forwardValue)}'],
        ]),
        pw.SizedBox(height: 8),
        table(
          ['Package', 'Bookings', 'Revenue', 'Advance', 'Balance', 'Cancel'],
          [
            for (final p in r.packageBreakdown)
              [
                p.package,
                '${p.count}',
                _money(p.revenue),
                _money(p.advance),
                _money(p.balance),
                '${p.cancellations}',
              ]
          ],
        ),
        if (r.leadSource.isNotEmpty) ...[
          h2('Lead source'),
          table(['Source', 'Count'],
              [for (final e in r.leadSource.entries) [e.key, '${e.value}']]),
        ],
        h2('Customer Relations'),
        kpis([
          ['Active clients', '${r.activeClients}'],
          ['New clients', '${r.newClients}'],
          ['Repeat clients', '${r.repeatClients}'],
          ['Referral leads', '${r.referralLeads}'],
        ]),
        pw.SizedBox(height: 8),
        table(['District', 'Bookings', 'Revenue'],
            [for (final d in r.districtBreakdown) [d.district, '${d.count}', _money(d.revenue)]]),
        if (r.cancellations.isNotEmpty) ...[
          h2('Cancellations (reason)'),
          table(['Customer', 'Package', 'Reason'],
              [for (final c in r.cancellations) [c.customer, c.package, c.reason]]),
        ],
        h2('Finance (from CRM)'),
        kpis([
          ['Cash collected', _money(r.cashCollected)],
          ['Receivables 0-30d', _money(r.aging0to30)],
          ['Receivables 31-90d', _money(r.aging31to90)],
          ['Receivables 90d+', _money(r.aging90plus)],
        ]),
        pw.SizedBox(height: 8),
        pw.Text(
            'Cash = verified collections this month. GST, bank balances, loans and '
            'full expense exports come from the accounting system (Zoho), not the CRM.',
            style: pw.TextStyle(fontSize: 8, color: muted)),
      ],
    ),
  );

  final bytes = await pdf.save();
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/financial_report_${r.month}.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)],
      subject: 'Financial Report ${r.month}');
}
