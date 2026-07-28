import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/utils/kerala_pincodes.dart';

void main() {
  group('keralaDistrict', () {
    test('resolves an exact listed pincode', () {
      expect(keralaDistrict('673001'), 'Kozhikode');
      expect(keralaDistrict('695001'), 'Thiruvananthapuram');
    });

    test('resolves an unlisted pincode via its 3-digit prefix', () {
      // 673616 is not in the table, but every 673xxx is Kozhikode.
      expect(keralaDistrict('673616'), 'Kozhikode');
    });

    test('trims whitespace', () {
      expect(keralaDistrict('  673616 '), 'Kozhikode');
    });

    test('returns null for a non-Kerala / unknown prefix', () {
      expect(keralaDistrict('110001'), isNull); // Delhi
      expect(keralaDistrict(''), isNull);
      expect(keralaDistrict('9'), isNull);
    });
  });
}
