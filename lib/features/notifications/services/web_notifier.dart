// Facade over the browser Notification API. On non-web platforms every call is
// a no-op (the in-app toast still shows); on web it fires a native OS popup.

import 'web_notifier_stub.dart'
    if (dart.library.html) 'web_notifier_web.dart' as impl;

/// True when native browser notifications are available (web only).
bool get webNotificationsSupported => impl.supported;

/// Ask the browser for notification permission (best-effort, web only).
Future<void> ensureWebNotificationPermission() => impl.ensurePermission();

/// Show a native OS notification if permission has been granted (web only).
/// It closes itself after a few seconds, closes when clicked (focusing the app
/// and running [onClick]), and [id] is used as the OS tag so duplicates from
/// several tabs collapse into one.
void showWebNotification(String title, String body,
        {String? id, void Function()? onClick}) =>
    impl.showWebNotification(title, body, id: id, onClick: onClick);

/// Close the native notification shown for [id], if it is still open.
void closeWebNotification(String id) => impl.closeWebNotification(id);
