import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/features/hr/letters/data/letter_models.dart';
import 'package:nizan_crm/features/hr/recruitment/data/recruitment_models.dart';

/// Official Nizan Brand Palette for PDF Documents
const PdfColor kPdfNavy = PdfColor.fromInt(0xFF0D1333); // Nizan deep navy
const PdfColor kPdfMaroon = PdfColor.fromInt(0xFF601A29); // Team N maroon
const PdfColor kPdfGold = PdfColor.fromInt(0xFFC9A66B); // Nizan luxury gold
const PdfColor kPdfGoldDark = PdfColor.fromInt(0xFFB0873F);
const PdfColor kPdfSand = PdfColor.fromInt(0xFFEFE8E1); // Warm sand background
const PdfColor kPdfInk = PdfColor.fromInt(0xFF1C1A19); // Crisp body ink
const PdfColor kPdfMuted = PdfColor.fromInt(0xFF5A5550);
const PdfColor kPdfBorder = PdfColor.fromInt(0xFFD6CEC5);

// Cache loaded letterhead images in memory for instant reuse
pw.MemoryImage? _headerBannerCache;
pw.MemoryImage? _footerBannerCache;
pw.MemoryImage? _nizanLogoCache;
pw.MemoryImage? _nizanMonogramCache;
bool _assetsLoaded = false;

Future<void> _ensureAssetsLoaded() async {
  if (_assetsLoaded) return;
  _assetsLoaded = true;

  try {
    final headerData = await rootBundle.load('assets/images/nizan_letterhead_header.png');
    _headerBannerCache = pw.MemoryImage(headerData.buffer.asUint8List());
  } catch (_) {
    _headerBannerCache = null;
  }

  try {
    final footerData = await rootBundle.load('assets/images/nizan_letterhead_footer.jpeg');
    _footerBannerCache = pw.MemoryImage(footerData.buffer.asUint8List());
  } catch (_) {
    _footerBannerCache = null;
  }

  try {
    final logoData = await rootBundle.load('assets/images/nizan_logo.png');
    _nizanLogoCache = pw.MemoryImage(logoData.buffer.asUint8List());
  } catch (_) {
    _nizanLogoCache = null;
  }

  try {
    final monoData = await rootBundle.load('assets/images/nizan_monogram.png');
    _nizanMonogramCache = pw.MemoryImage(monoData.buffer.asUint8List());
  } catch (_) {
    _nizanMonogramCache = null;
  }
}


/// Normalise Unicode characters to ASCII equivalents supported by standard PDF fonts
String _pdfSafe(String? text) {
  if (text == null) return '';
  return text
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('•', '*')
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('…', '...')
      .replaceAll('₹', 'INR ')
      .replaceAll(' ', ' ')
      .replaceAll(' ', ' ')
      .replaceAll(' ', ' ');
}

/// Structure for compensation table items in offer / salary letters
class SalaryComponentItem {
  final String label;
  final double monthly;
  final double annual;
  final bool isDeduction;
  final bool isHeaderOrTotal;

  const SalaryComponentItem({
    required this.label,
    required this.monthly,
    double? annual,
    this.isDeduction = false,
    this.isHeaderOrTotal = false,
  }) : annual = annual ?? (monthly * 12);
}

