import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/spot_invoice.dart';
import 'package:nizan_crm/core/utils/spot_invoice_html.dart';

void main() {
  final fixedDate = DateTime(2026, 7, 31);

  group('SpotInvoiceData', () {
    test('total sums the line amounts', () {
      final data = SpotInvoiceData(
        invoiceNo: 'QT-1',
        customerName: 'Asha',
        lines: const [
          SpotInvoiceLine(label: 'Platinum Package', amount: 25000),
          SpotInvoiceLine(label: 'Hair styling', amount: 3000),
        ],
        date: fixedDate,
      );
      expect(data.total, 28000);
    });
  });

  group('buildSpotInvoiceHtml', () {
    final data = SpotInvoiceData(
      invoiceNo: 'QT-20260731-42',
      customerName: 'Asha & <Co>',
      customerPhone: '9876543210',
      lines: const [
        SpotInvoiceLine(label: 'Bridal Package', amount: 40000),
        SpotInvoiceLine(label: 'Draping', amount: 2000),
      ],
      date: fixedDate,
      note: 'Advance 3000 on booking',
    );

    final html = buildSpotInvoiceHtml(data);

    test('is a self-contained HTML document', () {
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('TEAM N MAKEOVERS'));
      expect(html, contains('QUOTATION'));
    });

    test('renders customer, lines and total', () {
      expect(html, contains('QT-20260731-42'));
      expect(html, contains('Bridal Package'));
      expect(html, contains('Draping'));
      expect(html, contains('9876543210'));
      expect(html, contains('42000')); // total
      expect(html, contains('Advance 3000 on booking'));
    });

    test('escapes HTML-unsafe characters in customer name', () {
      expect(html, contains('Asha &amp; &lt;Co&gt;'));
      expect(html, isNot(contains('<Co>')));
    });

    // The quotation deliberately reuses the Team N GST invoice layout (gst-* CSS classes, the company GSTIN in
    // "Company Details"), so the word GST appears — but it is labelled NO GST and charges no tax at all.
    test('is explicitly not a tax invoice (no GST)', () {
      expect(html.toLowerCase(), contains('not a tax invoice'));
      expect(html, contains('QUOTATION (NO GST)'));
      final upper = html.replaceAll(RegExp(r'data:image/[^"]+'), '').toUpperCase(); // not the logo's base64
      for (final tax in ['CGST', 'SGST', 'IGST', 'GST @', 'GST AMOUNT', 'TAXABLE', 'TAX AMOUNT', 'HSN', 'SAC']) {
        expect(upper, isNot(contains(tax)), reason: tax);
      }
      // the total is the plain sum of the lines: nothing is added on top
      expect(RegExp('₹42000').allMatches(html).length, 2, reason: 'subtotal and total are the same amount');
    });
  });
}
