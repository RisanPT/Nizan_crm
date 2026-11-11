import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/models/trial.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/trial_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/presentation/screens/artist_finance_screen.dart';
import 'package:nizan_crm/services/employee_service.dart';

// Artist Finance sits its three tabs in a NestedScrollView. On a desktop browser (mouse
// wheel, auto scrollbars) the tab pages all share the one inner scroll controller, and a
// scrollbar on that controller used to throw "attached to more than one ScrollPosition"
// whenever two pages were alive at once (while swiping/switching tabs) and the wheel moved.

class _FakeBookingNotifier extends BookingNotifier {
  @override
  FutureOr<List<Booking>> build() => <Booking>[];
}

Map<String, dynamic> _coll(int i) => {
      '_id': 'c$i',
      'amount': 1000.0 + i,
      'status': 'verified',
      'paymentMode': 'upi',
      'date': '2026-10-12T04:30:00.000Z',
      'bookingId': {'_id': 'b$i', 'bookingNumber': 'BK-$i', 'customerName': 'Client $i', 'service': 'Bridal'},
      'employeeId': {'_id': 'e1', 'name': 'Anu'},
    };

Map<String, dynamic> _exp(int i) => {
      '_id': 'x$i',
      'amount': 300.0 + i,
      'status': 'verified',
      'category': 'travel',
      'workType': 'bridal',
      'date': '2026-10-12T04:30:00.000Z',
      'employeeId': {'_id': 'e1', 'name': 'Anu'},
      'notes': 'Expense note $i',
    };

Future<FinancePage<ArtistCollection>> _collections(FinanceQuery q) async => FinancePage(
      items: [for (var i = 0; i < 20; i++) ArtistCollection.fromJson(_coll(i))],
      page: 1,
      limit: 20,
      totalItems: 45,
      totalPages: 3,
      summary: FinanceSummary.fromJson({
        'byStatus': {'verified': {'count': 45, 'amount': 45000}},
        'shown': {'count': 45, 'amount': 45000},
      }),
    );

Future<FinancePage<ArtistExpense>> _expenses(FinanceQuery q) async => FinancePage(
      items: [for (var i = 0; i < 20; i++) ArtistExpense.fromJson(_exp(i))],
      page: 1,
      limit: 20,
      totalItems: 30,
      totalPages: 2,
      summary: FinanceSummary.fromJson({
        'byStatus': {'verified': {'count': 30, 'amount': 9000}},
        'shown': {'count': 30, 'amount': 9000},
      }),
    );

Widget _app() => ProviderScope(
      overrides: [
        financeCollectionsPageProvider.overrideWith((ref, q) => _collections(q)),
        financeExpensesPageProvider.overrideWith((ref, q) => _expenses(q)),
        employeesProvider.overrideWith((ref) async => [Employee.fromJson({'_id': 'e1', 'name': 'Anu', 'artistRole': 'artist', 'status': 'active'})]),
        bookingProvider.overrideWith(() => _FakeBookingNotifier()),
        allTrialsProvider.overrideWith((ref) async => <Trial>[]),
        authSessionProvider.overrideWithValue(
          const AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'accounts', employeeId: ''),
        ),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: ArtistFinanceScreen())),
    );

Future<void> _wheel(WidgetTester t, Offset at, double dy) async {
  final mouse = TestPointer(99, PointerDeviceKind.mouse);
  await t.sendEventToBinding(mouse.hover(at));
  await t.sendEventToBinding(mouse.scroll(Offset(0, dy)));
  await t.pump();
}

void main() {
  testWidgets('mouse wheel on a desktop never trips the scrollbar, even with two tab pages alive', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    try {
      await t.pumpWidget(_app());
      await t.pumpAndSettle();

      // the page still has its scroll thumb on desktop, just not one you can grab
      final bars = t.widgetList<Scrollbar>(find.byType(Scrollbar)).toList();
      expect(bars, isNotEmpty);
      expect(bars.every((b) => b.interactive == false), isTrue);

      const bodyPoint = Offset(700, 650);

      // 1. resting on the first tab
      await _wheel(t, bodyPoint, 300);
      await t.pumpAndSettle();

      // 2. half-way through a swipe to the next tab: two pages are alive at once
      final gesture = await t.startGesture(bodyPoint);
      await gesture.moveBy(const Offset(-100, 0));
      await gesture.moveBy(const Offset(-350, 0));
      await t.pump(const Duration(milliseconds: 50));
      await _wheel(t, bodyPoint, 200);
      await gesture.up();
      await t.pumpAndSettle();

      // 3. just after tapping another tab, while the page is still sliding
      await t.tap(find.text('COLLECTIONS'));
      await t.pump(const Duration(milliseconds: 60));
      await _wheel(t, bodyPoint, 200);
      await t.pumpAndSettle();

      await t.tap(find.text('BY WORK'));
      await t.pump(const Duration(milliseconds: 60));
      await _wheel(t, bodyPoint, 200);
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