/// Core Document Builder implementing the exact Nizan Letterhead Template
class NizanHrDocumentBuilder {
  /// Generates raw PDF bytes for ANY HR document or letter
  static Future<Uint8List> build({
    required String title,
    String? refNumber,
    DateTime? date,
    required String recipientName,
    String? recipientDesignation,
    String? recipientDepartment,
    String? recipientAddress,
    String? recipientEmail,
    String? recipientPhone,
    String? subject,
    required String body,
    List<SalaryComponentItem>? salaryComponents,
    DateTime? joiningDate,
    String? signatoryName,
    String? signatoryTitle,
    bool includeCandidateAcceptance = false,
  }) async {
    await _ensureAssetsLoaded();

    final doc = pw.Document();
    final issueDate = date ?? DateTime.now();
    final formattedDate = DateFormat('d MMMM yyyy').format(issueDate);
    final ref = refNumber ??
        'NZ/HR/${title.replaceAll(RegExp(r'[^A-Z]'), '')}/${issueDate.year}/${issueDate.millisecondsSinceEpoch.toString().substring(8)}';

    // A4 dimensions in PDF points
    const a4Width = 595.28;

    // Header & Footer Banner Dimensions with printable white space
    const headerHeight = 99.0;
    const headerTop = 54.0;
    const footerHeight = 57.0;
    const footerBottom = 35.0;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(44, 178, 44, 115),
          buildBackground: (pw.Context ctx) {
            final isFirst = ctx.pageNumber == 1;
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Stack(
                children: [
                  // Top Header Banner with white space only on page 1
                  if (isFirst) ...[
                    if (_headerBannerCache != null)
                      pw.Positioned(
                        top: headerTop,
                        left: 0,
                        right: 0,
                        child: pw.Image(
                          _headerBannerCache!,
                          width: a4Width,
                          height: headerHeight,
                          fit: pw.BoxFit.fill,
                        ),
                      )
                    else
                      pw.Positioned(
                        top: headerTop,
                        left: 0,
                        right: 0,
                        child: pw.Container(
                          height: headerHeight,
                          color: kPdfNavy,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              if (_nizanLogoCache != null)
                                pw.Image(_nizanLogoCache!, height: 46)
                              else
                                pw.Text('NIZAN BEAUTY VENTURES',
                                    style: pw.TextStyle(color: PdfColors.white, fontSize: 15, fontWeight: pw.FontWeight.bold)),
                              pw.Text('+91 9645424283  |  www.nizanmakeovers.com',
                                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 9.5)),
                            ],
                          ),
                        ),
                      ),
                  ],

                  // Bottom Footer Banner with white space on all pages
                  if (_footerBannerCache != null)
                    pw.Positioned(
                      bottom: footerBottom,
                      left: 0,
                      right: 0,
                      child: pw.Image(
                        _footerBannerCache!,
                        width: a4Width,
                        height: footerHeight,
                        fit: pw.BoxFit.fill,
                      ),
                    )
                  else
                    pw.Positioned(
                      bottom: footerBottom,
                      left: 0,
                      right: 0,
                      child: pw.Container(
                        height: footerHeight,
                        color: kPdfNavy,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        child: pw.Text(
                          'Nizan Beauty Ventures Private Limited | Hilite Business Park, Kozhikode, Kerala',
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 8.5),
                        ),
                      ),
                    ),

                  // Elegant Subtle Center Monogram Watermark
                  if (_nizanMonogramCache != null)
                    pw.Positioned.fill(
                      child: pw.Center(
                        child: pw.Opacity(
                          opacity: 0.045,
                          child: pw.Image(
                            _nizanMonogramCache!,
                            width: 320,
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),
                    )
                  else if (_nizanLogoCache != null)
                    pw.Positioned.fill(
                      child: pw.Center(
                        child: pw.Opacity(
                          opacity: 0.045,
                          child: pw.Image(
                            _nizanLogoCache!,
                            width: 280,
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        build: (pw.Context ctx) {
          final contentParagraphs = body.split('\n');

          return [
            // Top Date and Ref Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('REF: ${_pdfSafe(ref)}',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: kPdfMuted,
                        )),
                    pw.Text('CONFIDENTIAL & PRIVILEGED',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: kPdfGoldDark,
                          letterSpacing: 0.8,
                        )),
                  ],
                ),
                pw.Text('Date: $formattedDate',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: kPdfInk,
                    )),
              ],
            ),
            pw.SizedBox(height: 16),

