import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/booking.dart';
import 'booking_print_service.dart';

Future<void> printBookingDetails(
  Booking booking, {
  required BookingPrintVariant variant,
  List<Booking> relatedArtistBookings = const [],
  List<BookingDisplayEntry> relatedArtistEntries = const [],
  BookingDisplayEntry? selectedArtistEntry,
  String artistName = '',
}) async {
  // Generate the PDF
  final pdf = pw.Document();
  
  // Load Logo (if present, try to load it from assets, or fallback if it fails)
  pw.MemoryImage? logoImage;
  try {
    final logoData = await rootBundle.load('assets/images/teamn_logo.png');
    logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
  } catch (_) {
    // Fallback if logo cannot be loaded
  }

  // Setup styles
  final primaryColor = PdfColor.fromHex('#601A29');
  final secondaryColor = PdfColor.fromHex('#7B8694');
  final borderColor = PdfColor.fromHex('#D9DDE3');
  final lightBg = PdfColor.fromHex('#F5F7FA');

  // Let's build the pages
  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      build: (context) {
        final addonsTotal = booking.addons.fold(0.0, (sum, item) => sum + (item.amount * item.persons));
        final basePrice = booking.totalPrice - addonsTotal;

        // ── GST helpers (inclusive @ 5%) ──────────────────────────────────
        double gstBase(double incl) =>
            double.parse((incl * 100.0 / 105.0).toStringAsFixed(2));
        double gstCgst(double incl) =>
            double.parse((incl * 2.5 / 105.0).toStringAsFixed(2));
        double gstSgst(double incl) =>
            double.parse((incl * 2.5 / 105.0).toStringAsFixed(2));
        String inr(double v) => 'INR ${v.toStringAsFixed(2)}';

        final paymentMode = booking.paymentMode.trim().isNotEmpty
            ? booking.paymentMode.trim()
            : 'N/A';
        final hsnCode = booking.hsnCode.trim().isNotEmpty
            ? booking.hsnCode.trim()
            : '998361';
        final invoiceStatus =
            (booking.status.toLowerCase() == 'confirmed' ||
                    booking.status.toLowerCase() == 'completed')
                ? 'APPROVED'
                : 'PENDING';
        final statusBgColor = invoiceStatus == 'APPROVED'
            ? PdfColors.green700
            : PdfColors.orange700;

        final invDate = booking.bookingDate;
        final invDateStr =
            '${invDate.day.toString().padLeft(2, '0')}/'
            '${invDate.month.toString().padLeft(2, '0')}/'
            '${invDate.year}';

        final pkgBase = gstBase(basePrice);
        final pkgCgst = gstCgst(basePrice);
        final pkgSgst = gstSgst(basePrice);

        final totalCgst = gstCgst(booking.totalPrice);
        final totalSgst = gstSgst(booking.totalPrice);
        final totalGst =
            double.parse((totalCgst + totalSgst).toStringAsFixed(2));
        final balanceDue = (booking.totalPrice -
                booking.advanceAmount -
                booking.discountAmount)
            .clamp(0.0, double.infinity);

        return [
          // Header / Logo
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Image(logoImage, width: 64, height: 64)
              else
                pw.Container(
                  width: 64,
                  height: 64,
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    shape: pw.BoxShape.circle,
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'N',
                    style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 32),
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.Text(
                'TEAM N MAKEOVERS',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                variant == BookingPrintVariant.clientConfirmation ? 'BOOKING CONFIRMATION' : variant == BookingPrintVariant.clientInvoice ? 'TAX INVOICE & CONFIRMATION' : 'Artist Copy - Assignment Sheet',
                style: pw.TextStyle(fontSize: 10, color: secondaryColor),
              ),
            ],
          ),
          pw.Divider(color: primaryColor, thickness: 1.5, height: 20),

          // Core Booking Details
          pw.Text('Booking Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 8),

          pw.Table(
            border: pw.TableBorder.all(color: borderColor),
            children: [
              _buildTableRow('Booking ID / Number', booking.displayBookingNumber, lightBg),
              _buildTableRow('Customer Name', booking.customerName, PdfColors.white),
              _buildTableRow('Phone Number', booking.phone, lightBg),
              _buildTableRow('Service / Package', booking.service, PdfColors.white),
              _buildTableRow('Event Slot', booking.eventSlot.isNotEmpty ? booking.eventSlot : 'General', lightBg),
              _buildTableRow('Date of Event', [
                if (booking.selectedDates.isNotEmpty)
                  booking.selectedDates.map((d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}').join(', ')
                else
                  '${booking.bookingDate.day.toString().padLeft(2, '0')}/${booking.bookingDate.month.toString().padLeft(2, '0')}/${booking.bookingDate.year}'
              ].join(), PdfColors.white),
              _buildTableRow('Location', booking.district.isNotEmpty ? booking.district : 'N/A', lightBg),
              if (booking.address.trim().isNotEmpty)
                _buildTableRow('Address', booking.address, PdfColors.white),
              if (booking.pincode.trim().isNotEmpty)
                _buildTableRow('Pincode', booking.pincode, lightBg),
              if (booking.outfitDetails.isNotEmpty)
                _buildTableRow('Outfit Details', booking.outfitDetails, PdfColors.white),
            ],
          ),
          pw.SizedBox(height: 20),

          // Variant-specific Details
          if (variant == BookingPrintVariant.clientInvoice || variant == BookingPrintVariant.clientConfirmation) ...[
            // Invoice subtitle
            pw.Text(
              variant == BookingPrintVariant.clientConfirmation ? 'BOOKING CONFIRMATION' : 'GST INVOICE — ORIGINAL COPY',
              style: pw.TextStyle(
                fontSize: 10,
                color: secondaryColor,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 8),
            // Invoice meta row
            pw.Table(
              border: pw.TableBorder.all(color: borderColor),
              columnWidths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('INVOICE NO.',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: secondaryColor,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text(booking.displayBookingNumber,
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('DATE',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: secondaryColor,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text(invDateStr,
                              style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),

                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('STATUS',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: secondaryColor,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: statusBgColor,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              invoiceStatus,
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Billed To
            pw.Text('BILLED TO',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1.1)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor),
              children: [
                _buildTableRow('Customer', booking.customerName, lightBg),
                if (booking.phone.isNotEmpty)
                  _buildTableRow('Phone', booking.phone, PdfColors.white),
                if (booking.address.trim().isNotEmpty)
                  _buildTableRow('Address', booking.address, lightBg),
                if (booking.district.trim().isNotEmpty)
                  _buildTableRow('District', booking.district, PdfColors.white),
              ],
            ),
            pw.SizedBox(height: 20),

            // Services Table
            pw.Text('SERVICES',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1.1)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor),
              columnWidths: const {
                0: pw.FlexColumnWidth(3.0),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1.2),
                4: pw.FlexColumnWidth(1.2),
                5: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('SERVICE',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('HSN/SAC',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8),
                            textAlign: pw.TextAlign.center)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('BASE AMT',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8),
                            textAlign: pw.TextAlign.right)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('CGST 2.5%',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8),
                            textAlign: pw.TextAlign.right)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('SGST 2.5%',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8),
                            textAlign: pw.TextAlign.right)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('TOTAL',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8),
                            textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(booking.service,
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(hsnCode,
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(inr(pkgBase),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(inr(pkgCgst),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(inr(pkgSgst),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(inr(basePrice),
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right)),
                  ],
                ),
                ...booking.addons.map((addon) {
                  final addonIncl = addon.amount * addon.persons;
                  final addonBase = gstBase(addonIncl);
                  final addonCgst = gstCgst(addonIncl);
                  final addonSgst = gstSgst(addonIncl);
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              addon.persons > 1
                                  ? '${addon.service} x${addon.persons}'
                                  : addon.service,
                              style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(hsnCode,
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(inr(addonBase),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(inr(addonCgst),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(inr(addonSgst),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(inr(addonIncl),
                              style: pw.TextStyle(
                                  fontSize: 8, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right)),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),

            // Payment Summary
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 280,
                  child: pw.Table(
                    border: pw.TableBorder.all(color: borderColor),
                    children: [
                      _buildTableRow('Subtotal (Incl. GST)',
                          inr(booking.totalPrice), lightBg),
                      _buildTableRow(
                          '  CGST @ 2.5%', inr(totalCgst), PdfColors.white),
                      _buildTableRow('  SGST @ 2.5%', inr(totalSgst), lightBg),
                      _buildTableRow(
                          'Total GST', inr(totalGst), PdfColors.white),
                      if (booking.discountAmount > 0)
                        _buildTableRow('Discount',
                            'Discount Applied', lightBg),
                      _buildTableRow('Advance Paid',
                          inr(booking.advanceAmount), PdfColors.white),
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: primaryColor),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            child: pw.Text('BALANCE DUE',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10,
                                    color: PdfColors.white)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            child: pw.Text(inr(balanceDue),
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10,
                                    color: PdfColors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // GST Note
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#f0fdf4'),
                border: pw.Border.all(color: PdfColor.fromHex('#bbf7d0')),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'Price inclusive of GST @ 5%  |  SAC: $hsnCode',
                style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromHex('#15803d'),
                    fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 16),

            // Terms & Conditions
            pw.Text('Terms & Conditions',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor)),
            pw.SizedBox(height: 6),
            pw.Bullet(text: 'The booking advance payment is non-refundable and non-transferable under any circumstances.'),
            pw.Bullet(text: 'Any additional services requested on the event day will be charged extra as per actual costs.'),
            pw.Bullet(text: 'The remaining balance must be fully paid on or before the event date prior to service completion.'),
            pw.Bullet(text: 'Please ensure power supply and standard mirror/lighting setups are available at the service location.'),
          ] else ...[
            // Artist assignment details
            pw.Text('Artist Assignment Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor),
              children: [
                _buildTableRow('Travel Mode', booking.travelMode.isNotEmpty ? booking.travelMode : 'Not specified', lightBg),
                _buildTableRow('Travel Distance', '${booking.travelDistanceKm.toStringAsFixed(1)} KM', PdfColors.white),
                _buildTableRow('Travel Time', booking.travelTime.isNotEmpty ? booking.travelTime : 'Not specified', lightBg),
                _buildTableRow('Driver Name', booking.driverName.isNotEmpty ? booking.driverName : 'Not assigned', PdfColors.white),
              ],
            ),
            pw.SizedBox(height: 16),
            if (booking.staffInstructions.isNotEmpty) ...[
              pw.Text('Staff Instructions', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  color: lightBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(booking.staffInstructions, style: const pw.TextStyle(fontSize: 11)),
              ),
              pw.SizedBox(height: 16),
            ],

            // Assigned Staff list
            if (booking.assignedStaff.isNotEmpty) ...[
              pw.Text('Assigned Team Members', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Role/Specialization', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Phone', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ...booking.assignedStaff.map(
                    (staff) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(staff.artistName)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(staff.specialization.isNotEmpty ? staff.specialization : staff.role)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(staff.phone.isNotEmpty ? staff.phone : 'N/A')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ];
      },
    ),
  );

  // Save PDF locally and trigger native share
  final bytes = await pdf.save();
  final tempDir = await getTemporaryDirectory();
  final cleanName = booking.customerName.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
  final fileName = '${(variant == BookingPrintVariant.clientInvoice || variant == BookingPrintVariant.clientConfirmation) ? "Client" : "Artist"}_Booking_${booking.displayBookingNumber}_$cleanName.pdf';
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Booking Report - ${booking.customerName}',
    text: 'Please find attached the Booking PDF for ${booking.customerName}.',
    sharePositionOrigin: const Rect.fromLTWH(0, 0, 300, 300),
  );
}

pw.TableRow _buildTableRow(String label, String value, PdfColor bgColor, {bool isBold = false}) {
  return pw.TableRow(
    decoration: pw.BoxDecoration(color: bgColor),
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: pw.Text(value, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10)),
      ),
    ],
  );
}
