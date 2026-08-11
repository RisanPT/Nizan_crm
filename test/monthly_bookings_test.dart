import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/sales/presentation/screens/monthly_bookings_screen.dart';

class _EmptyBookingNotifier extends BookingNotifier {
  @override
  FutureOr<List<Booking>> build() => <Booking>[];
}

void main() {
  testWidgets('renders controls + empty state (no blank body / layout crash)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingProvider.overrideWith(() => _EmptyBookingNotifier()),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
          home: const MonthlyBookingsScreen(),
        ),
      ),
    );
    await tester.pump(); // resolve the async notifier
    await tester.pump();

    // The basis toggle (the piece that previously crashed) must be present.
    expect(find.text('Event date'), findsOneWidget);
    expect(find.text('Booking date'), findsOneWidget);
    // Stats + empty message prove the data branch rendered.
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.textContaining('No bookings'), findsOneWidget);
    // No layout/render exception was thrown.
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow width renders without overflow', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingProvider.overrideWith(() => _EmptyBookingNotifier()),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
          home: const MonthlyBookingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Event date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