            // Recipient Block
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: kPdfSand,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: kPdfBorder, width: 0.6),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TO:',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: kPdfMaroon,
                              letterSpacing: 0.8,
                            )),
                        pw.SizedBox(height: 2),
                        pw.Text(_pdfSafe(recipientName),
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: kPdfNavy,
                            )),
                        if (recipientDesignation != null && recipientDesignation.trim().isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(_pdfSafe(recipientDesignation),
                              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: kPdfInk)),
                        ],
                        if (recipientDepartment != null && recipientDepartment.trim().isNotEmpty)
                          pw.Text('Department: ${_pdfSafe(recipientDepartment)}',
                              style: pw.TextStyle(fontSize: 9.5, color: kPdfMuted)),
                        if (recipientAddress != null && recipientAddress.trim().isNotEmpty)
                          pw.Text(_pdfSafe(recipientAddress), style: pw.TextStyle(fontSize: 9.5, color: kPdfMuted)),
                        if (recipientPhone != null && recipientPhone.trim().isNotEmpty)
                          pw.Text('Contact: ${_pdfSafe(recipientPhone)}',
                              style: pw.TextStyle(fontSize: 9.5, color: kPdfMuted)),
                        if (recipientEmail != null && recipientEmail.trim().isNotEmpty)
                          pw.Text('Email: ${_pdfSafe(recipientEmail)}',
                              style: pw.TextStyle(fontSize: 9.5, color: kPdfMuted)),
                      ],
                    ),
                  ),
                  if (_nizanLogoCache != null)
                    pw.SizedBox(
                      height: 48,
                      width: 48,
                      child: pw.Image(_nizanLogoCache!, fit: pw.BoxFit.contain),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Subject Header
            if (subject != null && subject.trim().isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: kPdfMaroon, width: 3.5),
                  ),
                ),
                child: pw.Text(
                  'SUBJECT: ${_pdfSafe(subject).toUpperCase()}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: kPdfNavy,
                  ),
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // Formal Salutation
            pw.Text('Dear ${_pdfSafe(recipientName)},',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: kPdfInk,
                )),
            pw.SizedBox(height: 10),

            // Body Paragraphs
            ...contentParagraphs.map((para) {
              final trimmed = para.trim();
              if (trimmed.isEmpty) return pw.SizedBox(height: 8);

              // Bullet points
              if (trimmed.startsWith('* ') || trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
                final bulletText = trimmed.substring(2);
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 5,
                        height: 5,
                        margin: const pw.EdgeInsets.only(top: 4, right: 8),
                        decoration: const pw.BoxDecoration(color: kPdfGoldDark, shape: pw.BoxShape.circle),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          _pdfSafe(bulletText),
                          style: const pw.TextStyle(fontSize: 10, color: kPdfInk, lineSpacing: 1.6),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Bold Headings inside body (e.g. "Terms & Conditions:", "Annexure:")
              if (trimmed.endsWith(':') && trimmed.length < 50) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
                  child: pw.Text(
                    _pdfSafe(trimmed),
                    style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: kPdfNavy),
                  ),
                );
              }

              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  _pdfSafe(trimmed),
                  textAlign: pw.TextAlign.justify,
                  style: const pw.TextStyle(fontSize: 10, color: kPdfInk, lineSpacing: 1.8),
                ),
              );
            }),

            // Compensation / CTC Table Annexure if applicable
            if (salaryComponents != null && salaryComponents.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      color: kPdfNavy,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('ANNEXURE A: COMPENSATION BREAKDOWN',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('CURRENCY: INR',
                            style: pw.TextStyle(color: kPdfGold, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.Table(
                    border: pw.TableBorder.all(color: kPdfBorder, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: kPdfSand),
                        children: [
                          _th('Salary Component'),
                          _th('Monthly (INR)', alignRight: true),
                          _th('Annualized (INR)', alignRight: true),
                        ],
                      ),
                      ...salaryComponents.map((item) {
                        final isTotal = item.isHeaderOrTotal;
                        final bg = isTotal ? kPdfSand : PdfColors.white;
                        final weight = isTotal ? pw.FontWeight.bold : pw.FontWeight.normal;
                        final color = item.isDeduction ? PdfColors.red800 : kPdfInk;

                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: bg),
                          children: [
                            _td(_pdfSafe(item.label), weight: weight, color: color),
                            _td(NumberFormat('#,##,###').format(item.monthly),
                                alignRight: true, weight: weight, color: color),
                            _td(NumberFormat('#,##,###').format(item.annual),
                                alignRight: true, weight: weight, color: color),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
            ],

            // Proposed Joining Date Callout
            if (joiningDate != null) ...[
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: kPdfGoldDark, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('PROPOSED JOINING DATE: ',
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: kPdfNavy)),
                    pw.Text(DateFormat('EEEE, d MMMM yyyy').format(joiningDate),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfMaroon)),
                  ],
                ),
              ),
            ],

            pw.SizedBox(height: 20),

            // Dual Signature Blocks
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // Left: Candidate Acceptance (if offer)
                if (includeCandidateAcceptance)
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: kPdfBorder, width: 0.6),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CANDIDATE ACCEPTANCE',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: kPdfNavy)),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'I accept the offer and confirm joining on the stated date.',
                          style: const pw.TextStyle(fontSize: 7.5, color: kPdfMuted),
                        ),
                        pw.SizedBox(height: 28),
                        pw.Container(height: 0.8, color: kPdfBorder),
                        pw.SizedBox(height: 4),
                        pw.Text('Signature: ${_pdfSafe(recipientName)}',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: kPdfInk)),
                        pw.Text('Date: _________________________',
                            style: const pw.TextStyle(fontSize: 8, color: kPdfMuted)),
                      ],
                    ),
                  )
                else
                  pw.SizedBox(width: 1),

                // Right: Authorized Signatory with Nizan stamp placeholder
                pw.Container(
                  width: 220,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('For Nizan Beauty Ventures Pvt. Ltd.',
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: kPdfNavy)),
                      pw.SizedBox(height: 36), // Seal / Signature Space
                      pw.Container(height: 0.8, color: kPdfInk),
                      pw.SizedBox(height: 4),
                      pw.Text(_pdfSafe(signatoryName ?? 'Authorized Signatory'),
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: kPdfInk)),
                      pw.Text(_pdfSafe(signatoryTitle ?? 'Human Resources Department'),
                          style: const pw.TextStyle(fontSize: 8.5, color: kPdfMuted)),
                      pw.Text('Kozhikode, Kerala', style: const pw.TextStyle(fontSize: 8, color: kPdfMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _th(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kPdfNavy),
      ),
    );
  }

  static pw.Widget _td(String text,
      {bool alignRight = false, pw.FontWeight weight = pw.FontWeight.normal, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: weight, color: color ?? kPdfInk),
      ),
    );
  }
}

