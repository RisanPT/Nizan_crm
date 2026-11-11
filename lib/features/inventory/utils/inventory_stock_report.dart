import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/branded_pdf.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';

/// Inventory stock report (PDF, A4 landscape, Team N branding):
///  1. Summary — totals: products, in stock, low stock, out of stock, units,
///     stock value.
///  2. Category summary — the same counts per category.
///  3. In Stock — detailed list of every product with quantity > 0
///     (low-stock items flagged).
///  4. Out of Stock — detailed list of every product with quantity ≤ 0.
///
/// Status rule matches the app: Out = qty ≤ 0, Low = qty ≤ low-stock level.
/// Web → browser download; mobile → share sheet.

/// Button handler shared by the Stock List and Inventory Reports screens.
Future<void> exportInventoryStockReport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Preparing stock report…')));
  try {
    final products = await ref.read(inventoryProductsProvider.future);
    final now = DateTime.now();
    final bytes = await buildInventoryStockReportPdf(products, now: now);
    await saveFileBytes(
      'Inventory_Stock_Report_${DateFormat('yyyy-MM-dd').format(now)}.pdf',
      bytes,
      mime: 'application/pdf',
    );
    final out = products.where((p) => p.quantity <= 0).length;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
            'Stock report downloaded · ${products.length - out} in stock, $out out of stock'),
      ));
  } catch (e) {
    messenger.hideCurrentSnackBar();
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

/// Stock status label used throughout the report.
String stockStatusOf(InventoryProduct p) {
  if (p.quantity <= 0) return 'Out of Stock';
  if (p.quantity <= p.lowStockThreshold) return 'Low Stock';
  return 'In Stock';
}

// The built-in PDF fonts have no ₹ glyph, so amounts are written "Rs 1,23,456".
final _rs = NumberFormat.decimalPattern('en_IN');
String _money(num v) => 'Rs ${_rs.format(v.round())}';

const _red = PdfColor.fromInt(0xFFB91C1C);
const _amber = PdfColor.fromInt(0xFFB45309);
const _green = PdfColor.fromInt(0xFF047857);

Future<Uint8List> buildInventoryStockReportPdf(
  List<InventoryProduct> products, {
  DateTime? now,
}) async {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final sorted = [...products]
    ..sort((a, b) {
      final c = a.category.toLowerCase().compareTo(b.category.toLowerCase());
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  final inStock = sorted.where((p) => p.quantity > 0).toList();
  final outStock = sorted.where((p) => p.quantity <= 0).toList();
  final lowCount = inStock.where((p) => p.quantity <= p.lowStockThreshold).length;
  final units = inStock.fold<int>(0, (a, p) => a + p.quantity);
  final value = inStock.fold<double>(0, (a, p) => a + p.quantity * p.price);

  final dateFmt = DateFormat('d MMM yyyy');
  final logo = await brandedPdfLogo();
  final doc = pw.Document(title: 'Inventory Stock Report');

  // ── building blocks ───────────────────────────────────────────────────────
  pw.Widget statBox(String label, String v, PdfColor color) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6),
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: kPdfBrandLt,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(pdfSafe(label), style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
            pw.SizedBox(height: 3),
            pw.Text(pdfSafe(v),
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: color)),
          ]),
        ),
      );

  pw.Widget sectionTitle(String t, String sub) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 5),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(pdfSafe(t),
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
          pw.SizedBox(width: 8),
          pw.Text(pdfSafe(sub), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ]),
      );

  pw.Widget cell(String text,
          {pw.Alignment align = pw.Alignment.centerLeft,
          bool bold = false,
          PdfColor? color,
          double size = 8}) =>
      pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(pdfSafe(text),
            style: pw.TextStyle(
              fontSize: size,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.grey900,
            )),
      );

  // Detailed product list. Returned as a splittable Table (not wrapped in a
  // Column) so long lists flow across pages.
  pw.Widget productTable(List<InventoryProduct> list) {
    const headers = [
      '#', 'Product', 'Brand', 'Shade', 'Category', 'Type', 'Barcode',
      'Qty', 'Min', 'Unit Price', 'Stock Value', 'Expiry', 'Status', 'Updated',
    ];
    const right = {0, 7, 8, 9, 10};
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(22),
      1: const pw.FlexColumnWidth(3.2),
      2: const pw.FlexColumnWidth(1.6),
      3: const pw.FlexColumnWidth(1.2),
      4: const pw.FlexColumnWidth(1.3),
      5: const pw.FlexColumnWidth(1.3),
      6: const pw.FlexColumnWidth(1.7),
      7: const pw.FixedColumnWidth(30),
      8: const pw.FixedColumnWidth(32),
      9: const pw.FixedColumnWidth(58),
      10: const pw.FixedColumnWidth(64),
      11: const pw.FixedColumnWidth(62),
      12: const pw.FixedColumnWidth(58),
      13: const pw.FixedColumnWidth(58),
    };
    if (list.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
        child: pw.Text('No products', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      );
    }
    var i = 0;
    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          repeat: true, // header repeats on every page
          decoration: const pw.BoxDecoration(color: kPdfBrandLt),
          children: [
            for (var c = 0; c < headers.length; c++)
              cell(headers[c],
                  bold: true,
                  color: kPdfBrand,
                  align: right.contains(c) ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
          ],
        ),
        for (final p in list)
          () {
            i++;
            final status = stockStatusOf(p);
            final expired = p.expiry != null && p.expiry!.toLocal().isBefore(today);
            final statusColor = status == 'Out of Stock'
                ? _red
                : status == 'Low Stock'
                    ? _amber
                    : _green;
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.grey100 : PdfColors.white),
              children: [
                cell('$i', align: pw.Alignment.centerRight),
                cell(p.name, bold: true),
                cell(p.brand),
                cell(p.shade),
                cell(p.category),
                cell(p.productType),
                cell(p.barcode, size: 7.5),
                cell('${p.quantity}', align: pw.Alignment.centerRight, bold: true, color: statusColor),
                cell('${p.lowStockThreshold}', align: pw.Alignment.centerRight),
                cell(_money(p.price), align: pw.Alignment.centerRight),
                cell(_money(p.quantity > 0 ? p.quantity * p.price : 0), align: pw.Alignment.centerRight),
                cell(
                  p.expiry == null ? '-' : '${dateFmt.format(p.expiry!.toLocal())}${expired ? ' (expired)' : ''}',
                  color: expired ? _red : null,
                ),
                cell(status, bold: true, color: statusColor),
                cell(p.updatedAt == null ? '-' : dateFmt.format(p.updatedAt!)),
              ],
            );
          }(),
      ],
    );
  }

  // Category summary rows.
  final byCat = <String, List<InventoryProduct>>{};
  for (final p in sorted) {
    byCat.putIfAbsent(p.category.trim().isEmpty ? 'Other' : p.category, () => []).add(p);
  }
  final catRows = <List<String>>[
    for (final e in byCat.entries)
      () {
        final ps = e.value;
        final inS = ps.where((p) => p.quantity > 0).toList();
        return [
          e.key,
          '${ps.length}',
          '${inS.length}',
          '${inS.where((p) => p.quantity <= p.lowStockThreshold).length}',
          '${ps.length - inS.length}',
          '${inS.fold<int>(0, (a, p) => a + p.quantity)}',
          _money(inS.fold<double>(0, (a, p) => a + p.quantity * p.price)),
        ];
      }(),
    [
      'TOTAL', '${sorted.length}', '${inStock.length}', '$lowCount',
      '${outStock.length}', '$units', _money(value),
    ],
  ];

  doc.addPage(pw.MultiPage(
    maxPages: 500,
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.fromLTRB(26, 26, 26, 30),
    header: (ctx) => ctx.pageNumber == 1
        ? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              if (logo != null) ...[
                pw.SizedBox(height: 42, width: 42, child: pw.Image(logo, fit: pw.BoxFit.contain)),
                pw.SizedBox(width: 12),
              ],
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Inventory Stock Report',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
                  pw.Text(pdfSafe('In stock & out of stock - as of ${DateFormat('d MMM yyyy, h:mm a').format(now!)}'),
                      style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700)),
                ]),
              ),
              pw.Text('Team N ERP',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
            ]),
            pw.SizedBox(height: 8),
            pw.Container(height: 2.5, color: kPdfBrand),
          ])
        : pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text('Inventory Stock Report (continued)',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kPdfBrand)),
          ),
    footer: (ctx) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.6)),
      ),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(
            pdfSafe('Team N ERP - generated ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}'),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ]),
    ),
    build: (ctx) => [
      pw.SizedBox(height: 12),
      pw.Row(children: [
        statBox('Total products', '${sorted.length}', kPdfBrand),
        statBox('In stock', '${inStock.length}', _green),
        statBox('Low stock', '$lowCount', _amber),
        statBox('Out of stock', '${outStock.length}', _red),
        statBox('Units in stock', '$units', kPdfBrand),
        statBox('Stock value', _money(value), kPdfBrand),
      ]),

      sectionTitle('Category Summary', 'products and stock per category'),
      pw.TableHelper.fromTextArray(
        headers: const ['Category', 'Products', 'In Stock', 'Low Stock', 'Out of Stock', 'Units', 'Stock Value'],
        data: catRows,
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: kPdfBrand),
        headerDecoration: const pw.BoxDecoration(color: kPdfBrandLt),
        cellStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey900),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          for (var c = 1; c < 7; c++) c: pw.Alignment.centerRight,
        },
      ),

      // Each detailed list starts on its own page so its title never sits
      // alone at the foot of the previous page.
      pw.NewPage(),
      sectionTitle('In Stock - ${inStock.length} products',
          'quantity above 0 - $lowCount at or below their low-stock level'),
      productTable(inStock),

      pw.NewPage(),
      sectionTitle('Out of Stock - ${outStock.length} products', 'quantity 0 - need restocking'),
      productTable(outStock),
    ],
  ));
  return doc.save();
}
