import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// What the viewer needs from a video player — a small seam so tests can drive it without a real platform player, and so a platform
/// that has no player (video_player has none on Windows / Linux) fails into the viewer's "open it in Dropbox" fallback instead of crashing.
abstract class ClipPlayer extends ChangeNotifier {
  /// Opens the file. Throws when it cannot be played here.
  Future<void> initialize();
  bool get isReady;
  bool get isPlaying;
  bool get isMuted;
  Duration get position;
  Duration get duration;
  double get aspectRatio;

  /// Set when the platform reports a playback failure after it opened.
  String? get errorText;
  Future<void> play();
  Future<void> pause();
  Future<void> setMuted(bool muted);
  Future<void> seekTo(Duration to);

  /// Repeat when it ends (the grid previews). A player that cannot loop just stops at the end.
  Future<void> setLooping(bool loop) async {}

  /// The picture.
  Widget buildView();
}

/// The real thing: `video_player` streaming a network file.
class VideoPlayerClip extends ClipPlayer {
  VideoPlayerClip(Uri uri) : _c = VideoPlayerController.networkUrl(uri) {
    _c.addListener(notifyListeners);
  }

  final VideoPlayerController _c;
  bool _muted = false;

  @override
  Future<void> initialize() async {
    await _c.initialize();
    await _c.setLooping(false);
    notifyListeners();
  }

  @override
  bool get isReady => _c.value.isInitialized;
  @override
  bool get isPlaying => _c.value.isPlaying;
  @override
  bool get isMuted => _muted;
  @override
  Duration get position => _c.value.position;
  @override
  Duration get duration => _c.value.duration;
  @override
  double get aspectRatio => _c.value.isInitialized && _c.value.aspectRatio > 0 ? _c.value.aspectRatio : 16 / 9;
  @override
  String? get errorText => _c.value.hasError ? (_c.value.errorDescription ?? 'The file could not be played.') : null;

  @override
  Future<void> play() => _c.play();
  @override
  Future<void> pause() => _c.pause();
  @override
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    await _c.setVolume(muted ? 0 : 1);
    notifyListeners();
  }

  @override
  Future<void> seekTo(Duration to) => _c.seekTo(to);
  @override
  Future<void> setLooping(bool loop) => _c.setLooping(loop);
  @override
  Widget buildView() => VideoPlayer(_c);

  @override
  void dispose() {
    _c.removeListener(notifyListeners);
    _c.dispose();
    super.dispose();
  }
}

typedef ClipPlayerFactory = ClipPlayer Function(Uri uri);

/// Why a clip would not play, in the few kinds a person can act on.
enum ClipFailure { network, format, timeout, unsupported, unknown }

/// The short code shown beside the message (so "it did not work" can be told apart when asking for help).
String clipFailureCode(ClipFailure f) => f.name;

/// Plain words for each kind — never the raw error.
String clipFailureText(ClipFailure f) => switch (f) {
      ClipFailure.network => 'Dropbox did not send the video — the connection dropped or the link was refused. Dropbox limits a link that is opened a lot, and some networks and ad blockers block it.',
      ClipFailure.format => 'The browser could not play what came back: either the video\'s format is not supported here, or Dropbox refused the link (it limits a link that is opened a lot).',
      ClipFailure.timeout => 'The video took too long to start. The connection may be slow, or Dropbox is not answering.',
      ClipFailure.unsupported => 'This device has no built-in video player for the app.',
      ClipFailure.unknown => 'The video could not be started here.',
    };

/// Reads an error from the platform player (a `PlatformException` with a `MEDIA_ERR_…` code on the web, a timeout, a missing plugin).
ClipFailure classifyClipError(Object error) {
  if (error is TimeoutException) return ClipFailure.timeout;
  if (error is UnimplementedError) return ClipFailure.unsupported;
  final t = error.toString().toUpperCase();
  if (t.contains('UNIMPLEMENTED') || t.contains('MISSINGPLUGIN') || t.contains('NO IMPLEMENTATION')) return ClipFailure.unsupported;
  if (t.contains('TIMEOUT') || t.contains('TIMED OUT')) return ClipFailure.timeout;
  if (t.contains('SRC_NOT_SUPPORTED') || t.contains('DECODE') || t.contains('FORMAT')) return ClipFailure.format;
  if (t.contains('NETWORK') || t.contains('ABORTED') || t.contains('SOCKET') || t.contains('CONNECTION')) return ClipFailure.network;
  return ClipFailure.unknown;
}

class ClipOpenException implements Exception {
  const ClipOpenException(this.failure);
  final ClipFailure failure;
  @override
  String toString() => 'ClipOpenException(${failure.name})';
}

/// How long a player gets to open before it counts as not answering.
const kClipOpenTimeout = Duration(seconds: 30);

/// Opens the first address that plays. A player that fails is let go before the next is tried; when none opens, throws a
/// [ClipOpenException] with the reason of the last failure.
Future<ClipPlayer> openClip(ClipPlayerFactory make, List<String> urls, {Duration timeout = kClipOpenTimeout}) async {
  var last = ClipFailure.unknown;
  for (final u in urls) {
    final p = make(Uri.parse(u));
    try {
      await p.initialize().timeout(timeout);
      return p;
    } catch (e) {
      last = classifyClipError(e);
      p.dispose();
    }
  }
  throw ClipOpenException(last);
}

/// Tests replace this with a fake player.
final clipPlayerFactoryProvider = Provider<ClipPlayerFactory>((ref) => (uri) => VideoPlayerClip(uri));
