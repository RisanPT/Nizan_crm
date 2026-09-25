import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/live_notifications.dart';
import '../../controllers/notification_providers.dart';
import '../../data/app_notification.dart';
import '../../services/web_notifier.dart';
import '../../../../core/providers/auth_provider.dart';
import 'notification_toast.dart';

/// Sits in the app shell and, while mounted, watches [liveNotificationsProvider]
/// for newly-arrived notifications and surfaces each as a popup:
///   • an in-app toast (all platforms), and
///   • a native browser notification on web (when the user granted permission).
///
/// A notification pops when it is unread and hasn't been popped before.
/// "Popped" ids are persisted PER USER (keyed by user-id) so a sales_manager
/// logging in after another role doesn't inherit the wrong primed baseline —
/// which was the root cause of popups not appearing for the sales_manager role.
class NotificationWatcher extends ConsumerStatefulWidget {
  const NotificationWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationWatcher> createState() =>
      _NotificationWatcherState();
}

class _NotificationWatcherState extends ConsumerState<NotificationWatcher> {
  static const _maxRemembered = 500;

  // Keys are computed per-user so different accounts on the same device
  // never share a primed baseline or a popped-ids list.
  String _prefsKey = 'popped_notification_ids';
  String _primedKey = 'notif_watcher_primed';

  final Set<String> _popped = {};
  bool _loaded = false;
  bool _primed = false; // baseline established (persisted across reloads)
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
      // Scope prefs keys to the logged-in user so a sales_manager logging in
      // after an admin doesn't inherit the admin's "already-primed" baseline.
      final userId = ref.read(authSessionProvider)?.userId ?? 'anon';
      _prefsKey = 'popped_notification_ids_$userId';
      _primedKey = 'notif_watcher_primed_$userId';
      _popped.addAll(_prefs?.getStringList(_prefsKey) ?? const []);
      _primed = _prefs?.getBool(_primedKey) ?? false;
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
      await _prefs?.setBool(_primedKey, true);
    } catch (_) {}
  }

  void _onPage(NotificationPage page) {
    // Wait until the persisted "already popped" set is loaded first.
    if (!_loaded) return;

    // First run ever on this device/user: record the existing inbox as a
    // baseline so we don't flood with the backlog. Everything that arrives
    // AFTER this priming pops. (Persisted, so a page reload doesn't re-baseline
    // and swallow new items.)
    if (!_primed) {
      for (final n in page.items) {
        _popped.add(n.id);
      }
      _primed = true;
      _persist();
      return;
    }

    // Pop any unread notification we haven't popped before — no time-window, so
    // client/server clock skew can't hide a fresh notification.
    final fresh = page.items
        .where((n) => !n.read && !_popped.contains(n.id))
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
    void openLink() {
      if (mounted && n.link.isNotEmpty) context.go(n.link);
    }

    // Native OS notification (web only; no-op elsewhere). Auto-closes, closes
    // on click, and is tagged by id so multiple tabs don't stack copies.
    showWebNotification(n.title, n.body, id: n.id, onClick: openLink);
    // In-app toast (works on every platform). Closing either one closes both.
    if (!mounted) return;
    NotificationToast.show(
      context,
      title: n.title,
      body: n.body,
      icon: _iconFor(n.type),
      onTap: n.link.isNotEmpty ? openLink : null,
      onDismissed: () => closeWebNotification(n.id),
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
      case 'report_uploaded':
        return Icons.folder_shared_rounded;
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
