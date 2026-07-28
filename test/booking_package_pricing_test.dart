import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

/// Guards the pricing rule: the ₹3000-per-package amount is the ADVANCE, and
/// must never be added on top of a package's price in the displayed/derived
/// booking amounts. Two ₹24,500 packages total ₹49,000 — not ₹55,000.
Booking _twoPackageBooking() => Booking.fromJson({
      '_id': 'b1',
      'customerName': 'Test',
      'phone': '1',
      'totalPrice': 49000, // Σ item base, no per-package charge
      'advanceAmount': 6000, // 2 packages × ₹3000 advance
      'bookingItems': [
        {
          'service': 'Bridal',
          'totalPrice': 24500,
          'advanceAmount': 3000,
          'selectedDates': ['2026-07-24'],
        },
        {
          'service': 'Bridal',
          'totalPrice': 24500,
          'advanceAmount': 3000,
          'selectedDates': ['2026-07-25'],
        },
      ],
    });

void main() {
  test('each package display entry shows its base price, not base + 3000', () {
    final b = _twoPackageBooking();
    final entries = b.displayEntries;
    expect(entries.length, 2);
    for (final e in entries) {
      expect(e.totalPrice, 24500,
          reason: 'a package entry must not have the ₹3000 advance added');
    }
  });

  test('package entry totals sum to the booking total (no inflation)', () {
    final b = _twoPackageBooking();
    final sum = b.displayEntries.fold<double>(0, (s, e) => s + e.totalPrice);
    expect(sum, b.totalPrice);
    expect(sum, 49000);
  });

  test('advance is package count × 3000, kept out of the total', () {
    final b = _twoPackageBooking();
    final advSum =
        b.displayEntries.fold<double>(0, (s, e) => s + e.advanceAmount);
    expect(advSum, 6000);
    // The advance is NOT part of the package total.
    expect(b.totalPrice, isNot(equals(b.totalPrice + advSum)));
  });
}
