import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/reports/data/financial_analyst_report.dart';
import 'package:nizan_crm/core/utils/financial_report_html.dart';

void main() {
  Map<String, dynamic> sample() => {
        'month': '2026-07',
        'sales': {
          'packageBreakdown': [
            {
              'package': 'Airbrush',
              'count': 4,
              'revenue': 100000,
              'advance': 12000,
              'balance': 88000,
              'cancellations': 1,
            },
            {
              'package': 'Platinum',
              'count': 2,
              'revenue': 90000,
              'advance': 6000,
              'balance': 84000,
              'cancellations': 0,
            },
          ],
          'totals': {
            'totalBookings': 6,
            'totalRevenue': 190000,
            'totalAdvance': 18000,
            'totalBalance': 172000,
            'totalDiscounts': 5000,
            'totalCancellations': 1,
          },
          'enquiries': 20,
          'leadSource': {'Instagram': 12, 'Reference': 5, 'Walk-in': 3},
          'forwardBookings': {'count': 3, 'value': 75000},
        },
        'customerRelations': {
          'activeClients': 6,
          'newClients': 4,
          'repeatClients': 2,
          'districtBreakdown': [
            {'district': 'Kozhikode', 'count': 4, 'revenue': 120000},
            {'district': 'Thrissur', 'count': 2, 'revenue': 70000},
          ],
          'referralLeads': 5,
          'cancellations': [
            {'customer': 'Asha', 'package': 'Airbrush', 'reason': 'Date clash'},
          ],
        },
        'finance': {
          'cashCollected': 45000,
          'receivablesAging': {'d0_30': 172000, 'd31_90': 20000, 'd90plus': 0},
        },
      };

  group('FinancialAnalystReport.fromJson', () {
    test('parses all sections', () {
      final r = FinancialAnalystReport.fromJson(sample());
      expect(r.month, '2026-07');
      expect(r.packageBreakdown.length, 2);
      expect(r.packageBreakdown.first.package, 'Airbrush');
      expect(r.totalRevenue, 190000);
      expect(r.totalCancellations, 1);
      expect(r.enquiries, 20);
      expect(r.leadSource['Instagram'], 12);
      expect(r.forwardCount, 3);
      expect(r.newClients, 4);
      expect(r.repeatClients, 2);
      expect(r.districtBreakdown.first.district, 'Kozhikode');
      expect(r.referralLeads, 5);
      expect(r.cancellations.first.reason, 'Date clash');
      expect(r.cashCollected, 45000);
      expect(r.aging31to90, 20000);
    });

    test('tolerates an empty payload', () {
      final r = FinancialAnalystReport.fromJson({});
      expect(r.packageBreakdown, isEmpty);
      expect(r.totalRevenue, 0);
      expect(r.districtBreakdown, isEmpty);
    });
  });

  group('buildFinancialReportHtml', () {
    final html = buildFinancialReportHtml(
        FinancialAnalystReport.fromJson(sample()));

    test('is a self-contained branded document', () {
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('Team N Makeovers'));
      expect(html, contains('2026-07'));
    });

    test('includes package, district and finance data', () {
      expect(html, contains('Airbrush'));
      expect(html, contains('Platinum'));
      expect(html, contains('Kozhikode'));
      expect(html, contains('₹190,000')); // grouped revenue
      expect(html, contains('Cash collected'));
    });
  });
}
