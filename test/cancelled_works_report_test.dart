import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/core/utils/cancelled_works_report_html.dart';
import 'package:nizan_crm/features/sales/presentation/screens/cancelled_works_screen.dart';

Booking _b({
  required String name,
  required double total,
  double advance = 0,
  String service = 'Bridal',
  String remarks = '',
  DateTime? event,
}) =>
    Booking.fromJson({
      '_id': 'x',
      'bookingNumber': 'BK1',
      'customerName': name,
      'phone': '9000000000',
      'service': service,
      'status': 'cancelled',
      'totalPrice': total,
      'advanceAmount': advance,
      'internalRemarks': remarks,
      'serviceStart': (event ?? DateTime(2026, 7, 24)).toIso8601String(),
    });

void main() {
  final when = DateTime(2026, 7, 28, 10, 0);

  group('financialYearLabel', () {
    test('April starts a new FY', () {
      expect(financialYearLabel(DateTime(2026, 4, 1)), 'FY 2026-27');
      expect(financialYearLabel(DateTime(2026, 12, 31)), 'FY 2026-27');
    });
    test('Jan–Mar belongs to the previous FY', () {
      expect(financialYearLabel(DateTime(2026, 3, 31)), 'FY 2025-26');
      expect(financialYearLabel(DateTime(2026, 1, 1)), 'FY 2025-26');
    });
  });

  group('buildCancelledWorksReportHtml', () {
    test('lists cancelled works and totals the value lost', () {
      final html = buildCancelledWorksReportHtml([
        _b(name: 'Asha', total: 24500, advance: 3000),
        _b(name: 'Meera', total: 20000, advance: 3000),
      ], generatedAt: when);

      expect(html, contains('Asha'));
      expect(html, contains('Meera'));
      expect(html, contains('Cancelled works: <b>2</b>'));
      expect(html, contains('₹44500')); // value lost 24500+20000
      expect(html, contains('₹6000')); // advance 3000+3000
      expect(html, contains('TEAM N MAKEOVERS'));
    });

    test('carries the period label', () {
      final html = buildCancelledWorksReportHtml([],
          generatedAt: when, periodLabel: 'FY 2026-27');
      expect(html, contains('FY 2026-27'));
      expect(html, contains('No cancelled works in this period.'));
    });

    test('escapes HTML in client-entered fields', () {
      final html = buildCancelledWorksReportHtml([
        _b(name: '<b>x</b>', total: 1, remarks: '<script>'),
      ], generatedAt: when);
      expect(html.contains('<b>x</b>'), isFalse);
      expect(html, contains('&lt;b&gt;x&lt;/b&gt;'));
      expect(html.contains('<script>'), isFalse);
    });
  });
}
