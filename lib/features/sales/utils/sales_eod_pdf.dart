import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:nizan_crm/core/utils/branded_pdf.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/features/sales/data/sales_eod_report.dart';

final _countFmt = NumberFormat.decimalPattern('en_IN');

String _rsPdf(double amount) => 'Rs ${_countFmt.format(amount.round())}';
String _rsText(double amount) => '₹${_countFmt.format(amount.round())}';

String _formatDateHeading(String dateStr) {
  try {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return DateFormat('d-MMM-yy').format(dt);
    }
  } catch (_) {}
  return dateStr;
}

/// Builds branded PDF bytes for a Sales End of Day (EOD) Report,
/// faithfully matching the spreadsheet layouts in the user specifications.
Future<Uint8List> buildSalesEodPdfBytes(SalesEodReport report) async {
  final dateLabel = report.reportDateFormatted.isNotEmpty
      ? report.reportDateFormatted
      : _formatDateHeading(report.date);
  final isIndividual = !report.isTeam && report.salesPerson != null;
  final title = isIndividual
      ? 'End of Day Sales Report - Individual'
      : 'End of Day Sales Report - Team Ledger';

  final repName = isIndividual ? report.salesPerson!.name : 'All Sales Team';
  final monthLabel = report.monthName.isNotEmpty ? report.monthName : 'Current Month';
  final subtitle = 'Report Date: $dateLabel  |  Sales Person: $repName  |  Month: $monthLabel  |  Lead-count: ${report.leadCountTask}';

  final sections = <PdfSection>[];

  // ── 1. Table 1: TODAY — ACHIEVABLE TARGET vs ACHIEVED (Screenshot 2) ──
  final bToday = report.bookingsTargetToday;
  final vToday = report.bookingValueTargetToday;
  final shortExcessBookings = bToday.shortExcess <= 0
      ? '(${bToday.shortExcess.abs().toStringAsFixed(1)})'
      : bToday.shortExcess.toStringAsFixed(1);
  final shortExcessValue = vToday.shortExcess < 0
      ? '-(Rs ${_countFmt.format(vToday.shortExcess.abs().round())})'
      : 'Rs ${_countFmt.format(vToday.shortExcess.round())}';

  sections.add(
    PdfSection(
      'TODAY - ACHIEVABLE TARGET vs ACHIEVED',
      ['Metric', 'Achievable Target', 'Achieved', 'Achievement %', 'Short / (Excess)'],
      [
        [
          'Bookings (Nos)',
          bToday.achievableTarget.toStringAsFixed(1),
          '${bToday.achieved.toInt()}',
          '${bToday.achievementPct.toStringAsFixed(1)}%',
          shortExcessBookings,
        ],
        [
          'Booking Value (Rs)',
          _rsPdf(vToday.achievableTarget),
          _rsPdf(vToday.achieved),
          '${vToday.achievementPct.toStringAsFixed(1)}%',
          shortExcessValue,
        ],
      ],
    ),
  );

  // ── 2. Table 2: MONTH-TO-DATE (1st of month → report date) (Screenshot 2) ──
  final bMtd = report.bookingsTargetMtd;
  final vMtd = report.bookingValueTargetMtd;

  sections.add(
    PdfSection(
      'MONTH-TO-DATE (1st of month -> report date)',
      ['Metric', 'MTD Target (Till Date)', 'MTD Achieved', 'Achievement %', 'Full Month Target', 'Balance to Target'],
      [
        [
          'Bookings (Nos)',
          bMtd.mtdTarget.toStringAsFixed(1),
          '${bMtd.mtdAchieved.toInt()}',
          '${bMtd.mtdAchievementPct.toStringAsFixed(1)}%',
          bMtd.monthlyTarget.toStringAsFixed(1),
          bMtd.balanceToTarget.toStringAsFixed(1),
        ],
        [
          'Booking Value (Rs)',
          _rsPdf(vMtd.mtdTarget),
          _rsPdf(vMtd.mtdAchieved),
          '${vMtd.mtdAchievementPct.toStringAsFixed(1)}%',
          _rsPdf(vMtd.monthlyTarget),
          _rsPdf(vMtd.balanceToTarget),
        ],
      ],
    ),
  );

  // ── 3. Table 3: BOOKINGS BY SOURCE (Screenshot 2) ──
  sections.add(
    PdfSection(
      'BOOKINGS BY SOURCE',
      ['Source', 'Today', 'MTD', 'Share of MTD'],
      [
        ['Organic', '${report.organicBookings.today}', '${report.organicBookings.mtd}', '${report.organicBookings.shareOfMtd.toStringAsFixed(1)}%'],
        ['Paid Ads (Kerala page)', '${report.paidAdsBookings.today}', '${report.paidAdsBookings.mtd}', '${report.paidAdsBookings.shareOfMtd.toStringAsFixed(1)}%'],
        if (report.trialBookings.today > 0 || report.trialBookings.mtd > 0)
          ['Trial Bookings', '${report.trialBookings.today}', '${report.trialBookings.mtd}', '${report.trialBookings.shareOfMtd.toStringAsFixed(1)}%'],
        ['Total Bookings', '${report.totalBookings.today}', '${report.totalBookings.mtd}', '100.0%'],
      ],
    ),
  );

  // ── 4. Table 4: LEADS & FOLLOW-UPS LOGGED (Screenshot 3) ──
  sections.add(
    PdfSection(
      'LEADS & FOLLOW-UPS LOGGED',
      ['Count', 'Today', 'MTD'],
      [
        ['WhatsApp Leads (Organic)', '${report.whatsappLeads.today.toInt()}', '${report.whatsappLeads.mtd.toInt()}'],
        ['IG Leads - Main Page', '${report.igMainLeads.today.toInt()}', '${report.igMainLeads.mtd.toInt()}'],
        ['IG Leads - Kerala Page', '${report.igKeralaLeads.today.toInt()}', '${report.igKeralaLeads.mtd.toInt()}'],
        ['Paid Ads Leads', '${report.paidAdsLeads.today.toInt()}', '${report.paidAdsLeads.mtd.toInt()}'],
        if (report.trialCampaignLeads.today > 0 || report.trialCampaignLeads.mtd > 0)
          ['Trial Campaign Leads', '${report.trialCampaignLeads.today.toInt()}', '${report.trialCampaignLeads.mtd.toInt()}'],
        ['Leads Contacted', '${report.leadsContacted.today.toInt()}', '${report.leadsContacted.mtd.toInt()}'],
        ['Follow-ups Done', '${report.followUpsDone.today.toInt()}', '${report.followUpsDone.mtd.toInt()}'],
        ['Contacted -> Booking %', '${report.contactedToBookingPct.today.toStringAsFixed(1)}%', '${report.contactedToBookingPct.mtd.toStringAsFixed(1)}%'],
        ['Team Missed Leads (IG - WhatsApp)', '${report.teamMissedLeads.today.toInt()}', '${report.teamMissedLeads.mtd.toInt()}'],
      ],
    ),
  );

  // ── 5. Table 5: TRIAL BOOKING CAMPAIGN (Screenshot 3) ──
  sections.add(
    PdfSection(
      'TRIAL BOOKING CAMPAIGN',
      ['Metric', 'Today', 'MTD'],
      [
        ['Trial Campaign Leads', '${report.trialCampaignLeadsMetric.today.toInt()}', '${report.trialCampaignLeadsMetric.mtd.toInt()}'],
        ['Trial Bookings', '${report.trialBookingsMetric.today.toInt()}', '${report.trialBookingsMetric.mtd.toInt()}'],
        [
          'Trial Conversion %',
          report.trialConversionPctMetric.today > 0 ? '${report.trialConversionPctMetric.today.toStringAsFixed(1)}%' : '-',
          report.trialConversionPctMetric.mtd > 0 ? '${report.trialConversionPctMetric.mtd.toStringAsFixed(1)}%' : '-',
        ],
      ],
    ),
  );

  // ── 6. Table 6: ORDER VALUE & PAYMENTS (Screenshot 3) ──
  sections.add(
    PdfSection(
      'ORDER VALUE & PAYMENTS',
      ['Metric', 'Today', 'MTD'],
      [
        ['Total Order Value (Rs)', _rsPdf(report.totalOrderValueMetric.today), _rsPdf(report.totalOrderValueMetric.mtd)],
        ['Advance Paid (Rs)', _rsPdf(report.advancePaidMetric.today), _rsPdf(report.advancePaidMetric.mtd)],
        ['Balance Due (Rs)', _rsPdf(report.balanceDueMetric.today), _rsPdf(report.balanceDueMetric.mtd)],
      ],
    ),
  );

  // ── 7. Team Daily Ledger Table (Screenshot 1) ──
  if (report.ledgerRows.isNotEmpty) {
    final ledgerTableRows = <List<dynamic>>[];

    // Top TOTAL row if available (matches Screenshot 1)
    if (report.ledgerTotals != null) {
      final t = report.ledgerTotals!;
      ledgerTableRows.add([
        'TOTAL',
        'All',
        '${t.whatsappLeads}',
        '${t.igMainLeads}',
        '${t.igKeralaLeads}',
        '${t.paidAdsLeads}',
        '${t.trialCampaignLeads}',
        '${t.leadsContacted}',
        '${t.followUpsDone}',
        '${t.organicBookings}',
        '${t.paidAdsBookings}',
        '${t.trialBookings}',
        _rsPdf(t.totalOrderValue),
        _rsPdf(t.advancePaid),
      ]);
    }

    for (final r in report.ledgerRows) {
      ledgerTableRows.add([
        r.date,
        r.salesPersonName,
        '${r.whatsappLeads}',
        '${r.igMainLeads}',
        '${r.igKeralaLeads}',
        '${r.paidAdsLeads}',
        '${r.trialCampaignLeads}',
        '${r.leadsContacted}',
        '${r.followUpsDone}',
        '${r.organicBookings}',
        '${r.paidAdsBookings}',
        '${r.trialBookings}',
        _rsPdf(r.totalOrderValue),
        _rsPdf(r.advancePaid),
      ]);
    }

    sections.add(
      PdfSection(
        'TEAM DAILY SALES LEDGER',
        [
          'Date',
          'Sales Person',
          'WhatsApp (Org)',
          'IG Main',
          'IG Kerala',
          'Paid Ads',
          'Trial Leads',
          'Contacted',
          'Follow-ups',
          'Org Bookings',
          'Paid Bookings',
          'Trial Bookings',
          'Total Value',
          'Advance Paid',
        ],
        ledgerTableRows,
      ),
    );
  }

  // ── 8. Bookings Closed Detail Table ──
  if (report.bookings.isNotEmpty) {
    sections.add(
      PdfSection(
        'Bookings Closed Today (${report.bookings.length})',
        ['Booking #', 'Customer Name', 'Phone', 'Source', 'Service', 'Total Price', 'Advance', 'Status'],
        [
          for (final b in report.bookings)
            [
              b.bookingNumber.isNotEmpty ? b.bookingNumber : b.id.substring(b.id.length >= 6 ? b.id.length - 6 : 0),
              b.customerName,
              b.phone,
              b.source,
              b.service,
              _rsPdf(b.totalPrice),
              _rsPdf(b.advanceAmount),
              b.status.toUpperCase(),
            ],
          [
            'Total',
            '-',
            '-',
            '-',
            '-',
            _rsPdf(report.summary.totalRevenue),
            _rsPdf(report.summary.totalAdvance),
            '',
          ],
        ],
      ),
    );
  }

  return buildBrandedReportBytes(
    title: title,
    subtitle: subtitle,
    sections: sections,
  );
}

