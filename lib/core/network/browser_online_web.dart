// Web: the browser's navigator.onLine flag plus its online/offline events.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool isOnline() {
  try {
    return web.window.navigator.onLine;
  } catch (_) {
    return true;
  }
}

Stream<bool> onlineChanges() {
  late StreamController<bool> controller;
  JSFunction? onOnline;
  JSFunction? onOffline;
  controller = StreamController<bool>.broadcast(
    onListen: () {
      onOnline = ((web.Event _) => controller.add(true)).toJS;
      onOffline = ((web.Event _) => controller.add(false)).toJS;
      web.window.addEventListener('online', onOnline);
      web.window.addEventListener('offline', onOffline);
    },
    onCancel: () {
      if (onOnline != null) web.window.removeEventListener('online', onOnline);
      if (onOffline != null) {
        web.window.removeEventListener('offline', onOffline);
      }
    },
  );
  return controller.stream;
}
