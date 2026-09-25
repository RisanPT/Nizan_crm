// Web implementation of the browser Notification API.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get supported => true;

/// How long a native popup stays up before we close it ourselves. Without
/// this, Chrome/Edge on Windows keep it on screen until the user closes it.
const _autoClose = Duration(seconds: 8);

/// Open native notifications by notification id, so they can be closed when
/// the matching in-app toast is dismissed.
final Map<String, web.Notification> _open = {};

/// Current permission: 'granted' | 'denied' | 'default'.
String _permission() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'default';
  }
}

/// Request OS notification permission if the user hasn't decided yet.
Future<void> ensurePermission() async {
  try {
    if (_permission() == 'default') {
      await web.Notification.requestPermission().toDart;
    }
  } catch (_) {
    // Some browsers require a user gesture; the in-app toast covers that case.
  }
}

void showWebNotification(String title, String body,
    {String? id, void Function()? onClick}) {
  try {
    if (_permission() != 'granted') return;
    final key = id ?? '$title|$body';
    closeWebNotification(key);

    final n = web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        // Same tag => the OS replaces rather than stacks, so several open tabs
        // polling the same inbox show ONE popup, not one per tab.
        tag: key,
      ),
    );
    _open[key] = n;

    n.onclick = ((web.Event _) {
      try {
        web.window.focus();
      } catch (_) {}
      onClick?.call();
      closeWebNotification(key);
    }).toJS;
    n.onclose = ((web.Event _) {
      if (identical(_open[key], n)) _open.remove(key);
    }).toJS;

    Timer(_autoClose, () => closeWebNotification(key));
  } catch (_) {}
}

void closeWebNotification(String id) {
  final n = _open.remove(id);
  try {
    n?.close();
  } catch (_) {}
}
