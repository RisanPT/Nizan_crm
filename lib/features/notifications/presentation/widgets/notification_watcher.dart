import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/live_notifications.dart';
import '../../controllers/notification_providers.dart';
import '../../data/app_notification.dart';
import '../../services/web_notifier.dart';
import 'notification_toast.dart';

/// Sits in the app shell and, while mounted, watches [liveNotificationsProvider]
/// for newly-arrived notifications and surfaces each as a popup:
///   • an in-app toast (all platforms), and
///   • a native browser notification on web (when the user granted permission).
///
/// A notification pops when it is unread, created within the last
/// [_recentWindow], and hasn't been popped before. "Popped" ids are persisted,
/// so a notification created just before the app opened (or a page reload on
/// web) still shows exactly once — while an old backlog never spams the screen.
class NotificationWatcher extends ConsumerStatefulWidget {
  const NotificationWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationWatcher> createState() => _NotificationWatcherState();
}

class _NotificationWatcherState extends ConsumerState<NotificationWatcher> {
  static const _prefsKey = 'popped_notification_ids';
  static const _recentWindow = Duration(minutes: 10);
  static const _maxRemembered = 500;

  final Set<String> _popped = {};
  bool _loaded = false;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    // Best-effort: ask for OS notification permission on web up front.
    ensureWebNotificationPermission();
    _load();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _popped.addAll(_prefs?.getStringList(_prefsKey) ?? const []);
    } catch (_) {
      // No persistence available — fall back to in-memory only.
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    try {
      final list = _popped.toList();
      final trimmed =
          list.length > _maxRemembered ? list.sublist(list.length - _maxRemembered) : list;
      await _prefs?.setStringList(_prefsKey, trimmed);
    } catch (_) {}
  }

  void _onPage(NotificationPage page) {
    // Wait until the persisted "already popped" set is loaded so we don't
    // replay old notifications on the first tick. The recent-window guard means
    // skipping one early tick can't lose a genuinely new notification.
    if (!_loaded) return;

    final cutoff = DateTime.now().subtract(_recentWindow);
    final fresh = page.items
        .where((n) =>
            !n.read &&
            !_popped.contains(n.id) &&
            n.createdAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (fresh.isEmpty) return;

    for (final n in fresh) {
      _popped.add(n.id);
    }
    _persist();

    // Keep the bell badge + inbox in sync with what we're popping.
    ref.invalidate(unreadCountProvider);
    ref.invalidate(notificationsProvider);

    // Only pop the newest few so a burst can't flood the screen.
    final toShow = fresh.length > 3 ? fresh.sublist(fresh.length - 3) : fresh;
    for (final n in toShow) {
      _popup(n);
    }
  }

  void _popup(AppNotification n) {
    // Native OS notification (web only; no-op elsewhere).
    showWebNotification(n.title, n.body);
    // In-app toast (works on every platform).
    if (!mounted) return;
    NotificationToast.show(
      context,
      title: n.title,
      body: n.body,
      icon: _iconFor(n.type),
      onTap: n.link.isNotEmpty ? () => context.go(n.link) : null,
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'payment_received':
        return Icons.payments_rounded;
      case 'expense_recorded':
        return Icons.receipt_long_rounded;
      case 'month_end_summary':
        return Icons.summarize_rounded;
      case 'booking_created':
        return Icons.event_available_rounded;
      case 'new_lead':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<NotificationPage>>(liveNotificationsProvider, (prev, next) {
      next.whenData(_onPage);
    });
    return widget.child;
  }
}
