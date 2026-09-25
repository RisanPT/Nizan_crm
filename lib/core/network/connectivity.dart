import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/error_message.dart';
import 'browser_online_stub.dart'
    if (dart.library.js_interop) 'browser_online_web.dart' as browser;

/// Whether the app can currently reach the API.
enum NetworkStatus {
  /// Requests are getting through.
  online,

  /// The device has no network, or the server can't be reached.
  offline,

  /// Just came back after being offline (shown briefly as "Back online").
  restored,
}

/// App-wide connection state, fed by:
///  • every API response/failure (see [ConnectivityInterceptor]), and
///  • the browser's `online` / `offline` events on web.
///
/// While offline it pings the API every few seconds so the banner clears by
/// itself as soon as the connection (or the server) is back.
class ConnectivityNotifier extends Notifier<NetworkStatus> {
  Timer? _probe;
  Timer? _restoredTimer;
  StreamSubscription<bool>? _browserSub;

  /// Set by the dio provider: a cheap request used to probe the server.
  Future<void> Function()? ping;

  @override
  NetworkStatus build() {
    _browserSub = browser.onlineChanges().listen((online) {
      if (online) {
        // The browser says the network is back — confirm the server is too.
        _checkNow();
      } else {
        markOffline();
      }
    });
    ref.onDispose(() {
      _probe?.cancel();
      _restoredTimer?.cancel();
      _browserSub?.cancel();
    });
    return browser.isOnline() ? NetworkStatus.online : NetworkStatus.offline;
  }

  bool get isOffline => state == NetworkStatus.offline;

  void markOffline() {
    _restoredTimer?.cancel();
    if (state != NetworkStatus.offline) state = NetworkStatus.offline;
    _probe ??= Timer.periodic(const Duration(seconds: 5), (_) => _checkNow());
  }

  void markOnline() {
    _probe?.cancel();
    _probe = null;
    if (state == NetworkStatus.offline) {
      state = NetworkStatus.restored;
      _restoredTimer?.cancel();
      _restoredTimer = Timer(const Duration(seconds: 3), () {
        if (state == NetworkStatus.restored) state = NetworkStatus.online;
      });
    }
  }

  /// Try the server right now (used by the banner's "Retry" button too).
  Future<void> _checkNow() async {
    final p = ping;
    if (p == null) return;
    try {
      await p();
      markOnline();
    } catch (e) {
      // Any reply at all (even an error status) proves we're connected.
      if (e is DioException && e.response != null) {
        markOnline();
      } else {
        markOffline();
      }
    }
  }

  Future<void> retry() => _checkNow();
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, NetworkStatus>(
        ConnectivityNotifier.new);

/// Dio interceptor that reports every request outcome to [connectivityProvider].
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor(this._notifier);

  final ConnectivityNotifier Function() _notifier;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _notifier().markOnline();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      _notifier().markOnline(); // the server answered — we're connected
    } else if (isOfflineError(err)) {
      _notifier().markOffline();
    }
    handler.next(err);
  }
}
