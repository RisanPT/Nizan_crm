import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/presentation/widgets/booking_amount_breakdown.dart';

Booking _booking({
  double total = 0,
  double discount = 0,
  double advance = 0,
  double collected = 0,
  List<BookingAddon> addons = const [],
  List<BookingItem> items = const [],
}) =>
    Booking(
      id: 'b1',
      customerName: 'Test Bride',
      phone: '9999999999',
      service: 'Bridal',
      bookingDate: DateTime(2026, 12, 1),
      serviceStart: DateTime(2026, 12, 1),
      serviceEnd: DateTime(2026, 12, 1),
      totalPrice: total,
      discountAmount: discount,
      advanceAmount: advance,
      collectedAmount: collected,
      addons: addons,
      bookingItems: items,
    );

void main() {
  test('single package: package = total − add-ons; balance net of discount', () {
    final a = BookingAmounts.of(_booking(
      total: 50000,
      discount: 5000,
      advance: 3000,
      collected: 10000,
      addons: const [BookingAddon(service: 'Extra look', amount: 2500, persons: 2)],
    ));
    expect(a.packages.single.amount, 45000);
    expect(a.addonsTotal, 5000);
    expect(a.otherCharges, 0);
    expect(a.orderValue, 50000);
    expect(a.netPayable, 45000);
    expect(a.received, 13000);
    expect(a.balance, 32000);
  });

  test('multi package: per-item add-ons counted, nothing unexplained', () {
    final a = BookingAmounts.of(_booking(
      total: 61000,
      items: const [
        BookingItem(service: 'Engagement', totalPrice: 20000,
            addons: [BookingAddon(service: 'Hair extension', amount: 1000, persons: 1)]),
        BookingItem(service: 'Wedding', totalPrice: 40000),
      ],
    ));
    expect(a.packages.length, 2);
    expect(a.addons.single.amount, 1000);
    expect(a.addons.single.invoiceLabel, 'Hair extension (Engagement)');
    expect(a.otherCharges, 0);
    expect(a.balance, 61000);
  });

  test('unexplained part of total shows as other charges; overpaid balance is 0', () {
    final a = BookingAmounts.of(_booking(
      total: 30000,
      advance: 40000,
      items: const [BookingItem(service: 'Party', totalPrice: 25000)],
    ));
    expect(a.otherCharges, 5000);
    expect(a.balance, 0);
  });

  testWidgets('renders add-ons, discount and balance', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BookingAmountBreakdown(
            booking: _booking(
              total: 50000,
              discount: 5000,
              advance: 3000,
              addons: const [BookingAddon(service: 'Extra look', amount: 2500, persons: 2)],
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Extra look'), findsOneWidget);
    expect(find.text('Total order value'), findsOneWidget);
    expect(find.text('Discount'), findsWidgets);
    expect(find.text('Balance due'), findsOneWidget);
    expect(find.text('No add-ons taken'), findsNothing);
  });
}