/// The official 15 operational responsibilities for Marketing Manager roles
const List<String> kDefaultMarketingResponsibilities = [
  'Marketing Strategy - Develop and execute monthly and quarterly marketing strategies aligned with company sales and revenue targets.',
  'Digital Marketing Management - Manage and optimize Meta Ads, Google Ads, SEO, SEM, social media, and other digital marketing channels.',
  'Lead Generation - Generate high-quality leads and continuously improve lead volume, quality, and cost per lead.',
  'Campaign Planning - Plan, execute, and monitor promotional campaigns, offers, seasonal campaigns, and brand campaigns.',
  'Social Media Management - Oversee content calendars, social media activities, creatives, reels, campaigns, and audience engagement.',
  'Performance Analysis - Track marketing KPIs such as leads, CPL, conversions, bookings, ROAS, revenue generated, and campaign performance.',
  'Sales & CRM Coordination - Work closely with Sales and CRM teams to improve lead follow-up, conversion rates, and booking performance.',
  'Budget Management - Prepare and manage marketing budgets and ensure efficient utilization of advertising and promotional expenses.',
  'Team Management - Lead, monitor, and evaluate the marketing team, assign tasks, set targets, and ensure timely completion.',
  'Content & Branding - Maintain consistent brand identity across social media, advertisements, websites, promotional materials, and campaigns.',
  'Market Research - Analyze competitors, customer behavior, market trends, and new opportunities to improve marketing strategies.',
  'Reporting to Management - Submit weekly and monthly marketing reports covering performance, spending, leads, conversions, ROI, and future action plans.',
  'Website & SEO Coordination - Coordinate website updates, landing pages, SEO improvements, Google Business activities, and conversion optimization.',
  'Creative Coordination - Work with designers, video editors, photographers, and content teams to ensure timely delivery of marketing creatives.',
  'Revenue Contribution - Take responsibility for converting marketing efforts into measurable business growth, bookings, and revenue.',
];

/// Helper to render bullet point with bold prefix before colon
pw.Widget _buildOfferBulletPoint(String bulletText) {
  final clean = _pdfSafe(bulletText).trim();
  final colonIdx = clean.indexOf(':');
  if (colonIdx != -1) {
    final title = clean.substring(0, colonIdx + 1);
    final rest = clean.substring(colonIdx + 1);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 3.5,
          height: 3.5,
          margin: const pw.EdgeInsets.only(top: 4, right: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.black, shape: pw.BoxShape.circle),
        ),
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 9.2, color: PdfColors.black, lineSpacing: 1.35),
              children: [
                pw.TextSpan(text: title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.TextSpan(text: rest),
              ],
            ),
          ),
        ),
      ],
    );
  }
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 3.5,
        height: 3.5,
        margin: const pw.EdgeInsets.only(top: 4, right: 6),
        decoration: const pw.BoxDecoration(color: PdfColors.black, shape: pw.BoxShape.circle),
      ),
      pw.Expanded(
        child: pw.Text(clean, style: const pw.TextStyle(fontSize: 9.2, color: PdfColors.black, lineSpacing: 1.35)),
      ),
    ],
  );
}

