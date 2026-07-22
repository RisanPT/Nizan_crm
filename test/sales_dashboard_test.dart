import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/booking.dart';
import 'package:nizan_crm/core/models/crm_user.dart';
import 'package:nizan_crm/core/models/lead.dart';
import 'package:nizan_crm/core/providers/booking_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_dashboard_screen.dart';
import 'package:nizan_crm/services/lead_service.dart';
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

Widget _harness(List<dynamic> overrides) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
      home: const Scaffold(body: SalesDashboardScreen()),
    ),
  );
}

void main() {
  testWidgets('renders with data without layout errors', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness([
      bookingProvider.overrideWith(
          () => _FakeBookingNotifier([_booking('1'), _booking('2')])),
      leadsProvider.overrideWith((ref) async => [
            _lead(id: '1', status: 'Converted', assignedTo: 'u1'),
            _lead(id: '2', status: 'New', assignedTo: 'u1'),
            _lead(id: '3', status: 'Lost', source: 'Website'),
          ]),
      crmUsersProvider.overrideWith((ref) async => [
            const CrmUser(
                id: 'u1',
                name: 'Amal',
                email: 'a@b.c',
                role: 'sales',
                active: true),
          ]),
    ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sales Manager Dashboard'), findsOneWidget);
    expect(find.text('Lead & Conversion Overview'), findsOneWidget);
    expect(find.text('Recent Leads'), findsOneWidget);
  });

  testWidgets('renders on a narrow screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness([
      bookingProvider.overrideWith(() => _FakeBookingNotifier([_booking('1')])),
      leadsProvider
          .overrideWith((ref) async => [_lead(id: '1', status: 'Converted')]),
      crmUsersProvider.overrideWith((ref) async => <CrmUser>[]),
    ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders with no data at all', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness([
      bookingProvider.overrideWith(() => _FakeBookingNotifier([])),
      leadsProvider.overrideWith((ref) async => <Lead>[]),
      crmUsersProvider.overrideWith((ref) async => <CrmUser>[]),
    ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sales Manager Dashboard'), findsOneWidget);
  });
}
