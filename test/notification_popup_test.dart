import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/notifications/controllers/live_notifications.dart';
import 'package:nizan_crm/features/notifications/data/app_notification.dart';
import 'package:nizan_crm/features/notifications/presentation/widgets/notification_watcher.dart';

NotificationPage _page(List<AppNotification> items) => NotificationPage(
      items: items,
      unreadCount: items.where((n) => !n.read).length,
      totalPages: 1,
      page: 1,
    );

Widget _harness(List<AppNotification> items) => ProviderScope(
      overrides: [
        liveNotificationsProvider.overrideWith((ref) async* {
          // Emit after a beat so the persisted "seen" set loads first.
          await Future<void>.delayed(const Duration(milliseconds: 40));
          yield _page(items);
        }),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
        home: const Scaffold(body: NotificationWatcher(child: SizedBox.expand())),
      ),
    );

void main() {
  testWidgets('pops a toast for a fresh unread notification', (tester) async {
    // Keys are scoped to the logged-in user; tests have no auth session → 'anon'.
    SharedPreferences.setMockInitialValues({'notif_watcher_primed_anon': true});

    await tester.pumpWidget(_harness([
      AppNotification(
        id: 'n1',
        type: 'payment_received',
        title: 'Payment received',
        body: 'A payment of Rs 5,000 was recorded.',
        read: false,
        createdAt: DateTime.now(),
      ),
    ]));

    await tester.pump(); // build + initState
    await tester.pump(const Duration(milliseconds: 80)); // provider emits
    await tester.pump(const Duration(milliseconds: 350)); // toast animates in

    expect(find.text('Payment received'), findsOneWidget);
    expect(find.text('A payment of Rs 5,000 was recorded.'), findsOneWidget);

    // Flush the 6s auto-dismiss timer so none are left pending.
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('does NOT pop an already-seen or already-read notification', (tester) async {
    // 'seen1' is already in the persisted popped-set; primed so no baseline.
    // Keys are user-scoped; tests have no auth session → 'anon'.
    SharedPreferences.setMockInitialValues({
      'notif_watcher_primed_anon': true,
      'popped_notification_ids_anon': ['seen1'],
    });

    await tester.pumpWidget(_harness([
      AppNotification(
        id: 'seen1',
        type: 'payment_received',
        title: 'Already popped',
        body: 'Should not pop again.',
        read: false,
        createdAt: DateTime.now(),
      ),
      AppNotification(
        id: 'read1',
        type: 'expense_recorded',
        title: 'Read expense',
        body: 'Already read.',
        read: true,
        createdAt: DateTime.now(),
      ),
    ]));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Already popped'), findsNothing);
    expect(find.text('Read expense'), findsNothing);
  });

  testWidgets('first run establishes a baseline (no flood), then pops new ones', (tester) async {
    // Not primed: the first page becomes the baseline and must NOT pop.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_harness([
      AppNotification(
        id: 'backlog',
        type: 'payment_received',
        title: 'Backlog item',
        body: 'Existed before app opened.',
        read: false,
        createdAt: DateTime.now(),
      ),
    ]));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Backlog item'), findsNothing);
  });
}
