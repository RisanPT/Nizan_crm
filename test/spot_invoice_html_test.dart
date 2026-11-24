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

    test('is explicitly not a tax invoice (no GST)', () {
      expect(html.toLowerCase(), contains('not a tax invoice'));
      expect(html.toUpperCase(), isNot(contains('GST')));
    });
  });
}
