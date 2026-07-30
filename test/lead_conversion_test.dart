import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/features/sales/utils/lead_conversion.dart';

Lead _lead({
  String status = 'New',
  String? email,
  String address = '',
  String location = '',
  String pincode = '',
}) =>
    Lead.fromJson({
      '_id': 'lead123',
      'name': 'Chitra',
      'phone': '9745523227',
      'email': email,
      'address': address,
      'location': location,
      'pincode': pincode,
      'status': status,
      'reason': '',
      'remarks': '',
    });

void main() {
  group('canConvertLead', () {
    test('open pipeline stages can convert', () {
      for (final s in ['New', 'Contacted', 'Follow-up']) {
        expect(canConvertLead(_lead(status: s)), isTrue, reason: s);
      }
    });

    test('converted / lost / pending cannot convert again', () {
      for (final s in ['Converted', 'Lost', 'Pending Lost Approval']) {
        expect(canConvertLead(_lead(status: s)), isFalse, reason: s);
      }
    });
  });

  group('leadToBookingRoute', () {
    test('always carries mode, leadId, name and phone', () {
      final uri = Uri.parse(leadToBookingRoute(_lead()));
      expect(uri.path, '/booking/add');
      expect(uri.queryParameters['mode'], 'single');
      expect(uri.queryParameters['leadId'], 'lead123');
      expect(uri.queryParameters['name'], 'Chitra');
      expect(uri.queryParameters['phone'], '9745523227');
    });

    test('forwards known customer details for a richer prefill', () {
      final uri = Uri.parse(leadToBookingRoute(
        _lead(email: 'chitra@example.com', address: 'Kozhikode', pincode: '673001'),
      ));
      expect(uri.queryParameters['email'], 'chitra@example.com');
      expect(uri.queryParameters['address'], 'Kozhikode');
      expect(uri.queryParameters['pincode'], '673001');
    });

    test('falls back to location when the lead has no confirmed address', () {
      final uri = Uri.parse(leadToBookingRoute(_lead(location: 'Kozhikode')));
      expect(uri.queryParameters['address'], 'Kozhikode');
    });

    test('prefers the confirmed address over location when both exist', () {
      final uri = Uri.parse(
        leadToBookingRoute(_lead(address: '12 MG Road', location: 'Kozhikode')),
      );
      expect(uri.queryParameters['address'], '12 MG Road');
    });

    test('omits empty optional details instead of sending blanks', () {
      final uri = Uri.parse(leadToBookingRoute(_lead()));
      expect(uri.queryParameters.containsKey('email'), isFalse);
      expect(uri.queryParameters.containsKey('address'), isFalse);
      expect(uri.queryParameters.containsKey('pincode'), isFalse);
    });
  });
}