/// Computes the standard file name for the EOD report.
String getSalesEodFileName(SalesEodReport report) {
  final cleanDate = report.date.replaceAll('-', '');
  final cleanName = report.isTeam || report.salesPerson == null
      ? 'team'
      : report.salesPerson!.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  return 'sales_eod_${cleanDate}_$cleanName.pdf';
}

/// Generates and triggers downloading the EOD report as a branded PDF file.
Future<void> downloadSalesEodPdf(SalesEodReport report) async {
  final bytes = await buildSalesEodPdfBytes(report);
  final fileName = getSalesEodFileName(report);
  await saveFileBytes(fileName, bytes, mime: 'application/pdf');
}

/// Opens the system print dialog or print preview for the EOD report.
Future<void> printSalesEodPdf(SalesEodReport report) async {
  final bytes = await buildSalesEodPdfBytes(report);
  final fileName = getSalesEodFileName(report);
  await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
}

/// Formats a clean WhatsApp summary text for quick reporting to managers or team chat.
String formatSalesEodWhatsAppText(SalesEodReport report) {
  final dateLabel = report.reportDateFormatted.isNotEmpty ? report.reportDateFormatted : report.date;
  final name = report.salesPerson?.name ?? (report.isTeam ? 'Sales Team' : 'Sales Executive');

  final isRange = dateLabel.contains(' to ');
  final targetHeader = isRange ? 'PERIOD TARGET vs ACHIEVED' : 'TODAY TARGET vs ACHIEVED';
  final leadsHeader = isRange ? 'LEADS BY SOURCE (PERIOD / MTD)' : 'LEADS BY SOURCE (TODAY / MTD)';
  final bookingsHeader = isRange ? 'Bookings Closed in Period (${report.bookings.length}):' : 'Bookings Closed Today (${report.bookings.length}):';

  final buffer = StringBuffer();
  buffer.writeln('📊 *TEAM N — END OF DAY SALES REPORT*');
  buffer.writeln('📅 *Date:* $dateLabel');
  buffer.writeln('👤 *Sales Person:* $name');
  buffer.writeln('📌 *Primary Task:* ${report.leadCountTask}');
  buffer.writeln('────────────────────────────');

  buffer.writeln('🎯 *$targetHeader*');
  buffer.writeln('• Bookings: ${report.bookingsTargetToday.achieved.toInt()} / ${report.bookingsTargetToday.achievableTarget.toStringAsFixed(1)} (${report.bookingsTargetToday.achievementPct.toStringAsFixed(1)}%)');
  buffer.writeln('• Value: ${_rsText(report.bookingValueTargetToday.achieved)} / ${_rsText(report.bookingValueTargetToday.achievableTarget)} (${report.bookingValueTargetToday.achievementPct.toStringAsFixed(1)}%)');

  buffer.writeln('\n📈 *MONTH-TO-DATE (MTD)*');
  buffer.writeln('• Bookings MTD: ${report.bookingsTargetMtd.mtdAchieved.toInt()} / ${report.bookingsTargetMtd.mtdTarget.toStringAsFixed(1)} (${report.bookingsTargetMtd.mtdAchievementPct.toStringAsFixed(1)}% of Target Till Date | Full Month: ${report.bookingsTargetMtd.monthlyTarget.toInt()})');
  buffer.writeln('• Value MTD: ${_rsText(report.bookingValueTargetMtd.mtdAchieved)} / ${_rsText(report.bookingValueTargetMtd.mtdTarget)} (${report.bookingValueTargetMtd.mtdAchievementPct.toStringAsFixed(1)}% of Target Till Date | Full Month: ${_rsText(report.bookingValueTargetMtd.monthlyTarget)})');

  buffer.writeln('\n📥 *$leadsHeader*');
  buffer.writeln('• WhatsApp (Organic): ${report.whatsappLeads.today.toInt()} / ${report.whatsappLeads.mtd.toInt()}');
  buffer.writeln('• IG Leads (Main): ${report.igMainLeads.today.toInt()} / ${report.igMainLeads.mtd.toInt()}');
  buffer.writeln('• IG Leads (Kerala): ${report.igKeralaLeads.today.toInt()} / ${report.igKeralaLeads.mtd.toInt()}');
  buffer.writeln('• Paid Ads: ${report.paidAdsLeads.today.toInt()} / ${report.paidAdsLeads.mtd.toInt()}');
  buffer.writeln('• Trial Campaign: ${report.trialCampaignLeads.today.toInt()} / ${report.trialCampaignLeads.mtd.toInt()}');
  buffer.writeln('• Contacted: ${report.leadsContacted.today.toInt()} | Follow-ups: ${report.followUpsDone.today.toInt()}');

  buffer.writeln('\n💳 *ORDER VALUE & PAYMENTS*');
  buffer.writeln('• Total Order Value: ${_rsText(report.totalOrderValueMetric.today)} (MTD: ${_rsText(report.totalOrderValueMetric.mtd)})');
  buffer.writeln('• Advance Paid: ${_rsText(report.advancePaidMetric.today)} (MTD: ${_rsText(report.advancePaidMetric.mtd)})');
  buffer.writeln('• Balance Due: ${_rsText(report.balanceDueMetric.today)} (MTD: ${_rsText(report.balanceDueMetric.mtd)})');

  if (report.bookings.isNotEmpty) {
    buffer.writeln('\n🎉 *$bookingsHeader*');
    for (int i = 0; i < report.bookings.length; i++) {
      final b = report.bookings[i];
      buffer.writeln('${i + 1}. *${b.customerName}* (${b.source}) — ${_rsText(b.totalPrice)} (Adv: ${_rsText(b.advanceAmount)})');
    }
  }

  buffer.writeln('\n_Generated via Team N CRM_');
  return buffer.toString();
}
