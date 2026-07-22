import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/utils/phone_utils.dart';

void main() {
  group('normalizePhone', () {
    test('strips spaces, tabs and surrounding whitespace', () {
      expect(normalizePhone('70341 09552'), '7034109552');
      expect(normalizePhone('  7034109552  '), '7034109552');
      expect(normalizePhone('70341\t09552'), '7034109552');
      expect(normalizePhone(' 94476 19804 '), '9447619804');
    });

    test('keeps the country code intact', () {
      expect(normalizePhone('+91 70341 09552'), '+917034109552');
    });

    test('handles null and empty safely', () {
      expect(normalizePhone(null), '');
      expect(normalizePhone(''), '');
    });
  });

  group('phoneMatchKey', () {
    test('matches the same number typed different ways', () {
      const forms = [
        '7034109552',
        '70341 09552',
        '+91 70341 09552',
        '070341-09552',
        ' 70341  09552 ',
      ];
      for (final f in forms) {
        expect(phoneMatchKey(f), '7034109552', reason: 'failed for "$f"');
      }
    });

    test('does not match a different number', () {
      expect(phoneMatchKey('7034109553'), isNot(phoneMatchKey('7034109552')));
    });

    test('leaves short numbers as-is', () {
      expect(phoneMatchKey('98954'), '98954');
    });
  });
}