/// Helper to render detailed policies on page 4 with bold prefix before dash
pw.Widget _buildOfferPolicyPoint(String policyText) {
  final clean = _pdfSafe(policyText).trim();
  final dashIdx = clean.indexOf(' - ');
  if (dashIdx != -1) {
    final title = clean.substring(0, dashIdx + 3);
    final rest = clean.substring(dashIdx + 3);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 3.5,
          height: 3.5,
          margin: const pw.EdgeInsets.only(top: 4, right: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.black, shape: pw.BoxShape.circle),
        ),
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 9.2, color: PdfColors.black, lineSpacing: 1.35),
              children: [
                pw.TextSpan(text: title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.TextSpan(text: rest),
              ],
            ),
          ),
        ),
      ],
    );
  }
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 3.5,
        height: 3.5,
        margin: const pw.EdgeInsets.only(top: 4, right: 6),
        decoration: const pw.BoxDecoration(color: PdfColors.black, shape: pw.BoxShape.circle),
      ),
      pw.Expanded(
        child: pw.Text(clean, style: const pw.TextStyle(fontSize: 9.2, color: PdfColors.black, lineSpacing: 1.35)),
      ),
    ],
  );
}

/// Helper to render numbered responsibility items
pw.Widget _buildNumberedResponsibility({required int number, required String itemText}) {
  var clean = _pdfSafe(itemText).trim();
  final leadingNumRegex = RegExp(r'^\d+[\.\)]\s*');
  if (leadingNumRegex.hasMatch(clean)) {
    clean = clean.replaceFirst(leadingNumRegex, '');
  }

  final dashIdx = clean.indexOf(' - ');
  if (dashIdx != -1) {
    final title = clean.substring(0, dashIdx + 3);
    final rest = clean.substring(dashIdx + 3);
    return pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 9.2, color: PdfColors.black, lineSpacing: 1.35),
        children: [
          pw.TextSpan(text: '$number.$title', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.TextSpan(text: rest),
        ],
      ),
    );
  }
  return pw.RichText(
    text: pw.TextSpan(
      style: const pw.TextStyle(fontSize: 9.2, color: PdfColors.black, lineSpacing: 1.35),
      children: [
        pw.TextSpan(text: '$number. ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TextSpan(text: clean),
      ],
    ),
  );
}

