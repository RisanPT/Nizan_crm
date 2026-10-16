import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_api_service.dart';

/// How often the shell re-checks for unread client messages. Short enough to
/// feel near-real-time, long enough not to hammer the API. Mirrors the
/// notifications poll in `features/notifications/controllers/live_notifications.dart`.
const _pollInterval = Duration(seconds: 15);

/// Live unread-message count (client → staff) across every concierge thread,
/// polled on an interval so the sidebar badge updates without the user opening
/// the inbox. Emits once immediately on subscribe, then every tick.
final clientChatUnreadProvider = StreamProvider.autoDispose<int>((ref) {
  final api = ref.watch(clientChatApiServiceProvider);
  final controller = StreamController<int>();
  var closed = false;

  Future<void> tick() async {
    if (closed) return;
    try {
      final count = await api.getUnreadCount();
      if (!closed) controller.add(count);
    } catch (_) {
      // Transient network error — try again on the next tick.
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
