// Non-web stub — native browser notifications are unavailable off the web.

bool get supported => false;

Future<void> ensurePermission() async {}

void showWebNotification(String title, String body,
    {String? id, void Function()? onClick}) {}

void closeWebNotification(String id) {}
