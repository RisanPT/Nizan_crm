import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_leads_screen.dart';

void main() {
  group('lead status list', () {
    test('Qualified is no longer selectable', () {
      expect(kLeadStatuses.contains('Qualified'), isFalse);
      expect(kLeadStatusFilters.contains('Qualified'), isFalse);
      expect(kLeadStatusFilters.first, 'All');
    });

    test('coerceLeadStatus keeps valid statuses', () {
      for (final s in kLeadStatuses) {
        expect(coerceLeadStatus(s), s);
      }
    });

    test('coerceLeadStatus maps legacy Qualified to Contacted', () {
      // A legacy value must map to something IN the list, or the dropdown asserts.
      expect(coerceLeadStatus('Qualified'), 'Contacted');
      expect(kLeadStatuses.contains(coerceLeadStatus('Qualified')), isTrue);
    });
  });

  group('Lead.followUpCount', () {
    Map<String, dynamic> base() => {
          '_id': '1',
          'name': 'A',
          'phone': '1',
          'status': 'New',
          'reason': '',
          'remarks': '',
        };

    test('defaults to 0 when absent', () {
      expect(Lead.fromJson(base()).followUpCount, 0);
    });

    test('parses an integer count', () {
      expect(Lead.fromJson({...base(), 'followUpCount': 3}).followUpCount, 3);
    });
  });
}