/// Helper to build page background: Header ONLY on page 1, Footer & Watermark on all pages
pw.Widget _buildOfferPageBackground({required bool isFirstPage, required double a4Width}) {
  const headerHeight = 99.0;
  const headerTop = 54.0; // Top white space matching original template (54 pt)
  const footerHeight = 57.0;
  const footerBottom = 35.0; // Bottom white space matching original template (35 pt)

  return pw.FullPage(
    ignoreMargins: true,
    child: pw.Stack(
      children: [
        // Top Header Banner with top white space ONLY on page 1
        if (isFirstPage) ...[
          if (_headerBannerCache != null)
            pw.Positioned(
              top: headerTop,
              left: 0,
              right: 0,
              child: pw.Image(
                _headerBannerCache!,
                width: a4Width,
                height: headerHeight,
                fit: pw.BoxFit.fill,
              ),
            )
          else
            pw.Positioned(
              top: headerTop,
              left: 0,
              right: 0,
              child: pw.Container(
                height: headerHeight,
                color: kPdfNavy,
                padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (_nizanLogoCache != null)
                      pw.Image(_nizanLogoCache!, height: 46)
                    else
                      pw.Text('NIZAN BEAUTY VENTURES',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    pw.Text('+91 9645424283  |  www.nizanmakeovers.com',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 9.5)),
                  ],
                ),
              ),
            ),
        ],

        // Bottom Footer Banner with bottom white space on all pages
        if (_footerBannerCache != null)
          pw.Positioned(
            bottom: footerBottom,
            left: 0,
            right: 0,
            child: pw.Image(
              _footerBannerCache!,
              width: a4Width,
              height: footerHeight,
              fit: pw.BoxFit.fill,
            ),
          )
        else
          pw.Positioned(
            bottom: footerBottom,
            left: 0,
            right: 0,
            child: pw.Container(
              height: footerHeight,
              color: kPdfNavy,
              padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: pw.Text(
                'Nizan Beauty Ventures Private Limited | Hilite Business Park, Kozhikode, Kerala',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 8.5),
              ),
            ),
          ),

        // Elegant Subtle Center Monogram Watermark on all pages
        if (_nizanMonogramCache != null)
          pw.Positioned.fill(
            child: pw.Center(
              child: pw.Opacity(
                opacity: 0.045,
                child: pw.Image(
                  _nizanMonogramCache!,
                  width: 320,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          )
        else if (_nizanLogoCache != null)
          pw.Positioned.fill(
            child: pw.Center(
              child: pw.Opacity(
                opacity: 0.045,
                child: pw.Image(
                  _nizanLogoCache!,
                  width: 280,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

String _fmtCurrency(double val) {
  if (val % 1 == 0) {
    return val.toInt().toString();
  }
  return val.toStringAsFixed(0);
}

/// Specialized Generator for Candidate Offer Letters matching the exact layout of SALMANUL FARIS -MM.pdf
Future<Uint8List> generateOfferLetterPdf({
  required Offer offer,
  DateTime? issueDate,
  String? candidateEmail,
  String? candidatePhone,
  String? candidateAddress,
  String? signatoryName,
  String? customBody,
}) async {
  await _ensureAssetsLoaded();

  final doc = pw.Document();
  const a4Width = 595.28;

  final dateOfIssue = issueDate ?? DateTime.now();
  final issueDateStr = DateFormat('dd/MM/yyyy').format(dateOfIssue);
  final effectiveDateStr = offer.joiningDate != null
      ? DateFormat('dd/MM/yyyy').format(offer.joiningDate!)
      : DateFormat('dd/MM/yyyy').format(dateOfIssue.add(const Duration(days: 1)));

  final reportingTo = offer.reportingTo.isNotEmpty ? offer.reportingTo : 'HR Manager';

  // Resolve responsibilities list: use offer's custom list, or marketing template, or general role template
  List<String> responsibilities = offer.responsibilities;
  if (responsibilities.isEmpty) {
    final desigLower = offer.designation.toLowerCase();
    if (desigLower.contains('market') ||
        desigLower.contains('growth') ||
        desigLower.contains('brand') ||
        desigLower.contains('digital') ||
        desigLower.contains('ad') ||
        desigLower.contains('seo')) {
      responsibilities = kDefaultMarketingResponsibilities;
    } else {
      // General comprehensive role responsibilities
      responsibilities = [
        'Strategic Planning - Develop and execute operational goals aligned with studio performance and company targets.',
        'Core Role Execution - Deliver high-quality work, ensuring exceptional standards and client satisfaction.',
        'Process & Pipeline Management - Oversee workflow processes, timelines, and quality checkpoints within the department.',
        'Client Coordination - Maintain professional communication, managing requirements and expectations seamlessly.',
        'Team Collaboration - Work closely with cross-functional teams to drive efficiency and team harmony.',
        'Quality & Standards - Uphold Nizan luxury brand guidelines and rigorous service delivery protocols.',
        'Performance Analysis - Track operational metrics, deliverables, turnaround times, and departmental benchmarks.',
        'Resource Optimization - Efficiently utilize company assets, tools, and budgets allocated to the department.',
        'Team Mentorship - Guide team members, assign tasks, review progress, and ensure timely project completion.',
        'Continuous Improvement - Proactively identify bottlenecks and suggest improvements to enhance business outcomes.',
        'Reporting & Documentation - Submit regular progress and performance reports to management as scheduled.',
        'Brand Ambassador - Represent Nizan Beauty Ventures with integrity, professionalism, and creative excellence.',
      ];
    }
  }

  // Page 1: Top 7 responsibilities; Page 2: Remaining responsibilities
  final page1Resp = responsibilities.take(7).toList();
  final page2Resp = responsibilities.skip(7).toList();

  final netSalary = offer.salary;
  final basicSalary = offer.effectiveBasicSalary;
  final hasHra = offer.hra > 0;
  final hasIncentive = offer.incentive > 0 || offer.incentiveNote.isNotEmpty;
  final incentiveNoteText = offer.incentiveNote.isNotEmpty
      ? offer.incentiveNote
      : 'Rs. ${NumberFormat('#,##,###').format(offer.incentive)} incentive will be applicable based on the company’s predefined Performance criteria';

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 1: Header banner, Title, Issue Date, Salutation, Intro, Resp 1-7
  // ══════════════════════════════════════════════════════════════════════════
  doc.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 178, 48, 115),
        buildBackground: (_) => _buildOfferPageBackground(isFirstPage: true, a4Width: a4Width),
      ),
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'EMPLOYMENT OFFER LETTER',
                style: pw.TextStyle(
                  fontSize: 14.5,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                  color: PdfColors.black,
                ),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'ISSUE DATE:$issueDateStr',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
            pw.SizedBox(height: 14),
            pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                children: [
                  const pw.TextSpan(text: 'Dear '),
                  pw.TextSpan(
                    text: _pdfSafe(offer.candidateName.toUpperCase()),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  const pw.TextSpan(text: ','),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black, lineSpacing: 1.4),
                children: [
                  const pw.TextSpan(text: 'We are pleased to offer you the position of '),
                  pw.TextSpan(text: _pdfSafe(offer.designation), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(text: ' at '),
                  pw.TextSpan(text: 'Nizan Beauty Ventures Pvt Ltd', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(text: ' effective on '),
                  pw.TextSpan(text: effectiveDateStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(text: '. In this role, you will report directly to the '),
                  pw.TextSpan(text: _pdfSafe(reportingTo), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(text: ' and will be responsible for the following key areas:'),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'RESPONSIBILITIES:-',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 8),
            for (int i = 0; i < page1Resp.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: _buildNumberedResponsibility(number: i + 1, itemText: page1Resp[i]),
              ),
          ],
        );
      },
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 2: Resp 8-15, Salary Structure table, Incentive Note
  // ══════════════════════════════════════════════════════════════════════════
  doc.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 100, 48, 115),
        buildBackground: (_) => _buildOfferPageBackground(isFirstPage: false, a4Width: a4Width),
      ),
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < page2Resp.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: _buildNumberedResponsibility(number: page1Resp.length + i + 1, itemText: page2Resp[i]),
              ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Salary Structure:-',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.2),
                1: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: pw.Text('COMPONENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: pw.Text('AMOUNT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: pw.Text('BASIC SALARY', style: const pw.TextStyle(fontSize: 9.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: pw.Text(_fmtCurrency(basicSalary), style: const pw.TextStyle(fontSize: 9.5)),
                    ),
                  ],
                ),
                if (hasHra)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: pw.Text('HRA', style: const pw.TextStyle(fontSize: 9.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: pw.Text(_fmtCurrency(offer.hra), style: const pw.TextStyle(fontSize: 9.5)),
                      ),
                    ],
                  ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: pw.Text('NET SALARY', style: const pw.TextStyle(fontSize: 9.5)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: pw.Text(_fmtCurrency(netSalary), style: const pw.TextStyle(fontSize: 9.5)),
                    ),
                  ],
                ),
              ],
            ),
            if (hasIncentive) ...[
              pw.SizedBox(height: 10),
              pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black),
                  children: [
                    pw.TextSpan(text: 'Note:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: _pdfSafe(incentiveNoteText)),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 3: Probation Period, Policies, Wedding Industry Specific Policies
  // ══════════════════════════════════════════════════════════════════════════
  final probationMonthsText = offer.probationMonths == 3
      ? 'three (3)'
      : '${offer.probationMonths} (${offer.probationMonths})';

  const generalPolicies = [
    'Probation Period: Initial evaluation phase for new hires',
    'Work Schedule: Standard working hours, overtime policy, and flexibility guidelines',
    'Professional Conduct: Expected behavior, dress code, and professionalism with clients, team, and vendors',
    'Anti-Harassment & Discrimination: Commitment to a safe and respectful workplace',
    'Confidentiality: Protection of client data and company information',
  ];

  const weddingPolicies = [
    'Client Communication: Maintain clear, professional communication, respect boundaries, and manage client expectations',
    'Conflict Resolution: Handle difficult situations calmly and de-escalate client issues professionally',
    'Vendor Management: Work with vendors in a professional manner and maintain positive relationships',
    'Appearance & Attire: Follow neat and professional dress standards during events',
    'Discretion: Maintain strict confidentiality of client and wedding details',
    'Social Media During Events: Use social media only with proper permission from clients/company',
  ];

  doc.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 100, 48, 115),
        buildBackground: (_) => _buildOfferPageBackground(isFirstPage: false, a4Width: a4Width),
      ),
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'PROBATION PERIOD',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black, lineSpacing: 1.4),
                children: [
                  const pw.TextSpan(text: 'Please note that you will be placed under a probationary period of '),
                  pw.TextSpan(text: probationMonthsText, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  const pw.TextSpan(
                    text: ' months commencing from your date of joining. During this period, your performance and suitability for the role will be evaluated.',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'POLICIES AND TERMS AND CONDITIONS',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 8),
            for (final p in generalPolicies)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: _buildOfferBulletPoint(p),
              ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Wedding Industry Specific Policies',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 8),
            for (final wp in weddingPolicies)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: _buildOfferBulletPoint(wp),
              ),
          ],
        );
      },
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 4: Additional Policies, SINCERELY / Acknowledge by Signatures
  // ══════════════════════════════════════════════════════════════════════════
  const additionalPolicies = [
    'Leave Policy - Employees are entitled to one paid leave per month; any additional leave will be treated as Loss of Pay (LOP).',
    'Attendance & Login Policy - Daily Time Box login is mandatory; failure to log work attendance will be considered Loss of Pay (LOP).',
    'Annual Increment Policy - Yearly salary increments are granted based on individual performance and the company\'s approved increment structure.',
    'Work Performance & Professional Conduct Policy - Employees are expected to complete assigned tasks within deadlines and maintain professional conduct; failure to do so may result in disciplinary action.',
    'Termination Policy - The company reserves the right to terminate employment without a notice period in cases of serious misconduct, policy violations, or actions that adversely affect the organization.',
  ];

  doc.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 100, 48, 115),
        buildBackground: (_) => _buildOfferPageBackground(isFirstPage: false, a4Width: a4Width),
      ),
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Additional Policies:-',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 12),
            for (final ap in additionalPolicies)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 14),
                child: _buildOfferPolicyPoint(ap),
              ),
            pw.SizedBox(height: 48),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SINCERELY,', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 38),
                    pw.Text('CEO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('FEENIYA NIZAN', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Nizan Beauty Ventures Pvt Ltd', style: const pw.TextStyle(fontSize: 9.5)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Acknowledge by', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 38),
                    pw.Text(
                      _pdfSafe(offer.candidateName.toUpperCase()),
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      _pdfSafe(offer.designation.toUpperCase()),
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

/// Specialized Generator for GeneratedLetter entities from the HR Letters vault
Future<Uint8List> generateHrLetterPdf({
  required GeneratedLetter letter,
  String? employeeDesignation,
  String? employeeDepartment,
  String? employeeEmail,
  String? employeePhone,
  double? baseSalary,
}) async {
  final title = letterTypeLabel(letter.type).toUpperCase();
  final isOffer = letter.type == 'offer';

  List<SalaryComponentItem>? salaryComponents;
  if (baseSalary != null && baseSalary > 0 && (isOffer || letter.type == 'salary_certificate')) {
    final basic = (baseSalary * 0.50).roundToDouble();
    final hra = (baseSalary * 0.25).roundToDouble();
    final special = baseSalary - (basic + hra);

    salaryComponents = [
      SalaryComponentItem(label: 'Basic Salary', monthly: basic),
      SalaryComponentItem(label: 'House Rent Allowance (HRA)', monthly: hra),
      SalaryComponentItem(label: 'Special Allowance', monthly: special),
      SalaryComponentItem(label: 'TOTAL GROSS SALARY', monthly: baseSalary, isHeaderOrTotal: true),
    ];
  }

  return NizanHrDocumentBuilder.build(
    title: title,
    date: letter.createdAt,
    recipientName: letter.employeeName,
    recipientDesignation: employeeDesignation,
    recipientDepartment: employeeDepartment,
    recipientEmail: employeeEmail,
    recipientPhone: employeePhone,
    subject: letter.subject.isNotEmpty ? letter.subject : '$title - ${letter.employeeName}',
    body: letter.body,
    salaryComponents: salaryComponents,
    signatoryName: letter.issuedByName.isNotEmpty ? letter.issuedByName : 'Authorized HR Signatory',
    signatoryTitle: 'Human Resources & Operations',
    includeCandidateAcceptance: isOffer,
  );
}

/// Triggers interactive print preview or direct PDF file download
Future<void> previewOrDownloadNizanHrDocument({
  required String filename,
  required Future<Uint8List> Function() documentBuilder,
  bool directDownload = false,
}) async {
  final bytes = await documentBuilder();

  if (directDownload) {
    await saveFileBytes(
      filename.endsWith('.pdf') ? filename : '$filename.pdf',
      bytes,
      mime: 'application/pdf',
    );
  } else {
    await Printing.layoutPdf(
      name: filename,
      onLayout: (format) async => bytes,
    );
  }
}
