import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/core/models/crm_user.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_period_detail_screen.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/services/user_service.dart';

class _FakeBookingNotifier extends BookingNotifier {
  _FakeBookingNotifier(this._items);
  final List<Booking> _items;

  @override
  FutureOr<List<Booking>> build() => _items;
}

Lead _lead({
  required String id,
  required String status,
  String source = 'Instagram',
  String district = 'Kozhikkode',
  String pincode = '673001',
  String? assignedTo,
  DateTime? date,
  String? bookingId,
}) {
  final d = date ?? DateTime.now();
  return Lead(
    id: id,
    name: 'Lead $id',
    phone: '98954998$id',
    source: source,
    location: 'Calicut',
    leadType: 'Individual',
    leadDate: d,
    enquiryDate: d,
    assignedTo: assignedTo,
    bookingId: bookingId,
    status: status,
    district: district,
    pincode: pincode,
    reason: '',
    remarks: '',
    createdAt: d,
    updatedAt: d,
  );
}

Booking _booking(String id) {
  final now = DateTime.now();
  return Booking(
    id: id,
    customerName: 'Client $id',
    phone: '9895499872',
    service: 'Platinum',
    bookingDate: now,
    serviceStart: now,
    serviceEnd: now.add(const Duration(hours: 1)),
    totalPrice: 24500,
    advanceAmount: 3000,
    createdAt: now,
  );
}

Widget _harness(List<dynamic> overrides, {Widget? screen}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
      home: Scaffold(body: screen!),
    ),
  );
}

void main() => _periodDetailTests();

void _periodDetailTests() {
  group('Sales period drill-down', () {
    for (final mode in const ['today', 'week']) {
      testWidgets('$mode view renders with data', (tester) async {
        tester.view.physicalSize = const Size(1500, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_harness(
          [
            bookingProvider
                .overrideWith(() => _FakeBookingNotifier([_booking('1')])),
            leadsProvider.overrideWith((ref) async => [
                  _lead(id: '1', status: 'Converted', assignedTo: 'u1'),
                  _lead(id: '2', status: 'New'),
                ]),
            crmUsersProvider.overrideWith((ref) async => [
                  const CrmUser(
                      id: 'u1',
                      name: 'Amal',
                      email: 'a@b.c',
                      role: 'sales',
                      active: true),
                ]),
          ],
          screen: SalesPeriodDetailScreen(mode: mode),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(mode == 'week' ? 'This Week' : "Today's Sales"),
            findsWidgets);
        expect(find.text('By Salesperson'), findsOneWidget);
      });

      testWidgets('$mode view renders empty and narrow', (tester) async {
        tester.view.physicalSize = const Size(400, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_harness(
          [
            bookingProvider.overrideWith(() => _FakeBookingNotifier([])),
            leadsProvider.overrideWith((ref) async => <Lead>[]),
            crmUsersProvider.overrideWith((ref) async => <CrmUser>[]),
          ],
          screen: SalesPeriodDetailScreen(mode: mode),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('specific-day view renders that date', (tester) async {
      tester.view.physicalSize = const Size(1500, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final target = DateTime(2026, 7, 8);
      await tester.pumpWidget(_harness(
        [
          bookingProvider.overrideWith(() => _FakeBookingNotifier([])),
          leadsProvider.overrideWith(
              (ref) async => [_lead(id: '1', status: 'New', date: target)]),
          crmUsersProvider.overrideWith((ref) async => <CrmUser>[]),
        ],
        screen: SalesPeriodDetailScreen(mode: 'day', date: target),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('8 July 2026'), findsOneWidget);
      // The lead dated 8 Jul must appear in that day's list.
      expect(find.text('Leads (1)'), findsOneWidget);
    });

  });
}
