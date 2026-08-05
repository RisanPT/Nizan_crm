// Web implementation of the browser Notification API.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get supported => true;

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

void showWebNotification(String title, String body) {
  try {
    if (_permission() == 'granted') {
      web.Notification(title, web.NotificationOptions(body: body));
    }
  } catch (_) {}
}
