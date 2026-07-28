import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/presentation/screens/client_profile_screen.dart';

Booking _b({String phone = '', String name = ''}) => Booking.fromJson({
      '_id': 'x',
      'customerName': name,
      'phone': phone,
      'totalPrice': 0,
    });

void main() {
  group('clientPhoneKey', () {
    test('keeps the last 10 digits, ignoring formatting/country code', () {
      expect(clientPhoneKey('+91 73561 96623'), '7356196623');
      expect(clientPhoneKey('073561-96623'), '7356196623');
      expect(clientPhoneKey('7356196623'), '7356196623');
    });
    test('is empty for null/blank', () {
      expect(clientPhoneKey(null), '');
      expect(clientPhoneKey('  '), '');
    });
  });

  group('bookingMatchesClient', () {
    const key = '7356196623';
    test('matches by phone regardless of formatting', () {
      expect(
        bookingMatchesClient(_b(phone: '+91 73561 96623', name: 'Anything'),
            phoneKey: key, nameLower: 'shifa'),
        isTrue,
      );
    });

    test('does not match a different phone even with same-ish name', () {
      expect(
        bookingMatchesClient(_b(phone: '9000000000', name: 'Other'),
            phoneKey: key, nameLower: 'shifa'),
        isFalse,
      );
    });

    test('falls back to exact name when the booking has no phone', () {
      expect(
        bookingMatchesClient(_b(phone: '', name: 'Shifa'),
            phoneKey: key, nameLower: 'shifa'),
        isTrue,
      );
    });

    test('a too-short client phone key never matches by phone', () {
      // Prevents a blank/short key from vacuously matching phoneless bookings.
      expect(
        bookingMatchesClient(_b(phone: '', name: 'A'),
            phoneKey: '123', nameLower: 'zzz'),
        isFalse,
      );
    });
  });
}
