import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

// The full GST invoice as a real PDF file, laid out like the CRM's
// "Print Full GST Invoice" page (booking_print_service_web.dart →
// _buildClientConfirmationHtml, clientInvoice variant) so the customer gets
// the same invoice on WhatsApp that Accounts sees in the CRM. Same line /
// GST / total maths as that page. Pure Dart — works on web, Windows, mobile.

const _maroon = PdfColor.fromInt(0xFF601A29);
const _ink = PdfColor.fromInt(0xFF1A1A2E);
const _muted = PdfColor.fromInt(0xFF667085);
const _label = PdfColor.fromInt(0xFF44526D);
const _border = PdfColor.fromInt(0xFFD9DDE3);
const _rowLine = PdfColor.fromInt(0xFFE5E9EF);
const _cardBg = PdfColor.fromInt(0xFFFAFBFC);
const _zebra = PdfColor.fromInt(0xFFF8F9FB);
const _greenBg = PdfColor.fromInt(0xFFF0FDF4);
const _greenBorder = PdfColor.fromInt(0xFFBBF7D0);
const _green = PdfColor.fromInt(0xFF15803D);
const _amber = PdfColor.fromInt(0xFFB45309);
const _subText = PdfColor.fromInt(0xFF6B7280);

String gstInvoicePdfFileName(Booking booking) {
  final no = booking.hasInvoiceNumber
      ? booking.invoiceNumber.replaceAll('/', '-')
      : booking.displayBookingNumber;
  final name = booking.customerName
      .replaceAll(RegExp(r'[^\w\s\-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return 'GST_Invoice_$no${name.isEmpty ? '' : '_$name'}.pdf';
}

Future<Uint8List> buildGstInvoicePdfBytes(Booking booking) async {
  // ── Fonts: Noto Sans has the ₹ sign; fall back to Helvetica + "Rs." ──────
  pw.Font? regular;
  pw.Font? bold;
  try {
    regular = await PdfGoogleFonts.notoSansRegular();
    bold = await PdfGoogleFonts.notoSansBold();
  } catch (_) {
    regular = null;
    bold = null;
  }
  // PdfGoogleFonts doesn't throw when offline — it quietly hands back
  // Helvetica (no ₹). Only a downloaded TrueType font can draw the sign.
  if (regular is! pw.TtfFont || bold is! pw.TtfFont) {
    regular = null;
    bold = null;
  }
  final hasRupee = regular != null;
  String inr(double v) => '${hasRupee ? '₹' : 'Rs. '}${v.toStringAsFixed(2)}';

  pw.MemoryImage? logo;
  try {
    final data = await rootBundle.load('assets/images/teamn_logo.png');
    logo = pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {}

  // ── GST helpers (inclusive @ 5%) — identical to the CRM page ──────────────
  double gstCgst(double incl) => double.parse((incl * 2.5 / 105.0).toStringAsFixed(2));
  double gstSgst(double incl) => double.parse((incl * 2.5 / 105.0).toStringAsFixed(2));
  String dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String time(DateTime v) {
    final hour = v.hour % 12 == 0 ? 12 : v.hour % 12;
    return '$hour:${v.minute.toString().padLeft(2, '0')} ${v.hour < 12 ? 'AM' : 'PM'}';
  }

  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String datesLabel(List<DateTime> dates) {
    if (dates.isEmpty) return '';
    final sorted = [...dates]..sort((a, b) => a.compareTo(b));
    return sorted.map((d) => '${d.day} ${months[d.month - 1]} ${d.year}').join(', ');
  }

  // Add-ons: booking level (single) + per package (multi), no double count.
  final perItem = [for (final it in booking.bookingItems) ...it.addons];
  final allAddons = booking.bookingItems.length <= 1
      ? (booking.addons.isNotEmpty ? booking.addons : perItem)
      : [...booking.addons, ...perItem];
  final addonTotal = allAddons.fold<double>(0, (s, a) => s + a.amount * a.persons);
  final packageAmount = (booking.totalPrice - addonTotal) < 0 ? 0.0 : booking.totalPrice - addonTotal;

  final invoiceNo = booking.hasInvoiceNumber ? booking.invoiceNumber : booking.displayBookingNumber;
  final invoiceDate = booking.hasInvoiceNumber
      ? (booking.invoiceDate ?? booking.bookingDate)
      : booking.bookingDate;
  final hsn = booking.hsnCode.trim().isNotEmpty ? booking.hsnCode.trim() : '998361';
  final approved = ['confirmed', 'completed'].contains(booking.status.toLowerCase());

  // ── SERVICES lines (GST accumulated from the printed lines) ──────────────
  final lines = <({String name, String sub, double base, double cgst, double sgst, double incl})>[];
  void addLine(String name, String sub, double incl) {
    final c = gstCgst(incl), s = gstSgst(incl);
    lines.add((
      name: name,
      sub: sub,
      base: double.parse((incl - c - s).toStringAsFixed(2)),
      cgst: c,
      sgst: s,
      incl: incl,
    ));
  }

  final dash = hasRupee ? '–' : '-'; // Helvetica (offline) has no en dash
  final scheduleTime = '${time(booking.serviceStart)} $dash ${time(booking.serviceEnd)}';
  if (booking.bookingItems.isNotEmpty) {
    for (final item in booking.bookingItems) {
      final dates = datesLabel(item.selectedDates);
      final slot = item.eventSlot.trim();
      addLine(
        item.service.trim().isEmpty ? 'Package' : item.service.trim(),
        [if (dates.isNotEmpty) dates, scheduleTime, if (slot.isNotEmpty) slot].join('  ·  '),
        item.totalPrice,
      );
    }
  } else {
    addLine(
      booking.service,
      [
        datesLabel(booking.selectedDates.isNotEmpty ? booking.selectedDates : [booking.bookingDate]),
        scheduleTime,
        if (booking.eventSlot.trim().isNotEmpty) booking.eventSlot.trim(),
      ].join('  ·  '),
      packageAmount,
    );
  }
  for (final a in allAddons) {
    addLine('${a.service}${a.persons > 1 ? ' × ${a.persons}' : ''}', '', a.amount * a.persons);
  }

  final lineTotal = lines.fold<double>(0, (s, l) => s + l.incl);
  final invoiceTotal = lineTotal > 0 ? double.parse(lineTotal.toStringAsFixed(2)) : booking.totalPrice;
  final remainingBalance = (invoiceTotal - booking.discountAmount - booking.advanceAmount - booking.collectedAmount)
      .clamp(0, double.infinity)
      .toDouble();
  final cgstSum = lines.fold<double>(0, (s, l) => s + l.cgst);
  final sgstSum = lines.fold<double>(0, (s, l) => s + l.sgst);
  final totalCgst = cgstSum > 0 ? double.parse(cgstSum.toStringAsFixed(2)) : gstCgst(invoiceTotal);
  final totalSgst = sgstSum > 0 ? double.parse(sgstSum.toStringAsFixed(2)) : gstSgst(invoiceTotal);
  final totalGst = double.parse((totalCgst + totalSgst).toStringAsFixed(2));

  // ── Building blocks ────────────────────────────────────────────────────────
  pw.TextStyle st(double size, {PdfColor color = _ink, bool b = false, double spacing = 0}) =>
      pw.TextStyle(fontSize: size, color: color, fontWeight: b ? pw.FontWeight.bold : null, letterSpacing: spacing);

  pw.Widget meta(String label, pw.Widget value) => pw.Column(children: [
        pw.Text(label, style: st(7.5, color: _muted, spacing: 0.6)),
        pw.SizedBox(height: 2),
        value,
      ]);

  pw.Widget infoLine(String key, String val) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(text: '$key  ', style: st(9.5, color: _label, b: true)),
            pw.TextSpan(text: val, style: st(9.5)),
          ]),
        ),
      );

  pw.Widget card(String title, List<pw.Widget> children) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: _cardBg,
          border: pw.Border.all(color: _border),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: st(7.5, color: _muted, b: true, spacing: 0.6)),
          pw.SizedBox(height: 6),
          ...children,
        ]),
      );

  pw.Widget cell(String text, {bool right = false, bool center = false, bool b = false, String sub = ''}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        alignment: right ? pw.Alignment.centerRight : (center ? pw.Alignment.center : pw.Alignment.centerLeft),
        child: pw.Column(
          crossAxisAlignment: right ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
          children: [
            pw.Text(text, style: st(9.5, b: b), textAlign: right ? pw.TextAlign.right : (center ? pw.TextAlign.center : pw.TextAlign.left)),
            if (sub.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(sub, style: st(7.5, color: _subText)),
            ],
          ],
        ),
      );

  pw.Widget head(String text, {bool right = false, bool center = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        alignment: right ? pw.Alignment.centerRight : (center ? pw.Alignment.center : pw.Alignment.centerLeft),
        child: pw.Text(text, style: st(8, color: PdfColors.white, b: true, spacing: 0.3)),
      );

  pw.TableRow sumRow(String label, String value, {bool sub = false}) => pw.TableRow(
        decoration: pw.BoxDecoration(
          color: sub ? _greenBg : null,
          border: const pw.Border(bottom: pw.BorderSide(color: _rowLine)),
        ),
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.fromLTRB(sub ? 22 : 10, 5, 10, 5),
            child: pw.Text(label,
                textAlign: pw.TextAlign.right,
                style: sub ? st(9, color: _muted) : st(9.5, color: _label)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 5, 10, 5),
            child: pw.Text(value,
                textAlign: pw.TextAlign.right,
                style: sub ? st(9, color: _muted) : st(9.5, b: true)),
          ),
        ],
      );

  final doc = pw.Document(title: 'GST Invoice $invoiceNo');

  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      theme: regular == null
          ? pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold())
          : pw.ThemeData.withFont(base: regular, bold: bold),
    ),
    build: (context) => [
      // ═══ HEADER ═══
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _maroon, width: 1.5))),
        child: pw.Column(children: [
          if (logo != null)
            pw.Container(
              width: 48,
              height: 48,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          pw.SizedBox(height: 6),
          pw.Text('TEAM N ERP', style: st(17, color: _maroon, b: true, spacing: 0.5)),
          pw.SizedBox(height: 2),
          pw.Text('GST INVOICE', style: st(8, color: _muted, spacing: 0.5)),
          pw.SizedBox(height: 12),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            meta('INVOICE NO.', pw.Text(invoiceNo, style: st(10.5, b: true))),
            pw.SizedBox(width: 24),
            meta('DATE', pw.Text(dmy(invoiceDate), style: st(10.5, b: true))),
            if (booking.createdAt != null) ...[
              pw.SizedBox(width: 24),
              meta('BOOKED ON', pw.Text(dmy(booking.createdAt!), style: st(10.5, b: true))),
            ],
            pw.SizedBox(width: 24),
            meta(
              'STATUS',
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: approved ? _green : _amber,
                  borderRadius: pw.BorderRadius.circular(9),
                ),
                child: pw.Text(approved ? 'APPROVED' : 'PENDING', style: st(8, color: PdfColors.white, b: true, spacing: 0.4)),
              ),
            ),
          ]),
        ]),
      ),
      pw.SizedBox(height: 14),

      // ═══ BILLED TO + COMPANY DETAILS ═══
      // A table row (not a Row) so both cards stretch to the taller one's height.
      pw.Table(
        columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FixedColumnWidth(12), 2: pw.FlexColumnWidth()},
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
        children: [pw.TableRow(children: [
          card('BILLED TO', [
            pw.Text(booking.customerName, style: st(12, color: _maroon, b: true)),
            pw.SizedBox(height: 4),
            if (booking.phone.isNotEmpty) infoLine('Phone', booking.phone),
            if (booking.secondaryContact.isNotEmpty) infoLine('Alt. Phone', booking.secondaryContact),
            if (booking.email.isNotEmpty) infoLine('Email', booking.email),
            if (booking.address.isNotEmpty)
              infoLine('Address', '${booking.address}${booking.pincode.isNotEmpty ? ', ${booking.pincode}' : ''}'),
            if (booking.district.isNotEmpty) infoLine('District', booking.district),
          ]),
          pw.SizedBox(),
          card('COMPANY DETAILS', [
            pw.Text('TEAM N ERP', style: st(12, color: _maroon, b: true)),
            pw.SizedBox(height: 4),
            pw.Text('Kozhikode Kerala 673014\nIndia', style: st(9.5, color: PdfColor.fromInt(0xFF1F2937), spacing: 0)),
            pw.SizedBox(height: 6),
            infoLine('GSTIN', '32AAJCN6432D1ZR'),
            infoLine('Phone', '9645424283'),
            infoLine('Email', 'teamnfinance@gmail.com'),
          ]),
        ])],
      ),
      pw.SizedBox(height: 14),

      // ═══ SERVICES ═══
      pw.Container(
        padding: const pw.EdgeInsets.only(left: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: _maroon, width: 2.5))),
        child: pw.Text('SERVICES', style: st(8.5, color: _maroon, b: true, spacing: 0.6)),
      ),
      pw.SizedBox(height: 6),
      pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(3.4),
          1: pw.FlexColumnWidth(1.1),
          2: pw.FlexColumnWidth(1.4),
          3: pw.FlexColumnWidth(1.2),
          4: pw.FlexColumnWidth(1.2),
          5: pw.FlexColumnWidth(1.6),
        },
        // Every cell centred in its row, like the CRM table — a wrapped header
        // or a two-line service name no longer pushes its neighbours out of line.
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _maroon), children: [
            head('SERVICE'),
            head('HSN / SAC', center: true),
            head('BASE AMT', right: true),
            head('CGST 2.5%', right: true),
            head('SGST 2.5%', right: true),
            head('TOTAL (INCL. GST)', right: true),
          ]),
          for (var i = 0; i < lines.length; i++)
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: i.isOdd ? _zebra : null,
                border: const pw.Border(bottom: pw.BorderSide(color: _rowLine)),
              ),
              children: [
                cell(lines[i].name, sub: lines[i].sub),
                cell(hsn, center: true),
                cell(inr(lines[i].base), right: true),
                cell(inr(lines[i].cgst), right: true),
                cell(inr(lines[i].sgst), right: true),
                cell(inr(lines[i].incl), right: true, b: true),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 14),

      // ═══ PAYMENT SUMMARY ═══
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 250,
          child: pw.Table(
            columnWidths: const {0: pw.FlexColumnWidth(1.4), 1: pw.FlexColumnWidth(1)},
            children: [
              sumRow('Subtotal (Incl. GST)', inr(invoiceTotal)),
              sumRow('CGST @ 2.5%', inr(totalCgst), sub: true),
              sumRow('SGST @ 2.5%', inr(totalSgst), sub: true),
              sumRow('Total GST', inr(totalGst)),
              if (booking.discountAmount > 0) sumRow('Discount', '$dash ${inr(booking.discountAmount)}'),
              sumRow('Advance Paid', inr(booking.advanceAmount)),
              if (remainingBalance > 0)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _maroon),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 7),
                      child: pw.Text('BALANCE DUE', textAlign: pw.TextAlign.right, style: st(10.5, color: PdfColors.white, b: true)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 7),
                      child: pw.Text(inr(remainingBalance), textAlign: pw.TextAlign.right, style: st(12, color: PdfColors.white, b: true)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      pw.SizedBox(height: 16),

      // ═══ FOOTER ═══
      pw.Container(
        width: double.infinity, // divider spans the page, like the CRM
        padding: const pw.EdgeInsets.only(top: 10),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _border))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: pw.BoxDecoration(
              color: _greenBg,
              border: pw.Border.all(color: _greenBorder),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text('Price inclusive of GST @ 5%   |   SAC: $hsn', style: st(9, color: _green, b: true)),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Terms & Conditions', style: st(10, color: _maroon, b: true)),
          pw.SizedBox(height: 5),
          for (final (i, t) in const [
            'The booking advance payment is non-refundable and non-transferable under any circumstances.',
            'Any additional services requested on the event day will be charged extra as per actual costs.',
            'The remaining balance must be fully paid on or before the event date prior to service completion.',
            'Please ensure power supply and standard mirror / lighting setups are available at the service location.',
          ].indexed)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3, left: 4),
              child: pw.Text('${i + 1}. $t', style: st(9, color: _label)),
            ),
        ]),
      ),
    ],
  ));

  return doc.save();
}
