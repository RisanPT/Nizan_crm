import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_notification.dart';
import 'notification_providers.dart';

/// How often the app checks for newly-arrived notifications while running.
/// Short enough to feel near-real-time, long enough not to hammer the API.
const _pollInterval = Duration(seconds: 15);

/// Polls the notifications inbox on an interval so the shell can surface new
/// notifications as popups without the user opening the inbox. Emits the latest
/// [NotificationPage] on each tick (and once immediately on subscribe).
final liveNotificationsProvider =
    StreamProvider.autoDispose<NotificationPage>((ref) {
  final api = ref.watch(notificationApiServiceProvider);
  final controller = StreamController<NotificationPage>();
  var closed = false;

  Future<void> tick() async {
    if (closed) return;
    try {
      final page = await api.getNotifications();
      if (!closed) controller.add(page);
    } catch (_) {
      // Transient network error — just try again on the next tick.
    }
  }

  tick();
  final timer = Timer.periodic(_pollInterval, (_) => tick());

  ref.onDispose(() {
    closed = true;
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});
