// Artist Finance → expense bills show the event date (from the linked
// booking, or stored on the bill for model shoots) next to the bill date.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/trial_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/presentation/screens/artist_finance_screen.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoBookings extends BookingNotifier {
  @override
  FutureOr<List<Booking>> build() => <Booking>[];
}

Map<String, dynamic> _bill(String id, Map<String, dynamic> extra) => {
      '_id': id,
      'employeeId': {'_id': 'e1', 'name': 'Fathima Liya Muhammed Rafeeq'},
      'category': 'travel',
      'amount': 450,
      'date': '2026-11-11T10:00:00.000Z',
      'createdAt': '2026-11-11T10:00:00.000Z',
      'receiptImage': 'https://res.cloudinary.com/demo/image/upload/v1/bill.jpg',
      'status': 'pending',
      ...extra,
    };

List<ArtistExpense> _bills() => [
      // Bridal, linked to a 2-day booking.
      ArtistExpense.fromJson(_bill('x1', {
        'workType': 'bridal',
        'bookingId': {
          '_id': 'b1',
          'bookingNumber': 'TN-1001',
          'customerName': 'Anjali Krishnakumar Menon',
          'service': 'Bridal',
          'serviceStart': '2026-11-08T03:30:00.000Z',
          'serviceEnd': '2026-11-09T12:00:00.000Z',
        },
      })),
      // Model shoot with its own event date.
      ArtistExpense.fromJson(_bill('x2', {
        'workType': 'model_shoot',
        'eventDate': '2026-11-05T00:00:00.000Z',
      })),
      // Old bill: no booking, no event date.
      ArtistExpense.fromJson(_bill('x3', {'workType': 'bridal'})),
    ];

Future<void> _pump(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authSessionProvider.overrideWith((ref) => const AuthSession(
          token: 't', userId: 'u0', name: 'Admin', email: 'admin@example.com', role: 'admin')),
      bookingProvider.overrideWith(() => _NoBookings()),
      allTrialsProvider.overrideWith((ref) async => []),
      employeesProvider.overrideWith((ref) async => []),
      collectionsProvider.overrideWith((ref) async => []),
      expensesProvider.overrideWith((ref) async => _bills()),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: ArtistFinanceScreen())),
  ));
  await tester.pumpAndSettle();
  // Swipe to the EXPENSES tab (the test font is wide enough to clip the tab
  // label at 390px, so a tap on it can miss).
  await tester.fling(find.text('No collections logged yet'), const Offset(-300, 0), 1000);
  await tester.pumpAndSettle();
}

void main() {
  test('event date comes from the booking, else from the bill', () {
    final b = _bills();
    expect(b[0].eventStart!.day, 8);
    expect(b[0].eventEnd!.day, 9);
    expect(b[1].eventStart, DateTime.parse('2026-11-05T00:00:00.000Z').toLocal());
    expect(b[1].eventEnd, isNull);
    expect(b[2].eventStart, isNull);
  });

  for (final (label, size) in [('desktop 1440', const Size(1440, 1400)), ('phone 390', const Size(390, 2600))]) {
    testWidgets('$label: bill cards show event + bill dates', (tester) async {
      await _pump(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('Event: 08 Nov 2026 – 09 Nov 2026'), findsOneWidget);
      expect(find.textContaining('Event: 05 Nov 2026'), findsOneWidget);
      expect(find.text('Event date not set'), findsOneWidget);
      expect(find.text('Bill date: 11 Nov 2026'), findsNWidgets(3));
    });
  }

  testWidgets('expense form asks for the event date when no bookings exist', (tester) async {
    await _pump(tester, const Size(390, 1400));
    await tester.tap(find.text('EXPENSE').first);
    await tester.pumpAndSettle();
    expect(find.text('Event date *'), findsOneWidget);
    expect(find.text('Bill date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
