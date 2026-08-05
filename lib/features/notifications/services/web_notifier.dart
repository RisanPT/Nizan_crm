// Facade over the browser Notification API. On non-web platforms every call is
// a no-op (the in-app toast still shows); on web it fires a native OS popup.

import 'web_notifier_stub.dart'
    if (dart.library.html) 'web_notifier_web.dart' as impl;

/// True when native browser notifications are available (web only).
bool get webNotificationsSupported => impl.supported;

/// Ask the browser for notification permission (best-effort, web only).
Future<void> ensureWebNotificationPermission() => impl.ensurePermission();

/// Show a native OS notification if permission has been granted (web only).
void showWebNotification(String title, String body) =>
    impl.showWebNotification(title, body);
