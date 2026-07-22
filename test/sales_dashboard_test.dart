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
import 'package:nizan_crm/features/sales/presentation/screens/sales_period_detail_screen.dart';
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
      home: Scaffold(body: screen ?? const SalesDashboardScreen()),
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

  testWidgets('day-wise report and FY/month pickers render', (tester) async {
    tester.view.physicalSize = const Size(1600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);

    await tester.pumpWidget(_harness([
      bookingProvider.overrideWith(() => _FakeBookingNotifier([_booking('1')])),
      leadsProvider.overrideWith((ref) async => [
            _lead(id: '1', status: 'Converted', date: thisMonth),
            _lead(id: '2', status: 'New', date: thisMonth),
          ]),
      crmUsersProvider.overrideWith((ref) async => <CrmUser>[]),
    ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Defaults to the current month => day-wise report.
    expect(find.text('Day-wise Report'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);

    // Open the month picker (second dropdown) and choose Full Year — the
    // report should switch from day buckets to month buckets.
    await tester.tap(find.byType(DropdownButton<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full Year').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Month-wise Report'), findsOneWidget);
    expect(find.text('Day-wise Report'), findsNothing);

    // Guard against unescaped-interpolation regressions: no label may leak a
    // raw Dart template like '\$fyStartYear' into the UI.
    final leaked = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.contains(r'$'))
        .toList();
    expect(leaked, isEmpty, reason: 'Uninterpolated text rendered: $leaked');
  });

  _periodDetailTests();

  testWidgets('revenue is attributed through the lead-booking link',
      (tester) async {
    tester.view.physicalSize = const Size(1700, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Two bookings worth 24,500 each; only ONE is linked to a converted lead,
    // so total revenue is 49,000 but lead-attributed revenue is 24,500.
    await tester.pumpWidget(_harness([
      bookingProvider.overrideWith(
          () => _FakeBookingNotifier([_booking('1'), _booking('2')])),
      leadsProvider.overrideWith((ref) async => [
            _lead(id: '1', status: 'Converted', bookingId: '1'),
            _lead(id: '2', status: 'New'),
          ]),
      crmUsersProvider.overrideWith((ref) async => <CrmUser>[]),
    ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('From Leads'), findsOneWidget);
    // 24,500 of 49,000 == 50%.
    expect(find.text('50% of revenue'), findsOneWidget);
  });

  testWidgets('KPI cards do not overflow at desktop widths', (tester) async {
    // Mirrors the real app: ~1990 logical px viewport minus a 340px sidebar.
    // Sweep the desktop range: the 6-column KPI grid must never overflow,
    // and text scaling nudges the content taller than the test default.
    for (final w in const [1250.0, 1400.0, 1650.0, 1920.0]) {
      tester.view.physicalSize = Size(w, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // 1.1x text scaling stands in for browsers rendering slightly taller
      // than the test default — that's what surfaced this in the real app.
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _harness([
          bookingProvider.overrideWith(
              () => _FakeBookingNotifier([_booking('1'), _booking('2')])),
          leadsProvider.overrideWith((ref) async => [
                _lead(id: '1', status: 'Converted', bookingId: '1'),
                _lead(id: '2', status: 'New'),
              ]),
          crmUsersProvider.overrideWith((ref) async => <CrmUser>[]),
        ]),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at width $w');
    }
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

    testWidgets('dashboard shows Today and This Week shortcuts',
        (tester) async {
      tester.view.physicalSize = const Size(1500, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness([
        bookingProvider.overrideWith(() => _FakeBookingNotifier([_booking('1')])),
        leadsProvider
            .overrideWith((ref) async => [_lead(id: '1', status: 'New')]),
        crmUsersProvider.overrideWith((ref) async => <CrmUser>[]),
      ]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('This Week'), findsWidgets);
    });
  });
}
